//
//  SettingsManager.swift
//  DualCameraApp
//
//  Centralized settings management for user preferences and quality persistence
//

import Foundation
import AVFoundation

class SettingsManager {
    static let shared = SettingsManager()
    
    private let userDefaults = UserDefaults.standard
    
    // MARK: - Setting Keys
    
    private enum Keys {
        static let videoQuality = "DualCamera.VideoQuality"
        static let recordingLayout = "DualCamera.RecordingLayout"
        static let enableTripleOutput = "DualCamera.EnableTripleOutput"
        static let enableHapticFeedback = "DualCamera.EnableHapticFeedback"
        static let enableVisualCountdown = "DualCamera.EnableVisualCountdown"
        static let countdownDuration = "DualCamera.CountdownDuration"
        static let flashMode = "DualCamera.FlashMode"
        static let autoFocusEnabled = "DualCamera.AutoFocusEnabled"
        static let enableGrid = "DualCamera.EnableGrid"
        static let defaultCamera = "DualCamera.DefaultCamera"
        static let videoOrientation = "DualCamera.VideoOrientation"
        static let audioSource = "DualCamera.AudioSource"
        static let enableNoiseReduction = "DualCamera.EnableNoiseReduction"
        static let recordingQualityAdaptive = "DualCamera.RecordingQualityAdaptive"
        static let maxRecordingDuration = "DualCamera.MaxRecordingDuration"
        static let autoSaveToPhotoLibrary = "DualCamera.AutoSaveToPhotoLibrary"
        static let enablePerformanceMonitoring = "DualCamera.EnablePerformanceMonitoring"
    }
    
    private init() {
        registerDefaultSettings()
    }
    
    // MARK: - Default Settings Registration
    
    private func registerDefaultSettings() {
        let defaults: [String: Any] = [
            Keys.videoQuality: VideoQuality.hd1080.rawValue,
            Keys.recordingLayout: "sideBySide",
            Keys.enableTripleOutput: true,
            Keys.enableHapticFeedback: true,
            Keys.enableVisualCountdown: false,
            Keys.countdownDuration: 3,
            Keys.flashMode: "off",
            Keys.autoFocusEnabled: true,
            Keys.enableGrid: false,
            Keys.defaultCamera: "back",
            Keys.videoOrientation: "portrait",
            Keys.audioSource: "builtIn",
            Keys.enableNoiseReduction: true,
            Keys.recordingQualityAdaptive: true,
            Keys.maxRecordingDuration: 300, // 5 minutes
            Keys.autoSaveToPhotoLibrary: true,
            Keys.enablePerformanceMonitoring: true
        ]
        
        userDefaults.register(defaults: defaults)
    }
    
    // MARK: - Video Quality Settings
    
    var videoQuality: VideoQuality {
        get {
            let rawValue = userDefaults.string(forKey: Keys.videoQuality) ?? VideoQuality.hd1080.rawValue
            return VideoQuality(rawValue: rawValue) ?? .hd1080
        }
        set {
            userDefaults.set(newValue.rawValue, forKey: Keys.videoQuality)
        }
    }
    
    var recordingLayout: String {
        get {
            return userDefaults.string(forKey: Keys.recordingLayout) ?? "sideBySide"
        }
        set {
            userDefaults.set(newValue, forKey: Keys.recordingLayout)
        }
    }
    
    var enableTripleOutput: Bool {
        get {
            return userDefaults.bool(forKey: Keys.enableTripleOutput)
        }
        set {
            userDefaults.set(newValue, forKey: Keys.enableTripleOutput)
        }
    }
    
    // MARK: - Recording Control Settings
    
    var enableHapticFeedback: Bool {
        get {
            return userDefaults.bool(forKey: Keys.enableHapticFeedback)
        }
        set {
            userDefaults.set(newValue, forKey: Keys.enableHapticFeedback)
            HapticFeedbackManager.shared.updateHapticSettings(enabled: newValue)
        }
    }
    
