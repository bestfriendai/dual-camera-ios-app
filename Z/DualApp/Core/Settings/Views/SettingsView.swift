//
//  SettingsView.swift
//  DualApp
//
//  Created by DualApp Team on 10/3/25.
//

import SwiftUI

struct SettingsView: View {
    // MARK: - State
    
    @StateObject private var settingsViewModel = SettingsViewModel()
    @State private var selectedSection: SettingsSection? = nil
    @State private var showingResetAlert = false
    @State private var showingExportSheet = false
    @State private var showingImportSheet = false
    
    // MARK: - Body
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                Color.black
                    .ignoresSafeArea()
                
                // Main content
                ScrollView {
                    LazyVStack(spacing: 0) {
                        // Header
                        settingsHeader
                        
                        // Settings sections
                        settingsSections
                        
                        // Footer
                        settingsFooter
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }
                
                // Floating action buttons
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        
                        // Export button
                        LiquidGlassComponents.button(
                            action: {
                                showingExportSheet = true
                            }
                        ) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        
                        // Reset button
                        LiquidGlassComponents.button(
                            action: {
                                showingResetAlert = true
                            }
                        ) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 16, weight: .semibold))
                        }
                    }
                    .padding(.trailing, 16)
                    .padding(.bottom, 100)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .navigationBarHidden(true)
            .onAppear {
                settingsViewModel.loadSettings()
            }
            .sheet(isPresented: $showingExportSheet) {
                SettingsExportView(settingsViewModel: settingsViewModel)
            }
            .sheet(isPresented: $showingImportSheet) {
                SettingsImportView(settingsViewModel: settingsViewModel)
            }
            .alert("Reset Settings", isPresented: $showingResetAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Reset", role: .destructive) {
                    Task {
                        await settingsViewModel.resetToDefaults()
                    }
                }
            } message: {
                Text("This will reset all settings to their default values. This action cannot be undone.")
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
    
    // MARK: - Settings Header
    
    private var settingsHeader: some View {
        VStack(spacing: 16) {
            // App icon and title
            HStack {
                Image(systemName: "camera.circle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(DesignColors.primary)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("DualApp")
                        .textStyle(TypographyPresets.Glass.title)
                    
                    Text("Professional Dual Camera Recording")
                        .textStyle(TypographyPresets.Glass.caption)
                }
                
                Spacer()
                
                // Sync status
                if settingsViewModel.isCloudSyncEnabled {
                    HStack(spacing: 4) {
                        Image(systemName: "icloud.fill")
                            .font(.system(size: 14))
                            .foregroundColor(DesignColors.success)
                        
                        Text("Synced")
                            .textStyle(TypographyPresets.Glass.caption)
                    }
                }
            }
            
            // Quick stats
            HStack(spacing: 16) {
                QuickStatView(
                    title: "Version",
                    value: settingsViewModel.appVersion,
                    icon: "info.circle",
                    color: DesignColors.info
                )
                
                QuickStatView(
                    title: "Storage",
                    value: settingsViewModel.storageUsage,
                    icon: "internaldrive",
                    color: DesignColors.warning
                )
                
                QuickStatView(
                    title: "Health",
                    value: settingsViewModel.systemHealth,
                    icon: "heart.fill",
                    color: settingsViewModel.systemHealthColor
                )
            }
        }
        .padding(.vertical, 16)
    }
    
    // MARK: - Settings Sections
    
    private var settingsSections: some View {
        LazyVStack(spacing: 16) {
            // Camera Settings
            SettingsSectionView(
                title: "Camera",
                icon: "camera.fill",
                color: DesignColors.primary,
                isExpanded: selectedSection == .camera
            ) {
                CameraSettingsView(settingsViewModel: settingsViewModel)
            }
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.3)) {
                    selectedSection = selectedSection == .camera ? nil : .camera
                }
            }
            
            // Audio Settings
            SettingsSectionView(
                title: "Audio",
                icon: "waveform",
                color: DesignColors.accent,
                isExpanded: selectedSection == .audio
            ) {
                AudioSettingsView(settingsViewModel: settingsViewModel)
            }
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.3)) {
                    selectedSection = selectedSection == .audio ? nil : .audio
                }
            }
            
            // Video Settings
            SettingsSectionView(
                title: "Video",
                icon: "video.fill",
                color: DesignColors.success,
                isExpanded: selectedSection == .video
            ) {
                VideoSettingsView(settingsViewModel: settingsViewModel)
            }
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.3)) {
                    selectedSection = selectedSection == .video ? nil : .video
                }
            }
            
            // UI Settings
            SettingsSectionView(
                title: "Appearance",
                icon: "paintbrush.fill",
                color: DesignColors.purple,
                isExpanded: selectedSection == .ui
            ) {
                UISettingsView(settingsViewModel: settingsViewModel)
            }
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.3)) {
                    selectedSection = selectedSection == .ui ? nil : .ui
                }
            }
            
            // Performance Settings
            SettingsSectionView(
                title: "Performance",
                icon: "speedometer",
                color: DesignColors.orange,
                isExpanded: selectedSection == .performance
            ) {
                PerformanceSettingsView(settingsViewModel: settingsViewModel)
            }
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.3)) {
                    selectedSection = selectedSection == .performance ? nil : .performance
                }
            }
            
            // General Settings
            SettingsSectionView(
                title: "General",
                icon: "gear",
                color: DesignColors.secondary,
                isExpanded: selectedSection == .general
            ) {
                GeneralSettingsView(settingsViewModel: settingsViewModel)
            }
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.3)) {
                    selectedSection = selectedSection == .general ? nil : .general
                }
            }
            
            // Advanced Settings
            SettingsSectionView(
                title: "Advanced",
                icon: "wrench.and.screwdriver.fill",
                color: DesignColors.error,
                isExpanded: selectedSection == .advanced
            ) {
                AdvancedSettingsView(settingsViewModel: settingsViewModel)
            }
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.3)) {
                    selectedSection = selectedSection == .advanced ? nil : .advanced
                }
            }
        }
    }
    
    // MARK: - Settings Footer
    
    private var settingsFooter: some View {
        VStack(spacing: 16) {
            // Diagnostics button
            LiquidGlassComponents.button(
                "Run Diagnostics",
                action: {
                    settingsViewModel.runDiagnostics()
                }
            )
            
            // Error report button
            if settingsViewModel.hasErrors {
                LiquidGlassComponents.button(
                    "View Error Report",
                    action: {
                        settingsViewModel.showErrorReport()
                    }
                )
            }
            
            // Copyright and version info
            VStack(spacing: 4) {
                Text("© 2025 DualApp Team")
                    .textStyle(TypographyPresets.Glass.caption)
                
                Text("Version \(settingsViewModel.appVersion) (\(settingsViewModel.buildNumber))")
                    .textStyle(TypographyPresets.Glass.caption)
            }
            .padding(.top, 8)
        }
        .padding(.vertical, 16)
    }
}

