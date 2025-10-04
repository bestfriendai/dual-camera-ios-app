//
//  GlassPreviewFrame.swift
//  DualApp
//
//  Created by DualApp Team on 10/3/25.
//

import SwiftUI

// MARK: - Glass Preview Frame

struct GlassPreviewFrame<Content: View>: View {
    // MARK: - Properties
    
    let content: Content
    let variant: GlassPreviewFrameVariant
    let intensity: Double
    let palette: LiquidGlassPalette?
    let animationType: GlassPreviewFrameAnimationType
    let borderStyle: GlassBorderStyle
    let cornerStyle: GlassPreviewFrameCornerStyle
    
    // MARK: - State
    
    @State private var animationOffset: CGSize = .zero
    @State private var isAnimating = false
    @State private var shimmerRotation: Double = 0
    @State private var pulseScale: CGFloat = 1.0
    @State private var glowIntensity: Double = 0.2
    @State private var wavePhase: Double = 0
    @State private var borderAnimationPhase: Double = 0
    @State private var cornerAnimationPhase: Double = 0
    @State private var isHovered = false
    @State private var isPressed = false
    @State private var focusPoint: CGPoint = .center
    @State private var isFocused = false
    
    // MARK: - Initialization
    
    init(
        variant: GlassPreviewFrameVariant = .standard,
        intensity: Double = 0.5,
        palette: LiquidGlassPalette? = nil,
        animationType: GlassPreviewFrameAnimationType = .shimmer,
        borderStyle: GlassBorderStyle = .solid,
        cornerStyle: GlassPreviewFrameCornerStyle = .rounded,
        @ViewBuilder content: () -> Content
    ) {
        self.variant = variant
        self.intensity = intensity
        self.palette = palette
        self.animationType = animationType
        self.borderStyle = borderStyle
        self.cornerStyle = cornerStyle
        self.content = content()
    }
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            // Background layers
            backgroundLayers
            
            // Glass surface
            glassSurface
            
            // Animation effects
            animationEffects
            
            // Border effects
            borderEffects
            
            // Corner effects
            cornerEffects
            
            // Interactive effects
            interactiveEffects
            
            // Focus ring
            if isFocused {
                focusRing
            }
            
