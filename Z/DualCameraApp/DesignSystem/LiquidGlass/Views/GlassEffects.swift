//
//  GlassEffects.swift
//  DualApp
//
//  Created by DualApp Team on 10/3/25.
//

import SwiftUI

// MARK: - Glass Effects View

struct GlassEffects<Content: View>: View {
    // MARK: - Properties
    
    let content: Content
    let effectType: GlassEffectType
    let intensity: Double
    let palette: LiquidGlassPalette?
    let isEnabled: Bool
    
    // MARK: - State
    
    @State private var shimmerOffset: CGSize = .zero
    @State private var shimmerRotation: Double = 0
    @State private var rippleCenter: CGPoint = .center
    @State private var rippleScale: CGFloat = 0
    @State private var rippleOpacity: Double = 0
    @State private var particlePositions: [Particle] = []
    @State private var morphProgress: Double = 0
    @State private var liquidDeformPoints: [CGPoint] = []
    @State private var isAnimating = false
    @State private var animationPhase: Double = 0
    
    // MARK: - Initialization
    
    init(
        effectType: GlassEffectType,
        intensity: Double = 0.5,
        palette: LiquidGlassPalette? = nil,
        isEnabled: Bool = true,
        @ViewBuilder content: () -> Content
    ) {
        self.effectType = effectType
        self.intensity = intensity
        self.palette = palette
        self.isEnabled = isEnabled
        self.content = content()
    }
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            // Content
            content
            
