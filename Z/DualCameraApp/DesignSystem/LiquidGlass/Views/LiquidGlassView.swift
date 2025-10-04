//
//  LiquidGlassView.swift
//  DualApp
//
//  Created by DualApp Team on 10/3/25.
//

import SwiftUI

// MARK: - Liquid Glass View

struct LiquidGlassView<Content: View>: View {
    // MARK: - Properties
    
    let content: Content
    let style: LiquidGlassStyle
    let intensity: Double
    let palette: LiquidGlassPalette?
    let animationType: LiquidGlassAnimationType
    
    // MARK: - State
    
    @State private var animationOffset: CGSize = .zero
    @State private var isAnimating = false
    @State private var shimmerRotation: Double = 0
    @State private var pulseScale: CGFloat = 1.0
    @State private var glowIntensity: Double = 0.2
    @State private var wavePhase: Double = 0
    @State private var particlePositions: [CGPoint] = []
    @State private var isHovered = false
    @State private var isPressed = false
    
    // MARK: - Initialization
    
    init(
        style: LiquidGlassStyle = .default,
        intensity: Double = 0.5,
        palette: LiquidGlassPalette? = nil,
        animationType: LiquidGlassAnimationType = .shimmer,
        @ViewBuilder content: () -> Content
    ) {
        self.style = style
        self.intensity = intensity
        self.palette = palette
        self.animationType = animationType
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
            
            // Particle effects
            if animationType == .particles {
                particleEffects
            }
            
            // Content
            content
                .padding(style.padding)
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
    }
    
    // MARK: - View Components
    
    private var backgroundLayers: some View {
        ZStack {
            // Base blur effect
            RoundedRectangle(cornerRadius: style.cornerRadius)
                .fill(baseBackgroundColor)
                .background(
                    RoundedRectangle(cornerRadius: style.cornerRadius)
                        .fill(backgroundGradient)
                )
                .blur(radius: style.blurRadius * intensity)
            
            // Depth layers
            ForEach(0..<3, id: \.self) { index in
                RoundedRectangle(cornerRadius: style.cornerRadius)
                    .fill(depthLayerColor(for: index))
                    .offset(depthLayerOffset(for: index))
                    .blur(radius: depthLayerBlur(for: index))
            }
        }
    }
    
    private var glassSurface: some View {
        RoundedRectangle(cornerRadius: style.cornerRadius)
            .fill(surfaceGradient)
            .overlay(
                // Surface highlights
                RoundedRectangle(cornerRadius: style.cornerRadius)
                    .fill(surfaceHighlightGradient)
                    .opacity(surfaceHighlightOpacity)
            )
            .overlay(
                // Border
                RoundedRectangle(cornerRadius: style.cornerRadius)
                    .stroke(borderGradient, lineWidth: style.borderWidth)
            )
            .shadow(
                color: shadowColor,
                radius: style.shadowRadius,
                x: style.shadowOffset.width,
                y: style.shadowOffset.height
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
            case .none:
                EmptyView()
            default:
                EmptyView()
            }
        }
    }
    
    private var interactiveEffects: some View {
        RoundedRectangle(cornerRadius: style.cornerRadius)
            .fill(interactiveOverlay)
            .opacity(isHovered ? 0.1 : 0)
            .animation(.easeInOut(duration: 0.2), value: isHovered)
    }
    
    private var particleEffects: some View {
        ZStack {
            ForEach(Array(particlePositions.enumerated()), id: \.offset) { index, position in
                Circle()
                    .fill(particleColor(for: index))
                    .frame(width: particleSize(for: index), height: particleSize(for: index))
                    .position(position)
                    .opacity(particleOpacity(for: index))
            }
        }
        .mask(
            RoundedRectangle(cornerRadius: style.cornerRadius)
        )
    }
    
    // MARK: - Animation Components
    
    private var shimmerEffect: some View {
        RoundedRectangle(cornerRadius: style.cornerRadius)
            .fill(shimmerGradient)
            .offset(animationOffset)
            .rotationEffect(.degrees(shimmerRotation))
            .mask(
                RoundedRectangle(cornerRadius: style.cornerRadius)
            )
    }
    
    private var pulseEffect: some View {
        RoundedRectangle(cornerRadius: style.cornerRadius)
            .fill(pulseGradient)
            .scaleEffect(pulseScale)
            .opacity(pulseOpacity)
            .mask(
                RoundedRectangle(cornerRadius: style.cornerRadius)
            )
    }
    
    private var glowEffect: some View {
        RoundedRectangle(cornerRadius: style.cornerRadius)
            .fill(glowGradient)
            .opacity(glowIntensity)
            .blur(radius: glowBlurRadius)
            .mask(
                RoundedRectangle(cornerRadius: style.cornerRadius)
            )
    }
    
    private var waveEffect: some View {
        RoundedRectangle(cornerRadius: style.cornerRadius)
            .fill(waveGradient)
            .opacity(waveOpacity)
            .mask(
                RoundedRectangle(cornerRadius: style.cornerRadius)
                    .offset(x: sin(wavePhase) * 10, y: cos(wavePhase) * 5)
            )
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
    
    private var shadowColor: Color {
        LiquidGlassColors.glassShadow.opacity(0.2 * intensity)
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
    
    private var interactiveOverlay: Color {
        palette?.accentColor ?? .white
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
    
    private func particleColor(for index: Int) -> Color {
        let tints = palette?.tints ?? [.clear]
        let tint = tints[index % tints.count]
        return tint.color
    }
    
    private func particleSize(for index: Int) -> CGFloat {
        return CGFloat.random(in: 2...6)
    }
    
    private func particleOpacity(for index: Int) -> Double {
        return Double.random(in: 0.3...0.8) * intensity
    }
    
    // MARK: - Animation Methods
    
    private func setupInitialState() {
        // Initialize particle positions
        if animationType == .particles {
            particlePositions = (0..<20).map { _ in
                CGPoint(
                    x: CGFloat.random(in: -100...100),
                    y: CGFloat.random(in: -100...100)
                )
            }
        }
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
        case .particles:
            startParticleAnimation()
        case .none:
            break
        }
    }
    
    private func stopAnimations() {
        isAnimating = false
    }
    
    private func startShimmerAnimation() {
        withAnimation(
            .easeInOut(duration: style.animationDuration)
            .repeatForever(autoreverses: true)
        ) {
            animationOffset = CGSize(width: 30, height: 30)
            shimmerRotation = 45
        }
    }
    
    private func startPulseAnimation() {
        withAnimation(
            .easeInOut(duration: style.animationDuration)
            .repeatForever(autoreverses: true)
        ) {
            pulseScale = 1.05
        }
    }
    
    private func startGlowAnimation() {
        withAnimation(
            .easeInOut(duration: style.animationDuration * 1.5)
            .repeatForever(autoreverses: true)
        ) {
            glowIntensity = 0.4
        }
    }
    
    private func startWaveAnimation() {
        withAnimation(
            .linear(duration: style.animationDuration)
            .repeatForever(autoreverses: false)
        ) {
            wavePhase = 2 * .pi
        }
    }
    
    private func startParticleAnimation() {
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            guard isAnimating else { return }
            
            particlePositions = particlePositions.map { position in
                CGPoint(
                    x: position.x + CGFloat.random(in: -2...2),
                    y: position.y + CGFloat.random(in: -2...2)
                )
            }
        }
    }
}

