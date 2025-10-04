//
//  RecordingCoordinator.swift
//  DualApp
//
//  Created by DualApp Team on 10/3/25.
//

import Foundation
import AVFoundation
import CoreMedia

// MARK: - Recording Coordinator

@MainActor
actor RecordingCoordinator: Sendable {
    
    // MARK: - Properties
    
    private var configuration: CameraConfiguration
    private var frontDevice: AVCaptureDevice?
    private var backDevice: AVCaptureDevice?
    
    // MARK: - Recording State
    
    private var isRecording: Bool = false
    private var recordingStartTime: Date?
    private var recordingDuration: TimeInterval = 0
    
    // MARK: - Asset Writers
    
    private var frontAssetWriter: AVAssetWriter?
    private var backAssetWriter: AVAssetWriter?
    private var compositeAssetWriter: AVAssetWriter?
    
    // MARK: - Asset Writer Inputs
    
    private var frontVideoInput: AVAssetWriterInput?
    private var backVideoInput: AVAssetWriterInput?
    private var audioInput: AVAssetWriterInput?
    private var compositeVideoInput: AVAssetWriterInput?
    
    // MARK: - Pixel Buffer Pools
    
    private var frontPixelBufferPool: CVPixelBufferPool?
    private var backPixelBufferPool: CVPixelBufferPool?
    private var compositePixelBufferPool: CVPixelBufferPool?
    
    // MARK: - File Management
    
    private var frontRecordingURL: URL?
    private var backRecordingURL: URL?
    private var compositeRecordingURL: URL?
    
    // MARK: - Frame Processing
    
    private var frameProcessor: FrameProcessor?
    private var videoCompositor: VideoCompositor?
    
    // MARK: - Event Stream
    
    let events: AsyncStream<RecordingEvent>
    private let eventContinuation: AsyncStream<RecordingEvent>.Continuation
    
    // MARK: - Performance Monitoring
    
    private var recordingMetrics: RecordingMetrics = RecordingMetrics()
    private var frameDropCount: Int = 0
    private var totalFrameCount: Int = 0
    
    // MARK: - Initialization
    
    init(configuration: CameraConfiguration, frontDevice: AVCaptureDevice?, backDevice: AVCaptureDevice?) {
        self.configuration = configuration
        self.frontDevice = frontDevice
        self.backDevice = backDevice
        
        (self.events, self.eventContinuation) = AsyncStream<RecordingEvent>.makeStream()
        
        // Initialize frame processor and compositor
        self.frameProcessor = FrameProcessor(configuration: configuration)
        self.videoCompositor = VideoCompositor(configuration: configuration)
    }
    
    // MARK: - Public Interface
    
    func startRecording() async throws {
        guard !isRecording else {
            throw RecordingError.alreadyRecording
        }
        
        // Generate recording URLs
        await generateRecordingURLs()
        
        // Create asset writers
        try await createAssetWriters()
        
        // Create pixel buffer pools
        try await createPixelBufferPools()
        
        // Start recording sessions
        try await startRecordingSessions()
        
        isRecording = true
        recordingStartTime = Date()
        
        eventContinuation.yield(.recordingStarted)
        
        // Start recording monitoring
        await startRecordingMonitoring()
    }
    
    func stopRecording() async throws {
        guard isRecording else {
            throw RecordingError.notRecording
        }
        
        isRecording = false
        recordingDuration = Date().timeIntervalSince(recordingStartTime ?? Date())
        
        // Stop recording monitoring
        await stopRecordingMonitoring()
        
        // Finish writing
        try await finishRecording()
        
        eventContinuation.yield(.recordingStopped(recordingDuration))
    }
    
    func processVideoFrame(_ frame: DualCameraFrame) async {
        guard isRecording else { return }
        
        totalFrameCount += 1
        
        do {
            // Process frame based on camera position
            switch frame.position {
            case .front:
                try await processFrontCameraFrame(frame)
            case .back:
                try await processBackCameraFrame(frame)
            default:
                break
            }
            
            // Process for composite recording
            try await processCompositeFrame(frame)
            
        } catch {
            frameDropCount += 1
            eventContinuation.yield(.frameDropped(frame.position, error))
        }
    }
    
    func processAudioFrame(_ sampleBuffer: CMSampleBuffer) async {
        guard isRecording else { return }
        
        do {
            try await writeAudioFrame(sampleBuffer)
        } catch {
            eventContinuation.yield(.audioFrameDropped(error))
        }
    }
    
    func getRecordingMetrics() async -> RecordingMetrics {
        var metrics = recordingMetrics
        metrics.duration = recordingDuration
        metrics.frameDropRate = totalFrameCount > 0 ? Double(frameDropCount) / Double(totalFrameCount) : 0
        metrics.totalFrames = totalFrameCount
        metrics.droppedFrames = frameDropCount
        
        return metrics
    }
    
    func pauseRecording() async throws {
        guard isRecording else {
            throw RecordingError.notRecording
        }
        
        // Pause asset writers
        frontAssetWriter?.pause()
        backAssetWriter?.pause()
        compositeAssetWriter?.pause()
        
        eventContinuation.yield(.recordingPaused)
    }
    
    func resumeRecording() async throws {
        guard isRecording else {
            throw RecordingError.notRecording
        }
        
        // Resume asset writers
        frontAssetWriter?.resume()
        backAssetWriter?.resume()
        compositeAssetWriter?.resume()
        
        eventContinuation.yield(.recordingResumed)
    }
    
    // MARK: - Private Methods
    
    private func generateRecordingURLs() async {
        let timestamp = Date().timeIntervalSince1970
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        
        frontRecordingURL = documentsPath.appendingPathComponent("front_\(timestamp).\(configuration.outputFormat.rawValue.lowercased())")
        backRecordingURL = documentsPath.appendingPathComponent("back_\(timestamp).\(configuration.outputFormat.rawValue.lowercased())")
        compositeRecordingURL = documentsPath.appendingPathComponent("composite_\(timestamp).\(configuration.outputFormat.rawValue.lowercased())")
    }
    
    private func createAssetWriters() async throws {
        guard let frontURL = frontRecordingURL,
              let backURL = backRecordingURL,
              let compositeURL = compositeRecordingURL else {
            throw RecordingError.invalidURL
        }
        
        // Create front camera asset writer
        frontAssetWriter = try AVAssetWriter(outputURL: frontURL, fileType: configuration.outputFormat.avFileType)
        
        // Create back camera asset writer
        backAssetWriter = try AVAssetWriter(outputURL: backURL, fileType: configuration.outputFormat.avFileType)
        
        // Create composite asset writer
        compositeAssetWriter = try AVAssetWriter(outputURL: compositeURL, fileType: configuration.outputFormat.avFileType)
        
        // Configure video inputs
        try await configureVideoInputs()
        
        // Configure audio input
        try await configureAudioInput()
    }
    
    private func configureVideoInputs() async throws {
        guard let frontWriter = frontAssetWriter,
              let backWriter = backAssetWriter,
              let compositeWriter = compositeAssetWriter else {
            throw RecordingError.assetWriterNotAvailable
        }
        
        // Front camera video input
        let frontVideoSettings: [String: Any] = [
            AVVideoCodecKey: configuration.outputFormat.codec,
            AVVideoWidthKey: configuration.quality.resolution.width,
            AVVideoHeightKey: configuration.quality.resolution.height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: configuration.quality.bitRate,
                AVVideoExpectedSourceFrameRateKey: configuration.frameRate,
                AVVideoMaxKeyFrameIntervalKey: configuration.keyFrameInterval,
                AVVideoProfileLevelKey: kAVVideoProfileLevelH264HighAutoLevel
            ]
        ]
        
        frontVideoInput = AVAssetWriterInput(mediaType: .video, outputSettings: frontVideoSettings)
        frontVideoInput?.expectsMediaDataInRealTime = true
        
        if frontWriter.canAdd(frontVideoInput!) {
            frontWriter.add(frontVideoInput!)
        }
        
        // Back camera video input
        let backVideoSettings: [String: Any] = [
            AVVideoCodecKey: configuration.outputFormat.codec,
            AVVideoWidthKey: configuration.quality.resolution.width,
            AVVideoHeightKey: configuration.quality.resolution.height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: configuration.quality.bitRate,
                AVVideoExpectedSourceFrameRateKey: configuration.frameRate,
                AVVideoMaxKeyFrameIntervalKey: configuration.keyFrameInterval,
                AVVideoProfileLevelKey: kAVVideoProfileLevelH264HighAutoLevel
            ]
        ]
        
        backVideoInput = AVAssetWriterInput(mediaType: .video, outputSettings: backVideoSettings)
        backVideoInput?.expectsMediaDataInRealTime = true
        
        if backWriter.canAdd(backVideoInput!) {
            backWriter.add(backVideoInput!)
        }
        
        // Composite video input
        let compositeVideoSettings: [String: Any] = [
            AVVideoCodecKey: configuration.outputFormat.codec,
            AVVideoWidthKey: configuration.quality.resolution.width * 2, // Side by side
            AVVideoHeightKey: configuration.quality.resolution.height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: configuration.quality.bitRate * 2,
                AVVideoExpectedSourceFrameRateKey: configuration.frameRate,
                AVVideoMaxKeyFrameIntervalKey: configuration.keyFrameInterval,
                AVVideoProfileLevelKey: kAVVideoProfileLevelH264HighAutoLevel
            ]
        ]
        
        compositeVideoInput = AVAssetWriterInput(mediaType: .video, outputSettings: compositeVideoSettings)
        compositeVideoInput?.expectsMediaDataInRealTime = true
        
        if compositeWriter.canAdd(compositeVideoInput!) {
            compositeWriter.add(compositeVideoInput!)
        }
    }
    
    private func configureAudioInput() async throws {
        guard configuration.audioEnabled,
              let compositeWriter = compositeAssetWriter else {
            return
        }
        
        let audioSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVNumberOfChannelsKey: configuration.audioQuality.channels,
            AVSampleRateKey: configuration.audioQuality.sampleRate,
            AVEncoderBitRateKey: configuration.audioQuality.bitRate
        ]
        
        audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
        audioInput?.expectsMediaDataInRealTime = true
        
        if compositeWriter.canAdd(audioInput!) {
            compositeWriter.add(audioInput!)
        }
    }
    
    private func createPixelBufferPools() async throws {
        // Create pixel buffer pools for efficient frame processing
        frontPixelBufferPool = try createPixelBufferPool(
            width: Int(configuration.quality.resolution.width),
            height: Int(configuration.quality.resolution.height),
            pixelFormat: kCVPixelFormatType_32BGRA
        )
        
        backPixelBufferPool = try createPixelBufferPool(
            width: Int(configuration.quality.resolution.width),
            height: Int(configuration.quality.resolution.height),
            pixelFormat: kCVPixelFormatType_32BGRA
        )
        
        compositePixelBufferPool = try createPixelBufferPool(
            width: Int(configuration.quality.resolution.width * 2),
            height: Int(configuration.quality.resolution.height),
            pixelFormat: kCVPixelFormatType_32BGRA
        )
    }
    
    private func createPixelBufferPool(width: Int, height: Int, pixelFormat: OSType) throws -> CVPixelBufferPool {
        let pixelBufferAttributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: pixelFormat,
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height,
            kCVPixelBufferIOSurfacePropertiesKey as String: [:],
            kCVPixelBufferPoolMinimumBufferCountKey as String: 3
        ]
        
        var pixelBufferPool: CVPixelBufferPool?
        let status = CVPixelBufferPoolCreate(kCFAllocatorDefault, pixelBufferAttributes as CFDictionary, nil, &pixelBufferPool)
        
        guard status == kCVReturnSuccess, let pool = pixelBufferPool else {
            throw RecordingError.pixelBufferPoolCreationFailed
        }
        
        return pool
    }
    
    private func startRecordingSessions() async throws {
        guard let frontWriter = frontAssetWriter,
              let backWriter = backAssetWriter,
              let compositeWriter = compositeAssetWriter else {
            throw RecordingError.assetWriterNotAvailable
        }
        
        // Start writing
        frontWriter.startWriting()
        backWriter.startWriting()
        compositeWriter.startWriting()
        
        // Start sessions
        let startTime = CMSampleBufferGetPresentationTimeStamp(CMSampleBufferCreateReadyWithImageBuffer(nil, nil, nil, nil).takeRetainedValue())
        
        frontWriter.startSession(atSourceTime: startTime)
        backWriter.startSession(atSourceTime: startTime)
        compositeWriter.startSession(atSourceTime: startTime)
    }
    
    private func processFrontCameraFrame(_ frame: DualCameraFrame) async throws {
        guard let frontInput = frontVideoInput,
              frontInput.isReadyForMoreMediaData else {
            throw RecordingError.inputNotReady
        }
        
        // Process frame through frame processor
        let processedFrame = await frameProcessor?.processFrame(frame)
        
        // Append to front camera recording
        if let sampleBuffer = processedFrame?.sampleBuffer {
            frontInput.append(sampleBuffer)
        }
    }
    
    private func processBackCameraFrame(_ frame: DualCameraFrame) async throws {
        guard let backInput = backVideoInput,
              backInput.isReadyForMoreMediaData else {
            throw RecordingError.inputNotReady
        }
        
        // Process frame through frame processor
        let processedFrame = await frameProcessor?.processFrame(frame)
        
        // Append to back camera recording
        if let sampleBuffer = processedFrame?.sampleBuffer {
            backInput.append(sampleBuffer)
        }
    }
    
    private func processCompositeFrame(_ frame: DualCameraFrame) async throws {
        guard let compositeInput = compositeVideoInput,
              compositeInput.isReadyForMoreMediaData else {
            throw RecordingError.inputNotReady
        }
        
        // Create composite frame using video compositor
        let compositeFrame = await videoCompositor?.createCompositeFrame(frame)
        
        // Append to composite recording
        if let sampleBuffer = compositeFrame?.sampleBuffer {
            compositeInput.append(sampleBuffer)
        }
    }
    
    private func writeAudioFrame(_ sampleBuffer: CMSampleBuffer) async throws {
        guard let audioInput = audioInput,
              audioInput.isReadyForMoreMediaData else {
            throw RecordingError.inputNotReady
        }
        
        audioInput.append(sampleBuffer)
    }
    
    private func finishRecording() async throws {
        // Finish writing sessions
        frontVideoInput?.markAsFinished()
        backVideoInput?.markAsFinished()
        compositeVideoInput?.markAsFinished()
        audioInput?.markAsFinished()
        
        // Wait for completion
        frontAssetWriter?.finishWriting {}
        backAssetWriter?.finishWriting {}
        compositeAssetWriter?.finishWriting {}
        
        // Update metrics
        recordingMetrics.fileSize = await calculateTotalFileSize()
        recordingMetrics.averageBitrate = await calculateAverageBitrate()
        
        eventContinuation.yield(.recordingCompleted(recordingMetrics))
    }
    
    private func startRecordingMonitoring() async {
        Task {
            while isRecording {
                await updateRecordingMetrics()
                try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            }
        }
    }
    
    private func stopRecordingMonitoring() async {
        // Monitoring task will stop when isRecording becomes false
    }
    
    private func updateRecordingMetrics() async {
        guard let startTime = recordingStartTime else { return }
        
        recordingDuration = Date().timeIntervalSince(startTime)
        recordingMetrics.duration = recordingDuration
        
        // Calculate current bitrate
        if let currentSize = await calculateTotalFileSize(), recordingDuration > 0 {
            recordingMetrics.currentBitrate = Double(currentSize * 8) / recordingDuration
        }
        
        eventContinuation.yield(.metricsUpdated(recordingMetrics))
    }
    
    private func calculateTotalFileSize() async -> Int64 {
        var totalSize: Int64 = 0
        
        if let frontURL = frontRecordingURL {
            totalSize += getFileSize(at: frontURL)
        }
        
        if let backURL = backRecordingURL {
            totalSize += getFileSize(at: backURL)
        }
        
        if let compositeURL = compositeRecordingURL {
            totalSize += getFileSize(at: compositeURL)
        }
        
        return totalSize
    }
    
    private func calculateAverageBitrate() async -> Double {
        let totalSize = await calculateTotalFileSize()
        return recordingDuration > 0 ? Double(totalSize * 8) / recordingDuration : 0
    }
    
    private func getFileSize(at url: URL) -> Int64 {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            return attributes[.size] as? Int64 ?? 0
        } catch {
            return 0
        }
    }
}

