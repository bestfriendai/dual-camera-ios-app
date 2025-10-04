//
//  AudioRecorder.swift
//  DualApp
//
//  Created by DualApp Team on 10/3/25.
//

import Foundation
import AVFoundation
import CoreMedia

// MARK: - Audio Recorder Actor

@MainActor
actor AudioRecorder: Sendable {
    // MARK: - State Properties
    
    private(set) var isRecording = false
    private(set) var isPaused = false
    private(set) var recordingURL: URL?
    private(set) var recordingDuration: TimeInterval = 0.0
    private(set) var configuration: AudioConfiguration = .default
    private(set) var recordingMetadata: AudioRecordingMetadata = AudioRecordingMetadata()
    private(set) var recordingStatistics: AudioRecordingStatistics = AudioRecordingStatistics()
    
    // MARK: - Recording Components
    
    private var audioFile: AVAudioFile?
    private var audioEngine: AVAudioEngine?
    private var inputNode: AVAudioInputNode?
    private var recordingTimer: Timer?
    private var formatConverter: AVAudioConverter?
    
    // MARK: - Buffer Management
    
    private var recordingQueue: DispatchQueue
    private var bufferQueue: [AVAudioPCMBuffer] = []
    private var maxBufferQueueSize: Int = 100
    private var isWritingBuffer = false
    
    // MARK: - Event Streams
    
    let recordingEvents: AsyncStream<AudioRecordingEvent>
    private let recordingContinuation: AsyncStream<AudioRecordingEvent>.Continuation
    
    // MARK: - Performance Monitoring
    
    private var droppedBuffers: Int = 0
    private var writtenBuffers: Int = 0
    private var lastBufferTime: CMTime = .zero
    
    // MARK: - Initialization
    
    init(configuration: AudioConfiguration = .default) {
        self.configuration = configuration
        self.recordingQueue = DispatchQueue(label: "audio.recording", qos: .userInteractive)
        
        (recordingEvents, recordingContinuation) = AsyncStream.makeStream()
        
        Task {
            await initializeRecorder()
        }
    }
    
    // MARK: - Public Interface
    
    func startRecording(to url: URL? = nil, configuration: AudioConfiguration? = nil) async throws -> URL {
        guard !isRecording else {
            throw AudioError.alreadyRecording
        }
        
        // Update configuration if provided
        if let config = configuration {
            self.configuration = config
        }
        
        // Generate recording URL if not provided
        let recordingURL = url ?? generateRecordingURL()
        self.recordingURL = recordingURL
        
        // Initialize recording metadata
        recordingMetadata = AudioRecordingMetadata(
            url: recordingURL,
            configuration: configuration,
            startTime: Date()
        )
        
        // Reset statistics
        recordingStatistics = AudioRecordingStatistics()
        
        do {
            // Setup audio engine
            try await setupAudioEngine()
            
            // Create audio file
            try await createAudioFile(at: recordingURL)
            
            // Setup format converter if needed
            try await setupFormatConverter()
            
            // Start recording timer
            await startRecordingTimer()
            
            // Start audio engine
            try audioEngine?.start()
            
            // Install input tap
            try await installInputTap()
            
            isRecording = true
            isPaused = false
            
            // Send recording started event
            let event = AudioRecordingEvent(
                type: .started,
                url: recordingURL,
                timestamp: Date()
            )
            recordingContinuation.yield(event)
            
            return recordingURL
            
        } catch {
            await cleanupRecording()
            throw AudioError.recordingFailed(error.localizedDescription)
        }
    }
    
    func stopRecording() async throws -> URL {
        guard isRecording, let url = recordingURL else {
            throw AudioError.notRecording
        }
        
        do {
            // Stop recording timer
            await stopRecordingTimer()
            
            // Remove input tap
            await removeInputTap()
            
            // Stop audio engine
            audioEngine?.stop()
            
            // Write any remaining buffers
            await writeRemainingBuffers()
            
            // Finalize audio file
            try await finalizeAudioFile()
            
            // Update metadata
            recordingMetadata.endTime = Date()
            recordingMetadata.duration = recordingDuration
            
            // Update statistics
            recordingStatistics.recordingDuration = recordingDuration
            recordingStatistics.totalBuffers = writtenBuffers
            recordingStatistics.droppedBuffers = droppedBuffers
            
            isRecording = false
            isPaused = false
            
            // Send recording stopped event
            let event = AudioRecordingEvent(
                type: .stopped,
                url: url,
                timestamp: Date(),
                metadata: recordingMetadata,
                statistics: recordingStatistics
            )
            recordingContinuation.yield(event)
            
            return url
            
        } catch {
            await cleanupRecording()
            throw AudioError.recordingFailed(error.localizedDescription)
        }
    }
    
    func pauseRecording() async throws {
        guard isRecording && !isPaused else {
            throw AudioError.invalidState("Cannot pause - not recording or already paused")
        }
        
        isPaused = true
        
        // Remove input tap but keep engine running
        await removeInputTap()
        
        // Send recording paused event
        let event = AudioRecordingEvent(
            type: .paused,
            url: recordingURL,
            timestamp: Date()
        )
        recordingContinuation.yield(event)
    }
    
    func resumeRecording() async throws {
        guard isRecording && isPaused else {
            throw AudioError.invalidState("Cannot resume - not recording or not paused")
        }
        
        isPaused = false
        
        // Reinstall input tap
        try await installInputTap()
        
        // Send recording resumed event
        let event = AudioRecordingEvent(
            type: .resumed,
            url: recordingURL,
            timestamp: Date()
        )
        recordingContinuation.yield(event)
    }
    
    func updateConfiguration(_ config: AudioConfiguration) async throws {
        guard !isRecording else {
            throw AudioError.invalidState("Cannot change configuration during recording")
        }
        
        configuration = config
    }
    
    func writeBuffer(_ buffer: AVAudioPCMBuffer) async throws {
        guard isRecording, !isPaused else {
            throw AudioError.notRecording
        }
        
        // Add buffer to queue
        await addToBufferQueue(buffer)
        
        // Process buffer queue
        await processBufferQueue()
    }
    
    func getRecordingMetadata() async -> AudioRecordingMetadata {
        return recordingMetadata
    }
    
    func getRecordingStatistics() async -> AudioRecordingStatistics {
        var stats = recordingStatistics
        stats.currentDuration = recordingDuration
        stats.averageLevel = recordingMetadata.averageLevel
        stats.peakLevel = recordingMetadata.peakLevel
        return stats
    }
    
    func setRecordingMetadata(_ metadata: AudioRecordingMetadata) async {
        recordingMetadata = metadata
    }
    
    func addMetadataTag(_ key: String, value: String) async {
        recordingMetadata.customTags[key] = value
    }
    
    // MARK: - Private Methods
    
    private func initializeRecorder() async {
        // Initialize recorder components
        audioEngine = AVAudioEngine()
    }
    
    private func setupAudioEngine() async throws {
        guard let audioEngine = audioEngine else {
            throw AudioError.hardwareUnavailable
        }
        
        inputNode = audioEngine.inputNode
        
        guard let inputNode = inputNode else {
            throw AudioError.recordingDeviceNotAvailable
        }
        
        // Configure input node
        let inputFormat = inputNode.outputFormat(forBus: 0)
        
        // Check if input format is compatible with configuration
        guard isFormatCompatible(inputFormat, with: configuration) else {
            throw AudioError.formatNotSupported
        }
    }
    
    private func createAudioFile(at url: URL) async throws {
        let settings = createAudioSettings(from: configuration)
        
        do {
            audioFile = try AVAudioFile(
                forWriting: url,
                settings: settings
            )
        } catch {
            throw AudioError.fileSystemError("Failed to create audio file: \(error.localizedDescription)")
        }
    }
    
    private func setupFormatConverter() async throws {
        guard let inputNode = inputNode else {
            throw AudioError.recordingDeviceNotAvailable
        }
        
        let inputFormat = inputNode.outputFormat(forBus: 0)
        let outputFormat = createOutputFormat(from: configuration)
        
        // Check if conversion is needed
        if inputFormat != outputFormat {
            formatConverter = AVAudioConverter(from: inputFormat, to: outputFormat)
            
            guard formatConverter != nil else {
                throw AudioError.formatConversionFailed
            }
        }
    }
    
    private func installInputTap() async throws {
        guard let inputNode = inputNode else {
            throw AudioError.recordingDeviceNotAvailable
        }
        
        let inputFormat = inputNode.outputFormat(forBus: 0)
        
        inputNode.installTap(
            onBus: 0,
            bufferSize: configuration.bufferSize,
            format: inputFormat
        ) { [weak self] buffer, time in
            Task { @MainActor in
                await self?.processInputBuffer(buffer, at: time)
            }
        }
    }
    
    private func removeInputTap() async {
        inputNode?.removeTap(onBus: 0)
    }
    
    private func processInputBuffer(_ buffer: AVAudioPCMBuffer, at time: CMTime) async {
        guard isRecording && !isPaused else { return }
        
        lastBufferTime = time
        
        // Update level metrics
        await updateLevelMetrics(from: buffer)
        
        // Add buffer to queue for writing
        await addToBufferQueue(buffer)
        
        // Process buffer queue
        await processBufferQueue()
    }
    
    private func updateLevelMetrics(from buffer: AVAudioPCMBuffer) async {
        let levels = AudioLevels.calculate(from: buffer)
        
        // Update metadata
        recordingMetadata.averageLevel = (recordingMetadata.averageLevel + levels.averagePower) / 2.0
        recordingMetadata.peakLevel = max(recordingMetadata.peakLevel, levels.peakPower)
        recordingMetadata.currentLevel = levels.averagePower
        
        // Update statistics
        recordingStatistics.currentLevel = levels.averagePower
        recordingStatistics.peakLevel = max(recordingStatistics.peakLevel, levels.peakPower)
    }
    
    private func addToBufferQueue(_ buffer: AVAudioPCMBuffer) async {
        bufferQueue.append(buffer)
        
        // Drop oldest buffers if queue is too large
        if bufferQueue.count > maxBufferQueueSize {
            bufferQueue.removeFirst()
            droppedBuffers += 1
        }
    }
    
    private func processBufferQueue() async {
        guard !isWritingBuffer && !bufferQueue.isEmpty else { return }
        
        isWritingBuffer = true
        
        recordingQueue.async { [weak self] in
            Task { @MainActor in
                await self?.writeBufferQueue()
            }
        }
    }
    
    private func writeBufferQueue() async {
        while !bufferQueue.isEmpty {
            let buffer = bufferQueue.removeFirst()
            
            do {
                try await writeBufferToFile(buffer)
                writtenBuffers += 1
            } catch {
                print("Failed to write buffer: \(error)")
            }
        }
        
        isWritingBuffer = false
    }
    
    private func writeBufferToFile(_ buffer: AVAudioPCMBuffer) async throws {
        guard let audioFile = audioFile else {
            throw AudioError.fileSystemError("Audio file not available")
        }
        
        var bufferToWrite = buffer
        
        // Apply format conversion if needed
        if let converter = formatConverter {
            let outputFormat = createOutputFormat(from: configuration)
            let convertedBuffer = AVAudioPCMBuffer(
                pcmFormat: outputFormat,
                frameCapacity: buffer.frameCapacity
            )!
            
            var error: NSError?
            let status = converter.convert(
                to: convertedBuffer,
                error: &error,
                withInputFrom: { inNumPackets, outStatus in
                    outStatus.pointee = .haveData
                    return buffer
                }
            )
            
            guard status == .error else {
                throw AudioError.formatConversionFailed
            }
            
            bufferToWrite = convertedBuffer
        }
        
        // Write buffer to file
        try audioFile.write(from: bufferToWrite)
    }
    
    private func writeRemainingBuffers() async {
        while !bufferQueue.isEmpty {
            await writeBufferQueue()
        }
    }
    
    private func finalizeAudioFile() async throws {
        guard let audioFile = audioFile else {
            throw AudioError.fileSystemError("Audio file not available")
        }
        
        // Close audio file
        audioFile.close()
        
        // Write metadata to file
        try await writeMetadataToFile()
    }
    
    private func writeMetadataToFile() async throws {
        guard let url = recordingURL else {
            throw AudioError.fileNotFound("Recording URL not available")
        }
        
        let asset = AVAsset(url: url)
        
        // Create metadata items
        var metadataItems: [AVMetadataItem] = []
        
        // Add basic metadata
        if let titleItem = createMetadataItem(for: .commonIdentifierTitle, value: recordingMetadata.title) {
            metadataItems.append(titleItem)
        }
        
        if let artistItem = createMetadataItem(for: .commonIdentifierArtist, value: recordingMetadata.artist) {
            metadataItems.append(artistItem)
        }
        
        if let albumItem = createMetadataItem(for: .commonIdentifierAlbum, value: recordingMetadata.album) {
            metadataItems.append(albumItem)
        }
        
        if let dateItem = createMetadataItem(for: .commonIdentifierCreationDate, value: recordingMetadata.startTime) {
            metadataItems.append(dateItem)
        }
        
        // Add custom metadata
        for (key, value) in recordingMetadata.customTags {
            if let customItem = createMetadataItem(for: .commonIdentifierDescription, value: "\(key): \(value)") {
                metadataItems.append(customItem)
            }
        }
        
        // Write metadata to file
        if !metadataItems.isEmpty {
            // This would require using AVAssetWriter to write metadata
            // For now, we'll just store it in the metadata object
        }
    }
    
    private func createMetadataItem(for identifier: AVMetadataIdentifier, value: Any) -> AVMetadataItem? {
        let item = AVMutableMetadataItem()
        item.identifier = identifier
        item.value = value as? NSCopying & NSObjectProtocol
        return item.copy() as? AVMetadataItem
    }
    
    private func startRecordingTimer() async {
        recordingDuration = 0.0
        
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.updateRecordingDuration()
            }
        }
    }
    
    private func stopRecordingTimer() async {
        recordingTimer?.invalidate()
        recordingTimer = nil
    }
    
    private func updateRecordingDuration() async {
        guard isRecording && !isPaused else { return }
        
        recordingDuration += 0.1
        recordingMetadata.duration = recordingDuration
    }
    
    private func cleanupRecording() async {
        await stopRecordingTimer()
        await removeInputTap()
        
        audioEngine?.stop()
        audioEngine = nil
        
        audioFile?.close()
        audioFile = nil
        
        formatConverter = nil
        
        bufferQueue.removeAll()
        
        isRecording = false
        isPaused = false
    }
    
    private func generateRecordingURL() -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let timestamp = Int(Date().timeIntervalSince1970)
        let filename = "audio_\(timestamp).\(configuration.format.fileExtension)"
        return documentsPath.appendingPathComponent(filename)
    }
    
    private func createAudioSettings(from config: AudioConfiguration) -> [String: Any] {
        var settings: [String: Any] = [
            AVFormatIDKey: config.format.avFormatID,
            AVSampleRateKey: config.sampleRate,
            AVNumberOfChannelsKey: config.channels,
            AVLinearPCMBitDepthKey: config.bitDepth,
            AVEncoderAudioQualityKey: config.quality.encoderQuality
        ]
        
        if config.format.supportsCompression {
            settings[AVEncoderBitRateKey] = config.quality.bitRate
        }
        
        // Add format-specific settings
        switch config.format {
        case .pcm:
            settings[AVLinearPCMIsBigEndianKey] = false
            settings[AVLinearPCMIsFloatKey] = true
            settings[AVLinearPCMIsNonInterleaved] = false
        case .alac:
            settings[AVEncoderBitRateKey] = config.sampleRate * Double(config.channels) * Double(config.bitDepth)
        default:
            break
        }
        
        return settings
    }
    
    private func createOutputFormat(from config: AudioConfiguration) -> AVAudioFormat {
        var settings = createAudioSettings(from: config)
        
        // Remove quality key for format creation
        settings.removeValue(forKey: AVEncoderAudioQualityKey)
        
        return AVAudioFormat(settings: settings)!
    }
    
    private func isFormatCompatible(_ format: AVAudioFormat, with config: AudioConfiguration) -> Bool {
        // Check sample rate compatibility
        if abs(format.sampleRate - config.sampleRate) > 100 {
            return false
        }
        
        // Check channel count compatibility
        if format.channelCount != config.channels {
            return false
        }
        
        // Check bit depth compatibility for PCM formats
        if config.format == .pcm || config.format == .wav {
            if let commonFormat = format.commonFormat {
                switch commonFormat {
                case .pcmFormatFloat32:
                    return config.bitDepth == 32
                case .pcmFormatInt16:
                    return config.bitDepth == 16
                case .pcmFormatInt32:
                    return config.bitDepth == 32
                default:
                    return false
                }
            }
        }
        
        return true
    }
}

