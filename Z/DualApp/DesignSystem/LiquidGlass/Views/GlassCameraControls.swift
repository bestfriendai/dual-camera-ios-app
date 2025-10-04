//
//  GlassCameraControls.swift
//  DualApp
//
//  Created by DualApp Team on 10/3/25.
//

import SwiftUI

// MARK: - Glass Camera Controls

struct GlassCameraControls: View {
    // MARK: - Properties
    
    let isRecording: Bool
    let isVideoMode: Bool
    let flashMode: FlashMode
    let cameraPosition: CameraPosition
    let intensity: Double
    let palette: LiquidGlassPalette?
    let onRecord: () -> Void
    let onStop: () -> Void
    let onCapture: () -> Void
    let onToggleFlash: () -> Void
    let onSwitchCamera: () -> Void
    
    // MARK: - State
    
    @State private var recordingPulseScale: CGFloat = 1.0
    @State private var recordingPulseOpacity: Double = 0.3
    @State private var isHovered = false
    @State private var glowIntensity: Double = 0.2
    @State private var wavePhase: Double = 0
    @State private var shimmerOffset: CGSize = .zero
    @State private var isAnimating = false
    
    // MARK: - Body
    
    var body: some View {
        HStack(spacing: 30) {
            // Left controls
            HStack(spacing: 20) {
                // Flash button
                GlassCameraControlButton(
                    icon: flashIcon,
                    isActive: flashMode != .off,
                    intensity: intensity,
                    palette: palette,
                    action: onToggleFlash
                )
                
                // Camera switch button
                GlassCameraControlButton(
                    icon: "camera.rotate",
                    isActive: false,
                    intensity: intensity,
                    palette: palette,
                    action: onSwitchCamera
                )
            }
            
            Spacer()
            
            // Center recording button
            GlassRecordingButton(
                isRecording: isRecording,
                isVideoMode: isVideoMode,
                intensity: intensity,
                palette: palette,
                onRecord: onRecord,
                onStop: onStop,
                onCapture: onCapture
            )
            
            Spacer()
            
            // Right controls
            HStack(spacing: 20) {
                // Gallery button
                GlassCameraControlButton(
                    icon: "photo.on.rectangle",
                    isActive: false,
                    intensity: intensity,
                    palette: palette,
                    action: {
                        // Handle gallery
                    }
                )
                
                // Settings button
                GlassCameraControlButton(
                    icon: "gearshape.fill",
                    isActive: false,
                    intensity: intensity,
                    palette: palette,
                    action: {
                        // Handle settings
                    }
                )
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
        .background(
            GlassToolbar(
                variant: .elevated,
                intensity: intensity,
                palette: palette,
                animationType: .wave,
                position: .bottom,
                floatingStyle: .dramatic
            ) {
                EmptyView()
            }
        )
        .onAppear {
            startAnimations()
        }
        .onDisappear {
            stopAnimations()
        }
    }
    
    // MARK: - Helper Properties
    
    private var flashIcon: String {
        switch flashMode {
        case .off:
            return "bolt.slash.fill"
        case .on:
            return "bolt.fill"
        case .auto:
            return "bolt.badge.automatic.fill"
        }
    }
    
    // MARK: - Animation Methods
    
    private func startAnimations() {
        isAnimating = true
        
        if isRecording {
            startRecordingAnimation()
        }
        
        startGlowAnimation()
        startWaveAnimation()
        startShimmerAnimation()
    }
    
    private func stopAnimations() {
        isAnimating = false
    }
    
    private func startRecordingAnimation() {
        withAnimation(
            .easeInOut(duration: 1.0)
            .repeatForever(autoreverses: true)
        ) {
            recordingPulseScale = 1.2
            recordingPulseOpacity = 0.6
        }
    }
    
    private func startGlowAnimation() {
        withAnimation(
            .easeInOut(duration: 3.0)
            .repeatForever(autoreverses: true)
        ) {
            glowIntensity = 0.4
        }
    }
    
    private func startWaveAnimation() {
        withAnimation(
            .linear(duration: 4.0)
            .repeatForever(autoreverses: false)
        ) {
            wavePhase = 2 * .pi
        }
    }
    
    private func startShimmerAnimation() {
        withAnimation(
            .easeInOut(duration: 3.0)
            .repeatForever(autoreverses: true)
        ) {
            shimmerOffset = CGSize(width: 50, height: 0)
        }
    }
}

// MARK: - Glass Recording Button

struct GlassRecordingButton: View {
    // MARK: - Properties
    
    let isRecording: Bool
    let isVideoMode: Bool
    let intensity: Double
    let palette: LiquidGlassPalette?
    let onRecord: () -> Void
    let onStop: () -> Void
    let onCapture: () -> Void
    
    // MARK: - State
    
    @State private var buttonScale: CGFloat = 1.0
    @State private var pulseScale: CGFloat = 1.0
    @State private var pulseOpacity: Double = 0.3
    @State private var glowIntensity: Double = 0.2
    @State private var isPressed = false
    @State private var rippleScale: CGFloat = 0
    @State private var rippleOpacity: Double = 0
    @State private var recordingRingScale: CGFloat = 1.0
    @State private var recordingRingOpacity: Double = 0
    @State private var isAnimating = false
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            // Recording pulse effect
            if isRecording {
                recordingPulseEffect
            }
            
            // Ripple effect
            if isPressed {
                rippleEffect
            }
            
            // Main button
            mainButton
            
            // Glow effect
            glowEffect
        }
        .scaleEffect(buttonScale)
        .onAppear {
            startAnimations()
        }
        .onDisappear {
            stopAnimations()
        }
        .onChange(of: isRecording) { newValue in
            if newValue {
                startRecordingAnimation()
            } else {
                stopRecordingAnimation()
            }
        }
    }
    
