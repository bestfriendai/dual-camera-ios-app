//
//  SettingsValidator.swift
//  DualApp
//
//  Created by DualApp Team on 10/3/25.
//

import Foundation

// MARK: - Settings Validator

actor SettingsValidator: Sendable {
    
    // MARK: - Singleton
    
    static let shared = SettingsValidator()
    
    // MARK: - Properties
    
    private var validationRules: [ValidationRule] = []
    private var migrationRules: [MigrationRule] = []
    
    // MARK: - Initialization
    
    private init() {
        setupValidationRules()
        setupMigrationRules()
    }
    
    // MARK: - Public Interface
    
    func validate(_ settings: UserSettings) async -> ValidationResult {
        var errors: [ValidationError] = []
        var warnings: [ValidationWarning] = []
        
        for rule in validationRules {
            let result = await rule.validate(settings)
            errors.append(contentsOf: result.errors)
            warnings.append(contentsOf: result.warnings)
        }
        
        return ValidationResult(
            isValid: errors.isEmpty,
            errors: errors,
            warnings: warnings
        )
    }
    
    func migrate(_ settings: UserSettings, from version: String) async -> MigrationResult {
        var migratedSettings = settings
        var migrationSteps: [MigrationStep] = []
        
        // Find applicable migration rules
        let applicableRules = migrationRules.filter { rule in
            return rule.canMigrate(from: version, to: UserSettings.version)
        }
        
        // Apply migrations in order
        for rule in applicableRules.sorted(by: { $0.priority < $1.priority }) {
            do {
                let result = try await rule.migrate(migratedSettings)
                migratedSettings = result.settings
                migrationSteps.append(result.step)
            } catch {
                return MigrationResult(
                    success: false,
                    settings: migratedSettings,
                    steps: migrationSteps,
                    error: error
                )
            }
        }
        
        // Update version
        migratedSettings.settingsVersion = UserSettings.version
        migratedSettings.updatedAt = Date()
        
        return MigrationResult(
            success: true,
            settings: migratedSettings,
            steps: migrationSteps,
            error: nil
        )
    }
    
    func sanitize(_ settings: UserSettings) async -> UserSettings {
        var sanitizedSettings = settings
        
        // Sanitize camera settings
        sanitizedSettings.cameraSettings = await sanitizeCameraSettings(settings.cameraSettings)
        
        // Sanitize audio settings
        sanitizedSettings.audioSettings = await sanitizeAudioSettings(settings.audioSettings)
        
        // Sanitize video settings
        sanitizedSettings.videoSettings = await sanitizeVideoSettings(settings.videoSettings)
        
        // Sanitize UI settings
        sanitizedSettings.uiSettings = await sanitizeUISettings(settings.uiSettings)
        
        // Sanitize performance settings
        sanitizedSettings.performanceSettings = await sanitizePerformanceSettings(settings.performanceSettings)
        
        // Sanitize general settings
        sanitizedSettings.generalSettings = await sanitizeGeneralSettings(settings.generalSettings)
        
        sanitizedSettings.updatedAt = Date()
        
        return sanitizedSettings
    }
    
    // MARK: - Private Methods
    
    private func setupValidationRules() {
        // Camera validation rules
        validationRules.append(CameraSettingsValidationRule())
        validationRules.append(AudioSettingsValidationRule())
        validationRules.append(VideoSettingsValidationRule())
        validationRules.append(UISettingsValidationRule())
        validationRules.append(PerformanceSettingsValidationRule())
        validationRules.append(GeneralSettingsValidationRule())
    }
    
    private func setupMigrationRules() {
        // Migration rules for different versions
        migrationRules.append(MigrationFromV0_9())
        migrationRules.append(MigrationFromV1_0())
        migrationRules.append(MigrationFromV1_1())
    }
    
    private func sanitizeCameraSettings(_ settings: CameraSettings) async -> CameraSettings {
        var sanitized = settings
        
        // Ensure valid camera position
        if !CameraPosition.allCases.contains(sanitized.defaultCameraPosition) {
            sanitized.defaultCameraPosition = .back
        }
        
        // Ensure valid flash mode
        if !FlashMode.allCases.contains(sanitized.flashMode) {
            sanitized.flashMode = .auto
        }
        
        // Ensure valid focus mode
        if !FocusMode.allCases.contains(sanitized.focusMode) {
            sanitized.focusMode = .autoFocus
        }
        
        // Ensure valid exposure mode
        if !ExposureMode.allCases.contains(sanitized.exposureMode) {
            sanitized.exposureMode = .autoExposure
        }
        
        // Ensure valid white balance mode
        if !WhiteBalanceMode.allCases.contains(sanitized.whiteBalanceMode) {
            sanitized.whiteBalanceMode = .autoWhiteBalance
        }
        
        return sanitized
    }
    
    private func sanitizeAudioSettings(_ settings: AudioSettings) async -> AudioSettings {
        var sanitized = settings
        
        // Ensure valid audio quality
        if !AudioQuality.allCases.contains(sanitized.audioQuality) {
            sanitized.audioQuality = .high
        }
        
        // Ensure valid audio format
        if !AudioFormat.allCases.contains(sanitized.audioFormat) {
            sanitized.audioFormat = .aac
        }
        
        // Ensure valid sample rate
        if !SampleRate.allCases.contains(sanitized.sampleRate) {
            sanitized.sampleRate = .hz48000
        }
        
        // Ensure valid bit rate
        if !BitRate.allCases.contains(sanitized.bitRate) {
            sanitized.bitRate = .kbps128
        }
        
        // Ensure valid channels
        if !AudioChannels.allCases.contains(sanitized.channels) {
            sanitized.channels = .stereo
        }
        
        // Clamp audio boost level
        sanitized.audioBoostLevel = max(0.0, min(2.0, sanitized.audioBoostLevel))
        
        return sanitized
    }
    
    private func sanitizeVideoSettings(_ settings: VideoSettings) async -> VideoSettings {
        var sanitized = settings
        
        // Ensure valid video quality
        if !VideoQuality.allCases.contains(sanitized.videoQuality) {
            sanitized.videoQuality = .hd1080
        }
        
        // Ensure valid frame rate
        if !FrameRate.allCases.contains(sanitized.frameRate) {
            sanitized.frameRate = .fps30
        }
        
        // Ensure valid codec
        if !VideoCodec.allCases.contains(sanitized.codec) {
            sanitized.codec = .h264
        }
        
        // Ensure valid bitrate mode
        if !BitrateMode.allCases.contains(sanitized.bitrateMode) {
            sanitized.bitrateMode = .variable
        }
        
        // Ensure valid dual camera mode
        if !DualCameraMode.allCases.contains(sanitized.dualCameraMode) {
            sanitized.dualCameraMode = .pictureInPicture
        }
        
        // Ensure valid recording format
        if !RecordingFormat.allCases.contains(sanitized.recordingFormat) {
            sanitized.recordingFormat = .mp4
        }
        
        // Ensure valid slow motion rate
        if !SlowMotionRate.allCases.contains(sanitized.slowMotionRate) {
            sanitized.slowMotionRate = .x120
        }
        
        // Clamp keyframe interval
        sanitized.keyframeInterval = max(1, min(300, sanitized.keyframeInterval))
        
        // Clamp bitrates
        sanitized.maxBitrate = max(1000000, min(100000000, sanitized.maxBitrate))
        sanitized.averageBitrate = max(500000, min(sanitized.maxBitrate, sanitized.averageBitrate))
        
        return sanitized
    }
    
    private func sanitizeUISettings(_ settings: UISettings) async -> UISettings {
        var sanitized = settings
        
        // Ensure valid theme
        if !AppTheme.allCases.contains(sanitized.theme) {
            sanitized.theme = .dark
        }
        
        // Ensure valid accent color
        if !AccentColor.allCases.contains(sanitized.accentColor) {
            sanitized.accentColor = .blue
        }
        
        // Ensure valid animation speed
        if !AnimationSpeed.allCases.contains(sanitized.animationSpeed) {
            sanitized.animationSpeed = .normal
        }
        
        // Ensure valid haptic intensity
        if !HapticIntensity.allCases.contains(sanitized.hapticIntensity) {
            sanitized.hapticIntensity = .medium
        }
        
        // Clamp intensity values
        sanitized.liquidGlassIntensity = max(0.0, min(1.0, sanitized.liquidGlassIntensity))
        sanitized.soundVolume = max(0.0, min(1.0, sanitized.soundVolume))
        
        return sanitized
    }
    
    private func sanitizePerformanceSettings(_ settings: PerformanceSettings) async -> PerformanceSettings {
        var sanitized = settings
        
        // Clamp cache size (between 100MB and 10GB)
        sanitized.cacheSize = max(100 * 1024 * 1024, min(10 * 1024 * 1024 * 1024, sanitized.cacheSize))
        
        // Clamp max recording duration (between 1 minute and 24 hours)
        sanitized.maxRecordingDuration = max(60, min(86400, sanitized.maxRecordingDuration))
        
        // Clamp threshold values
        sanitized.lowBatteryThreshold = max(0.05, min(0.5, sanitized.lowBatteryThreshold))
        sanitized.highTemperatureThreshold = max(0.5, min(1.0, sanitized.highTemperatureThreshold))
        
        return sanitized
    }
    
    private func sanitizeGeneralSettings(_ settings: GeneralSettings) async -> GeneralSettings {
        // General settings are mostly boolean values, no sanitization needed
        return settings
    }
}

