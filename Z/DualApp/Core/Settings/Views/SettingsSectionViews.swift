//
//  SettingsSectionViews.swift
//  DualApp
//
//  Created by DualApp Team on 10/3/25.
//

import SwiftUI

// MARK: - Camera Settings View

struct CameraSettingsView: View {
    @ObservedObject var settingsViewModel: SettingsViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            // Default Camera Position
            // Default Camera Position - Simplified for now
            LiquidGlassComponents.settingsRow(
                title: "Default Camera",
                subtitle: "Choose the default camera when opening the app",
                icon: "camera",
                color: DesignColors.primary
            ) {
                Text(settingsViewModel.userSettings.cameraSettings.defaultCameraPosition.description)
                    .foregroundColor(DesignColors.secondaryText)
            }
            
            Divider()
                .background(DesignColors.glassBorder)
                .opacity(0.3)
            
            // Flash Mode
            SettingsPickerView(
                title: "Flash Mode",
                subtitle: "Default flash behavior",
                icon: "bolt.fill",
                color: DesignColors.warning,
                selection: Binding(
                    get: { settingsViewModel.userSettings.cameraSettings.flashMode },
                    set: { settingsViewModel.updateFlashMode($0) }
                )
            )
            
            Divider()
                .background(DesignColors.glassBorder)
                .opacity(0.3)
            
            // Focus Mode
            SettingsPickerView(
                title: "Focus Mode",
                subtitle: "Default focus behavior",
                icon: "camera.metering.spot",
                color: DesignColors.info,
                selection: Binding(
                    get: { settingsViewModel.userSettings.cameraSettings.focusMode },
                    set: { settingsViewModel.updateFocusMode($0) }
                )
            )
            
            Divider()
                .background(DesignColors.glassBorder)
                .opacity(0.3)
            
            // Video Stabilization
            SettingsToggleView(
                title: "Video Stabilization",
                subtitle: "Reduce camera shake in videos",
                icon: "camera.metering.matrix",
                color: DesignColors.success,
                isOn: Binding(
                    get: { settingsViewModel.userSettings.cameraSettings.videoStabilizationEnabled },
                    set: { settingsViewModel.updateVideoStabilization($0) }
                )
            )
            
            Divider()
                .background(DesignColors.glassBorder)
                .opacity(0.3)
            
            // High Resolution Photos
            SettingsToggleView(
                title: "High Resolution Photos",
                subtitle: "Capture photos at maximum resolution",
                icon: "photo",
                color: DesignColors.accent,
                isOn: Binding(
                    get: { settingsViewModel.userSettings.cameraSettings.highResolutionPhotoEnabled },
                    set: { settingsViewModel.updateHighResolutionPhoto($0) }
                )
            )
            
            Divider()
                .background(DesignColors.glassBorder)
                .opacity(0.3)
            
            // Grid Overlay
            SettingsToggleView(
                title: "Grid Overlay",
                subtitle: "Show grid lines for better composition",
                icon: "grid",
                color: DesignColors.secondary,
                isOn: Binding(
                    get: { settingsViewModel.userSettings.cameraSettings.gridEnabled },
                    set: { settingsViewModel.updateGridEnabled($0) }
                )
            )
        }
    }
}

// MARK: - Audio Settings View

struct AudioSettingsView: View {
    @ObservedObject var settingsViewModel: SettingsViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            // Audio Recording
            SettingsToggleView(
                title: "Audio Recording",
                subtitle: "Record audio along with video",
                icon: "waveform",
                color: DesignColors.accent,
                isOn: Binding(
                    get: { settingsViewModel.userSettings.audioSettings.audioRecordingEnabled },
                    set: { newValue in
                        settingsViewModel.updateAudioSettings { settings in
                            var newSettings = settings
                            newSettings.audioRecordingEnabled = newValue
                            return newSettings
                        }
                    }
                )
            )
            
            Divider()
                .background(DesignColors.glassBorder)
                .opacity(0.3)
            