// MARK: - Quick Stat View

struct QuickStatView: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        LiquidGlassComponents.container(
            variant: .card,
            intensity: 0.4,
            palette: .monochrome,
            animationType: .none
        ) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(color)
                
                Text(value)
                    .textStyle(TypographyPresets.Glass.caption)
                    .foregroundColor(color)
                
                Text(title)
                    .textStyle(TypographyPresets.Glass.caption)
                    .foregroundColor(DesignColors.textOnGlassTertiary)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Settings Section View

struct SettingsSectionView<Content: View>: View {
    let title: String
    let icon: String
    let color: Color
    let isExpanded: Bool
    let content: () -> Content
    
    @State private var isHovered = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Section header
            LiquidGlassComponents.container(
                variant: .card,
                intensity: isHovered ? 0.7 : 0.5,
                palette: .monochrome,
                animationType: .shimmer
            ) {
                HStack {
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(color)
                        .frame(width: 24)
                    
                    Text(title)
                        .textStyle(TypographyPresets.Glass.title)
                        .foregroundColor(DesignColors.textOnGlass)
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(DesignColors.textOnGlassSecondary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                        .animation(.easeInOut(duration: 0.3), value: isExpanded)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.2)) {
                    isHovered = hovering
                }
            }
            
            // Section content
            if isExpanded {
                content()
                    .transition(.asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal: .move(edge: .top).combined(with: .opacity)
                    ))
            }
        }
    }
}

