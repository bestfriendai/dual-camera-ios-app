//
//  AudioExportManager.swift
//  DualApp
//
//  Created by DualApp Team on 10/3/25.
//

import Foundation
import AVFoundation
import UIKit
import SwiftUI

// MARK: - Audio Export Manager

actor AudioExportManager: Sendable {
    // MARK: - State Properties
    
    private(set) var isExporting = false
    private(set) var currentExportProgress: Float = 0.0
    private(set) var exportQueue: [AudioExportRequest] = []
    private(set) var completedExports: [AudioExportResult] = []
    private(set) var failedExports: [AudioExportError] = []
    
    // MARK: - Export Components
    
    private let storageManager: AudioStorageManager
    private var currentExportSession: AVAssetExportSession?
    private var exportTimer: Timer?
    
    // MARK: - Event Streams
    
    let exportEvents: AsyncStream<AudioExportEvent>
    private let exportContinuation: AsyncStream<AudioExportEvent>.Continuation
    
    // MARK: - Configuration
    
    private let configuration: AudioExportConfiguration
    
    // MARK: - Initialization
    
    init(
        storageManager: AudioStorageManager,
        configuration: AudioExportConfiguration = .default
    ) {
        self.storageManager = storageManager
        self.configuration = configuration
        
        (exportEvents, exportContinuation) = AsyncStream.makeStream()
        
        Task {
            await initializeExportManager()
        }
    }
    
    // MARK: - Public Interface
    
    func exportRecording(
        _ recording: AudioRecordingInfo,
        to format: AudioFormat,
        quality: AudioQuality,
        options: AudioExportOptions = .default
    ) async throws -> URL {
        let request = AudioExportRequest(
            recording: recording,
            format: format,
            quality: quality,
            options: options,
            id: UUID()
        )
        
        return try await performExport(request)
    }
    
    func exportMultipleRecordings(
        _ recordings: [AudioRecordingInfo],
        to format: AudioFormat,
        quality: AudioQuality,
        options: AudioExportOptions = .default
    ) async throws -> [URL] {
        var results: [URL] = []
        
        for recording in recordings {
            do {
                let url = try await exportRecording(
                    recording,
                    to: format,
                    quality: quality,
                    options: options
                )
                results.append(url)
            } catch {
                throw AudioError.exportFailed("Failed to export recording: \(recording.title)")
            }
        }
        
        return results
    }
    
    func addToExportQueue(_ request: AudioExportRequest) async {
        exportQueue.append(request)
        
        // Start processing if not already exporting
        if !isExporting {
            await processExportQueue()
        }
    }
    
    func cancelCurrentExport() async {
        guard isExporting, let exportSession = currentExportSession else { return }
        
        exportSession.cancelExport()
        
        // Update state
        isExporting = false
        currentExportProgress = 0.0
        currentExportSession = nil
        
        // Send event
        let event = AudioExportEvent(
            type: .exportCancelled,
            timestamp: Date()
        )
        exportContinuation.yield(event)
    }
    
    func clearExportQueue() async {
        exportQueue.removeAll()
    }
    
    func getExportProgress() async -> Float {
        return currentExportProgress
    }
    
    func getExportQueue() async -> [AudioExportRequest] {
        return exportQueue
    }
    
    func getCompletedExports() async -> [AudioExportResult] {
        return completedExports
    }
    
    func getFailedExports() async -> [AudioExportError] {
        return failedExports
    }
    
    func createShareSheet(for recording: AudioRecordingInfo) async throws -> UIActivityViewController {
        let sharingItems = try await storageManager.shareRecording(recording)
        
        let activityViewController = UIActivityViewController(
            activityItems: sharingItems,
            applicationActivities: nil
        )
        
        return activityViewController
    }
    
    func createShareSheet(for recordings: [AudioRecordingInfo]) async throws -> UIActivityViewController {
        var sharingItems: [Any] = []
        
        for recording in recordings {
            let items = try await storageManager.shareRecording(recording)
            sharingItems.append(contentsOf: items)
        }
        
        let activityViewController = UIActivityViewController(
            activityItems: sharingItems,
            applicationActivities: nil
        )
        
        return activityViewController
    }
    
    func shareToCloudDrive(_ recording: AudioRecordingInfo, service: CloudService) async throws {
        let exportURL = try await exportRecording(
            recording,
            to: .m4a,
            quality: .high,
            options: [.includeMetadata, .includeWaveform]
        )
        
        try await uploadToCloudService(exportURL, service: service)
    }
    
    func generateShareableLink(for recording: AudioRecordingInfo) async throws -> URL {
        // Export to temporary location
        let exportURL = try await exportRecording(
            recording,
            to: .m4a,
            quality: .high,
            options: [.includeMetadata, .includeWaveform]
        )
        
        // Upload to cloud service and get shareable link
        // This would be implemented with specific cloud service APIs
        return exportURL
    }
    
    // MARK: - Private Methods
    
    private func initializeExportManager() async {
        // Start processing queue if there are items
        if !exportQueue.isEmpty {
            await processExportQueue()
        }
    }
    
    private func performExport(_ request: AudioExportRequest) async throws -> URL {
        guard let sourceURL = request.recording.fileURL else {
            throw AudioError.fileNotFound("Source file not available")
        }
        
        // Update state
        isExporting = true
        currentExportProgress = 0.0
        
        // Send event
        let startedEvent = AudioExportEvent(
            type: .exportStarted,
            timestamp: Date(),
            request: request
        )
        exportContinuation.yield(startedEvent)
        
        do {
            // Create export URL
            let exportURL = try await createExportURL(for: request)
            
            // Setup export session
            let asset = AVAsset(url: sourceURL)
            let exportSession = AVAssetExportSession(asset: asset, presetName: request.quality.avExportPreset)
            
            guard let exportSession = exportSession else {
                throw AudioError.formatConversionFailed
            }
            
            // Configure export
            exportSession.outputURL = exportURL
            exportSession.outputFileType = request.format.avFileType
            exportSession.shouldOptimizeForNetworkUse = request.options.contains(.optimizeForNetwork)
            
            // Apply metadata if requested
            if request.options.contains(.includeMetadata) {
                try await applyMetadataToExport(exportSession, recording: request.recording)
            }
            
            // Store current session
            currentExportSession = exportSession
            
            // Start progress monitoring
            await startProgressMonitoring()
            
            // Export
            await withCheckedContinuation { continuation in
                exportSession.exportAsynchronously {
                    continuation.resume()
                }
            }
            
            // Stop progress monitoring
            await stopProgressMonitoring()
            
            // Check result
            guard exportSession.status == .completed else {
                throw AudioError.exportFailed(exportSession.error?.localizedDescription ?? "Unknown error")
            }
            
            // Create waveform if requested
            if request.options.contains(.includeWaveform) {
                try await createWaveformForExport(exportURL, recording: request.recording)
            }
            
            // Update state
            isExporting = false
            currentExportProgress = 1.0
            currentExportSession = nil
            
            // Create result
            let result = AudioExportResult(
                request: request,
                outputURL: exportURL,
                fileSize: try await getFileSize(exportURL),
                duration: request.recording.duration,
                completedAt: Date()
            )
            
            completedExports.append(result)
            
            // Send event
            let completedEvent = AudioExportEvent(
                type: .exportCompleted,
                timestamp: Date(),
                request: request,
                result: result
            )
            exportContinuation.yield(completedEvent)
            
            return exportURL
            
        } catch {
            // Update state
            isExporting = false
            currentExportProgress = 0.0
            currentExportSession = nil
            
            // Create error
            let exportError = AudioExportError(
                request: request,
                error: error,
                timestamp: Date()
            )
            
            failedExports.append(exportError)
            
            // Send event
            let errorEvent = AudioExportEvent(
                type: .exportFailed,
                timestamp: Date(),
                request: request,
                error: exportError
            )
            exportContinuation.yield(errorEvent)
            
            throw error
        }
    }
    
    private func processExportQueue() async {
        guard !isExporting && !exportQueue.isEmpty else { return }
        
        let request = exportQueue.removeFirst()
        
        do {
            _ = try await performExport(request)
        } catch {
            print("Failed to export from queue: \(error)")
        }
        
        // Process next item in queue
        if !exportQueue.isEmpty {
            await processExportQueue()
        }
    }
    
    private func createExportURL(for request: AudioExportRequest) async throws -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let exportsPath = documentsPath.appendingPathComponent("AudioExports")
        
        // Create directory if it doesn't exist
        try FileManager.default.createDirectory(at: exportsPath, withIntermediateDirectories: true)
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
        let dateString = dateFormatter.string(from: Date())
        
        let filename = "\(request.recording.title)_exported_\(dateString).\(request.format.fileExtension)"
        return exportsPath.appendingPathComponent(filename)
    }
    
    private func applyMetadataToExport(_ exportSession: AVAssetExportSession, recording: AudioRecordingInfo) async throws {
        // Create metadata items
        var metadataItems: [AVMetadataItem] = []
        
        // Title
        if let titleItem = createMetadataItem(for: .commonIdentifierTitle, value: recording.title) {
            metadataItems.append(titleItem)
        }
        
        // Artist
        if let artistItem = createMetadataItem(for: .commonIdentifierArtist, value: recording.metadata.artist ?? "") {
            metadataItems.append(artistItem)
        }
        
        // Album
        if let albumItem = createMetadataItem(for: .commonIdentifierAlbum, value: recording.metadata.album ?? "") {
            metadataItems.append(albumItem)
        }
        
        // Creation date
        if let dateItem = createMetadataItem(for: .commonIdentifierCreationDate, value: recording.createdAt) {
            metadataItems.append(dateItem)
        }
        
        // Custom tags
        for (key, value) in recording.metadata.customTags {
            if let customItem = createMetadataItem(for: .commonIdentifierDescription, value: "\(key): \(value)") {
                metadataItems.append(customItem)
            }
        }
        
        // Apply metadata to export session
        if !metadataItems.isEmpty {
            exportSession.metadata = metadataItems
        }
    }
    
    private func createMetadataItem(for identifier: AVMetadataIdentifier, value: Any) -> AVMetadataItem? {
        let item = AVMutableMetadataItem()
        item.identifier = identifier
        item.value = value as? NSCopying & NSObjectProtocol
        return item.copy() as? AVMetadataItem
    }
    
    private func createWaveformForExport(_ url: URL, recording: AudioRecordingInfo) async throws {
        // Generate waveform and save alongside the exported file
        let waveformURL = url.appendingPathExtension("waveform")
        
        // This would use the same waveform generation logic as in AudioStorageManager
        // For now, we'll just create an empty file
        try Data().write(to: waveformURL)
    }
    
    private func startProgressMonitoring() async {
        exportTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.updateExportProgress()
            }
        }
    }
    
    private func stopProgressMonitoring() async {
        exportTimer?.invalidate()
        exportTimer = nil
    }
    
    private func updateExportProgress() async {
        guard let exportSession = currentExportSession else { return }
        
        switch exportSession.status {
        case .waiting:
            currentExportProgress = 0.0
        case .exporting:
            currentExportProgress = Float(exportSession.progress)
        case .completed:
            currentExportProgress = 1.0
        case .failed, .cancelled:
            currentExportProgress = 0.0
        @unknown default:
            break
        }
        
        // Send progress event
        let event = AudioExportEvent(
            type: .exportProgress,
            timestamp: Date(),
            progress: currentExportProgress
        )
        exportContinuation.yield(event)
    }
    
    private func uploadToCloudService(_ url: URL, service: CloudService) async throws {
        // This would be implemented with specific cloud service APIs
        // For now, we'll just simulate the upload
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
    }
    
    private func getFileSize(_ url: URL) async throws -> UInt64 {
        let resourceValues = try url.resourceValues(forKeys: [.fileSizeKey])
        return UInt64(resourceValues.fileSize ?? 0)
    }
}