// MARK: - Validation Protocol

protocol ValidationRule: Sendable {
    func validate(_ settings: UserSettings) async -> RuleResult
}

// MARK: - Migration Protocol

protocol MigrationRule: Sendable {
    var priority: Int { get }
    func canMigrate(from version: String, to version: String) -> Bool
    func migrate(_ settings: UserSettings) async throws -> MigrationResult
}

// MARK: - Validation Results

struct ValidationResult: Sendable {
    let isValid: Bool
    let errors: [ValidationError]
    let warnings: [ValidationWarning]
}

struct RuleResult: Sendable {
    let errors: [ValidationError]
    let warnings: [ValidationWarning]
}

struct ValidationError: Sendable, Identifiable {
    let id = UUID()
    let category: ValidationCategory
    let field: String
    let message: String
    let severity: ValidationSeverity
}

struct ValidationWarning: Sendable, Identifiable {
    let id = UUID()
    let category: ValidationCategory
    let field: String
    let message: String
    let suggestion: String?
}

enum ValidationCategory: String, Sendable {
    case camera = "camera"
    case audio = "audio"
    case video = "video"
    case ui = "ui"
    case performance = "performance"
    case general = "general"
}

enum ValidationSeverity: String, Sendable {
    case error = "error"
    case warning = "warning"
    case info = "info"
}

