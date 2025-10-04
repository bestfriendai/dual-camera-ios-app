//
//  GlassToolbar.swift
//  DualApp
//
//  Created by DualApp Team on 10/3/25.
//

import SwiftUI

// MARK: - Glass Toolbar

struct GlassToolbar<Content: View>: View {
    // MARK: - Properties
    
    let content: Content
    let variant: GlassToolbarVariant
    let intensity: Double
    let palette: LiquidGlassPalette?
    let animationType: LiquidGlassAnimationType
    let position: GlassToolbarPosition
    let floatingStyle: GlassFloatingStyle
    
    // MARK: - State
    
    @State private var animationOffset: CGSize = .zero
    @State private var isAnimating = false
    @State private var shimmerRotation: Double = 0
    @State private var pulseScale: CGFloat = 1.0
    @State private var glowIntensity: Double = 0.2
    @State private var wavePhase: Double = 0
    @State private var isHovered = false
    @State private var floatingOffset: CGFloat = 0
    @State private var shadowIntensity: Double = 0.3
    @State private var toolbarOpacity: Double = 1.0
    
    // MARK: - Initialization
    
    init(
        variant: GlassToolbarVariant = .standard,
        intensity: Double = 0.5,
        palette: LiquidGlassPalette? = nil,
        animationType: LiquidGlassAnimationType = .shimmer,
        position: GlassToolbarPosition = .bottom,
        floatingStyle: GlassFloatingStyle = .standard,
        @ViewBuilder content: () -> Content
    ) {
        self.variant = variant
        self.intensity = intensity
        self.palette = palette
        self.animationType = animationType
        self.position = position
        self.floatingStyle = floatingStyle
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
                .opacity(toolbarOpacity)
        }
        .frame(maxWidth: .infinity)
        .frame(height: variant.height)
        .background(
            // Floating shadow
            floatingShadow
        )
        .offset(y: floatingOffset)
        .onAppear {
            startAnimations()
        }
        .onDisappear {
            stopAnimations()
        }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isHovered {
                        isHovered = true
                        HapticFeedbackManager.shared.lightImpact()
                    }
                }
                .onEnded { _ in
                    isHovered = false
                }
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilityLabel)
    }
    
    // MARK: - View Components
    
    private var backgroundLayers: some View {
        ZStack {
            // Base blur effect
            toolbarShape
                .fill(baseBackgroundColor)
                .background(
                    toolbarShape
                        .fill(backgroundGradient)
                )
                .blur(radius: variant.blurRadius * intensity)
            
            // Depth layers
            ForEach(0..<variant.depthLayers, id: \.self) { index in
                toolbarShape
                    .fill(depthLayerColor(for: index))
                    .offset(depthLayerOffset(for: index))
                    .blur(radius: depthLayerBlur(for: index))
            }
        }
    }
    
    private var glassSurface: some View {
        ZStack {
            toolbarShape
                .fill(surfaceGradient)
                .overlay(
                    // Surface highlights
                    toolbarShape
                        .fill(surfaceHighlightGradient)
                        .opacity(surfaceHighlightOpacity)
                )
                .overlay(
                    // Border
                    toolbarShape
                        .stroke(borderGradient, lineWidth: variant.borderWidth)
                )
                .shadow(
                    color: shadowColor,
                    radius: shadowRadius,
                    x: shadowOffset.width,
                    y: shadowOffset.height
                )
            
            // Floating reflection
            if floatingStyle != .none {
                toolbarShape
                    .fill(reflectionGradient)
                    .opacity(reflectionOpacity)
                    .mask(reflectionMask)
            }
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
            default:
                EmptyView()
            }
        }
    }
    
    private var interactiveEffects: some View {
        toolbarShape
            .fill(interactiveOverlay)
            .opacity(interactiveOpacity)
            .animation(.easeInOut(duration: 0.2), value: isHovered)
    }
    
    private var floatingShadow: some View {
        ZStack {
            // Main shadow
            toolbarShape
                .fill(shadowColor)
                .blur(radius: floatingShadowRadius)
                .offset(y: floatingShadowOffset)
                .opacity(shadowIntensity)
            
            // Ambient shadow
            toolbarShape
                .fill(ambientShadowColor)
                .blur(radius: ambientShadowRadius)
                .offset(y: ambientShadowOffset)
                .opacity(ambientShadowOpacity)
        }
    }
    
    // MARK: - Shape Components
    
    private var toolbarShape: some Shape {
        switch position {
        case .top, .bottom:
            return RoundedRectangle(cornerRadius: variant.cornerRadius)
        case .left:
            return UnevenRoundedRectangle(
                topLeading: 0,
                bottomLeading: 0,
                topTrailing: variant.cornerRadius,
                bottomTrailing: variant.cornerRadius
            )
        case .right:
            return UnevenRoundedRectangle(
                topLeading: variant.cornerRadius,
                bottomLeading: variant.cornerRadius,
                topTrailing: 0,
                bottomTrailing: 0
            )
        }
    }
    
    private var reflectionMask: some Shape {
        RoundedRectangle(cornerRadius: variant.cornerRadius)
            .path(in: CGRect(x: 0, y: 0, width: 400, height: 100))
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
            startPoint: position.gradientStart,
            endPoint: position.gradientEnd
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
            startPoint: position.gradientStart,
            endPoint: position.gradientEnd
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
            startPoint: position.gradientStart,
            endPoint: position.gradientEnd
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
            startPoint: position.gradientStart,
            endPoint: position.gradientEnd
        )
    }
    
    private var reflectionGradient: LinearGradient {
        let colors = [
            .white.opacity(0.2),
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
            LiquidGlassColors.shimmerBright.opacity(0.4 * intensity),
            LiquidGlassColors.shimmer.opacity(0)
        ]
        
        return LinearGradient(
            colors: colors,
            startPoint: position.gradientStart,
            endPoint: position.gradientEnd
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
            startPoint: position.gradientStart,
            endPoint: position.gradientEnd
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
        LiquidGlassColors.glassShadow.opacity(0.3 * shadowIntensity)
    }
    
    private var ambientShadowColor: Color {
        LiquidGlassColors.glassShadow.opacity(0.2 * shadowIntensity)
    }
    
    // MARK: - Animation Components
    
    private var shimmerEffect: some View {
        toolbarShape
            .fill(shimmerGradient)
            .offset(animationOffset)
            .rotationEffect(.degrees(shimmerRotation))
            .mask(toolbarShape)
    }
    
    private var pulseEffect: some View {
        toolbarShape
            .fill(pulseGradient)
            .scaleEffect(pulseScale)
            .opacity(pulseOpacity)
            .mask(toolbarShape)
    }
    
    private var glowEffect: some View {
        toolbarShape
            .fill(glowGradient)
            .opacity(glowIntensity)
            .blur(radius: glowBlurRadius)
            .mask(toolbarShape)
    }
    
    private var waveEffect: some View {
        toolbarShape
            .fill(waveGradient)
            .opacity(waveOpacity)
            .mask(
                toolbarShape
                    .offset(x: sin(wavePhase) * 10, y: cos(wavePhase) * 5)
            )
    }
    
    private var breathingEffect: some View {
        toolbarShape
            .fill(breathingGradient)
            .scaleEffect(1.0 + sin(wavePhase) * 0.02)
            .opacity(0.8 + sin(wavePhase) * 0.2)
            .mask(toolbarShape)
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
        0.3 * intensity
    }
    
    private var reflectionOpacity: Double {
        0.2 * intensity
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
    
    private var interactiveOpacity: Double {
        isHovered ? 0.1 : 0
    }
    
    private var shadowRadius: CGFloat {
        8 * intensity
    }
    
    private var shadowOffset: CGSize {
        CGSize(width: 0, height: 2)
    }
    
    private var floatingShadowRadius: CGFloat {
        switch floatingStyle {
        case .none:
            return 0
        case .subtle:
            return 10 * intensity
        case .standard:
            return 15 * intensity
        case .dramatic:
            return 25 * intensity
        }
    }
    
    private var floatingShadowOffset: CGFloat {
        switch floatingStyle {
        case .none:
            return 0
        case .subtle:
            return 4
        case .standard:
            return 8
        case .dramatic:
            return 12
        }
    }
    
    private var ambientShadowRadius: CGFloat {
        switch floatingStyle {
        case .none:
            return 0
        case .subtle:
            return 20 * intensity
        case .standard:
            return 30 * intensity
        case .dramatic:
            return 40 * intensity
        }
    }
    
    private var ambientShadowOffset: CGFloat {
        switch floatingStyle {
        case .none:
            return 0
        case .subtle:
            return 8
        case .standard:
            return 12
        case .dramatic:
            return 16
        }
    }
    
    private var ambientShadowOpacity: Double {
        switch floatingStyle {
        case .none:
            return 0
        case .subtle:
            return 0.1
        case .standard:
            return 0.15
        case .dramatic:
            return 0.2
        }
    }
    
    private var accessibilityLabel: String {
        switch position {
        case .top:
            return "Top toolbar"
        case .bottom:
            return "Bottom toolbar"
        case .left:
            return "Left toolbar"
        case .right:
            return "Right toolbar"
        }
    }
    
    // MARK: - Animation Methods
    
    private func startAnimations() {
        isAnimating = true
        
        // Start floating animation
        if floatingStyle != .none {
            startFloatingAnimation()
        }
        
        // Start effect animation
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
        default:
            break
        }
    }
    
    private func stopAnimations() {
        isAnimating = false
    }
    
    private func startFloatingAnimation() {
        withAnimation(
            .easeInOut(duration: floatingStyle.animationDuration)
            .repeatForever(autoreverses: true)
        ) {
            floatingOffset = floatingStyle.floatAmount
            shadowIntensity = 0.4
            toolbarOpacity = 0.95
        }
    }
    
    private func startShimmerAnimation() {
        withAnimation(
            .easeInOut(duration: variant.animationDuration)
            .repeatForever(autoreverses: true)
        ) {
            animationOffset = CGSize(width: 100, height: 0)
            shimmerRotation = 45
        }
    }
    
    private func startPulseAnimation() {
        withAnimation(
            .easeInOut(duration: variant.animationDuration)
            .repeatForever(autoreverses: true)
        ) {
            pulseScale = 1.02
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
    
    private func startBreathingAnimation() {
        withAnimation(
            .easeInOut(duration: variant.animationDuration * 3)
            .repeatForever(autoreverses: true)
        ) {
            wavePhase = 2 * .pi
        }
    }
}

// MARK: - Glass Toolbar Variant

enum GlassToolbarVariant: CaseIterable {
    case minimal
    case standard
    case elevated
    case floating
    case dramatic
    
    var height: CGFloat {
        switch self {
        case .minimal:
            return 44
        case .standard:
            return 56
        case .elevated:
            return 64
        case .floating:
            return 72
        case .dramatic:
            return 80
        }
    }
    
    var cornerRadius: CGFloat {
        switch self {
        case .minimal:
            return 12
        case .standard:
            return 16
        case .elevated:
            return 20
        case .floating:
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
        case .elevated:
            return 12
        case .floating:
            return 16
        case .dramatic:
            return 20
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
        case .dramatic:
            return 2.5
        }
    }
    
    var padding: EdgeInsets {
        switch self {
        case .minimal:
            return EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16)
        case .standard:
            return EdgeInsets(top: 12, leading: 20, bottom: 12, trailing: 20)
        case .elevated:
            return EdgeInsets(top: 16, leading: 24, bottom: 16, trailing: 24)
        case .floating:
            return EdgeInsets(top: 20, leading: 28, bottom: 20, trailing: 28)
        case .dramatic:
            return EdgeInsets(top: 24, leading: 32, bottom: 24, trailing: 32)
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
        case .elevated:
            return 3
        case .floating:
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
        case .elevated:
            return "Elevated"
        case .floating:
            return "Floating"
        case .dramatic:
            return "Dramatic"
        }
    }
}

// MARK: - Glass Toolbar Position

enum GlassToolbarPosition: CaseIterable {
    case top
    case bottom
    case left
    case right
    
    var gradientStart: UnitPoint {
        switch self {
        case .top:
            return .topLeading
        case .bottom:
            return .bottomLeading
        case .left:
            return .leading
        case .right:
            return .trailing
        }
    }
    
    var gradientEnd: UnitPoint {
        switch self {
        case .top:
            return .bottomTrailing
        case .bottom:
            return .topTrailing
        case .left:
            return .trailing
        case .right:
            return .leading
        }
    }
    
    var name: String {
        switch self {
        case .top:
            return "Top"
        case .bottom:
            return "Bottom"
        case .left:
            return "Left"
        case .right:
            return "Right"
        }
    }
}

// MARK: - Glass Floating Style

enum GlassFloatingStyle: CaseIterable {
    case none
    case subtle
    case standard
    case dramatic
    
    var floatAmount: CGFloat {
        switch self {
        case .none:
            return 0
        case .subtle:
            return -4
        case .standard:
            return -8
        case .dramatic:
            return -12
        }
    }
    
    var animationDuration: Double {
        switch self {
        case .none:
            return 0
        case .subtle:
            return 3.0
        case .standard:
            return 4.0
        case .dramatic:
            return 5.0
        }
    }
    
    var name: String {
        switch self {
        case .none:
            return "None"
        case .subtle:
            return "Subtle"
        case .standard:
            return "Standard"
        case .dramatic:
            return "Dramatic"
        }
    }
}

// MARK: - Glass Toolbar Item

struct GlassToolbarItem<Content: View>: View {
    let content: Content
    let spacing: CGFloat
    
    init(spacing: CGFloat = 12, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.content = content()
    }
    
    var body: some View {
        content
            .frame(maxWidth: .infinity)
    }
}

// MARK: - Glass Toolbar Control

struct GlassToolbarControl<Content: View>: View {
    let content: Content
    let isSelected: Bool
    let action: () -> Void
    
    @State private var isPressed = false
    
    init(isSelected: Bool = false, action: @escaping () -> Void, @ViewBuilder content: () -> Content) {
        self.isSelected = isSelected
        self.action = action
        self.content = content()
    }
    
    var body: some View {
        GlassButton(
            variant: .minimal,
            size: .medium,
            intensity: 0.6,
            animationType: .none,
            hapticStyle: .light,
            action: action
        ) {
            content
                .opacity(isSelected ? 1.0 : 0.7)
                .scaleEffect(isSelected ? 1.1 : 1.0)
        }
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .onTapGesture {
            action()
        }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    isPressed = true
                }
                .onEnded { _ in
                    isPressed = false
                }
        )
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        // Top toolbar
        GlassToolbar(
            variant: .standard,
            intensity: 0.7,
            position: .top,
            floatingStyle: .standard
        ) {
            HStack(spacing: 20) {
                GlassToolbarControl {
                    Image(systemName: "camera.fill")
                        .foregroundColor(DesignColors.textOnGlass)
                }
                
                Spacer()
                
                GlassToolbarControl(isSelected: true) {
                    Image(systemName: "video.fill")
                        .foregroundColor(DesignColors.textOnGlass)
                }
                
                GlassToolbarControl {
                    Image(systemName: "photo.fill")
                        .foregroundColor(DesignColors.textOnGlass)
                }
                
                Spacer()
                
                GlassToolbarControl {
                    Image(systemName: "gearshape.fill")
                        .foregroundColor(DesignColors.textOnGlass)
                }
            }
        }
        .padding(.horizontal)
        
        Spacer()
        
        // Bottom toolbar
        GlassToolbar(
            variant: .elevated,
            intensity: 0.6,
            palette: .ocean,
            animationType: .wave,
            position: .bottom,
            floatingStyle: .dramatic
        ) {
            HStack(spacing: 16) {
                GlassToolbarControl {
                    Image(systemName: "mic.fill")
                        .foregroundColor(DesignColors.textOnGlass)
                }
                
                GlassToolbarControl {
                    Image(systemName: "bolt.fill")
                        .foregroundColor(DesignColors.textOnGlass)
                }
                
                Spacer()
                
                GlassToolbarControl(isSelected: true) {
                    Image(systemName: "record.circle.fill")
                        .foregroundColor(.red)
                }
                
                Spacer()
                
                GlassToolbarControl {
                    Image(systemName: "switch.camera")
                        .foregroundColor(DesignColors.textOnGlass)
                }
                
                GlassToolbarControl {
                    Image(systemName: "timer")
                        .foregroundColor(DesignColors.textOnGlass)
                }
            }
        }
        .padding(.horizontal)
    }
    .background(DesignColors.background)
}