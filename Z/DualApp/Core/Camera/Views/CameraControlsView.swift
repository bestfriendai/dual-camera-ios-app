//
//  CameraControlsView.swift
//  DualApp
//
//  Created by DualApp Team on 10/3/25.
//

import SwiftUI

// MARK: - Camera Controls View

struct CameraControlsView: View {
    
    // MARK: - Properties
    
    let dualCameraSession: DualCameraSession
    @Binding var configuration: CameraConfiguration
    @Binding var isRecording: Bool
    @Binding var selectedCamera: CameraPosition
    @Binding var renderMode: RenderMode
    @Binding var showComposite: Bool
    
    // MARK: - State
    
    @State private var showingSettings = false
    @State private var showingAdvancedControls = false
    @State private var showingQualitySelector = false
    @State private var showingFilterSelector = false
    @State private var showingModeSelector = false
    @State private var hapticManager = HapticFeedbackManager()
    
    // MARK: - Body
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Main controls
                VStack(spacing: 0) {
                    // Top controls
                    topControls
                    
                    Spacer()
                    
                    // Bottom controls
                    bottomControls
                }
                
                // Settings sheet
                if showingSettings {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                showingSettings = false
                            }
                        }
                    
                    SettingsSheetView(
                        configuration: $configuration,
                        isPresented: $showingSettings
                    )
                    .transition(.move(edge: .bottom))
                }
                
                // Advanced controls sheet
                if showingAdvancedControls {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                showingAdvancedControls = false
                            }
                        }
                    
                    AdvancedControlsSheetView(
                        dualCameraSession: dualCameraSession,
                        configuration: $configuration,
                        isPresented: $showingAdvancedControls
                    )
                    .transition(.move(edge: .bottom))
                }
                
                // Quality selector sheet
                if showingQualitySelector {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                showingQualitySelector = false
                            }
                        }
                    
                    QualitySelectorSheetView(
                        configuration: $configuration,
                        isPresented: $showingQualitySelector
                    )
                    .transition(.move(edge: .bottom))
                }
                
                // Filter selector sheet
                if showingFilterSelector {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                showingFilterSelector = false
                            }
                        }
                    
                    FilterSelectorSheetView(
                        configuration: $configuration,
                        isPresented: $showingFilterSelector
                    )
                    .transition(.move(edge: .bottom))
                }
                
                // Mode selector sheet
                if showingModeSelector {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                showingModeSelector = false
                            }
                        }
                    
                    ModeSelectorSheetView(
                        configuration: $configuration,
                        isPresented: $showingModeSelector
                    )
                    .transition(.move(edge: .bottom))
                }
            }
        }
    }
    
    // MARK: - Top Controls
    
    private var topControls: some View {
        HStack {
            // Camera switcher
            cameraSwitcher
            
            Spacer()
            
            // Mode selector
            modeSelector
            
            Spacer()
            
            // Filter selector
            filterSelector
            
            Spacer()
            
            // Settings button
            settingsButton
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
    }
    
    // MARK: - Bottom Controls
    
    private var bottomControls: some View {
        HStack(alignment: .bottom) {
            // Gallery button
            galleryButton
            
            Spacer()
            
            // Quality selector
            qualitySelector
            
            Spacer()
            
            // Recording button
            recordingButton
            
            Spacer()
            
            // Composite toggle
            compositeToggle
            
            Spacer()
            
            // Advanced controls
            advancedControlsButton
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 10)
    }
    
    // MARK: - Camera Switcher
    
    private var cameraSwitcher: some View {
        LiquidGlassButton(
            action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    selectedCamera = selectedCamera == .front ? .back : .front
                }
                hapticManager.lightImpact()
            },
            label: {
                HStack(spacing: 8) {
                    Image(systemName: selectedCamera.icon)
                        .font(.title3)
                        .foregroundColor(.white)
                    
                    Text(selectedCamera.description)
                        .font(.caption)
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
        )
    }
    
    // MARK: - Mode Selector
    
    private var modeSelector: some View {
        LiquidGlassButton(
            action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showingModeSelector = true
                }
                hapticManager.lightImpact()
            },
            label: {
                Image(systemName: "camera.metering.spot")
                    .font(.title3)
                    .foregroundColor(.white)
                    .padding(12)
            }
        )
    }
    
    // MARK: - Filter Selector
    
    private var filterSelector: some View {
        LiquidGlassButton(
            action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showingFilterSelector = true
                }
                hapticManager.lightImpact()
            },
            label: {
                Image(systemName: "camera.filters")
                    .font(.title3)
                    .foregroundColor(.white)
                    .padding(12)
            }
        )
    }
    
    // MARK: - Settings Button
    
    private var settingsButton: some View {
        LiquidGlassButton(
            action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showingSettings = true
                }
                hapticManager.lightImpact()
            },
            label: {
                Image(systemName: "gearshape.fill")
                    .font(.title3)
                    .foregroundColor(.white)
                    .padding(12)
            }
        )
    }
    
    // MARK: - Gallery Button
    
    private var galleryButton: some View {
        LiquidGlassButton(
            action: {
                // Open gallery
                hapticManager.lightImpact()
            },
            label: {
                Image(systemName: "photo.stack")
                    .font(.title3)
                    .foregroundColor(.white)
                    .padding(12)
            }
        )
    }
    
    // MARK: - Quality Selector
    
    private var qualitySelector: some View {
        LiquidGlassButton(
            action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showingQualitySelector = true
                }
                hapticManager.lightImpact()
            },
            label: {
                VStack(spacing: 2) {
                    Text(configuration.quality.shortDescription)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                    
                    Text("\(configuration.frameRate)fps")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.8))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
        )
    }
    
    // MARK: - Recording Button
    
    private var recordingButton: some View {
        Button(action: {
            Task {
                if isRecording {
                    try? await dualCameraSession.stopRecording()
                } else {
                    try? await dualCameraSession.startRecording()
                }
            }
            hapticManager.heavyImpact()
        }) {
            ZStack {
                Circle()
                    .fill(isRecording ? Color.red : Color.white)
                    .frame(width: 70, height: 70)
                    .scaleEffect(isRecording ? 1.1 : 1.0)
                    .animation(.easeInOut(duration: 0.2), value: isRecording)
                    .shadow(color: isRecording ? .red.opacity(0.5) : .white.opacity(0.3), radius: 10, x: 0, y: 0)
                
                if !isRecording {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 60, height: 60)
                }
            }
            .overlay(
                Circle()
                    .stroke(Color.white.opacity(0.2), lineWidth: 2)
                    .frame(width: 80, height: 80)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Composite Toggle
    
    private var compositeToggle: some View {
        LiquidGlassButton(
            action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    showComposite.toggle()
                }
                hapticManager.lightImpact()
            },
            label: {
                HStack(spacing: 6) {
                    Image(systemName: showComposite ? "rectangle.split.2x1" : "rectangle")
                        .font(.caption)
                        .foregroundColor(.white)
                    
                    Text(showComposite ? "Both" : "Single")
                        .font(.caption2)
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
            }
        )
    }
    
    // MARK: - Advanced Controls Button
    
    private var advancedControlsButton: some View {
        LiquidGlassButton(
            action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showingAdvancedControls = true
                }
                hapticManager.lightImpact()
            },
            label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.title3)
                    .foregroundColor(.white)
                    .padding(12)
            }
        )
    }
}