            // Audio Quality
            SettingsPickerView(
                title: "Audio Quality",
                subtitle: "Higher quality uses more storage",
                icon: "waveform.path.ecg",
                color: DesignColors.success,
                selection: Binding(
                    get: { settingsViewModel.userSettings.audioSettings.audioQuality },
                    set: { settingsViewModel.updateAudioQuality($0) }
                )
            )
            
            Divider()
                .background(DesignColors.glassBorder)
                .opacity(0.3)
            
            // Audio Format
            SettingsPickerView(
                title: "Audio Format",
                subtitle: "Audio file format",
                icon: "music.note",
                color: DesignColors.info,
                selection: Binding(
                    get: { settingsViewModel.userSettings.audioSettings.audioFormat },
                    set: { settingsViewModel.updateAudioFormat($0) }
                )
            )
            
            Divider()
                .background(DesignColors.glassBorder)
                .opacity(0.3)
            
            // Sample Rate
            SettingsPickerView(
                title: "Sample Rate",
                subtitle: "Higher sample rate for better quality",
                icon: "waveform.path",
                color: DesignColors.warning,
                selection: Binding(
                    get: { settingsViewModel.userSettings.audioSettings.sampleRate },
                    set: { settingsViewModel.updateSampleRate($0) }
                )
            )
            
            Divider()
                .background(DesignColors.glassBorder)
                .opacity(0.3)
            
            // Noise Reduction
            SettingsToggleView(
                title: "Noise Reduction",
                subtitle: "Reduce background noise",
                icon: "speaker.wave.3.fill",
                color: DesignColors.primary,
                isOn: Binding(
                    get: { settingsViewModel.userSettings.audioSettings.noiseReductionEnabled },
                    set: { settingsViewModel.updateNoiseReduction($0) }
                )
            )
            
            Divider()
                .background(DesignColors.glassBorder)
                .opacity(0.3)
            
            // Audio Boost
            VStack(spacing: 0) {
                SettingsToggleView(
                    title: "Audio Boost",
                    subtitle: "Increase audio volume",
                    icon: "speaker.wave.2.fill",
                    color: DesignColors.error,
                    isOn: Binding(
                        get: { settingsViewModel.userSettings.audioSettings.audioBoostEnabled },
                        set: { enabled in
                            settingsViewModel.updateAudioBoost(enabled, settingsViewModel.userSettings.audioSettings.audioBoostLevel)
                        }
                    )
                )
                
                if settingsViewModel.userSettings.audioSettings.audioBoostEnabled {
                    SettingsSliderView(
                        title: "Boost Level",
                        subtitle: "Audio boost intensity",
                        icon: "speaker.wave.3.fill",
                        color: DesignColors.error,
                        range: 1.0...2.0,
                        step: 0.1,
                        value: Binding(
                            get: { settingsViewModel.userSettings.audioSettings.audioBoostLevel },
                            set: { settingsViewModel.updateAudioBoost(settingsViewModel.userSettings.audioSettings.audioBoostEnabled, $0) }
                        )
                    )
                }
            }
        }
    }
}

// MARK: - Video Settings View

struct VideoSettingsView: View {
    @ObservedObject var settingsViewModel: SettingsViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            // Video Quality
            // Video Quality - Simplified for now
            LiquidGlassComponents.settingsRow(
                title: "Video Quality",
                subtitle: "Higher quality uses more storage and battery",
                icon: "video.badge.plus",
                color: DesignColors.primary
            ) {
                Text($settingsViewModel.userSettings.videoSettings.videoQuality.wrappedValue.description)
                    .foregroundColor(DesignColors.secondaryText)
            }
            
            Divider()
                .background(DesignColors.glassBorder)
                .opacity(0.3)
            
            // Frame Rate
            SettingsPickerView(
                title: "Frame Rate",
                subtitle: "Higher frame rate for smoother video",
                icon: "speedometer",
                color: DesignColors.success,
                selection: Binding(
                    get: { settingsViewModel.userSettings.videoSettings.frameRate },
                    set: { settingsViewModel.updateFrameRate($0) }
                )
            )
            