    var enableVisualCountdown: Bool {
        get {
            return userDefaults.bool(forKey: Keys.enableVisualCountdown)
        }
        set {
            userDefaults.set(newValue, forKey: Keys.enableVisualCountdown)
        }
    }
    
    var countdownDuration: Int {
        get {
            return userDefaults.integer(forKey: Keys.countdownDuration)
        }
        set {
            userDefaults.set(newValue, forKey: Keys.countdownDuration)
        }
    }
    
    var maxRecordingDuration: Int {
        get {
            return userDefaults.integer(forKey: Keys.maxRecordingDuration)
        }
        set {
            userDefaults.set(newValue, forKey: Keys.maxRecordingDuration)
        }
    }
    
    // MARK: - Camera Settings
    
    var flashMode: String {
        get {
            return userDefaults.string(forKey: Keys.flashMode) ?? "off"
        }
        set {
            userDefaults.set(newValue, forKey: Keys.flashMode)
        }
    }
    
    var autoFocusEnabled: Bool {
        get {
            return userDefaults.bool(forKey: Keys.autoFocusEnabled)
        }
        set {
            userDefaults.set(newValue, forKey: Keys.autoFocusEnabled)
        }
    }
    
    var enableGrid: Bool {
        get {
            return userDefaults.bool(forKey: Keys.enableGrid)
        }
        set {
            userDefaults.set(newValue, forKey: Keys.enableGrid)
        }
    }
    
    var defaultCamera: String {
        get {
            return userDefaults.string(forKey: Keys.defaultCamera) ?? "back"
        }
        set {
            userDefaults.set(newValue, forKey: Keys.defaultCamera)
        }
    }
    
    // MARK: - Audio Settings
    
    var audioSource: String {
        get {
            return userDefaults.string(forKey: Keys.audioSource) ?? "builtIn"
        }
        set {
            userDefaults.set(newValue, forKey: Keys.audioSource)
        }
    }
    
    var enableNoiseReduction: Bool {
        get {
            return userDefaults.bool(forKey: Keys.enableNoiseReduction)
        }
        set {
            userDefaults.set(newValue, forKey: Keys.enableNoiseReduction)
        }
    }
    
    // MARK: - Performance Settings
    
    var recordingQualityAdaptive: Bool {
        get {
            return userDefaults.bool(forKey: Keys.recordingQualityAdaptive)
        }
        set {
            userDefaults.set(newValue, forKey: Keys.recordingQualityAdaptive)
        }
    }
    
    var enablePerformanceMonitoring: Bool {
        get {
            return userDefaults.bool(forKey: Keys.enablePerformanceMonitoring)
        }
        set {
            userDefaults.set(newValue, forKey: Keys.enablePerformanceMonitoring)
        }
    }
    
    // MARK: - Storage Settings
    
    var autoSaveToPhotoLibrary: Bool {
        get {
            return userDefaults.bool(forKey: Keys.autoSaveToPhotoLibrary)
        }
        set {
            userDefaults.set(newValue, forKey: Keys.autoSaveToPhotoLibrary)
        }
    }
    
    // MARK: - Settings Management
    
    func resetToDefaults() {
        let domain = Bundle.main.bundleIdentifier!
        userDefaults.removePersistentDomain(forName: domain)
        registerDefaultSettings()
    }
    
    func exportSettings() -> [String: Any] {
        return [
            "videoQuality": videoQuality.rawValue,
            "enableTripleOutput": enableTripleOutput,
            "enableHapticFeedback": enableHapticFeedback,
            "enableVisualCountdown": enableVisualCountdown,
            "countdownDuration": countdownDuration,
            "flashMode": flashMode,
            "autoFocusEnabled": autoFocusEnabled,
            "enableGrid": enableGrid,
            "defaultCamera": defaultCamera,
            "audioSource": audioSource,
            "enableNoiseReduction": enableNoiseReduction,
            "recordingQualityAdaptive": recordingQualityAdaptive,
            "maxRecordingDuration": maxRecordingDuration,
            "autoSaveToPhotoLibrary": autoSaveToPhotoLibrary,
            "enablePerformanceMonitoring": enablePerformanceMonitoring
        ]
    }
    
