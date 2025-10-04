//
//  AudioVideoSyncCoordinator.swift
//  DualApp
//
//  Created by DualApp Team on 10/3/25.
//

import Foundation
@preconcurrency import AVFoundation
import CoreMedia

// MARK: - Audio Video Sync Coordinator

actor AudioVideoSyncCoordinator {
    // MARK: - State Properties
    
    private(set) var isSynchronizing = false
    private(set) var syncStatus: AudioVideoSyncStatus = .idle
    private(set) var currentDrift: TimeInterval = 0.0
    private(set) var currentLatency: TimeInterval = 0.0
    private(set) var syncQuality: AudioVideoSyncQuality = .excellent
    
    // MARK: - Synchronization Components
    
    private let audioClock: CMClock
    private let videoClock: CMClock
    private var masterClock: CMClock
    private var syncTimer: Timer?
    private var driftCorrectionEnabled = true
    private var lipSyncCompensationEnabled = true
    
    // MARK: - Buffer Management
    
    private var audioBufferQueue: AudioBufferQueue
    private var videoBufferQueue: VideoBufferQueue
    private var maxBufferSize: Int = 30
    private var targetLatency: TimeInterval = 0.1 // 100ms
    
    // MARK: - Sync Metrics
    
    private var syncMetrics: AudioVideoSyncMetrics
    private var driftHistory: [TimeInterval] = []
    private var latencyHistory: [TimeInterval] = []
    private var syncQualityHistory: [AudioVideoSyncQuality] = []
    
    // MARK: - Event Streams
    
    let syncEvents: AsyncStream<AudioVideoSyncEvent>
    private let syncContinuation: AsyncStream<AudioVideoSyncEvent>.Continuation
    
    // MARK: - Configuration
    
    private let configuration: AudioVideoSyncConfiguration
    
    // MARK: - Initialization
    
    init(configuration: AudioVideoSyncConfiguration = .default) {
        self.configuration = configuration
        self.audioClock = CMClockGetHostTimeClock()
        self.videoClock = CMClockGetHostTimeClock()
        self.masterClock = CMClockGetHostTimeClock()
        self.audioBufferQueue = AudioBufferQueue(maxSize: configuration.maxAudioBufferSize)
        self.videoBufferQueue = VideoBufferQueue(maxSize: configuration.maxVideoBufferSize)
        self.syncMetrics = AudioVideoSyncMetrics()
        
        (syncEvents, syncContinuation) = AsyncStream.makeStream()
        
        Task {
            await initializeSyncCoordinator()
        }
    }
    
    // MARK: - Public Interface
    
    func startSynchronization() async throws {
        guard !isSynchronizing else {
            throw AudioError.synchronizationFailed("Already synchronizing")
        }
        
        isSynchronizing = true
        syncStatus = .synchronizing
        
        // Start sync timer
        await startSyncTimer()
        
        // Send sync started event
        let event = AudioVideoSyncEvent(
            type: .synchronizationStarted,
            timestamp: Date(),
            metrics: syncMetrics
        )
        syncContinuation.yield(event)
    }
    
    func stopSynchronization() async {
        guard isSynchronizing else { return }
        
        isSynchronizing = false
        syncStatus = .stopped
        
        // Stop sync timer
        await stopSyncTimer()
        
        // Clear buffers
        await clearBuffers()
        
        // Send sync stopped event
        let event = AudioVideoSyncEvent(
            type: .synchronizationStopped,
            timestamp: Date(),
            metrics: syncMetrics
        )
        syncContinuation.yield(event)
    }
    
    func addAudioBuffer(_ buffer: AVAudioPCMBuffer, at time: CMTime) async {
        guard isSynchronizing else { return }
        
        let audioFrame = AudioFrame(
            buffer: buffer,
            timestamp: time,
            clockTime: audioClock.time
        )
        
        await audioBufferQueue.add(audioFrame)
        
        // Process synchronization
        await processSynchronization()
    }
    
    func addVideoBuffer(_ buffer: CVPixelBuffer, at time: CMTime) async {
        guard isSynchronizing else { return }
        
        let videoFrame = VideoFrame(
            buffer: buffer,
            timestamp: time,
            clockTime: videoClock.time
        )
        
        await videoBufferQueue.add(videoFrame)
        
        // Process synchronization
        await processSynchronization()
    }
    
    func addAudioSampleBuffer(_ sampleBuffer: CMSampleBuffer) async {
        guard isSynchronizing else { return }
        
        let presentationTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        
        // Convert to PCM buffer
        if let pcmBuffer = createPCMBuffer(from: sampleBuffer) {
            await addAudioBuffer(pcmBuffer, at: presentationTime)
        }
    }
    
    func addVideoSampleBuffer(_ sampleBuffer: CMSampleBuffer) async {
        guard isSynchronizing else { return }
        
        let presentationTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        
        if let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
            await addVideoBuffer(pixelBuffer, at: presentationTime)
        }
    }
    
    func setTargetLatency(_ latency: TimeInterval) async {
        targetLatency = max(0.01, min(latency, 0.5)) // 10ms to 500ms
    }
    
    func enableDriftCorrection(_ enabled: Bool) async {
        driftCorrectionEnabled = enabled
    }
    
    func enableLipSyncCompensation(_ enabled: Bool) async {
        lipSyncCompensationEnabled = enabled
    }
    
    func setMasterClock(_ clock: CMClock) async {
        masterClock = clock
    }
    
    func getSyncMetrics() async -> AudioVideoSyncMetrics {
        return syncMetrics
    }
    
    func getSyncQuality() async -> AudioVideoSyncQuality {
        return syncQuality
    }
    
    func getCurrentDrift() async -> TimeInterval {
        return currentDrift
    }
    
    func getCurrentLatency() async -> TimeInterval {
        return currentLatency
    }
    
    func getSynchronizedBuffers() async -> (audio: AudioFrame?, video: VideoFrame?) {
        return await getSynchronizedAudioVideoBuffers()
    }
    
    func forceResynchronization() async {
        await performResynchronization()
    }
    
    // MARK: - Private Methods
    
    private func initializeSyncCoordinator() async {
        // Initialize synchronization parameters
        targetLatency = configuration.targetLatency
        driftCorrectionEnabled = configuration.driftCorrectionEnabled
        lipSyncCompensationEnabled = configuration.lipSyncCompensationEnabled
        
        // Set master clock
        masterClock = configuration.masterClock ?? CMClockGetHostTimeClock()
    }
    
    private func startSyncTimer() async {
        syncTimer = Timer.scheduledTimer(withTimeInterval: configuration.syncInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.performSyncCycle()
            }
        }
    }
    
    private func stopSyncTimer() async {
        syncTimer?.invalidate()
        syncTimer = nil
    }
    
    private func performSyncCycle() async {
        guard isSynchronizing else { return }
        
        // Calculate current drift
        await calculateDrift()
        
        // Calculate current latency
        await calculateLatency()
        
        // Apply drift correction if needed
        if driftCorrectionEnabled {
            await applyDriftCorrection()
        }
        
        // Apply lip-sync compensation if needed
        if lipSyncCompensationEnabled {
            await applyLipSyncCompensation()
        }
        
        // Update sync quality
        await updateSyncQuality()
        
        // Update metrics
        await updateSyncMetrics()
        
        // Send sync update event
        let event = AudioVideoSyncEvent(
            type: .synchronizationUpdate,
            timestamp: Date(),
            metrics: syncMetrics,
            drift: currentDrift,
            latency: currentLatency,
            quality: syncQuality
        )
        syncContinuation.yield(event)
    }
    
    private func processSynchronization() async {
        guard isSynchronizing else { return }
        
        // Check if we have both audio and video buffers
        let audioCount = await audioBufferQueue.count
        let videoCount = await videoBufferQueue.count
        
        guard audioCount > 0 && videoCount > 0 else { return }
        
        // Get synchronized buffers
        let (audioFrame, videoFrame) = await getSynchronizedAudioVideoBuffers()
        
        // Send synchronized buffers event
        if let audio = audioFrame, let video = videoFrame {
            let event = AudioVideoSyncEvent(
                type: .buffersSynchronized,
                timestamp: Date(),
                audioFrame: audio,
                videoFrame: video
            )
            syncContinuation.yield(event)
        }
    }
    
    private func getSynchronizedAudioVideoBuffers() async -> (AudioFrame?, VideoFrame?) {
        let audioFrame = await audioBufferQueue.peek()
        let videoFrame = await videoBufferQueue.peek()
        
        guard let audio = audioFrame, let video = videoFrame else {
            return (nil, nil)
        }
        
        // Calculate time difference
        let timeDiff = CMTimeGetSeconds(audio.timestamp) - CMTimeGetSeconds(video.timestamp)
        
        // Check if buffers are synchronized within tolerance
        let tolerance = configuration.syncTolerance
        
        if abs(timeDiff) <= tolerance {
            // Buffers are synchronized
            _ = await audioBufferQueue.remove()
            _ = await videoBufferQueue.remove()
            return (audio, video)
        } else if timeDiff > tolerance {
            // Audio is ahead, drop video frame
            _ = await videoBufferQueue.remove()
            return await getSynchronizedAudioVideoBuffers()
        } else {
            // Video is ahead, drop audio frame
            _ = await audioBufferQueue.remove()
            return await getSynchronizedAudioVideoBuffers()
        }
    }
    
    private func calculateDrift() async {
        let audioCount = await audioBufferQueue.count
        let videoCount = await videoBufferQueue.count
        
        guard audioCount > 0 && videoCount > 0 else {
            currentDrift = 0.0
            return
        }
        
        let audioFrame = await audioBufferQueue.peek()
        let videoFrame = await videoBufferQueue.peek()
        
        guard let audio = audioFrame, let video = videoFrame else {
            currentDrift = 0.0
            return
        }
        
        // Calculate drift between audio and video
        let audioTime = CMTimeGetSeconds(audio.timestamp)
        let videoTime = CMTimeGetSeconds(video.timestamp)
        currentDrift = audioTime - videoTime
        
        // Add to history
        driftHistory.append(currentDrift)
        if driftHistory.count > 100 {
            driftHistory.removeFirst()
        }
    }
    
    private func calculateLatency() async {
        let audioCount = await audioBufferQueue.count
        let videoCount = await videoBufferQueue.count
        
        guard audioCount > 0 && videoCount > 0 else {
            currentLatency = 0.0
            return
        }
        
        // Calculate average buffer age
        let audioLatency = await calculateAverageBufferLatency(for: .audio)
        let videoLatency = await calculateAverageBufferLatency(for: .video)
        
        currentLatency = (audioLatency + videoLatency) / 2.0
        
        // Add to history
        latencyHistory.append(currentLatency)
        if latencyHistory.count > 100 {
            latencyHistory.removeFirst()
        }
    }
    
    private func calculateAverageBufferLatency(for type: BufferType) async -> TimeInterval {
        let currentTime = CMClockGetTime(masterClock)
        
        switch type {
        case .audio:
            let audioFrame = await audioBufferQueue.peek()
            guard let audio = audioFrame else { return 0.0 }
            return CMTimeGetSeconds(currentTime) - CMTimeGetSeconds(audio.clockTime)
            
        case .video:
            let videoFrame = await videoBufferQueue.peek()
            guard let video = videoFrame else { return 0.0 }
            return CMTimeGetSeconds(currentTime) - CMTimeGetSeconds(video.clockTime)
        }
    }
    
    private func applyDriftCorrection() async {
        guard abs(currentDrift) > configuration.driftThreshold else { return }
        
        // Calculate correction amount
        let correctionAmount = min(abs(currentDrift), configuration.maxDriftCorrection)
        let correctionDirection = currentDrift > 0 ? 1.0 : -1.0
        
        // Apply correction by adjusting buffer queues
        if currentDrift > 0 {
            // Audio is ahead, drop audio frames
            let framesToDrop = Int(correctionAmount / (1.0 / 30.0))
            for _ in 0..<framesToDrop {
                _ = await audioBufferQueue.remove()
            }
        } else {
            // Video is ahead, drop video frames
            let framesToDrop = Int(correctionAmount / (1.0 / 30.0))
            for _ in 0..<framesToDrop {
                _ = await videoBufferQueue.remove()
            }
        }
        
        // Send drift correction event
        let event = AudioVideoSyncEvent(
            type: .driftCorrected,
            timestamp: Date(),
            drift: currentDrift,
            correctionApplied: correctionAmount * correctionDirection
        )
        syncContinuation.yield(event)
    }
    
    private func applyLipSyncCompensation() async {
        guard abs(currentDrift) > configuration.lipSyncThreshold else { return }
        
        // Calculate lip-sync delay
        let lipSyncDelay = min(abs(currentDrift), configuration.maxLipSyncDelay)
        
        // Apply compensation by adjusting target latency
        let newTargetLatency = targetLatency + lipSyncDelay
        await setTargetLatency(newTargetLatency)
        
        // Send lip-sync compensation event
        let event = AudioVideoSyncEvent(
            type: .lipSyncCompensated,
            timestamp: Date(),
            drift: currentDrift,
            compensationApplied: lipSyncDelay
        )
        syncContinuation.yield(event)
    }
    
    private func updateSyncQuality() async {
        let quality = calculateSyncQuality()
        syncQuality = quality
        
        // Add to history
        syncQualityHistory.append(quality)
        if syncQualityHistory.count > 100 {
            syncQualityHistory.removeFirst()
        }
    }
    
    private func calculateSyncQuality() -> AudioVideoSyncQuality {
        let driftScore = calculateDriftScore()
        let latencyScore = calculateLatencyScore()
        let stabilityScore = calculateStabilityScore()
        
        let overallScore = (driftScore + latencyScore + stabilityScore) / 3.0
        
        switch overallScore {
        case 0.8...1.0:
            return .excellent
        case 0.6..<0.8:
            return .good
        case 0.4..<0.6:
            return .fair
        case 0.2..<0.4:
            return .poor
        default:
            return .terrible
        }
    }
    
    private func calculateDriftScore() -> Float {
        let maxAcceptableDrift: Float = 0.04 // 40ms
        let normalizedDrift = min(abs(Float(currentDrift)) / maxAcceptableDrift, 1.0)
        return 1.0 - normalizedDrift
    }
    
    private func calculateLatencyScore() -> Float {
        let maxAcceptableLatency: Float = 0.2 // 200ms
        let normalizedLatency = min(Float(currentLatency) / maxAcceptableLatency, 1.0)
        return 1.0 - normalizedLatency
    }
    
    private func calculateStabilityScore() -> Float {
        guard driftHistory.count >= 10 else { return 1.0 }
        
        let recentDrifts = Array(driftHistory.suffix(10))
        let average = recentDrifts.reduce(0, +) / Double(recentDrifts.count)
        let variance = recentDrifts.map { pow($0 - average, 2) }.reduce(0, +) / Double(recentDrifts.count)
        let standardDeviation = sqrt(variance)
        
        let maxAcceptableDeviation: Float = 0.02 // 20ms
        let normalizedDeviation = min(Float(standardDeviation) / maxAcceptableDeviation, 1.0)
        return 1.0 - normalizedDeviation
    }
    
    private func updateSyncMetrics() async {
        syncMetrics.currentDrift = currentDrift
        syncMetrics.currentLatency = currentLatency
        syncMetrics.syncQuality = syncQuality
        syncMetrics.audioBufferSize = await audioBufferQueue.count
        syncMetrics.videoBufferSize = await videoBufferQueue.count
        syncMetrics.targetLatency = targetLatency
        syncMetrics.lastUpdateTime = Date()
        
        // Calculate averages
        if !driftHistory.isEmpty {
            syncMetrics.averageDrift = driftHistory.reduce(0, +) / Double(driftHistory.count)
        }
        
        if !latencyHistory.isEmpty {
            syncMetrics.averageLatency = latencyHistory.reduce(0, +) / Double(latencyHistory.count)
        }
        
        // Calculate drop rates
        syncMetrics.audioDropRate = await audioBufferQueue.dropRate
        syncMetrics.videoDropRate = await videoBufferQueue.dropRate
    }
    
    private func performResynchronization() async {
        // Clear all buffers
        await clearBuffers()
        
        // Reset metrics
        currentDrift = 0.0
        currentLatency = 0.0
        driftHistory.removeAll()
        latencyHistory.removeAll()
        syncQualityHistory.removeAll()
        
        // Send resynchronization event
        let event = AudioVideoSyncEvent(
            type: .resynchronization,
            timestamp: Date(),
            metrics: syncMetrics
        )
        syncContinuation.yield(event)
    }
    
    private func clearBuffers() async {
        await audioBufferQueue.clear()
        await videoBufferQueue.clear()
    }
    
    private func createPCMBuffer(from sampleBuffer: CMSampleBuffer) -> AVAudioPCMBuffer? {
        guard let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer) else {
            return nil
        }
        
        let format = AVAudioFormat(cmAudioFormatDescription: formatDescription)
        
        let frameCount = CMSampleBufferGetNumSamples(sampleBuffer)
        guard let pcmBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frameCount)) else {
            return nil
        }
        
        pcmBuffer.frameLength = AVAudioFrameCount(frameCount)
        
        let status = CMSampleBufferCopyPCMDataIntoAudioBufferList(
            sampleBuffer,
            at: 0,
            frameCount: Int32(frameCount),
            into: pcmBuffer.mutableAudioBufferList
        )

        guard status == noErr else {
            return nil
        }
        
        return pcmBuffer
    }
}

