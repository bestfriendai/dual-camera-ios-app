//
//  VideoRecorder.swift
//  DualApp
//
//  Created by DualApp Team on 10/3/25.
//

import Foundation
import AVFoundation
import CoreMedia
import Photos

// MARK: - Video Recorder Actor

@MainActor
actor VideoRecorder: Sendable {
    
    // MARK: - Properties
    
    private var configuration: CameraConfiguration
    private var isRecording: Bool = false
    private var isPaused: Bool = false
    
    // MARK: - Recording State
    
    private var recordingSession: RecordingSession?
    private var recordingStartTime: Date?
    private var pausedStartTime: Date?
    private var totalPausedDuration: TimeInterval = 0
    
    // MARK: - Asset Writers
    
    private var frontAssetWriter: AVAssetWriter?
    private var backAssetWriter: AVAssetWriter?
    private var compositeAssetWriter: AVAssetWriter?
    private var pictureInPictureAssetWriter: AVAssetWriter?
    
    // MARK: - Asset Writer Inputs
    
    private var frontVideoInput: AVAssetWriterInput?
    private var backVideoInput: AVAssetWriterInput?
    private var compositeVideoInput: AVAssetWriterInput?
    private var pictureInPictureVideoInput: AVAssetWriterInput?
    private var audioInput: AVAssetWriterInput?
    
    // MARK: - Recording URLs
    
    private var frontRecordingURL: URL?
    private var backRecordingURL: URL?
    private var compositeRecordingURL: URL?
    private var pictureInPictureRecordingURL: URL?
    
    // MARK: - Recording Options
    
    private var recordingOutputs: Set<RecordingOutput> = [.front, .back]
    private var videoCompositionMode: VideoCompositionMode = .sideBySide
    
    // MARK: - Event Stream
    
    let events: AsyncStream<VideoRecorderEvent>
    private let eventContinuation: AsyncStream<VideoRecorderEvent>.Continuation
    
    // MARK: - Performance Monitoring
    
    private var recordingMetrics: VideoRecordingMetrics = VideoRecordingMetrics()
    private var frameCounters: [CameraPosition: Int] = [:]
    private var droppedFrameCounters: [CameraPosition: Int] = [:]
    
    // MARK: - Initialization
    
    init(configuration: CameraConfiguration) {
        self.configuration = configuration
        
        (self.events, self.eventContinuation) = AsyncStream<VideoRecorderEvent>.makeStream()
        
        // Initialize frame counters
        frameCounters[.front] = 0
        frameCounters[.back] = 0
        droppedFrameCounters[.front] = 0
        droppedFrameCounters[.back] = 0
    }
    
    // MARK: - Public Interface
    
    func startRecording() async throws -> RecordingSession {
        guard !isRecording else {
            throw VideoRecorderError.alreadyRecording
        }
        
        // Create recording session
        recordingSession = RecordingSession(configuration: configuration)
        recordingStartTime = Date()
        
        // Generate recording URLs
        try await generateRecordingURLs()
        
        // Create asset writers
        try await createAssetWriters()
        
        // Start recording sessions
        try await startRecordingSessions()
        
        isRecording = true
        isPaused = false
        
        eventContinuation.yield(.recordingStarted(recordingSession!))
        
        return recordingSession!
    }
    
    func stopRecording() async throws -> RecordingSession {
        guard isRecording else {
            throw VideoRecorderError.notRecording
        }
        
        isRecording = false
        
        // Calculate final duration
        let finalDuration = calculateRecordingDuration()
        
        // Finish recording
        try await finishRecording()
        
        // Update session
        recordingSession?.updateState(.stopped)
        recordingSession?.endTime = Date()
        
        eventContinuation.yield(.recordingStopped(recordingSession!))
        
        let session = recordingSession!
        recordingSession = nil
        
        return session
    }
    
    func pauseRecording() async throws {
        guard isRecording && !isPaused else {
            throw VideoRecorderError.invalidState
        }
        
        isPaused = true
        pausedStartTime = Date()
        
        // Note: AVAssetWriter doesn't have pause/resume methods
        // Pausing is handled by tracking time intervals
        
        eventContinuation.yield(.recordingPaused)
    }
    
    func resumeRecording() async throws {
        guard isRecording && isPaused else {
            throw VideoRecorderError.invalidState
        }
        
        isPaused = false
        if let pausedStart = pausedStartTime {
            totalPausedDuration += Date().timeIntervalSince(pausedStart)
        }
        pausedStartTime = nil
        
        // Note: AVAssetWriter doesn't have pause/resume methods
        // Resuming is handled by tracking time intervals
        
        eventContinuation.yield(.recordingResumed)
    }
    
    func processVideoFrame(_ frame: DualCameraFrame) async {
        guard isRecording && !isPaused else { return }
        
        // Update frame counter
        frameCounters[frame.position, default: 0] += 1
        
        // Process frame for each enabled output
        if recordingOutputs.contains(.front) && frame.position == .front {
            await processFrontCameraFrame(frame)
        }
        
        if recordingOutputs.contains(.back) && frame.position == .back {
            await processBackCameraFrame(frame)
        }
        
        if recordingOutputs.contains(.composite) {
            await processCompositeFrame(frame)
        }
        
        if recordingOutputs.contains(.pictureInPicture) {
            await processPictureInPictureFrame(frame)
        }
    }
    
    func processAudioFrame(_ sampleBuffer: CMSampleBuffer) async {
        guard isRecording && !isPaused else { return }
        
        do {
            try await writeAudioFrame(sampleBuffer)
        } catch {
            eventContinuation.yield(.error(VideoRecorderError.audioProcessingFailed(error)))
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
        guard let session = recordingSession else {
            return .idle
        }
        
        return session.state
    }
    
    // MARK: - Private Methods
    
    private func generateRecordingURLs() async throws {
        let timestamp = Int(Date().timeIntervalSince1970)
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        
        if recordingOutputs.contains(.front) {
            frontRecordingURL = documentsPath.appendingPathComponent("front_\(timestamp).\(configuration.outputFormat.rawValue.lowercased())")
        }
        
        if recordingOutputs.contains(.back) {
            backRecordingURL = documentsPath.appendingPathComponent("back_\(timestamp).\(configuration.outputFormat.rawValue.lowercased())")
        }
        
        if recordingOutputs.contains(.composite) {
            compositeRecordingURL = documentsPath.appendingPathComponent("composite_\(timestamp).\(configuration.outputFormat.rawValue.lowercased())")
        }
        
        if recordingOutputs.contains(.pictureInPicture) {
            pictureInPictureRecordingURL = documentsPath.appendingPathComponent("pip_\(timestamp).\(configuration.outputFormat.rawValue.lowercased())")
        }
    }
    
    private func createAssetWriters() async throws {
        // Create front camera asset writer
        if recordingOutputs.contains(.front), let frontURL = frontRecordingURL {
            frontAssetWriter = try AVAssetWriter(outputURL: frontURL, fileType: configuration.outputFormat.avFileType)
            try await createFrontVideoInput()
        }
        
        // Create back camera asset writer
        if recordingOutputs.contains(.back), let backURL = backRecordingURL {
            backAssetWriter = try AVAssetWriter(outputURL: backURL, fileType: configuration.outputFormat.avFileType)
            try await createBackVideoInput()
        }
        
        // Create composite asset writer
        if recordingOutputs.contains(.composite), let compositeURL = compositeRecordingURL {
            compositeAssetWriter = try AVAssetWriter(outputURL: compositeURL, fileType: configuration.outputFormat.avFileType)
            try await createCompositeVideoInput()
        }
        
        // Create picture-in-picture asset writer
        if recordingOutputs.contains(.pictureInPicture), let pipURL = pictureInPictureRecordingURL {
            pictureInPictureAssetWriter = try AVAssetWriter(outputURL: pipURL, fileType: configuration.outputFormat.avFileType)
            try await createPictureInPictureVideoInput()
        }
        
        // Create audio input for composite and pip recordings
        if recordingOutputs.contains(.composite) || recordingOutputs.contains(.pictureInPicture) {
            try await createAudioInput()
        }
    }
    
    private func createFrontVideoInput() async throws {
        guard let frontWriter = frontAssetWriter else { return }
        
        let videoSettings: [String: Any] = [
            AVVideoCodecKey: configuration.outputFormat.codec,
            AVVideoWidthKey: configuration.quality.dimensions.width,
            AVVideoHeightKey: configuration.quality.dimensions.height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: configuration.quality.bitRate,
                AVVideoExpectedSourceFrameRateKey: configuration.frameRate,
                AVVideoMaxKeyFrameIntervalKey: configuration.keyFrameInterval
            ]
        ]
        
        frontVideoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        frontVideoInput?.expectsMediaDataInRealTime = true
        
        if frontWriter.canAdd(frontVideoInput!) {
            frontWriter.add(frontVideoInput!)
        }
    }
    
    private func createBackVideoInput() async throws {
        guard let backWriter = backAssetWriter else { return }
        
        let videoSettings: [String: Any] = [
            AVVideoCodecKey: configuration.outputFormat.codec,
            AVVideoWidthKey: configuration.quality.dimensions.width,
            AVVideoHeightKey: configuration.quality.dimensions.height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: configuration.quality.bitRate,
                AVVideoExpectedSourceFrameRateKey: configuration.frameRate,
                AVVideoMaxKeyFrameIntervalKey: configuration.keyFrameInterval
            ]
        ]
        
        backVideoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        backVideoInput?.expectsMediaDataInRealTime = true
        
        if backWriter.canAdd(backVideoInput!) {
            backWriter.add(backVideoInput!)
        }
    }
    
    private func createCompositeVideoInput() async throws {
        guard let compositeWriter = compositeAssetWriter else { return }
        
        let compositeSize = getCompositeSize()
        
        let videoSettings: [String: Any] = [
            AVVideoCodecKey: configuration.outputFormat.codec,
            AVVideoWidthKey: compositeSize.width,
            AVVideoHeightKey: compositeSize.height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: configuration.quality.bitRate * 2,
                AVVideoExpectedSourceFrameRateKey: configuration.frameRate,
                AVVideoMaxKeyFrameIntervalKey: configuration.keyFrameInterval
            ]
        ]
        
        compositeVideoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        compositeVideoInput?.expectsMediaDataInRealTime = true
        
        if compositeWriter.canAdd(compositeVideoInput!) {
            compositeWriter.add(compositeVideoInput!)
        }
    }
    
    private func createPictureInPictureVideoInput() async throws {
        guard let pipWriter = pictureInPictureAssetWriter else { return }
        
        let videoSettings: [String: Any] = [
            AVVideoCodecKey: configuration.outputFormat.codec,
            AVVideoWidthKey: configuration.quality.dimensions.width,
            AVVideoHeightKey: configuration.quality.dimensions.height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: configuration.quality.bitRate,
                AVVideoExpectedSourceFrameRateKey: configuration.frameRate,
                AVVideoMaxKeyFrameIntervalKey: configuration.keyFrameInterval
            ]
        ]
        
        pictureInPictureVideoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        pictureInPictureVideoInput?.expectsMediaDataInRealTime = true
        
        if pipWriter.canAdd(pictureInPictureVideoInput!) {
            pipWriter.add(pictureInPictureVideoInput!)
        }
    }
    
    private func createAudioInput() async throws {
        guard configuration.audioEnabled else { return }
        
        let audioSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVNumberOfChannelsKey: configuration.audioQuality.channels,
            AVSampleRateKey: configuration.audioQuality.sampleRate,
            AVEncoderBitRateKey: configuration.audioQuality.bitRate
        ]
        
        audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
        audioInput?.expectsMediaDataInRealTime = true
        
        // Add to appropriate writers
        if recordingOutputs.contains(.composite), let compositeWriter = compositeAssetWriter {
            if compositeWriter.canAdd(audioInput!) {
                compositeWriter.add(audioInput!)
            }
        }
        
        if recordingOutputs.contains(.pictureInPicture), let pipWriter = pictureInPictureAssetWriter {
            // Create a separate audio input for pip writer
            let pipAudioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
            pipAudioInput.expectsMediaDataInRealTime = true
            
            if pipWriter.canAdd(pipAudioInput) {
                pipWriter.add(pipAudioInput)
            }
        }
    }
    
    private func startRecordingSessions() async throws {
        let startTime = CMTime.zero
        
        // Start front camera recording
        if let frontWriter = frontAssetWriter {
            frontWriter.startWriting()
            frontWriter.startSession(atSourceTime: startTime)
        }
        
        // Start back camera recording
        if let backWriter = backAssetWriter {
            backWriter.startWriting()
            backWriter.startSession(atSourceTime: startTime)
        }
        
        // Start composite recording
        if let compositeWriter = compositeAssetWriter {
            compositeWriter.startWriting()
            compositeWriter.startSession(atSourceTime: startTime)
        }
        
        // Start picture-in-picture recording
        if let pipWriter = pictureInPictureAssetWriter {
            pipWriter.startWriting()
            pipWriter.startSession(atSourceTime: startTime)
        }
    }
    
    private func processFrontCameraFrame(_ frame: DualCameraFrame) async {
        guard let frontInput = frontVideoInput, frontInput.isReadyForMoreMediaData else {
            droppedFrameCounters[.front, default: 0] += 1
            return
        }
        
        if let sampleBuffer = createSampleBuffer(from: frame) {
            frontInput.append(sampleBuffer)
        }
    }
    
    private func processBackCameraFrame(_ frame: DualCameraFrame) async {
        guard let backInput = backVideoInput, backInput.isReadyForMoreMediaData else {
            droppedFrameCounters[.back, default: 0] += 1
            return
        }
        
        if let sampleBuffer = createSampleBuffer(from: frame) {
            backInput.append(sampleBuffer)
        }
    }
    
    private func processCompositeFrame(_ frame: DualCameraFrame) async {
        guard let compositeInput = compositeVideoInput, compositeInput.isReadyForMoreMediaData else {
            return
        }
        
        // Create composite frame based on composition mode
        if let compositeSampleBuffer = createCompositeSampleBuffer(from: frame) {
            compositeInput.append(compositeSampleBuffer)
        }
    }
    
    private func processPictureInPictureFrame(_ frame: DualCameraFrame) async {
        guard let pipInput = pictureInPictureVideoInput, pipInput.isReadyForMoreMediaData else {
            return
        }
        
        // Create picture-in-picture frame
        if let pipSampleBuffer = createPictureInPictureSampleBuffer(from: frame) {
            pipInput.append(pipSampleBuffer)
        }
    }
    
    private func writeAudioFrame(_ sampleBuffer: CMSampleBuffer) async throws {
        guard let audioInput = audioInput, audioInput.isReadyForMoreMediaData else {
            throw VideoRecorderError.audioInputNotReady
        }
        
        audioInput.append(sampleBuffer)
    }
    
    private func createSampleBuffer(from frame: DualCameraFrame) -> CMSampleBuffer? {
        // Create sample buffer from frame
        // This would convert the frame's pixel buffer to a sample buffer
        return nil // Placeholder
    }
    
    private func createCompositeSampleBuffer(from frame: DualCameraFrame) -> CMSampleBuffer? {
        // Create composite sample buffer based on composition mode
        switch videoCompositionMode {
        case .sideBySide:
            return createSideBySideSampleBuffer(from: frame)
        case .pictureInPicture:
            return createPictureInPictureSampleBuffer(from: frame)
        case .splitScreen:
            return createSplitScreenSampleBuffer(from: frame)
        case .overlay:
            return createOverlaySampleBuffer(from: frame)
        }
    }
    
    private func createSideBySideSampleBuffer(from frame: DualCameraFrame) -> CMSampleBuffer? {
        // Create side-by-side composite
        return nil // Placeholder
    }
    
    private func createPictureInPictureSampleBuffer(from frame: DualCameraFrame) -> CMSampleBuffer? {
        // Create picture-in-picture composite
        return nil // Placeholder
    }
    
    private func createSplitScreenSampleBuffer(from frame: DualCameraFrame) -> CMSampleBuffer? {
        // Create split-screen composite
        return nil // Placeholder
    }
    
    private func createOverlaySampleBuffer(from frame: DualCameraFrame) -> CMSampleBuffer? {
        // Create overlay composite
        return nil // Placeholder
    }
    
    private func getCompositeSize() -> CGSize {
        switch videoCompositionMode {
        case .sideBySide:
            return CGSize(
                width: configuration.quality.dimensions.width * 2,
                height: configuration.quality.dimensions.height
            )
        case .pictureInPicture, .splitScreen, .overlay:
            return configuration.quality.dimensions
        }
    }
    
    private func finishRecording() async throws {
        // Mark inputs as finished
        frontVideoInput?.markAsFinished()
        backVideoInput?.markAsFinished()
        compositeVideoInput?.markAsFinished()
        pictureInPictureVideoInput?.markAsFinished()
        audioInput?.markAsFinished()
        
        // Finish writing
        frontAssetWriter?.finishWriting {}
        backAssetWriter?.finishWriting {}
        compositeAssetWriter?.finishWriting {}
        pictureInPictureAssetWriter?.finishWriting {}
        
        // Save to photo library if enabled
        if configuration.includeDeviceMetadata {
            try await saveRecordingsToPhotoLibrary()
        }
    }
    
    private func saveRecordingsToPhotoLibrary() async throws {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized else {
            throw VideoRecorderError.photoLibraryAccessDenied
        }
        
        // Save recordings to photo library
        if let frontURL = frontRecordingURL {
            try await saveVideoToPhotoLibrary(at: frontURL)
        }
        
        if let backURL = backRecordingURL {
            try await saveVideoToPhotoLibrary(at: backURL)
        }
        
        if let compositeURL = compositeRecordingURL {
            try await saveVideoToPhotoLibrary(at: compositeURL)
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
        
        if isPaused, let pausedStart = pausedStartTime {
            duration -= Date().timeIntervalSince(pausedStart)
        }
        
        return duration
    }
}