            Divider()
                .background(DesignColors.glassBorder)
                .opacity(0.3)
            
            // Video Codec
            SettingsPickerView(
                title: "Video Codec",
                subtitle: "Video compression format",
                icon: "film",
                color: DesignColors.info,
                selection: Binding(
                    get: { settingsViewModel.userSettings.videoSettings.codec },
                    set: { settingsViewModel.updateVideoCodec($0) }
                )
            )
            
            Divider()
                .background(DesignColors.glassBorder)
                .opacity(0.3)
            
            // Dual Camera Mode
            SettingsPickerView(
                title: "Dual Camera Mode",
                subtitle: "How to display both cameras",
                icon: "camera.on.rectangle",
                color: DesignColors.accent,
                selection: Binding(
                    get: { settingsViewModel.userSettings.videoSettings.dualCameraMode },
                    set: { settingsViewModel.updateDualCameraMode($0) }
                )
            )
            
            Divider()
                .background(DesignColors.glassBorder)
                .opacity(0.3)
            
            // Recording Format
            SettingsPickerView(
                title: "Recording Format",
                subtitle: "Video file format",
                icon: "video.square",
                color: DesignColors.warning,
                selection: Binding(
                    get: { settingsViewModel.userSettings.videoSettings.recordingFormat },
                    set: { settingsViewModel.updateRecordingFormat($0) }
                )
            )
            
            Divider()
                .background(DesignColors.glassBorder)
                .opacity(0.3)
            
            // Time Lapse
            SettingsToggleView(
                title: "Time Lapse",
                subtitle: "Enable time lapse recording",
                icon: "timelapse",
                color: DesignColors.secondary,
                isOn: Binding(
                    get: { settingsViewModel.userSettings.videoSettings.timeLapseEnabled },
                    set: { settingsViewModel.updateVideoSettings({ var s = $0; s.timeLapseEnabled = $1; return s }) }
                )
            )
            
            Divider()
                .background(DesignColors.glassBorder)
                .opacity(0.3)
            
            // Slow Motion
            SettingsToggleView(
                title: "Slow Motion",
                subtitle: "Enable slow motion recording",
                icon: "slowmo",
                color: DesignColors.error,
                isOn: Binding(
                    get: { settingsViewModel.userSettings.videoSettings.slowMotionEnabled },
                    set: { settingsViewModel.updateVideoSettings({ var s = $0; s.slowMotionEnabled = $1; return s }) }
                )
            )
        }
    }
}

// MARK: - UI Settings View

struct UISettingsView: View {
    @ObservedObject var settingsViewModel: SettingsViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            // Theme - Simplified for now
            LiquidGlassComponents.settingsRow(
                title: "Theme",
                subtitle: "App appearance theme",
                icon: "paintbrush",
                color: DesignColors.primary
            ) {
                Text($settingsViewModel.userSettings.uiSettings.theme.wrappedValue)
                    .foregroundColor(DesignColors.secondaryText)
            }
            
            Divider()
                .background(DesignColors.glassBorder)
                .opacity(0.3)
            
            // Accent Color
            SettingsPickerView(
                title: "Accent Color",
                subtitle: "Primary accent color",
                icon: "paintpalette",
                color: DesignColors.accent,
                selection: Binding(
                    get: { settingsViewModel.userSettings.uiSettings.accentColor },
                    set: { settingsViewModel.updateAccentColor($0) }
                )
            )
            
            Divider()
                .background(DesignColors.glassBorder)
                .opacity(0.3)
            
            // Liquid Glass Intensity
            SettingsSliderView(
                title: "Glass Intensity",
                subtitle: "Liquid glass effect intensity",
                icon: "circle.hexagongrid",
                color: DesignColors.info,
                range: 0.0...1.0,
                step: 0.1,
                value: Binding(
                    get: { settingsViewModel.userSettings.uiSettings.liquidGlassIntensity },
                    set: { settingsViewModel.updateLiquidGlassIntensity($0) }
                )
            )
            
