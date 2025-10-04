//
//  AudioStorageManager.swift
//  DualApp
//
//  Created by DualApp Team on 10/3/25.
//

import Foundation
import AVFoundation
import CoreMedia
import SwiftUI

// MARK: - Audio Storage Manager

actor AudioStorageManager: Sendable {
    // MARK: - State Properties
    
    private(set) var storageLocation: AudioStorageLocation = .documents
    private(set) var availableSpace: UInt64 = 0
    private(set) var usedSpace: UInt64 = 0
    private(set) var totalRecordings: Int = 0
    private(set) var isOptimizing = false
    
    // MARK: - Storage Components
    
    private let fileManager: FileManager
    private let documentsDirectory: URL
    private let cacheDirectory: URL
    private let temporaryDirectory: URL
    private var recordingsIndex: [String: AudioRecordingInfo] = [:]
    private var waveformCache: [String: AudioWaveform] = [:]
    
    // MARK: - Event Streams
    
    let storageEvents: AsyncStream<AudioStorageEvent>
    private let storageContinuation: AsyncStream<AudioStorageEvent>.Continuation
    
    // MARK: - Configuration
    
    private let configuration: AudioStorageConfiguration
    
    // MARK: - Initialization
    
    init(configuration: AudioStorageConfiguration = .default) {
        self.configuration = configuration
        self.fileManager = FileManager.default
        
        // Get directory URLs
        self.documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.cacheDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        self.temporaryDirectory = fileManager.temporaryDirectory
        
        (storageEvents, storageContinuation) = AsyncStream.makeStream()
        
        Task {
            await initializeStorageManager()
        }
    }
    
    // MARK: - Public Interface
    
    func saveRecording(_ recording: AudioRecordingInfo) async throws -> URL {
        // Validate recording
        try validateRecording(recording)
        
        // Check available space
        try await checkAvailableSpace(for: recording)
        
        // Generate file URL
        let fileURL = try await generateFileURL(for: recording)
        
        // Copy file to storage location
        try await copyRecordingToStorage(recording, to: fileURL)
        
        // Update recording info
        var updatedRecording = recording
        updatedRecording.fileURL = fileURL
        updatedRecording.savedAt = Date()
        
        // Add to index
        recordingsIndex[updatedRecording.id.uuidString] = updatedRecording
        
        // Generate waveform
        if configuration.generateWaveforms {
            await generateWaveform(for: updatedRecording)
        }
        
        // Update storage metrics
        await updateStorageMetrics()
        
        // Send storage event
        let event = AudioStorageEvent(
            type: .recordingSaved,
            recording: updatedRecording,
            timestamp: Date()
        )
        storageContinuation.yield(event)
        
        return fileURL
    }
    
    func loadRecording(id: UUID) async throws -> AudioRecordingInfo? {
        return recordingsIndex[id.uuidString]
    }
    
    func loadRecording(at url: URL) async throws -> AudioRecordingInfo {
        // Load recording from file
        let asset = AVAsset(url: url)
        
        // Extract metadata
        let metadata = try await extractMetadata(from: asset)
        
        // Create recording info
        let recording = AudioRecordingInfo(
            id: UUID(),
            fileURL: url,
            title: metadata.title ?? url.lastPathComponent,
            duration: asset.duration.seconds,
            fileSize: try await getFileSize(url),
            format: AudioFormat(rawValue: url.pathExtension) ?? .m4a,
            sampleRate: metadata.sampleRate ?? 44100.0,
            channels: metadata.channels ?? 2,
            bitRate: metadata.bitRate ?? 128000,
            createdAt: metadata.creationDate ?? Date(),
            metadata: metadata
        )
        
        return recording
    }
    
    func deleteRecording(id: UUID) async throws {
        guard var recording = recordingsIndex[id.uuidString] else {
            throw AudioError.fileNotFound("Recording not found")
        }
        
        // Delete file
        if let fileURL = recording.fileURL {
            try fileManager.removeItem(at: fileURL)
        }
        
        // Delete waveform
        let waveformURL = getWaveformURL(for: recording)
        if fileManager.fileExists(atPath: waveformURL.path) {
            try fileManager.removeItem(at: waveformURL)
        }
        
        // Remove from index
        recordingsIndex.removeValue(forKey: id.uuidString)
        waveformCache.removeValue(forKey: id.uuidString)
        
        // Update storage metrics
        await updateStorageMetrics()
        
        // Send storage event
        let event = AudioStorageEvent(
            type: .recordingDeleted,
            recording: recording,
            timestamp: Date()
        )
        storageContinuation.yield(event)
    }
    
    func deleteRecording(at url: URL) async throws {
        // Find recording by URL
        let recording = recordingsIndex.values.first { $0.fileURL == url }
        
        if let recording = recording {
            try await deleteRecording(id: recording.id)
        } else {
            // Delete file directly
            try fileManager.removeItem(at: url)
        }
    }
    
    func getAllRecordings() async -> [AudioRecordingInfo] {
        return Array(recordingsIndex.values).sorted { $0.createdAt > $1.createdAt }
    }
    
    func getRecordings(filter: AudioRecordingFilter? = nil, sort: AudioRecordingSort = .dateDescending) async -> [AudioRecordingInfo] {
        var recordings = Array(recordingsIndex.values)
        
        // Apply filter
        if let filter = filter {
            recordings = recordings.filter { filter.matches($0) }
        }
        
        // Apply sort
        recordings.sort { sort.compare($0, $1) }
        
        return recordings
    }
    
    func getWaveform(for recordingId: UUID) async -> AudioWaveform? {
        // Check cache first
        if let cachedWaveform = waveformCache[recordingId.uuidString] {
            return cachedWaveform
        }
        
        // Load from disk
        guard let recording = recordingsIndex[recordingId.uuidString],
              let fileURL = recording.fileURL else {
            return nil
        }
        
        let waveformURL = getWaveformURL(for: recording)
        
        if fileManager.fileExists(atPath: waveformURL.path),
           let data = try? Data(contentsOf: waveformURL),
           let waveform = try? JSONDecoder().decode(AudioWaveform.self, from: data) {
            waveformCache[recordingId.uuidString] = waveform
            return waveform
        }
        
        // Generate waveform if not available
        if configuration.generateWaveforms {
            return await generateWaveform(for: recording)
        }
        
        return nil
    }
    
    func exportRecording(_ recording: AudioRecordingInfo, to format: AudioFormat, quality: AudioQuality) async throws -> URL {
        guard let sourceURL = recording.fileURL else {
            throw AudioError.fileNotFound("Source file not available")
        }
        
        // Create export URL
        let exportURL = try await generateExportURL(for: recording, format: format)
        
        // Setup export session
        let asset = AVAsset(url: sourceURL)
        let exportSession = AVAssetExportSession(asset: asset, presetName: quality.avExportPreset)
        
        guard let exportSession = exportSession else {
            throw AudioError.formatConversionFailed
        }
        
        // Configure export
        exportSession.outputURL = exportURL
        exportSession.outputFileType = format.avFileType
        exportSession.shouldOptimizeForNetworkUse = true
        
        // Export
        await withCheckedContinuation { continuation in
            exportSession.exportAsynchronously {
                continuation.resume()
            }
        }
        
        guard exportSession.status == .completed else {
            throw AudioError.exportFailed(exportSession.error?.localizedDescription ?? "Unknown error")
        }
        
        // Send export event
        let event = AudioStorageEvent(
            type: .recordingExported,
            recording: recording,
            timestamp: Date(),
            exportURL: exportURL
        )
        storageContinuation.yield(event)
        
        return exportURL
    }
    
    func shareRecording(_ recording: AudioRecordingInfo) async throws -> [Any] {
        guard let fileURL = recording.fileURL else {
            throw AudioError.fileNotFound("Recording file not available")
        }
        
        // Create sharing items
        var sharingItems: [Any] = []
        
        // Add file URL
        sharingItems.append(fileURL)
        
        // Add metadata
        let metadataText = createMetadataText(for: recording)
        sharingItems.append(metadataText)
        
        // Add waveform image if available
        if let waveform = await getWaveform(for: recording.id),
           let waveformImage = await createWaveformImage(from: waveform) {
            sharingItems.append(waveformImage)
        }
        
        return sharingItems
    }
    
    func optimizeStorage() async {
        guard !isOptimizing else { return }
        
        isOptimizing = true
        
        // Send optimization started event
        let event = AudioStorageEvent(
            type: .optimizationStarted,
            timestamp: Date()
        )
        storageContinuation.yield(event)
        
        // Remove old temporary files
        await cleanupTemporaryFiles()
        
        // Remove unused waveforms
        await cleanupUnusedWaveforms()
        
        // Compact recordings index
        await compactRecordingsIndex()
        
        // Update storage metrics
        await updateStorageMetrics()
        
        isOptimizing = false
        
        // Send optimization completed event
        let completedEvent = AudioStorageEvent(
            type: .optimizationCompleted,
            timestamp: Date()
        )
        storageContinuation.yield(completedEvent)
    }
    
    func getStorageMetrics() async -> AudioStorageMetrics {
        return AudioStorageMetrics(
            availableSpace: availableSpace,
            usedSpace: usedSpace,
            totalSpace: availableSpace + usedSpace,
            totalRecordings: totalRecordings,
            averageFileSize: totalRecordings > 0 ? usedSpace / UInt64(totalRecordings) : 0,
            oldestRecording: getOldestRecordingDate(),
            newestRecording: getNewestRecordingDate(),
            isOptimizing: isOptimizing
        )
    }
    
    func setStorageLocation(_ location: AudioStorageLocation) async throws {
        storageLocation = location
        
        // Migrate recordings if needed
        try await migrateRecordings(to: location)
        
        // Update storage metrics
        await updateStorageMetrics()
    }
    
    func updateRecordingMetadata(_ recording: AudioRecordingInfo) async throws {
        guard let fileURL = recording.fileURL else {
            throw AudioError.fileNotFound("Recording file not available")
        }
        
        // Update metadata in file
        try await writeMetadataToFile(recording, at: fileURL)
        
        // Update index
        recordingsIndex[recording.id.uuidString] = recording
        
        // Send metadata updated event
        let event = AudioStorageEvent(
            type: .metadataUpdated,
            recording: recording,
            timestamp: Date()
        )
        storageContinuation.yield(event)
    }
    
    // MARK: - Private Methods
    
    private func initializeStorageManager() async {
        // Create directories
        await createStorageDirectories()
        
        // Load recordings index
        await loadRecordingsIndex()
        
        // Update storage metrics
        await updateStorageMetrics()
        
        // Start background optimization
        if configuration.enableBackgroundOptimization {
            await startBackgroundOptimization()
        }
    }
    
    private func createStorageDirectories() async {
        let directories = [
            documentsDirectory.appendingPathComponent("AudioRecordings"),
            cacheDirectory.appendingPathComponent("AudioWaveforms"),
            cacheDirectory.appendingPathComponent("AudioThumbnails"),
            temporaryDirectory.appendingPathComponent("AudioTemp")
        ]
        
        for directory in directories {
            try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }
    }
    
    private func loadRecordingsIndex() async {
        let indexURL = documentsDirectory.appendingPathComponent("AudioRecordings/index.json")
        
        guard fileManager.fileExists(atPath: indexURL.path),
              let data = try? Data(contentsOf: indexURL),
              let index = try? JSONDecoder().decode([String: AudioRecordingInfo].self, from: data) else {
            return
        }
        
        recordingsIndex = index
        
        // Validate recordings exist
        for (id, recording) in recordingsIndex {
            if let fileURL = recording.fileURL,
               !fileManager.fileExists(atPath: fileURL.path) {
                recordingsIndex.removeValue(forKey: id)
            }
        }
    }
    
    private func saveRecordingsIndex() async {
        let indexURL = documentsDirectory.appendingPathComponent("AudioRecordings/index.json")
        
        guard let data = try? JSONEncoder().encode(recordingsIndex) else {
            return
        }
        
        try? data.write(to: indexURL)
    }
    
    private func updateStorageMetrics() async {
        let recordingsURL = documentsDirectory.appendingPathComponent("AudioRecordings")
        
        // Calculate used space
        if let enumerator = fileManager.enumerator(at: recordingsURL, includingPropertiesForKeys: [.fileSizeKey]) {
            usedSpace = 0
            totalRecordings = 0
            
            for case let fileURL as URL in enumerator {
                if let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey]),
                   let fileSize = resourceValues.fileSize {
                    usedSpace += UInt64(fileSize)
                    totalRecordings += 1
                }
            }
        }
        
        // Calculate available space
        if let resourceValues = try? documentsDirectory.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]),
           let availableCapacity = resourceValues.volumeAvailableCapacityForImportantUsage {
            availableSpace = UInt64(availableCapacity)
        }
        
        // Save index
        await saveRecordingsIndex()
    }
    
    private func validateRecording(_ recording: AudioRecordingInfo) throws {
        guard recording.fileURL != nil else {
            throw AudioError.fileNotFound("Recording file URL is nil")
        }
        
        guard recording.duration > 0 else {
            throw AudioError.invalidConfiguration("Recording duration must be greater than 0")
        }
        
        guard recording.fileSize > 0 else {
            throw AudioError.invalidConfiguration("Recording file size must be greater than 0")
        }
    }
    
    private func checkAvailableSpace(for recording: AudioRecordingInfo) async throws {
        let requiredSpace = recording.fileSize + (100 * 1024 * 1024) // Add 100MB buffer
        
        guard availableSpace >= requiredSpace else {
            throw AudioError.diskSpaceInsufficient
        }
    }
    
    private func generateFileURL(for recording: AudioRecordingInfo) async throws -> URL {
        let recordingsURL = documentsDirectory.appendingPathComponent("AudioRecordings")
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
        let dateString = dateFormatter.string(from: recording.createdAt)
        
        let filename = "\(recording.title)_\(dateString).\(recording.format.fileExtension)"
        let fileURL = recordingsURL.appendingPathComponent(filename)
        
        // Ensure unique filename
        var uniqueURL = fileURL
        var counter = 1
        
        while fileManager.fileExists(atPath: uniqueURL.path) {
            let nameWithoutExtension = fileURL.deletingPathExtension().lastPathComponent
            let fileExtension = fileURL.pathExtension
            uniqueURL = fileURL.deletingLastPathComponent()
                .appendingPathComponent("\(nameWithoutExtension)_\(counter)")
                .appendingPathExtension(fileExtension)
            counter += 1
        }
        
        return uniqueURL
    }
    
    private func copyRecordingToStorage(_ recording: AudioRecordingInfo, to destinationURL: URL) async throws {
        guard let sourceURL = recording.fileURL else {
            throw AudioError.fileNotFound("Source file not available")
        }
        
        try fileManager.copyItem(at: sourceURL, to: destinationURL)
    }
    
    private func generateWaveform(for recording: AudioRecordingInfo) async -> AudioWaveform? {
        guard let fileURL = recording.fileURL else {
            return nil
        }
        
        return await withCheckedContinuation { continuation in
            Task {
                do {
                    let asset = AVAsset(url: fileURL)
                    
                    // Load audio track
                    let audioTracks = try await asset.loadTracks(withMediaType: .audio)
                    guard let audioTrack = audioTracks.first else {
                        continuation.resume(returning: nil)
                        return
                    }
                    
                    // Create audio reader
                    let reader = try AVAssetReader(asset: asset)
                    let output = AVAssetReaderTrackOutput(track: audioTrack, outputSettings: [
                        AVFormatIDKey: kAudioFormatLinearPCM,
                        AVLinearPCMIsFloatKey: true,
                        AVLinearPCMIsBigEndianKey: false,
                        AVLinearPCMBitDepthKey: 32,
                        AVLinearPCMIsNonInterleaved: false
                    ])
                    
                    reader.add(output)
                    reader.startReading()
                    
                    // Read samples and generate waveform
                    var samples: [Float] = []
                    let targetSamples = 1000
                    
                    while reader.status == .reading {
                        if let sampleBuffer = output.copyNextSampleBuffer(),
                           let buffer = createPCMBuffer(from: sampleBuffer) {
                            let channelData = buffer.floatChannelData![0]
                            let frameLength = Int(buffer.frameLength)
                            
                            // Downsample to target sample count
                            let step = max(1, frameLength / targetSamples)
                            
                            for i in stride(from: 0, to: frameLength, by: step) {
                                samples.append(abs(channelData[i]))
                            }
                        }
                    }
                    
                    // Normalize samples
                    let maxSample = samples.max() ?? 1.0
                    let normalizedSamples = samples.map { $0 / maxSample }
                    
                    // Create waveform
                    let waveform = AudioWaveform(
                        samples: normalizedSamples,
                        duration: recording.duration,
                        sampleRate: recording.sampleRate,
                        channels: recording.channels,
                        generatedAt: Date()
                    )
                    
                    // Cache waveform
                    waveformCache[recording.id.uuidString] = waveform
                    
                    // Save waveform to disk
                    await saveWaveform(waveform, for: recording)
                    
                    continuation.resume(returning: waveform)
                    
                } catch {
                    print("Failed to generate waveform: \(error)")
                    continuation.resume(returning: nil)
                }
            }
        }
    }
    
    private func saveWaveform(_ waveform: AudioWaveform, for recording: AudioRecordingInfo) async {
        let waveformURL = getWaveformURL(for: recording)
        
        guard let data = try? JSONEncoder().encode(waveform) else {
            return
        }
        
        try? data.write(to: waveformURL)
    }
    
    private func getWaveformURL(for recording: AudioRecordingInfo) -> URL {
        let waveformsURL = cacheDirectory.appendingPathComponent("AudioWaveforms")
        return waveformsURL.appendingPathComponent("\(recording.id.uuidString).json")
    }
    
    private func createPCMBuffer(from sampleBuffer: CMSampleBuffer) -> AVAudioPCMBuffer? {
        guard let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer) else {
            return nil
        }
        
        let audioFormat = AVAudioFormat(cmAudioFormatDescription: formatDescription)
        guard let format = audioFormat else {
            return nil
        }
        
        let frameCount = CMSampleBufferGetNumSamples(sampleBuffer)
        guard let pcmBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frameCount)) else {
            return nil
        }
        
        pcmBuffer.frameLength = AVAudioFrameCount(frameCount)
        
        CMSampleBufferCopyPCMDataIntoAudioBufferList(
            with: sampleBuffer,
            at: 0,
            frameCount: Int32(frameCount),
            into: pcmBuffer.mutableAudioBufferList
        )
        
        return pcmBuffer
    }
    
    private func extractMetadata(from asset: AVAsset) async throws -> AudioMetadata {
        let metadata = AudioMetadata()
        
        // Load common metadata
        let commonMetadata = try await asset.load(.commonMetadata)
        
        for item in commonMetadata {
            guard let key = item.commonKey,
                  let value = item.value else { continue }
            
            switch key {
            case .commonIdentifierTitle:
                metadata.title = value as? String
            case .commonIdentifierArtist:
                metadata.artist = value as? String
            case .commonIdentifierAlbum:
                metadata.album = value as? String
            case .commonIdentifierCreationDate:
                if let date = value as? Date {
                    metadata.creationDate = date
                }
            default:
                break
            }
        }
        
        // Load format metadata
        let format = try await asset.load(.format)
        
        if let audioFormats = format.audioFormats.first {
            metadata.sampleRate = audioFormats.sampleRate
            metadata.channels = audioFormats.channelCount
            metadata.bitRate = audioFormats.estimatedBitRate
        }
        
        return metadata
    }
    
    private func getFileSize(_ url: URL) async throws -> UInt64 {
        let resourceValues = try url.resourceValues(forKeys: [.fileSizeKey])
        return UInt64(resourceValues.fileSize ?? 0)
    }
    
    private func generateExportURL(for recording: AudioRecordingInfo, format: AudioFormat) async throws -> URL {
        let exportsURL = documentsDirectory.appendingPathComponent("AudioExports")
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
        let dateString = dateFormatter.string(from: Date())
        
        let filename = "\(recording.title)_exported_\(dateString).\(format.fileExtension)"
        return exportsURL.appendingPathComponent(filename)
    }
    
    private func createMetadataText(for recording: AudioRecordingInfo) -> String {
        var metadata = "Title: \(recording.title)\n"
        metadata += "Duration: \(formatDuration(recording.duration))\n"
        metadata += "Format: \(recording.format.displayName)\n"
        metadata += "Sample Rate: \(Int(recording.sampleRate)) Hz\n"
        metadata += "Channels: \(recording.channels)\n"
        metadata += "Bit Rate: \(recording.bitRate) bps\n"
        metadata += "File Size: \(formatFileSize(recording.fileSize))\n"
        metadata += "Created: \(DateFormatter.string(from: recording.createdAt))"
        
        return metadata
    }
    
    private func createWaveformImage(from waveform: AudioWaveform) async -> UIImage? {
        let width = 800
        let height = 200
        
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height))
        
        return renderer.image { context in
            // Set background
            context.setFillColor(UIColor.systemBackground.cgColor)
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
            
            // Draw waveform
            context.setStrokeColor(UIColor.systemBlue.cgColor)
            context.setLineWidth(1.0)
            
            let path = UIBezierPath()
            let samples = waveform.samples
            let sampleCount = samples.count
            
            for i in 0..<sampleCount {
                let x = CGFloat(i) / CGFloat(sampleCount - 1) * CGFloat(width)
                let y = CGFloat(1.0 - samples[i]) * CGFloat(height)
                
                if i == 0 {
                    path.move(to: CGPoint(x: x, y: y))
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
            
            context.addPath(path.cgPath)
            context.strokePath()
        }
    }
    
    private func cleanupTemporaryFiles() async {
        let tempURL = temporaryDirectory.appendingPathComponent("AudioTemp")
        
        guard let enumerator = fileManager.enumerator(at: tempURL, includingPropertiesForKeys: [.contentModificationDateKey]) else {
            return
        }
        
        let cutoffDate = Date().addingTimeInterval(-3600) // 1 hour ago
        
        for case let fileURL as URL in enumerator {
            if let resourceValues = try? fileURL.resourceValues(forKeys: [.contentModificationDateKey]),
               let modificationDate = resourceValues.contentModificationDate,
               modificationDate < cutoffDate {
                try? fileManager.removeItem(at: fileURL)
            }
        }
    }
    
    private func cleanupUnusedWaveforms() async {
        let waveformsURL = cacheDirectory.appendingPathComponent("AudioWaveforms")
        
        guard let enumerator = fileManager.enumerator(at: waveformsURL, includingPropertiesForKeys: nil) else {
            return
        }
        
        for case let fileURL as URL in enumerator {
            let filename = fileURL.deletingPathExtension().lastPathComponent
            
            // Check if recording exists
            if recordingsIndex[filename] == nil {
                try? fileManager.removeItem(at: fileURL)
            }
        }
    }
    
    private func compactRecordingsIndex() async {
        // Remove invalid entries
        for (id, recording) in recordingsIndex {
            if let fileURL = recording.fileURL,
               !fileManager.fileExists(atPath: fileURL.path) {
                recordingsIndex.removeValue(forKey: id)
            }
        }
        
        // Save compacted index
        await saveRecordingsIndex()
    }
    
    private func startBackgroundOptimization() async {
        // Schedule optimization to run periodically
        Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.optimizeStorage()
            }
        }
    }
    
    private func migrateRecordings(to location: AudioStorageLocation) async throws {
        // Implementation for migrating recordings to different storage location
    }
    
    private func writeMetadataToFile(_ recording: AudioRecordingInfo, at url: URL) async throws {
        // Implementation for writing metadata to audio file
    }
    
    private func getOldestRecordingDate() -> Date? {
        return recordingsIndex.values.map(\.createdAt).min()
    }
    
    private func getNewestRecordingDate() -> Date? {
        return recordingsIndex.values.map(\.createdAt).max()
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) % 3600 / 60
        let seconds = Int(duration) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
    
    private func formatFileSize(_ size: UInt64) -> String {
        let byteCountFormatter = ByteCountFormatter()
        byteCountFormatter.allowedUnits = [.useKB, .useMB, .useGB]
        byteCountFormatter.countStyle = .file
        return byteCountFormatter.string(fromByteCount: Int64(size))
    }
}