// MARK: - Liquid Glass Button

struct LiquidGlassButton<Content: View>: View {
    let action: () -> Void
    let label: () -> Content
    
    @State private var isPressed = false
    @State private var shimmerOffset: CGFloat = -200
    
    var body: some View {
        Button(action: action) {
            label()
                .background(
                    ZStack {
                        // Glass background
                        RoundedRectangle(cornerRadius: 20)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.2),
                                        Color.white.opacity(0.1),
                                        Color.white.opacity(0.05)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(
                                        RadialGradient(
                                            colors: [
                                                Color.white.opacity(0.1),
                                                Color.clear
                                            ],
                                            center: .center,
                                            startRadius: 5,
                                            endRadius: 30
                                        )
                                    )
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(
                                        LinearGradient(
                                            colors: [
                                                Color.white.opacity(0.3),
                                                Color.white.opacity(0.1),
                                                Color.white.opacity(0.2)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1
                                    )
                            )
                        
                        // Shimmer effect
                        RoundedRectangle(cornerRadius: 20)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.clear,
                                        Color.white.opacity(0.3),
                                        Color.clear
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: 200)
                            .offset(x: shimmerOffset)
                            .clipped()
                    }
                )
                .scaleEffect(isPressed ? 0.95 : 1.0)
                .animation(.easeInOut(duration: 0.1), value: isPressed)
        }
        .buttonStyle(PlainButtonStyle())
        .onAppear {
            withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                shimmerOffset = 200
            }
        }
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        }, perform: {})
    }
}

