//
//  GlassFocusRing.swift
//  DualApp
//
//  Created by DualApp Team on 10/3/25.
//

import SwiftUI

// MARK: - Glass Focus Ring

struct GlassFocusRing: View {
    // MARK: - Properties
    
    let focusPoint: CGPoint
    let isFocused: Bool
    let isAutoFocusing: Bool
    let intensity: Double
    let palette: LiquidGlassPalette?
    let variant: GlassFocusRingVariant
    let animationType: GlassFocusRingAnimationType
    
    // MARK: - State
    
    @State private var ringScale: CGFloat = 1.0
    @State private var ringOpacity: Double = 0.8
    @State private var pulseScale: CGFloat = 1.0
    @State private var pulseOpacity: Double = 0.3
    @State private var rotationAngle: Double = 0
    @State private var glowIntensity: Double = 0.2
    @State private var wavePhase: Double = 0
    @State private var focusAnimationPhase: Double = 0
    @State private var isAnimating = false
    @State private var targetFocusPoint: CGPoint = .center
    @State private var currentFocusPoint: CGPoint = .center
    @State private var focusProgress: Double = 0.0
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            // Focus ring layers
            focusRingLayers
            
            // Animation effects
            animationEffects
            
            // Focus indicators
            focusIndicators
            
            // Focus brackets
            focusBrackets
            