            Divider()
                .background(DesignColors.glassBorder)
                .opacity(0.3)
            
            // Animation Speed
            SettingsPickerView(
                title: "Animation Speed",
                subtitle: "UI animation speed",
                icon: "speedometer",
                color: DesignColors.success,
                selection: Binding(
                    get: { settingsViewModel.userSettings.uiSettings.animationSpeed },
                    set: { settingsViewModel.updateAnimationSpeed($0) }
                )
            )
            
            Divider()
                .background(DesignColors.glassBorder)
                .opacity(0.3)
            
            // Haptic Feedback
            VStack(spacing: 0) {
                SettingsToggleView(
                    title: "Haptic Feedback",
                    subtitle: "Enable haptic feedback",
                    icon: "hand.tap",
                    color: DesignColors.warning,
                    isOn: Binding(
                        get: { settingsViewModel.userSettings.uiSettings.hapticFeedbackEnabled },
                        set: { enabled in
                            settingsViewModel.updateHapticFeedback(enabled, settingsViewModel.userSettings.uiSettings.hapticIntensity)
                        }
                    )
                )
                
                if settingsViewModel.userSettings.uiSettings.hapticFeedbackEnabled {
                    SettingsPickerView(
                        title: "Haptic Intensity",
                        subtitle: "Haptic feedback intensity",
                        icon: "hand.tap.fill",
                        color: DesignColors.warning,
                        selection: Binding(
                            get: { settingsViewModel.userSettings.uiSettings.hapticIntensity },
                            set: { settingsViewModel.updateHapticFeedback(settingsViewModel.userSettings.uiSettings.hapticFeedbackEnabled, $0) }
                        )
                    )
                }
            }
            
            Divider()
                .background(DesignColors.glassBorder)
                .opacity(0.3)
            
            // Sound Effects
            SettingsToggleView(
                title: "Sound Effects",
                subtitle: "Enable UI sound effects",
                icon: "speaker.wave.2",
                color: DesignColors.secondary,
                isOn: Binding(
                    get: { settingsViewModel.userSettings.uiSettings.soundEffectsEnabled },
                    set: { settingsViewModel.updateUISettings({ var s = $0; s.soundEffectsEnabled = $1; return s }) }
                )
            )
        }
    }
}

// MARK: - Performance Settings View

struct PerformanceSettingsView: View {
    @ObservedObject var settingsViewModel: SettingsViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            // Thermal Management
            SettingsToggleView(
                title: "Thermal Management",
                subtitle: "Automatically reduce performance when device gets hot",
                icon: "thermometer",
                color: DesignColors.error,
                isOn: Binding(
                    get: { $settingsViewModel.userSettings.performanceSettings.thermalManagementEnabled.wrappedValue },
                    set: { settingsViewModel.updateThermalManagement($0) }
                )
            )
            
            Divider()
                .background(DesignColors.glassBorder)
                .opacity(0.3)
            
            // Battery Optimization
            SettingsToggleView(
                title: "Battery Optimization",
                subtitle: "Optimize performance for battery life",
                icon: "battery.100",
                color: DesignColors.success,
                isOn: Binding(
                    get: { settingsViewModel.userSettings.performanceSettings.batteryOptimizationEnabled },
                    set: { settingsViewModel.updateBatteryOptimization($0) }
                )
            )
            
            Divider()
                .background(DesignColors.glassBorder)
                .opacity(0.3)
            
            // Memory Management
            SettingsToggleView(
                title: "Memory Management",
                subtitle: "Automatically manage memory usage",
                icon: "memorychip",
                color: DesignColors.info,
                isOn: Binding(
                    get: { settingsViewModel.userSettings.performanceSettings.memoryManagementEnabled },
                    set: { settingsViewModel.updateMemoryManagement($0) }
                )
            )
            
            Divider()
                .background(DesignColors.glassBorder)
                .opacity(0.3)
            