// MARK: - Settings Sheet View

struct SettingsSheetView: View {
    @Binding var configuration: CameraConfiguration
    @Binding var isPresented: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button("Close") {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isPresented = false
                    }
                }
                .foregroundColor(.white)
                
                Spacer()
                
                Text("Settings")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Spacer()
                
                Button("Reset") {
                    // Reset settings
                }
                .foregroundColor(.white)
            }
            .padding()
            .background(
                Color.black.opacity(0.8)
                    .overlay(
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.1),
                                        Color.clear
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    )
            )
            
            // Settings content
            ScrollView {
                VStack(spacing: 20) {
                    // Audio settings
                    SettingsSection(title: "Audio") {
                        Toggle("Enable Audio", isOn: $configuration.audioEnabled)
                        
                        if configuration.audioEnabled {
                            Picker("Audio Quality", selection: $configuration.audioQuality) {
                                ForEach(AudioQuality.allCases, id: \.self) { quality in
                                    Text(quality.description).tag(quality)
                                }
                            }
                            .pickerStyle(SegmentedPickerStyle())
                            
                            Toggle("Noise Reduction", isOn: $configuration.noiseReductionEnabled)
                            Toggle("Stereo Recording", isOn: $configuration.stereoRecordingEnabled)
                        }
                    }
                    
                    // Video settings
                    SettingsSection(title: "Video") {
                        Toggle("Video Stabilization", isOn: $configuration.videoStabilizationEnabled)
                        Toggle("Cinematic Stabilization", isOn: $configuration.cinematicStabilizationEnabled)
                        Toggle("Optical Image Stabilization", isOn: $configuration.opticalImageStabilizationEnabled)
                        Toggle("HDR", isOn: $configuration.hdrEnabled)
                    }
                    
                    // Performance settings
                    SettingsSection(title: "Performance") {
                        Toggle("Thermal Management", isOn: $configuration.thermalManagementEnabled)
                        Toggle("Battery Optimization", isOn: $configuration.batteryOptimizationEnabled)
                        Toggle("Adaptive Quality", isOn: $configuration.adaptiveQualityEnabled)
                    }
                    
                    // Metadata settings
                    SettingsSection(title: "Metadata") {
                        Toggle("Include Location", isOn: $configuration.includeLocationMetadata)
                        Toggle("Include Device Info", isOn: $configuration.includeDeviceMetadata)
                        Toggle("Include Timestamp", isOn: $configuration.includeTimestampMetadata)
                    }
                }
                .padding()
            }
            .background(Color.black.opacity(0.7))
        }
        .frame(height: 500)
        .background(
            Color.black.opacity(0.8)
                .overlay(
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [
                                        Color.white.opacity(0.1),
                                        Color.clear
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                        )
                )
        )
        .cornerRadius(20, corners: [.topLeft, .topRight])
        .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: -5)
    }
}

