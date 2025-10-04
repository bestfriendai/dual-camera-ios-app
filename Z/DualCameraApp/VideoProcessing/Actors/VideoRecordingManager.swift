//
//  VideoRecordingManager.swift
//  DualApp
//
//  Created by DualApp Team on 10/3/25.
//

import Foundation
import AVFoundation
import CoreMedia
import Photos
import Combine

// MARK: - Video Recording Manager

@MainActor
actor VideoRecordingManager: Sendable {
    
    // MARK: - Properties
    
    private var configuration: CameraConfiguration
    private var recordingSessions: [RecordingSession] = []
    private var activeSession: RecordingSession?
    
    // MARK: - Recording State
    
    private var isRecording: Bool = false
    private var isPaused: Bool = false
    private var recordingStartTime: Date?
    private var pausedDuration: TimeInterval = 0
    private var totalPausedDuration: TimeInterval = 0
    
    // MARK: - Asset Writers
    
    private var assetWriters: [RecordingOutput: AVAssetWriter] = [:]
    private var assetWriterInputs: [RecordingOutput: [AVAssetWriterInput]] = [:]
    
    // MARK: - Recording URLs
    
    private var recordingURLs: [RecordingOutput: URL] = [:]
    
    // MARK: - Recording Options
    
    private var recordingOutputs: Set<RecordingOutput> = [.front, .back, .composite]
    private var videoCompositionMode: VideoCompositionMode = .sideBySide
    
    // MARK: - Event Stream
    
    let events: AsyncStream<VideoRecordingEvent>
    private let eventContinuation: AsyncStream<VideoRecordingEvent>.Continuation
    
    // MARK: - Performance Monitoring
    
    private var recordingMetrics: VideoRecordingMetrics = VideoRecordingMetrics()
    private var frameCounters: [RecordingOutput: Int] = [:]
    private var droppedFrameCounters: [RecordingOutput: Int] = [:]
    
    // MARK: - Quality Presets
    
    private var qualityPresets: [VideoQualityPreset] = []
    private var currentQualityPreset: VideoQualityPreset?
    
    // MARK: - Initialization
    
    init(configuration: CameraConfiguration) {
        self.configuration = configuration
        
        (self.events, self.eventContinuation) = AsyncStream<VideoRecordingEvent>.makeStream()
        
        // Initialize quality presets
        setupQualityPresets()
        
        // Initialize frame counters
        for output in RecordingOutput.allCases {
            frameCounters[output] = 0
            droppedFrameCounters[output] = 0
        }
    }
    
    // MARK: - Public Interface
    
    func startRecording() async throws -> RecordingSession {
        guard !isRecording else {
            throw VideoRecordingManagerError.alreadyRecording
        }
        
        // Create recording session
        let session = RecordingSession(configuration: configuration)
        activeSession = session
        recordingStartTime = Date()
        
        // Generate recording URLs
        try await generateRecordingURLs()
        
        // Create asset writers
        try await createAssetWriters()
        
        // Start recording sessions
        try await startRecordingSessions()
        
        isRecording = true
        isPaused = false
        
        eventContinuation.yield(.recordingStarted(session))
        
        return session
    }
    
    func stopRecording() async throws -> RecordingSession {
        guard isRecording, let session = activeSession else {
            throw VideoRecordingManagerError.notRecording
        }
        
        isRecording = false
        
        // Calculate final duration
        let finalDuration = calculateRecordingDuration()
        
        // Finish recording
        try await finishRecording()
        
        // Update session
        session.updateState(.stopped)
        session.duration = finalDuration
        
        // Add to recording history
        recordingSessions.append(session)
        
        eventContinuation.yield(.recordingStopped(session))
        
        activeSession = nil
        
        return session
    }
    
    func pauseRecording() async throws {
        guard isRecording && !isPaused else {
            throw VideoRecordingManagerError.invalidState
        }
        
        isPaused = true
        pausedDuration = Date()
        
        // Pause asset writers
        for (_, writer) in assetWriters {
            writer.pause()
        }
        
        eventContinuation.yield(.recordingPaused)
    }
    
    func resumeRecording() async throws {
        guard isRecording && isPaused else {
            throw VideoRecordingManagerError.invalidState
        }
        
        isPaused = false
        totalPausedDuration += Date().timeIntervalSince(pausedDuration)
        
        // Resume asset writers
        for (_, writer) in assetWriters {
            writer.resume()
        }
        
        eventContinuation.yield(.recordingResumed)
    }
    
    func processVideoFrame(_ frame: DualCameraFrame) async {
        guard isRecording && !isPaused else { return }
        
        // Update frame counter
        frameCounters[frame.output, default: 0] += 1
        
        // Process frame for each enabled output
        for output in recordingOutputs {
            await processFrameForOutput(frame, output: output)
        }
    }
    
    func processAudioFrame(_ sampleBuffer: CMSampleBuffer) async {
        guard isRecording && !isPaused else { return }
        
        do {
            try await writeAudioFrame(sampleBuffer)
        } catch {
            eventContinuation.yield(.error(VideoRecordingManagerError.audioProcessingFailed(error)))
        }
    }
    
    func setRecordingOutputs(_ outputs: Set<RecordingOutput>) async {
        recordingOutputs = outputs
        eventContinuation.yield(.recordingOutputsChanged(outputs))
    }
    
    func setVideoCompositionMode(_ mode: VideoCompositionMode) async {
        videoCompositionMode = mode
        eventContinuation.yield(.videoCompositionModeChanged(mode))
    }
    
    func setQualityPreset(_ preset: VideoQualityPreset) async {
        currentQualityPreset = preset
        configuration = preset.configuration
        eventContinuation.yield(.qualityPresetChanged(preset))
    }
    
    func getRecordingMetrics() async -> VideoRecordingMetrics {
        var metrics = recordingMetrics
        metrics.duration = calculateRecordingDuration()
        metrics.frameCount = frameCounters.values.reduce(0, +)
        metrics.droppedFrameCount = droppedFrameCounters.values.reduce(0, +)
        
        if metrics.frameCount > 0 {
            metrics.frameDropRate = Double(metrics.droppedFrameCount) / Double(metrics.frameCount)
        }
        
        return metrics
    }
    
    func getRecordingState() async -> RecordingState {
        guard let session = activeSession else {
            return .idle
        }
        
        return session.state
    }
    
    func getRecordingHistory() async -> [RecordingSession] {
        return recordingSessions
    }
    
    func deleteRecording(_ session: RecordingSession) async throws {
        // Delete files
        for track in session.recordings {
            try FileManager.default.removeItem(at: track.url)
        }
        
        // Remove from history
        recordingSessions.removeAll { $0.id == session.id }
        
        eventContinuation.yield(.recordingDeleted(session))
    }
    
    // MARK: - Private Methods
    
    private func setupQualityPresets() {
        qualityPresets = [
            VideoQualityPreset(
                name: "Low Power",
                configuration: .lowPower,
                description: "Optimized for battery life",
                icon: "battery.100"
            ),
            VideoQualityPreset(
                name: "Standard",
                configuration: .default,
                description: "Balanced quality and performance",
                icon: "camera"
            ),
            VideoQualityPreset(
                name: "High Quality",
                configuration: .highQuality,
                description: "Best quality recording",
                icon: "camera.aperture"
            ),
            VideoQualityPreset(
                name: "Portrait",
                configuration: .portrait,
                description: "Portrait mode with depth effect",
                icon: "person.crop.circle"
            ),
            VideoQualityPreset(
                name: "Cinematic",
                configuration: .cinematic,
                description: "Cinematic video recording",
                icon: "film"
            ),
            VideoQualityPreset(
                name: "Slow Motion",
                configuration: .slowMotion,
                description: "High frame rate slow motion",
                icon: "slowmo"
            ),
            VideoQualityPreset(
                name: "Time Lapse",
                configuration: .timeLapse,
                description: "Time lapse recording",
                icon: "timelapse"
            ),
            VideoQualityPreset(
                name: "Night Mode",
                configuration: .nightMode,
                description: "Optimized for low light",
                icon: "moon"
            )
        ]
        
        currentQualityPreset = qualityPresets.first { $0.configuration == configuration }
    }
    
    private func generateRecordingURLs() async throws {
        let timestamp = Int(Date().timeIntervalSince1970)
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        
        for output in recordingOutputs {
            let filename = "\(output.rawValue.lowercased())_\(timestamp).\(configuration.outputFormat.rawValue.lowercased())"
            recordingURLs[output] = documentsPath.appendingPathComponent(filename)
        }
    }
    
    private func createAssetWriters() async throws {
        for output in recordingOutputs {
            guard let url = recordingURLs[output] else { continue }
            
            let writer = try AVAssetWriter(outputURL: url, fileType: configuration.outputFormat.avFileType)
            assetWriters[output] = writer
            
            // Create inputs based on output type
            switch output {
            case .front, .back:
                try await createVideoInput(for: output, writer: writer)
            case .composite, .pictureInPicture:
                try await createVideoInput(for: output, writer: writer)
                if configuration.audioEnabled {
                    try await createAudioInput(for: output, writer: writer)
                }
            }
        }
    }
    
    private func createVideoInput(for output: RecordingOutput, writer: AVAssetWriter) async throws {
        let videoSettings: [String: Any] = [
            AVVideoCodecKey: configuration.outputFormat.codec,
            AVVideoWidthKey: getVideoSize(for: output).width,
            AVVideoHeightKey: getVideoSize(for: output).height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: getBitrate(for: output),
                AVVideoExpectedSourceFrameRateKey: configuration.frameRate,
                AVVideoMaxKeyFrameIntervalKey: configuration.keyFrameInterval,
                AVVideoProfileLevelKey: kAVVideoProfileLevelH264HighAutoLevel
            ]
        ]
        
        let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        videoInput.expectsMediaDataInRealTime = true
        
        if assetWriterInputs[output] == nil {
            assetWriterInputs[output] = []
        }
        assetWriterInputs[output]?.append(videoInput)
        
        if writer.canAdd(videoInput) {
            writer.add(videoInput)
        }
    }
    
    private func createAudioInput(for output: RecordingOutput, writer: AVAssetWriter) async throws {
        let audioSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVNumberOfChannelsKey: configuration.audioQuality.channels,
            AVSampleRateKey: configuration.audioQuality.sampleRate,
            AVEncoderBitRateKey: configuration.audioQuality.bitRate
        ]
        
        let audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
        audioInput.expectsMediaDataInRealTime = true
        
        if assetWriterInputs[output] == nil {
            assetWriterInputs[output] = []
        }
        assetWriterInputs[output]?.append(audioInput)
        
        if writer.canAdd(audioInput) {
            writer.add(audioInput)
        }
    }
    
    private func startRecordingSessions() async throws {
        let startTime = CMSampleBufferGetPresentationTimeStamp(CMSampleBufferCreateReadyWithImageBuffer(nil, nil, nil, nil).takeRetainedValue())
        
        for (_, writer) in assetWriters {
            writer.startWriting()
            writer.startSession(atSourceTime: startTime)
        }
    }
    
    private func processFrameForOutput(_ frame: DualCameraFrame, output: RecordingOutput) async {
        guard let inputs = assetWriterInputs[output],
              let videoInput = inputs.first(where: { $0.mediaType == .video }),
              videoInput.isReadyForMoreMediaData else {
            droppedFrameCounters[output, default: 0] += 1
            return
        }
        
        do {
            let sampleBuffer = try createSampleBuffer(for: frame, output: output)
            videoInput.append(sampleBuffer)
        } catch {
            droppedFrameCounters[output, default: 0] += 1
        }
    }
    
    private func writeAudioFrame(_ sampleBuffer: CMSampleBuffer) async throws {
        for (output, inputs) in assetWriterInputs {
            guard let audioInput = inputs.first(where: { $0.mediaType == .audio }),
                  audioInput.isReadyForMoreMediaData else {
                continue
            }
            
            audioInput.append(sampleBuffer)
        }
    }
    
    private func createSampleBuffer(for frame: DualCameraFrame, output: RecordingOutput) throws -> CMSampleBuffer {
        // Create sample buffer from frame based on output type
        switch output {
        case .front, .back:
            return try createSingleCameraSampleBuffer(from: frame)
        case .composite:
            return try createCompositeSampleBuffer(from: frame)
        case .pictureInPicture:
            return try createPictureInPictureSampleBuffer(from: frame)
        }
    }
    
    private func createSingleCameraSampleBuffer(from frame: DualCameraFrame) throws -> CMSampleBuffer {
        // Create sample buffer from single camera frame
        // This would convert the frame's pixel buffer to a sample buffer
        throw VideoRecordingManagerError.sampleBufferCreationFailed
    }
    
    private func createCompositeSampleBuffer(from frame: DualCameraFrame) throws -> CMSampleBuffer {
        // Create composite sample buffer based on composition mode
        switch videoCompositionMode {
        case .sideBySide:
            return try createSideBySideSampleBuffer(from: frame)
        case .pictureInPicture:
            return try createPictureInPictureSampleBuffer(from: frame)
        case .splitScreen:
            return try createSplitScreenSampleBuffer(from: frame)
        case .overlay:
            return try createOverlaySampleBuffer(from: frame)
        }
    }
    
    private func createSideBySideSampleBuffer(from frame: DualCameraFrame) throws -> CMSampleBuffer {
        // Create side-by-side composite
        throw VideoRecordingManagerError.sampleBufferCreationFailed
    }
    
    private func createPictureInPictureSampleBuffer(from frame: DualCameraFrame) throws -> CMSampleBuffer {
        // Create picture-in-picture composite
        throw VideoRecordingManagerError.sampleBufferCreationFailed
    }
    
    private func createSplitScreenSampleBuffer(from frame: DualCameraFrame) throws -> CMSampleBuffer {
        // Create split-screen composite
        throw VideoRecordingManagerError.sampleBufferCreationFailed
    }
    
    private func createOverlaySampleBuffer(from frame: DualCameraFrame) throws -> CMSampleBuffer {
        // Create overlay composite
        throw VideoRecordingManagerError.sampleBufferCreationFailed
    }
    
    private func getVideoSize(for output: RecordingOutput) -> CGSize {
        switch output {
        case .front, .back:
            return configuration.quality.resolution
        case .composite:
            return getCompositeSize()
        case .pictureInPicture:
            return configuration.quality.resolution
        }
    }
    
    private func getBitrate(for output: RecordingOutput) -> Int {
        switch output {
        case .front, .back:
            return configuration.quality.bitRate
        case .composite:
            return configuration.quality.bitRate * 2
        case .pictureInPicture:
            return configuration.quality.bitRate
        }
    }
    
    private func getCompositeSize() -> CGSize {
        switch videoCompositionMode {
        case .sideBySide:
            return CGSize(
                width: configuration.quality.resolution.width * 2,
                height: configuration.quality.resolution.height
            )
        case .pictureInPicture, .splitScreen, .overlay:
            return configuration.quality.resolution
        }
    }
    
    private func finishRecording() async throws {
        // Mark inputs as finished
        for (_, inputs) in assetWriterInputs {
            for input in inputs {
                input.markAsFinished()
            }
        }
        
        // Finish writing
        for (_, writer) in assetWriters {
            writer.finishWriting {}
        }
        
        // Save to photo library if enabled
        if configuration.includeDeviceMetadata {
            try await saveRecordingsToPhotoLibrary()
        }
        
        // Update metrics
        recordingMetrics.fileSize = await calculateTotalFileSize()
        recordingMetrics.averageBitrate = await calculateAverageBitrate()
    }
    
    private func saveRecordingsToPhotoLibrary() async throws {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized else {
            throw VideoRecordingManagerError.photoLibraryAccessDenied
        }
        
        for (_, url) in recordingURLs {
            try await saveVideoToPhotoLibrary(at: url)
        }
    }
    
    private func saveVideoToPhotoLibrary(at url: URL) async throws {
        try await PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
        }
    }
    
    private func calculateRecordingDuration() -> TimeInterval {
        guard let startTime = recordingStartTime else { return 0 }
        
        var duration = Date().timeIntervalSince(startTime)
        duration -= totalPausedDuration
        
        if isPaused {
            duration -= Date().timeIntervalSince(pausedDuration)
        }
        
        return duration
    }
    
    private func calculateTotalFileSize() async -> Int64 {
        var totalSize: Int64 = 0
        
        for (_, url) in recordingURLs {
            totalSize += getFileSize(at: url)
        }
        
        return totalSize
    }
    
    private func calculateAverageBitrate() async -> Double {
        let totalSize = await calculateTotalFileSize()
        let duration = calculateRecordingDuration()
        return duration > 0 ? Double(totalSize * 8) / duration : 0
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

enum VideoRecordingEvent: Sendable {
    case recordingStarted(RecordingSession)
    case recordingStopped(RecordingSession)
    case recordingPaused
    case recordingResumed
    case recordingOutputsChanged(Set<RecordingOutput>)
    case videoCompositionModeChanged(VideoCompositionMode)
    case qualityPresetChanged(VideoQualityPreset)
    case recordingDeleted(RecordingSession)
    case error(VideoRecordingManagerError)
}

enum VideoRecordingManagerError: LocalizedError, Sendable {
    case alreadyRecording
    case notRecording
    case invalidState
    case audioProcessingFailed(Error)
    case sampleBufferCreationFailed
    case photoLibraryAccessDenied
    
    var errorDescription: String? {
        switch self {
        case .alreadyRecording:
            return "Recording is already in progress"
        case .notRecording:
            return "No recording is in progress"
        case .invalidState:
            return "Invalid recording state"
        case .audioProcessingFailed(let error):
            return "Audio processing failed: \(error.localizedDescription)"
        case .sampleBufferCreationFailed:
            return "Failed to create sample buffer"
        case .photoLibraryAccessDenied:
            return "Photo library access denied"
        }
    }
}

struct VideoQualityPreset: Sendable, Identifiable {
    let id = UUID()
    let name: String
    let configuration: CameraConfiguration
    let description: String
    let icon: String
}

extension DualCameraFrame {
    var output: RecordingOutput {
        switch position {
        case .front:
            return .front
        case .back:
            return .back
        default:
            return .back
        }
    }
}