            // Adaptive Quality
            SettingsToggleView(
                title: "Adaptive Quality",
                subtitle: "Automatically adjust quality based on performance",
                icon: "wand.and.stars",
                color: DesignColors.accent,
                isOn: Binding(
                    get: { settingsViewModel.userSettings.performanceSettings.adaptiveQualityEnabled },
                    set: { settingsViewModel.updateAdaptiveQuality($0) }
                )
            )
            
            Divider()
                .background(DesignColors.glassBorder)
                .opacity(0.3)
            
            // Max Recording Duration
            SettingsSliderView(
                title: "Max Recording Duration",
                subtitle: "Maximum recording time in minutes",
                icon: "clock",
                color: DesignColors.warning,
                range: 60...1440, // 1 minute to 24 hours
                step: 60,
                value: Binding(
                    get: { settingsViewModel.userSettings.performanceSettings.maxRecordingDuration / 60 },
                    set: { settingsViewModel.updateMaxRecordingDuration($0 * 60) }
                )
            )
        }
    }
}

// MARK: - General Settings View

struct GeneralSettingsView: View {
    @ObservedObject var settingsViewModel: SettingsViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            // Auto Save to Gallery
            SettingsToggleView(
                title: "Auto Save to Gallery",
                subtitle: "Automatically save recordings to photo gallery",
                icon: "photo.on.rectangle",
                color: DesignColors.primary,
                isOn: Binding(
                    get: { $settingsViewModel.userSettings.generalSettings.autoSaveToGallery.wrappedValue },
                    set: { settingsViewModel.updateAutoSave($0) }
                )
            )
            
            Divider()
                .background(DesignColors.glassBorder)
                .opacity(0.3)
            
            // Location Metadata
            SettingsToggleView(
                title: "Location Metadata",
                subtitle: "Include location information in recordings",
                icon: "location",
                color: DesignColors.warning,
                isOn: Binding(
                    get: { settingsViewModel.userSettings.generalSettings.includeLocationMetadata },
                    set: { settingsViewModel.updateLocationMetadata($0) }
                )
            )
            
            Divider()
                .background(DesignColors.glassBorder)
                .opacity(0.3)
            
            // Analytics
            SettingsToggleView(
                title: "Analytics",
                subtitle: "Help improve the app by sharing usage data",
                icon: "chart.bar",
                color: DesignColors.info,
                isOn: Binding(
                    get: { settingsViewModel.userSettings.generalSettings.analyticsEnabled },
                    set: { settingsViewModel.updateAnalytics($0) }
                )
            )
            
            Divider()
                .background(DesignColors.glassBorder)
                .opacity(0.3)
            
            // Crash Reporting
            SettingsToggleView(
                title: "Crash Reporting",
                subtitle: "Automatically send crash reports",
                icon: "exclamationmark.triangle",
                color: DesignColors.error,
                isOn: Binding(
                    get: { settingsViewModel.userSettings.generalSettings.crashReportingEnabled },
                    set: { settingsViewModel.updateCrashReporting($0) }
                )
            )
            
            Divider()
                .background(DesignColors.glassBorder)
                .opacity(0.3)
            
            // Beta Features
            SettingsToggleView(
                title: "Beta Features",
                subtitle: "Enable experimental features",
                icon: "flask",
                color: DesignColors.accent,
                isOn: Binding(
                    get: { settingsViewModel.userSettings.generalSettings.betaFeaturesEnabled },
                    set: { settingsViewModel.updateBetaFeatures($0) }
                )
            )
            
            Divider()
                .background(DesignColors.glassBorder)
                .opacity(0.3)
            
            // Debug Mode
            SettingsToggleView(
                title: "Debug Mode",
                subtitle: "Enable debug information and tools",
                icon: "ladybug",
                color: DesignColors.secondary,
                isOn: Binding(
                    get: { settingsViewModel.userSettings.generalSettings.debugModeEnabled },
                    set: { settingsViewModel.updateDebugMode($0) }
                )
            )
        }
    }
}

// MARK: - Advanced Settings View

