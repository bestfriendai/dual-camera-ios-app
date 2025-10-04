//
//  SettingsViewModel.swift
//  DualApp
//
//  Created by DualApp Team on 10/3/25.
//

import Foundation
import SwiftUI

@MainActor
class SettingsViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var userSettings: UserSettings = UserSettings.default
    @Published var isCloudSyncEnabled: Bool = false
    @Published var lastSyncDate: Date?
    @Published var syncInProgress: Bool = false
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    @Published var showingError: Bool = false
    @Published var showingSuccess: Bool = false
    @Published var diagnosticReport: DiagnosticReport?
    @Published var showingDiagnosticReport: Bool = false
    @Published var errorReport: ErrorReport?
    @Published var showingErrorReport: Bool = false
    
    // MARK: - Computed Properties
    
    var appVersion: String {
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }
    
    var buildNumber: String {
        return Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
    }
    
    var storageUsage: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB]
        formatter.countStyle = .file
        
        // This would get actual storage usage
        return formatter.string(fromByteCount: 1024 * 1024 * 1024) // 1GB placeholder
    }
    
    var systemHealth: String {
        // This would get actual system health
        return "Good"
    }
    
    var systemHealthColor: Color {
        switch systemHealth {
        case "Excellent":
            return DesignColors.success
        case "Good":
            return DesignColors.info
        case "Fair":
            return DesignColors.warning
        case "Poor":
            return DesignColors.error
        default:
            return DesignColors.textSecondary
        }
    }
    
    var hasErrors: Bool {
        // This would check if there are any active errors
        return false
    }
    
    // MARK: - Initialization
    
    init() {
        loadSettings()
    }
    
    // MARK: - Settings Management
    
    func loadSettings() {
        Task {
            isLoading = true
            
            do {
                let settings = await SettingsManager.shared.getSettings()
                userSettings = settings
                
                let syncStatus = await SettingsManager.shared.getSyncStatus()
                isCloudSyncEnabled = syncStatus.isCloudSyncEnabled
                lastSyncDate = syncStatus.lastSyncDate
                syncInProgress = syncStatus.syncInProgress
                
            } catch {
                showError("Failed to load settings: \(error.localizedDescription)")
            }
            
            isLoading = false
        }
    }
    
    func saveSettings() {
        Task {
            isLoading = true
            
            do {
                try await SettingsManager.shared.updateSettings(userSettings)
                showSuccess("Settings saved successfully")
            } catch {
                showError("Failed to save settings: \(error.localizedDescription)")
            }
            
            isLoading = false
        }
    }
    
    func resetToDefaults() {
        Task {
            isLoading = true
            
            do {
                try await SettingsManager.shared.resetToDefaults()
                loadSettings()
                showSuccess("Settings reset to defaults")
            } catch {
                showError("Failed to reset settings: \(error.localizedDescription)")
            }
            
            isLoading = false
        }
    }
    
    func exportSettings() -> Data? {
        do {
            return try await SettingsManager.shared.exportSettings()
        } catch {
            showError("Failed to export settings: \(error.localizedDescription)")
            return nil
        }
    }
    
    func importSettings(from data: Data) {
        Task {
            isLoading = true
            
            do {
                try await SettingsManager.shared.importSettings(from: data)
                loadSettings()
                showSuccess("Settings imported successfully")
            } catch {
                showError("Failed to import settings: \(error.localizedDescription)")
            }
            
            isLoading = false
        }
    }
    
    // MARK: - Cloud Sync
    
    func toggleCloudSync() {
        Task {
            isLoading = true
            
            do {
                try await SettingsManager.shared.enableCloudSync(!isCloudSyncEnabled)
                isCloudSyncEnabled.toggle()
                showSuccess("Cloud sync \(isCloudSyncEnabled ? "enabled" : "disabled")")
            } catch {
                showError("Failed to toggle cloud sync: \(error.localizedDescription)")
            }
            
            isLoading = false
        }
    }
    
    func forceSyncToCloud() {
        Task {
            isLoading = true
            syncInProgress = true
            
            do {
                try await SettingsManager.shared.forceSyncToCloud()
                lastSyncDate = Date()
                showSuccess("Settings synced to cloud")
            } catch {
                showError("Failed to sync to cloud: \(error.localizedDescription)")
            }
            
            isLoading = false
            syncInProgress = false
        }
    }
    
    func forceSyncFromCloud() {
        Task {
            isLoading = true
            syncInProgress = true
            
            do {
                try await SettingsManager.shared.forceSyncFromCloud()
                loadSettings()
                lastSyncDate = Date()
                showSuccess("Settings synced from cloud")
            } catch {
                showError("Failed to sync from cloud: \(error.localizedDescription)")
            }
            
            isLoading = false
            syncInProgress = false
        }
    }
    
    // MARK: - Camera Settings
    
    func updateCameraSettings(_ settings: CameraSettings) {
        userSettings.cameraSettings = settings
        saveSettings()
    }
    
    func updateDefaultCameraPosition(_ position: CameraPosition) {
        userSettings.cameraSettings.defaultCameraPosition = position
        saveSettings()
    }
    
    func updateFlashMode(_ mode: FlashMode) {
        userSettings.cameraSettings.flashMode = mode
        saveSettings()
    }
    
    func updateFocusMode(_ mode: FocusMode) {
        userSettings.cameraSettings.focusMode = mode
        saveSettings()
    }
    
    func updateVideoStabilization(_ enabled: Bool) {
        userSettings.cameraSettings.videoStabilizationEnabled = enabled
        saveSettings()
    }
    
    func updateHighResolutionPhoto(_ enabled: Bool) {
        userSettings.cameraSettings.highResolutionPhotoEnabled = enabled
        saveSettings()
    }
    
    func updateGridEnabled(_ enabled: Bool) {
        userSettings.cameraSettings.gridEnabled = enabled
        saveSettings()
    }
    
    // MARK: - Audio Settings
    
    func updateAudioSettings(_ settings: AudioSettings) {
        userSettings.audioSettings = settings
        saveSettings()
    }
    
    func updateAudioQuality(_ quality: AudioQuality) {
        userSettings.audioSettings.audioQuality = quality
        saveSettings()
    }
    
    func updateAudioFormat(_ format: AudioFormat) {
        userSettings.audioSettings.audioFormat = format
        saveSettings()
    }
    
    func updateSampleRate(_ rate: SampleRate) {
        userSettings.audioSettings.sampleRate = rate
        saveSettings()
    }
    
    func updateNoiseReduction(_ enabled: Bool) {
        userSettings.audioSettings.noiseReductionEnabled = enabled
        saveSettings()
    }
    
    func updateAudioBoost(_ enabled: Bool, level: Float) {
        userSettings.audioSettings.audioBoostEnabled = enabled
        userSettings.audioSettings.audioBoostLevel = level
        saveSettings()
    }
    
    // MARK: - Video Settings
    
    func updateVideoSettings(_ settings: VideoSettings) {
        userSettings.videoSettings = settings
        saveSettings()
    }
    
    func updateVideoQuality(_ quality: VideoQuality) {
        userSettings.videoSettings.videoQuality = quality
        saveSettings()
    }
    
    func updateFrameRate(_ rate: FrameRate) {
        userSettings.videoSettings.frameRate = rate
        saveSettings()
    }
    
    func updateVideoCodec(_ codec: VideoCodec) {
        userSettings.videoSettings.codec = codec
        saveSettings()
    }
    
    func updateDualCameraMode(_ mode: DualCameraMode) {
        userSettings.videoSettings.dualCameraMode = mode
        saveSettings()
    }
    
    func updateRecordingFormat(_ format: RecordingFormat) {
        userSettings.videoSettings.recordingFormat = format
        saveSettings()
    }
    
    // MARK: - UI Settings
    
    func updateUISettings(_ settings: UISettings) {
        userSettings.uiSettings = settings
        saveSettings()
    }
    
    func updateTheme(_ theme: AppTheme) {
        userSettings.uiSettings.theme = theme
        saveSettings()
    }
    
    func updateAccentColor(_ color: AccentColor) {
        userSettings.uiSettings.accentColor = color
        saveSettings()
    }
    
    func updateLiquidGlassIntensity(_ intensity: Double) {
        userSettings.uiSettings.liquidGlassIntensity = intensity
        saveSettings()
    }
    
    func updateAnimationSpeed(_ speed: AnimationSpeed) {
        userSettings.uiSettings.animationSpeed = speed
        saveSettings()
    }
    
    func updateHapticFeedback(_ enabled: Bool, intensity: HapticIntensity) {
        userSettings.uiSettings.hapticFeedbackEnabled = enabled
        userSettings.uiSettings.hapticIntensity = intensity
        saveSettings()
    }
    
    // MARK: - Performance Settings

    func updatePerformanceSettings(_ settings: PerformanceSettings) {
        userSettings.performanceSettings = settings
        saveSettings()
    }

    func updateBatteryOptimization(_ enabled: Bool) {
        userSettings.performanceSettings.batteryOptimizationEnabled = enabled
        saveSettings()
    }
    
    func updateThermalManagement(_ enabled: Bool) {
        userSettings.performanceSettings.thermalManagementEnabled = enabled
        saveSettings()
    }
    
    func updateBatteryOptimization(_ enabled: Bool) {
        userSettings.performanceSettings.batteryOptimizationEnabled = enabled
        saveSettings()
    }
    
    func updateMemoryManagement(_ enabled: Bool) {
        userSettings.performanceSettings.memoryManagementEnabled = enabled
        saveSettings()
    }
    
    func updateAdaptiveQuality(_ enabled: Bool) {
        userSettings.performanceSettings.adaptiveQualityEnabled = enabled
        saveSettings()
    }
    
    func updateMaxRecordingDuration(_ duration: TimeInterval) {
        userSettings.performanceSettings.maxRecordingDuration = duration
        saveSettings()
    }
    
    // MARK: - General Settings

    func updateGeneralSettings(_ settings: GeneralSettings) {
        userSettings.generalSettings = settings
        saveSettings()
    }

    func updateLocationMetadata(_ enabled: Bool) {
        userSettings.generalSettings.includeLocationMetadata = enabled
        saveSettings()
    }
    
    func updateAutoSaveToGallery(_ enabled: Bool) {
        userSettings.generalSettings.autoSaveToGallery = enabled
        saveSettings()
    }
    
    func updateLocationMetadata(_ enabled: Bool) {
        userSettings.generalSettings.includeLocationMetadata = enabled
        saveSettings()
    }
    
    func updateAnalytics(_ enabled: Bool) {
        userSettings.generalSettings.analyticsEnabled = enabled
        saveSettings()
    }
    
    func updateCrashReporting(_ enabled: Bool) {
        userSettings.generalSettings.crashReportingEnabled = enabled
        saveSettings()
    }
    
    func updateBetaFeatures(_ enabled: Bool) {
        userSettings.generalSettings.betaFeaturesEnabled = enabled
        saveSettings()
    }
    
    func updateDebugMode(_ enabled: Bool) {
        userSettings.generalSettings.debugModeEnabled = enabled
        saveSettings()
    }
    
    // MARK: - Diagnostics
    
    func runDiagnostics() {
        Task {
            isLoading = true
            
            do {
                let report = await DiagnosticsManager.shared.generateDiagnosticReport()
                diagnosticReport = report
                showingDiagnosticReport = true
                showSuccess("Diagnostics completed successfully")
            } catch {
                showError("Failed to run diagnostics: \(error.localizedDescription)")
            }
            
            isLoading = false
        }
    }
    
    func showErrorReport() {
        Task {
            isLoading = true
            
            do {
                let report = await ErrorHandlingManager.shared.generateErrorReport()
                errorReport = report
                showingErrorReport = true
                showSuccess("Error report generated")
            } catch {
                showError("Failed to generate error report: \(error.localizedDescription)")
            }
            
            isLoading = false
        }
    }
    
    func exportDiagnosticData() -> Data? {
        Task {
            isLoading = true
            
            do {
                let data = await DiagnosticsManager.shared.exportDiagnosticData()
                isLoading = false
                return data
            } catch {
                showError("Failed to export diagnostic data: \(error.localizedDescription)")
                isLoading = false
                return nil
            }
        }
        
        return nil
    }
    
    // MARK: - Error Handling
    
    private func showError(_ message: String) {
        errorMessage = message
        showingError = true
        
        // Auto-hide after 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            self.showingError = false
        }
    }
    
    private func showSuccess(_ message: String) {
        successMessage = message
        showingSuccess = true
        
        // Auto-hide after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.showingSuccess = false
        }
    }
}