// MARK: - Supporting Types

enum AudioStorageLocation: String, CaseIterable, Sendable {
    case documents = "documents"
    case cache = "cache"
    case temporary = "temporary"
    case iCloud = "iCloud"
    
    var displayName: String {
        switch self {
        case .documents:
            return "Documents"
        case .cache:
            return "Cache"
        case .temporary:
            return "Temporary"
        case .iCloud:
            return "iCloud"
        }
    }
}

struct AudioStorageConfiguration: Sendable {
    let generateWaveforms: Bool
    let enableBackgroundOptimization: Bool
    let maxCacheSize: UInt64
    let maxRecordings: Int
    let autoDeleteOldRecordings: Bool
    let maxRecordingAge: TimeInterval
    
    static let `default` = AudioStorageConfiguration(
        generateWaveforms: true,
        enableBackgroundOptimization: true,
        maxCacheSize: 1024 * 1024 * 1024, // 1GB
        maxRecordings: 1000,
        autoDeleteOldRecordings: false,
        maxRecordingAge: 30 * 24 * 60 * 60 // 30 days
    )
}

struct AudioRecordingInfo: Sendable, Codable, Identifiable {
    let id: UUID
    var fileURL: URL?
    let title: String
    let duration: TimeInterval
    let fileSize: UInt64
    let format: AudioFormat
    let sampleRate: Double
    let channels: UInt32
    let bitRate: Int
    let createdAt: Date
    var savedAt: Date?
    let metadata: AudioMetadata
    var tags: [String]
    var isFavorite: Bool
    var playCount: Int
    var lastPlayedAt: Date?
    