// MARK: - Liquid Glass Style

struct LiquidGlassStyle {
    let cornerRadius: CGFloat
    let blurRadius: CGFloat
    let borderWidth: CGFloat
    let shadowRadius: CGFloat
    let shadowOffset: CGSize
    let padding: EdgeInsets
    let animationDuration: Double
    let elasticity: Double
    let responsiveness: Double
    
    static let `default` = LiquidGlassStyle(
        cornerRadius: 16,
        blurRadius: 10,
        borderWidth: 1,
        shadowRadius: 8,
        shadowOffset: CGSize(width: 0, height: 4),
        padding: EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16),
        animationDuration: 3.0,
        elasticity: 0.8,
        responsiveness: 0.6
    )
    
    static let card = LiquidGlassStyle(
        cornerRadius: 12,
        blurRadius: 8,
        borderWidth: 0.5,
        shadowRadius: 6,
        shadowOffset: CGSize(width: 0, height: 2),
        padding: EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12),
        animationDuration: 2.5,
        elasticity: 0.7,
        responsiveness: 0.5
    )
    
    static let button = LiquidGlassStyle(
        cornerRadius: 8,
        blurRadius: 6,
        borderWidth: 0.5,
        shadowRadius: 4,
        shadowOffset: CGSize(width: 0, height: 2),
        padding: EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16),
        animationDuration: 2.0,
        elasticity: 0.9,
        responsiveness: 0.8
    )
    
    static let container = LiquidGlassStyle(
        cornerRadius: 24,
        blurRadius: 15,
        borderWidth: 1,
        shadowRadius: 12,
        shadowOffset: CGSize(width: 0, height: 6),
        padding: EdgeInsets(top: 24, leading: 24, bottom: 24, trailing: 24),
        animationDuration: 4.0,
        elasticity: 0.6,
        responsiveness: 0.4
    )
    
    static let minimal = LiquidGlassStyle(
        cornerRadius: 6,
        blurRadius: 4,
        borderWidth: 0.25,
        shadowRadius: 2,
        shadowOffset: CGSize(width: 0, height: 1),
        padding: EdgeInsets(top: 6, leading: 8, bottom: 6, trailing: 8),
        animationDuration: 1.5,
        elasticity: 0.5,
        responsiveness: 0.3
    )
    
    static let dramatic = LiquidGlassStyle(
        cornerRadius: 32,
        blurRadius: 20,
        borderWidth: 2,
        shadowRadius: 16,
        shadowOffset: CGSize(width: 0, height: 8),
        padding: EdgeInsets(top: 32, leading: 32, bottom: 32, trailing: 32),
        animationDuration: 5.0,
        elasticity: 1.0,
        responsiveness: 0.9
    )
}

