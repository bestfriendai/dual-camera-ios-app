//
//  AudioLevelMonitorView.swift
//  DualApp
//
//  Created by DualApp Team on 10/3/25.
//

import SwiftUI
import AVFoundation

// MARK: - Audio Level Monitor View

struct AudioLevelMonitorView: View {
    // MARK: - State Properties
    
    @StateObject private var audioManager: AudioManager
    @State private var audioLevels: AudioLevels = AudioLevels()
    @State private var isMonitoring = false
    @State private var monitorMode: AudioMonitorMode = .stereo
    @State private var showPeaks = true
    @State private var showHistory = false
    @State private var historyData: [AudioLevels] = []
    @State private var maxHistoryPoints = 100
    
    // MARK: - UI Properties
    
    private let style: LiquidGlassStyle
    private let intensity: Double
    private let animationType: LiquidGlassAnimationType
    
    // MARK: - Initialization
    
    init(
        audioManager: AudioManager,
        style: LiquidGlassStyle = .card,
        intensity: Double = 0.6,
        animationType: LiquidGlassAnimationType = .pulse
    ) {
        self._audioManager = StateObject(wrappedValue: audioManager)
        self.style = style
        self.intensity = intensity
        self.animationType = animationType
    }
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with controls
            headerView
            
            // Main level display
            mainLevelView
            
            // Channel meters
            channelMetersView
            