// MARK: - Settings Item View

struct SettingsItemView<Content: View>: View {
    let title: String
    let subtitle: String?
    let icon: String?
    let color: Color?
    let content: () -> Content
    
    @State private var isHovered = false
    
    init(
        title: String,
        subtitle: String? = nil,
        icon: String? = nil,
        color: Color? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.color = color
        self.content = content
    }
    
    var body: some View {
        LiquidGlassComponents.container(
            variant: .minimal,
            intensity: isHovered ? 0.4 : 0.2,
            palette: .monochrome,
            animationType: .none
        ) {
            HStack {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(color ?? DesignColors.textOnGlass)
                        .frame(width: 20)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .textStyle(TypographyPresets.Glass.body)
                        .foregroundColor(DesignColors.textOnGlass)
                    
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .textStyle(TypographyPresets.Glass.caption)
                            .foregroundColor(DesignColors.textOnGlassTertiary)
                    }
                }
                
                Spacer()
                
                content()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Settings Toggle View

struct SettingsToggleView: View {
    let title: String
    let subtitle: String?
    let icon: String?
    let color: Color?
    @Binding var isOn: Bool
    
    var body: some View {
        SettingsItemView(
            title: title,
            subtitle: subtitle,
            icon: icon,
            color: color
        ) {
            Toggle("", isOn: $isOn)
                .toggleStyle(GlassToggleStyle())
        }
    }
}

// MARK: - Settings Slider View

struct SettingsSliderView: View {
    let title: String
    let subtitle: String?
    let icon: String?
    let color: Color?
    let range: ClosedRange<Double>
    let step: Double?
    @Binding var value: Double
    
    @State private var isHovered = false
    
    var body: some View {
        VStack(spacing: 8) {
            SettingsItemView(
                title: title,
                subtitle: subtitle,
                icon: icon,
                color: color
            ) {
                Text(String(format: "%.1f", value))
                    .textStyle(TypographyPresets.Glass.body)
                    .foregroundColor(DesignColors.textOnGlass)
                    .frame(minWidth: 40)
            }
            
            // Slider
            LiquidGlassComponents.container(
                variant: .minimal,
                intensity: 0.3,
                palette: .monochrome,
                animationType: .none
            ) {
                Slider(
                    value: $value,
                    in: range,
                    step: step ?? 0.1
                )
                .accentColor(color ?? DesignColors.primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
        }
    }
}

// MARK: - Settings Picker View

struct SettingsPickerView<T: CaseIterable & Hashable & CustomStringConvertible>: View {
    let title: String
    let subtitle: String?
    let icon: String?
    let color: Color?
    @Binding var selection: T
    
    var body: some View {
        SettingsItemView(
            title: title,
            subtitle: subtitle,
            icon: icon,
            color: color
        ) {
            Menu {
                ForEach(Array(T.allCases), id: \.self) { option in
                    Button(option.description) {
                        selection = option
                    }
                }
            } label: {
                HStack {
                    Text(selection.description)
                        .textStyle(TypographyPresets.Glass.body)
                        .foregroundColor(DesignColors.textOnGlass)
                    
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(DesignColors.textOnGlassSecondary)
                }
            }
        }
    }
}

// MARK: - Glass Toggle Style (using existing implementation from AudioExportManager)

// MARK: - Settings Section Enum

enum SettingsSection: String, CaseIterable {
    case camera = "camera"
    case audio = "audio"
    case video = "video"
    case ui = "ui"
    case performance = "performance"
    case general = "general"
    case advanced = "advanced"
}

// MARK: - Preview

#Preview {
    SettingsView()
        .preferredColorScheme(.dark)
}