// MARK: - Advanced Controls Sheet View

struct AdvancedControlsSheetView: View {
    let dualCameraSession: DualCameraSession
    @Binding var configuration: CameraConfiguration
    @Binding var isPresented: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button("Close") {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isPresented = false
                    }
                }
                .foregroundColor(.white)
                
                Spacer()
                
                Text("Advanced Controls")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Spacer()
                
                Button("Reset") {
                    // Reset controls
                }
                .foregroundColor(.white)
            }
            .padding()
            .background(
                Color.black.opacity(0.8)
                    .overlay(
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.1),
                                        Color.clear
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    )
            )
            
            // Advanced controls content
            ScrollView {
                VStack(spacing: 20) {
                    // Focus controls
                    AdvancedControlsSection(title: "Focus") {
                        Picker("Focus Mode", selection: $configuration.focusMode) {
                            ForEach(FocusMode.allCases, id: \.self) { mode in
                                Text(mode.description).tag(mode)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        
                        Slider(value: .constant(0.5), in: 0...1) {
                            Text("Focus")
                        }
                    }
                    
                    // Exposure controls
                    AdvancedControlsSection(title: "Exposure") {
                        Picker("Exposure Mode", selection: $configuration.exposureMode) {
                            ForEach(ExposureMode.allCases, id: \.self) { mode in
                                Text(mode.description).tag(mode)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        
                        Slider(value: .constant(0.5), in: 0...1) {
                            Text("Exposure")
                        }
                    }
                    
                    // White balance controls
                    AdvancedControlsSection(title: "White Balance") {
                        Picker("White Balance", selection: $configuration.whiteBalanceMode) {
                            ForEach(WhiteBalanceMode.allCases, id: \.self) { mode in
                                Text(mode.description).tag(mode)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        
                        Slider(value: .constant(0.5), in: 0...1) {
                            Text("Temperature")
                        }
                    }
                    
                    // Zoom controls
                    AdvancedControlsSection(title: "Zoom") {
                        Slider(value: $configuration.zoomLevel, in: 1...configuration.maxZoomLevel) {
                            Text("Zoom: \(String(format: "%.1fx", configuration.zoomLevel))")
                        }
                    }
                    
                    // Special features
                    AdvancedControlsSection(title: "Special Features") {
                        Toggle("Portrait Mode", isOn: $configuration.portraitModeEnabled)
                        Toggle("Night Mode", isOn: $configuration.nightModeEnabled)
                        Toggle("Slow Motion", isOn: $configuration.slowMotionEnabled)
                        Toggle("Time Lapse", isOn: $configuration.timeLapseEnabled)
                        Toggle("Cinematic Mode", isOn: $configuration.cinematicModeEnabled)
                    }
                }
                .padding()
            }
            .background(Color.black.opacity(0.7))
        }
        .frame(height: 600)
        .background(
            Color.black.opacity(0.8)
                .overlay(
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [
                                        Color.white.opacity(0.1),
                                        Color.clear
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                        )
                )
        )
        .cornerRadius(20, corners: [.topLeft, .topRight])
        .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: -5)
    }
}

// MARK: - Quality Selector Sheet View

struct QualitySelectorSheetView: View {
    @Binding var configuration: CameraConfiguration
    @Binding var isPresented: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button("Close") {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isPresented = false
                    }
                }
                .foregroundColor(.white)
                
                Spacer()
                
                Text("Video Quality")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Spacer()
                
                EmptyView()
            }
            .padding()
            .background(
                Color.black.opacity(0.8)
                    .overlay(
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.1),
                                        Color.clear
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    )
            )
            
            // Quality options
            ScrollView {
                VStack(spacing: 16) {
                    ForEach([VideoQuality.hd720, VideoQuality.hd1080, VideoQuality.uhd4k], id: \.self) { quality in
                        QualityOptionView(
                            quality: quality,
                            frameRate: configuration.frameRate,
                            isSelected: configuration.quality == quality,
                            action: {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    configuration = CameraConfiguration(
                                        quality: quality,
                                        frameRate: configuration.frameRate,
                                        hdrEnabled: configuration.hdrEnabled,
                                        multiCamEnabled: configuration.multiCamEnabled,
                                        focusMode: configuration.focusMode,
                                        exposureMode: configuration.exposureMode,
                                        whiteBalanceMode: configuration.whiteBalanceMode,
                                        flashMode: configuration.flashMode,
                                        preferredCamera: configuration.preferredCamera,
                                        zoomLevel: configuration.zoomLevel,
                                        maxZoomLevel: configuration.maxZoomLevel,
                                        enableOpticalZoom: configuration.enableOpticalZoom,
                                        audioEnabled: configuration.audioEnabled,
                                        audioQuality: configuration.audioQuality,
                                        noiseReductionEnabled: configuration.noiseReductionEnabled,
                                        stereoRecordingEnabled: configuration.stereoRecordingEnabled,
                                        videoStabilizationEnabled: configuration.videoStabilizationEnabled,
                                        cinematicStabilizationEnabled: configuration.cinematicStabilizationEnabled,
                                        opticalImageStabilizationEnabled: configuration.opticalImageStabilizationEnabled,
                                        portraitModeEnabled: configuration.portraitModeEnabled,
                                        nightModeEnabled: configuration.nightModeEnabled,
                                        slowMotionEnabled: configuration.slowMotionEnabled,
                                        timeLapseEnabled: configuration.timeLapseEnabled,
                                        cinematicModeEnabled: configuration.cinematicModeEnabled,
                                        colorSpace: configuration.colorSpace,
                                        colorFilter: configuration.colorFilter,
                                        toneMappingEnabled: configuration.toneMappingEnabled,
                                        dynamicRange: configuration.dynamicRange,
                                        lowLightBoostEnabled: configuration.lowLightBoostEnabled,
                                        thermalManagementEnabled: configuration.thermalManagementEnabled,
                                        batteryOptimizationEnabled: configuration.batteryOptimizationEnabled,
                                        adaptiveQualityEnabled: configuration.adaptiveQualityEnabled,
                                        outputFormat: configuration.outputFormat,
                                        compressionQuality: configuration.compressionQuality,
                                        keyFrameInterval: configuration.keyFrameInterval,
                                        enableTemporalCompression: configuration.enableTemporalCompression,
                                        previewFrameRate: configuration.previewFrameRate,
                                        previewQuality: configuration.previewQuality,
                                        enableGridOverlay: configuration.enableGridOverlay,
                                        enableLevelIndicator: configuration.enableLevelIndicator,
                                        includeLocationMetadata: configuration.includeLocationMetadata,
                                        includeDeviceMetadata: configuration.includeDeviceMetadata,
                                        includeTimestampMetadata: configuration.includeTimestampMetadata,
                                        customMetadata: configuration.customMetadata,
                                        sceneDetectionEnabled: configuration.sceneDetectionEnabled,
                                        subjectTrackingEnabled: configuration.subjectTrackingEnabled,
                                        autoEnhancementEnabled: configuration.autoEnhancementEnabled,
                                        smartHDR: configuration.smartHDR,
                                        voiceControlEnabled: configuration.voiceControlEnabled,
                                        hapticFeedbackEnabled: configuration.hapticFeedbackEnabled,
                                        audioDescriptionsEnabled: configuration.audioDescriptionsEnabled
                                    )
                                    isPresented = false
                                }
                            }
                        )
                    }
                }
                .padding()
            }
            .background(Color.black.opacity(0.7))
        }
        .frame(height: 400)
        .background(
            Color.black.opacity(0.8)
                .overlay(
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [
                                        Color.white.opacity(0.1),
                                        Color.clear
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                        )
                )
        )
        .cornerRadius(20, corners: [.topLeft, .topRight])
        .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: -5)
    }
}

