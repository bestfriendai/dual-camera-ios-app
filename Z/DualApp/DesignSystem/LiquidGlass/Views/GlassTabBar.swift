//
//  GlassTabBar.swift
//  DualApp
//
//  Created by DualApp Team on 10/3/25.
//

import SwiftUI

// MARK: - Glass Tab Bar

struct GlassTabBar<Tab: GlassTabItem>: View {
    // MARK: - Properties
    
    let tabs: [Tab]
    @Binding var selectedTab: Tab.ID
    let variant: GlassTabBarVariant
    let intensity: Double
    let palette: LiquidGlassPalette?
    let animationType: GlassTabBarAnimationType
    let position: GlassTabBarPosition
    
    // MARK: - State
    
    @State private var animationOffset: CGSize = .zero
    @State private var isAnimating = false
    @State private var shimmerRotation: Double = 0
    @State private var pulseScale: CGFloat = 1.0
    @State private var glowIntensity: Double = 0.2
    @State private var wavePhase: Double = 0
    @State private var indicatorPosition: CGFloat = 0
    @State private var indicatorWidth: CGFloat = 0
    @State private var isHovered = false
    @State private var hoveredTab: Tab.ID? = nil
    @State private var tabPositions: [Tab.ID: CGFloat] = [:]
    @State private var tabWidths: [Tab.ID: CGFloat] = [:]
    
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
            
            // Tab indicator
            tabIndicator
            
