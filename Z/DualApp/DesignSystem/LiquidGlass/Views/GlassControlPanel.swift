//
//  GlassControlPanel.swift
//  DualApp
//
//  Created by DualApp Team on 10/3/25.
//

import SwiftUI

// MARK: - Glass Control Panel

struct GlassControlPanel<Content: View>: View {
    // MARK: - Properties
    
    let content: Content
    let variant: GlassControlPanelVariant
    let intensity: Double
    let palette: LiquidGlassPalette?
    let animationType: LiquidGlassAnimationType
    let position: GlassControlPanelPosition
    let gestureStyle: GlassGestureStyle
    
    // MARK: - State
    
    @State private var animationOffset: CGSize = .zero
    @State private var isAnimating = false
    @State private var shimmerRotation: Double = 0
    @State private var pulseScale: CGFloat = 1.0
    @State private var glowIntensity: Double = 0.2
    @State private var wavePhase: Double = 0
    @State private var isHovered = false
    @State private var isPressed = false
    @State private var panelOffset: CGSize = .zero
    @State private var panelScale: CGFloat = 1.0
    @State private var panelOpacity: Double = 1.0
    @State private var isExpanded = false
    @State private var dragOffset: CGSize = .zero
    @State private var isDragging = false
    @State private var gestureProgress: Double = 0.0
    @State private var lastPanLocation: CGPoint = .zero
    @State private var panVelocity: CGPoint = .zero
    
    // MARK: - Initialization
    
