//
//  RecordingState.swift
//  DualApp
//
//  Created by DualApp Team on 10/3/25.
//

import Foundation
import AVFoundation
import SwiftUI

// MARK: - Recording State

enum RecordingState: String, CaseIterable, Sendable, Codable {
    case idle = "Idle"
    case preparing = "Preparing"
    case recording = "Recording"
    case paused = "Paused"
    case stopping = "Stopping"
    case stopped = "Stopped"
    case error = "Error"
    case processing = "Processing"
    case completed = "Completed"
    
    var isActive: Bool {
        switch self {
        case .preparing, .recording, .paused, .stopping:
            return true
        default:
            return false
        }
    }
    
    var canStart: Bool {
        switch self {
        case .idle, .stopped, .completed, .error:
            return true
        default:
            return false
        }
    }
    
    var canStop: Bool {
        switch self {
        case .recording, .paused:
            return true
        default:
            return false
        }
    }
    
    var canPause: Bool {
        switch self {
        case .recording:
            return true
        default:
            return false
        }
    }
    
    var canResume: Bool {
        switch self {
        case .paused:
            return true
        default:
            return false
        }
    }
    
    var description: String {
        return rawValue
    }
    
    var icon: String {
        switch self {
        case .idle:
            return "circle"
        case .preparing:
            return "circle.dashed"
        case .recording:
            return "record.circle.fill"
        case .paused:
            return "pause.circle.fill"
        case .stopping:
            return "stop.circle.fill"
        case .stopped:
            return "stop.circle"
        case .error:
            return "xmark.circle.fill"
        case .processing:
            return "gear.circle.fill"
        case .completed:
            return "checkmark.circle.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .idle:
            return .gray
        case .preparing:
            return .orange
        case .recording:
            return .red
        case .paused:
            return .yellow
        case .stopping:
            return .orange
        case .stopped:
            return .gray
        case .error:
            return .red
        case .processing:
            return .blue
        case .completed:
            return .green
        }
    }
}

// MARK: - Recording Session

struct RecordingSession: Sendable, Codable, Identifiable {
    let id: UUID
    let startTime: Date
    var endTime: Date?
    var duration: TimeInterval {
        if let endTime = endTime {
            return endTime.timeIntervalSince(startTime)
        } else {
            return Date().timeIntervalSince(startTime)
        }
    }
    
    var state: RecordingState
    var configuration: CameraConfiguration
    var recordings: [RecordingTrack]
    var metadata: RecordingMetadata
    var error: RecordingError?
    
    init(
        id: UUID = UUID(),
        startTime: Date = Date(),
        state: RecordingState = .idle,
        configuration: CameraConfiguration,
        recordings: [RecordingTrack] = [],
        metadata: RecordingMetadata = RecordingMetadata(),
        error: RecordingError? = nil
    ) {
        self.id = id
        self.startTime = startTime
        self.state = state
        self.configuration = configuration
        self.recordings = recordings
        self.metadata = metadata
        self.error = error
    }
    
    var formattedDuration: String {
        let duration = Int(self.duration)
        let hours = duration / 3600
        let minutes = (duration % 3600) / 60
        let seconds = duration % 60
        
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
    
    var isActive: Bool {
        return state.isActive
    }
    
    var isCompleted: Bool {
        return state == .completed
    }
    
    var hasError: Bool {
        return state == .error || error != nil
    }
    
    mutating func updateState(_ newState: RecordingState) {
        state = newState
        
        if newState == .stopped || newState == .completed {
            endTime = Date()
        }
    }
    
    mutating func addRecording(_ recording: RecordingTrack) {
        recordings.append(recording)
    }
    
    mutating func setError(_ error: RecordingError) {
        self.error = error
        state = .error
        endTime = Date()
    }
    
    mutating func complete() {
        state = .completed
        endTime = Date()
    }
}

// MARK: - Recording Track

struct RecordingTrack: Sendable, Codable, Identifiable {
    let id: UUID
    let cameraPosition: CameraPosition
    let url: URL
    let startTime: Date
    var endTime: Date?
    let configuration: RecordingTrackConfiguration
    var metadata: TrackMetadata
    