// MARK: - Supporting Types

enum VideoRecorderEvent: Sendable {
    case recordingStarted(RecordingSession)
    case recordingStopped(RecordingSession)
    case recordingPaused
    case recordingResumed
    case recordingOutputsChanged(Set<RecordingOutput>)
    case videoCompositionModeChanged(VideoCompositionMode)
    case error(VideoRecorderError)
}

enum VideoRecorderError: LocalizedError, Sendable {
    case alreadyRecording
    case notRecording
    case invalidState
    case audioInputNotReady
    case audioProcessingFailed(Error)
    case photoLibraryAccessDenied
    
    var errorDescription: String? {
        switch self {
        case .alreadyRecording:
            return "Recording is already in progress"
        case .notRecording:
            return "No recording is in progress"
        case .invalidState:
            return "Invalid recording state"
        case .audioInputNotReady:
            return "Audio input is not ready"
        case .audioProcessingFailed(let error):
            return "Audio processing failed: \(error.localizedDescription)"
        case .photoLibraryAccessDenied:
            return "Photo library access denied"
        }
    }
}

enum RecordingOutput: String, CaseIterable, Sendable {
    case front = "Front"
    case back = "Back"
    case composite = "Composite"
    case pictureInPicture = "Picture in Picture"
    
    var description: String {
        return rawValue
    }
    