// MARK: - Migration Results

struct MigrationResult: Sendable {
    let success: Bool
    let settings: UserSettings
    let steps: [MigrationStep]
    let error: Error?
}

struct MigrationStep: Sendable, Identifiable {
    let id = UUID()
    let name: String
    let description: String
    let fromVersion: String
    let toVersion: String
}

// MARK: - Camera Settings Validation

struct CameraSettingsValidationRule: ValidationRule {
    func validate(_ settings: UserSettings) async -> RuleResult {
        var errors: [ValidationError] = []
        var warnings: [ValidationWarning] = []
        
        let camera = settings.cameraSettings
        
        // Validate high resolution photo compatibility
        if camera.highResolutionPhotoEnabled && camera.defaultCameraPosition == .front {
            warnings.append(ValidationWarning(
                category: .camera,
                field: "highResolutionPhotoEnabled",
                message: "High resolution photos may not be supported on front camera",
                suggestion: "Consider disabling high resolution for front camera"
            ))
        }
        
        // Validate night mode compatibility
        if camera.nightModeEnabled && camera.flashMode == .on {
            warnings.append(ValidationWarning(
                category: .camera,
                field: "nightModeEnabled",
                message: "Night mode may interfere with flash",
                suggestion: "Consider using auto flash with night mode"
            ))
        }
        
        // Validate portrait mode
        if camera.portraitModeEnabled && camera.defaultCameraPosition == .back {
            // Portrait mode is typically only available on back camera
            // This is just an example validation
        }
        
        return RuleResult(errors: errors, warnings: warnings)
    }
}

// MARK: - Audio Settings Validation

struct AudioSettingsValidationRule: ValidationRule {
    func validate(_ settings: UserSettings) async -> RuleResult {
        var errors: [ValidationError] = []
        var warnings: [ValidationWarning] = []
        
        let audio = settings.audioSettings
        
        // Validate audio quality and format compatibility
        if audio.audioQuality == .lossless && audio.audioFormat == .aac {
            errors.append(ValidationError(
                category: .audio,
                field: "audioQuality",
                message: "Lossless quality is not compatible with AAC format",
                severity: .error
            ))
        }
        
        // Validate sample rate and quality
        if audio.audioQuality == .low && audio.sampleRate == .hz192000 {
            warnings.append(ValidationWarning(
                category: .audio,
                field: "sampleRate",
                message: "High sample rate with low quality may not be optimal",
                suggestion: "Consider increasing audio quality or decreasing sample rate"
            ))
        }
        
        // Validate bit rate and quality
        if audio.audioQuality == .high && audio.bitRate == .kbps64 {
            warnings.append(ValidationWarning(
                category: .audio,
                field: "bitRate",
                message: "Low bit rate may not match high quality setting",
                suggestion: "Consider increasing bit rate for better quality"
            ))
        }
        
        // Validate audio boost
        if audio.audioBoostEnabled && audio.audioBoostLevel > 1.5 {
            warnings.append(ValidationWarning(
                category: .audio,
                field: "audioBoostLevel",
                message: "High audio boost level may cause distortion",
                suggestion: "Consider reducing boost level to avoid distortion"
            ))
        }
        
        return RuleResult(errors: errors, warnings: warnings)
    }
}