            // History view
            if showHistory {
                historyView
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
            startMonitoring()
        }
        .onDisappear {
            stopMonitoring()
        }
    }
    
    // MARK: - View Components
    
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Audio Levels")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(DesignColors.textOnGlass)
                
                Text(isMonitoring ? "Monitoring" : "Not Monitoring")
                    .font(.caption)
                    .foregroundColor(DesignColors.textOnGlass.opacity(0.8))
            }
            
            Spacer()
            
            // Monitor mode selector
            Picker("Mode", selection: $monitorMode) {
                Text("Stereo").tag(AudioMonitorMode.stereo)
                Text("Mono").tag(AudioMonitorMode.mono)
                Text("Surround").tag(AudioMonitorMode.surround)
            }
            .pickerStyle(SegmentedPickerStyle())
            .frame(width: 180)
            
            // Toggle buttons
            HStack(spacing: 8) {
                Button(action: {
                    showPeaks.toggle()
                }) {
                    Image(systemName: showPeaks ? "waveform.path.ecg" : "waveform.path")
                        .foregroundColor(showPeaks ? DesignColors.accent : DesignColors.textOnGlass.opacity(0.6))
                }
                .buttonStyle(GlassButtonStyle(style: .minimal))
                
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showHistory.toggle()
                    }
                }) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .foregroundColor(showHistory ? DesignColors.accent : DesignColors.textOnGlass.opacity(0.6))
                }
                .buttonStyle(GlassButtonStyle(style: .minimal))
            }
        }
        .padding(.bottom, 16)
    }
    
    private var mainLevelView: some View {
        VStack(spacing: 12) {
            // Combined level meter
            ZStack {
                // Background circle
                Circle()
                    .fill(DesignColors.background.opacity(0.3))
                    .frame(width: 200, height: 200)
                
                // Level arc
                Circle()
                    .trim(from: 0, to: CGFloat(audioLevels.normalizedLevel))
                    .stroke(levelColor, lineWidth: 12)
                    .frame(width: 200, height: 200)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.1), value: audioLevels.normalizedLevel)
                
                // Peak indicator
                if showPeaks {
                    Circle()
                        .trim(from: 0, to: CGFloat(audioLevels.normalizedPeakLevel))
                        .stroke(DesignColors.textOnGlass, lineWidth: 2)
                        .frame(width: 200, height: 200)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 0.05), value: audioLevels.normalizedPeakLevel)
                }
                
                // Center info
                VStack(spacing: 4) {
                    Text("\(Int(audioLevels.averagePower)) dB")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(DesignColors.textOnGlass)
                    
                    Text("Peak: \(Int(audioLevels.peakPower)) dB")
                        .font(.caption)
                        .foregroundColor(DesignColors.textOnGlass.opacity(0.8))
                    
                    if audioLevels.isClipping {
                        Text("CLIPPING")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(DesignColors.error)
                    }
                }
            }
            .frame(height: 220)
        }
        .padding(.bottom, 20)
    }
    
    private var channelMetersView: some View {
        VStack(spacing: 16) {
            switch monitorMode {
            case .stereo:
                stereoChannelMeters
            case .mono:
                monoChannelMeter
            case .surround:
                surroundChannelMeters
            }
        }
        .padding(.bottom, 16)
    }
    
    private var stereoChannelMeters: some View {
        HStack(spacing: 20) {
            // Left channel
            VStack(alignment: .leading, spacing: 8) {
                Text("Left")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(DesignColors.textOnGlass)
                
                VerticalLevelMeterView(
                    level: audioLevels.leftChannelLevel,
                    peakLevel: audioLevels.peakLevel,
                    isClipping: audioLevels.isClipping,
                    showPeaks: showPeaks
                )
                .frame(width: 40, height: 120)
                
                Text("\(Int(audioLevels.leftChannelLevel * 100))%")
                    .font(.caption)
                    .foregroundColor(DesignColors.textOnGlass.opacity(0.8))
            }
            
            // Right channel
            VStack(alignment: .leading, spacing: 8) {
                Text("Right")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(DesignColors.textOnGlass)
                
                VerticalLevelMeterView(
                    level: audioLevels.rightChannelLevel,
                    peakLevel: audioLevels.peakLevel,
                    isClipping: audioLevels.isClipping,
                    showPeaks: showPeaks
                )
                .frame(width: 40, height: 120)
                
                Text("\(Int(audioLevels.rightChannelLevel * 100))%")
                    .font(.caption)
                    .foregroundColor(DesignColors.textOnGlass.opacity(0.8))
            }
        }
    }
    
    private var monoChannelMeter: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Mono")
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundColor(DesignColors.textOnGlass)
            
            VerticalLevelMeterView(
                level: audioLevels.rmsLevel,
                peakLevel: audioLevels.peakLevel,
                isClipping: audioLevels.isClipping,
                showPeaks: showPeaks
            )
            .frame(width: 40, height: 120)
            
            Text("\(Int(audioLevels.rmsLevel * 100))%")
                .font(.caption)
                .foregroundColor(DesignColors.textOnGlass.opacity(0.8))
        }
    }
    
    private var surroundChannelMeters: some View {
        VStack(spacing: 16) {
            // Front channels
            HStack(spacing: 20) {
                channelMeterView(name: "Front L", level: audioLevels.leftChannelLevel)
                channelMeterView(name: "Front R", level: audioLevels.rightChannelLevel)
            }
            
            // Center channel
            channelMeterView(name: "Center", level: audioLevels.rmsLevel)
            
            // Rear channels
            HStack(spacing: 20) {
                channelMeterView(name: "Rear L", level: audioLevels.leftChannelLevel * 0.8)
                channelMeterView(name: "Rear R", level: audioLevels.rightChannelLevel * 0.8)
            }
            
            // LFE channel
            channelMeterView(name: "LFE", level: audioLevels.rmsLevel * 1.2)
        }
    }
    
    private func channelMeterView(name: String, level: Float) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(name)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(DesignColors.textOnGlass)
            
            VerticalLevelMeterView(
                level: level,
                peakLevel: audioLevels.peakLevel,
                isClipping: audioLevels.isClipping,
                showPeaks: showPeaks
            )
            .frame(width: 30, height: 80)
            
            Text("\(Int(level * 100))%")
                .font(.caption2)
                .foregroundColor(DesignColors.textOnGlass.opacity(0.8))
        }
    }
    
    private var historyView: some View {
        VStack(spacing: 12) {
            Text("Level History")
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundColor(DesignColors.textOnGlass)
            
            // History chart
            GeometryReader { geometry in
                ZStack {
                    // Grid lines
                    Path { path in
                        let step = geometry.size.height / 4
                        
                        for i in 0...4 {
                            let y = CGFloat(i) * step
                            path.move(to: CGPoint(x: 0, y: y))
                            path.addLine(to: CGPoint(x: geometry.size.width, y: y))
                        }
                    }
                    .stroke(DesignColors.textOnGlass.opacity(0.2), lineWidth: 1)
                    
                    // History line
                    Path { path in
                        guard !historyData.isEmpty else { return }
                        
                        let step = geometry.size.width / CGFloat(maxHistoryPoints - 1)
                        
                        for (index, levels) in historyData.enumerated() {
                            let x = CGFloat(index) * step
                            let y = geometry.size.height * (1.0 - CGFloat(levels.normalizedLevel))
                            
                            if index == 0 {
                                path.move(to: CGPoint(x: x, y: y))
                            } else {
                                path.addLine(to: CGPoint(x: x, y: y))
                            }
                        }
                    }
                    .stroke(DesignColors.accent, lineWidth: 2)
                    
                    // Peak line
                    if showPeaks {
                        Path { path in
                            guard !historyData.isEmpty else { return }
                            
                            let step = geometry.size.width / CGFloat(maxHistoryPoints - 1)
                            
                            for (index, levels) in historyData.enumerated() {
                                let x = CGFloat(index) * step
                                let y = geometry.size.height * (1.0 - CGFloat(levels.normalizedPeakLevel))
                                
                                if index == 0 {
                                    path.move(to: CGPoint(x: x, y: y))
                                } else {
                                    path.addLine(to: CGPoint(x: x, y: y))
                                }
                            }
                        }
                        .stroke(DesignColors.warning, lineWidth: 1)
                    }
                }
            }
            .frame(height: 120)
            .background(DesignColors.background.opacity(0.2))
            .cornerRadius(8)
        }
        .padding(.bottom, 16)
    }
    
    // MARK: - Computed Properties
    
    private var levelColor: Color {
        if audioLevels.isClipping {
            return DesignColors.error
        } else if audioLevels.normalizedLevel > 0.8 {
            return DesignColors.warning
        } else if audioLevels.normalizedLevel > 0.5 {
            return DesignColors.accent
        } else {
            return DesignColors.success
        }
    }
    
    // MARK: - Methods
    
    private func startMonitoring() {
        isMonitoring = true
        
        // Listen for audio level events
        Task {
            for await event in audioManager.audioLevelEvents {
                await MainActor.run {
                    audioLevels = event.levels
                    
                    // Update history
                    if showHistory {
                        historyData.append(audioLevels)
                        
                        // Keep only the last maxHistoryPoints
                        if historyData.count > maxHistoryPoints {
                            historyData.removeFirst()
                        }
                    }
                }
            }
        }
    }
    
    private func stopMonitoring() {
        isMonitoring = false
    }
}