    var duration: TimeInterval {
        if let endTime = endTime {
            return endTime.timeIntervalSince(startTime)
        } else {
            return Date().timeIntervalSince(startTime)
        }
    }
    
    var fileSize: Int64 {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            return attributes[.size] as? Int64 ?? 0
        } catch {
            return 0
        }
    }
    
    var formattedFileSize: String {
        let byteCountFormatter = ByteCountFormatter()
        byteCountFormatter.allowedUnits = [.useKB, .useMB, .useGB]
        byteCountFormatter.countStyle = .file
        return byteCountFormatter.string(fromByteCount: fileSize)
    }
    
    var isActive: Bool {
        return endTime == nil
    }
    
    init(
        id: UUID = UUID(),
        cameraPosition: CameraPosition,
        url: URL,
        startTime: Date = Date(),
        configuration: RecordingTrackConfiguration,
        metadata: TrackMetadata = TrackMetadata()
    ) {
        self.id = id
        self.cameraPosition = cameraPosition
        self.url = url
        self.startTime = startTime
        self.configuration = configuration
        self.metadata = metadata
    }
    
    mutating func stop() {
        endTime = Date()
    }
}

// MARK: - Recording Track Configuration

struct RecordingTrackConfiguration: Sendable, Codable {
    let quality: VideoQuality
    let frameRate: Int32
    let codec: AVVideoCodecType
    let audioEnabled: Bool
    let audioQuality: AudioQuality
    let stabilizationEnabled: Bool
    
    init(
        quality: VideoQuality,
        frameRate: Int32,
        codec: AVVideoCodecType,
        audioEnabled: Bool,
        audioQuality: AudioQuality,
        stabilizationEnabled: Bool
    ) {
        self.quality = quality
        self.frameRate = frameRate
        self.codec = codec
        self.audioEnabled = audioEnabled
        self.audioQuality = audioQuality
        self.stabilizationEnabled = stabilizationEnabled
    }
    
    static func from(_ configuration: CameraConfiguration) -> RecordingTrackConfiguration {
        return RecordingTrackConfiguration(
            quality: configuration.quality,
            frameRate: configuration.frameRate,
            codec: configuration.outputFormat.codec,
            audioEnabled: configuration.audioEnabled,
            audioQuality: configuration.audioQuality,
            stabilizationEnabled: configuration.videoStabilizationEnabled
        )
    }
}

// MARK: - Recording Metadata

struct RecordingMetadata: Sendable, Codable {
    let id: UUID
    let createdAt: Date
    var title: String
    var description: String?
    var tags: [String]
    var location: LocationMetadata?
    var deviceMetadata: DeviceMetadata
    var customMetadata: [String: String]
    
    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        title: String = "",
        description: String? = nil,
        tags: [String] = [],
        location: LocationMetadata? = nil,
        deviceMetadata: DeviceMetadata = DeviceMetadata(),
        customMetadata: [String: String] = [:]
    ) {
        self.id = id
        self.createdAt = createdAt
        self.title = title
        self.description = description
        self.tags = tags
        self.location = location
        self.deviceMetadata = deviceMetadata
        self.customMetadata = customMetadata
    }
}

// MARK: - Track Metadata

struct TrackMetadata: Sendable, Codable {
    let cameraPosition: CameraPosition
    let focalLength: Float?
    let aperture: Float?
    let shutterSpeed: Float?
    let iso: Float?
    let whiteBalance: Float?
    let exposureBias: Float?
    
    init(
        cameraPosition: CameraPosition,
        focalLength: Float? = nil,
        aperture: Float? = nil,
        shutterSpeed: Float? = nil,
        iso: Float? = nil,
        whiteBalance: Float? = nil,
        exposureBias: Float? = nil
    ) {
        self.cameraPosition = cameraPosition
        self.focalLength = focalLength
        self.aperture = aperture
        self.shutterSpeed = shutterSpeed
        self.iso = iso
        self.whiteBalance = whiteBalance
        self.exposureBias = exposureBias
    }
}

// MARK: - Location Metadata