            // Effects overlay
            if isEnabled {
                effectsOverlay
            }
        }
        .clipped()
        .onAppear {
            if isEnabled {
                startAnimations()
            }
        }
        .onDisappear {
            stopAnimations()
        }
        .onChange(of: isEnabled) { enabled in
            if enabled {
                startAnimations()
            } else {
                stopAnimations()
            }
        }
        .gesture(
            tapGesture
        )
    }
    
    // MARK: - View Components
    
    private var effectsOverlay: some View {
        ZStack {
            switch effectType {
            case .shimmer:
                shimmerEffect
            case .ripple:
                rippleEffect
            case .particles:
                particleEffect
            case .morphing:
                morphingEffect
            case .liquidDeformation:
                liquidDeformationEffect
            case .none:
                EmptyView()
            }
        }
    }
    
    private var shimmerEffect: some View {
        ZStack {
            // Shimmer gradient
            RoundedRectangle(cornerRadius: 0)
                .fill(shimmerGradient)
                .offset(shimmerOffset)
                .rotationEffect(.degrees(shimmerRotation))
                .mask(
                    LinearGradient(
                        colors: [
                            .clear,
                            .black.opacity(0.3),
                            .clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
    }
    
    private var rippleEffect: some View {
        ZStack {
            // Ripple circles
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .stroke(rippleGradient, lineWidth: 2)
                    .frame(width: 100, height: 100)
                    .position(rippleCenter)
                    .scaleEffect(rippleScale + CGFloat(index) * 0.5)
                    .opacity(rippleOpacity - Double(index) * 0.2)
            }
        }
    }
    
    private var particleEffect: some View {
        ZStack {
            ForEach(particlePositions, id: \.id) { particle in
                Circle()
                    .fill(particle.color)
                    .frame(width: particle.size, height: particle.size)
                    .position(particle.position)
                    .opacity(particle.opacity)
            }
        }
    }
    
    private var morphingEffect: some View {
        ZStack {
            // Morphing shape
            MorphingShape(progress: morphProgress)
                .fill(morphingGradient)
                .opacity(0.3 * intensity)
        }
    }
    
    private var liquidDeformationEffect: some View {
        ZStack {
            // Liquid deformation mesh
            LiquidDeformationMesh(
                points: liquidDeformPoints,
                phase: animationPhase
            )
            .fill(liquidDeformGradient)
            .opacity(0.2 * intensity)
        }
    }
    
    // MARK: - Gesture Handling
    
    private var tapGesture: some Gesture {
        TapGesture()
            .onEnded { location in
                handleTap(at: location)
            }
    }
    
    private func handleTap(at location: CGPoint) {
        switch effectType {
        case .ripple:
            triggerRipple(at: location)
        case .particles:
            triggerParticles(at: location)
        case .liquidDeformation:
            triggerLiquidDeformation(at: location)
        default:
            break
        }
        
        HapticFeedbackManager.shared.lightImpact()
    }
    
    private func triggerRipple(at location: CGPoint) {
        rippleCenter = location
        rippleScale = 0.1
        rippleOpacity = 0.8
        
        withAnimation(.easeOut(duration: 1.5)) {
            rippleScale = 2.0
            rippleOpacity = 0
        }
    }
    
    private func triggerParticles(at location: CGPoint) {
        // Add new particles at tap location
        let newParticles = (0..<10).map { _ in
            Particle(
                id: UUID(),
                position: location,
                velocity: CGPoint(
                    x: CGFloat.random(in: -100...100),
                    y: CGFloat.random(in: -100...100)
                ),
                size: CGFloat.random(in: 2...6),
                color: particleColor,
                opacity: Double.random(in: 0.5...1.0),
                life: 1.0
            )
        }
        
        particlePositions.append(contentsOf: newParticles)
        
        // Limit particle count
        if particlePositions.count > 50 {
            particlePositions.removeFirst(particlePositions.count - 50)
        }
    }
    
    private func triggerLiquidDeformation(at location: CGPoint) {
        // Add deformation point
        liquidDeformPoints.append(location)
        
        // Limit deformation points
        if liquidDeformPoints.count > 10 {
            liquidDeformPoints.removeFirst()
        }
    }
    
    // MARK: - Color and Gradient Computations
    
    private var shimmerGradient: LinearGradient {
        let colors = [
            LiquidGlassColors.shimmer.opacity(0),
            LiquidGlassColors.shimmerBright.opacity(0.6 * intensity),
            LiquidGlassColors.shimmer.opacity(0)
        ]
        
        return LinearGradient(
            colors: colors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    private var rippleGradient: RadialGradient {
        let accentColor = palette?.accentColor ?? .blue
        
        return RadialGradient(
            colors: [
                accentColor.opacity(0.6 * intensity),
                accentColor.opacity(0.3 * intensity),
                accentColor.opacity(0.1 * intensity)
            ],
            center: .center,
            startRadius: 10,
            endRadius: 50
        )
    }
    
    private var morphingGradient: LinearGradient {
        let accentColor = palette?.accentColor ?? .blue
        
        return LinearGradient(
            colors: [
                accentColor.opacity(0.4 * intensity),
                accentColor.opacity(0.2 * intensity),
                accentColor.opacity(0.1 * intensity)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    private var liquidDeformGradient: LinearGradient {
        let accentColor = palette?.accentColor ?? .blue
        
        return LinearGradient(
            colors: [
                accentColor.opacity(0.3 * intensity),
                accentColor.opacity(0.15 * intensity),
                accentColor.opacity(0.05 * intensity)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    private var particleColor: Color {
        let tints = palette?.tints ?? [.clear]
        let tint = tints.randomElement() ?? .clear
        return tint.color
    }
    
    // MARK: - Animation Methods
    
    private func startAnimations() {
        isAnimating = true
        
        switch effectType {
        case .shimmer:
            startShimmerAnimation()
        case .particles:
            startParticleAnimation()
        case .morphing:
            startMorphingAnimation()
        case .liquidDeformation:
            startLiquidDeformationAnimation()
        default:
            break
        }
    }
    
    private func stopAnimations() {
        isAnimating = false
    }
    
    private func startShimmerAnimation() {
        withAnimation(
            .easeInOut(duration: 2.5)
            .repeatForever(autoreverses: true)
        ) {
            shimmerOffset = CGSize(width: 200, height: 200)
            shimmerRotation = 45
        }
    }
    
    private func startParticleAnimation() {
        // Initialize particles
        particlePositions = (0..<20).map { _ in
            Particle(
                id: UUID(),
                position: CGPoint(
                    x: CGFloat.random(in: 0...UIScreen.main.bounds.width),
                    y: CGFloat.random(in: 0...UIScreen.main.bounds.height)
                ),
                velocity: CGPoint(
                    x: CGFloat.random(in: -50...50),
                    y: CGFloat.random(in: -50...50)
                ),
                size: CGFloat.random(in: 2...6),
                color: particleColor,
                opacity: Double.random(in: 0.3...0.8),
                life: 1.0
            )
        }
        
        // Animate particles
        Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            guard isAnimating else { return }
            
            updateParticles()
        }
    }
    
    private func updateParticles() {
        particlePositions = particlePositions.map { particle in
            var updatedParticle = particle
            
            // Update position
            updatedParticle.position.x += particle.velocity.x * 0.01
            updatedParticle.position.y += particle.velocity.y * 0.01
            
            // Update life
            updatedParticle.life -= 0.01
            updatedParticle.opacity = particle.opacity * updatedParticle.life
            
            // Bounce off edges
            if updatedParticle.position.x <= 0 || updatedParticle.position.x >= UIScreen.main.bounds.width {
                updatedParticle.velocity.x *= -1
            }
            
            if updatedParticle.position.y <= 0 || updatedParticle.position.y >= UIScreen.main.bounds.height {
                updatedParticle.velocity.y *= -1
            }
            
            return updatedParticle
        }
        
        // Remove dead particles
        particlePositions.removeAll { $0.life <= 0 }
        
        // Add new particles if needed
        if particlePositions.count < 20 {
            particlePositions.append(
                Particle(
                    id: UUID(),
                    position: CGPoint(
                        x: CGFloat.random(in: 0...UIScreen.main.bounds.width),
                        y: CGFloat.random(in: 0...UIScreen.main.bounds.height)
                    ),
                    velocity: CGPoint(
                        x: CGFloat.random(in: -50...50),
                        y: CGFloat.random(in: -50...50)
                    ),
                    size: CGFloat.random(in: 2...6),
                    color: particleColor,
                    opacity: Double.random(in: 0.3...0.8),
                    life: 1.0
                )
            )
        }
    }
    
    private func startMorphingAnimation() {
        withAnimation(
            .easeInOut(duration: 4.0)
            .repeatForever(autoreverses: true)
        ) {
            morphProgress = 1.0
        }
    }
    
    private func startLiquidDeformationAnimation() {
        // Initialize deformation points
        liquidDeformPoints = (0..<5).map { _ in
            CGPoint(
                x: CGFloat.random(in: 0...UIScreen.main.bounds.width),
                y: CGFloat.random(in: 0...UIScreen.main.bounds.height)
            )
        }
        
        // Animate deformation
        withAnimation(
            .easeInOut(duration: 3.0)
            .repeatForever(autoreverses: true)
        ) {
            animationPhase = 2 * .pi
        }
        
        // Update deformation points
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            guard isAnimating else { return }
            
            updateLiquidDeformation()
        }
    }
    
    private func updateLiquidDeformation() {
        liquidDeformPoints = liquidDeformPoints.map { point in
            CGPoint(
                x: point.x + CGFloat.random(in: -5...5),
                y: point.y + CGFloat.random(in: -5...5)
            )
        }
    }
}

// MARK: - Glass Effect Type

enum GlassEffectType: CaseIterable {
    case none
    case shimmer
    case ripple
    case particles
    case morphing
    case liquidDeformation
    
    var name: String {
        switch self {
        case .none:
            return "None"
        case .shimmer:
            return "Shimmer"
        case .ripple:
            return "Ripple"
        case .particles:
            return "Particles"
        case .morphing:
            return "Morphing"
        case .liquidDeformation:
            return "Liquid Deformation"
        }
    }
    
    var description: String {
        switch self {
        case .none:
            return "No effect"
        case .shimmer:
            return "Subtle light shimmer effect"
        case .ripple:
            return "Water ripple effect on touch"
        case .particles:
            return "Floating particle effects"
        case .morphing:
            return "Shape morphing animation"
        case .liquidDeformation:
            return "Liquid-like deformation effect"
        }
    }
}

// MARK: - Particle Model

struct Particle: Identifiable {
    let id: UUID
    var position: CGPoint
    var velocity: CGPoint
    var size: CGFloat
    var color: Color
    var opacity: Double
    var life: Double
}

// MARK: - Morphing Shape

struct MorphingShape: Shape {
    let progress: Double
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        let width = rect.width
        let height = rect.height
        
        // Create a morphing shape based on progress
        let cornerRadius: CGFloat = 20 + sin(progress * .pi * 2) * 10
        let morphFactor: CGFloat = sin(progress * .pi * 2) * 0.1
        
        // Create a rounded rectangle with morphing
        let morphWidth = width * (1 + morphFactor)
        let morphHeight = height * (1 - morphFactor)
        let x = (width - morphWidth) / 2
        let y = (height - morphHeight) / 2
        
        path.addRoundedRect(
            in: CGRect(x: x, y: y, width: morphWidth, height: morphHeight),
            cornerSize: CGSize(width: cornerRadius, height: cornerRadius)
        )
        
        return path
    }
}

// MARK: - Liquid Deformation Mesh

struct LiquidDeformationMesh: Shape {
    let points: [CGPoint]
    let phase: Double
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        guard !points.isEmpty else {
            path.addRect(rect)
            return path
        }
        
        // Create a liquid deformation effect based on points
        let gridSize: CGFloat = 20
        let cols = Int(rect.width / gridSize)
        let rows = Int(rect.height / gridSize)
        
        for row in 0..<rows {
            for col in 0..<cols {
                let x = CGFloat(col) * gridSize
                let y = CGFloat(row) * gridSize
                
                // Calculate deformation based on nearby points
                var deformation: CGPoint = .zero
                
                for point in points {
                    let distance = sqrt(pow(x - point.x, 2) + pow(y - point.y, 2))
                    if distance < 100 {
                        let influence = 1.0 - (distance / 100)
                        let angle = atan2(y - point.y, x - point.x) + phase
                        let deformAmount = influence * 10 * sin(phase)
                        
                        deformation.x += cos(angle) * deformAmount
                        deformation.y += sin(angle) * deformAmount
                    }
                }
                
                // Add deformed point to path
                let deformedPoint = CGPoint(
                    x: x + deformation.x,
                    y: y + deformation.y
                )
                
                if row == 0 && col == 0 {
                    path.move(to: deformedPoint)
                } else {
                    path.addLine(to: deformedPoint)
                }
            }
        }
        
        return path
    }
}

// MARK: - Glass Effects View Modifier

extension View {
    func glassEffect(
        _ effectType: GlassEffectType,
        intensity: Double = 0.5,
        palette: LiquidGlassPalette? = nil,
        isEnabled: Bool = true
    ) -> some View {
        self.overlay(
            GlassEffects(
                effectType: effectType,
                intensity: intensity,
                palette: palette,
                isEnabled: isEnabled
            ) {
                EmptyView()
            }
        )
    }
}

// MARK: - Glass Effects Container

struct GlassEffectsContainer<Content: View>: View {
    // MARK: - Properties
    
    let content: Content
    let effects: [GlassEffectType]
    let intensity: Double
    let palette: LiquidGlassPalette?
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            content
            
            ForEach(Array(effects.enumerated()), id: \.offset) { index, effect in
                GlassEffects(
                    effectType: effect,
                    intensity: intensity,
                    palette: palette
                ) {
                    EmptyView()
                }
                .opacity(1.0 - Double(index) * 0.2) // Stack effects with decreasing opacity
            }
        }
    }
    
    // MARK: - Initialization
    
    init(
        effects: [GlassEffectType],
        intensity: Double = 0.5,
        palette: LiquidGlassPalette? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.effects = effects
        self.intensity = intensity
        self.palette = palette
        self.content = content()
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black
        
        VStack(spacing: 30) {
            // Shimmer effect
            GlassContainerView(variant: .standard, intensity: 0.7) {
                Text("Shimmer Effect")
                    .textStyle(TypographyPresets.Glass.title)
            }
            .glassEffect(.shimmer, intensity: 0.7)
            
            // Ripple effect
            GlassContainerView(variant: .standard, intensity: 0.7) {
                Text("Ripple Effect")
                    .textStyle(TypographyPresets.Glass.title)
            }
            .glassEffect(.ripple, intensity: 0.7)
            
            // Particle effect
            GlassContainerView(variant: .standard, intensity: 0.7) {
                Text("Particle Effect")
                    .textStyle(TypographyPresets.Glass.title)
            }
            .glassEffect(.particles, intensity: 0.7)
            
            // Morphing effect
            GlassContainerView(variant: .standard, intensity: 0.7) {
                Text("Morphing Effect")
                    .textStyle(TypographyPresets.Glass.title)
            }
            .glassEffect(.morphing, intensity: 0.7)
            
            // Liquid deformation effect
            GlassContainerView(variant: .standard, intensity: 0.7) {
                Text("Liquid Deformation")
                    .textStyle(TypographyPresets.Glass.title)
            }
            .glassEffect(.liquidDeformation, intensity: 0.7)
            
            // Combined effects
            GlassContainerView(variant: .standard, intensity: 0.7, palette: .ocean) {
                Text("Combined Effects")
                    .textStyle(TypographyPresets.Glass.title)
            }
            .glassEffect(.shimmer, intensity: 0.5)
            .glassEffect(.particles, intensity: 0.3)
        }
        .padding()
    }
    .ignoresSafeArea()
}