// MARK: - Settings View Models for Individual Sections

@MainActor
class CameraSettingsViewModel: ObservableObject {
    @Published var settings: CameraSettings = CameraSettings.default
    
    func updateSettings(_ newSettings: CameraSettings) {
        settings = newSettings
    }
}

@MainActor
class AudioSettingsViewModel: ObservableObject {
    @Published var settings: AudioSettings = AudioSettings.default
    
    func updateSettings(_ newSettings: AudioSettings) {
        settings = newSettings
    }
}

@MainActor
class VideoSettingsViewModel: ObservableObject {
    @Published var settings: VideoSettings = VideoSettings.default
    
    func updateSettings(_ newSettings: VideoSettings) {
        settings = newSettings
    }
}

@MainActor
class UISettingsViewModel: ObservableObject {
    @Published var settings: UISettings = UISettings.default
    
    func updateSettings(_ newSettings: UISettings) {
        settings = newSettings
    }
}

@MainActor
class PerformanceSettingsViewModel: ObservableObject {
    @Published var settings: PerformanceSettings = PerformanceSettings.default
    
    func updateSettings(_ newSettings: PerformanceSettings) {
        settings = newSettings
    }
}

@MainActor
class GeneralSettingsViewModel: ObservableObject {
    @Published var settings: GeneralSettings = GeneralSettings.default
    
    func updateSettings(_ newSettings: GeneralSettings) {
        settings = newSettings
    }
}