// MARK: - Supporting Types

enum BufferType {
    case audio
    case video
}

enum AudioVideoSyncStatus: String, CaseIterable, Sendable {
    case idle = "idle"
    case synchronizing = "synchronizing"
    case synchronized = "synchronized"
    case stopped = "stopped"
    case error = "error"
    
    var displayName: String {
        switch self {
        case .idle:
            return "Idle"
        case .synchronizing:
            return "Synchronizing"
        case .synchronized:
            return "Synchronized"
        case .stopped:
            return "Stopped"
        case .error:
            return "Error"
        }
    }
}

enum AudioVideoSyncQuality: String, CaseIterable, Sendable {
    case excellent = "excellent"
    case good = "good"
    case fair = "fair"
    case poor = "poor"
    case terrible = "terrible"
    
    var displayName: String {
        switch self {
        case .excellent:
            return "Excellent"
        case .good:
            return "Good"
        case .fair:
            return "Fair"
        case .poor:
            return "Poor"
        case .terrible:
            return "Terrible"
        }
    }
    
    var score: Float {
        switch self {
        case .excellent:
            return 1.0
        case .good:
            return 0.8
        case .fair:
            return 0.6
        case .poor:
            return 0.4
        case .terrible:
            return 0.2
        }
    }
}

struct AudioVideoSyncConfiguration: Sendable {
    let targetLatency: TimeInterval
    let syncTolerance: TimeInterval
    let driftThreshold: TimeInterval
    let maxDriftCorrection: TimeInterval
    let lipSyncThreshold: TimeInterval
    let maxLipSyncDelay: TimeInterval
    let syncInterval: TimeInterval
    let maxAudioBufferSize: Int
    let maxVideoBufferSize: Int
    let driftCorrectionEnabled: Bool
    let lipSyncCompensationEnabled: Bool
    let masterClock: CMClock?
    