    init(
        variant: GlassControlPanelVariant = .standard,
        intensity: Double = 0.5,
        palette: LiquidGlassPalette? = nil,
        animationType: LiquidGlassAnimationType = .shimmer,
        position: GlassControlPanelPosition = .bottom,
        gestureStyle: GlassGestureStyle = .slide,
        @ViewBuilder content: () -> Content
    ) {
        self.variant = variant
        self.intensity = intensity
        self.palette = palette
        self.animationType = animationType
        self.position = position
        self.gestureStyle = gestureStyle
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
            
            // Gesture indicator
            if isDragging {
                gestureIndicator
            }
            
            // Content
            content
                .padding(variant.padding)
                .scaleEffect(panelScale)
                .opacity(panelOpacity)
        }
        .frame(width: panelWidth, height: panelHeight)
        .clipShape(panelShape)
        .offset(panelOffset + dragOffset)
        .scaleEffect(isExpanded ? 1.05 : 1.0)
        .shadow(
            color: shadowColor,
            radius: shadowRadius,
            x: shadowOffset.width,
            y: shadowOffset.height
        )
        .onAppear {
            startAnimations()
        }
        .onDisappear {
            stopAnimations()
        }
        .gesture(
            combinedGesture
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilityLabel)
    }
    
    // MARK: - View Components
    
    private var backgroundLayers: some View {
        ZStack {
            // Base blur effect
            panelShape
                .fill(baseBackgroundColor)
                .background(
                    panelShape
                        .fill(backgroundGradient)
                )
                .blur(radius: variant.blurRadius * intensity)
            
            // Depth layers
            ForEach(0..<variant.depthLayers, id: \.self) { index in
                panelShape
                    .fill(depthLayerColor(for: index))
                    .offset(depthLayerOffset(for: index))
                    .blur(radius: depthLayerBlur(for: index))
            }
        }
    }
    
    private var glassSurface: some View {
        ZStack {
            panelShape
                .fill(surfaceGradient)
                .overlay(
                    // Surface highlights
                    panelShape
                        .fill(surfaceHighlightGradient)
                        .opacity(surfaceHighlightOpacity)
                )
                .overlay(
                    // Border
                    panelShape
                        .stroke(borderGradient, lineWidth: variant.borderWidth)
                )
            
            // Reflection layer
            panelShape
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
            panelShape
                .fill(interactiveOverlay)
                .opacity(interactiveOpacity)
                .animation(.easeInOut(duration: 0.2), value: isHovered)
            
            // Hover glow
            if isHovered {
                panelShape
                    .fill(hoverGlowGradient)
                    .opacity(0.1 * intensity)
                    .blur(radius: 15)
            }
        }
    }
    
    private var gestureIndicator: some View {
        ZStack {
            // Gesture trail
            ForEach(0..<5, id: \.self) { index in
                Circle()
                    .fill(gestureIndicatorColor)
                    .frame(width: 8 - CGFloat(index) * 1.5, height: 8 - CGFloat(index) * 1.5)
                    .position(gestureTrailPosition(for: index))
                    .opacity(0.6 - Double(index) * 0.1)
            }
        }
    }
    
    // MARK: - Shape Components
    
    private var panelShape: some Shape {
        switch position {
        case .top, .bottom:
            return RoundedRectangle(cornerRadius: variant.cornerRadius)
        case .left, .right:
            return RoundedRectangle(cornerRadius: variant.cornerRadius)
        case .floating:
            return RoundedRectangle(cornerRadius: variant.cornerRadius)
        }
    }
    
    private var reflectionMask: some Shape {
        RoundedRectangle(cornerRadius: variant.cornerRadius)
            .path(in: CGRect(x: 0, y: 0, width: panelWidth, height: panelHeight / 3))
            .offset(y: -panelHeight / 6)
    }
    
    // MARK: - Layout Components
    
    private var panelWidth: CGFloat {
        switch position {
        case .top, .bottom:
            return UIScreen.main.bounds.width - 40
        case .left, .right:
            return variant.width
        case .floating:
            return variant.width
        }
    }
    
    private var panelHeight: CGFloat {
        switch position {
        case .top, .bottom:
            return variant.height
        case .left, .right:
            return UIScreen.main.bounds.height - 100
        case .floating:
            return variant.height
        }
    }
    
    // MARK: - Gesture Handling
    
    private var combinedGesture: some Gesture {
        switch gestureStyle {
        case .slide:
            return slideGesture
        case .pan:
            return panGesture
        case .pinch:
            return pinchGesture
        case .rotate:
            return rotateGesture
        case .tap:
            return tapGesture
        case .longPress:
            return longPressGesture
        }
    }
    
    private var slideGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                handleSlideChanged(value)
            }
            .onEnded { value in
                handleSlideEnded(value)
            }
    }
    
    private var panGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                handlePanChanged(value)
            }
            .onEnded { value in
                handlePanEnded(value)
            }
    }
    
    private var pinchGesture: some Gesture {
        MagnificationGesture()
            .onChanged { scale in
                handlePinchChanged(scale)
            }
            .onEnded { scale in
                handlePinchEnded(scale)
            }
    }
    
    private var rotateGesture: some Gesture {
        RotationGesture()
            .onChanged { angle in
                handleRotateChanged(angle)
            }
            .onEnded { angle in
                handleRotateEnded(angle)
            }
    }
    
    private var tapGesture: some Gesture {
        TapGesture(count: 2)
            .onEnded {
                handleTap()
            }
    }
    
    private var longPressGesture: some Gesture {
        LongPressGesture(minimumDuration: 0.5)
            .onChanged { _ in
                handleLongPressChanged()
            }
            .onEnded { _ in
                handleLongPressEnded()
            }
    }
    
    // MARK: - Gesture Handlers
    
    private func handleSlideChanged(_ value: DragGesture.Value) {
        isDragging = true
        lastPanLocation = value.location
        
        switch position {
        case .bottom:
            dragOffset = CGSize(width: 0, height: min(0, value.translation.y))
        case .top:
            dragOffset = CGSize(width: 0, height: max(0, value.translation.y))
        case .left:
            dragOffset = CGSize(width: max(0, value.translation.x), height: 0)
        case .right:
            dragOffset = CGSize(width: min(0, value.translation.x), height: 0)
        case .floating:
            dragOffset = value.translation
        }
        
        gestureProgress = gestureProgressFromOffset()
        
        HapticFeedbackManager.shared.lightImpact()
    }
    
    private func handleSlideEnded(_ value: DragGesture.Value) {
        isDragging = false
        
        let threshold: CGFloat = 50
        let shouldDismiss = shouldDismissFromOffset(threshold: threshold)
        
        if shouldDismiss {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                panelOpacity = 0
                panelScale = 0.8
                
                switch position {
                case .bottom:
                    dragOffset = CGSize(width: 0, height: panelHeight)
                case .top:
                    dragOffset = CGSize(width: 0, height: -panelHeight)
                case .left:
                    dragOffset = CGSize(width: -panelWidth, height: 0)
                case .right:
                    dragOffset = CGSize(width: panelWidth, height: 0)
                case .floating:
                    dragOffset = value.translation * 2
                }
            }
        } else {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                dragOffset = .zero
            }
        }
        
        gestureProgress = 0
    }
    
    private func handlePanChanged(_ value: DragGesture.Value) {
        isDragging = true
        lastPanLocation = value.location
        panVelocity = value.predictedEndLocation
        
        dragOffset = value.translation
        gestureProgress = min(1.0, value.translation.magnitude / 100)
        
        HapticFeedbackManager.shared.lightImpact()
    }
    
    private func handlePanEnded(_ value: DragGesture.Value) {
        isDragging = false
        
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            dragOffset = .zero
        }
        
        gestureProgress = 0
    }
    
    private func handlePinchChanged(_ scale: CGFloat) {
        panelScale = max(0.5, min(2.0, scale))
        gestureProgress = (scale - 1.0) / 1.0
        
        HapticFeedbackManager.shared.mediumImpact()
    }
    
    private func handlePinchEnded(_ scale: CGFloat) {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            panelScale = 1.0
        }
        
        gestureProgress = 0
    }
    
    private func handleRotateChanged(_ angle: Angle) {
        // Handle rotation if needed
        gestureProgress = abs(angle.degrees) / 180.0
        
        HapticFeedbackManager.shared.lightImpact()
    }
    
    private func handleRotateEnded(_ angle: Angle) {
        gestureProgress = 0
    }
    
    private func handleTap() {
        isExpanded.toggle()
        
        HapticFeedbackManager.shared.mediumImpact()
        
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            panelScale = isExpanded ? 1.05 : 1.0
        }
    }
    
    private func handleLongPressChanged() {
        HapticFeedbackManager.shared.heavyImpact()
        
        withAnimation(.easeInOut(duration: 0.2)) {
            glowIntensity = 0.6
        }
    }
    
    private func handleLongPressEnded() {
        withAnimation(.easeInOut(duration: 0.3)) {
            glowIntensity = 0.2
        }
    }
    
    // MARK: - Helper Methods
    
    private func gestureProgressFromOffset() -> Double {
        switch position {
        case .bottom:
            return min(1.0, abs(dragOffset.height) / panelHeight)
        case .top:
            return min(1.0, abs(dragOffset.height) / panelHeight)
        case .left:
            return min(1.0, abs(dragOffset.width) / panelWidth)
        case .right:
            return min(1.0, abs(dragOffset.width) / panelWidth)
        case .floating:
            return min(1.0, dragOffset.magnitude / 100)
        }
    }
    
    private func shouldDismissFromOffset(threshold: CGFloat) -> Bool {
        switch position {
        case .bottom:
            return dragOffset.height < -threshold
        case .top:
            return dragOffset.height > threshold
        case .left:
            return dragOffset.width > threshold
        case .right:
            return dragOffset.width < -threshold
        case .floating:
            return dragOffset.magnitude > threshold
        }
    }
    
    private func gestureTrailPosition(for index: Int) -> CGPoint {
        let trailLength: CGFloat = 50
        let offset = CGFloat(index) * 10
        
        switch position {
        case .bottom:
            return CGPoint(
                x: lastPanLocation.x,
                y: lastPanLocation.y + offset
            )
        case .top:
            return CGPoint(
                x: lastPanLocation.x,
                y: lastPanLocation.y - offset
            )
        case .left:
            return CGPoint(
                x: lastPanLocation.x - offset,
                y: lastPanLocation.y
            )
        case .right:
            return CGPoint(
                x: lastPanLocation.x + offset,
                y: lastPanLocation.y
            )
        case .floating:
            return CGPoint(
                x: lastPanLocation.x + panVelocity.x * CGFloat(index) * 0.1,
                y: lastPanLocation.y + panVelocity.y * CGFloat(index) * 0.1
            )
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
    
    private var gestureIndicatorColor: Color {
        palette?.accentColor ?? .white
    }
    
    private var shadowColor: Color {
        LiquidGlassColors.glassShadow.opacity(0.3 * intensity)
    }
    
    private var accessibilityLabel: String {
        switch position {
        case .top:
            return "Top control panel"
        case .bottom:
            return "Bottom control panel"
        case .left:
            return "Left control panel"
        case .right:
            return "Right control panel"
        case .floating:
            return "Floating control panel"
        }
    }
    
    // MARK: - Animation Components
    
    private var shimmerEffect: some View {
        panelShape
            .fill(shimmerGradient)
            .offset(animationOffset)
            .rotationEffect(.degrees(shimmerRotation))
            .mask(panelShape)
    }
    
    private var pulseEffect: some View {
        panelShape
            .fill(pulseGradient)
            .scaleEffect(pulseScale)
            .opacity(pulseOpacity)
            .mask(panelShape)
    }
    
    private var glowEffect: some View {
        panelShape
            .fill(glowGradient)
            .opacity(glowIntensity)
            .blur(radius: glowBlurRadius)
            .mask(panelShape)
    }
    
    private var waveEffect: some View {
        panelShape
            .fill(waveGradient)
            .opacity(waveOpacity)
            .mask(
                panelShape
                    .offset(x: sin(wavePhase) * 10, y: cos(wavePhase) * 5)
            )
    }
    
    private var breathingEffect: some View {
        panelShape
            .fill(breathingGradient)
            .scaleEffect(1.0 + sin(wavePhase) * 0.02)
            .opacity(0.9 + sin(wavePhase) * 0.1)
            .mask(panelShape)
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
        if isPressed {
            return 0.2
        } else if isHovered {
            return 0.1
        } else {
            return 0
        }
    }
    
    private var shadowRadius: CGFloat {
        12 * intensity
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
    }
    
    private func stopAnimations() {
        isAnimating = false
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

// MARK: - Glass Control Panel Variant

enum GlassControlPanelVariant: CaseIterable {
    case minimal
    case standard
    case expanded
    case dramatic
    
    var width: CGFloat {
        switch self {
        case .minimal:
            return 300
        case .standard:
            return 350
        case .expanded:
            return 400
        case .dramatic:
            return 450
        }
    }
    
    var height: CGFloat {
        switch self {
        case .minimal:
            return 120
        case .standard:
            return 160
        case .expanded:
            return 200
        case .dramatic:
            return 240
        }
    }
    
    var cornerRadius: CGFloat {
        switch self {
        case .minimal:
            return 16
        case .standard:
            return 20
        case .expanded:
            return 24
        case .dramatic:
            return 28
        }
    }
    
    var blurRadius: CGFloat {
        switch self {
        case .minimal:
            return 8
        case .standard:
            return 12
        case .expanded:
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
        case .expanded:
            return 2
        case .dramatic:
            return 2.5
        }
    }
    
    var padding: EdgeInsets {
        switch self {
        case .minimal:
            return EdgeInsets(top: 16, leading: 20, bottom: 16, trailing: 20)
        case .standard:
            return EdgeInsets(top: 20, leading: 24, bottom: 20, trailing: 24)
        case .expanded:
            return EdgeInsets(top: 24, leading: 28, bottom: 24, trailing: 28)
        case .dramatic:
            return EdgeInsets(top: 28, leading: 32, bottom: 28, trailing: 32)
        }
    }
    
    var animationDuration: Double {
        switch self {
        case .minimal:
            return 2.5
        case .standard:
            return 3.0
        case .expanded:
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
        case .expanded:
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
        case .expanded:
            return "Expanded"
        case .dramatic:
            return "Dramatic"
        }
    }
}

// MARK: - Glass Control Panel Position

enum GlassControlPanelPosition: CaseIterable {
    case top
    case bottom
    case left
    case right
    case floating
    
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
        case .floating:
            return "Floating"
        }
    }
}

// MARK: - Glass Gesture Style

enum GlassGestureStyle: CaseIterable {
    case slide
    case pan
    case pinch
    case rotate
    case tap
    case longPress
    
    var name: String {
        switch self {
        case .slide:
            return "Slide"
        case .pan:
            return "Pan"
        case .pinch:
            return "Pinch"
        case .rotate:
            return "Rotate"
        case .tap:
            return "Tap"
        case .longPress:
            return "Long Press"
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black
        
        VStack {
            Spacer()
            
            GlassControlPanel(
                variant: .standard,
                intensity: 0.7,
                palette: .ocean,
                animationType: .wave,
                position: .bottom,
                gestureStyle: .slide
            ) {
                HStack(spacing: 20) {
                    GlassButton("Zoom", variant: .minimal, size: .small) {}
                    GlassButton("Focus", variant: .minimal, size: .small) {}
                    GlassButton("Exposure", variant: .minimal, size: .small) {}
                    GlassButton("White Balance", variant: .minimal, size: .small) {}
                }
            }
        }
        .padding(.bottom, 50)
    }
    .ignoresSafeArea()
}