    init(
        id: UUID = UUID(),
        fileURL: URL? = nil,
        title: String,
        duration: TimeInterval,
        fileSize: UInt64,
        format: AudioFormat,
        sampleRate: Double,
        channels: UInt32,
        bitRate: Int,
        createdAt: Date,
        savedAt: Date? = nil,
        metadata: AudioMetadata = AudioMetadata(),
        tags: [String] = [],
        isFavorite: Bool = false,
        playCount: Int = 0,
        lastPlayedAt: Date? = nil
    ) {
        self.id = id
        self.fileURL = fileURL
        self.title = title
        self.duration = duration
        self.fileSize = fileSize
        self.format = format
        self.sampleRate = sampleRate
        self.channels = channels
        self.bitRate = bitRate
        self.createdAt = createdAt
        self.savedAt = savedAt
        self.metadata = metadata
        self.tags = tags
        self.isFavorite = isFavorite
        self.playCount = playCount
        self.lastPlayedAt = lastPlayedAt
    }
}

struct AudioMetadata: Sendable, Codable {
    var title: String?
    var artist: String?
    var album: String?
    var genre: String?
    var year: Int?
    var trackNumber: Int?
    var creationDate: Date?
    var sampleRate: Double?
    var channels: Int?
    var bitRate: Int?
    var customTags: [String: String] = [:]
    