// MARK: - Vertical Level Meter View

struct VerticalLevelMeterView: View {
    let level: Float
    let peakLevel: Float
    let isClipping: Bool
    let showPeaks: Bool
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                // Background
                RoundedRectangle(cornerRadius: 4)
                    .fill(DesignColors.background.opacity(0.3))
                    .frame(width: geometry.size.width, height: geometry.size.height)
                
                // Level bar
                RoundedRectangle(cornerRadius: 4)
                    .fill(levelColor)
                    .frame(width: geometry.size.width, height: geometry.size.height * CGFloat(normalizedLevel))
                    .animation(.easeInOut(duration: 0.1), value: level)
                
                // Peak indicator
                if showPeaks {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(peakColor)
                        .frame(width: geometry.size.width, height: 4)
                        .offset(y: -geometry.size.height * CGFloat(normalizedPeakLevel))
                        .animation(.easeInOut(duration: 0.05), value: peakLevel)
                }
            }
        }
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

// MARK: - Audio Monitor Mode

enum AudioMonitorMode: String, CaseIterable {
    case stereo = "stereo"
    case mono = "mono"
    case surround = "surround"
    
    var displayName: String {
        switch self {
        case .stereo:
            return "Stereo"
        case .mono:
            return "Mono"
        case .surround:
            return "Surround"
        }
    }
}

