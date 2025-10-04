//
//  GlassRecordingIndicator.swift
//  DualApp
//
//  Created by DualApp Team on 10/3/25.
//

import SwiftUI

// MARK: - Glass Recording Indicator

struct GlassRecordingIndicator: View {
    // MARK: - Properties
    
    let isRecording: Bool
    let recordingTime: TimeInterval
    let intensity: Double
    let palette: LiquidGlassPalette?
    let variant: GlassRecordingIndicatorVariant
    let animationType: GlassRecordingAnimationType
    
    // MARK: - State
    
    @State private var pulseScale: CGFloat = 1.0
    @State private var pulseOpacity: Double = 0.6
    @State private var glowIntensity: Double = 0.3
    @State private var wavePhase: Double = 0
    @State private var rippleScale: CGFloat = 1.0
    @State private var rippleOpacity: Double = 0
    @State private var breathingScale: CGFloat = 1.0
    @State private var breathingOpacity: Double = 0.8
    @State private var rotationAngle: Double = 0
    @State private var isAnimating = false
    @State private var pulseRings: [PulseRing] = []
    @State private var particlePositions: [CGPoint] = []
    @State private var recordingBlink: Bool = false
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            // Background layers
            backgroundLayers
            
            // Glass surface
            glassSurface
            
            // Animation effects
            animationEffects
            
            // Pulse rings
            if isRecording {
                pulseRingsView
            }
            
            // Ripple effect
            if isRecording {
                rippleEffect
            }
            
            // Particle effects
            if isRecording && animationType == .particles {
                particleEffects
            }
            