// MARK: - Supporting Types

struct AudioExportConfiguration: Sendable {
    let maxConcurrentExports: Int
    let defaultFormat: AudioFormat
    let defaultQuality: AudioQuality
    let enableWaveformGeneration: Bool
    let enableMetadataPreservation: Bool
    let enableCloudIntegration: Bool
    
    static let `default` = AudioExportConfiguration(
        maxConcurrentExports: 1,
        defaultFormat: .m4a,
        defaultQuality: .high,
        enableWaveformGeneration: true,
        enableMetadataPreservation: true,
        enableCloudIntegration: false
    )
}

struct AudioExportRequest: Sendable, Identifiable {
    let id: UUID
    let recording: AudioRecordingInfo
    let format: AudioFormat
    let quality: AudioQuality
    let options: AudioExportOptions
    let createdAt: Date
    
    init(
        recording: AudioRecordingInfo,
        format: AudioFormat,
        quality: AudioQuality,
        options: AudioExportOptions = .default,
        id: UUID = UUID(),
        createdAt: Date = Date()
    ) {
        self.id = id
        self.recording = recording
        self.format = format
        self.quality = quality
        self.options = options
        self.createdAt = createdAt
    }
}

struct AudioExportOptions: OptionSet, Sendable {
    static let includeMetadata = AudioExportOptions(rawValue: 1 << 0)
    static let includeWaveform = AudioExportOptions(rawValue: 1 << 1)
    static let optimizeForNetwork = AudioExportOptions(rawValue: 1 << 2)
    static let includeArtwork = AudioExportOptions(rawValue: 1 << 3)
    