// MARK: - Filter Selector Sheet View

struct FilterSelectorSheetView: View {
    @Binding var configuration: CameraConfiguration
    @Binding var isPresented: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button("Close") {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isPresented = false
                    }
                }
                .foregroundColor(.white)
                
                Spacer()
                
                Text("Color Filters")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Spacer()
                
                EmptyView()
            }
            .padding()
            .background(
                Color.black.opacity(0.8)
                    .overlay(
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.1),
                                        Color.clear
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    )
            )
            
            // Filter options
            ScrollView {
                VStack(spacing: 16) {
                    ForEach(ColorFilter.allCases, id: \.self) { filter in
                        FilterOptionView(
                            filter: filter,
                            isSelected: configuration.colorFilter == filter,
                            action: {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    configuration = CameraConfiguration(
                                        quality: configuration.quality,
                                        frameRate: configuration.frameRate,
                                        hdrEnabled: configuration.hdrEnabled,
                                        multiCamEnabled: configuration.multiCamEnabled,
                                        focusMode: configuration.focusMode,
                                        exposureMode: configuration.exposureMode,
                                        whiteBalanceMode: configuration.whiteBalanceMode,
                                        flashMode: configuration.flashMode,
                                        preferredCamera: configuration.preferredCamera,
                                        zoomLevel: configuration.zoomLevel,
                                        maxZoomLevel: configuration.maxZoomLevel,
                                        enableOpticalZoom: configuration.enableOpticalZoom,
                                        audioEnabled: configuration.audioEnabled,
                                        audioQuality: configuration.audioQuality,
                                        noiseReductionEnabled: configuration.noiseReductionEnabled,
                                        stereoRecordingEnabled: configuration.stereoRecordingEnabled,
                                        videoStabilizationEnabled: configuration.videoStabilizationEnabled,
                                        cinematicStabilizationEnabled: configuration.cinematicStabilizationEnabled,
                                        opticalImageStabilizationEnabled: configuration.opticalImageStabilizationEnabled,
                                        portraitModeEnabled: configuration.portraitModeEnabled,
                                        nightModeEnabled: configuration.nightModeEnabled,
                                        slowMotionEnabled: configuration.slowMotionEnabled,
                                        timeLapseEnabled: configuration.timeLapseEnabled,
                                        cinematicModeEnabled: configuration.cinematicModeEnabled,
                                        colorSpace: configuration.colorSpace,
                                        colorFilter: filter,
                                        toneMappingEnabled: configuration.toneMappingEnabled,
                                        dynamicRange: configuration.dynamicRange,
                                        lowLightBoostEnabled: configuration.lowLightBoostEnabled,
                                        thermalManagementEnabled: configuration.thermalManagementEnabled,
                                        batteryOptimizationEnabled: configuration.batteryOptimizationEnabled,
                                        adaptiveQualityEnabled: configuration.adaptiveQualityEnabled,
                                        outputFormat: configuration.outputFormat,
                                        compressionQuality: configuration.compressionQuality,
                                        keyFrameInterval: configuration.keyFrameInterval,
                                        enableTemporalCompression: configuration.enableTemporalCompression,
                                        previewFrameRate: configuration.previewFrameRate,
                                        previewQuality: configuration.previewQuality,
                                        enableGridOverlay: configuration.enableGridOverlay,
                                        enableLevelIndicator: configuration.enableLevelIndicator,
                                        includeLocationMetadata: configuration.includeLocationMetadata,
                                        includeDeviceMetadata: configuration.includeDeviceMetadata,
                                        includeTimestampMetadata: configuration.includeTimestampMetadata,
                                        customMetadata: configuration.customMetadata,
                                        sceneDetectionEnabled: configuration.sceneDetectionEnabled,
                                        subjectTrackingEnabled: configuration.subjectTrackingEnabled,
                                        autoEnhancementEnabled: configuration.autoEnhancementEnabled,
                                        smartHDR: configuration.smartHDR,
                                        voiceControlEnabled: configuration.voiceControlEnabled,
                                        hapticFeedbackEnabled: configuration.hapticFeedbackEnabled,
                                        audioDescriptionsEnabled: configuration.audioDescriptionsEnabled
                                    )
                                    isPresented = false
                                }
                            }
                        )
                    }
                }
                .padding()
            }
            .background(Color.black.opacity(0.7))
        }
        .frame(height: 400)
        .background(
            Color.black.opacity(0.8)
                .overlay(
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [
                                        Color.white.opacity(0.1),
                                        Color.clear
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                        )
                )
        )
        .cornerRadius(20, corners: [.topLeft, .topRight])
        .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: -5)
    }
}

