//
//  SettingsManager.swift
//  DualApp
//
//  Created by DualApp Team on 10/3/25.
//

import Foundation
import SwiftUI
import CloudKit
import Combine

// MARK: - Settings Manager Actor

actor SettingsManager: Sendable {
    
    // MARK: - Singleton
    
    static let shared = SettingsManager()
    
    // MARK: - Properties
    
    private var userSettings: UserSettings
    private var cloudSettings: CloudSettings
    private var isCloudSyncEnabled: Bool = true
    private var lastSyncDate: Date?
    private var syncInProgress: Bool = false
    
    // MARK: - Event Streams
    
    let events: AsyncStream<SettingsEvent>
    private let eventContinuation: AsyncStream<SettingsEvent>.Continuation
    
    // MARK: - CloudKit
    
    private let container: CKContainer
    private let privateDatabase: CKDatabase
    private let subscriptionID = "userSettingsSubscription"
    
    // MARK: - Local Storage
    
    private let userDefaults: UserDefaults
    private let settingsKey = "dualApp_userSettings"
    private let cloudSettingsKey = "dualApp_cloudSettings"
    
    // MARK: - Initialization
    
    private init() {
        (self.events, self.eventContinuation) = AsyncStream<SettingsEvent>.makeStream()
        
        // Initialize CloudKit
        self.container = CKContainer(identifier: "icloud.dualapp.settings")
        self.privateDatabase = container.privateCloudDatabase
        
        // Initialize UserDefaults
        self.userDefaults = UserDefaults.standard
        
        // Load settings
        self.userSettings = Self.loadLocalSettings(from: userDefaults) ?? UserSettings.default
        self.cloudSettings = Self.loadCloudSettings(from: userDefaults) ?? CloudSettings.default
        
        // Setup cloud sync
        Task {
            await setupCloudSync()
        }
    }
    
    // MARK: - Public Interface
    
    func getSettings() async -> UserSettings {
        return userSettings
    }
    
    func updateSettings(_ settings: UserSettings) async throws {
        let oldSettings = userSettings
        userSettings = settings
        
        // Save locally
        await saveLocalSettings(settings)
        
        // Sync to cloud if enabled
        if isCloudSyncEnabled {
            try await syncToCloud(settings)
        }
        
        // Notify listeners
        eventContinuation.yield(.settingsChanged(oldSettings: oldSettings, newSettings: settings))
    }
    
    func updateSetting<T: Codable & Sendable>(keyPath: WritableKeyPath<UserSettings, T>, value: T) async throws {
        var newSettings = userSettings
        newSettings[keyPath: keyPath] = value
        try await updateSettings(newSettings)
    }
    
    func resetToDefaults() async throws {
        try await updateSettings(UserSettings.default)
    }
    
    func exportSettings() async throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        return try encoder.encode(userSettings)
    }
    
    func importSettings(from data: Data) async throws {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let importedSettings = try decoder.decode(UserSettings.self, from: data)
        try await updateSettings(importedSettings)
    }
    
    func enableCloudSync(_ enabled: Bool) async throws {
        isCloudSyncEnabled = enabled
        
        if enabled {
            await setupCloudSync()
            try await syncFromCloud()
        }
        
        eventContinuation.yield(.cloudSyncChanged(enabled))
    }
    
    func forceSyncToCloud() async throws {
        guard isCloudSyncEnabled else {
            throw SettingsError.cloudSyncDisabled
        }
        
        try await syncToCloud(userSettings)
    }
    
    func forceSyncFromCloud() async throws {
        guard isCloudSyncEnabled else {
            throw SettingsError.cloudSyncDisabled
        }
        
        try await syncFromCloud()
    }
    
    func getSyncStatus() async -> SyncStatus {
        return SyncStatus(
            isCloudSyncEnabled: isCloudSyncEnabled,
            lastSyncDate: lastSyncDate,
            syncInProgress: syncInProgress,
            cloudAvailable: await isCloudAvailable()
        )
    }
    
    // MARK: - Cloud Sync Methods
    
    private func setupCloudSync() async {
        do {
            // Check account status
            let accountStatus = try await container.accountStatus()
            
            switch accountStatus {
            case .available:
                // Setup subscription for remote changes
                try await setupCloudSubscription()
                eventContinuation.yield(.cloudSyncStatusChanged(.available))
                
            case .noAccount:
                eventContinuation.yield(.cloudSyncStatusChanged(.noAccount))
                isCloudSyncEnabled = false
                
            case .restricted:
                eventContinuation.yield(.cloudSyncStatusChanged(.restricted))
                isCloudSyncEnabled = false
                
            case .couldNotDetermine:
                eventContinuation.yield(.cloudSyncStatusChanged(.unknown))
                isCloudSyncEnabled = false
                
            case .temporarilyUnavailable:
                eventContinuation.yield(.cloudSyncStatusChanged(.temporarilyUnavailable))
                
            @unknown default:
                eventContinuation.yield(.cloudSyncStatusChanged(.unknown))
                isCloudSyncEnabled = false
            }
        } catch {
            eventContinuation.yield(.cloudSyncError(error))
            isCloudSyncEnabled = false
        }
    }
    
    private func setupCloudSubscription() async throws {
        let subscriptionID = subscriptionID
        
        // Check if subscription already exists
        let subscription = CKQuerySubscription(
            recordType: "UserSettings",
            predicate: NSPredicate(value: true),
            subscriptionID: subscriptionID
        )
        
        let notificationInfo = CKSubscription.NotificationInfo()
        notificationInfo.shouldSendContentAvailable = true
        subscription.notificationInfo = notificationInfo
        
        try await privateDatabase.save(subscription)
    }
    
    private func syncToCloud(_ settings: UserSettings) async throws {
        guard !syncInProgress else { return }
        
        syncInProgress = true
        defer { syncInProgress = false }
        
        do {
            let record = try await createSettingsRecord(from: settings)
            let savedRecord = try await privateDatabase.save(record)
            
            // Update cloud settings metadata
            cloudSettings = CloudSettings(
                recordID: savedRecord.recordID,
                lastModified: savedRecord.modificationDate ?? Date(),
                deviceName: await getDeviceName()
            )
            
            lastSyncDate = Date()
            await saveCloudSettings(cloudSettings)
            
            eventContinuation.yield(.cloudSyncCompleted(.upload))
        } catch {
            eventContinuation.yield(.cloudSyncError(error))
            throw SettingsError.cloudSyncFailed(error.localizedDescription)
        }
    }
    
    private func syncFromCloud() async throws {
        guard !syncInProgress else { return }
        
        syncInProgress = true
        defer { syncInProgress = false }
        
        do {
            let query = CKQuery(recordType: "UserSettings", predicate: NSPredicate(value: true))
            let result = try await privateDatabase.records(matching: query)
            
            for (_, recordResult) in result.matchResults {
                switch recordResult {
                case .success(let record):
                    let settings = try await createSettings(from: record)
                    let oldSettings = userSettings
                    userSettings = settings
                    
                    await saveLocalSettings(settings)
                    
                    // Update cloud settings metadata
                    let deviceName: String
                    if let recordDeviceName = record["deviceName"] as? String {
                        deviceName = recordDeviceName
                    } else {
                        deviceName = await getDeviceName()
                    }
                    cloudSettings = CloudSettings(
                        recordID: record.recordID,
                        lastModified: record.modificationDate ?? Date(),
                        deviceName: deviceName
                    )
                    
                    lastSyncDate = Date()
                    await saveCloudSettings(cloudSettings)
                    
                    eventContinuation.yield(.settingsChanged(oldSettings: oldSettings, newSettings: settings))
                    eventContinuation.yield(.cloudSyncCompleted(.download))
                    
                case .failure(let error):
                    eventContinuation.yield(.cloudSyncError(error))
                }
            }
        } catch {
            eventContinuation.yield(.cloudSyncError(error))
            throw SettingsError.cloudSyncFailed(error.localizedDescription)
        }
    }
    
    private func createSettingsRecord(from settings: UserSettings) async throws -> CKRecord {
        let record = CKRecord(recordType: "UserSettings")
        
        // Encode settings to data
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(settings)
        
        record["settingsData"] = data
        record["deviceName"] = await getDeviceName()
        record["appVersion"] = await getAppVersion()
        record["settingsVersion"] = UserSettings.version
        
        return record
    }
    
    private func createSettings(from record: CKRecord) async throws -> UserSettings {
        guard let data = record["settingsData"] as? Data else {
            throw SettingsError.invalidCloudData
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(UserSettings.self, from: data)
    }
    
    private func isCloudAvailable() async -> Bool {
        do {
            let accountStatus = try await container.accountStatus()
            return accountStatus == .available
        } catch {
            return false
        }
    }
    
    // MARK: - Local Storage Methods
    
    private func saveLocalSettings(_ settings: UserSettings) async {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        do {
            let data = try encoder.encode(settings)
            userDefaults.set(data, forKey: settingsKey)
        } catch {
            eventContinuation.yield(.localSaveError(error))
        }
    }
    
    private func saveCloudSettings(_ settings: CloudSettings) async {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        do {
            let data = try encoder.encode(settings)
            userDefaults.set(data, forKey: cloudSettingsKey)
        } catch {
            eventContinuation.yield(.localSaveError(error))
        }
    }
    
    private static func loadLocalSettings(from userDefaults: UserDefaults) -> UserSettings? {
        guard let data = userDefaults.data(forKey: "dualApp_userSettings") else {
            return nil
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        do {
            return try decoder.decode(UserSettings.self, from: data)
        } catch {
            return nil
        }
    }
    
    private static func loadCloudSettings(from userDefaults: UserDefaults) -> CloudSettings? {
        guard let data = userDefaults.data(forKey: "dualApp_cloudSettings") else {
            return nil
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        do {
            return try decoder.decode(CloudSettings.self, from: data)
        } catch {
            return nil
        }
    }
    
    // MARK: - Utility Methods
    
    private func getDeviceName() async -> String {
        return await UIDevice.current.name
    }
    
    private func getAppVersion() async -> String {
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }
}

// MARK: - Settings Event

enum SettingsEvent: Sendable {
    case settingsChanged(oldSettings: UserSettings, newSettings: UserSettings)
    case cloudSyncChanged(Bool)
    case cloudSyncStatusChanged(CloudSyncStatus)
    case cloudSyncCompleted(CloudSyncDirection)
    case cloudSyncError(Error)
    case localSaveError(Error)
    case settingsReset
    case settingsImported
    case settingsExported
}

// MARK: - Settings Models

struct UserSettings: Codable, Sendable {
    static let version = "1.0.0"
    static let `default` = UserSettings()
    
    // MARK: - Camera Settings
    
    var cameraSettings: CameraSettings = CameraSettings.default
    
    // MARK: - Audio Settings
    
    var audioSettings: AudioSettings = AudioSettings.default
    
    // MARK: - Video Settings
    
    var videoSettings: VideoSettings = VideoSettings.default
    
    // MARK: - UI Settings
    
    var uiSettings: UISettings = UISettings.default
    
    // MARK: - Performance Settings
    
    var performanceSettings: PerformanceSettings = PerformanceSettings.default
    
    // MARK: - General Settings
    
    var generalSettings: GeneralSettings = GeneralSettings.default
    
    // MARK: - Metadata
    
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var settingsVersion: String = version
}

struct CameraSettings: Codable, Sendable {
    static let `default` = CameraSettings()
    
    var defaultCameraPosition: CameraPosition = .back
    var flashMode: FlashMode = .auto
    var focusMode: FocusMode = .autoFocus
    var exposureMode: ExposureMode = .autoExposure
    var whiteBalanceMode: WhiteBalanceMode = .autoWhiteBalance
    var videoStabilizationEnabled: Bool = true
    var highResolutionPhotoEnabled: Bool = true
    var portraitModeEnabled: Bool = false
    var nightModeEnabled: Bool = false
    var livePhotoEnabled: Bool = false
    var hdrEnabled: Bool = true
    var gridEnabled: Bool = false
    var mirrorFrontCamera: Bool = true
    var preserveSettings: Bool = true
}

struct AudioSettings: Codable, Sendable {
    static let `default` = AudioSettings()
    
    var audioRecordingEnabled: Bool = true
    var audioQuality: AudioQuality = .high
    var audioFormat: AudioFormat = .aac
    var sampleRate: SampleRate = .hz48000
    var bitRate: BitRate = .kbps128
    var channels: AudioChannels = .stereo
    var noiseReductionEnabled: Bool = true
    var echoCancellationEnabled: Bool = true
    var automaticGainControlEnabled: Bool = true
    var audioBoostEnabled: Bool = false
    var audioBoostLevel: Float = 1.0
    var limiterEnabled: Bool = true
    var compressorEnabled: Bool = false
}

struct VideoSettings: Codable, Sendable {
    static let `default` = VideoSettings()
    
    var videoQuality: VideoQuality = .hd1080
    var frameRate: FrameRate = .fps30
    var codec: VideoCodec = .h264
    var bitrateMode: BitrateMode = .variable
    var keyframeInterval: Int = 30
    var maxBitrate: Int = 10000000
    var averageBitrate: Int = 5000000
    var dualCameraMode: DualCameraMode = .pictureInPicture
    var recordingFormat: RecordingFormat = .mp4
    var timeLapseEnabled: Bool = false
    var slowMotionEnabled: Bool = false
    var slowMotionRate: SlowMotionRate = .x120
}

struct UISettings: Codable, Sendable {
    static let `default` = UISettings()
    
    var theme: AppTheme = .dark
    var accentColor: AccentColor = .blue
    var liquidGlassIntensity: Double = 0.5
    var animationSpeed: AnimationSpeed = .normal
    var hapticFeedbackEnabled: Bool = true
    var hapticIntensity: HapticIntensity = .medium
    var soundEffectsEnabled: Bool = true
    var soundVolume: Double = 0.5
    var accessibilityEnabled: Bool = false
    var largeTextEnabled: Bool = false
    var highContrastEnabled: Bool = false
    var reduceMotionEnabled: Bool = false
    var showTooltips: Bool = true
    var showHints: Bool = true
}

struct PerformanceSettings: Codable, Sendable {
    static let `default` = PerformanceSettings()
    
    var thermalManagementEnabled: Bool = true
    var batteryOptimizationEnabled: Bool = true
    var memoryManagementEnabled: Bool = true
    var adaptiveQualityEnabled: Bool = true
    var backgroundProcessingEnabled: Bool = true
    var cachingEnabled: Bool = true
    var cacheSize: Int = 1024 * 1024 * 1024 // 1GB
    var maxRecordingDuration: TimeInterval = 3600 // 1 hour
    var autoStopOnLowBattery: Bool = true
    var lowBatteryThreshold: Double = 0.1
    var autoStopOnHighTemperature: Bool = true
    var highTemperatureThreshold: Double = 0.8
}

struct GeneralSettings: Codable, Sendable {
    static let `default` = GeneralSettings()
    
    var autoSaveToGallery: Bool = true
    var includeLocationMetadata: Bool = false
    var includeDateTimeMetadata: Bool = true
    var includeDeviceMetadata: Bool = true
    var analyticsEnabled: Bool = false
    var crashReportingEnabled: Bool = true
    var usageDataEnabled: Bool = false
    var betaFeaturesEnabled: Bool = false
    var debugModeEnabled: Bool = false
    var developerOptionsEnabled: Bool = false
    var automaticUpdatesEnabled: Bool = true
    var wifiOnlyDownloads: Bool = true
    var cellularDataEnabled: Bool = false
}

// MARK: - Cloud Settings

struct CloudSettings: Codable, Sendable {
    static let `default` = CloudSettings()

    var recordID: CKRecord.ID?
    var lastModified: Date?
    var deviceName: String?
    var appVersion: String?
    var settingsVersion: String?

    enum CodingKeys: String, CodingKey {
        case lastModified, deviceName, appVersion, settingsVersion
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        recordID = nil // CKRecord.ID is not codable, so we skip it
        lastModified = try container.decodeIfPresent(Date.self, forKey: .lastModified)
        deviceName = try container.decodeIfPresent(String.self, forKey: .deviceName)
        appVersion = try container.decodeIfPresent(String.self, forKey: .appVersion)
        settingsVersion = try container.decodeIfPresent(String.self, forKey: .settingsVersion)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(lastModified, forKey: .lastModified)
        try container.encodeIfPresent(deviceName, forKey: .deviceName)
        try container.encodeIfPresent(appVersion, forKey: .appVersion)
        try container.encodeIfPresent(settingsVersion, forKey: .settingsVersion)
    }

    init(recordID: CKRecord.ID? = nil, lastModified: Date? = nil, deviceName: String? = nil, appVersion: String? = nil, settingsVersion: String? = nil) {
        self.recordID = recordID
        self.lastModified = lastModified
        self.deviceName = deviceName
        self.appVersion = appVersion
        self.settingsVersion = settingsVersion
    }
}

// MARK: - Sync Status

struct SyncStatus: Sendable {
    let isCloudSyncEnabled: Bool
    let lastSyncDate: Date?
    let syncInProgress: Bool
    let cloudAvailable: Bool
    
    var lastSyncFormatted: String {
        guard let lastSyncDate = lastSyncDate else {
            return "Never"
        }
        
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: lastSyncDate, relativeTo: Date())
    }
}

// MARK: - Supporting Enums

enum CloudSyncStatus: String, Sendable {
    case available = "available"
    case noAccount = "noAccount"
    case restricted = "restricted"
    case temporarilyUnavailable = "temporarilyUnavailable"
    case unknown = "unknown"
}

enum CloudSyncDirection: String, Sendable {
    case upload = "upload"
    case download = "download"
}

enum CameraPosition: String, Codable, CaseIterable, Sendable {
    case front = "front"
    case back = "back"
    case dual = "dual"
}

enum FlashMode: String, Codable, CaseIterable, Sendable {
    case off = "off"
    case on = "on"
    case auto = "auto"
}

enum FocusMode: String, Codable, CaseIterable, Sendable {
    case autoFocus = "autoFocus"
    case locked = "locked"
    case continuousAutoFocus = "continuousAutoFocus"
    case manual = "manual"
}

enum ExposureMode: String, Codable, CaseIterable, Sendable {
    case autoExposure = "autoExposure"
    case locked = "locked"
    case continuousAutoExposure = "continuousAutoExposure"
    case manual = "manual"
}

enum WhiteBalanceMode: String, Codable, CaseIterable, Sendable {
    case autoWhiteBalance = "autoWhiteBalance"
    case locked = "locked"
    case continuousAutoWhiteBalance = "continuousAutoWhiteBalance"
    case daylight = "daylight"
    case cloudy = "cloudy"
    case tungsten = "tungsten"
    case fluorescent = "fluorescent"
}

enum SampleRate: String, Codable, CaseIterable, Sendable {
    case hz8000 = "8000"
    case hz16000 = "16000"
    case hz22050 = "22050"
    case hz44100 = "44100"
    case hz48000 = "48000"
    case hz96000 = "96000"
    case hz192000 = "192000"
}

enum BitRate: String, Codable, CaseIterable, Sendable {
    case kbps64 = "64000"
    case kbps96 = "96000"
    case kbps128 = "128000"
    case kbps160 = "160000"
    case kbps192 = "192000"
    case kbps256 = "256000"
    case kbps320 = "320000"
}

enum AudioChannels: String, Codable, CaseIterable, Sendable {
    case mono = "mono"
    case stereo = "stereo"
}

enum FrameRate: String, Codable, CaseIterable, Sendable {
    case fps24 = "24"
    case fps30 = "30"
    case fps60 = "60"
    case fps120 = "120"
    case fps240 = "240"
}

enum VideoCodec: String, Codable, CaseIterable, Sendable {
    case h264 = "h264"
    case h265 = "h265"
    case hevc = "hevc"
    case proRes = "proRes"
}

enum BitrateMode: String, Codable, CaseIterable, Sendable {
    case constant = "constant"
    case variable = "variable"
}

enum DualCameraMode: String, Codable, CaseIterable, Sendable {
    case pictureInPicture = "pictureInPicture"
    case splitScreen = "splitScreen"
    case sideBySide = "sideBySide"
    case overlay = "overlay"
}

enum RecordingFormat: String, Codable, CaseIterable, Sendable {
    case mp4 = "mp4"
    case mov = "mov"
    case m4v = "m4v"
}

enum SlowMotionRate: String, Codable, CaseIterable, Sendable {
    case x60 = "60"
    case x120 = "120"
    case x240 = "240"
}

enum AppTheme: String, Codable, CaseIterable, Sendable, CustomStringConvertible {
    case light = "light"
    case dark = "dark"
    case system = "system"
    case auto = "auto"

    var description: String {
        switch self {
        case .light:
            return "Light"
        case .dark:
            return "Dark"
        case .system:
            return "System"
        case .auto:
            return "Auto"
        }
    }
}

enum AccentColor: String, Codable, CaseIterable, Sendable, CustomStringConvertible {
    case blue = "blue"
    case green = "green"
    case orange = "orange"
    case red = "red"
    case purple = "purple"
    case pink = "pink"
    case yellow = "yellow"
    case teal = "teal"

    var description: String {
        switch self {
        case .blue:
            return "Blue"
        case .green:
            return "Green"
        case .orange:
            return "Orange"
        case .red:
            return "Red"
        case .purple:
            return "Purple"
        case .pink:
            return "Pink"
        case .yellow:
            return "Yellow"
        case .teal:
            return "Teal"
        }
    }
}

enum AnimationSpeed: String, Codable, CaseIterable, Sendable {
    case slow = "slow"
    case normal = "normal"
    case fast = "fast"
}

enum HapticIntensity: String, Codable, CaseIterable, Sendable {
    case light = "light"
    case medium = "medium"
    case heavy = "heavy"
}

// MARK: - Settings Error

enum SettingsError: LocalizedError, Sendable {
    case cloudSyncDisabled
    case cloudSyncFailed(String)
    case invalidCloudData
    case networkUnavailable
    case authenticationFailed
    case quotaExceeded
    case settingsCorrupted
    case importFailed(String)
    case exportFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .cloudSyncDisabled:
            return "Cloud sync is disabled"
        case .cloudSyncFailed(let reason):
            return "Cloud sync failed: \(reason)"
        case .invalidCloudData:
            return "Invalid cloud data"
        case .networkUnavailable:
            return "Network is unavailable"
        case .authenticationFailed:
            return "Authentication failed"
        case .quotaExceeded:
            return "iCloud quota exceeded"
        case .settingsCorrupted:
            return "Settings are corrupted"
        case .importFailed(let reason):
            return "Import failed: \(reason)"
        case .exportFailed(let reason):
            return "Export failed: \(reason)"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .cloudSyncDisabled:
            return "Enable cloud sync in settings"
        case .cloudSyncFailed:
            return "Check your internet connection and try again"
        case .invalidCloudData:
            return "Reset settings to defaults"
        case .networkUnavailable:
            return "Check your internet connection"
        case .authenticationFailed:
            return "Sign in to iCloud"
        case .quotaExceeded:
            return "Free up space in iCloud"
        case .settingsCorrupted:
            return "Reset settings to defaults"
        case .importFailed:
            return "Check the file format and try again"
        case .exportFailed:
            return "Try exporting again"
        }
    }
}