    static let `default`: AudioExportOptions = [.includeMetadata, .includeWaveform]
}

struct AudioExportResult: Sendable {
    let request: AudioExportRequest
    let outputURL: URL
    let fileSize: UInt64
    let duration: TimeInterval
    let completedAt: Date
    
    var formattedFileSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(fileSize))
    }
    
    var formattedDuration: String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) % 3600 / 60
        let seconds = Int(duration) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
}

struct AudioExportError: Sendable {
    let request: AudioExportRequest
    let error: Error
    let timestamp: Date
    
    var localizedDescription: String {
        return error.localizedDescription
    }
}

enum CloudService: String, CaseIterable, Sendable {
    case iCloud = "iCloud"
    case dropbox = "dropbox"
    case googleDrive = "googleDrive"
    case oneDrive = "oneDrive"
    
    var displayName: String {
        switch self {
        case .iCloud:
            return "iCloud"
        case .dropbox:
            return "Dropbox"
        case .googleDrive:
            return "Google Drive"
        case .oneDrive:
            return "OneDrive"
        }
    }
    
    var iconName: String {
        switch self {
        case .iCloud:
            return "icloud.fill"
        case .dropbox:
            return "dropbox.fill"
        case .googleDrive:
            return "externaldrive.fill"
        case .oneDrive:
            return "onedrive.fill"
        }
    }
}