    init() {}
}

struct AudioWaveform: Sendable, Codable {
    let samples: [Float]
    let duration: TimeInterval
    let sampleRate: Double
    let channels: UInt32
    let generatedAt: Date
    
    init(samples: [Float], duration: TimeInterval, sampleRate: Double, channels: UInt32, generatedAt: Date) {
        self.samples = samples
        self.duration = duration
        self.sampleRate = sampleRate
        self.channels = channels
        self.generatedAt = generatedAt
    }
}

struct AudioStorageMetrics: Sendable {
    let availableSpace: UInt64
    let usedSpace: UInt64
    let totalSpace: UInt64
    let totalRecordings: Int
    let averageFileSize: UInt64
    let oldestRecording: Date?
    let newestRecording: Date?
    let isOptimizing: Bool
    
    var usagePercentage: Double {
        guard totalSpace > 0 else { return 0.0 }
        return Double(usedSpace) / Double(totalSpace) * 100.0
    }
    
    var spaceStatus: String {
        switch usagePercentage {
        case 0..<50:
            return "Plenty of space"
        case 50..<80:
            return "Getting full"
        case 80..<95:
            return "Almost full"
        default:
            return "Full"
        }
    }
}

struct AudioRecordingFilter: Sendable {
    let title: String?
    let format: AudioFormat?
    let dateRange: ClosedRange<Date>?
    let durationRange: ClosedRange<TimeInterval>?
    let tags: [String]
    let isFavorite: Bool?
    