            // Content
            content
                .clipped()
        }
        .frame(width: variant.width, height: variant.height)
        .clipShape(frameShape)
        .onAppear {
            startAnimations()
        }
        .onDisappear {
            stopAnimations()
        }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    handleDragChanged(value)
                }
                .onEnded { _ in
                    handleDragEnded()
                }
        )
        .onTapGesture { location in
            handleTap(at: location)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Camera preview")
    }
    
    // MARK: - View Components
    
    private var backgroundLayers: some View {
        ZStack {
            // Base blur effect
            frameShape
                .fill(baseBackgroundColor)
                .background(
                    frameShape
                        .fill(backgroundGradient)
                )
                .blur(radius: variant.blurRadius * intensity)
            
            // Depth layers
            ForEach(0..<variant.depthLayers, id: \.self) { index in
                frameShape
                    .fill(depthLayerColor(for: index))
                    .offset(depthLayerOffset(for: index))
                    .blur(radius: depthLayerBlur(for: index))
            }
            
            // Vignette effect
            frameShape
                .fill(vignetteGradient)
                .opacity(0.1 * intensity)
        }
    }
    
    private var glassSurface: some View {
        ZStack {
            frameShape
                .fill(surfaceGradient)
                .overlay(
                    // Surface highlights
                    frameShape
                        .fill(surfaceHighlightGradient)
                        .opacity(surfaceHighlightOpacity)
                )
                .overlay(
                    // Surface reflection
                    frameShape
                        .fill(reflectionGradient)
                        .opacity(reflectionOpacity)
                        .mask(reflectionMask)
                )
                .shadow(
                    color: shadowColor,
                    radius: shadowRadius,
                    x: shadowOffset.width,
                    y: shadowOffset.height
                )
        }
    }
    
    private var animationEffects: some View {
        ZStack {
            switch animationType {
            case .shimmer:
                shimmerEffect
            case .pulse:
                pulseEffect
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
    
    private var borderEffects: some View {
        ZStack {
            switch borderStyle {
            case .solid:
                solidBorder
            case .animated:
                animatedBorder
            case .dashed:
                dashedBorder
            case .dotted:
                dottedBorder
            case .gradient:
                gradientBorder
            case .neon:
                neonBorder
            }
        }
    }
    
    private var cornerEffects: some View {
        ZStack {
            switch cornerStyle {
            case .rounded:
                EmptyView()
            case .animated:
                animatedCorners
            case .accented:
                accentedCorners
            case .glowing:
                glowingCorners
            }
        }
    }
    
    private var interactiveEffects: some View {
        ZStack {
            frameShape
                .fill(interactiveOverlay)
                .opacity(interactiveOpacity)
                .animation(.easeInOut(duration: 0.2), value: isHovered)
            
            // Hover glow
            if isHovered {
                frameShape
                    .fill(hoverGlowGradient)
                    .opacity(0.1 * intensity)
                    .blur(radius: 15)
            }
        }
    }
    
    private var focusRing: some View {
        ZStack {
            // Focus ring
            Circle()
                .stroke(focusRingGradient, lineWidth: 2)
                .scaleEffect(1.0 + sin(borderAnimationPhase) * 0.05)
                .opacity(0.8)
            
            // Focus point
            Circle()
                .fill(Color.white)
                .frame(width: 8, height: 8)
                .position(focusPoint)
                .opacity(0.9)
        }
    }
    
    // MARK: - Shape Components
    
    private var frameShape: some Shape {
        switch cornerStyle {
        case .rounded, .animated, .accented, .glowing:
            return RoundedRectangle(cornerRadius: variant.cornerRadius)
        }
    }
    
    private var reflectionMask: some Shape {
        RoundedRectangle(cornerRadius: variant.cornerRadius)
            .path(in: CGRect(x: 0, y: 0, width: variant.width, height: variant.height / 3))
            .offset(y: -variant.height / 6)
    }
    
    // MARK: - Border Components
    
    private var solidBorder: some View {
        frameShape
            .stroke(borderGradient, lineWidth: variant.borderWidth)
    }
    
    private var animatedBorder: some View {
        frameShape
            .stroke(
                LinearGradient(
                    colors: [
                        (palette?.accentColor ?? .blue).opacity(0.8 * intensity),
                        (palette?.accentColor ?? .blue).opacity(0.3 * intensity),
                        (palette?.accentColor ?? .blue).opacity(0.8 * intensity)
                    ],
                    startPoint: animatedBorderStart,
                    endPoint: animatedBorderEnd
                ),
                lineWidth: variant.borderWidth
            )
    }
    
    private var dashedBorder: some View {
        frameShape
            .stroke(
                borderGradient,
                style: StrokeStyle(
                    lineWidth: variant.borderWidth,
                    lineCap: .round,
                    dash: [10, 5]
                )
            )
    }
    
    private var dottedBorder: some View {
        frameShape
            .stroke(
                borderGradient,
                style: StrokeStyle(
                    lineWidth: variant.borderWidth,
                    lineCap: .round,
                    dash: [2, 4]
                )
            )
    }
    
    private var gradientBorder: some View {
        frameShape
            .stroke(borderGradient, lineWidth: variant.borderWidth * 2)
    }
    
    private var neonBorder: some View {
        ZStack {
            frameShape
                .stroke(neonBorderGradient, lineWidth: variant.borderWidth)
                .blur(radius: 4)
            
            frameShape
                .stroke(neonBorderGradient, lineWidth: variant.borderWidth / 2)
        }
    }
    
    // MARK: - Corner Components
    
    private var animatedCorners: some View {
        ZStack {
            ForEach(0..<4, id: \.self) { index in
                cornerAccent(at: index)
                    .scaleEffect(1.0 + sin(cornerAnimationPhase + Double(index) * .pi / 2) * 0.2)
                    .opacity(0.8)
            }
        }
    }
    
    private var accentedCorners: some View {
        ZStack {
            ForEach(0..<4, id: \.self) { index in
                cornerAccent(at: index)
            }
        }
    }
    
    private var glowingCorners: some View {
        ZStack {
            ForEach(0..<4, id: \.self) { index in
                cornerAccent(at: index)
                    .glow()
            }
        }
    }
    
    private func cornerAccent(at index: Int) -> some View {
        let positions = [
            CGPoint(x: variant.cornerRadius, y: variant.cornerRadius),
            CGPoint(x: variant.width - variant.cornerRadius, y: variant.cornerRadius),
            CGPoint(x: variant.width - variant.cornerRadius, y: variant.height - variant.cornerRadius),
            CGPoint(x: variant.cornerRadius, y: variant.height - variant.cornerRadius)
        ]
        
        return Circle()
            .fill(cornerAccentGradient)
            .frame(width: 12, height: 12)
            .position(positions[index])
    }
    
    // MARK: - Color and Gradient Computations
    
    private var baseBackgroundColor: Color {
        palette?.baseColor ?? LiquidGlassColors.clear
    }
    
    private var backgroundGradient: LinearGradient {
        let colors = [
            baseBackgroundColor.opacity(0.03 * intensity),
            baseBackgroundColor.opacity(0.06 * intensity),
            baseBackgroundColor.opacity(0.09 * intensity)
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
            baseTint.opacity(0.08 * intensity),
            baseTint.opacity(0.04 * intensity),
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
            LiquidGlassColors.surfaceReflection.opacity(0.2 * intensity),
            LiquidGlassColors.surfaceReflection.opacity(0.1 * intensity),
            LiquidGlassColors.surfaceReflection.opacity(0.05 * intensity)
        ]
        
        return LinearGradient(
            colors: colors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    private var reflectionGradient: LinearGradient {
        let colors = [
            .white.opacity(0.15),
            .white.opacity(0.08),
            .white.opacity(0)
        ]
        
        return LinearGradient(
            colors: colors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    private var borderGradient: LinearGradient {
        let accentColor = palette?.accentColor ?? LiquidGlassColors.glassBorder
        
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
    
    private var cornerAccentGradient: RadialGradient {
        let accentColor = palette?.accentColor ?? .blue
        
        return RadialGradient(
            colors: [
                accentColor.opacity(0.8 * intensity),
                accentColor.opacity(0.4 * intensity),
                accentColor.opacity(0)
            ],
            center: .center,
            startRadius: 2,
            endRadius: 8
        )
    }
    
    private var vignetteGradient: RadialGradient {
        return RadialGradient(
            colors: [
                .clear,
                .black.opacity(0.1),
                .black.opacity(0.2)
            ],
            center: .center,
            startRadius: 100,
            endRadius: 300
        )
    }
    
    private var animatedBorderStart: UnitPoint {
        let angle = borderAnimationPhase * 180 / .pi
        return UnitPoint(
            x: 0.5 + cos(angle) * 0.5,
            y: 0.5 + sin(angle) * 0.5
        )
    }
    
    private var animatedBorderEnd: UnitPoint {
        let angle = borderAnimationPhase * 180 / .pi + .pi
        return UnitPoint(
            x: 0.5 + cos(angle) * 0.5,
            y: 0.5 + sin(angle) * 0.5
        )
    }
    
    private var neonBorderGradient: LinearGradient {
        let accentColor = palette?.accentColor ?? .blue
        
        return LinearGradient(
            colors: [
                accentColor.opacity(0.9),
                accentColor.opacity(0.6),
                accentColor.opacity(0.3),
                accentColor.opacity(0.6),
                accentColor.opacity(0.9)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    private var shimmerGradient: LinearGradient {
        let colors = [
            LiquidGlassColors.shimmer.opacity(0),
            LiquidGlassColors.shimmerBright.opacity(0.4 * intensity),
            LiquidGlassColors.shimmer.opacity(0)
        ]
        
        return LinearGradient(
            colors: colors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    private var pulseGradient: LinearGradient {
        let pulseColor = palette?.accentColor ?? LiquidGlassColors.pulse
        
        return LinearGradient(
            colors: [
                pulseColor.opacity(0.1 * intensity),
                pulseColor.opacity(0.05 * intensity),
                pulseColor.opacity(0)
            ],
            startPoint: .center,
            endPoint: .edge
        )
    }
    
    private var glowGradient: RadialGradient {
        let glowColor = palette?.accentColor ?? LiquidGlassColors.glow
        
        return RadialGradient(
            colors: [
                glowColor.opacity(0.3 * intensity),
                glowColor.opacity(0.15 * intensity),
                glowColor.opacity(0)
            ],
            center: .center,
            startRadius: 20,
            endRadius: 150
        )
    }
    
    private var waveGradient: LinearGradient {
        let waveColor = palette?.baseColor ?? LiquidGlassColors.waveOverlay
        
        return LinearGradient(
            colors: [
                waveColor.opacity(0.15 * intensity),
                waveColor.opacity(0.08 * intensity),
                waveColor.opacity(0.04 * intensity)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
    
    private var breathingGradient: LinearGradient {
        let breathingColor = palette?.baseColor ?? .white
        
        return LinearGradient(
            colors: [
                breathingColor.opacity(0.08 * intensity),
                breathingColor.opacity(0.04 * intensity),
                breathingColor.opacity(0.02 * intensity)
            ],
            startPoint: .center,
            endPoint: .edge
        )
    }
    
    private var interactiveOverlay: Color {
        palette?.accentColor ?? .white
    }
    
    private var hoverGlowGradient: RadialGradient {
        let glowColor = palette?.accentColor ?? .blue
        
        return RadialGradient(
            colors: [
                glowColor.opacity(0.4),
                glowColor.opacity(0.2),
                glowColor.opacity(0)
            ],
            center: .center,
            startRadius: 10,
            endRadius: 100
        )
    }
    
    private var focusRingGradient: LinearGradient {
        return LinearGradient(
            colors: [
                .white.opacity(0.9),
                .white.opacity(0.6),
                .white.opacity(0.3)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    private var shadowColor: Color {
        LiquidGlassColors.glassShadow.opacity(0.3 * intensity)
    }
    
    // MARK: - Animation Components
    
    private var shimmerEffect: some View {
        frameShape
            .fill(shimmerGradient)
            .offset(animationOffset)
            .rotationEffect(.degrees(shimmerRotation))
            .mask(frameShape)
    }
    
    private var pulseEffect: some View {
        frameShape
            .fill(pulseGradient)
            .scaleEffect(pulseScale)
            .opacity(pulseOpacity)
            .mask(frameShape)
    }
    
    private var glowEffect: some View {
        frameShape
            .fill(glowGradient)
            .opacity(glowIntensity)
            .blur(radius: glowBlurRadius)
            .mask(frameShape)
    }
    
    private var waveEffect: some View {
        frameShape
            .fill(waveGradient)
            .opacity(waveOpacity)
            .mask(
                frameShape
                    .offset(x: sin(wavePhase) * 10, y: cos(wavePhase) * 5)
            )
    }
    
    private var breathingEffect: some View {
        frameShape
            .fill(breathingGradient)
            .scaleEffect(1.0 + sin(wavePhase) * 0.01)
            .opacity(0.9 + sin(wavePhase) * 0.1)
            .mask(frameShape)
    }
    
    // MARK: - Gesture Handling
    
    private func handleDragChanged(_ value: DragGesture.Value) {
        isPressed = true
        isHovered = true
        
        // Update focus point
        focusPoint = value.location
        isFocused = true
        
        HapticFeedbackManager.shared.lightImpact()
    }
    
    private func handleDragEnded() {
        isPressed = false
        isHovered = false
        
        // Clear focus after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            isFocused = false
        }
    }
    
    private func handleTap(at location: CGPoint) {
        focusPoint = location
        isFocused = true
        
        HapticFeedbackManager.shared.lightImpact()
        
        // Clear focus after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            isFocused = false
        }
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
    
    private var surfaceHighlightOpacity: Double {
        0.2 * intensity
    }
    
    private var reflectionOpacity: Double {
        0.15 * intensity
    }
    
    private var pulseOpacity: Double {
        0.15 * intensity
    }
    
    private var glowBlurRadius: CGFloat {
        20 * intensity
    }
    
    private var waveOpacity: Double {
        0.12 * intensity
    }
    
    private var interactiveOpacity: Double {
        if isPressed {
            return 0.15
        } else if isHovered {
            return 0.08
        } else {
            return 0
        }
    }
    
    private var shadowRadius: CGFloat {
        10 * intensity
    }
    
    private var shadowOffset: CGSize {
        CGSize(width: 0, height: 4)
    }
    
    // MARK: - Animation Methods
    
    private func startAnimations() {
        isAnimating = true
        
        switch animationType {
        case .shimmer:
            startShimmerAnimation()
        case .pulse:
            startPulseAnimation()
        case .glow:
            startGlowAnimation()
        case .wave:
            startWaveAnimation()
        case .breathing:
            startBreathingAnimation()
        case .none:
            break
        }
        
        // Start border animations
        if borderStyle == .animated {
            startBorderAnimation()
        }
        
        // Start corner animations
        if cornerStyle == .animated || cornerStyle == .glowing {
            startCornerAnimation()
        }
    }
    
    private func stopAnimations() {
        isAnimating = false
    }
    
    private func startShimmerAnimation() {
        withAnimation(
            .easeInOut(duration: variant.animationDuration)
            .repeatForever(autoreverses: true)
        ) {
            animationOffset = CGSize(width: variant.width, height: variant.height)
            shimmerRotation = 45
        }
    }
    
    private func startPulseAnimation() {
        withAnimation(
            .easeInOut(duration: variant.animationDuration)
            .repeatForever(autoreverses: true)
        ) {
            pulseScale = 1.01
        }
    }
    
    private func startGlowAnimation() {
        withAnimation(
            .easeInOut(duration: variant.animationDuration * 1.5)
            .repeatForever(autoreverses: true)
        ) {
            glowIntensity = 0.3
        }
    }
    
    private func startWaveAnimation() {
        withAnimation(
            .linear(duration: variant.animationDuration)
            .repeatForever(autoreverses: false)
        ) {
            wavePhase = 2 * .pi
        }
    }
    
    private func startBreathingAnimation() {
        withAnimation(
            .easeInOut(duration: variant.animationDuration * 3)
            .repeatForever(autoreverses: true)
        ) {
            wavePhase = 2 * .pi
        }
    }
    
    private func startBorderAnimation() {
        withAnimation(
            .linear(duration: 4.0)
            .repeatForever(autoreverses: false)
        ) {
            borderAnimationPhase = 2 * .pi
        }
    }
    
    private func startCornerAnimation() {
        withAnimation(
            .easeInOut(duration: 2.0)
            .repeatForever(autoreverses: true)
        ) {
            cornerAnimationPhase = 2 * .pi
        }
    }
}

// MARK: - Glass Preview Frame Variant

enum GlassPreviewFrameVariant: CaseIterable {
    case minimal
    case standard
    case cinematic
    case immersive
    case dramatic
    
    var width: CGFloat {
        switch self {
        case .minimal:
            return 280
        case .standard:
            return 320
        case .cinematic:
            return 360
        case .immersive:
            return 400
        case .dramatic:
            return 440
        }
    }
    
    var height: CGFloat {
        switch self {
        case .minimal:
            return 200
        case .standard:
            return 240
        case .cinematic:
            return 280
        case .immersive:
            return 320
        case .dramatic:
            return 360
        }
    }
    
    var cornerRadius: CGFloat {
        switch self {
        case .minimal:
            return 12
        case .standard:
            return 16
        case .cinematic:
            return 20
        case .immersive:
            return 24
        case .dramatic:
            return 28
        }
    }
    
    var blurRadius: CGFloat {
        switch self {
        case .minimal:
            return 4
        case .standard:
            return 8
        case .cinematic:
            return 12
        case .immersive:
            return 16
        case .dramatic:
            return 20
        }
    }
    
    var borderWidth: CGFloat {
        switch self {
        case .minimal:
            return 1
        case .standard:
            return 1.5
        case .cinematic:
            return 2
        case .immersive:
            return 2.5
        case .dramatic:
            return 3
        }
    }
    
    var animationDuration: Double {
        switch self {
        case .minimal:
            return 2.5
        case .standard:
            return 3.0
        case .cinematic:
            return 3.5
        case .immersive:
            return 4.0
        case .dramatic:
            return 4.5
        }
    }
    
    var depthLayers: Int {
        switch self {
        case .minimal:
            return 1
        case .standard:
            return 2
        case .cinematic:
            return 3
        case .immersive:
            return 4
        case .dramatic:
            return 5
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
        case .immersive:
            return "Immersive"
        case .dramatic:
            return "Dramatic"
        }
    }
}

// MARK: - Glass Preview Frame Animation Type

enum GlassPreviewFrameAnimationType: CaseIterable {
    case none
    case shimmer
    case pulse
    case glow
    case wave
    case breathing
    
    var name: String {
        switch self {
        case .none:
            return "None"
        case .shimmer:
            return "Shimmer"
        case .pulse:
            return "Pulse"
        case .glow:
            return "Glow"
        case .wave:
            return "Wave"
        case .breathing:
            return "Breathing"
        }
    }
}

// MARK: - Glass Border Style

enum GlassBorderStyle: CaseIterable {
    case solid
    case animated
    case dashed
    case dotted
    case gradient
    case neon
    
    var name: String {
        switch self {
        case .solid:
            return "Solid"
        case .animated:
            return "Animated"
        case .dashed:
            return "Dashed"
        case .dotted:
            return "Dotted"
        case .gradient:
            return "Gradient"
        case .neon:
            return "Neon"
        }
    }
}

// MARK: - Glass Preview Frame Corner Style

enum GlassPreviewFrameCornerStyle: CaseIterable {
    case rounded
    case animated
    case accented
    case glowing
    
    var name: String {
        switch self {
        case .rounded:
            return "Rounded"
        case .animated:
            return "Animated"
        case .accented:
            return "Accented"
        case .glowing:
            return "Glowing"
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 30) {
        // Basic examples
        GlassPreviewFrame(
            variant: .minimal,
            intensity: 0.7,
            animationType: .shimmer
        ) {
            Color.blue.opacity(0.3)
        }
        
        GlassPreviewFrame(
            variant: .standard,
            intensity: 0.5,
            animationType: .pulse,
            borderStyle: .animated
        ) {
            Color.green.opacity(0.3)
        }
        
        // Advanced examples
        GlassPreviewFrame(
            variant: .cinematic,
            intensity: 0.6,
            palette: .ocean,
            animationType: .wave,
            borderStyle: .neon,
            cornerStyle: .glowing
        ) {
            Color.red.opacity(0.3)
        }
        
        GlassPreviewFrame(
            variant: .immersive,
            intensity: 0.8,
            palette: .sunset,
            animationType: .breathing,
            borderStyle: .gradient,
            cornerStyle: .animated
        ) {
            Color.purple.opacity(0.3)
        }
    }
    .padding()
    .background(DesignColors.background)
}