// MARK: - Supporting Types

enum RecordingEvent: Sendable {
    case recordingStarted
    case recordingStopped(TimeInterval)
    case recordingPaused
    case recordingResumed
    case recordingCompleted(RecordingMetrics)
    case metricsUpdated(RecordingMetrics)
    case frameDropped(CameraPosition, Error)
    case audioFrameDropped(Error)
    case warning(String)
    case error(RecordingError)
}

enum RecordingError: LocalizedError, Sendable {
    case alreadyRecording
    case notRecording
    case assetWriterNotAvailable
    case invalidURL
    case inputNotReady
    case pixelBufferPoolCreationFailed
    case configurationInvalid
    
    var errorDescription: String? {
        switch self {
        case .alreadyRecording:
            return "Recording is already in progress"
        case .notRecording:
            return "No recording is in progress"
        case .assetWriterNotAvailable:
            return "Asset writer is not available"
        case .invalidURL:
            return "Invalid recording URL"
        case .inputNotReady:
            return "Asset writer input is not ready"
        case .pixelBufferPoolCreationFailed:
            return "Failed to create pixel buffer pool"
        case .configurationInvalid:
            return "Invalid recording configuration"
        }
    }
}

struct RecordingMetrics: Sendable {
    var duration: TimeInterval = 0
    var fileSize: Int64 = 0
    var averageBitrate: Double = 0
    var currentBitrate: Double = 0
    var frameDropRate: Double = 0
    var totalFrames: Int = 0
    var droppedFrames: Int = 0
    
