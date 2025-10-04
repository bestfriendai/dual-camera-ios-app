//
//  GlassContainerView.swift
//  DualApp
//
//  Created by DualApp Team on 10/3/25.
//

import SwiftUI

// MARK: - Glass Container View

struct GlassContainerView<Content: View>: View {
    // MARK: - Properties
    
    let content: Content
    let variant: GlassContainerVariant
    let intensity: Double
    let palette: LiquidGlassPalette?
    let animationType: LiquidGlassAnimationType
    let cornerStyle: GlassCornerStyle
    let shadowStyle: GlassShadowStyle
    
    // MARK: - State
    
    @State private var animationOffset: CGSize = .zero
    @State private var isAnimating = false
    @State private var shimmerRotation: Double = 0
    @State private var pulseScale: CGFloat = 1.0
    @State private var glowIntensity: Double = 0.2
    @State private var wavePhase: Double = 0
    @State private var isHovered = false
    @State private var isPressed = false
    @State private var morphProgress: Double = 0.0
    
    // MARK: - Initialization
    
    init(
        variant: GlassContainerVariant = .standard,
        intensity: Double = 0.5,
        palette: LiquidGlassPalette? = nil,
        animationType: LiquidGlassAnimationType = .shimmer,
        cornerStyle: GlassCornerStyle = .rounded,
        shadowStyle: GlassShadowStyle = .elevated,
        @ViewBuilder content: () -> Content
    ) {
        self.variant = variant
        self.intensity = intensity
        self.palette = palette
        self.animationType = animationType
        self.cornerStyle = cornerStyle
        self.shadowStyle = shadowStyle
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
            interactiveEffects
            
            // Content
            content
                .padding(variant.padding)
                .scaleEffect(isPressed ? 0.98 : 1.0)
                .animation(.easeInOut(duration: 0.1), value: isPressed)
        }
        .onAppear {
            setupInitialState()
            startAnimations()
        }
        .onDisappear {
            stopAnimations()
        }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isPressed {
                        isPressed = true
                        HapticFeedbackManager.shared.lightImpact()
                    }
                }
                .onEnded { _ in
                    isPressed = false
                }
        )
        .accessibilityElement(children: .contain)
    }
    
    // MARK: - View Components
    
    private var backgroundLayers: some View {
        ZStack {
            // Base blur effect
            backgroundShape
                .fill(baseBackgroundColor)
                .background(
                    backgroundShape
                        .fill(backgroundGradient)
                )
                .blur(radius: variant.blurRadius * intensity)
            
            // Depth layers
            ForEach(0..<variant.depthLayers, id: \.self) { index in
                backgroundShape
                    .fill(depthLayerColor(for: index))
                    .offset(depthLayerOffset(for: index))
                    .blur(radius: depthLayerBlur(for: index))
            }
        }
    }
    
    private var glassSurface: some View {
        backgroundShape
            .fill(surfaceGradient)
            .overlay(
                // Surface highlights
                backgroundShape
                    .fill(surfaceHighlightGradient)
                    .opacity(surfaceHighlightOpacity)
            )
            .overlay(
                // Border
                backgroundShape
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
        backgroundShape
            .fill(interactiveOverlay)
            .opacity(isHovered ? 0.1 : 0)
            .animation(.easeInOut(duration: 0.2), value: isHovered)
    }
    
    // MARK: - Animation Components
    
    private var shimmerEffect: some View {
        backgroundShape
            .fill(shimmerGradient)
            .offset(animationOffset)
            .rotationEffect(.degrees(shimmerRotation))
            .mask(backgroundShape)
    }
    
    private var pulseEffect: some View {
        backgroundShape
            .fill(pulseGradient)
            .scaleEffect(pulseScale)
            .opacity(pulseOpacity)
            .mask(backgroundShape)
    }
    
    private var glowEffect: some View {
        backgroundShape
            .fill(glowGradient)
            .opacity(glowIntensity)
            .blur(radius: glowBlurRadius)
            .mask(backgroundShape)
    }
    
    private var waveEffect: some View {
        backgroundShape
            .fill(waveGradient)
            .opacity(waveOpacity)
            .mask(
                backgroundShape
                    .offset(x: sin(wavePhase) * 10, y: cos(wavePhase) * 5)
            )
    }
    
    private var morphingEffect: some View {
        backgroundShape
            .fill(morphingGradient)
            .scaleEffect(1.0 + morphProgress * 0.1)
            .mask(morphingShape)
    }
    
    private var breathingEffect: some View {
        backgroundShape
            .fill(breathingGradient)
            .scaleEffect(1.0 + sin(wavePhase) * 0.05)
            .opacity(0.8 + sin(wavePhase) * 0.2)
            .mask(backgroundShape)
    }
    
    // MARK: - Shape Components
    
    private var backgroundShape: some Shape {
        switch cornerStyle {
        case .rounded:
            return RoundedRectangle(cornerRadius: variant.cornerRadius)
        case .circular:
            return Circle()
        case .capsule:
            return Capsule()
        case .custom(let radius):
            return RoundedRectangle(cornerRadius: radius)
        }
    }
    
    private var morphingShape: some Shape {
        MorphingShape(progress: morphProgress)
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
        let accentColor = palette?.accentColor ?? LiquidGlassColors.glassBorder
        
        let colors = [
            accentColor.opacity(0.3 * intensity),
            accentColor.opacity(0.1 * intensity),
            accentColor.opacity(0.3 * intensity)
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
                glowColor.opacity(0.4 * intensity),
                glowColor.opacity(0.2 * intensity),
                glowColor.opacity(0)
            ],
            center: .center,
            startRadius: 10,
            endRadius: 100
        )
    }
    
    private var waveGradient: LinearGradient {
        let waveColor = palette?.baseColor ?? LiquidGlassColors.waveOverlay
        
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
                breathingColor.opacity(0.1 * intensity),
                breathingColor.opacity(0.05 * intensity),
                breathingColor.opacity(0.02 * intensity)
            ],
            startPoint: .center,
            endPoint: .edge
        )
    }
    
    private var interactiveOverlay: Color {
        palette?.accentColor ?? .white
    }
    
    private var shadowColor: Color {
        switch shadowStyle {
        case .elevated:
            return LiquidGlassColors.glassShadow.opacity(0.3 * intensity)
        case .subtle:
            return LiquidGlassColors.glassShadow.opacity(0.15 * intensity)
        case .dramatic:
            return LiquidGlassColors.glassShadow.opacity(0.4 * intensity)
        case .none:
            return .clear
        }
    }
    
    private var shadowRadius: CGFloat {
        switch shadowStyle {
        case .elevated:
            return 8 * intensity
        case .subtle:
            return 4 * intensity
        case .dramatic:
            return 16 * intensity
        case .none:
            return 0
        }
    }
    
    private var shadowOffset: CGSize {
        switch shadowStyle {
        case .elevated:
            return CGSize(width: 0, height: 4)
        case .subtle:
            return CGSize(width: 0, height: 2)
        case .dramatic:
            return CGSize(width: 0, height: 8)
        case .none:
            return .zero
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
        0.3 * intensity
    }
    
    private var pulseOpacity: Double {
        0.2 * intensity
    }
    
    private var glowBlurRadius: CGFloat {
        20 * intensity
    }
    
    private var waveOpacity: Double {
        0.15 * intensity
    }
    
    // MARK: - Animation Methods
    
    private func setupInitialState() {
        // Initialize animation state
        morphProgress = 0.0
    }
    
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
            animationOffset = CGSize(width: 30, height: 30)
            shimmerRotation = 45
        }
    }
    
    private func startPulseAnimation() {
        withAnimation(
            .easeInOut(duration: variant.animationDuration)
            .repeatForever(autoreverses: true)
        ) {
            pulseScale = 1.05
        }
    }
    
    private func startGlowAnimation() {
        withAnimation(
            .easeInOut(duration: variant.animationDuration * 1.5)
            .repeatForever(autoreverses: true)
        ) {
            glowIntensity = 0.4
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
            morphProgress = 1.0
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

// MARK: - Glass Container Variant

enum GlassContainerVariant: CaseIterable {
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
            return 16
        case .elevated:
            return 20
        case .floating:
            return 24
        case .immersive:
            return 32
        case .dramatic:
            return 40
        }
    }
    
    var blurRadius: CGFloat {
        switch self {
        case .minimal:
            return 4
        case .standard:
            return 10
        case .elevated:
            return 15
        case .floating:
            return 20
        case .immersive:
            return 25
        case .dramatic:
            return 30
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
            return EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12)
        case .standard:
            return EdgeInsets(top: 16, leading: 20, bottom: 16, trailing: 20)
        case .elevated:
            return EdgeInsets(top: 20, leading: 24, bottom: 20, trailing: 24)
        case .floating:
            return EdgeInsets(top: 24, leading: 28, bottom: 24, trailing: 28)
        case .immersive:
            return EdgeInsets(top: 32, leading: 36, bottom: 32, trailing: 36)
        case .dramatic:
            return EdgeInsets(top: 40, leading: 44, bottom: 40, trailing: 44)
        }
    }
    
    var animationDuration: Double {
        switch self {
        case .minimal:
            return 2.0
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

// MARK: - Glass Corner Style

enum GlassCornerStyle: Equatable {
    case rounded
    case circular
    case capsule
    case custom(CGFloat)
}

// MARK: - Glass Shadow Style

enum GlassShadowStyle: CaseIterable {
    case none
    case subtle
    case elevated
    case dramatic
    
    var name: String {
        switch self {
        case .none:
            return "None"
        case .subtle:
            return "Subtle"
        case .elevated:
            return "Elevated"
        case .dramatic:
            return "Dramatic"
        }
    }
}

// MARK: - Morphing Shape

struct MorphingShape: Shape {
    let progress: Double
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        let cornerRadius: CGFloat = 16 + sin(progress * .pi * 2) * 8
        let morphFactor: CGFloat = sin(progress * .pi * 2) * 0.1
        
        // Create a morphing rounded rectangle
        let width = rect.width * (1 + morphFactor)
        let height = rect.height * (1 - morphFactor)
        let x = (rect.width - width) / 2
        let y = (rect.height - height) / 2
        
        path.addRoundedRect(
            in: CGRect(x: x, y: y, width: width, height: height),
            cornerSize: CGSize(width: cornerRadius, height: cornerRadius)
        )
        
        return path
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        // Basic examples
        GlassContainerView(variant: .minimal, intensity: 0.7) {
            Text("Minimal Container")
                .textStyle(TypographyPresets.Glass.title)
        }
        
        GlassContainerView(variant: .standard, intensity: 0.5) {
            Text("Standard Container")
                .textStyle(TypographyPresets.Glass.subtitle)
        }
        
        // Animation examples
        GlassContainerView(
            variant: .elevated,
            intensity: 0.6,
            animationType: .shimmer
        ) {
            Text("Shimmer Effect")
                .textStyle(TypographyPresets.Glass.body)
        }
        
        GlassContainerView(
            variant: .floating,
            intensity: 0.6,
            animationType: .pulse
        ) {
            Text("Pulse Effect")
                .textStyle(TypographyPresets.Glass.body)
        }
        
        GlassContainerView(
            variant: .immersive,
            intensity: 0.8,
            palette: .ocean,
            animationType: .wave
        ) {
            VStack {
                Text("Ocean Palette")
                    .textStyle(TypographyPresets.Glass.title)
                Text("With wave animation")
                    .textStyle(TypographyPresets.Glass.caption)
            }
        }
        
        GlassContainerView(
            variant: .dramatic,
            intensity: 0.9,
            palette: .sunset,
            animationType: .morphing
        ) {
            VStack {
                Text("Dramatic Morphing")
                    .textStyle(TypographyPresets.Glass.title)
                Text("Maximum impact")
                    .textStyle(TypographyPresets.Glass.caption)
            }
        }
    }
    .padding()
    .background(DesignColors.background)
}