    var icon: String {
        switch self {
        case .front:
            return "camera.fill"
        case .back:
            return "camera.rotate"
        case .composite:
            return "rectangle.split.2x1"
        case .pictureInPicture:
            return "rectangle.inset.filled"
        }
    }
}

enum VideoCompositionMode: String, CaseIterable, Sendable {
    case sideBySide = "Side by Side"
    case pictureInPicture = "Picture in Picture"
    case splitScreen = "Split Screen"
    case overlay = "Overlay"
    
    var description: String {
        return rawValue
    }
    
    var icon: String {
        switch self {
        case .sideBySide:
            return "rectangle.split.2x1"
        case .pictureInPicture:
            return "rectangle.inset.filled"
        case .splitScreen:
            return "rectangle.split.2x1.fill"
        case .overlay:
            return "rectangle.on.rectangle"
        }
    }
}

struct VideoRecordingMetrics: Sendable {
    var duration: TimeInterval = 0
    var frameCount: Int = 0
    var droppedFrameCount: Int = 0
    var frameDropRate: Double = 0
    var averageBitrate: Double = 0
    var fileSize: Int64 = 0
    
    var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    var formattedFrameDropRate: String {
        return String(format: "%.1f%%", frameDropRate * 100)
    }
    
    var formattedAverageBitrate: String {
        return String(format: "%.0f kbps", averageBitrate / 1000)
    }
    
    var formattedFileSize: String {
        return ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
    }
}