// MARK: - Mode Selector Sheet View

struct ModeSelectorSheetView: View {
    @Binding var configuration: CameraConfiguration
    @Binding var isPresented: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button("Close") {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isPresented = false
                    }
                }
                .foregroundColor(.white)
                
                Spacer()
                
                Text("Recording Modes")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Spacer()
                
                EmptyView()
            }
            .padding()
            .background(
                Color.black.opacity(0.8)
                    .overlay(
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.1),
                                        Color.clear
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    )
            )
            
            // Mode options
            ScrollView {
                VStack(spacing: 16) {
                    ForEach([CameraConfiguration.default, CameraConfiguration.highQuality, CameraConfiguration.lowPower, CameraConfiguration.portrait, CameraConfiguration.cinematic, CameraConfiguration.slowMotion, CameraConfiguration.timeLapse, CameraConfiguration.nightMode], id: \.description) { preset in
                        ModeOptionView(
                            preset: preset,
                            isSelected: configuration.description == preset.description,
                            action: {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    configuration = preset
                                    isPresented = false
                                }
                            }
                        )
                    }
                }
                .padding()
            }
            .background(Color.black.opacity(0.7))
        }
        .frame(height: 500)
        .background(
            Color.black.opacity(0.8)
                .overlay(
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [
                                        Color.white.opacity(0.1),
                                        Color.clear
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                        )
                )
        )
        .cornerRadius(20, corners: [.topLeft, .topRight])
        .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: -5)
    }
}

