//
//  GlassButton.swift
//  DualApp
//
//  Created by DualApp Team on 10/3/25.
//

import SwiftUI

// MARK: - Glass Button

struct GlassButton<Label: View>: View {
    // MARK: - Properties
    
    let label: Label
    let variant: GlassButtonVariant
    let size: GlassButtonSize
    let intensity: Double
    let palette: LiquidGlassPalette?
    let animationType: LiquidGlassAnimationType
    let hapticStyle: HapticStyle
    let action: () -> Void
    
    // MARK: - State
    
    @State private var isPressed = false
    @State private var isHovered = false
    @State private var isDisabled = false
    @State private var animationOffset: CGSize = .zero
    @State private var shimmerRotation: Double = 0
    @State private var pulseScale: CGFloat = 1.0
    @State private var glowIntensity: Double = 0.2
    @State private var wavePhase: Double = 0
    @State private var rippleScale: CGFloat = 0
    @State private var rippleOpacity: Double = 0
    @State private var isAnimating = false
    
    // MARK: - Initialization
    
    init(
        variant: GlassButtonVariant = .standard,
        size: GlassButtonSize = .medium,
        intensity: Double = 0.5,
        palette: LiquidGlassPalette? = nil,
        animationType: LiquidGlassAnimationType = .shimmer,
        hapticStyle: HapticStyle = .light,
        action: @escaping () -> Void,
        @ViewBuilder label: () -> Label
    ) {
        self.variant = variant
        self.size = size
        self.intensity = intensity
        self.palette = palette
        self.animationType = animationType
        self.hapticStyle = hapticStyle
        self.action = action
        self.label = label()
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
            
            // Ripple effect
            if isPressed {
                rippleEffect
            }
            
            // Content
            label
                .textStyle(size.textStyle)
                .foregroundColor(textColor)
                .scaleEffect(isPressed ? 0.95 : 1.0)
                .opacity(isDisabled ? 0.5 : 1.0)
        }
        .frame(width: size.width, height: size.height)
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
            handleTap()
        }
        .disabled(isDisabled)
        .accessibilityButton(label: accessibilityLabel, hint: accessibilityHint, action: action)
    }
    
    // MARK: - View Components
    
    private var backgroundLayers: some View {
        ZStack {
            // Base blur effect
            buttonShape
                .fill(baseBackgroundColor)
                .background(
                    buttonShape
                        .fill(backgroundGradient)
                )
                .blur(radius: variant.blurRadius * intensity)
            
            // Depth layers
            ForEach(0..<variant.depthLayers, id: \.self) { index in
                buttonShape
                    .fill(depthLayerColor(for: index))
                    .offset(depthLayerOffset(for: index))
                    .blur(radius: depthLayerBlur(for: index))
            }
        }
    }
    
    private var glassSurface: some View {
        buttonShape
            .fill(surfaceGradient)
            .overlay(
                // Surface highlights
                buttonShape
                    .fill(surfaceHighlightGradient)
                    .opacity(surfaceHighlightOpacity)
            )
            .overlay(
                // Border
                buttonShape
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
            case .none:
                EmptyView()
            default:
                EmptyView()
            }
        }
    }
    
    private var interactiveEffects: some View {
        buttonShape
            .fill(interactiveOverlay)
            .opacity(interactiveOpacity)
            .animation(.easeInOut(duration: 0.2), value: isHovered)
    }
    
    private var rippleEffect: some View {
        Circle()
            .fill(rippleColor)
            .scaleEffect(rippleScale)
            .opacity(rippleOpacity)
            .animation(.easeOut(duration: 0.6), value: rippleScale)
            .animation(.easeOut(duration: 0.6), value: rippleOpacity)
    }
    
    // MARK: - Shape Components
    
    private var buttonShape: some Shape {
        switch variant.shape {
        case .rounded:
            return RoundedRectangle(cornerRadius: size.cornerRadius)
        case .circular:
            return Circle()
        case .capsule:
            return Capsule()
        case .custom(let radius):
            return RoundedRectangle(cornerRadius: radius)
        }
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
            endRadius: 50
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
    
    private var textColor: Color {
        palette?.accentColor ?? DesignColors.textOnGlass
    }
    
    private var rippleColor: Color {
        palette?.accentColor ?? .white
    }
    
    private var shadowColor: Color {
        LiquidGlassColors.glassShadow.opacity(0.2 * intensity)
    }
    
    // MARK: - Animation Components
    
    private var shimmerEffect: some View {
        buttonShape
            .fill(shimmerGradient)
            .offset(animationOffset)
            .rotationEffect(.degrees(shimmerRotation))
            .mask(buttonShape)
    }
    
    private var pulseEffect: some View {
        buttonShape
            .fill(pulseGradient)
            .scaleEffect(pulseScale)
            .opacity(pulseOpacity)
            .mask(buttonShape)
    }
    
    private var glowEffect: some View {
        buttonShape
            .fill(glowGradient)
            .opacity(glowIntensity)
            .blur(radius: glowBlurRadius)
            .mask(buttonShape)
    }
    
    private var waveEffect: some View {
        buttonShape
            .fill(waveGradient)
            .opacity(waveOpacity)
            .mask(
                buttonShape
                    .offset(x: sin(wavePhase) * 5, y: cos(wavePhase) * 3)
            )
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
    
    private var pulseOpacity: Double {
        0.2 * intensity
    }
    
    private var glowBlurRadius: CGFloat {
        15 * intensity
    }
    
    private var waveOpacity: Double {
        0.15 * intensity
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
        6 * intensity
    }
    
    private var shadowOffset: CGSize {
        CGSize(width: 0, height: 2)
    }
    
    private var accessibilityLabel: String {
        // This should be provided by the caller or detected from the label content
        return "Button"
    }
    
    private var accessibilityHint: String {
        "Double tap to activate"
    }
    
    // MARK: - Interaction Methods
    
    private func handlePressBegan() {
        if !isDisabled {
            isPressed = true
            triggerHapticFeedback()
            
            withAnimation(.easeInOut(duration: 0.1)) {
                rippleScale = 0
                rippleOpacity = 0.6
            }
            
            withAnimation(.easeOut(duration: 0.6)) {
                rippleScale = 2.0
                rippleOpacity = 0
            }
        }
    }
    
    private func handlePressEnded() {
        if !isDisabled {
            isPressed = false
        }
    }
    
    private func handleTap() {
        if !isDisabled {
            action()
        }
    }
    
    private func triggerHapticFeedback() {
        switch hapticStyle {
        case .light:
            HapticFeedbackManager.shared.lightImpact()
        case .medium:
            HapticFeedbackManager.shared.mediumImpact()
        case .heavy:
            HapticFeedbackManager.shared.heavyImpact()
        case .success:
            HapticFeedbackManager.shared.success()
        case .warning:
            HapticFeedbackManager.shared.warning()
        case .error:
            HapticFeedbackManager.shared.error()
        case .selection:
            HapticFeedbackManager.shared.selectionChanged()
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
        case .none:
            break
        default:
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
            animationOffset = CGSize(width: 20, height: 20)
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
}

// MARK: - Glass Button Variant

enum GlassButtonVariant: CaseIterable {
    case minimal
    case standard
    case elevated
    case floating
    case dramatic
    
    var shape: GlassButtonShape {
        switch self {
        case .minimal:
            return .rounded
        case .standard:
            return .rounded
        case .elevated:
            return .rounded
        case .floating:
            return .rounded
        case .dramatic:
            return .rounded
        }
    }
    
    var blurRadius: CGFloat {
        switch self {
        case .minimal:
            return 2
        case .standard:
            return 6
        case .elevated:
            return 10
        case .floating:
            return 15
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

// MARK: - Glass Button Shape

enum GlassButtonShape: Equatable {
    case rounded
    case circular
    case capsule
    case custom(CGFloat)
}

// MARK: - Glass Button Size

enum GlassButtonSize: CaseIterable {
    case small
    case medium
    case large
    case extraLarge
    
    var width: CGFloat {
        switch self {
        case .small:
            return 80
        case .medium:
            return 120
        case .large:
            return 160
        case .extraLarge:
            return 200
        }
    }
    
    var height: CGFloat {
        switch self {
        case .small:
            return 32
        case .medium:
            return 44
        case .large:
            return 56
        case .extraLarge:
            return 68
        }
    }
    
    var cornerRadius: CGFloat {
        switch self {
        case .small:
            return 6
        case .medium:
            return 8
        case .large:
            return 12
        case .extraLarge:
            return 16
        }
    }
    
    var textStyle: DesignTypography.TextStyle {
        switch self {
        case .small:
            return TypographyPresets.Glass.caption
        case .medium:
            return TypographyPresets.Glass.body
        case .large:
            return TypographyPresets.Glass.subtitle
        case .extraLarge:
            return TypographyPresets.Glass.title
        }
    }
    
    var name: String {
        switch self {
        case .small:
            return "Small"
        case .medium:
            return "Medium"
        case .large:
            return "Large"
        case .extraLarge:
            return "Extra Large"
        }
    }
}

// MARK: - Haptic Style

enum HapticStyle: CaseIterable {
    case light
    case medium
    case heavy
    case success
    case warning
    case error
    case selection
    
    var name: String {
        switch self {
        case .light:
            return "Light"
        case .medium:
            return "Medium"
        case .heavy:
            return "Heavy"
        case .success:
            return "Success"
        case .warning:
            return "Warning"
        case .error:
            return "Error"
        case .selection:
            return "Selection"
        }
    }
}

// MARK: - Convenience Initializers

extension GlassButton where Label == Text {
    init(
        _ title: String,
        variant: GlassButtonVariant = .standard,
        size: GlassButtonSize = .medium,
        intensity: Double = 0.5,
        palette: LiquidGlassPalette? = nil,
        animationType: LiquidGlassAnimationType = .shimmer,
        hapticStyle: HapticStyle = .light,
        action: @escaping () -> Void
    ) {
        self.init(
            variant: variant,
            size: size,
            intensity: intensity,
            palette: palette,
            animationType: animationType,
            hapticStyle: hapticStyle,
            action: action
        ) {
            Text(title)
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        // Basic examples
        GlassButton(
            "Minimal Button",
            variant: .minimal,
            size: .small,
            animationType: .shimmer
        ) {
            print("Minimal button tapped")
        }
        
        GlassButton(
            "Standard Button",
            variant: .standard,
            size: .medium,
            animationType: .pulse
        ) {
            print("Standard button tapped")
        }
        
        GlassButton(
            "Elevated Button",
            variant: .elevated,
            size: .large,
            animationType: .glow
        ) {
            print("Elevated button tapped")
        }
        
        // Palette examples
        GlassButton(
            "Ocean Theme",
            variant: .floating,
            size: .medium,
            palette: .ocean,
            animationType: .wave
        ) {
            print("Ocean button tapped")
        }
        
        GlassButton(
            "Sunset Theme",
            variant: .dramatic,
            size: .large,
            palette: .sunset,
            animationType: .shimmer
        ) {
            print("Sunset button tapped")
        }
        
        // Custom label example
        GlassButton(
            variant: .standard,
            size: .medium,
            animationType: .pulse
        ) {
            HStack {
                Image(systemName: "camera.fill")
                Text("Capture")
            }
        }
    }
    .padding()
    .background(DesignColors.background)
}