// MARK: - Liquid Glass Animation Type

enum LiquidGlassAnimationType: CaseIterable {
    case none
    case shimmer
    case pulse
    case glow
    case wave
    case particles
    case morphing
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
        case .particles:
            return "Particles"
        case .morphing:
            return "Morphing"
        case .breathing:
            return "Breathing"
        }
    }
    
    var description: String {
        switch self {
        case .none:
            return "No animation"
        case .shimmer:
            return "Subtle light shimmer effect"
        case .pulse:
            return "Gentle pulsing animation"
        case .glow:
            return "Soft glow effect"
        case .wave:
            return "Flowing wave animation"
        case .particles:
            return "Floating particle effects"
        case .morphing:
            return "Shape morphing animation"
        case .breathing:
            return "Natural breathing effect"
        }
    }
}

// MARK: - Convenience Initializers

extension LiquidGlassView where Content == EmptyView {
    init(
        style: LiquidGlassStyle = .default,
        intensity: Double = 0.5,
        palette: LiquidGlassPalette? = nil,
        animationType: LiquidGlassAnimationType = .shimmer
    ) {
        self.style = style
        self.intensity = intensity
        self.palette = palette
        self.animationType = animationType
        self.content = EmptyView()
    }
}

// MARK: - Haptic Feedback Manager

class HapticFeedbackManager {
    static let shared = HapticFeedbackManager()
    
    private init() {}
    
    func lightImpact() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
    
    func mediumImpact() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
    }
    
    func heavyImpact() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
        impactFeedback.impactOccurred()
    }
    
    func success() {
        let notificationFeedback = UINotificationFeedbackGenerator()
        notificationFeedback.notificationOccurred(.success)
    }
    
    func warning() {
        let notificationFeedback = UINotificationFeedbackGenerator()
        notificationFeedback.notificationOccurred(.warning)
    }
    
    func error() {
        let notificationFeedback = UINotificationFeedbackGenerator()
        notificationFeedback.notificationOccurred(.error)
    }
    
    func selectionChanged() {
        let selectionFeedback = UISelectionFeedbackGenerator()
        selectionFeedback.selectionChanged()
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        // Basic examples
        LiquidGlassView(style: .default, intensity: 0.7) {
            Text("Default Glass")
                .font(.headline)
                .foregroundColor(DesignColors.textOnGlass)
        }
        
        LiquidGlassView(style: .card, intensity: 0.5) {
            Text("Card Glass")
                .font(.subheadline)
                .foregroundColor(DesignColors.textOnGlass)
        }
        
        // Animation examples
        LiquidGlassView(
            style: .button,
            intensity: 0.6,
            animationType: .shimmer
        ) {
            Text("Shimmer Effect")
                .font(.caption)
                .foregroundColor(DesignColors.textOnGlass)
        }
        
        LiquidGlassView(
            style: .button,
            intensity: 0.6,
            animationType: .pulse
        ) {
            Text("Pulse Effect")
                .font(.caption)
                .foregroundColor(DesignColors.textOnGlass)
        }
        
        LiquidGlassView(
            style: .button,
            intensity: 0.6,
            animationType: .glow
        ) {
            Text("Glow Effect")
                .font(.caption)
                .foregroundColor(DesignColors.textOnGlass)
        }
        
        // Palette examples
        LiquidGlassView(
            style: .container,
            intensity: 0.8,
            palette: .ocean,
            animationType: .wave
        ) {
            VStack {
                Text("Ocean Palette")
                    .font(.title2)
                    .foregroundColor(DesignColors.textOnGlass)
                Text("With wave animation")
                    .font(.body)
                    .foregroundColor(DesignColors.textOnGlass.opacity(0.8))
            }
        }
        
        LiquidGlassView(
            style: .container,
            intensity: 0.8,
            palette: .sunset,
            animationType: .particles
        ) {
            VStack {
                Text("Sunset Palette")
                    .font(.title2)
                    .foregroundColor(DesignColors.textOnGlass)
                Text("With particle effects")
                    .font(.body)
                    .foregroundColor(DesignColors.textOnGlass.opacity(0.8))
            }
        }
        
        // Style examples
        LiquidGlassView(style: .minimal, intensity: 0.4) {
            Text("Minimal Style")
                .font(.caption)
                .foregroundColor(DesignColors.textOnGlass)
        }
        
        LiquidGlassView(style: .dramatic, intensity: 0.9) {
            VStack {
                Text("Dramatic Style")
                    .font(.title3)
                    .foregroundColor(DesignColors.textOnGlass)
                Text("Maximum impact")
                    .font(.caption)
                    .foregroundColor(DesignColors.textOnGlass.opacity(0.8))
            }
        }
    }
    .padding()
    .background(DesignColors.background)
}