// MARK: - Audio Waveform View

struct AudioWaveformView: View {
    let waveform: AudioWaveform
    let style: LiquidGlassStyle
    let intensity: Double
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                RoundedRectangle(cornerRadius: style.cornerRadius)
                    .fill(DesignColors.background.opacity(0.3))
                
                // Waveform
                Path { path in
                    guard !waveform.samples.isEmpty else { return }
                    
                    let width = geometry.size.width
                    let height = geometry.size.height
                    let step = width / CGFloat(waveform.samples.count - 1)
                    
                    for (index, sample) in waveform.samples.enumerated() {
                        let x = CGFloat(index) * step
                        let y = height * (1.0 - CGFloat(sample))
                        
                        if index == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                }
                .stroke(DesignColors.accent, lineWidth: 2)
                
                // Center line
                Path { path in
                    path.move(to: CGPoint(x: 0, y: geometry.size.height / 2))
                    path.addLine(to: CGPoint(x: geometry.size.width, y: geometry.size.height / 2))
                }
                .stroke(DesignColors.textOnGlass.opacity(0.3), lineWidth: 1)
            }
        }
        .frame(height: 100)
        .padding(style.padding)
        .background(
            LiquidGlassView(
                style: style,
                intensity: intensity,
                animationType: .none
            )
        )
    }
}

// MARK: - Audio Spectrum View

struct AudioSpectrumView: View {
    let spectrumData: [Float]
    let style: LiquidGlassStyle
    let intensity: Double
    
    var body: some View {
        GeometryReader { geometry in
            HStack(alignment: .bottom, spacing: 2) {
                ForEach(Array(spectrumData.enumerated()), id: \.offset) { index, magnitude in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(spectrumColor(for: magnitude))
                        .frame(
                            width: geometry.size.width / CGFloat(spectrumData.count) - 2,
                            height: geometry.size.height * CGFloat(magnitude)
                        )
                        .animation(.easeInOut(duration: 0.1), value: magnitude)
                }
            }
        }
        .frame(height: 100)
        .padding(style.padding)
        .background(
            LiquidGlassView(
                style: style,
                intensity: intensity,
                animationType: .pulse
            )
        )
    }
    
    private func spectrumColor(for magnitude: Float) -> Color {
        if magnitude > 0.8 {
            return DesignColors.error
        } else if magnitude > 0.6 {
            return DesignColors.warning
        } else if magnitude > 0.4 {
            return DesignColors.accent
        } else {
            return DesignColors.success
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        AudioLevelMonitorView(
            audioManager: MockAudioManager(),
            style: .card,
            intensity: 0.7,
            animationType: .pulse
        )
        
        AudioWaveformView(
            waveform: AudioWaveform(
                samples: Array(repeating: 0.5, count: 100),
                duration: 10.0,
                sampleRate: 44100.0,
                channels: 2,
                generatedAt: Date()
            ),
            style: .card,
            intensity: 0.6
        )
        
        AudioSpectrumView(
            spectrumData: Array(repeating: 0.5, count: 32),
            style: .card,
            intensity: 0.6
        )
    }
    .padding()
    .background(DesignColors.background)
}

// MARK: - Mock AudioManager for Preview

class MockAudioManager: ObservableObject {
    @Published var audioLevels: AudioLevels = AudioLevels()
    @Published var isRecording: Bool = false
    @Published var isMonitoring: Bool = false

    init() {
        // Simulate audio levels for preview
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            self.audioLevels = AudioLevels(
                leftChannel: Float.random(in: 0...1),
                rightChannel: Float.random(in: 0...1),
                peak: Float.random(in: 0...1),
                average: Float.random(in: 0...0.8)
            )
        }
    }
}