enum AudioExportEventType: String, CaseIterable, Sendable {
    case exportStarted = "exportStarted"
    case exportProgress = "exportProgress"
    case exportCompleted = "exportCompleted"
    case exportFailed = "exportFailed"
    case exportCancelled = "exportCancelled"
    case queueUpdated = "queueUpdated"
    
    var displayName: String {
        switch self {
        case .exportStarted:
            return "Export Started"
        case .exportProgress:
            return "Export Progress"
        case .exportCompleted:
            return "Export Completed"
        case .exportFailed:
            return "Export Failed"
        case .exportCancelled:
            return "Export Cancelled"
        case .queueUpdated:
            return "Queue Updated"
        }
    }
}

struct AudioExportEvent: Sendable {
    let type: AudioExportEventType
    let timestamp: Date
    let request: AudioExportRequest?
    let result: AudioExportResult?
    let error: AudioExportError?
    let progress: Float?
    
    init(
        type: AudioExportEventType,
        timestamp: Date = Date(),
        request: AudioExportRequest? = nil,
        result: AudioExportResult? = nil,
        error: AudioExportError? = nil,
        progress: Float? = nil
    ) {
        self.type = type
        self.timestamp = timestamp
        self.request = request
        self.result = result
        self.error = error
        self.progress = progress
    }
}

// MARK: - Audio Export View

struct AudioExportView: View {
    // MARK: - State Properties
    
    @StateObject private var exportManager: AudioExportManager
    @State private var selectedRecordings: Set<UUID> = []
    @State private var selectedFormat: AudioFormat = .m4a
    @State private var selectedQuality: AudioQuality = .high
    @State private var exportOptions: AudioExportOptions = .default
    @State private var showingShareSheet = false
    @State private var shareSheetItems: [Any] = []
    @State private var showingCloudServiceSelection = false
    @State private var selectedCloudService: CloudService = .iCloud
    @State private var isExporting = false
    @State private var exportProgress: Float = 0.0
    @State private var showingProgress = false
    
    // MARK: - UI Properties
    
    private let style: LiquidGlassStyle
    private let intensity: Double
    private let animationType: LiquidGlassAnimationType
    
    // MARK: - Initialization
    
    init(
        exportManager: AudioExportManager,
        style: LiquidGlassStyle = .card,
        intensity: Double = 0.6,
        animationType: LiquidGlassAnimationType = .shimmer
    ) {
        self._exportManager = StateObject(wrappedValue: exportManager)
        self.style = style
        self.intensity = intensity
        self.animationType = animationType
    }
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
            
            // Recording selection
            recordingSelectionView
            
            // Export options
            exportOptionsView
            
            // Export actions
            exportActionsView
            