    static let `default` = AudioVideoSyncConfiguration(
        targetLatency: 0.1,
        syncTolerance: 0.02,
        driftThreshold: 0.04,
        maxDriftCorrection: 0.1,
        lipSyncThreshold: 0.03,
        maxLipSyncDelay: 0.05,
        syncInterval: 0.016, // 60fps
        maxAudioBufferSize: 30,
        maxVideoBufferSize: 30,
        driftCorrectionEnabled: true,
        lipSyncCompensationEnabled: true,
        masterClock: nil
    )
    
    static let lowLatency = AudioVideoSyncConfiguration(
        targetLatency: 0.05,
        syncTolerance: 0.01,
        driftThreshold: 0.02,
        maxDriftCorrection: 0.05,
        lipSyncThreshold: 0.015,
        maxLipSyncDelay: 0.025,
        syncInterval: 0.008, // 120fps
        maxAudioBufferSize: 15,
        maxVideoBufferSize: 15,
        driftCorrectionEnabled: true,
        lipSyncCompensationEnabled: true,
        masterClock: nil
    )
    
    static let highQuality = AudioVideoSyncConfiguration(
        targetLatency: 0.2,
        syncTolerance: 0.04,
        driftThreshold: 0.08,
        maxDriftCorrection: 0.2,
        lipSyncThreshold: 0.06,
        maxLipSyncDelay: 0.1,
        syncInterval: 0.033, // 30fps
        maxAudioBufferSize: 60,
        maxVideoBufferSize: 60,
        driftCorrectionEnabled: true,
        lipSyncCompensationEnabled: true,
        masterClock: nil
    )
}