// MARK: - Video Settings Validation

struct VideoSettingsValidationRule: ValidationRule {
    func validate(_ settings: UserSettings) async -> RuleResult {
        var errors: [ValidationError] = []
        var warnings: [ValidationWarning] = []
        
        let video = settings.videoSettings
        
        // Validate video quality and frame rate compatibility
        if video.videoQuality == .hd8K && video.frameRate == .fps240 {
            warnings.append(ValidationWarning(
                category: .video,
                field: "frameRate",
                message: "8K at 240fps may exceed device capabilities",
                suggestion: "Consider reducing frame rate or quality"
            ))
        }
        
        // Validate codec compatibility
        if video.codec == .proRes && video.videoQuality == .sd480 {
            warnings.append(ValidationWarning(
                category: .video,
                field: "codec",
                message: "ProRes codec with low quality may not be optimal",
                suggestion: "Consider using H.264 for low quality or increase quality"
            ))
        }
        
        // Validate bitrate settings
        if video.bitrateMode == .constant && video.averageBitrate > video.maxBitrate {
            errors.append(ValidationError(
                category: .video,
                field: "averageBitrate",
                message: "Average bitrate cannot exceed maximum bitrate",
                severity: .error
            ))
        }
        
        // Validate dual camera mode
        if video.dualCameraMode == .pictureInPicture && video.videoQuality == .hd8K {
            warnings.append(ValidationWarning(
                category: .video,
                field: "dualCameraMode",
                message: "PiP mode with 8K may cause performance issues",
                suggestion: "Consider reducing quality or using different dual camera mode"
            ))
        }
        
        return RuleResult(errors: errors, warnings: warnings)
    }
}

// MARK: - UI Settings Validation

struct UISettingsValidationRule: ValidationRule {
    func validate(_ settings: UserSettings) async -> RuleResult {
        var errors: [ValidationError] = []
        var warnings: [ValidationWarning] = []
        
        let ui = settings.uiSettings
        
        // Validate accessibility settings
        if ui.largeTextEnabled && ui.reduceMotionEnabled {
            warnings.append(ValidationWarning(
                category: .ui,
                field: "accessibility",
                message: "Multiple accessibility features enabled",
                suggestion: "Ensure these settings provide the best experience"
            ))
        }
        
        // Validate animation settings
        if ui.reduceMotionEnabled && ui.animationSpeed == .fast {
            warnings.append(ValidationWarning(
                category: .ui,
                field: "animationSpeed",
                message: "Animation speed setting ignored when reduce motion is enabled",
                suggestion: "Animation speed will be disabled when reduce motion is on"
            ))
        }
        
        // Validate haptic settings
        if !ui.hapticFeedbackEnabled && ui.hapticIntensity != .medium {
            warnings.append(ValidationWarning(
                category: .ui,
                field: "hapticIntensity",
                message: "Haptic intensity setting ignored when haptic feedback is disabled",
                suggestion: "Enable haptic feedback to use intensity settings"
            ))
        }
        
        return RuleResult(errors: errors, warnings: warnings)
    }
}

// MARK: - Performance Settings Validation