    init(
        title: String? = nil,
        format: AudioFormat? = nil,
        dateRange: ClosedRange<Date>? = nil,
        durationRange: ClosedRange<TimeInterval>? = nil,
        tags: [String] = [],
        isFavorite: Bool? = nil
    ) {
        self.title = title
        self.format = format
        self.dateRange = dateRange
        self.durationRange = durationRange
        self.tags = tags
        self.isFavorite = isFavorite
    }
    
    func matches(_ recording: AudioRecordingInfo) -> Bool {
        if let title = title {
            guard recording.title.localizedCaseInsensitiveContains(title) else { return false }
        }
        
        if let format = format {
            guard recording.format == format else { return false }
        }
        
        if let dateRange = dateRange {
            guard dateRange.contains(recording.createdAt) else { return false }
        }
        
        if let durationRange = durationRange {
            guard durationRange.contains(recording.duration) else { return false }
        }
        
        if !tags.isEmpty {
            let allTagsMatch = tags.allSatisfy { recording.tags.contains($0) }
            guard allTagsMatch else { return false }
        }
        
        if let isFavorite = isFavorite {
            guard recording.isFavorite == isFavorite else { return false }
        }
        
        return true
    }
}

enum AudioRecordingSort: Sendable {
    case dateAscending
    case dateDescending
    case titleAscending
    case titleDescending
    case durationAscending
    case durationDescending
    case sizeAscending
    case sizeDescending
    