struct AudioVideoSyncMetrics: Sendable {
    var currentDrift: TimeInterval = 0.0
    var currentLatency: TimeInterval = 0.0
    var averageDrift: TimeInterval = 0.0
    var averageLatency: TimeInterval = 0.0
    var syncQuality: AudioVideoSyncQuality = .excellent
    var audioBufferSize: Int = 0
    var videoBufferSize: Int = 0
    var audioDropRate: Float = 0.0
    var videoDropRate: Float = 0.0
    var targetLatency: TimeInterval = 0.1
    var lastUpdateTime: Date = Date()
    
    var overallScore: Float {
        let driftScore = max(0.0, 1.0 - abs(Float(currentDrift)) / 0.1)
        let latencyScore = max(0.0, 1.0 - Float(currentLatency) / 0.2)
        let qualityScore = syncQuality.score
        let bufferScore = max(0.0, 1.0 - Float(audioBufferSize + videoBufferSize) / 60.0)
        
        return (driftScore + latencyScore + qualityScore + bufferScore) / 4.0
    }
}

struct AudioVideoSyncEvent: Sendable {
    let type: AudioVideoSyncEventType
    let timestamp: Date
    let metrics: AudioVideoSyncMetrics?
    let drift: TimeInterval?
    let latency: TimeInterval?
    let quality: AudioVideoSyncQuality?
    let audioFrame: AudioFrame?
    let videoFrame: VideoFrame?
    let correctionApplied: TimeInterval?
    let compensationApplied: TimeInterval?
    
