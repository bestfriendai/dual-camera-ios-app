//
//  GlassModal.swift
//  DualApp
//
//  Created by DualApp Team on 10/3/25.
//

import SwiftUI

// MARK: - Glass Modal

struct GlassModal<Content: View>: View {
    // MARK: - Properties
    
    let content: Content
    let variant: GlassModalVariant
    let intensity: Double
    let palette: LiquidGlassPalette?
    let animationType: LiquidGlassAnimationType
    let presentationStyle: GlassModalPresentationStyle
    let dismissOnBackgroundTap: Bool
    let onDismiss: (() -> Void)?
    
    // MARK: - State
    
    @State private var isPresented = false
    @State private var animationOffset: CGSize = .zero
    @State private var isAnimating = false
    @State private var shimmerRotation: Double = 0
    @State private var pulseScale: CGFloat = 1.0
    @State private var glowIntensity: Double = 0.2
    @State private var wavePhase: Double = 0
    @State private var modalScale: CGFloat = 0.8
    @State private var modalOpacity: Double = 0
    @State private var backgroundOpacity: Double = 0
    @State private var contentOffset: CGFloat = 0
    @State private var dragOffset: CGFloat = 0
    @State private var isDragging = false
    @State private var isHovered = false
    
    // MARK: - Initialization
    
    init(
        variant: GlassModalVariant = .standard,
        intensity: Double = 0.5,
        palette: LiquidGlassPalette? = nil,
        animationType: LiquidGlassAnimationType = .shimmer,
        presentationStyle: GlassModalPresentationStyle = .center,
        dismissOnBackgroundTap: Bool = true,
        onDismiss: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.variant = variant
        self.intensity = intensity
        self.palette = palette
        self.animationType = animationType
        self.presentationStyle = presentationStyle
        self.dismissOnBackgroundTap = dismissOnBackgroundTap
        self.onDismiss = onDismiss
        self.content = content()
    }
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            // Background overlay
            backgroundOverlay
                .opacity(backgroundOpacity)
                .onTapGesture {
                    if dismissOnBackgroundTap {
                        dismiss()
                    }
                }
            