    var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    var formattedFileSize: String {
        return ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
    }
    
    var formattedAverageBitrate: String {
        return String(format: "%.0f kbps", averageBitrate / 1000)
    }
    
    var formattedFrameDropRate: String {
        return String(format: "%.1f%%", frameDropRate * 100)
    }
}

// MARK: - Frame Processor

class FrameProcessor: @unchecked Sendable {
    private let configuration: CameraConfiguration
    
    init(configuration: CameraConfiguration) {
        self.configuration = configuration
    }
    
    func processFrame(_ frame: DualCameraFrame) async -> DualCameraFrame? {
        // Apply filters, adjustments, and optimizations
        var processedFrame = frame
        
        // Apply color correction
        if configuration.colorFilter != .none {
            processedFrame = await applyColorFilter(processedFrame, filter: configuration.colorFilter)
        }
        
        // Apply stabilization if enabled
        if configuration.videoStabilizationEnabled {
            processedFrame = await applyStabilization(processedFrame)
        }
        
        // Apply HDR processing if enabled
        if configuration.hdrEnabled {
            processedFrame = await applyHDRProcessing(processedFrame)
        }
        
        return processedFrame
    }
    
    private func applyColorFilter(_ frame: DualCameraFrame, filter: ColorFilter) async -> DualCameraFrame {
        // Apply color filter processing
        return frame
    }
    