// MARK: - Settings Section

struct SettingsSection<Content: View>: View {
    let title: String
    let content: () -> Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundColor(.white)
            
            VStack(spacing: 12) {
                content()
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

// MARK: - Advanced Controls Section

struct AdvancedControlsSection<Content: View>: View {
    let title: String
    let content: () -> Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundColor(.white)
            
            VStack(spacing: 12) {
                content()
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

// MARK: - Quality Option View

struct QualityOptionView: View {
    let quality: VideoQuality
    let frameRate: Int32
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(quality.description)
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Text("\(quality.resolution.width) × \(quality.resolution.height)")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                    
                    Text("\(frameRate) fps")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? Color.white.opacity(0.2) : Color.white.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(isSelected ? Color.white.opacity(0.4) : Color.white.opacity(0.2), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Filter Option View

struct FilterOptionView: View {
    let filter: ColorFilter
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: filter.icon)
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: 30)
                
                Text(filter.description)
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? Color.white.opacity(0.2) : Color.white.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(isSelected ? Color.white.opacity(0.4) : Color.white.opacity(0.2), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Mode Option View

struct ModeOptionView: View {
    let preset: CameraConfiguration
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(preset.description)
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                    }
                }
                
                Text(preset.detailedDescription)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.leading)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? Color.white.opacity(0.2) : Color.white.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(isSelected ? Color.white.opacity(0.4) : Color.white.opacity(0.2), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Corner Radius Extension

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}