            // Focus point
            focusPointIndicator
        }
        .position(currentFocusPoint)
        .opacity(isFocused ? 1.0 : 0.0)
        .scaleEffect(isFocused ? 1.0 : 0.8)
        .onAppear {
            currentFocusPoint = focusPoint
            targetFocusPoint = focusPoint
            startAnimations()
        }
        .onChange(of: focusPoint) { newPoint in
            targetFocusPoint = newPoint
            animateFocusTo(newPoint)
        }
        .onChange(of: isFocused) { focused in
            if focused {
                startFocusAnimation()
            } else {
                stopFocusAnimation()
            }
        }
        .onChange(of: isAutoFocusing) { focusing in
            if focusing {
                startAutoFocusAnimation()
            } else {
                stopAutoFocusAnimation()
            }
        }
    }
    
    // MARK: - View Components
    
    private var focusRingLayers: some View {
        ZStack {
            // Outer ring
            Circle()
                .stroke(outerRingGradient, lineWidth: variant.outerRingWidth)
                .scaleEffect(ringScale)
                .opacity(ringOpacity)
            
            // Middle ring
            Circle()
                .stroke(middleRingGradient, lineWidth: variant.middleRingWidth)
                .scaleEffect(ringScale * 0.9)
                .opacity(ringOpacity * 0.8)
            
            // Inner ring
            Circle()
                .stroke(innerRingGradient, lineWidth: variant.innerRingWidth)
                .scaleEffect(ringScale * 0.8)
                .opacity(ringOpacity * 0.6)
        }
    }
    
    private var animationEffects: some View {
        ZStack {
            switch animationType {
            case .pulse:
                pulseEffect
            case .rotate:
                rotateEffect
            case .glow:
                glowEffect
            case .wave:
                waveEffect
            case .breathing:
                breathingEffect
            case .none:
                EmptyView()
            }
        }
    }
    
    private var focusIndicators: some View {
        ZStack {
            // Corner indicators
            ForEach(0..<4, id: \.self) { index in
                cornerIndicator(at: index)
            }
            
            // Edge indicators
            ForEach(0..<4, id: \.self) { index in
                edgeIndicator(at: index)
            }
        }
    }
    
    private var focusBrackets: some View {
        ZStack {
            // Corner brackets
            ForEach(0..<4, id: \.self) { index in
                cornerBracket(at: index)
            }
        }
    }
    
    private var focusPointIndicator: some View {
        ZStack {
            // Center dot
            Circle()
                .fill(focusPointColor)
                .frame(width: 6, height: 6)
                .opacity(isAutoFocusing ? 0.3 : 0.8)
            
            // Pulsing ring around center
            if isAutoFocusing {
                Circle()
                    .stroke(focusPointColor, lineWidth: 1)
                    .scaleEffect(pulseScale)
                    .opacity(pulseOpacity)
            }
        }
    }
    
    // MARK: - Indicator Components
    
    private func cornerIndicator(at index: Int) -> some View {
        let positions = [
            CGPoint(x: -variant.size / 2, y: -variant.size / 2),
            CGPoint(x: variant.size / 2, y: -variant.size / 2),
            CGPoint(x: variant.size / 2, y: variant.size / 2),
            CGPoint(x: -variant.size / 2, y: variant.size / 2)
        ]
        
        return Circle()
            .fill(cornerIndicatorGradient)
            .frame(width: 8, height: 8)
            .position(positions[index])
            .scaleEffect(1.0 + sin(focusAnimationPhase + Double(index) * .pi / 2) * 0.2)
            .opacity(0.8)
    }
    
    private func edgeIndicator(at index: Int) -> some View {
        let positions = [
            CGPoint(x: 0, y: -variant.size / 2),
            CGPoint(x: variant.size / 2, y: 0),
            CGPoint(x: 0, y: variant.size / 2),
            CGPoint(x: -variant.size / 2, y: 0)
        ]
        
        return RoundedRectangle(cornerRadius: 2)
            .fill(edgeIndicatorGradient)
            .frame(width: 12, height: 3)
            .position(positions[index])
            .scaleEffect(1.0 + sin(focusAnimationPhase + Double(index) * .pi / 2) * 0.15)
            .opacity(0.6)
    }
    
    private func cornerBracket(at index: Int) -> some View {
        let positions = [
            CGPoint(x: -variant.size / 2 + 10, y: -variant.size / 2 + 10),
            CGPoint(x: variant.size / 2 - 10, y: -variant.size / 2 + 10),
            CGPoint(x: variant.size / 2 - 10, y: variant.size / 2 - 10),
            CGPoint(x: -variant.size / 2 + 10, y: variant.size / 2 - 10)
        ]
        
        return cornerBracketShape(for: index)
            .stroke(bracketGradient, lineWidth: 2)
            .frame(width: 20, height: 20)
            .position(positions[index])
            .opacity(0.9)
    }
    
    private func cornerBracketShape(for index: Int) -> Path {
        var path = Path()
        
        switch index {
        case 0: // Top-left
            path.move(to: CGPoint(x: 0, y: 15))
            path.addLine(to: CGPoint(x: 0, y: 0))
            path.addLine(to: CGPoint(x: 15, y: 0))
        case 1: // Top-right
            path.move(to: CGPoint(x: 5, y: 0))
            path.addLine(to: CGPoint(x: 20, y: 0))
            path.addLine(to: CGPoint(x: 20, y: 15))
        case 2: // Bottom-right
            path.move(to: CGPoint(x: 20, y: 5))
            path.addLine(to: CGPoint(x: 20, y: 20))
            path.addLine(to: CGPoint(x: 5, y: 20))
        case 3: // Bottom-left
            path.move(to: CGPoint(x: 15, y: 20))
            path.addLine(to: CGPoint(x: 0, y: 20))
            path.addLine(to: CGPoint(x: 0, y: 5))
        default:
            break
        }
        
        return path
    }
    
    // MARK: - Animation Components
    
    private var pulseEffect: some View {
        Circle()
            .stroke(pulseGradient, lineWidth: 2)
            .scaleEffect(pulseScale)
            .opacity(pulseOpacity)
    }
    
    private var rotateEffect: some View {
        ZStack {
            ForEach(0..<8, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1)
                    .fill(rotateIndicatorColor)
                    .frame(width: 15, height: 2)
                    .offset(y: -variant.size / 2 - 5)
                    .rotationEffect(.degrees(Double(index) * 45 + rotationAngle))
            }
        }
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
            .stroke(waveGradient, lineWidth: 2)
            .scaleEffect(1.0 + sin(wavePhase) * 0.1)
            .opacity(0.6)
    }
    
    private var breathingEffect: some View {
        Circle()
            .stroke(breathingGradient, lineWidth: 2)
            .scaleEffect(1.0 + sin(wavePhase) * 0.05)
            .opacity(0.7 + sin(wavePhase) * 0.2)
    }
    
    // MARK: - Color and Gradient Computations
    
    private var outerRingGradient: LinearGradient {
        let accentColor = palette?.accentColor ?? .blue
        
        return LinearGradient(
            colors: [
                accentColor.opacity(0.8 * intensity),
                accentColor.opacity(0.4 * intensity),
                accentColor.opacity(0.8 * intensity)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    private var middleRingGradient: LinearGradient {
        let accentColor = palette?.accentColor ?? .blue
        
        return LinearGradient(
            colors: [
                accentColor.opacity(0.6 * intensity),
                accentColor.opacity(0.3 * intensity),
                accentColor.opacity(0.6 * intensity)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    private var innerRingGradient: LinearGradient {
        let accentColor = palette?.accentColor ?? .blue
        
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
    
    private var cornerIndicatorGradient: RadialGradient {
        let accentColor = palette?.accentColor ?? .blue
        
        return RadialGradient(
            colors: [
                accentColor.opacity(0.9 * intensity),
                accentColor.opacity(0.5 * intensity),
                accentColor.opacity(0)
            ],
            center: .center,
            startRadius: 2,
            endRadius: 6
        )
    }
    
    private var edgeIndicatorGradient: LinearGradient {
        let accentColor = palette?.accentColor ?? .blue
        
        return LinearGradient(
            colors: [
                accentColor.opacity(0.7 * intensity),
                accentColor.opacity(0.3 * intensity)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
    
    private var bracketGradient: LinearGradient {
        return LinearGradient(
            colors: [
                .white.opacity(0.9),
                .white.opacity(0.6),
                .white.opacity(0.9)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    private var pulseGradient: RadialGradient {
        let accentColor = palette?.accentColor ?? .blue
        
        return RadialGradient(
            colors: [
                accentColor.opacity(0.6 * intensity),
                accentColor.opacity(0.3 * intensity),
                accentColor.opacity(0)
            ],
            center: .center,
            startRadius: 10,
            endRadius: 50
        )
    }
    
    private var rotateIndicatorColor: Color {
        (palette?.accentColor ?? .blue).opacity(0.7 * intensity)
    }
    
    private var glowGradient: RadialGradient {
        let accentColor = palette?.accentColor ?? .blue
        
        return RadialGradient(
            colors: [
                accentColor.opacity(0.5 * intensity),
                accentColor.opacity(0.25 * intensity),
                accentColor.opacity(0)
            ],
            center: .center,
            startRadius: 10,
            endRadius: 60
        )
    }
    
    private var waveGradient: LinearGradient {
        let accentColor = palette?.accentColor ?? .blue
        
        return LinearGradient(
            colors: [
                accentColor.opacity(0.4 * intensity),
                accentColor.opacity(0.2 * intensity),
                accentColor.opacity(0.1 * intensity)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
    
    private var breathingGradient: LinearGradient {
        let accentColor = palette?.accentColor ?? .blue
        
        return LinearGradient(
            colors: [
                accentColor.opacity(0.3 * intensity),
                accentColor.opacity(0.15 * intensity),
                accentColor.opacity(0.05 * intensity)
            ],
            startPoint: .center,
            endPoint: .edge
        )
    }
    
    private var focusPointColor: Color {
        isAutoFocusing ? .red : .white
    }
    
    // MARK: - Animation Methods
    
    private func animateFocusTo(_ point: CGPoint) {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            currentFocusPoint = targetFocusPoint
        }
    }
    
    private func startAnimations() {
        isAnimating = true
        
        if isFocused {
            startFocusAnimation()
        }
        
        if isAutoFocusing {
            startAutoFocusAnimation()
        }
        
        switch animationType {
        case .pulse:
            startPulseAnimation()
        case .rotate:
            startRotateAnimation()
        case .glow:
            startGlowAnimation()
        case .wave:
            startWaveAnimation()
        case .breathing:
            startBreathingAnimation()
        case .none:
            break
        }
    }
    
    private func stopAnimations() {
        isAnimating = false
    }
    
    private func startFocusAnimation() {
        withAnimation(.easeInOut(duration: 0.3)) {
            ringScale = 1.0
            ringOpacity = 0.8
        }
        
        withAnimation(
            .easeInOut(duration: 1.5)
            .repeatForever(autoreverses: true)
        ) {
            focusAnimationPhase = 2 * .pi
        }
    }
    
    private func stopFocusAnimation() {
        withAnimation(.easeInOut(duration: 0.3)) {
            ringScale = 0.8
            ringOpacity = 0.0
        }
    }
    
    private func startAutoFocusAnimation() {
        withAnimation(
            .easeInOut(duration: 0.8)
            .repeatForever(autoreverses: true)
        ) {
            pulseScale = 1.5
            pulseOpacity = 0.6
        }
    }
    
    private func stopAutoFocusAnimation() {
        withAnimation(.easeInOut(duration: 0.3)) {
            pulseScale = 1.0
            pulseOpacity = 0.3
        }
    }
    
    private func startPulseAnimation() {
        withAnimation(
            .easeInOut(duration: 1.5)
            .repeatForever(autoreverses: true)
        ) {
            pulseScale = 1.2
            pulseOpacity = 0.5
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
    
    private func startGlowAnimation() {
        withAnimation(
            .easeInOut(duration: 2.0)
            .repeatForever(autoreverses: true)
        ) {
            glowIntensity = 0.4
        }
    }
    
    private func startWaveAnimation() {
        withAnimation(
            .linear(duration: 3.0)
            .repeatForever(autoreverses: false)
        ) {
            wavePhase = 2 * .pi
        }
    }
    
    private func startBreathingAnimation() {
        withAnimation(
            .easeInOut(duration: 4.0)
            .repeatForever(autoreverses: true)
        ) {
            wavePhase = 2 * .pi
        }
    }
}

// MARK: - Glass Focus Ring Variant

enum GlassFocusRingVariant: CaseIterable {
    case minimal
    case standard
    case cinematic
    case professional
    
    var size: CGFloat {
        switch self {
        case .minimal:
            return 60
        case .standard:
            return 80
        case .cinematic:
            return 100
        case .professional:
            return 120
        }
    }
    
    var outerRingWidth: CGFloat {
        switch self {
        case .minimal:
            return 2
        case .standard:
            return 2.5
        case .cinematic:
            return 3
        case .professional:
            return 3.5
        }
    }
    
    var middleRingWidth: CGFloat {
        switch self {
        case .minimal:
            return 1.5
        case .standard:
            return 2
        case .cinematic:
            return 2.5
        case .professional:
            return 3
        }
    }
    
    var innerRingWidth: CGFloat {
        switch self {
        case .minimal:
            return 1
        case .standard:
            return 1.5
        case .cinematic:
            return 2
        case .professional:
            return 2.5
        }
    }
    
    var name: String {
        switch self {
        case .minimal:
            return "Minimal"
        case .standard:
            return "Standard"
        case .cinematic:
            return "Cinematic"
        case .professional:
            return "Professional"
        }
    }
}

// MARK: - Glass Focus Ring Animation Type

enum GlassFocusRingAnimationType: CaseIterable {
    case none
    case pulse
    case rotate
    case glow
    case wave
    case breathing
    
    var name: String {
        switch self {
        case .none:
            return "None"
        case .pulse:
            return "Pulse"
        case .rotate:
            return "Rotate"
        case .glow:
            return "Glow"
        case .wave:
            return "Wave"
        case .breathing:
            return "Breathing"
        }
    }
}

// MARK: - Glass Focus Ring Container

struct GlassFocusRingContainer<Content: View>: View {
    // MARK: - Properties
    
    let content: Content
    let intensity: Double
    let palette: LiquidGlassPalette?
    let variant: GlassFocusRingVariant
    let animationType: GlassFocusRingAnimationType
    
    // MARK: - State
    
    @State private var focusPoint: CGPoint = .center
    @State private var isFocused: Bool = false
    @State private var isAutoFocusing: Bool = false
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            content
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            focusPoint = value.location
                            isFocused = true
                        }
                        .onEnded { _ in
                            // Clear focus after delay
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                                isFocused = false
                            }
                        }
                )
            
            GlassFocusRing(
                focusPoint: focusPoint,
                isFocused: isFocused,
                isAutoFocusing: isAutoFocusing,
                intensity: intensity,
                palette: palette,
                variant: variant,
                animationType: animationType
            )
        }
    }
    
    // MARK: - Public Methods
    
    func setFocusPoint(_ point: CGPoint) {
        focusPoint = point
        isFocused = true
    }
    
    func clearFocus() {
        isFocused = false
    }
    
    func startAutoFocus() {
        isAutoFocusing = true
    }
    
    func stopAutoFocus() {
        isAutoFocusing = false
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black
        
        GlassFocusRingContainer(
            intensity: 0.7,
            palette: .ocean,
            variant: .cinematic,
            animationType: .pulse
        ) {
            Color.blue.opacity(0.3)
                .frame(width: 400, height: 300)
        }
    }
    .ignoresSafeArea()
}