    private func applyStabilization(_ frame: DualCameraFrame) async -> DualCameraFrame {
        // Apply video stabilization
        return frame
    }
    
    private func applyHDRProcessing(_ frame: DualCameraFrame) async -> DualCameraFrame {
        // Apply HDR processing
        return frame
    }
}

// MARK: - Video Compositor

class VideoCompositor: @unchecked Sendable {
    private let configuration: CameraConfiguration
    private var frameBuffer: [CameraPosition: DualCameraFrame] = [:]
    
    init(configuration: CameraConfiguration) {
        self.configuration = configuration
    }
    
    func createCompositeFrame(_ frame: DualCameraFrame) async -> DualCameraFrame? {
        // Store frame in buffer
        frameBuffer[frame.position] = frame
        
        // Check if we have frames from both cameras
        guard let frontFrame = frameBuffer[.front],
              let backFrame = frameBuffer[.back] else {
            return nil
        }
        
        // Create composite frame based on configuration
        switch configuration.multiCamEnabled {
        case true:
            return await createSideBySideComposite(frontFrame: frontFrame, backFrame: backFrame)
        case false:
            return backFrame // Use back camera as primary
        }
    }
    
    private func createSideBySideComposite(frontFrame: DualCameraFrame, backFrame: DualCameraFrame) async -> DualCameraFrame? {
        // Create side-by-side composite
        // This would use Metal or Core Image to composite the frames
        return backFrame // Placeholder
    }
}