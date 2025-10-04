//
//  AudioControlsView.swift
//  DualApp
//
//  Created by DualApp Team on 10/3/25.
//

import SwiftUI
import AVFoundation

// MARK: - Audio Controls View

struct AudioControlsView: View {
    // MARK: - State Properties
    
    @StateObject private var audioManager: AudioManager
    @State private var audioLevels: AudioLevels = AudioLevels()
    @State private var isRecording = false
    @State private var isPaused = false
    @State private var currentConfiguration: AudioConfiguration = .default
    @State private var availableMicrophones: [MicrophoneConfiguration] = []
    @State private var selectedMicrophone: MicrophoneConfiguration = .default
    @State private var selectedPreset: AudioPreset?
    @State private var showingMicrophoneSelection = false
    @State private var showingPresetSelection = false
    @State private var showingAdvancedSettings = false
    @State private var showingFormatSelection = false
    @State private var isMuted = false
    @State private var gain: Float = 1.0
    @State private var recordingDuration: TimeInterval = 0.0
    @State private var recordingTimer: Timer?
    
    // MARK: - UI Properties
    
    private let style: LiquidGlassStyle
    private let animationType: LiquidGlassAnimationType
    private let intensity: Double
    
    // MARK: - Initialization
    
    init(
        audioManager: AudioManager,
        style: LiquidGlassStyle = .default,
        intensity: Double = 0.7,
        animationType: LiquidGlassAnimationType = .shimmer
    ) {
        self._audioManager = StateObject(wrappedValue: audioManager)
        self.style = style
        self.intensity = intensity
        self.animationType = animationType
    }
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with title and status
            headerView
            
            // Audio level meters
            audioLevelMetersView
            
            // Main controls
            mainControlsView
            
            // Microphone and preset selection
            configurationView
            