struct AdvancedSettingsView: View {
    @ObservedObject var settingsViewModel: SettingsViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            // Cloud Sync
            VStack(spacing: 0) {
                SettingsToggleView(
                    title: "Cloud Sync",
                    subtitle: "Sync settings across devices",
                    icon: "icloud",
                    color: DesignColors.primary,
                    isOn: Binding(
                        get: { settingsViewModel.isCloudSyncEnabled },
                        set: { _ in settingsViewModel.toggleCloudSync() }
                    )
                )
                
                if settingsViewModel.isCloudSyncEnabled {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Last Sync")
                                .font(.caption)
                                .foregroundColor(DesignColors.textOnGlassTertiary)
                            
                            if let lastSync = settingsViewModel.lastSyncDate {
                                Text(lastSync, style: .relative)
                                    .font(.body)
                                    .foregroundColor(DesignColors.textOnGlassSecondary)
                            } else {
                                Text("Never")
                                    .textStyle(TypographyPresets.Glass.body)
                                    .foregroundColor(DesignColors.textOnGlassSecondary)
                            }
                        }
                        
                        Spacer()
                        
                        if settingsViewModel.syncInProgress {
                            ProgressView()
                                .scaleEffect(0.8)
                                .foregroundColor(DesignColors.primary)
                        } else {
                            Button("Sync Now") {
                                settingsViewModel.forceSyncToCloud()
                            }
                            .font(.caption)
                            .foregroundColor(DesignColors.primary)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }
            }
            
            Divider()
                .background(DesignColors.glassBorder)
                .opacity(0.3)
            
            // Export Settings
            SettingsItemView(
                title: "Export Settings",
                subtitle: "Export settings to file",
                icon: "square.and.arrow.up",
                color: DesignColors.success
            ) {
                Button("Export") {
                    // Export settings
                }
                .font(.caption)
                .foregroundColor(DesignColors.success)
            }
            
            Divider()
                .background(DesignColors.glassBorder)
                .opacity(0.3)
            
            // Import Settings
            SettingsItemView(
                title: "Import Settings",
                subtitle: "Import settings from file",
                icon: "square.and.arrow.down",
                color: DesignColors.info
            ) {
                Button("Import") {
                    // Import settings
                }
                .font(.caption)
                .foregroundColor(DesignColors.info)
            }
            
            Divider()
                .background(DesignColors.glassBorder)
                .opacity(0.3)
            
            // Reset Settings
            SettingsItemView(
                title: "Reset Settings",
                subtitle: "Reset all settings to defaults",
                icon: "arrow.clockwise",
                color: DesignColors.error
            ) {
                Button("Reset") {
                    // Reset settings
                }
                .font(.caption)
                .foregroundColor(DesignColors.error)
            }
        }
    }
}

// MARK: - Export/Import Views

struct SettingsExportView: View {
    @ObservedObject var settingsViewModel: SettingsViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                Text("Export Settings")
                    .textStyle(TypographyPresets.Glass.title)
                    .padding()
                
                Text("Export your settings to share or backup")
                    .textStyle(TypographyPresets.Glass.body)
                    .foregroundColor(DesignColors.textOnGlassSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Spacer()
                
                LiquidGlassComponents.button(
                    "Export Settings",
                    action: {
                        Task {
                            do {
                                let data = try await settingsViewModel.exportSettings()
                                // Share the data
                            } catch {
                                print("Export failed: \(error)")
                            }
                        }
                    },
                    variant: .standard,
                    size: .large,
                    palette: .ocean,
                    animationType: .shimmer,
                    hapticStyle: .medium
                )
                .padding()
                
                Spacer()
            }
            .navigationTitle("Export Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct SettingsImportView: View {
    @ObservedObject var settingsViewModel: SettingsViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                Text("Import Settings")
                    .textStyle(TypographyPresets.Glass.title)
                    .padding()
                
                Text("Import settings from a file")
                    .textStyle(TypographyPresets.Glass.body)
                    .foregroundColor(DesignColors.textOnGlassSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Spacer()
                
                // File picker would go here
                
                Spacer()
            }
            .navigationTitle("Import Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}