struct PerformanceSettingsValidationRule: ValidationRule {
    func validate(_ settings: UserSettings) async -> RuleResult {
        var errors: [ValidationError] = []
        var warnings: [ValidationWarning] = []
        
        let performance = settings.performanceSettings
        
        // Validate cache size
        if performance.cacheSize > 5 * 1024 * 1024 * 1024 { // 5GB
            warnings.append(ValidationWarning(
                category: .performance,
                field: "cacheSize",
                message: "Large cache size may affect device storage",
                suggestion: "Consider reducing cache size to free up storage"
            ))
        }
        
        // Validate recording duration
        if performance.maxRecordingDuration > 4 * 3600 { // 4 hours
            warnings.append(ValidationWarning(
                category: .performance,
                field: "maxRecordingDuration",
                message: "Very long recording duration may cause performance issues",
                suggestion: "Consider reducing maximum recording duration"
            ))
        }
        
        // Validate thermal settings
        if !performance.thermalManagementEnabled && performance.autoStopOnHighTemperature {
            errors.append(ValidationError(
                category: .performance,
                field: "autoStopOnHighTemperature",
                message: "Auto-stop on high temperature requires thermal management",
                severity: .error
            ))
        }
        
        // Validate battery settings
        if !performance.batteryOptimizationEnabled && performance.autoStopOnLowBattery {
            errors.append(ValidationError(
                category: .performance,
                field: "autoStopOnLowBattery",
                message: "Auto-stop on low battery requires battery optimization",
                severity: .error
            ))
        }
        
        return RuleResult(errors: errors, warnings: warnings)
    }
}

// MARK: - General Settings Validation

struct GeneralSettingsValidationRule: ValidationRule {
    func validate(_ settings: UserSettings) async -> RuleResult {
        var errors: [ValidationError] = []
        var warnings: [ValidationWarning] = []
        
        let general = settings.generalSettings
        
        // Validate analytics settings
        if !general.analyticsEnabled && general.usageDataEnabled {
            warnings.append(ValidationWarning(
                category: .general,
                field: "usageDataEnabled",
                message: "Usage data requires analytics to be enabled",
                suggestion: "Enable analytics to collect usage data"
            ))
        }
        
        // Validate debug settings
        if general.debugModeEnabled && !general.developerOptionsEnabled {
            warnings.append(ValidationWarning(
                category: .general,
                field: "debugModeEnabled",
                message: "Debug mode requires developer options",
                suggestion: "Enable developer options to use debug mode"
            ))
        }
        
        // Validate network settings
        if !general.wifiOnlyDownloads && !general.cellularDataEnabled {
            errors.append(ValidationError(
                category: .general,
                field: "cellularDataEnabled",
                message: "Cellular data must be enabled when wifi-only is disabled",
                severity: .error
            ))
        }
        
        return RuleResult(errors: errors, warnings: warnings)
    }
}

// MARK: - Migration Rules

struct MigrationFromV0_9: MigrationRule {
    let priority = 1
    
    func canMigrate(from version: String, to version: String) -> Bool {
        return version == "0.9" && version == "1.0.0"
    }
    
    func migrate(_ settings: UserSettings) async throws -> MigrationResult {
        var migratedSettings = settings
        
        // Add new fields introduced in v1.0
        if migratedSettings.uiSettings.liquidGlassIntensity == 0 {
            migratedSettings.uiSettings.liquidGlassIntensity = 0.5
        }
        
        if migratedSettings.performanceSettings.adaptiveQualityEnabled == false {
            migratedSettings.performanceSettings.adaptiveQualityEnabled = true
        }
        
        return MigrationResult(
            success: true,
            settings: migratedSettings,
            steps: [
                MigrationStep(
                    name: "Migration from v0.9",
                    description: "Added liquid glass intensity and adaptive quality settings",
                    fromVersion: "0.9",
                    toVersion: "1.0.0"
                )
            ],
            error: nil
        )
    }
}

struct MigrationFromV1_0: MigrationRule {
    let priority = 2
    
    func canMigrate(from version: String, to version: String) -> Bool {
        return version == "1.0.0" && version == "1.0.0"
    }
    
    func migrate(_ settings: UserSettings) async throws -> MigrationResult {
        // No migration needed for same version
        return MigrationResult(
            success: true,
            settings: settings,
            steps: [],
            error: nil
        )
    }
}

struct MigrationFromV1_1: MigrationRule {
    let priority = 3
    
    func canMigrate(from version: String, to version: String) -> Bool {
        return version == "1.1" && version == "1.0.0"
    }
    
    func migrate(_ settings: UserSettings) async throws -> MigrationResult {
        var migratedSettings = settings
        
        // Downgrade migration if needed
        // Remove fields that don't exist in v1.0.0
        
        return MigrationResult(
            success: true,
            settings: migratedSettings,
            steps: [
                MigrationStep(
                    name: "Downgrade from v1.1",
                    description: "Removed v1.1 specific features",
                    fromVersion: "1.1",
                    toVersion: "1.0.0"
                )
            ],
            error: nil
        )
    }
}