//
//  SettingsViewModel.swift
//  DualApp
//
//  Simplified settings view model for iOS 18 compatibility
//

import Foundation
import SwiftUI
import Combine

// UserSettings is defined in SettingsManager.swift as a standalone struct

@MainActor
class SettingsViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showingAlert = false
    @Published var alertTitle = ""
    @Published var alertMessage = ""

    @Published var hasUnsavedChanges = false

    // Video Settings
    @Published var videoQuality: VideoQuality = .hd1080
    @Published var enableTripleOutput = true
    @Published var recordingLayout = "sideBySide"

    // Audio Settings
    @Published var audioSource = "default"
    @Published var enableNoiseReduction = true

    // UI Settings
    @Published var enableHapticFeedback = true
    @Published var enableVisualCountdown = false
    @Published var countdownDuration = 3
    @Published var enableGrid = false

    // Performance Settings
    @Published var enablePerformanceMonitoring = false
    @Published var recordingQualityAdaptive = true
    @Published var maxRecordingDuration = 300

    // Cloud sync (simplified)
    @Published var isCloudSyncEnabled = false
    @Published var lastSyncDate: Date?
    @Published var syncInProgress = false

    // MARK: - Private Properties

    private let settingsManager = SettingsManager.shared
    private var userSettings = UserSettings.default

    // Export/Import
    @Published var showingExportSheet = false
    @Published var showingImportSheet = false

    // Initialization (async version)
    @Published var exportData: Data?

    // Diagnostics
    @Published var diagnosticReport: DiagnosticReport?
    @Published var showingDiagnosticReport = false
    @Published var errorReport: ErrorReport?
    @Published var showingErrorReport = false

    // MARK: - Private Properties

    private let settingsManager = SettingsManager.shared

    // Current user settings
    @Published var userSettings: UserSettings = UserSettings.default

    // MARK: - Computed Properties

    var appVersion: String {
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    var buildNumber: String {
        return Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    var storageUsage: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: 1024 * 1024 * 1024) // 1GB placeholder
    }

    var systemHealth: String {
        return "Good"
    }

    var systemHealthColor: Color {
        return DesignColors.accent
    }

    var hasErrors: Bool {
        return errorReport?.errorCount ?? 0 > 0
    }

    // MARK: - Initialization

    init() {
        Task {
            await loadSettings()
        }
    }

    // MARK: - Settings Management

    func loadSettings() async {
        isLoading = true

        // Load from SettingsManager
        let settings = await settingsManager.getSettings()

        await MainActor.run {
            // Update UI properties from UserSettings
            videoQuality = settings.videoSettings.videoQuality
            enableTripleOutput = settings.videoSettings.dualCameraMode == .sideBySide
            enableHapticFeedback = settings.uiSettings.hapticFeedbackEnabled
            enableVisualCountdown = false // Not available in current UserSettings
            countdownDuration = 3 // Default value
            enableGrid = settings.cameraSettings.gridEnabled
            audioSource = settings.audioSettings.audioFormat.rawValue
            enableNoiseReduction = settings.audioSettings.noiseReductionEnabled
            recordingQualityAdaptive = settings.performanceSettings.adaptiveQualityEnabled
            maxRecordingDuration = Int(settings.performanceSettings.maxRecordingDuration)
            enablePerformanceMonitoring = settings.performanceSettings.thermalManagementEnabled

            isLoading = false
        }
    }

    func saveSettings() async {
        isLoading = true

        do {
            // Create updated settings from current UI state
            var settings = await settingsManager.getSettings()

            // Update settings with current UI values
            settings.videoSettings.videoQuality = videoQuality
            settings.videoSettings.dualCameraMode = enableTripleOutput ? .sideBySide : .pictureInPicture
            settings.uiSettings.hapticFeedbackEnabled = enableHapticFeedback
            // enableVisualCountdown and countdownDuration not available in current UserSettings
            settings.cameraSettings.gridEnabled = enableGrid
            // audioSource mapping would need enum conversion
            settings.audioSettings.noiseReductionEnabled = enableNoiseReduction
            settings.performanceSettings.adaptiveQualityEnabled = recordingQualityAdaptive
            settings.performanceSettings.maxRecordingDuration = TimeInterval(maxRecordingDuration)
            settings.performanceSettings.thermalManagementEnabled = enablePerformanceMonitoring

            // Save to SettingsManager
            try await settingsManager.updateSettings(settings)

            await MainActor.run {
                hasUnsavedChanges = false
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to save settings: \(error.localizedDescription)"
                showingAlert = true
                isLoading = false
            }
        }
    }

    func resetToDefaults() async {
        do {
            try await settingsManager.resetToDefaults()
            await loadSettings()
            await MainActor.run {
                hasUnsavedChanges = false
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to reset settings: \(error.localizedDescription)"
                showingAlert = true
            }
        }
    }

    func exportSettings() async throws -> Data {
        return try await settingsManager.exportSettings()
    }

    func importSettings(from data: Data) async throws {
        try await settingsManager.importSettings(from: data)
        await loadSettings()
        await MainActor.run {
            hasUnsavedChanges = false
        }
    }

    // MARK: - Cloud Sync (Simplified)

    func toggleCloudSync() {
        isCloudSyncEnabled.toggle()
        // In a real implementation, this would enable/disable cloud sync
    }

    func forceSyncToCloud() {
        syncInProgress = true
        // Simulate sync
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.syncInProgress = false
            self.lastSyncDate = Date()
        }
    }

    func forceSyncFromCloud() {
        syncInProgress = true
        // Simulate sync
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.syncInProgress = false
            self.lastSyncDate = Date()
            Task {
                await self.loadSettings()
            }
        }
    }

    // MARK: - Diagnostics (Simplified)

    func runDiagnostics() {
        isLoading = true
        // Simulate diagnostic run
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.isLoading = false
            self.showingDiagnosticReport = true
        }
    }

    func generateErrorReport() {
        isLoading = true
        // Simulate error report generation
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.isLoading = false
            self.errorReport = ErrorReport(
                timestamp: Date(),
                errorCount: 0,
                criticalErrors: 0,
                description: "No errors reported"
            )
            self.showingErrorReport = true
        }
    }

    func showErrorReport() {
        generateErrorReport()
    }

    // MARK: - Error Handling

    func showError(_ message: String) {
        errorMessage = message
        showingAlert = true
        alertTitle = "Error"
        alertMessage = message
    }

    func clearError() {
        errorMessage = nil
        showingAlert = false
    }

    // MARK: - Update Methods for SettingsSectionViews

    func updateVideoQuality(_ quality: VideoQuality) {
        videoQuality = quality
        hasUnsavedChanges = true
    }

    func updateTheme(_ theme: String) {
        // For now, just mark as changed since we don't have a theme property
        hasUnsavedChanges = true
    }

    func updateThermalManagement(_ enabled: Bool) {
        // For now, just mark as changed since we don't have this property
        hasUnsavedChanges = true
    }

    func updateAutoSaveToGallery(_ enabled: Bool) {
        // For now, just mark as changed since we don't have this property
        hasUnsavedChanges = true
    }
}