struct LocationMetadata: Sendable, Codable {
    let latitude: Double
    let longitude: Double
    let altitude: Double?
    let horizontalAccuracy: Double?
    let verticalAccuracy: Double?
    let timestamp: Date
    
    init(
        latitude: Double,
        longitude: Double,
        altitude: Double? = nil,
        horizontalAccuracy: Double? = nil,
        verticalAccuracy: Double? = nil,
        timestamp: Date = Date()
    ) {
        self.latitude = latitude
        self.longitude = longitude
        self.altitude = altitude
        self.horizontalAccuracy = horizontalAccuracy
        self.verticalAccuracy = verticalAccuracy
        self.timestamp = timestamp
    }
}

// MARK: - Device Metadata

struct DeviceMetadata: Sendable, Codable {
    let deviceModel: String
    let deviceName: String
    let systemVersion: String
    let appVersion: String
    let cameraModel: String?
    
    init(
        deviceModel: String = "Unknown",
        deviceName: String = "Unknown",
        systemVersion: String = "Unknown",
        appVersion: String = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown",
        cameraModel: String? = nil
    ) {
        self.deviceModel = deviceModel
        self.deviceName = deviceName
        self.systemVersion = systemVersion
        self.appVersion = appVersion
        self.cameraModel = cameraModel
    }
}

// MARK: - Recording Error

enum RecordingError: LocalizedError, Sendable, Codable {
    case configurationInvalid(String)
    case cameraNotAvailable
    case permissionDenied
    case diskSpaceInsufficient
    case sessionFailed(String)
    case fileSystemError(String)
    case encodingError(String)
    case audioError(String)
    case videoError(String)
    case synchronizationError(String)
    case thermalLimitReached
    case batteryLevelLow
    case memoryLimitReached
    case unknown(String)
    
    var errorDescription: String? {
        switch self {
        case .configurationInvalid(let reason):
            return "Invalid configuration: \(reason)"
        case .cameraNotAvailable:
            return "Camera is not available"
        case .permissionDenied:
            return "Camera permission denied"
        case .diskSpaceInsufficient:
            return "Insufficient disk space"
        case .sessionFailed(let reason):
            return "Recording session failed: \(reason)"
        case .fileSystemError(let reason):
            return "File system error: \(reason)"
        case .encodingError(let reason):
            return "Encoding error: \(reason)"
        case .audioError(let reason):
            return "Audio error: \(reason)"
        case .videoError(let reason):
            return "Video error: \(reason)"
        case .synchronizationError(let reason):
            return "Synchronization error: \(reason)"
        case .thermalLimitReached:
            return "Thermal limit reached"
        case .batteryLevelLow:
            return "Battery level too low"
        case .memoryLimitReached:
            return "Memory limit reached"
        case .unknown(let reason):
            return "Unknown error: \(reason)"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .configurationInvalid:
            return "Check camera configuration and try again"
        case .cameraNotAvailable:
            return "Close other camera apps and try again"
        case .permissionDenied:
            return "Grant camera permission in Settings"
        case .diskSpaceInsufficient:
            return "Free up disk space and try again"
        case .sessionFailed:
            return "Restart the app and try again"
        case .fileSystemError:
            return "Check file permissions and try again"
        case .encodingError:
            return "Try different recording settings"
        case .audioError:
            return "Check audio settings and try again"
        case .videoError:
            return "Check video settings and try again"
        case .synchronizationError:
            return "Try recording with single camera"
        case .thermalLimitReached:
            return "Let device cool down and try again"
        case .batteryLevelLow:
            return "Charge device and try again"
        case .memoryLimitReached:
            return "Close other apps and try again"
        case .unknown:
            return "Restart the app and try again"
        }
    }
    
    var severity: ErrorSeverity {
        switch self {
        case .thermalLimitReached, .batteryLevelLow, .memoryLimitReached:
            return .warning
        case .diskSpaceInsufficient, .permissionDenied:
            return .error
        default:
            return .critical
        }
    }
}

// MARK: - Error Severity

enum ErrorSeverity: String, CaseIterable, Sendable, Codable {
    case info = "Info"
    case warning = "Warning"
    case error = "Error"
    case critical = "Critical"
    