            // Content
            indicatorContent
        }
        .frame(width: variant.width, height: variant.height)
        .onAppear {
            startAnimations()
        }
        .onDisappear {
            stopAnimations()
        }
        .onChange(of: isRecording) { recording in
            if recording {
                startRecordingAnimation()
            } else {
                stopRecordingAnimation()
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(isRecording ? "Recording" : "Not recording")
        .accessibilityValue(recordingTimeString)
    }
    
    // MARK: - View Components
    
    private var backgroundLayers: some View {
        ZStack {
            // Base blur effect
            indicatorShape
                .fill(baseBackgroundColor)
                .background(
                    indicatorShape
                        .fill(backgroundGradient)
                )
                .blur(radius: variant.blurRadius * intensity)
            
            // Depth layers
            ForEach(0..<variant.depthLayers, id: \.self) { index in
                indicatorShape
                    .fill(depthLayerColor(for: index))
                    .offset(depthLayerOffset(for: index))
                    .blur(radius: depthLayerBlur(for: index))
            }
        }
    }
    
    private var glassSurface: some View {
        indicatorShape
            .fill(surfaceGradient)
            .overlay(
                // Surface highlights
                indicatorShape
                    .fill(surfaceHighlightGradient)
                    .opacity(surfaceHighlightOpacity)
            )
            .overlay(
                // Border
                indicatorShape
                    .stroke(borderGradient, lineWidth: variant.borderWidth)
            )
            .shadow(
                color: shadowColor,
                radius: shadowRadius,
                x: shadowOffset.width,
                y: shadowOffset.height
            )
    }
    
    private var animationEffects: some View {
        ZStack {
            switch animationType {
            case .pulse:
                pulseEffect
            case .glow:
                glowEffect
            case .wave:
                waveEffect
            case .breathing:
                breathingEffect
            case .rotate:
                rotateEffect
            case .blink:
                EmptyView() // Handled separately
            case .none:
                EmptyView()
            }
        }
    }
    
    private var pulseRingsView: some View {
        ZStack {
            ForEach(pulseRings, id: \.id) { ring in
                Circle()
                    .stroke(pulseRingGradient, lineWidth: 2)
                    .scaleEffect(ring.scale)
                    .opacity(ring.opacity)
            }
        }
    }
    
    private var rippleEffect: some View {
        Circle()
            .fill(rippleGradient)
            .scaleEffect(rippleScale)
            .opacity(rippleOpacity)
            .blur(radius: 5)
    }
    
    private var particleEffects: some View {
        ZStack {
            ForEach(Array(particlePositions.enumerated()), id: \.offset) { index, position in
                Circle()
                    .fill(particleColor)
                    .frame(width: 3, height: 3)
                    .position(position)
                    .opacity(particleOpacity(for: index))
            }
        }
    }
    
    private var indicatorContent: some View {
        HStack(spacing: 8) {
            // Recording dot
            Circle()
                .fill(isRecording ? recordingDotColor : inactiveDotColor)
                .frame(width: 12, height: 12)
                .scaleEffect(recordingBlink && isRecording ? 0.8 : 1.0)
                .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: recordingBlink)
            
            // Recording time
            Text(recordingTimeString)
                .textStyle(variant.textStyle)
                .foregroundColor(textColor)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
    
    // MARK: - Shape Components
    
    private var indicatorShape: some Shape {
        RoundedRectangle(cornerRadius: variant.cornerRadius)
    }
    
    // MARK: - Color and Gradient Computations
    
    private var baseBackgroundColor: Color {
        palette?.baseColor ?? LiquidGlassColors.clear
    }
    
    private var backgroundGradient: LinearGradient {
        let colors = [
            baseBackgroundColor.opacity(0.05 * intensity),
            baseBackgroundColor.opacity(0.1 * intensity),
            baseBackgroundColor.opacity(0.15 * intensity)
        ]
        
        return LinearGradient(
            colors: colors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    private var surfaceGradient: LinearGradient {
        let baseTint = palette?.primaryTint.color ?? .white
        
        let colors = [
            baseTint.opacity(0.1 * intensity),
            baseTint.opacity(0.05 * intensity),
            baseTint.opacity(0.02 * intensity)
        ]
        
        return LinearGradient(
            colors: colors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    private var surfaceHighlightGradient: LinearGradient {
        let colors = [
            LiquidGlassColors.surfaceReflection.opacity(0.3 * intensity),
            LiquidGlassColors.surfaceReflection.opacity(0.1 * intensity),
            LiquidGlassColors.surfaceReflection.opacity(0.05 * intensity)
        ]
        
        return LinearGradient(
            colors: colors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    private var borderGradient: LinearGradient {
        let accentColor = isRecording ? Color.red : (palette?.accentColor ?? LiquidGlassColors.glassBorder)
        
        let colors = [
            accentColor.opacity(0.4 * intensity),
            accentColor.opacity(0.2 * intensity),
            accentColor.opacity(0.4 * intensity)
        ]
        
        return LinearGradient(
            colors: colors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    private var pulseRingGradient: LinearGradient {
        return LinearGradient(
            colors: [
                Color.red.opacity(0.8),
                Color.red.opacity(0.4),
                Color.red.opacity(0.1)
            ],
            startPoint: .center,
            endPoint: .edge
        )
    }
    
    private var rippleGradient: RadialGradient {
        return RadialGradient(
            colors: [
                Color.red.opacity(0.3),
                Color.red.opacity(0.1),
                Color.red.opacity(0)
            ],
            center: .center,
            startRadius: 5,
            endRadius: 30
        )
    }
    
    private var pulseGradient: RadialGradient {
        let pulseColor = isRecording ? Color.red : (palette?.accentColor ?? LiquidGlassColors.pulse)
        
        return RadialGradient(
            colors: [
                pulseColor.opacity(0.3 * intensity),
                pulseColor.opacity(0.15 * intensity),
                pulseColor.opacity(0)
            ],
            center: .center,
            startRadius: 10,
            endRadius: 50
        )
    }
    
    private var glowGradient: RadialGradient {
        let glowColor = isRecording ? Color.red : (palette?.accentColor ?? LiquidGlassColors.glow)
        
        return RadialGradient(
            colors: [
                glowColor.opacity(0.4 * intensity),
                glowColor.opacity(0.2 * intensity),
                glowColor.opacity(0)
            ],
            center: .center,
            startRadius: 10,
            endRadius: 60
        )
    }
    
    private var waveGradient: LinearGradient {
        let waveColor = isRecording ? Color.red : (palette?.baseColor ?? LiquidGlassColors.waveOverlay)
        
        return LinearGradient(
            colors: [
                waveColor.opacity(0.2 * intensity),
                waveColor.opacity(0.1 * intensity),
                waveColor.opacity(0.05 * intensity)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
    
    private var breathingGradient: RadialGradient {
        let breathingColor = isRecording ? Color.red : (palette?.baseColor ?? .white)
        
        return RadialGradient(
            colors: [
                breathingColor.opacity(0.1 * intensity),
                breathingColor.opacity(0.05 * intensity),
                breathingColor.opacity(0.02 * intensity)
            ],
            center: .center,
            startRadius: 10,
            endRadius: 40
        )
    }
    
    private var recordingDotColor: Color {
        Color.red
    }
    
    private var inactiveDotColor: Color {
        DesignColors.textOnGlass.opacity(0.5)
    }
    
    private var textColor: Color {
        DesignColors.textOnGlass
    }
    
    private var particleColor: Color {
        Color.red.opacity(0.8)
    }
    
    private var shadowColor: Color {
        LiquidGlassColors.glassShadow.opacity(0.3 * intensity)
    }
    
    // MARK: - Helper Properties
    
    private var recordingTimeString: String {
        let minutes = Int(recordingTime) / 60
        let seconds = Int(recordingTime) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    // MARK: - Animation Components
    
    private var pulseEffect: some View {
        Circle()
            .fill(pulseGradient)
            .scaleEffect(pulseScale)
            .opacity(pulseOpacity)
    }
    
    private var glowEffect: some View {
        Circle()
            .fill(glowGradient)
            .opacity(glowIntensity)
            .blur(radius: 15)
            .scaleEffect(1.2)
    }
    
    private var waveEffect: some View {
        Circle()
            .fill(waveGradient)
            .scaleEffect(1.0 + sin(wavePhase) * 0.1)
            .opacity(0.6)
    }
    
    private var breathingEffect: some View {
        Circle()
            .fill(breathingGradient)
            .scaleEffect(breathingScale)
            .opacity(breathingOpacity)
    }
    
    private var rotateEffect: some View {
        ZStack {
            ForEach(0..<8, id: \.self) { index in
                Circle()
                    .fill(rotateIndicatorColor)
                    .frame(width: 4, height: 4)
                    .offset(y: -30)
                    .rotationEffect(.degrees(Double(index) * 45 + rotationAngle))
            }
        }
    }
    
    private var rotateIndicatorColor: Color {
        Color.red.opacity(0.7)
    }
    
    // MARK: - Helper Methods
    
    private func depthLayerColor(for index: Int) -> Color {
        let depth = GlassDepth.allCases[index % GlassDepth.allCases.count]
        let baseColor = palette?.tints[index % (palette?.tints.count ?? 1)].color ?? .white
        return baseColor.opacity(depth.opacity * intensity)
    }
    
    private func depthLayerOffset(for index: Int) -> CGSize {
        let offset: CGFloat = CGFloat(index + 1) * 1
        return CGSize(width: offset, height: offset)
    }
    
    private func depthLayerBlur(for index: Int) -> CGFloat {
        return CGFloat(index + 1) * 1
    }
    
    private func particleOpacity(for index: Int) -> Double {
        return Double.random(in: 0.3...0.8) * intensity
    }
    
    private var surfaceHighlightOpacity: Double {
        0.3 * intensity
    }
    
    private var pulseOpacity: Double {
        0.3 * intensity
    }
    
    // MARK: - Animation Methods
    
    private func startAnimations() {
        isAnimating = true
        
        if isRecording {
            startRecordingAnimation()
        }
        
        switch animationType {
        case .pulse:
            startPulseAnimation()
        case .glow:
            startGlowAnimation()
        case .wave:
            startWaveAnimation()
        case .breathing:
            startBreathingAnimation()
        case .rotate:
            startRotateAnimation()
        case .blink:
            startBlinkAnimation()
        case .none:
            break
        }
    }
    
    private func stopAnimations() {
        isAnimating = false
    }
    
    private func startRecordingAnimation() {
        // Start pulse rings
        startPulseRings()
        
        // Start ripple effect
        startRippleAnimation()
        
        // Initialize particles
        if animationType == .particles {
            initializeParticles()
            startParticleAnimation()
        }
    }
    
    private func stopRecordingAnimation() {
        // Stop pulse rings
        pulseRings.removeAll()
        
        // Clear particles
        particlePositions.removeAll()
    }
    
    private func startPulseRings() {
        // Create initial pulse ring
        addPulseRing()
        
        // Add pulse rings periodically
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if isAnimating && isRecording {
                addPulseRing()
            }
        }
    }
    
    private func addPulseRing() {
        let newRing = PulseRing(
            id: UUID(),
            scale: 1.0,
            opacity: 0.8
        )
        
        pulseRings.append(newRing)
        
        // Animate the ring
        withAnimation(.easeOut(duration: 2.0)) {
            if let index = pulseRings.firstIndex(where: { $0.id == newRing.id }) {
                pulseRings[index].scale = 2.5
                pulseRings[index].opacity = 0
            }
        }
        
        // Remove the ring after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            pulseRings.removeAll { $0.id == newRing.id }
        }
    }
    
    private func initializeParticles() {
        particlePositions = (0..<15).map { _ in
            CGPoint(
                x: CGFloat.random(in: -30...30),
                y: CGFloat.random(in: -30...30)
            )
        }
    }
    
    private func startPulseAnimation() {
        withAnimation(
            .easeInOut(duration: 1.0)
            .repeatForever(autoreverses: true)
        ) {
            pulseScale = 1.2
            pulseOpacity = 0.5
        }
    }
    
    private func startGlowAnimation() {
        withAnimation(
            .easeInOut(duration: 1.5)
            .repeatForever(autoreverses: true)
        ) {
            glowIntensity = 0.5
        }
    }
    
    private func startWaveAnimation() {
        withAnimation(
            .linear(duration: 2.0)
            .repeatForever(autoreverses: false)
        ) {
            wavePhase = 2 * .pi
        }
    }
    
    private func startBreathingAnimation() {
        withAnimation(
            .easeInOut(duration: 3.0)
            .repeatForever(autoreverses: true)
        ) {
            breathingScale = 1.1
            breathingOpacity = 0.9
        }
    }
    
    private func startRotateAnimation() {
        withAnimation(
            .linear(duration: 4.0)
            .repeatForever(autoreverses: false)
        ) {
            rotationAngle = 360
        }
    }
    
    private func startBlinkAnimation() {
        withAnimation(
            .easeInOut(duration: 0.5)
            .repeatForever(autoreverses: true)
        ) {
            recordingBlink.toggle()
        }
    }
    
    private func startRippleAnimation() {
        withAnimation(
            .easeOut(duration: 1.0)
            .repeatForever(autoreverses: false)
        ) {
            rippleScale = 1.5
            rippleOpacity = 0
        }
        
        // Reset ripple
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            if isAnimating && isRecording {
                rippleScale = 1.0
                rippleOpacity = 0.6
                startRippleAnimation()
            }
        }
    }
    
    private func startParticleAnimation() {
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            guard isAnimating && isRecording else { return }
            
            particlePositions = particlePositions.map { position in
                CGPoint(
                    x: position.x + CGFloat.random(in: -2...2),
                    y: position.y + CGFloat.random(in: -2...2)
                )
            }
            
            // Occasionally add new particles
            if Double.random(in: 0...1) < 0.1 {
                particlePositions.append(
                    CGPoint(
                        x: CGFloat.random(in: -10...10),
                        y: CGFloat.random(in: -10...10)
                    )
                )
                
                // Remove old particles if too many
                if particlePositions.count > 20 {
                    particlePositions.removeFirst()
                }
            }
        }
    }
}

// MARK: - Pulse Ring Model

struct PulseRing: Identifiable {
    let id: UUID
    var scale: CGFloat
    var opacity: Double
}

// MARK: - Glass Recording Indicator Variant

enum GlassRecordingIndicatorVariant: CaseIterable {
    case minimal
    case standard
    case prominent
    case dramatic
    
    var width: CGFloat {
        switch self {
        case .minimal:
            return 120
        case .standard:
            return 160
        case .prominent:
            return 200
        case .dramatic:
            return 240
        }
    }
    
    var height: CGFloat {
        switch self {
        case .minimal:
            return 36
        case .standard:
            return 44
        case .prominent:
            return 52
        case .dramatic:
            return 60
        }
    }
    
    var cornerRadius: CGFloat {
        switch self {
        case .minimal:
            return 18
        case .standard:
            return 22
        case .prominent:
            return 26
        case .dramatic:
            return 30
        }
    }
    
    var blurRadius: CGFloat {
        switch self {
        case .minimal:
            return 4
        case .standard:
            return 8
        case .prominent:
            return 12
        case .dramatic:
            return 16
        }
    }
    
    var borderWidth: CGFloat {
        switch self {
        case .minimal:
            return 1
        case .standard:
            return 1.5
        case .prominent:
            return 2
        case .dramatic:
            return 2.5
        }
    }
    
    var textStyle: DesignTypography.TextStyle {
        switch self {
        case .minimal:
            return TypographyPresets.Glass.caption
        case .standard:
            return TypographyPresets.Glass.body
        case .prominent:
            return TypographyPresets.Glass.subtitle
        case .dramatic:
            return TypographyPresets.Glass.title
        }
    }
    
    var animationDuration: Double {
        switch self {
        case .minimal:
            return 2.0
        case .standard:
            return 2.5
        case .prominent:
            return 3.0
        case .dramatic:
            return 3.5
        }
    }
    
    var depthLayers: Int {
        switch self {
        case .minimal:
            return 1
        case .standard:
            return 2
        case .prominent:
            return 3
        case .dramatic:
            return 4
        }
    }
    
    var name: String {
        switch self {
        case .minimal:
            return "Minimal"
        case .standard:
            return "Standard"
        case .prominent:
            return "Prominent"
        case .dramatic:
            return "Dramatic"
        }
    }
}

// MARK: - Glass Recording Animation Type

enum GlassRecordingAnimationType: CaseIterable {
    case pulse
    case glow
    case wave
    case breathing
    case rotate
    case blink
    case particles
    case none
    
    var name: String {
        switch self {
        case .pulse:
            return "Pulse"
        case .glow:
            return "Glow"
        case .wave:
            return "Wave"
        case .breathing:
            return "Breathing"
        case .rotate:
            return "Rotate"
        case .blink:
            return "Blink"
        case .particles:
            return "Particles"
        case .none:
            return "None"
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 30) {
        // Basic examples
        GlassRecordingIndicator(
            isRecording: true,
            recordingTime: 65,
            intensity: 0.7,
            variant: .minimal,
            animationType: .pulse
        )
        
        GlassRecordingIndicator(
            isRecording: true,
            recordingTime: 125,
            intensity: 0.5,
            variant: .standard,
            animationType: .glow
        )
        
        // Advanced examples
        GlassRecordingIndicator(
            isRecording: true,
            recordingTime: 185,
            intensity: 0.8,
            palette: .ocean,
            variant: .prominent,
            animationType: .wave
        )
        
        GlassRecordingIndicator(
            isRecording: true,
            recordingTime: 245,
            intensity: 0.9,
            palette: .sunset,
            variant: .dramatic,
            animationType: .particles
        )
        
        // Not recording
        GlassRecordingIndicator(
            isRecording: false,
            recordingTime: 0,
            intensity: 0.6,
            variant: .standard,
            animationType: .none
        )
    }
    .padding()
    .background(DesignColors.background)
}