    func compare(_ lhs: AudioRecordingInfo, _ rhs: AudioRecordingInfo) -> Bool {
        switch self {
        case .dateAscending:
            return lhs.createdAt < rhs.createdAt
        case .dateDescending:
            return lhs.createdAt > rhs.createdAt
        case .titleAscending:
            return lhs.title < rhs.title
        case .titleDescending:
            return lhs.title > rhs.title
        case .durationAscending:
            return lhs.duration < rhs.duration
        case .durationDescending:
            return lhs.duration > rhs.duration
        case .sizeAscending:
            return lhs.fileSize < rhs.fileSize
        case .sizeDescending:
            return lhs.fileSize > rhs.fileSize
        }
    }
}

enum AudioStorageEventType: String, CaseIterable, Sendable {
    case recordingSaved = "recordingSaved"
    case recordingDeleted = "recordingDeleted"
    case recordingExported = "recordingExported"
    case metadataUpdated = "metadataUpdated"
    case optimizationStarted = "optimizationStarted"
    case optimizationCompleted = "optimizationCompleted"
    case storageFull = "storageFull"
    case error = "error"
    
    var displayName: String {
        switch self {
        case .recordingSaved:
            return "Recording Saved"
        case .recordingDeleted:
            return "Recording Deleted"
        case .recordingExported:
            return "Recording Exported"
        case .metadataUpdated:
            return "Metadata Updated"
        case .optimizationStarted:
            return "Optimization Started"
        case .optimizationCompleted:
            return "Optimization Completed"
        case .storageFull:
            return "Storage Full"
        case .error:
            return "Error"
        }
    }
}

struct AudioStorageEvent: Sendable {
    let type: AudioStorageEventType
    let recording: AudioRecordingInfo?
    let timestamp: Date
    let exportURL: URL?
    let error: Error?
    
    init(
        type: AudioStorageEventType,
        recording: AudioRecordingInfo? = nil,
        timestamp: Date = Date(),
        exportURL: URL? = nil,
        error: Error? = nil
    ) {
        self.type = type
        self.recording = recording
        self.timestamp = timestamp
        self.exportURL = exportURL
        self.error = error
    }
}

// MARK: - Extensions

extension AudioFormat {
    var avFileType: AVFileType {
        switch self {
        case .m4a, .aac:
            return .m4a
        case .wav:
            return .wav
        case .pcm:
            return .wav
        case .alac:
            return .m4a
        case .flac:
            return .flac
        }
    }
}

extension AudioQuality {
    var avExportPreset: String {
        switch self {
        case .low:
            return AVAssetExportPresetLowQuality
        case .medium:
            return AVAssetExportPresetMediumQuality
        case .high:
            return AVAssetExportPresetHighQuality
        case .lossless, .ultra:
            return AVAssetExportPresetAppleLossless
        }
    }
}

extension DateFormatter {
    static func string(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}