    init(
        type: AudioVideoSyncEventType,
        timestamp: Date = Date(),
        metrics: AudioVideoSyncMetrics? = nil,
        drift: TimeInterval? = nil,
        latency: TimeInterval? = nil,
        quality: AudioVideoSyncQuality? = nil,
        audioFrame: AudioFrame? = nil,
        videoFrame: VideoFrame? = nil,
        correctionApplied: TimeInterval? = nil,
        compensationApplied: TimeInterval? = nil
    ) {
        self.type = type
        self.timestamp = timestamp
        self.metrics = metrics
        self.drift = drift
        self.latency = latency
        self.quality = quality
        self.audioFrame = audioFrame
        self.videoFrame = videoFrame
        self.correctionApplied = correctionApplied
        self.compensationApplied = compensationApplied
    }
}

enum AudioVideoSyncEventType: String, CaseIterable, Sendable {
    case synchronizationStarted = "synchronizationStarted"
    case synchronizationStopped = "synchronizationStopped"
    case synchronizationUpdate = "synchronizationUpdate"
    case buffersSynchronized = "buffersSynchronized"
    case driftCorrected = "driftCorrected"
    case lipSyncCompensated = "lipSyncCompensated"
    case resynchronization = "resynchronization"
    case qualityChanged = "qualityChanged"
    case error = "error"
    