    func importSettings(_ settings: [String: Any]) {
        if let videoQuality = settings["videoQuality"] as? String,
           let quality = VideoQuality(rawValue: videoQuality) {
            self.videoQuality = quality
        }
        
        if let enableTripleOutput = settings["enableTripleOutput"] as? Bool {
            self.enableTripleOutput = enableTripleOutput
        }
        
        if let enableHapticFeedback = settings["enableHapticFeedback"] as? Bool {
            self.enableHapticFeedback = enableHapticFeedback
        }
        
        if let enableVisualCountdown = settings["enableVisualCountdown"] as? Bool {
            self.enableVisualCountdown = enableVisualCountdown
        }
        
        if let countdownDuration = settings["countdownDuration"] as? Int {
            self.countdownDuration = countdownDuration
        }
        
        if let flashMode = settings["flashMode"] as? String {
            self.flashMode = flashMode
        }
        
        if let autoFocusEnabled = settings["autoFocusEnabled"] as? Bool {
            self.autoFocusEnabled = autoFocusEnabled
        }
        
        if let enableGrid = settings["enableGrid"] as? Bool {
            self.enableGrid = enableGrid
        }
        
        if let defaultCamera = settings["defaultCamera"] as? String {
            self.defaultCamera = defaultCamera
        }
        
        if let audioSource = settings["audioSource"] as? String {
            self.audioSource = audioSource
        }
        
        if let enableNoiseReduction = settings["enableNoiseReduction"] as? Bool {
            self.enableNoiseReduction = enableNoiseReduction
        }
        
        if let recordingQualityAdaptive = settings["recordingQualityAdaptive"] as? Bool {
            self.recordingQualityAdaptive = recordingQualityAdaptive
        }
        
        if let maxRecordingDuration = settings["maxRecordingDuration"] as? Int {
            self.maxRecordingDuration = maxRecordingDuration
        }
        
        if let autoSaveToPhotoLibrary = settings["autoSaveToPhotoLibrary"] as? Bool {
            self.autoSaveToPhotoLibrary = autoSaveToPhotoLibrary
        }
        
        if let enablePerformanceMonitoring = settings["enablePerformanceMonitoring"] as? Bool {
            self.enablePerformanceMonitoring = enablePerformanceMonitoring
        }
    }
    
    // MARK: - Settings Validation
    
    func validateSettings() -> [String] {
        var issues: [String] = []
        
        if countdownDuration < 1 || countdownDuration > 10 {
            issues.append("Countdown duration should be between 1 and 10 seconds")
        }
        
        if maxRecordingDuration < 10 || maxRecordingDuration > 3600 {
            issues.append("Maximum recording duration should be between 10 seconds and 1 hour")
        }
        
        return issues
    }
    
    // MARK: - Device-specific Settings
    
    func applyDeviceSpecificSettings() {
        // Adjust settings based on device capabilities
        let device = AVCaptureDevice.default(for: .video)
        
        if let device = device {
            let dimensions = CMVideoFormatDescriptionGetDimensions(device.activeFormat.formatDescription)
            let supports4K = dimensions.width >= 3840
            
            if !supports4K && videoQuality == .uhd4k {
                videoQuality = .hd1080
            }
        }
        
        // Adjust performance settings based on device memory
        let physicalMemory = ProcessInfo.processInfo.physicalMemory
        if physicalMemory < 2_000_000_000 { // Less than 2GB
            recordingQualityAdaptive = true
            enableTripleOutput = false // Disable on low-memory devices
        }
    }
    
    // MARK: - Debug Settings
    
    var debugMode: Bool {
        get {
            return userDefaults.bool(forKey: "DualCamera.DebugMode")
        }
        set {
            userDefaults.set(newValue, forKey: "DualCamera.DebugMode")
        }
    }
    
    var verboseLogging: Bool {
        get {
            return userDefaults.bool(forKey: "DualCamera.VerboseLogging")
        }
        set {
            userDefaults.set(newValue, forKey: "DualCamera.VerboseLogging")
        }
    }
}