// MARK: - Supporting Types

struct ErrorReport {
    let timestamp: Date
    let errorCount: Int
    let criticalErrors: Int
    let description: String

    static let sample = ErrorReport(
        timestamp: Date(),
        errorCount: 0,
        criticalErrors: 0,
        description: "No errors reported"
    )
}

// MARK: - Settings Management Methods

    func loadSettings() async {
        await MainActor.run {
            isLoading = true
        }

        do {
            let settings = await settingsManager.getSettings()
            await MainActor.run {
                self.userSettings = settings
                self.updatePublishedProperties(from: settings)
                isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.showingAlert = true
                isLoading = false
            }
        }
    }

    func saveSettings() async {
        await MainActor.run {
            isLoading = true
        }

        do {
            try await settingsManager.updateSettings(userSettings)
            await MainActor.run {
                hasUnsavedChanges = false
                isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.showingAlert = true
                isLoading = false
            }
        }
    }

    private func updatePublishedProperties(from settings: UserSettings) {
        videoQuality = settings.videoSettings.videoQuality
        enableTripleOutput = settings.videoSettings.dualCameraMode == .sideBySide
        recordingLayout = settings.videoSettings.dualCameraMode.rawValue

        audioSource = settings.audioSettings.audioFormat.rawValue
        enableNoiseReduction = settings.audioSettings.noiseReductionEnabled

        enableHapticFeedback = settings.uiSettings.hapticFeedbackEnabled
        enableGrid = settings.cameraSettings.gridEnabled

        recordingQualityAdaptive = settings.performanceSettings.adaptiveQualityEnabled
        maxRecordingDuration = Int(settings.performanceSettings.maxRecordingDuration)

        isCloudSyncEnabled = settings.generalSettings.analyticsEnabled
    }

    // Method to update settings and mark as changed
    func updateSetting<T>(_ keyPath: WritableKeyPath<UserSettings, T>, value: T) {
        userSettings[keyPath: keyPath] = value
        hasUnsavedChanges = true
    }

    // Specific update methods for UI bindings
    func updateVideoQuality(_ quality: VideoQuality) {
        var newSettings = userSettings
        newSettings.videoSettings.videoQuality = quality
        userSettings = newSettings
        hasUnsavedChanges = true
    }

    func updateBatteryOptimization(_ enabled: Bool) {
        var newSettings = userSettings
        newSettings.performanceSettings.batteryOptimizationEnabled = enabled
        userSettings = newSettings
        hasUnsavedChanges = true
    }

    func updateLocationMetadata(_ enabled: Bool) {
        var newSettings = userSettings
        newSettings.generalSettings.includeLocationMetadata = enabled
        userSettings = newSettings
        hasUnsavedChanges = true
    }

    func updateFrameRate(_ frameRate: Int) {
        var newSettings = userSettings
        // Convert Int to FrameRate enum
        switch frameRate {
        case 24:
            newSettings.videoSettings.frameRate = .fps24
        case 30:
            newSettings.videoSettings.frameRate = .fps30
        case 60:
            newSettings.videoSettings.frameRate = .fps60
        case 120:
            newSettings.videoSettings.frameRate = .fps120
        default:
            newSettings.videoSettings.frameRate = .fps30
        }
        userSettings = newSettings
        hasUnsavedChanges = true
    }

    func updateDefaultCameraPosition(_ position: CameraPosition) {
        var newSettings = userSettings
        newSettings.cameraSettings.defaultCameraPosition = position
        userSettings = newSettings
        hasUnsavedChanges = true
    }

    func updateAudioSettings(_ updater: (AudioSettings) -> AudioSettings) {
        var newSettings = userSettings
        newSettings.audioSettings = updater(newSettings.audioSettings)
        userSettings = newSettings
        hasUnsavedChanges = true
    }

    func updateTheme(_ theme: String) {
        var newSettings = userSettings
        newSettings.uiSettings.theme = theme
        userSettings = newSettings
        hasUnsavedChanges = true
    }

    func updateThermalManagement(_ enabled: Bool) {
        var newSettings = userSettings
        newSettings.performanceSettings.thermalManagementEnabled = enabled
        userSettings = newSettings
        hasUnsavedChanges = true
    }

    func updateAutoSave(_ enabled: Bool) {
        var newSettings = userSettings
        newSettings.generalSettings.autoSaveToGallery = enabled
        userSettings = newSettings
        hasUnsavedChanges = true
    }

    // Export/Import methods
    func exportSettings() async throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        return try encoder.encode(userSettings)
    }

    func importSettings(from data: Data) async throws {
        let decoder = JSONDecoder()
        let importedSettings = try decoder.decode(UserSettings.self, from: data)
        try await settingsManager.updateSettings(importedSettings)
        await MainActor.run {
            self.userSettings = importedSettings
            self.updatePublishedProperties(from: importedSettings)
            hasUnsavedChanges = false
        }
    }

    // MARK: - Computed Binding Properties for UI

    var videoQualityBinding: Binding<VideoQuality> {
        Binding(
            get: { self.userSettings.videoSettings.videoQuality },
            set: { self.updateVideoQuality($0) }
        )
    }

    var themeBinding: Binding<String> {
        Binding(
            get: { self.userSettings.uiSettings.theme },
            set: { self.updateTheme($0) }
        )
    }

    var thermalManagementBinding: Binding<Bool> {
        Binding(
            get: { self.userSettings.performanceSettings.thermalManagementEnabled },
            set: { self.updateThermalManagement($0) }
        )
    }

    var autoSaveBinding: Binding<Bool> {
        Binding(
            get: { self.userSettings.generalSettings.autoSaveToGallery },
            set: { self.updateAutoSave($0) }
        )
    }

    func updateAutoSaveToGallery(_ enabled: Bool) {
        updateAutoSave(enabled)
    }