    var displayName: String {
        switch self {
        case .synchronizationStarted:
            return "Synchronization Started"
        case .synchronizationStopped:
            return "Synchronization Stopped"
        case .synchronizationUpdate:
            return "Synchronization Update"
        case .buffersSynchronized:
            return "Buffers Synchronized"
        case .driftCorrected:
            return "Drift Corrected"
        case .lipSyncCompensated:
            return "Lip-Sync Compensated"
        case .resynchronization:
            return "Resynchronization"
        case .qualityChanged:
            return "Quality Changed"
        case .error:
            return "Error"
        }
    }
}

struct AudioFrame: @unchecked Sendable {
    let buffer: AVAudioPCMBuffer
    let timestamp: CMTime
    let clockTime: CMTime
    let sequenceNumber: Int
    
    init(buffer: AVAudioPCMBuffer, timestamp: CMTime, clockTime: CMTime, sequenceNumber: Int = 0) {
        self.buffer = buffer
        self.timestamp = timestamp
        self.clockTime = clockTime
        self.sequenceNumber = sequenceNumber
    }
}

struct VideoFrame: @unchecked Sendable {
    let buffer: CVPixelBuffer
    let timestamp: CMTime
    let clockTime: CMTime
    let sequenceNumber: Int
    
    init(buffer: CVPixelBuffer, timestamp: CMTime, clockTime: CMTime, sequenceNumber: Int = 0) {
        self.buffer = buffer
        self.timestamp = timestamp
        self.clockTime = clockTime
        self.sequenceNumber = sequenceNumber
    }
}