    var color: Color {
        switch self {
        case .info:
            return .blue
        case .warning:
            return .orange
        case .error:
            return .red
        case .critical:
            return .red
        }
    }
    
    var icon: String {
        switch self {
        case .info:
            return "info.circle.fill"
        case .warning:
            return "exclamationmark.triangle.fill"
        case .error:
            return "xmark.circle.fill"
        case .critical:
            return "exclamationmark.octagon.fill"
        }
    }
}

// MARK: - Recording Statistics

struct RecordingStatistics: Sendable, Codable {
    let totalRecordings: Int
    let totalDuration: TimeInterval
    let totalFileSize: Int64
    let averageDuration: TimeInterval
    let averageFileSize: Int64
    let mostUsedQuality: VideoQuality
    let mostUsedFrameRate: Int32
    let recordingsByQuality: [VideoQuality: Int]
    let recordingsByFrameRate: [Int32: Int]
    let recordingsByDate: [Date: Int]
    
    init(
        totalRecordings: Int = 0,
        totalDuration: TimeInterval = 0,
        totalFileSize: Int64 = 0,
        averageDuration: TimeInterval = 0,
        averageFileSize: Int64 = 0,
        mostUsedQuality: VideoQuality = .hd1080,
        mostUsedFrameRate: Int32 = 30,
        recordingsByQuality: [VideoQuality: Int] = [:],
        recordingsByFrameRate: [Int32: Int] = [:],
        recordingsByDate: [Date: Int] = [:]
    ) {
        self.totalRecordings = totalRecordings
        self.totalDuration = totalDuration
        self.totalFileSize = totalFileSize
        self.averageDuration = averageDuration
        self.averageFileSize = averageFileSize
        self.mostUsedQuality = mostUsedQuality
        self.mostUsedFrameRate = mostUsedFrameRate
        self.recordingsByQuality = recordingsByQuality
        self.recordingsByFrameRate = recordingsByFrameRate
        self.recordingsByDate = recordingsByDate
    }
    