            // Modal container
            modalContainer
                .scaleEffect(modalScale)
                .opacity(modalOpacity)
                .offset(y: contentOffset + dragOffset)
                .gesture(
                    presentationStyle == .bottom ? dragGesture : nil
                )
        }
        .ignoresSafeArea()
        .onAppear {
            present()
        }
    }
    
    // MARK: - View Components
    
    private var backgroundOverlay: some View {
        ZStack {
            // Base blur
            Color.black
                .opacity(0.3)
            
            // Animated gradient
            RadialGradient(
                colors: [
                    (palette?.baseColor ?? .blue).opacity(0.1),
                    Color.black.opacity(0.4),
                    Color.black.opacity(0.6)
                ],
                center: .center,
                startRadius: 100,
                endRadius: 500
            )
            
            // Noise texture effect
            noiseEffect
        }
    }
    
    private var noiseEffect: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [
                        .white.opacity(0.02),
                        .white.opacity(0.01),
                        .white.opacity(0.02)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
    }
    
    private var modalContainer: some View {
        ZStack {
            // Background layers
            modalBackgroundLayers
            
            // Glass surface
            modalGlassSurface
            
            // Animation effects
            modalAnimationEffects
            
            // Interactive effects
            modalInteractiveEffects
            
            // Content
            content
                .padding(variant.padding)
                .frame(maxWidth: variant.maxWidth, maxHeight: variant.maxHeight)
        }
        .frame(width: modalWidth, height: modalHeight)
        .clipShape(modalShape)
        .shadow(
            color: modalShadowColor,
            radius: modalShadowRadius,
            x: modalShadowOffset.width,
            y: modalShadowOffset.height
        )
    }
    
    private var modalBackgroundLayers: some View {
        ZStack {
            // Base blur effect
            modalShape
                .fill(baseBackgroundColor)
                .background(
                    modalShape
                        .fill(backgroundGradient)
                )
                .blur(radius: variant.blurRadius * intensity)
            
            // Depth layers
            ForEach(0..<variant.depthLayers, id: \.self) { index in
                modalShape
                    .fill(depthLayerColor(for: index))
                    .offset(depthLayerOffset(for: index))
                    .blur(radius: depthLayerBlur(for: index))
            }
            
            // Vignette effect
            modalShape
                .fill(vignetteGradient)
                .opacity(0.1 * intensity)
        }
    }
    
    private var modalGlassSurface: some View {
        ZStack {
            modalShape
                .fill(surfaceGradient)
                .overlay(
                    // Surface highlights
                    modalShape
                        .fill(surfaceHighlightGradient)
                        .opacity(surfaceHighlightOpacity)
                )
                .overlay(
                    // Border
                    modalShape
                        .stroke(borderGradient, lineWidth: variant.borderWidth)
                )
            
            // Reflection layer
            modalShape
                .fill(reflectionGradient)
                .opacity(reflectionOpacity)
                .mask(reflectionMask)
        }
    }
    
    private var modalAnimationEffects: some View {
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
    
    private var modalInteractiveEffects: some View {
        modalShape
            .fill(interactiveOverlay)
            .opacity(interactiveOpacity)
            .animation(.easeInOut(duration: 0.2), value: isHovered)
    }
    
    // MARK: - Shape Components
    
    private var modalShape: some Shape {
        switch variant.shape {
        case .rounded:
            return RoundedRectangle(cornerRadius: variant.cornerRadius)
        case .circular:
            return Circle()
        case .capsule:
            return Capsule()
        case .custom(let radius):
            return RoundedRectangle(cornerRadius: radius)
        case .asymmetric(let corners):
            return AsymmetricRoundedRectangle(
                topLeading: corners.topLeading,
                bottomLeading: corners.bottomLeading,
                topTrailing: corners.topTrailing,
                bottomTrailing: corners.bottomTrailing
            )
        }
    }
    
    private var reflectionMask: some Shape {
        RoundedRectangle(cornerRadius: variant.cornerRadius)
            .path(in: CGRect(x: 0, y: 0, width: 400, height: 150))
            .offset(y: -75)
    }
    
    // MARK: - Layout Components
    
    private var modalWidth: CGFloat? {
        switch presentationStyle {
        case .center, .fullscreen:
            return nil // Use maxWidth
        case .sheet:
            return UIScreen.main.bounds.width - 40
        case .bottom:
            return UIScreen.main.bounds.width
        }
    }
    
    private var modalHeight: CGFloat? {
        switch presentationStyle {
        case .center:
            return nil // Use maxHeight
        case .fullscreen:
            return nil // Use maxHeight
        case .sheet:
            return UIScreen.main.bounds.height * 0.7
        case .bottom:
            return UIScreen.main.bounds.height * 0.6
        }
    }
    
    // MARK: - Gesture Handling
    
    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                isDragging = true
                dragOffset = max(0, value.translation.y)
            }
            .onEnded { value in
                isDragging = false
                
                if value.translation.y > 100 {
                    dismiss()
                } else {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                        dragOffset = 0
                    }
                }
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
            baseTint.opacity(0.12 * intensity),
            baseTint.opacity(0.06 * intensity),
            baseTint.opacity(0.03 * intensity)
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
    
    private var vignetteGradient: RadialGradient {
        return RadialGradient(
            colors: [
                .clear,
                .black.opacity(0.2),
                .black.opacity(0.4)
            ],
            center: .center,
            startRadius: 100,
            endRadius: 300
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
            endRadius: 200
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
    
    private var modalShadowColor: Color {
        LiquidGlassColors.glassShadow.opacity(0.5 * intensity)
    }
    
    // MARK: - Animation Components
    
    private var shimmerEffect: some View {
        modalShape
            .fill(shimmerGradient)
            .offset(animationOffset)
            .rotationEffect(.degrees(shimmerRotation))
            .mask(modalShape)
    }
    
    private var pulseEffect: some View {
        modalShape
            .fill(pulseGradient)
            .scaleEffect(pulseScale)
            .opacity(pulseOpacity)
            .mask(modalShape)
    }
    
    private var glowEffect: some View {
        modalShape
            .fill(glowGradient)
            .opacity(glowIntensity)
            .blur(radius: glowBlurRadius)
            .mask(modalShape)
    }
    
    private var waveEffect: some View {
        modalShape
            .fill(waveGradient)
            .opacity(waveOpacity)
            .mask(
                modalShape
                    .offset(x: sin(wavePhase) * 10, y: cos(wavePhase) * 5)
            )
    }
    
    private var morphingEffect: some View {
        modalShape
            .fill(morphingGradient)
            .scaleEffect(1.0 + sin(wavePhase) * 0.03)
            .mask(modalShape)
    }
    
    private var breathingEffect: some View {
        modalShape
            .fill(breathingGradient)
            .scaleEffect(1.0 + sin(wavePhase) * 0.02)
            .opacity(0.8 + sin(wavePhase) * 0.2)
            .mask(modalShape)
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
        30 * intensity
    }
    
    private var waveOpacity: Double {
        0.2 * intensity
    }
    
    private var interactiveOpacity: Double {
        isHovered ? 0.1 : 0
    }
    
    private var modalShadowRadius: CGFloat {
        20 * intensity
    }
    
    private var modalShadowOffset: CGSize {
        CGSize(width: 0, height: 10)
    }
    
    // MARK: - Presentation Methods
    
    private func present() {
        isPresented = true
        
        // Animate background
        withAnimation(.easeInOut(duration: 0.3)) {
            backgroundOpacity = 1.0
        }
        
        // Animate modal based on presentation style
        switch presentationStyle {
        case .center:
            presentCenter()
        case .fullscreen:
            presentFullscreen()
        case .sheet:
            presentSheet()
        case .bottom:
            presentBottom()
        }
        
        // Start animations
        startAnimations()
    }
    
    private func presentCenter() {
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            modalScale = 1.0
            modalOpacity = 1.0
            contentOffset = 0
        }
    }
    
    private func presentFullscreen() {
        withAnimation(.easeInOut(duration: 0.4)) {
            modalScale = 1.0
            modalOpacity = 1.0
            contentOffset = 0
        }
    }
    
    private func presentSheet() {
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            modalScale = 1.0
            modalOpacity = 1.0
            contentOffset = 0
        }
    }
    
    private func presentBottom() {
        contentOffset = UIScreen.main.bounds.height
        
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            modalScale = 1.0
            modalOpacity = 1.0
            contentOffset = 0
        }
    }
    
    private func dismiss() {
        HapticFeedbackManager.shared.lightImpact()
        
        // Animate background
        withAnimation(.easeInOut(duration: 0.3)) {
            backgroundOpacity = 0
        }
        
        // Animate modal based on presentation style
        switch presentationStyle {
        case .center:
            dismissCenter()
        case .fullscreen:
            dismissFullscreen()
        case .sheet:
            dismissSheet()
        case .bottom:
            dismissBottom()
        }
        
        // Call completion
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            onDismiss?()
        }
    }
    
    private func dismissCenter() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            modalScale = 0.8
            modalOpacity = 0
        }
    }
    
    private func dismissFullscreen() {
        withAnimation(.easeInOut(duration: 0.3)) {
            modalScale = 0.9
            modalOpacity = 0
        }
    }
    
    private func dismissSheet() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            modalScale = 0.9
            modalOpacity = 0
        }
    }
    
    private func dismissBottom() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            contentOffset = UIScreen.main.bounds.height
            modalOpacity = 0
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
    
    private func startShimmerAnimation() {
        withAnimation(
            .easeInOut(duration: variant.animationDuration)
            .repeatForever(autoreverses: true)
        ) {
            animationOffset = CGSize(width: 100, height: 100)
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

// MARK: - Glass Modal Variant

enum GlassModalVariant: CaseIterable {
    case minimal
    case standard
    case elevated
    case dramatic
    
    var shape: GlassModalShape {
        switch self {
        case .minimal:
            return .rounded
        case .standard:
            return .rounded
        case .elevated:
            return .rounded
        case .dramatic:
            return .rounded
        }
    }
    
    var cornerRadius: CGFloat {
        switch self {
        case .minimal:
            return 16
        case .standard:
            return 20
        case .elevated:
            return 24
        case .dramatic:
            return 32
        }
    }
    
    var blurRadius: CGFloat {
        switch self {
        case .minimal:
            return 8
        case .standard:
            return 12
        case .elevated:
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
        case .elevated:
            return 2
        case .dramatic:
            return 2.5
        }
    }
    
    var padding: EdgeInsets {
        switch self {
        case .minimal:
            return EdgeInsets(top: 20, leading: 24, bottom: 20, trailing: 24)
        case .standard:
            return EdgeInsets(top: 24, leading: 28, bottom: 24, trailing: 28)
        case .elevated:
            return EdgeInsets(top: 28, leading: 32, bottom: 28, trailing: 32)
        case .dramatic:
            return EdgeInsets(top: 32, leading: 36, bottom: 32, trailing: 36)
        }
    }
    
    var maxWidth: CGFloat? {
        switch self {
        case .minimal:
            return 320
        case .standard:
            return 400
        case .elevated:
            return 480
        case .dramatic:
            return 600
        }
    }
    
    var maxHeight: CGFloat? {
        switch self {
        case .minimal:
            return 400
        case .standard:
            return 500
        case .elevated:
            return 600
        case .dramatic:
            return 700
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
        case .dramatic:
            return 4.0
        }
    }
    
    var depthLayers: Int {
        switch self {
        case .minimal:
            return 2
        case .standard:
            return 3
        case .elevated:
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
        case .dramatic:
            return "Dramatic"
        }
    }
}

// MARK: - Glass Modal Shape

enum GlassModalShape: Equatable {
    case rounded
    case circular
    case capsule
    case custom(CGFloat)
    case asymmetric(AsymmetricCorners)
}

// MARK: - Asymmetric Corners

struct AsymmetricCorners: Equatable {
    let topLeading: CGFloat
    let topTrailing: CGFloat
    let bottomLeading: CGFloat
    let bottomTrailing: CGFloat
    
    static let all = AsymmetricCorners(
        topLeading: 20,
        topTrailing: 20,
        bottomLeading: 20,
        bottomTrailing: 20
    )
    
    static let topOnly = AsymmetricCorners(
        topLeading: 20,
        topTrailing: 20,
        bottomLeading: 0,
        bottomTrailing: 0
    )
}

// MARK: - Glass Modal Presentation Style

enum GlassModalPresentationStyle: CaseIterable {
    case center
    case fullscreen
    case sheet
    case bottom
    
    var name: String {
        switch self {
        case .center:
            return "Center"
        case .fullscreen:
            return "Fullscreen"
        case .sheet:
            return "Sheet"
        case .bottom:
            return "Bottom"
        }
    }
}

// MARK: - Glass Modal View Modifier

extension View {
    func glassModal<Content: View>(
        isPresented: Binding<Bool>,
        variant: GlassModalVariant = .standard,
        intensity: Double = 0.5,
        palette: LiquidGlassPalette? = nil,
        animationType: LiquidGlassAnimationType = .shimmer,
        presentationStyle: GlassModalPresentationStyle = .center,
        dismissOnBackgroundTap: Bool = true,
        onDismiss: (() -> Void)? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        self.overlay(
            Group {
                if isPresented.wrappedValue {
                    GlassModal(
                        variant: variant,
                        intensity: intensity,
                        palette: palette,
                        animationType: animationType,
                        presentationStyle: presentationStyle,
                        dismissOnBackgroundTap: dismissOnBackgroundTap,
                        onDismiss: {
                            isPresented.wrappedValue = false
                            onDismiss?()
                        },
                        content: content
                    )
                }
            }
        )
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        GlassButton("Show Modal") {
            // Modal would be shown here
        }
        
        Text("Glass Modal Components")
            .textStyle(TypographyPresets.Glass.title)
    }
    .padding()
    .background(DesignColors.background)
    .glassModal(
        isPresented: .constant(true),
        variant: .standard,
        intensity: 0.7,
        palette: .ocean,
        animationType: .wave,
        presentationStyle: .center
    ) {
        VStack(spacing: 20) {
            Text("Glass Modal")
                .textStyle(TypographyPresets.Glass.title)
            
            Text("This is a beautiful glass modal with blur effects and smooth animations.")
                .textStyle(TypographyPresets.Glass.body)
                .multilineTextAlignment(.center)
            
            GlassButton("Dismiss") {
                // Handle dismiss
            }
        }
    }
}