// MARK: - Buffer Queues

actor AudioBufferQueue: Sendable {
    private var buffers: [AudioFrame] = []
    private let maxSize: Int
    private var droppedFrames: Int = 0
    private var totalFrames: Int = 0
    private var nextSequenceNumber: Int = 0
    
    init(maxSize: Int = 30) {
        self.maxSize = maxSize
    }
    
    func add(_ frame: AudioFrame) async {
        totalFrames += 1
        
        if buffers.count >= maxSize {
            buffers.removeFirst()
            droppedFrames += 1
        }
        
        var frame = frame
        frame = AudioFrame(
            buffer: frame.buffer,
            timestamp: frame.timestamp,
            clockTime: frame.clockTime,
            sequenceNumber: nextSequenceNumber
        )
        nextSequenceNumber += 1
        
        buffers.append(frame)
    }
    
    func peek() async -> AudioFrame? {
        return buffers.first
    }
    
    func remove() async -> AudioFrame? {
        return buffers.removeFirst()
    }
    
    func clear() async {
        buffers.removeAll()
    }
    
    var count: Int {
        return buffers.count
    }
    
    var dropRate: Float {
        guard totalFrames > 0 else { return 0.0 }
        return Float(droppedFrames) / Float(totalFrames)
    }
}

actor VideoBufferQueue: Sendable {
    private var buffers: [VideoFrame] = []
    private let maxSize: Int
    private var droppedFrames: Int = 0
    private var totalFrames: Int = 0
    private var nextSequenceNumber: Int = 0
    
    init(maxSize: Int = 30) {
        self.maxSize = maxSize
    }
    
    func add(_ frame: VideoFrame) async {
        totalFrames += 1
        
        if buffers.count >= maxSize {
            buffers.removeFirst()
            droppedFrames += 1
        }
        
        var frame = frame
        frame = VideoFrame(
            buffer: frame.buffer,
            timestamp: frame.timestamp,
            clockTime: frame.clockTime,
            sequenceNumber: nextSequenceNumber
        )
        nextSequenceNumber += 1
        
        buffers.append(frame)
    }
    
    func peek() async -> VideoFrame? {
        return buffers.first
    }
    
    func remove() async -> VideoFrame? {
        return buffers.removeFirst()
    }
    
    func clear() async {
        buffers.removeAll()
    }
    
    var count: Int {
        return buffers.count
    }
    
    var dropRate: Float {
        guard totalFrames > 0 else { return 0.0 }
        return Float(droppedFrames) / Float(totalFrames)
    }
}