            // Tabs
            tabsView
        }
        .frame(height: variant.height)
        .background(
            GeometryReader { geometry in
                Color.clear
                    .onAppear {
                        updateTabLayout(geometry: geometry)
                    }
                    .onChange(of: geometry.size) { _ in
                        updateTabLayout(geometry: geometry)
                    }
            }
        )
        .onAppear {
            startAnimations()
        }
        .onDisappear {
            stopAnimations()
        }
        .onChange(of: selectedTab) { _ in
            updateIndicatorPosition()
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Tab bar")
    }
    
    // MARK: - View Components
    
    private var backgroundLayers: some View {
        ZStack {
            // Base blur effect
            tabBarShape
                .fill(baseBackgroundColor)
                .background(
                    tabBarShape
                        .fill(backgroundGradient)
                )
                .blur(radius: variant.blurRadius * intensity)
            
            // Depth layers
            ForEach(0..<variant.depthLayers, id: \.self) { index in
                tabBarShape
                    .fill(depthLayerColor(for: index))
                    .offset(depthLayerOffset(for: index))
                    .blur(radius: depthLayerBlur(for: index))
            }
        }
    }
    
    private var glassSurface: some View {
        ZStack {
            tabBarShape
                .fill(surfaceGradient)
                .overlay(
                    // Surface highlights
                    tabBarShape
                        .fill(surfaceHighlightGradient)
                        .opacity(surfaceHighlightOpacity)
                )
                .overlay(
                    // Border
                    tabBarShape
                        .stroke(borderGradient, lineWidth: variant.borderWidth)
                )
                .shadow(
                    color: shadowColor,
                    radius: shadowRadius,
                    x: shadowOffset.width,
                    y: shadowOffset.height
                )
            
            // Reflection layer
            tabBarShape
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
            }
        }
    }
    
    private var interactiveEffects: some View {
        tabBarShape
            .fill(interactiveOverlay)
            .opacity(interactiveOpacity)
            .animation(.easeInOut(duration: 0.2), value: isHovered)
    }
    
    private var tabIndicator: some View {
        ZStack {
            // Indicator background
            RoundedRectangle(cornerRadius: variant.indicatorCornerRadius)
                .fill(indicatorGradient)
                .frame(width: indicatorWidth, height: variant.indicatorHeight)
                .position(x: indicatorPosition, y: position.indicatorY)
            
            // Indicator glow
            if variant.indicatorGlow {
                RoundedRectangle(cornerRadius: variant.indicatorCornerRadius)
                    .fill(indicatorGlowGradient)
                    .frame(width: indicatorWidth, height: variant.indicatorHeight)
                    .position(x: indicatorPosition, y: position.indicatorY)
                    .blur(radius: 8)
                    .opacity(0.5)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: indicatorPosition)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: indicatorWidth)
    }
    
    private var tabsView: some View {
        HStack(spacing: 0) {
            ForEach(tabs, id: \.id) { tab in
                tabItemView(for: tab)
                    .background(
                        GeometryReader { geometry in
                            Color.clear
                                .onAppear {
                                    tabPositions[tab.id] = geometry.frame(in: .local).midX
                                    tabWidths[tab.id] = geometry.size.width
                                }
                                .onChange(of: geometry.size) { _ in
                                    tabPositions[tab.id] = geometry.frame(in: .local).midX
                                    tabWidths[tab.id] = geometry.size.width
                                }
                        }
                    )
            }
        }
        .padding(.horizontal, variant.padding)
        .padding(.vertical, variant.verticalPadding)
    }
    
    private func tabItemView(for tab: Tab) -> some View {
        Button(action: {
            selectTab(tab)
        }) {
            tab.content
                .opacity(isSelected(tab.id) ? 1.0 : 0.7)
                .scaleEffect(isSelected(tab.id) ? 1.05 : 1.0)
                .animation(.easeInOut(duration: 0.2), value: isSelected(tab.id))
        }
        .buttonStyle(PlainButtonStyle())
        .background(
            // Hover effect
            RoundedRectangle(cornerRadius: variant.tabCornerRadius)
                .fill(hoverGradient)
                .opacity(isHovered(tab.id) ? 0.1 : 0)
                .animation(.easeInOut(duration: 0.2), value: isHovered(tab.id))
        )
        .onHover { hovering in
            if hovering {
                hoveredTab = tab.id
            } else if hoveredTab == tab.id {
                hoveredTab = nil
            }
        }
        .accessibilityLabel(tab.title)
        .accessibilityAddTraits(isSelected(tab.id) ? .isSelected : [])
        .accessibilityRemoveTraits(isSelected(tab.id) ? [] : .isSelected)
    }
    
    // MARK: - Shape Components
    
    private var tabBarShape: some Shape {
        switch position {
        case .top, .bottom:
            return RoundedRectangle(cornerRadius: variant.cornerRadius)
        case .leading, .trailing:
            return RoundedRectangle(cornerRadius: variant.cornerRadius)
        }
    }
    
    private var reflectionMask: some Shape {
        RoundedRectangle(cornerRadius: variant.cornerRadius)
            .path(in: CGRect(x: 0, y: 0, width: 400, height: variant.height / 3))
            .offset(y: -variant.height / 6)
    }
    
    // MARK: - Animation Components
    
    private var shimmerEffect: some View {
        tabBarShape
            .fill(shimmerGradient)
            .offset(animationOffset)
            .rotationEffect(.degrees(shimmerRotation))
            .mask(tabBarShape)
    }
    
    private var pulseEffect: some View {
        tabBarShape
            .fill(pulseGradient)
            .scaleEffect(pulseScale)
            .opacity(pulseOpacity)
            .mask(tabBarShape)
    }
    
    private var glowEffect: some View {
        tabBarShape
            .fill(glowGradient)
            .opacity(glowIntensity)
            .blur(radius: glowBlurRadius)
            .mask(tabBarShape)
    }
    
    private var waveEffect: some View {
        tabBarShape
            .fill(waveGradient)
            .opacity(waveOpacity)
            .mask(
                tabBarShape
                    .offset(x: sin(wavePhase) * 10, y: cos(wavePhase) * 5)
            )
    }
    
    private var breathingEffect: some View {
        tabBarShape
            .fill(breathingGradient)
            .scaleEffect(1.0 + sin(wavePhase) * 0.01)
            .opacity(0.95 + sin(wavePhase) * 0.05)
            .mask(tabBarShape)
    }
    
    // MARK: - Helper Methods
    
    private func isSelected(_ tabId: Tab.ID) -> Bool {
        return selectedTab == tabId
    }
    
    private func isHovered(_ tabId: Tab.ID) -> Bool {
        return hoveredTab == tabId
    }
    
    private func selectTab(_ tab: Tab) {
        selectedTab = tab.id
        HapticFeedbackManager.shared.selectionChanged()
    }
    
    private func updateTabLayout(geometry: GeometryProxy) {
        // Update tab positions and widths
        // This would be called when the layout changes
    }
    
    private func updateIndicatorPosition() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            indicatorPosition = tabPositions[selectedTab] ?? 0
            indicatorWidth = tabWidths[selectedTab] ?? 0
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
    
    private var indicatorGradient: LinearGradient {
        let accentColor = palette?.accentColor ?? .blue
        
        return LinearGradient(
            colors: [
                accentColor.opacity(0.8 * intensity),
                accentColor.opacity(0.6 * intensity),
                accentColor.opacity(0.4 * intensity)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    private var indicatorGlowGradient: RadialGradient {
        let accentColor = palette?.accentColor ?? .blue
        
        return RadialGradient(
            colors: [
                accentColor.opacity(0.6 * intensity),
                accentColor.opacity(0.3 * intensity),
                accentColor.opacity(0)
            ],
            center: .center,
            startRadius: 5,
            endRadius: 20
        )
    }
    
    private var hoverGradient: RadialGradient {
        let accentColor = palette?.accentColor ?? .blue
        
        return RadialGradient(
            colors: [
                accentColor.opacity(0.3 * intensity),
                accentColor.opacity(0.15 * intensity),
                accentColor.opacity(0)
            ],
            center: .center,
            startRadius: 5,
            endRadius: 20
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
    
    private var shadowColor: Color {
        LiquidGlassColors.glassShadow.opacity(0.3 * intensity)
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
    }
    
    private func stopAnimations() {
        isAnimating = false
    }
    
    private func startShimmerAnimation() {
        withAnimation(
            .easeInOut(duration: variant.animationDuration)
            .repeatForever(autoreverses: true)
        ) {
            animationOffset = CGSize(width: 200, height: 0)
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

// MARK: - Glass Tab Bar Variant

enum GlassTabBarVariant: CaseIterable {
    case minimal
    case standard
    case elevated
    case dramatic
    
    var height: CGFloat {
        switch self {
        case .minimal:
            return 50
        case .standard:
            return 60
        case .elevated:
            return 70
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
        case .dramatic:
            return 24
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
        case .dramatic:
            return 16
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
        case .dramatic:
            return 2
        }
    }
    
    var padding: CGFloat {
        switch self {
        case .minimal:
            return 16
        case .standard:
            return 20
        case .elevated:
            return 24
        case .dramatic:
            return 28
        }
    }
    
    var verticalPadding: CGFloat {
        switch self {
        case .minimal:
            return 8
        case .standard:
            return 10
        case .elevated:
            return 12
        case .dramatic:
            return 14
        }
    }
    
    var tabCornerRadius: CGFloat {
        switch self {
        case .minimal:
            return 6
        case .standard:
            return 8
        case .elevated:
            return 10
        case .dramatic:
            return 12
        }
    }
    
    var indicatorHeight: CGFloat {
        switch self {
        case .minimal:
            return 3
        case .standard:
            return 4
        case .elevated:
            return 5
        case .dramatic:
            return 6
        }
    }
    
    var indicatorCornerRadius: CGFloat {
        switch self {
        case .minimal:
            return 1.5
        case .standard:
            return 2
        case .elevated:
            return 2.5
        case .dramatic:
            return 3
        }
    }
    
    var indicatorGlow: Bool {
        switch self {
        case .minimal:
            return false
        case .standard:
            return true
        case .elevated:
            return true
        case .dramatic:
            return true
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
            return 1
        case .standard:
            return 2
        case .elevated:
            return 3
        case .dramatic:
            return 4
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

// MARK: - Glass Tab Bar Animation Type

enum GlassTabBarAnimationType: CaseIterable {
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

// MARK: - Glass Tab Bar Position

enum GlassTabBarPosition: CaseIterable {
    case top
    case bottom
    case leading
    case trailing
    
    var indicatorY: CGFloat {
        switch self {
        case .top:
            return -5
        case .bottom:
            return 5
        case .leading:
            return 0
        case .trailing:
            return 0
        }
    }
    
    var name: String {
        switch self {
        case .top:
            return "Top"
        case .bottom:
            return "Bottom"
        case .leading:
            return "Leading"
        case .trailing:
            return "Trailing"
        }
    }
}

// MARK: - Glass Tab Item Protocol

protocol GlassTabItem: Identifiable {
    associatedtype ID: Hashable
    var id: ID { get }
    var title: String { get }
    var content: AnyView { get }
}

// MARK: - Standard Tab Item

struct StandardTabItem: GlassTabItem {
    let id: String
    let title: String
    let icon: String
    let content: AnyView
    
    init(id: String, title: String, icon: String) {
        self.id = id
        self.title = title
        self.icon = icon
        self.content = AnyView(
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                
                Text(title)
                    .font(.system(size: 10, weight: .medium))
            }
            .foregroundColor(DesignColors.textOnGlass)
        )
    }
}

// MARK: - Preview

#Preview {
    VStack {
        Spacer()
        
        GlassTabBar(
            tabs: [
                StandardTabItem(id: "home", title: "Home", icon: "house.fill"),
                StandardTabItem(id: "camera", title: "Camera", icon: "camera.fill"),
                StandardTabItem(id: "gallery", title: "Gallery", icon: "photo.fill"),
                StandardTabItem(id: "settings", title: "Settings", icon: "gearshape.fill")
            ],
            selectedTab: .constant("camera"),
            variant: .standard,
            intensity: 0.7,
            palette: .ocean,
            animationType: .wave,
            position: .bottom
        )
    }
    .background(DesignColors.background)
}