    // MARK: - View Components
    
    private var mainButton: some View {
        ZStack {
            // Button background
            Circle()
                .fill(buttonBackgroundGradient)
                .overlay(
                    Circle()
                        .stroke(borderGradient, lineWidth: 2)
                )
                .shadow(
                    color: buttonShadowColor,
                    radius: 8,
                    x: 0,
                    y: 4
                )
            
            // Button content
            buttonContent
        }
        .frame(width: 80, height: 80)
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isPressed)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    handlePressBegan()
                }
                .onEnded { _ in
                    handlePressEnded()
                }
        )
        .accessibilityRecordingButton(isRecording: isRecording) {
            handleTap()
        }
    }
    
    private var buttonContent: some View {
        ZStack {
            if isVideoMode {
                // Video recording button
                if isRecording {
                    // Stop square
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white)
                        .frame(width: 28, height: 28)
                } else {
                    // Record circle
                    Circle()
                        .fill(Color.red)
                        .frame(width: 32, height: 32)
                }
            } else {
                // Photo capture button
                Circle()
                    .stroke(Color.white, lineWidth: 4)
                    .frame(width: 32, height: 32)
            }
        }
    }
    
    private var recordingPulseEffect: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .stroke(recordingPulseColor, lineWidth: 2)
                    .scaleEffect(recordingRingScale + CGFloat(index) * 0.2)
                    .opacity(recordingRingOpacity - Double(index) * 0.1)
                    .animation(
                        .easeInOut(duration: 1.5 + Double(index) * 0.3)
                        .repeatForever(autoreverses: false),
                        value: recordingRingScale
                    )
            }
        }
        .frame(width: 100, height: 100)
    }
    
    private var rippleEffect: some View {
        Circle()
            .fill(rippleColor)
            .scaleEffect(rippleScale)
            .opacity(rippleOpacity)
            .animation(.easeOut(duration: 0.6), value: rippleScale)
            .animation(.easeOut(duration: 0.6), value: rippleOpacity)
    }
    
    private var glowEffect: some View {
        Circle()
            .fill(glowGradient)
            .opacity(glowIntensity)
            .blur(radius: 20)
            .scaleEffect(1.2)
    }
    
    // MARK: - Color and Gradient Computations
    
    private var buttonBackgroundGradient: LinearGradient {
        let baseColor = palette?.primaryTint.color ?? .white
        
        if isRecording {
            return LinearGradient(
                colors: [
                    baseColor.opacity(0.15 * intensity),
                    baseColor.opacity(0.08 * intensity),
                    baseColor.opacity(0.04 * intensity)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            return LinearGradient(
                colors: [
                    baseColor.opacity(0.2 * intensity),
                    baseColor.opacity(0.1 * intensity),
                    baseColor.opacity(0.05 * intensity)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
    
    private var borderGradient: LinearGradient {
        let accentColor = palette?.accentColor ?? LiquidGlassColors.glassBorder
        
        if isRecording {
            return LinearGradient(
                colors: [
                    Color.red.opacity(0.6 * intensity),
                    Color.red.opacity(0.3 * intensity),
                    Color.red.opacity(0.6 * intensity)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            return LinearGradient(
                colors: [
                    accentColor.opacity(0.4 * intensity),
                    accentColor.opacity(0.2 * intensity),
                    accentColor.opacity(0.4 * intensity)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
    
    private var buttonShadowColor: Color {
        LiquidGlassColors.glassShadow.opacity(0.3 * intensity)
    }
    
    private var recordingPulseColor: Color {
        Color.red.opacity(0.6 * intensity)
    }
    
    private var rippleColor: Color {
        palette?.accentColor ?? .white
    }
    
    private var glowGradient: RadialGradient {
        let glowColor = isRecording ? Color.red : (palette?.accentColor ?? .blue)
        
        return RadialGradient(
            colors: [
                glowColor.opacity(0.4 * intensity),
                glowColor.opacity(0.2 * intensity),
                glowColor.opacity(0)
            ],
            center: .center,
            startRadius: 10,
            endRadius: 50
        )
    }
    
    // MARK: - Interaction Methods
    
    private func handlePressBegan() {
        isPressed = true
        HapticFeedbackManager.shared.mediumImpact()
        
        withAnimation(.easeInOut(duration: 0.1)) {
            rippleScale = 0
            rippleOpacity = 0.6
        }
        
        withAnimation(.easeOut(duration: 0.6)) {
            rippleScale = 2.0
            rippleOpacity = 0
        }
    }
    
    private func handlePressEnded() {
        isPressed = false
    }
    
    private func handleTap() {
        if isVideoMode {
            if isRecording {
                onStop()
            } else {
                onRecord()
            }
        } else {
            onCapture()
        }
    }
    
    // MARK: - Animation Methods
    
    private func startAnimations() {
        isAnimating = true
        
        if isRecording {
            startRecordingAnimation()
        }
        
        startGlowAnimation()
    }
    
    private func stopAnimations() {
        isAnimating = false
    }
    
    private func startRecordingAnimation() {
        withAnimation(
            .easeInOut(duration: 1.0)
            .repeatForever(autoreverses: true)
        ) {
            recordingRingScale = 1.5
            recordingRingOpacity = 0.6
        }
    }
    
    private func stopRecordingAnimation() {
        withAnimation(.easeInOut(duration: 0.3)) {
            recordingRingScale = 1.0
            recordingRingOpacity = 0
        }
    }
    
    private func startGlowAnimation() {
        withAnimation(
            .easeInOut(duration: 2.0)
            .repeatForever(autoreverses: true)
        ) {
            glowIntensity = isRecording ? 0.6 : 0.3
        }
    }
}

// MARK: - Glass Camera Control Button

struct GlassCameraControlButton: View {
    // MARK: - Properties
    
    let icon: String
    let isActive: Bool
    let intensity: Double
    let palette: LiquidGlassPalette?
    let action: () -> Void
    
    // MARK: - State
    
    @State private var isPressed = false
    @State private var glowIntensity: Double = 0.2
    @State private var isAnimating = false
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            // Glow effect
            if isActive {
                glowEffect
            }
            
            // Button background
            buttonBackground
            
            // Icon
            Image(systemName: icon)
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(iconColor)
        }
        .frame(width: 44, height: 44)
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isPressed)
        .onAppear {
            startAnimations()
        }
        .onDisappear {
            stopAnimations()
        }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    handlePressBegan()
                }
                .onEnded { _ in
                    handlePressEnded()
                }
        )
        .onTapGesture {
            action()
        }
        .accessibilityButton(label: accessibilityLabel, action: action)
    }
    
    // MARK: - View Components
    
    private var buttonBackground: some View {
        ZStack {
            Circle()
                .fill(backgroundGradient)
                .overlay(
                    Circle()
                        .stroke(borderGradient, lineWidth: 1)
                )
                .shadow(
                    color: buttonShadowColor,
                    radius: 4,
                    x: 0,
                    y: 2
                )
        }
    }
    
    private var glowEffect: some View {
        Circle()
            .fill(glowGradient)
            .opacity(glowIntensity)
            .blur(radius: 10)
            .scaleEffect(1.2)
    }
    
    // MARK: - Color and Gradient Computations
    
    private var backgroundGradient: LinearGradient {
        let baseColor = palette?.primaryTint.color ?? .white
        
        if isActive {
            return LinearGradient(
                colors: [
                    baseColor.opacity(0.2 * intensity),
                    baseColor.opacity(0.1 * intensity),
                    baseColor.opacity(0.05 * intensity)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            return LinearGradient(
                colors: [
                    baseColor.opacity(0.1 * intensity),
                    baseColor.opacity(0.05 * intensity),
                    baseColor.opacity(0.02 * intensity)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
    
    private var borderGradient: LinearGradient {
        let accentColor = palette?.accentColor ?? LiquidGlassColors.glassBorder
        
        if isActive {
            return LinearGradient(
                colors: [
                    accentColor.opacity(0.5 * intensity),
                    accentColor.opacity(0.3 * intensity),
                    accentColor.opacity(0.5 * intensity)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            return LinearGradient(
                colors: [
                    accentColor.opacity(0.3 * intensity),
                    accentColor.opacity(0.15 * intensity),
                    accentColor.opacity(0.3 * intensity)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
    
    private var buttonShadowColor: Color {
        LiquidGlassColors.glassShadow.opacity(0.2 * intensity)
    }
    
    private var iconColor: Color {
        if isActive {
            return palette?.accentColor ?? DesignColors.textOnGlass
        } else {
            return DesignColors.textOnGlass.opacity(0.7)
        }
    }
    
    private var glowGradient: RadialGradient {
        let glowColor = palette?.accentColor ?? .blue
        
        return RadialGradient(
            colors: [
                glowColor.opacity(0.4 * intensity),
                glowColor.opacity(0.2 * intensity),
                glowColor.opacity(0)
            ],
            center: .center,
            startRadius: 5,
            endRadius: 30
        )
    }
    
    private var accessibilityLabel: String {
        // This should be customized based on the icon
        return "Camera control"
    }
    
    // MARK: - Interaction Methods
    
    private func handlePressBegan() {
        isPressed = true
        HapticFeedbackManager.shared.lightImpact()
    }
    
    private func handlePressEnded() {
        isPressed = false
    }
    
    // MARK: - Animation Methods
    
    private func startAnimations() {
        isAnimating = true
        
        if isActive {
            startGlowAnimation()
        }
    }
    
    private func stopAnimations() {
        isAnimating = false
    }
    
    private func startGlowAnimation() {
        withAnimation(
            .easeInOut(duration: 2.0)
            .repeatForever(autoreverses: true)
        ) {
            glowIntensity = 0.4
        }
    }
}

// MARK: - Camera Enums

enum FlashMode {
    case off
    case on
    case auto
}

enum CameraPosition {
    case back
    case front
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black
        
        VStack {
            Spacer()
            
            GlassCameraControls(
                isRecording: true,
                isVideoMode: true,
                flashMode: .auto,
                cameraPosition: .back,
                intensity: 0.7,
                palette: .ocean,
                onRecord: {},
                onStop: {},
                onCapture: {},
                onToggleFlash: {},
                onSwitchCamera: {}
            )
        }
        .padding(.bottom, 50)
    }
    .ignoresSafeArea()
}