//
//  GlassCard.swift
//  DualApp
//
//  Created by DualApp Team on 10/3/25.
//

import SwiftUI

// MARK: - Glass Card

struct GlassCard<Content: View>: View {
    // MARK: - Properties
    
    let content: Content
    let variant: GlassCardVariant
    let intensity: Double
    let palette: LiquidGlassPalette?
    let animationType: LiquidGlassAnimationType
    let shadowStyle: GlassCardShadowStyle
    let cornerStyle: GlassCardCornerStyle
    let isInteractive: Bool
    
    // MARK: - State
    
    @State private var animationOffset: CGSize = .zero
    @State private var isAnimating = false
    @State private var shimmerRotation: Double = 0
    @State private var pulseScale: CGFloat = 1.0
    @State private var glowIntensity: Double = 0.2
    @State private var wavePhase: Double = 0
    @State private var isHovered = false
    @State private var isPressed = false
    @State private var cardRotation: Double = 0
    @State private var depthOffset: CGFloat = 0
    @State private var shadowOpacity: Double = 0.3
    
    // MARK: - Initialization
    
    init(
        variant: GlassCardVariant = .standard,
        intensity: Double = 0.5,
        palette: LiquidGlassPalette? = nil,
        animationType: LiquidGlassAnimationType = .shimmer,
        shadowStyle: GlassCardShadowStyle = .elevated,
        cornerStyle: GlassCardCornerStyle = .rounded,
        isInteractive: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.variant = variant
        self.intensity = intensity
        self.palette = palette
        self.animationType = animationType
        self.shadowStyle = shadowStyle
        self.cornerStyle = cornerStyle
        self.isInteractive = isInteractive
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
            
            // Interactive effects
            if isInteractive {
                interactiveEffects
            }
            
            // Content
            content
                .padding(variant.padding)
                .scaleEffect(isPressed ? 0.98 : 1.0)
                .rotationEffect(.degrees(cardRotation))
                .offset(y: depthOffset)
                .animation(.easeInOut(duration: 0.2), value: isPressed)
                .animation(.easeInOut(duration: 0.3), value: cardRotation)
                .animation(.easeInOut(duration: 0.3), value: depthOffset)
        }
        .onAppear {
            startAnimations()
        }
        .onDisappear {
            stopAnimations()
        }
        .gesture(
            isInteractive ? dragGesture : nil
        )
        .accessibilityElement(children: .contain)
    }
    
    // MARK: - View Components
    
    private var backgroundLayers: some View {
        ZStack {
            // Base blur effect
            cardShape
                .fill(baseBackgroundColor)
                .background(
                    cardShape
                        .fill(backgroundGradient)
                )
                .blur(radius: variant.blurRadius * intensity)
            
            // Depth layers
            ForEach(0..<variant.depthLayers, id: \.self) { index in
                cardShape
                    .fill(depthLayerColor(for: index))
                    .offset(depthLayerOffset(for: index))
                    .blur(radius: depthLayerBlur(for: index))
            }
            
            // Ambient occlusion layer
            cardShape
                .fill(ambientOcclusionGradient)
                .opacity(0.1 * intensity)
        }
    }
    
    private var glassSurface: some View {
        ZStack {
            cardShape
                .fill(surfaceGradient)
                .overlay(
                    // Surface highlights
                    cardShape
                        .fill(surfaceHighlightGradient)
                        .opacity(surfaceHighlightOpacity)
                )
                .overlay(
                    // Border
                    cardShape
                        .stroke(borderGradient, lineWidth: variant.borderWidth)
                )
                .shadow(
                    color: shadowColor,
                    radius: shadowRadius,
                    x: shadowOffset.width,
                    y: shadowOffset.height
                )
            
            // Reflection layer
            cardShape
                .fill(reflectionGradient)
                .opacity(reflectionOpacity)
                .mask(reflectionMask)
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
            case .morphing:
                morphingEffect
            case .breathing:
                breathingEffect
            case .none:
                EmptyView()
            default:
                EmptyView()
            }
        }
    }
    
    private var interactiveEffects: some View {
        ZStack {
            cardShape
                .fill(interactiveOverlay)
                .opacity(interactiveOpacity)
                .animation(.easeInOut(duration: 0.2), value: isHovered)
            
            // Hover glow
            if isHovered {
                cardShape
                    .fill(hoverGlowGradient)
                    .opacity(0.2 * intensity)
                    .blur(radius: 10)
            }
        }
    }
    
    // MARK: - Shape Components
    
    private var cardShape: some Shape {
        switch cornerStyle {
        case .rounded:
            return RoundedRectangle(cornerRadius: variant.cornerRadius)
        case .circular:
            return Circle()
        case .capsule:
            return Capsule()
        case .custom(let radius):
            return RoundedRectangle(cornerRadius: radius)
        case .asymmetric(let topLeft, let topRight, let bottomLeft, let bottomRight):
            return AsymmetricRoundedRectangle(
                topLeading: topLeft,
                bottomLeading: bottomLeft,
                topTrailing: topRight,
                bottomTrailing: bottomRight
            )
        }
    }
    
    private var reflectionMask: some Shape {
        RoundedRectangle(cornerRadius: variant.cornerRadius)
            .path(in: CGRect(x: 0, y: 0, width: 200, height: 100))
            .offset(y: -50)
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
            LiquidGlassColors.surfaceReflection.opacity(0.4 * intensity),
            LiquidGlassColors.surfaceReflection.opacity(0.2 * intensity),
            LiquidGlassColors.surfaceReflection.opacity(0.1 * intensity)
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
    
    private var ambientOcclusionGradient: RadialGradient {
        return RadialGradient(
            colors: [
                .black.opacity(0),
                .black.opacity(0.2),
                .black.opacity(0.4)
            ],
            center: .center,
            startRadius: 50,
            endRadius: 200
        )
    }
    
    private var reflectionGradient: LinearGradient {
        let colors = [
            .white.opacity(0.3),
            .white.opacity(0.1),
            .white.opacity(0)
        ]
        
        return LinearGradient(
            colors: colors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    private var shimmerGradient: LinearGradient {
        let colors = [
            LiquidGlassColors.shimmer.opacity(0),
            LiquidGlassColors.shimmerBright.opacity(0.5 * intensity),
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
                pulseColor.opacity(0.15 * intensity),
                pulseColor.opacity(0.08 * intensity),
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
                glowColor.opacity(0.4 * intensity),
                glowColor.opacity(0.2 * intensity),
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
                waveColor.opacity(0.25 * intensity),
                waveColor.opacity(0.15 * intensity),
                waveColor.opacity(0.08 * intensity)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
    
    private var morphingGradient: LinearGradient {
        let morphColor = palette?.accentColor ?? .blue
        
        return LinearGradient(
            colors: [
                morphColor.opacity(0.2 * intensity),
                morphColor.opacity(0.1 * intensity),
                morphColor.opacity(0.05 * intensity)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    private var breathingGradient: LinearGradient {
        let breathingColor = palette?.baseColor ?? .white
        
        return LinearGradient(
            colors: [
                breathingColor.opacity(0.12 * intensity),
                breathingColor.opacity(0.06 * intensity),
                breathingColor.opacity(0.03 * intensity)
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
                glowColor.opacity(0.6),
                glowColor.opacity(0.3),
                glowColor.opacity(0)
            ],
            center: .center,
            startRadius: 10,
            endRadius: 100
        )
    }
    
    private var shadowColor: Color {
        switch shadowStyle {
        case .subtle:
            return LiquidGlassColors.glassShadow.opacity(0.15 * shadowOpacity)
        case .elevated:
            return LiquidGlassColors.glassShadow.opacity(0.3 * shadowOpacity)
        case .dramatic:
            return LiquidGlassColors.glassShadow.opacity(0.5 * shadowOpacity)
        case .floating:
            return LiquidGlassColors.glassShadow.opacity(0.4 * shadowOpacity)
        }
    }
    
    // MARK: - Animation Components
    
    private var shimmerEffect: some View {
        cardShape
            .fill(shimmerGradient)
            .offset(animationOffset)
            .rotationEffect(.degrees(shimmerRotation))
            .mask(cardShape)
    }
    
    private var pulseEffect: some View {
        cardShape
            .fill(pulseGradient)
            .scaleEffect(pulseScale)
            .opacity(pulseOpacity)
            .mask(cardShape)
    }
    
    private var glowEffect: some View {
        cardShape
            .fill(glowGradient)
            .opacity(glowIntensity)
            .blur(radius: glowBlurRadius)
            .mask(cardShape)
    }
    
    private var waveEffect: some View {
        cardShape
            .fill(waveGradient)
            .opacity(waveOpacity)
            .mask(
                cardShape
                    .offset(x: sin(wavePhase) * 10, y: cos(wavePhase) * 5)
            )
    }
    
    private var morphingEffect: some View {
        cardShape
            .fill(morphingGradient)
            .scaleEffect(1.0 + sin(wavePhase) * 0.05)
            .mask(cardShape)
    }
    
    private var breathingEffect: some View {
        cardShape
            .fill(breathingGradient)
            .scaleEffect(1.0 + sin(wavePhase) * 0.03)
            .opacity(0.8 + sin(wavePhase) * 0.2)
            .mask(cardShape)
    }
    
    // MARK: - Gesture Handling
    
    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                handleDragChanged(value)
            }
            .onEnded { _ in
                handleDragEnded()
            }
    }
    
    private func handleDragChanged(_ value: DragGesture.Value) {
        isPressed = true
        isHovered = true
        
        // Calculate rotation based on drag position
        let rotationAmount = value.translation.x * 0.1
        cardRotation = rotationAmount
        
        // Calculate depth offset
        let depthAmount = value.translation.y * 0.05
        depthOffset = depthAmount
        
        // Update shadow opacity based on depth
        shadowOpacity = 0.3 + (depthOffset / 100)
        
        HapticFeedbackManager.shared.lightImpact()
    }
    
    private func handleDragEnded() {
        isPressed = false
        isHovered = false
        
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            cardRotation = 0
            depthOffset = 0
            shadowOpacity = 0.3
        }
    }
    
    // MARK: - Helper Methods
    
    private func depthLayerColor(for index: Int) -> Color {
        let depth = GlassDepth.allCases[index % GlassDepth.allCases.count]
        let baseColor = palette?.tints[index % (palette?.tints.count ?? 1)].color ?? .white
        return baseColor.opacity(depth.opacity * intensity)
    }
    
    private func depthLayerOffset(for index: Int) -> CGSize {
        let offset: CGFloat = CGFloat(index + 1) * 2
        return CGSize(width: offset, height: offset)
    }
    
    private func depthLayerBlur(for index: Int) -> CGFloat {
        return CGFloat(index + 1) * 2
    }
    
    private var surfaceHighlightOpacity: Double {
        0.4 * intensity
    }
    
    private var reflectionOpacity: Double {
        0.3 * intensity
    }
    
    private var pulseOpacity: Double {
        0.25 * intensity
    }
    
    private var glowBlurRadius: CGFloat {
        25 * intensity
    }
    
    private var waveOpacity: Double {
        0.2 * intensity
    }
    
    private var interactiveOpacity: Double {
        if isPressed {
            return 0.2
        } else if isHovered {
            return 0.1
        } else {
            return 0
        }
    }
    
    private var shadowRadius: CGFloat {
        switch shadowStyle {
        case .subtle:
            return 8 * intensity
        case .elevated:
            return 12 * intensity
        case .dramatic:
            return 20 * intensity
        case .floating:
            return 16 * intensity
        }
    }
    
    private var shadowOffset: CGSize {
        switch shadowStyle {
        case .subtle:
            return CGSize(width: 0, height: 2)
        case .elevated:
            return CGSize(width: 0, height: 4)
        case .dramatic:
            return CGSize(width: 0, height: 8)
        case .floating:
            return CGSize(width: 0, height: 6)
        }
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
        case .morphing:
            startMorphingAnimation()
        case .breathing:
            startBreathingAnimation()
        case .none:
            break
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
            animationOffset = CGSize(width: 50, height: 50)
            shimmerRotation = 45
        }
    }
    
    private func startPulseAnimation() {
        withAnimation(
            .easeInOut(duration: variant.animationDuration)
            .repeatForever(autoreverses: true)
        ) {
            pulseScale = 1.03
        }
    }
    
    private func startGlowAnimation() {
        withAnimation(
            .easeInOut(duration: variant.animationDuration * 1.5)
            .repeatForever(autoreverses: true)
        ) {
            glowIntensity = 0.5
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
    
    private func startMorphingAnimation() {
        withAnimation(
            .easeInOut(duration: variant.animationDuration * 2)
            .repeatForever(autoreverses: true)
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
}

// MARK: - Glass Card Variant

enum GlassCardVariant: CaseIterable {
    case minimal
    case standard
    case elevated
    case floating
    case immersive
    case dramatic
    
    var cornerRadius: CGFloat {
        switch self {
        case .minimal:
            return 8
        case .standard:
            return 12
        case .elevated:
            return 16
        case .floating:
            return 20
        case .immersive:
            return 24
        case .dramatic:
            return 32
        }
    }
    
    var blurRadius: CGFloat {
        switch self {
        case .minimal:
            return 4
        case .standard:
            return 8
        case .elevated:
            return 12
        case .floating:
            return 16
        case .immersive:
            return 20
        case .dramatic:
            return 25
        }
    }
    
    var borderWidth: CGFloat {
        switch self {
        case .minimal:
            return 0.5
        case .standard:
            return 1
        case .elevated:
            return 1.5
        case .floating:
            return 2
        case .immersive:
            return 2.5
        case .dramatic:
            return 3
        }
    }
    
    var padding: EdgeInsets {
        switch self {
        case .minimal:
            return EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16)
        case .standard:
            return EdgeInsets(top: 16, leading: 20, bottom: 16, trailing: 20)
        case .elevated:
            return EdgeInsets(top: 20, leading: 24, bottom: 20, trailing: 24)
        case .floating:
            return EdgeInsets(top: 24, leading: 28, bottom: 24, trailing: 28)
        case .immersive:
            return EdgeInsets(top: 28, leading: 32, bottom: 28, trailing: 32)
        case .dramatic:
            return EdgeInsets(top: 32, leading: 36, bottom: 32, trailing: 36)
        }
    }
    
    var animationDuration: Double {
        switch self {
        case .minimal:
            return 2.5
        case .standard:
            return 3.0
        case .elevated:
            return 3.5
        case .floating:
            return 4.0
        case .immersive:
            return 4.5
        case .dramatic:
            return 5.0
        }
    }
    
    var depthLayers: Int {
        switch self {
        case .minimal:
            return 1
        case .standard:
            return 2
        case .elevated:
            return 3
        case .floating:
            return 4
        case .immersive:
            return 5
        case .dramatic:
            return 6
        }
    }
    
    var name: String {
        switch self {
        case .minimal:
            return "Minimal"
        case .standard:
            return "Standard"
        case .elevated:
            return "Elevated"
        case .floating:
            return "Floating"
        case .immersive:
            return "Immersive"
        case .dramatic:
            return "Dramatic"
        }
    }
}

// MARK: - Glass Card Shadow Style

enum GlassCardShadowStyle: CaseIterable {
    case subtle
    case elevated
    case dramatic
    case floating
    
    var name: String {
        switch self {
        case .subtle:
            return "Subtle"
        case .elevated:
            return "Elevated"
        case .dramatic:
            return "Dramatic"
        case .floating:
            return "Floating"
        }
    }
}

// MARK: - Glass Card Corner Style

enum GlassCardCornerStyle: Equatable {
    case rounded
    case circular
    case capsule
    case custom(CGFloat)
    case asymmetric(topLeading: CGFloat, topTrailing: CGFloat, bottomLeading: CGFloat, bottomTrailing: CGFloat)
}

// MARK: - Asymmetric Rounded Rectangle

struct AsymmetricRoundedRectangle: Shape {
    let topLeading: CGFloat
    let bottomLeading: CGFloat
    let topTrailing: CGFloat
    let bottomTrailing: CGFloat
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        let width = rect.width
        let height = rect.height
        
        // Start from top-left corner
        path.move(to: CGPoint(x: topLeading, y: 0))
        
        // Top edge to top-right corner
        path.addLine(to: CGPoint(x: width - topTrailing, y: 0))
        
        // Top-right corner
        path.addArc(
            center: CGPoint(x: width - topTrailing, y: topTrailing),
            radius: topTrailing,
            startAngle: .degrees(-90),
            endAngle: .degrees(0),
            clockwise: false
        )
        
        // Right edge to bottom-right corner
        path.addLine(to: CGPoint(x: width, y: height - bottomTrailing))
        
        // Bottom-right corner
        path.addArc(
            center: CGPoint(x: width - bottomTrailing, y: height - bottomTrailing),
            radius: bottomTrailing,
            startAngle: .degrees(0),
            endAngle: .degrees(90),
            clockwise: false
        )
        
        // Bottom edge to bottom-left corner
        path.addLine(to: CGPoint(x: bottomLeading, y: height))
        
        // Bottom-left corner
        path.addArc(
            center: CGPoint(x: bottomLeading, y: height - bottomLeading),
            radius: bottomLeading,
            startAngle: .degrees(90),
            endAngle: .degrees(180),
            clockwise: false
        )
        
        // Left edge to top-left corner
        path.addLine(to: CGPoint(x: 0, y: topLeading))
        
        // Top-left corner
        path.addArc(
            center: CGPoint(x: topLeading, y: topLeading),
            radius: topLeading,
            startAngle: .degrees(180),
            endAngle: .degrees(270),
            clockwise: false
        )
        
        return path
    }
}

// MARK: - Preview

#Preview {
    ScrollView {
        VStack(spacing: 20) {
            // Basic examples
            GlassCard(variant: .minimal, intensity: 0.7) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Minimal Card")
                        .textStyle(TypographyPresets.Glass.title)
                    Text("Clean and simple design with subtle glass effects")
                        .textStyle(TypographyPresets.Glass.body)
                }
            }
            
            GlassCard(variant: .standard, intensity: 0.5) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Standard Card")
                        .textStyle(TypographyPresets.Glass.title)
                    Text("Balanced glass effect with good visibility")
                        .textStyle(TypographyPresets.Glass.body)
                }
            }
            
            // Animation examples
            GlassCard(
                variant: .elevated,
                intensity: 0.6,
                animationType: .shimmer
            ) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Shimmer Effect")
                        .textStyle(TypographyPresets.Glass.title)
                    Text("Animated shimmer effect for visual interest")
                        .textStyle(TypographyPresets.Glass.body)
                }
            }
            
            GlassCard(
                variant: .floating,
                intensity: 0.6,
                animationType: .pulse
            ) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Pulse Effect")
                        .textStyle(TypographyPresets.Glass.title)
                    Text("Gentle pulsing animation for attention")
                        .textStyle(TypographyPresets.Glass.body)
                }
            }
            
            // Interactive example
            GlassCard(
                variant: .elevated,
                intensity: 0.7,
                animationType: .glow,
                isInteractive: true
            ) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Interactive Card")
                        .textStyle(TypographyPresets.Glass.title)
                    Text("Drag to see depth and rotation effects")
                        .textStyle(TypographyPresets.Glass.body)
                }
            }
            
            // Palette examples
            GlassCard(
                variant: .immersive,
                intensity: 0.8,
                palette: .ocean,
                animationType: .wave
            ) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Ocean Theme")
                        .textStyle(TypographyPresets.Glass.title)
                    Text("Immersive ocean palette with wave animation")
                        .textStyle(TypographyPresets.Glass.body)
                }
            }
            
            GlassCard(
                variant: .dramatic,
                intensity: 0.9,
                palette: .sunset,
                animationType: .morphing
            ) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Dramatic Sunset")
                        .textStyle(TypographyPresets.Glass.title)
                    Text("Maximum impact with morphing effects")
                        .textStyle(TypographyPresets.Glass.body)
                }
            }
        }
        .padding()
    }
    .background(DesignColors.background)
}