// MARK: - Audio Recording Metadata

struct AudioRecordingMetadata: Sendable, Codable {
    var url: URL?
    var title: String = ""
    var artist: String = ""
    var album: String = ""
    var startTime: Date = Date()
    var endTime: Date?
    var duration: TimeInterval = 0.0
    var configuration: AudioConfiguration = .default
    var averageLevel: Float = -120.0
    var peakLevel: Float = -120.0
    var currentLevel: Float = -120.0
    var customTags: [String: String] = [:]
    
    init(url: URL? = nil, configuration: AudioConfiguration = .default, startTime: Date = Date()) {
        self.url = url
        self.configuration = configuration
        self.startTime = startTime
    }
}

// MARK: - Audio Recording Statistics

struct AudioRecordingStatistics: Sendable, Codable {
    var recordingDuration: TimeInterval = 0.0
    var currentDuration: TimeInterval = 0.0
    var totalBuffers: Int = 0
    var droppedBuffers: Int = 0
    var averageLevel: Float = -120.0
    var peakLevel: Float = -120.0
    var currentLevel: Float = -120.0
    var dataRate: Double = 0.0
    var fileSize: UInt64 = 0
    
    var dropRate: Float {
        guard totalBuffers > 0 else { return 0.0 }
        return Float(droppedBuffers) / Float(totalBuffers)
    }
    