    var formattedTotalDuration: String {
        let duration = Int(totalDuration)
        let hours = duration / 3600
        let minutes = (duration % 3600) / 60
        let seconds = duration % 60
        
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
    
    var formattedTotalFileSize: String {
        let byteCountFormatter = ByteCountFormatter()
        byteCountFormatter.allowedUnits = [.useMB, .useGB, .useTB]
        byteCountFormatter.countStyle = .file
        return byteCountFormatter.string(fromByteCount: totalFileSize)
    }
    
    var formattedAverageDuration: String {
        let duration = Int(averageDuration)
        let hours = duration / 3600
        let minutes = (duration % 3600) / 60
        let seconds = duration % 60
        
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
    
    var formattedAverageFileSize: String {
        let byteCountFormatter = ByteCountFormatter()
        byteCountFormatter.allowedUnits = [.useKB, .useMB, .useGB]
        byteCountFormatter.countStyle = .file
        return byteCountFormatter.string(fromByteCount: averageFileSize)
    }
}

// MARK: - Recording State Manager

@MainActor
class RecordingStateManager: ObservableObject {
    @Published var currentSession: RecordingSession?
    @Published var recordingHistory: [RecordingSession] = []
    @Published var statistics: RecordingStatistics = RecordingStatistics()
    
    private let storageService: StorageServiceProtocol
    
    init(storageService: StorageServiceProtocol = StorageService()) {
        self.storageService = storageService
        loadRecordingHistory()
        updateStatistics()
    }
    
    // MARK: - Session Management
    
    func createSession(with configuration: CameraConfiguration) -> RecordingSession {
        let session = RecordingSession(configuration: configuration)
        currentSession = session
        return session
    }
    
    func updateSessionState(_ state: RecordingState) {
        currentSession?.updateState(state)
        
        if state == .completed {
            finalizeSession()
        }
    }
    
    func addRecordingTrack(_ track: RecordingTrack) {
        currentSession?.addRecording(track)
    }
    
    func setSessionError(_ error: RecordingError) {
        currentSession?.setError(error)
    }
    
    private func finalizeSession() {
        guard let session = currentSession else { return }
        
        session.complete()
        recordingHistory.append(session)
        currentSession = nil
        
        saveRecordingHistory()
        updateStatistics()
    }
    
    // MARK: - History Management
    
    func deleteSession(_ session: RecordingSession) {
        // Delete files
        for track in session.recordings {
            try? FileManager.default.removeItem(at: track.url)
        }
        
        // Remove from history
        recordingHistory.removeAll { $0.id == session.id }
        
        saveRecordingHistory()
        updateStatistics()
    }
    
    func clearHistory() {
        // Delete all files
        for session in recordingHistory {
            for track in session.recordings {
                try? FileManager.default.removeItem(at: track.url)
            }
        }
        
        recordingHistory.removeAll()
        
        saveRecordingHistory()
        updateStatistics()
    }
    
    // MARK: - Statistics
    
    private func updateStatistics() {
        let totalRecordings = recordingHistory.count
        let totalDuration = recordingHistory.reduce(0) { $0 + $1.duration }
        let totalFileSize = recordingHistory.reduce(0) { total, session in
            total + session.recordings.reduce(0) { $0 + $1.fileSize }
        }
        
        let averageDuration = totalRecordings > 0 ? totalDuration / Double(totalRecordings) : 0
        let averageFileSize = totalRecordings > 0 ? totalFileSize / Int64(totalRecordings) : 0
        
        // Calculate most used quality and frame rate
        var qualityCounts: [VideoQuality: Int] = [:]
        var frameRateCounts: [Int32: Int] = [:]
        var dateCounts: [Date: Int] = [:]
        
        for session in recordingHistory {
            let quality = session.configuration.quality
            qualityCounts[quality, default: 0] += 1
            
            let frameRate = session.configuration.frameRate
            frameRateCounts[frameRate, default: 0] += 1
            
            let calendar = Calendar.current
            let date = calendar.startOfDay(for: session.startTime)
            dateCounts[date, default: 0] += 1
        }
        
        let mostUsedQuality = qualityCounts.max { $0.value < $1.value }?.key ?? .hd1080
        let mostUsedFrameRate = frameRateCounts.max { $0.value < $1.value }?.key ?? 30
        
        statistics = RecordingStatistics(
            totalRecordings: totalRecordings,
            totalDuration: totalDuration,
            totalFileSize: totalFileSize,
            averageDuration: averageDuration,
            averageFileSize: averageFileSize,
            mostUsedQuality: mostUsedQuality,
            mostUsedFrameRate: mostUsedFrameRate,
            recordingsByQuality: qualityCounts,
            recordingsByFrameRate: frameRateCounts,
            recordingsByDate: dateCounts
        )
    }
    
    // MARK: - Persistence
    
    private func loadRecordingHistory() {
        // Load recording history from storage
        if let data = UserDefaults.standard.data(forKey: "RecordingHistory"),
           let history = try? JSONDecoder().decode([RecordingSession].self, from: data) {
            recordingHistory = history
        }
    }
    
    private func saveRecordingHistory() {
        // Save recording history to storage
        if let data = try? JSONEncoder().encode(recordingHistory) {
            UserDefaults.standard.set(data, forKey: "RecordingHistory")
        }
    }
}

// MARK: - Storage Service Protocol

protocol StorageServiceProtocol {
    func saveRecording(_ track: RecordingTrack) throws -> URL
    func loadRecording(from url: URL) throws -> Data
    func deleteRecording(at url: URL) throws
    func getAvailableSpace() -> Int64
}

// MARK: - Storage Service

class StorageService: StorageServiceProtocol {
    
    func saveRecording(_ track: RecordingTrack) throws -> URL {
        // Implementation would save the recording file
        return track.url
    }
    
    func loadRecording(from url: URL) throws -> Data {
        return try Data(contentsOf: url)
    }
    
    func deleteRecording(at url: URL) throws {
        try FileManager.default.removeItem(at: url)
    }
    
    func getAvailableSpace() -> Int64 {
        let documentPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        do {
            let attributes = try FileManager.default.attributesOfFileSystem(forPath: documentPath.path)
            return attributes[.systemFreeSize] as? Int64 ?? 0
        } catch {
            return 0
        }
    }
}