            // Progress view
            if showingProgress {
                progressView
            }
        }
        .padding(style.padding)
        .background(
            LiquidGlassView(
                style: style,
                intensity: intensity,
                animationType: animationType
            )
        )
        .onAppear {
            setupExportView()
        }
        .sheet(isPresented: $showingShareSheet) {
            ShareSheet(items: shareSheetItems)
        }
        .sheet(isPresented: $showingCloudServiceSelection) {
            cloudServiceSelectionView
        }
    }
    
    // MARK: - View Components
    
    private var headerView: some View {
        HStack {
            Text("Export Audio")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(DesignColors.textOnGlass)
            
            Spacer()
            
            Button(action: {
                showingProgress.toggle()
            }) {
                Image(systemName: showingProgress ? "xmark.circle.fill" : "info.circle")
                    .foregroundColor(DesignColors.textOnGlass)
            }
            .buttonStyle(GlassButtonStyle(style: .minimal))
        }
        .padding(.bottom, 16)
    }
    
    private var recordingSelectionView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Select Recordings")
                .font(.headline)
                .foregroundColor(DesignColors.textOnGlass)
            
            // This would be populated with actual recordings
            Text("Recording selection would go here")
                .font(.body)
                .foregroundColor(DesignColors.textOnGlass.opacity(0.8))
                .padding()
                .background(DesignColors.background.opacity(0.2))
                .cornerRadius(8)
        }
        .padding(.bottom, 20)
    }
    
    private var exportOptionsView: some View {
        VStack(spacing: 16) {
            // Format selection
            VStack(alignment: .leading, spacing: 8) {
                Text("Format")
                    .font(.subheadline)
                    .foregroundColor(DesignColors.textOnGlass)
                
                Picker("Format", selection: $selectedFormat) {
                    ForEach(AudioFormat.allCases, id: \.self) { format in
                        Text(format.displayName).tag(format)
                    }
                }
                .pickerStyle(MenuPickerStyle())
            }
            
            // Quality selection
            VStack(alignment: .leading, spacing: 8) {
                Text("Quality")
                    .font(.subheadline)
                    .foregroundColor(DesignColors.textOnGlass)
                
                Picker("Quality", selection: $selectedQuality) {
                    ForEach(AudioQuality.allCases, id: \.self) { quality in
                        Text(quality.displayName).tag(quality)
                    }
                }
                .pickerStyle(MenuPickerStyle())
            }
            
            // Export options
            VStack(alignment: .leading, spacing: 8) {
                Text("Options")
                    .font(.subheadline)
                    .foregroundColor(DesignColors.textOnGlass)
                
                Toggle("Include Metadata", isOn: Binding(
                    get: { exportOptions.contains(.includeMetadata) },
                    set: { enabled in
                        if enabled {
                            exportOptions.insert(.includeMetadata)
                        } else {
                            exportOptions.remove(.includeMetadata)
                        }
                    }
                ))
                .toggleStyle(GlassToggleStyle())
                
                Toggle("Include Waveform", isOn: Binding(
                    get: { exportOptions.contains(.includeWaveform) },
                    set: { enabled in
                        if enabled {
                            exportOptions.insert(.includeWaveform)
                        } else {
                            exportOptions.remove(.includeWaveform)
                        }
                    }
                ))
                .toggleStyle(GlassToggleStyle())
                
                Toggle("Optimize for Network", isOn: Binding(
                    get: { exportOptions.contains(.optimizeForNetwork) },
                    set: { enabled in
                        if enabled {
                            exportOptions.insert(.optimizeForNetwork)
                        } else {
                            exportOptions.remove(.optimizeForNetwork)
                        }
                    }
                ))
                .toggleStyle(GlassToggleStyle())
            }
        }
        .padding(.bottom, 20)
    }
    
    private var exportActionsView: some View {
        VStack(spacing: 16) {
            // Export button
            Button(action: {
                exportSelectedRecordings()
            }) {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                        .font(.title3)
                    
                    Text("Export")
                        .font(.headline)
                }
                .foregroundColor(.white)
                .padding()
                .frame(maxWidth: .infinity)
                .background(DesignColors.accent)
                .cornerRadius(12)
            }
            .disabled(isExporting || selectedRecordings.isEmpty)
            
            // Share button
            Button(action: {
                shareSelectedRecordings()
            }) {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                        .font(.title3)
                    
                    Text("Share")
                        .font(.headline)
                }
                .foregroundColor(DesignColors.textOnGlass)
                .padding()
                .frame(maxWidth: .infinity)
                .background(DesignColors.background.opacity(0.3))
                .cornerRadius(12)
            }
            .disabled(selectedRecordings.isEmpty)
            
            // Cloud upload button
            Button(action: {
                showingCloudServiceSelection = true
            }) {
                HStack {
                    Image(systemName: "icloud.and.arrow.up")
                        .font(.title3)
                    
                    Text("Upload to Cloud")
                        .font(.headline)
                }
                .foregroundColor(DesignColors.textOnGlass)
                .padding()
                .frame(maxWidth: .infinity)
                .background(DesignColors.background.opacity(0.3))
                .cornerRadius(12)
            }
            .disabled(selectedRecordings.isEmpty)
        }
    }
    
    private var progressView: some View {
        VStack(spacing: 16) {
            Text("Exporting...")
                .font(.headline)
                .foregroundColor(DesignColors.textOnGlass)
            
            ProgressView(value: exportProgress)
                .progressViewStyle(LinearProgressViewStyle(tint: DesignColors.accent))
            
            Text("\(Int(exportProgress * 100))%")
                .font(.caption)
                .foregroundColor(DesignColors.textOnGlass.opacity(0.8))
        }
        .padding()
        .background(DesignColors.background.opacity(0.3))
        .cornerRadius(12)
    }
    
    private var cloudServiceSelectionView: some View {
        NavigationView {
            VStack {
                List(CloudService.allCases, id: \.rawValue) { service in
                    Button(action: {
                        selectedCloudService = service
                        uploadToCloudService()
                        showingCloudServiceSelection = false
                    }) {
                        HStack {
                            Image(systemName: service.iconName)
                                .foregroundColor(DesignColors.accent)
                                .frame(width: 30)
                            
                            Text(service.displayName)
                                .foregroundColor(DesignColors.textPrimary)
                            
                            Spacer()
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .navigationTitle("Select Cloud Service")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        showingCloudServiceSelection = false
                    }
                }
            }
        }
    }
    
    // MARK: - Methods
    
    private func setupExportView() {
        // Listen for export events
        Task {
            for await event in exportManager.exportEvents {
                await MainActor.run {
                    handleExportEvent(event)
                }
            }
        }
    }
    
    private func handleExportEvent(_ event: AudioExportEvent) {
        switch event.type {
        case .exportStarted:
            isExporting = true
            showingProgress = true
        case .exportProgress:
            if let progress = event.progress {
                exportProgress = progress
            }
        case .exportCompleted:
            isExporting = false
            showingProgress = false
            exportProgress = 1.0
        case .exportFailed, .exportCancelled:
            isExporting = false
            showingProgress = false
            exportProgress = 0.0
        default:
            break
        }
    }
    
    private func exportSelectedRecordings() {
        // Implementation for exporting selected recordings
        isExporting = true
        showingProgress = true
        
        Task {
            // Simulate export
            for i in 0...100 {
                await MainActor.run {
                    exportProgress = Float(i) / 100.0
                }
                try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
            }
            
            await MainActor.run {
                isExporting = false
                showingProgress = false
                exportProgress = 0.0
            }
        }
    }
    
    private func shareSelectedRecordings() {
        // Implementation for sharing selected recordings
        shareSheetItems = ["Recording data would go here"]
        showingShareSheet = true
    }
    
    private func uploadToCloudService() {
        // Implementation for uploading to cloud service
        isExporting = true
        showingProgress = true
        
        Task {
            // Simulate upload
            for i in 0...100 {
                await MainActor.run {
                    exportProgress = Float(i) / 100.0
                }
                try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
            }
            
            await MainActor.run {
                isExporting = false
                showingProgress = false
                exportProgress = 0.0
            }
        }
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Glass Toggle Style

struct GlassToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.label
            
            Spacer()
            
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(configuration.isOn ? DesignColors.accent : DesignColors.background.opacity(0.5))
                    .frame(width: 52, height: 32)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(DesignColors.textOnGlass.opacity(0.3), lineWidth: 1)
                    )
                
                Circle()
                    .fill(DesignColors.textOnGlass)
                    .frame(width: 28, height: 28)
                    .offset(x: configuration.isOn ? 12 : -12)
                    .animation(.easeInOut(duration: 0.2), value: configuration.isOn)
            }
        }
        .onTapGesture {
            configuration.isOn.toggle()
        }
    }
}



// MARK: - Preview

#Preview {
    AudioExportView(
        exportManager: AudioExportManager(
            storageManager: AudioStorageManager(),
            configuration: .default
        ),
        style: .card,
        intensity: 0.7,
        animationType: .shimmer
    )
}