            // Advanced settings
            if showingAdvancedSettings {
                advancedSettingsView
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
            setupAudioControls()
        }
        .onDisappear {
            cleanupAudioControls()
        }
        .sheet(isPresented: $showingMicrophoneSelection) {
            microphoneSelectionView
        }
        .sheet(isPresented: $showingPresetSelection) {
            presetSelectionView
        }
        .sheet(isPresented: $showingFormatSelection) {
            formatSelectionView
        }
    }
    
    // MARK: - View Components
    
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Audio Controls")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(DesignColors.textOnGlass)
                
                Text(statusText)
                    .font(.caption)
                    .foregroundColor(DesignColors.textOnGlass.opacity(0.8))
            }
            
            Spacer()
            
            // Settings button
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showingAdvancedSettings.toggle()
                }
            }) {
                Image(systemName: "gearshape.fill")
                    .font(.title3)
                    .foregroundColor(DesignColors.textOnGlass)
            }
            .buttonStyle(GlassButtonStyle(style: .minimal))
        }
        .padding(.bottom, 16)
    }
    
    private var audioLevelMetersView: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Audio Levels")
                    .font(.headline)
                    .foregroundColor(DesignColors.textOnGlass)
                
                Spacer()
                
                Text("\(Int(audioLevels.averagePower)) dB")
                    .font(.caption)
                    .foregroundColor(DesignColors.textOnGlass.opacity(0.8))
            }
            
            // Stereo level meters
            HStack(spacing: 16) {
                // Left channel
                VStack(alignment: .leading, spacing: 4) {
                    Text("L")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(DesignColors.textOnGlass)
                    
                    LevelMeterView(
                        level: audioLevels.leftChannelLevel,
                        peakLevel: audioLevels.peakLevel,
                        isClipping: audioLevels.isClipping
                    )
                }
                
                // Right channel
                VStack(alignment: .leading, spacing: 4) {
                    Text("R")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(DesignColors.textOnGlass)
                    
                    LevelMeterView(
                        level: audioLevels.rightChannelLevel,
                        peakLevel: audioLevels.peakLevel,
                        isClipping: audioLevels.isClipping
                    )
                }
            }
            
            // Combined level meter
            VStack(alignment: .leading, spacing: 4) {
                Text("Combined")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(DesignColors.textOnGlass)
                
                LevelMeterView(
                    level: audioLevels.rmsLevel,
                    peakLevel: audioLevels.peakLevel,
                    isClipping: audioLevels.isClipping,
                    showStereo: false
                )
            }
        }
        .padding(.bottom, 20)
    }
    
    private var mainControlsView: some View {
        VStack(spacing: 20) {
            // Recording controls
            HStack(spacing: 24) {
                // Record/Stop button
                Button(action: {
                    if isRecording {
                        stopRecording()
                    } else {
                        startRecording()
                    }
                }) {
                    ZStack {
                        Circle()
                            .fill(isRecording ? Color.red : DesignColors.accent)
                            .frame(width: 80, height: 80)
                            .shadow(color: isRecording ? Color.red.opacity(0.3) : DesignColors.accent.opacity(0.3), radius: 8, x: 0, y: 4)
                        
                        Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                            .font(.title)
                            .foregroundColor(.white)
                    }
                }
                .buttonStyle(GlassButtonStyle(style: .button))
                
                // Pause/Resume button
                if isRecording {
                    Button(action: {
                        if isPaused {
                            resumeRecording()
                        } else {
                            pauseRecording()
                        }
                    }) {
                        ZStack {
                            Circle()
                                .fill(DesignColors.secondary)
                                .frame(width: 60, height: 60)
                                .shadow(color: DesignColors.secondary.opacity(0.3), radius: 6, x: 0, y: 3)
                            
                            Image(systemName: isPaused ? "play.fill" : "pause.fill")
                                .font(.title2)
                                .foregroundColor(.white)
                        }
                    }
                    .buttonStyle(GlassButtonStyle(style: .button))
                }
                
                // Mute button
                Button(action: {
                    toggleMute()
                }) {
                    ZStack {
                        Circle()
                            .fill(isMuted ? DesignColors.warning : DesignColors.secondary)
                            .frame(width: 50, height: 50)
                            .shadow(color: (isMuted ? DesignColors.warning : DesignColors.secondary).opacity(0.3), radius: 4, x: 0, y: 2)
                        
                        Image(systemName: isMuted ? "mic.slash.fill" : "mic.fill")
                            .font(.title3)
                            .foregroundColor(.white)
                    }
                }
                .buttonStyle(GlassButtonStyle(style: .button))
            }
            
            // Recording duration
            if isRecording {
                Text(formatDuration(recordingDuration))
                    .font(.title3)
                    .fontWeight(.medium)
                    .foregroundColor(DesignColors.textOnGlass)
                    .padding(.top, 8)
            }
            
            // Gain control
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Gain")
                        .font(.subheadline)
                        .foregroundColor(DesignColors.textOnGlass)
                    
                    Spacer()
                    
                    Text("\(Int(gain * 100))%")
                        .font(.caption)
                        .foregroundColor(DesignColors.textOnGlass.opacity(0.8))
                }
                
                Slider(value: $gain, in: 0...2, step: 0.1) { _ in
                    updateGain()
                }
                .accentColor(DesignColors.accent)
            }
        }
        .padding(.bottom, 20)
    }
    
    private var configurationView: some View {
        VStack(spacing: 16) {
            // Microphone selection
            Button(action: {
                showingMicrophoneSelection = true
            }) {
                HStack {
                    Image(systemName: "mic.fill")
                        .foregroundColor(DesignColors.textOnGlass)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Microphone")
                            .font(.subheadline)
                            .foregroundColor(DesignColors.textOnGlass)
                        
                        Text(selectedMicrophone.name)
                            .font(.caption)
                            .foregroundColor(DesignColors.textOnGlass.opacity(0.8))
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.down")
                        .foregroundColor(DesignColors.textOnGlass.opacity(0.6))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .buttonStyle(GlassButtonStyle(style: .card))
            
            // Preset selection
            Button(action: {
                showingPresetSelection = true
            }) {
                HStack {
                    Image(systemName: "slider.horizontal.3")
                        .foregroundColor(DesignColors.textOnGlass)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Preset")
                            .font(.subheadline)
                            .foregroundColor(DesignColors.textOnGlass)
                        
                        Text(selectedPreset?.name ?? "Custom")
                            .font(.caption)
                            .foregroundColor(DesignColors.textOnGlass.opacity(0.8))
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.down")
                        .foregroundColor(DesignColors.textOnGlass.opacity(0.6))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .buttonStyle(GlassButtonStyle(style: .card))
            
            // Format selection
            Button(action: {
                showingFormatSelection = true
            }) {
                HStack {
                    Image(systemName: "waveform")
                        .foregroundColor(DesignColors.textOnGlass)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Format")
                            .font(.subheadline)
                            .foregroundColor(DesignColors.textOnGlass)
                        
                        Text(currentConfiguration.format.displayName)
                            .font(.caption)
                            .foregroundColor(DesignColors.textOnGlass.opacity(0.8))
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.down")
                        .foregroundColor(DesignColors.textOnGlass.opacity(0.6))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .buttonStyle(GlassButtonStyle(style: .card))
        }
        .padding(.bottom, 16)
    }
    
    private var advancedSettingsView: some View {
        VStack(spacing: 16) {
            // Noise reduction
            Toggle("Noise Reduction", isOn: Binding(
                get: { currentConfiguration.enableNoiseReduction },
                set: { enabled in
                    updateConfiguration(enableNoiseReduction: enabled)
                }
            ))
            .toggleStyle(GlassToggleStyle())
            
            // Spatial audio
            Toggle("Spatial Audio", isOn: Binding(
                get: { currentConfiguration.enableSpatialAudio },
                set: { enabled in
                    updateConfiguration(enableSpatialAudio: enabled)
                }
            ))
            .toggleStyle(GlassToggleStyle())
            
            // Echo cancellation
            Toggle("Echo Cancellation", isOn: Binding(
                get: { currentConfiguration.enableEchoCancellation },
                set: { enabled in
                    updateConfiguration(enableEchoCancellation: enabled)
                }
            ))
            .toggleStyle(GlassToggleStyle())
            
            // Automatic gain control
            Toggle("Automatic Gain Control", isOn: Binding(
                get: { currentConfiguration.enableAutomaticGainControl },
                set: { enabled in
                    updateConfiguration(enableAutomaticGainControl: enabled)
                }
            ))
            .toggleStyle(GlassToggleStyle())
            
            // Low latency mode
            Toggle("Low Latency Mode", isOn: Binding(
                get: { currentConfiguration.enableLowLatency },
                set: { enabled in
                    updateConfiguration(enableLowLatency: enabled)
                }
            ))
            .toggleStyle(GlassToggleStyle())
        }
        .padding(.bottom, 16)
    }
    
    private var microphoneSelectionView: some View {
        NavigationView {
            VStack {
                List(availableMicrophones, id: \.deviceID) { microphone in
                    Button(action: {
                        selectedMicrophone = microphone
                        updateMicrophone(microphone)
                        showingMicrophoneSelection = false
                    }) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(microphone.name)
                                    .font(.headline)
                                    .foregroundColor(DesignColors.textPrimary)
                                
                                Text(microphone.position.displayName)
                                    .font(.caption)
                                    .foregroundColor(DesignColors.textSecondary)
                            }
                            
                            Spacer()
                            
                            if microphone.deviceID == selectedMicrophone.deviceID {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(DesignColors.accent)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .navigationTitle("Select Microphone")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        showingMicrophoneSelection = false
                    }
                }
            }
        }
    }
    
    private var presetSelectionView: some View {
        NavigationView {
            VStack {
                List(AudioPreset.builtInPresets, id: \.id) { preset in
                    Button(action: {
                        selectedPreset = preset
                        applyPreset(preset)
                        showingPresetSelection = false
                    }) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(preset.name)
                                .font(.headline)
                                .foregroundColor(DesignColors.textPrimary)
                            
                            Text(preset.description)
                                .font(.caption)
                                .foregroundColor(DesignColors.textSecondary)
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .navigationTitle("Select Preset")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        showingPresetSelection = false
                    }
                }
            }
        }
    }
    
    private var formatSelectionView: some View {
        NavigationView {
            VStack {
                List(AudioFormat.allCases, id: \.rawValue) { format in
                    Button(action: {
                        updateConfiguration(format: format)
                        showingFormatSelection = false
                    }) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(format.displayName)
                                .font(.headline)
                                .foregroundColor(DesignColors.textPrimary)
                            
                            Text(format.description)
                                .font(.caption)
                                .foregroundColor(DesignColors.textSecondary)
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .navigationTitle("Select Format")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        showingFormatSelection = false
                    }
                }
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var statusText: String {
        if isRecording {
            return isPaused ? "Paused" : "Recording"
        } else {
            return "Ready"
        }
    }
    
    // MARK: - Methods
    
    private func setupAudioControls() {
        // Listen for audio level events
        Task {
            for await event in audioManager.audioLevelEvents {
                await MainActor.run {
                    audioLevels = event.levels
                }
            }
        }
        
        // Listen for audio state events
        Task {
            for await event in audioManager.audioStateEvents {
                await MainActor.run {
                    updateAudioState(event.newState)
                }
            }
        }
        
        // Get initial configuration
        Task {
            currentConfiguration = await audioManager.currentConfiguration
            availableMicrophones = await audioManager.getAvailableMicrophones()
            selectedMicrophone = await audioManager.currentMicrophoneConfiguration
        }
    }
    
    private func cleanupAudioControls() {
        recordingTimer?.invalidate()
        recordingTimer = nil
    }
    
    private func startRecording() {
        Task {
            do {
                _ = try await audioManager.startRecording()
                await MainActor.run {
                    isRecording = true
                    isPaused = false
                    startRecordingTimer()
                }
            } catch {
                print("Failed to start recording: \(error)")
            }
        }
    }
    
    private func stopRecording() {
        Task {
            do {
                _ = try await audioManager.stopRecording()
                await MainActor.run {
                    isRecording = false
                    isPaused = false
                    stopRecordingTimer()
                }
            } catch {
                print("Failed to stop recording: \(error)")
            }
        }
    }
    
    private func pauseRecording() {
        Task {
            do {
                try await audioManager.pauseRecording()
                await MainActor.run {
                    isPaused = true
                }
            } catch {
                print("Failed to pause recording: \(error)")
            }
        }
    }
    
    private func resumeRecording() {
        Task {
            do {
                try await audioManager.resumeRecording()
                await MainActor.run {
                    isPaused = false
                }
            } catch {
                print("Failed to resume recording: \(error)")
            }
        }
    }
    
    private func toggleMute() {
        Task {
            do {
                let newMutedState = !isMuted
                try await audioManager.muteRecording(newMutedState)
                await MainActor.run {
                    isMuted = newMutedState
                }
            } catch {
                print("Failed to toggle mute: \(error)")
            }
        }
    }
    
    private func updateGain() {
        Task {
            do {
                try await audioManager.setGain(gain)
            } catch {
                print("Failed to update gain: \(error)")
            }
        }
    }
    
    private func updateMicrophone(_ microphone: MicrophoneConfiguration) {
        Task {
            do {
                try await audioManager.setMicrophone(microphone)
            } catch {
                print("Failed to update microphone: \(error)")
            }
        }
    }
    
    private func applyPreset(_ preset: AudioPreset) {
        Task {
            do {
                try await audioManager.applyPreset(preset)
                await MainActor.run {
                    currentConfiguration = preset.configuration
                }
            } catch {
                print("Failed to apply preset: \(error)")
            }
        }
    }
    
    private func updateConfiguration(
        format: AudioFormat? = nil,
        enableNoiseReduction: Bool? = nil,
        enableSpatialAudio: Bool? = nil,
        enableEchoCancellation: Bool? = nil,
        enableAutomaticGainControl: Bool? = nil,
        enableLowLatency: Bool? = nil
    ) {
        var newConfiguration = currentConfiguration
        
        if let format = format {
            newConfiguration = AudioConfiguration(
                sampleRate: newConfiguration.sampleRate,
                channels: newConfiguration.channels,
                bitDepth: newConfiguration.bitDepth,
                format: format,
                quality: newConfiguration.quality,
                enableNoiseReduction: newConfiguration.enableNoiseReduction,
                enableSpatialAudio: newConfiguration.enableSpatialAudio,
                enableEchoCancellation: newConfiguration.enableEchoCancellation,
                enableAutomaticGainControl: newConfiguration.enableAutomaticGainControl,
                bufferSize: newConfiguration.bufferSize,
                enableLowLatency: newConfiguration.enableLowLatency
            )
        }
        
        if let enableNoiseReduction = enableNoiseReduction {
            newConfiguration = AudioConfiguration(
                sampleRate: newConfiguration.sampleRate,
                channels: newConfiguration.channels,
                bitDepth: newConfiguration.bitDepth,
                format: newConfiguration.format,
                quality: newConfiguration.quality,
                enableNoiseReduction: enableNoiseReduction,
                enableSpatialAudio: newConfiguration.enableSpatialAudio,
                enableEchoCancellation: newConfiguration.enableEchoCancellation,
                enableAutomaticGainControl: newConfiguration.enableAutomaticGainControl,
                bufferSize: newConfiguration.bufferSize,
                enableLowLatency: newConfiguration.enableLowLatency
            )
        }
        
        if let enableSpatialAudio = enableSpatialAudio {
            newConfiguration = AudioConfiguration(
                sampleRate: newConfiguration.sampleRate,
                channels: newConfiguration.channels,
                bitDepth: newConfiguration.bitDepth,
                format: newConfiguration.format,
                quality: newConfiguration.quality,
                enableNoiseReduction: newConfiguration.enableNoiseReduction,
                enableSpatialAudio: enableSpatialAudio,
                enableEchoCancellation: newConfiguration.enableEchoCancellation,
                enableAutomaticGainControl: newConfiguration.enableAutomaticGainControl,
                bufferSize: newConfiguration.bufferSize,
                enableLowLatency: newConfiguration.enableLowLatency
            )
        }
        
        if let enableEchoCancellation = enableEchoCancellation {
            newConfiguration = AudioConfiguration(
                sampleRate: newConfiguration.sampleRate,
                channels: newConfiguration.channels,
                bitDepth: newConfiguration.bitDepth,
                format: newConfiguration.format,
                quality: newConfiguration.quality,
                enableNoiseReduction: newConfiguration.enableNoiseReduction,
                enableSpatialAudio: newConfiguration.enableSpatialAudio,
                enableEchoCancellation: enableEchoCancellation,
                enableAutomaticGainControl: newConfiguration.enableAutomaticGainControl,
                bufferSize: newConfiguration.bufferSize,
                enableLowLatency: newConfiguration.enableLowLatency
            )
        }
        
        if let enableAutomaticGainControl = enableAutomaticGainControl {
            newConfiguration = AudioConfiguration(
                sampleRate: newConfiguration.sampleRate,
                channels: newConfiguration.channels,
                bitDepth: newConfiguration.bitDepth,
                format: newConfiguration.format,
                quality: newConfiguration.quality,
                enableNoiseReduction: newConfiguration.enableNoiseReduction,
                enableSpatialAudio: newConfiguration.enableSpatialAudio,
                enableEchoCancellation: newConfiguration.enableEchoCancellation,
                enableAutomaticGainControl: enableAutomaticGainControl,
                bufferSize: newConfiguration.bufferSize,
                enableLowLatency: newConfiguration.enableLowLatency
            )
        }
        
        if let enableLowLatency = enableLowLatency {
            newConfiguration = AudioConfiguration(
                sampleRate: newConfiguration.sampleRate,
                channels: newConfiguration.channels,
                bitDepth: newConfiguration.bitDepth,
                format: newConfiguration.format,
                quality: newConfiguration.quality,
                enableNoiseReduction: newConfiguration.enableNoiseReduction,
                enableSpatialAudio: newConfiguration.enableSpatialAudio,
                enableEchoCancellation: newConfiguration.enableEchoCancellation,
                enableAutomaticGainControl: newConfiguration.enableAutomaticGainControl,
                bufferSize: newConfiguration.bufferSize,
                enableLowLatency: enableLowLatency
            )
        }
        
        Task {
            do {
                try await audioManager.updateConfiguration(newConfiguration)
                await MainActor.run {
                    currentConfiguration = newConfiguration
                }
            } catch {
                print("Failed to update configuration: \(error)")
            }
        }
    }
    
    private func updateAudioState(_ state: AudioState) {
        switch state {
        case .recording:
            isRecording = true
            isPaused = false
        case .paused:
            isPaused = true
        case .configured, .inactive:
            isRecording = false
            isPaused = false
        default:
            break
        }
    }
    
    private func startRecordingTimer() {
        recordingDuration = 0.0
        
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            recordingDuration += 0.1
        }
    }
    
    private func stopRecordingTimer() {
        recordingTimer?.invalidate()
        recordingTimer = nil
        recordingDuration = 0.0
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
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

// MARK: - Level Meter View

struct LevelMeterView: View {
    let level: Float
    let peakLevel: Float
    let isClipping: Bool
    let showStereo: Bool
    
    init(level: Float, peakLevel: Float, isClipping: Bool, showStereo: Bool = true) {
        self.level = level
        self.peakLevel = peakLevel
        self.isClipping = isClipping
        self.showStereo = showStereo
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background
                RoundedRectangle(cornerRadius: 4)
                    .fill(DesignColors.background.opacity(0.3))
                    .frame(height: 8)
                
                // Level bar
                RoundedRectangle(cornerRadius: 4)
                    .fill(levelColor)
                    .frame(width: geometry.size.width * CGFloat(normalizedLevel), height: 8)
                    .animation(.easeInOut(duration: 0.1), value: level)
                
                // Peak indicator
                RoundedRectangle(cornerRadius: 2)
                    .fill(peakColor)
                    .frame(width: 2, height: 8)
                    .offset(x: geometry.size.width * CGFloat(normalizedPeakLevel) - 1)
                    .animation(.easeInOut(duration: 0.05), value: peakLevel)
            }
        }
        .frame(height: 8)
    }
    
    private var normalizedLevel: Float {
        return max(0.0, min(1.0, (level + 60.0) / 60.0))
    }
    
    private var normalizedPeakLevel: Float {
        return max(0.0, min(1.0, (peakLevel + 60.0) / 60.0))
    }
    
    private var levelColor: Color {
        if isClipping {
            return DesignColors.error
        } else if normalizedLevel > 0.8 {
            return DesignColors.warning
        } else if normalizedLevel > 0.5 {
            return DesignColors.accent
        } else {
            return DesignColors.success
        }
    }
    
    private var peakColor: Color {
        if isClipping {
            return DesignColors.error
        } else {
            return DesignColors.textOnGlass
        }
    }
}

// MARK: - Glass Button Style

struct GlassButtonStyle: ButtonStyle {
    let style: LiquidGlassStyle
    
    func makeBody(configuration: Configuration) -> some View {
        LiquidGlassView(
            style: style,
            intensity: 0.6,
            animationType: .shimmer
        ) {
            configuration.label
        }
        .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
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

// MARK: - Design Colors

struct DesignColors {
    static let accent = Color.blue
    static let secondary = Color.gray
    static let success = Color.green
    static let warning = Color.orange
    static let error = Color.red
    static let background = Color.black.opacity(0.1)
    static let textPrimary = Color.primary
    static let textSecondary = Color.secondary
    static let textOnGlass = Color.white
}

// MARK: - Preview

#Preview {
    AudioControlsView(
        audioManager: AudioManager(),
        style: .default,
        intensity: 0.7,
        animationType: .shimmer
    )
}