    var qualityScore: Float {
        let dropPenalty = dropRate * 100.0
        let levelScore = max(0.0, (averageLevel + 60.0) / 60.0 * 100.0)
        return max(0.0, levelScore - dropPenalty)
    }
}

// MARK: - Audio Recording Event

struct AudioRecordingEvent: Sendable, Codable {
    let type: AudioRecordingEventType
    let url: URL?
    let timestamp: Date
    let metadata: AudioRecordingMetadata?
    let statistics: AudioRecordingStatistics?
    
    init(
        type: AudioRecordingEventType,
        url: URL? = nil,
        timestamp: Date = Date(),
        metadata: AudioRecordingMetadata? = nil,
        statistics: AudioRecordingStatistics? = nil
    ) {
        self.type = type
        self.url = url
        self.timestamp = timestamp
        self.metadata = metadata
        self.statistics = statistics
    }
}

enum AudioRecordingEventType: String, CaseIterable, Sendable, Codable {
    case started = "started"
    case stopped = "stopped"
    case paused = "paused"
    case resumed = "resumed"
    case error = "error"
    case levelUpdate = "levelUpdate"
    
    var displayName: String {
        switch self {
        case .started:
            return "Started"
        case .stopped:
            return "Stopped"
        case .paused:
            return "Paused"
        case .resumed:
            return "Resumed"
        case .error:
            return "Error"
        case .levelUpdate:
            return "Level Update"
        }
    }
}

// MARK: - Audio Player Actor

@MainActor
actor AudioPlayer: Sendable {
    private(set) var isPlaying = false
    private(set) var currentURL: URL?
    private(set) var playbackDuration: TimeInterval = 0.0
    private(set) var currentTime: TimeInterval = 0.0
    
    private var audioPlayerNode: AVAudioPlayerNode?
    private var audioEngine: AVAudioEngine?
    private var audioFile: AVAudioFile?
    private var playbackTimer: Timer?
    
    func loadAudio(from url: URL) async throws {
        currentURL = url
        audioFile = try AVAudioFile(forReading: url)
    }
    
    func play() async throws {
        guard let audioFile = audioFile else {
            throw AudioError.playbackFileNotFound
        }
        
        audioEngine = AVAudioEngine()
        audioPlayerNode = AVAudioPlayerNode()
        
        guard let audioEngine = audioEngine,
              let audioPlayerNode = audioPlayerNode else {
            throw AudioError.playbackFailed("Failed to create audio player")
        }
        
        audioEngine.attach(audioPlayerNode)
        audioEngine.connect(audioPlayerNode, to: audioEngine.mainMixerNode, format: audioFile.processingFormat)
        
        try audioEngine.start()
        
        audioPlayerNode.scheduleFile(audioFile, at: nil)
        audioPlayerNode.play()
        
        isPlaying = true
        await startPlaybackTimer()
    }
    
    func pause() async {
        audioPlayerNode?.pause()
        isPlaying = false
        await stopPlaybackTimer()
    }
    
    func stop() async {
        audioPlayerNode?.stop()
        audioEngine?.stop()
        isPlaying = false
        currentTime = 0.0
        await stopPlaybackTimer()
    }
    
    func seek(to time: TimeInterval) async {
        // Implementation for seeking
        currentTime = time
    }
    
    private func startPlaybackTimer() async {
        playbackTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.updatePlaybackTime()
            }
        }
    }
    
    private func stopPlaybackTimer() async {
        playbackTimer?.invalidate()
        playbackTimer = nil
    }
    
    private func updatePlaybackTime() async {
        guard isPlaying else { return }
        currentTime += 0.1
    }
}