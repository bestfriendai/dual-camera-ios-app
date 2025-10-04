//
//  LiquidGlassComponents.swift
//  DualApp
//
//  Created by DualApp Team on 10/3/25.
//

import SwiftUI

// MARK: - Liquid Glass Components Index

// This file serves as a comprehensive index for all liquid glass components.
// Import this file to access all liquid glass components in your application.

// MARK: - Core Views

// Glass Container - Advanced liquid glass container with multiple variants and animations
public typealias GlassContainer = GlassContainerView<AnyView>

// Glass Button - Interactive glass button with haptic feedback and state animations
public typealias GlassButton = GlassButtonView<AnyView>

// Glass Card - Glass card with depth effects and interactive states
public typealias GlassCard = GlassCardView<AnyView>

// Glass Toolbar - Floating toolbar with glass effects and controls
public typealias GlassToolbar = GlassToolbarView<AnyView>

// Glass Modal - Modal with glass blur effects and smooth animations
public typealias GlassModal = GlassModalView<AnyView>

// MARK: - Camera Components

// Glass Camera Controls - Camera controls with liquid glass recording button
public typealias GlassCameraControls = GlassCameraControlsView

// Glass Preview Frame - Camera preview frame with animated borders
public typealias GlassPreviewFrame = GlassPreviewFrameView<AnyView>

// Glass Focus Ring - Focus ring with smooth animations and visual feedback
public typealias GlassFocusRing = GlassFocusRingView

// Glass Control Panel - Gesture-based control panel with glass effects
public typealias GlassControlPanel = GlassControlPanelView<AnyView>

// Glass Recording Indicator - Recording indicator with pulsing effects
public typealias GlassRecordingIndicator = GlassRecordingIndicatorView

// MARK: - Navigation Components

// Glass Tab Bar - Tab bar with smooth transitions and glass effects
public typealias GlassTabBar = GlassTabBarView<StandardTabItem>

// MARK: - Effects

// Glass Effects - Interactive glass effects (shimmer, ripple, particle, etc.)
public typealias GlassEffects = GlassEffectsView<AnyView>

// MARK: - Component Factories

public struct LiquidGlassComponents {
    
    // MARK: - Container Components
    
    public static func container<Content: View>(
        variant: GlassContainerVariant = .standard,
        intensity: Double = 0.5,
        palette: LiquidGlassPalette? = nil,
        animationType: LiquidGlassAnimationType = .shimmer,
        cornerStyle: GlassCornerStyle = .rounded,
        shadowStyle: GlassShadowStyle = .elevated,
        @ViewBuilder content: () -> Content
    ) -> some View {
        GlassContainerView(
            variant: variant,
            intensity: intensity,
            palette: palette,
            animationType: animationType,
            cornerStyle: cornerStyle,
            shadowStyle: shadowStyle,
            content: content
        )
    }
    
    public static func button<Label: View>(
        _ title: String? = nil,
        variant: GlassButtonVariant = .standard,
        size: GlassButtonSize = .medium,
        intensity: Double = 0.5,
        palette: LiquidGlassPalette? = nil,
        animationType: LiquidGlassAnimationType = .shimmer,
        hapticStyle: HapticStyle = .light,
        action: @escaping () -> Void,
        @ViewBuilder label: () -> Label
    ) -> some View {
        GlassButtonView(
            variant: variant,
            size: size,
            intensity: intensity,
            palette: palette,
            animationType: animationType,
            hapticStyle: hapticStyle,
            action: action,
            label: label
        )
    }
    
    public static func button(
        _ title: String,
        variant: GlassButtonVariant = .standard,
        size: GlassButtonSize = .medium,
        intensity: Double = 0.5,
        palette: LiquidGlassPalette? = nil,
        animationType: LiquidGlassAnimationType = .shimmer,
        hapticStyle: HapticStyle = .light,
        action: @escaping () -> Void
    ) -> some View {
        GlassButtonView(
            title: title,
            variant: variant,
            size: size,
            intensity: intensity,
            palette: palette,
            animationType: animationType,
            hapticStyle: hapticStyle,
            action: action
        )
    }
    
    public static func card<Content: View>(
        variant: GlassCardVariant = .standard,
        intensity: Double = 0.5,
        palette: LiquidGlassPalette? = nil,
        animationType: LiquidGlassAnimationType = .shimmer,
        shadowStyle: GlassCardShadowStyle = .elevated,
        cornerStyle: GlassCardCornerStyle = .rounded,
        isInteractive: Bool = false,
        @ViewBuilder content: () -> Content
    ) -> some View {
        GlassCardView(
            variant: variant,
            intensity: intensity,
            palette: palette,
            animationType: animationType,
            shadowStyle: shadowStyle,
            cornerStyle: cornerStyle,
            isInteractive: isInteractive,
            content: content
        )
    }
    
    public static func toolbar<Content: View>(
        variant: GlassToolbarVariant = .standard,
        intensity: Double = 0.5,
        palette: LiquidGlassPalette? = nil,
        animationType: LiquidGlassAnimationType = .shimmer,
        position: GlassToolbarPosition = .bottom,
        floatingStyle: GlassFloatingStyle = .standard,
        @ViewBuilder content: () -> Content
    ) -> some View {
        GlassToolbarView(
            variant: variant,
            intensity: intensity,
            palette: palette,
            animationType: animationType,
            position: position,
            floatingStyle: floatingStyle,
            content: content
        )
    }
    
    public static func modal<Content: View>(
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
        GlassModalView(
            variant: variant,
            intensity: intensity,
            palette: palette,
            animationType: animationType,
            presentationStyle: presentationStyle,
            dismissOnBackgroundTap: dismissOnBackgroundTap,
            onDismiss: onDismiss,
            content: content
        )
        .glassModal(
            isPresented: isPresented,
            variant: variant,
            intensity: intensity,
            palette: palette,
            animationType: animationType,
            presentationStyle: presentationStyle,
            dismissOnBackgroundTap: dismissOnBackgroundTap,
            onDismiss: onDismiss,
            content: content
        )
    }
    
    // MARK: - Camera Components
    
    public static func cameraControls(
        isRecording: Bool,
        isVideoMode: Bool,
        flashMode: FlashMode,
        cameraPosition: CameraPosition,
        intensity: Double = 0.5,
        palette: LiquidGlassPalette? = nil,
        onRecord: @escaping () -> Void,
        onStop: @escaping () -> Void,
        onCapture: @escaping () -> Void,
        onToggleFlash: @escaping () -> Void,
        onSwitchCamera: @escaping () -> Void
    ) -> some View {
        GlassCameraControlsView(
            isRecording: isRecording,
            isVideoMode: isVideoMode,
            flashMode: flashMode,
            cameraPosition: cameraPosition,
            intensity: intensity,
            palette: palette,
            onRecord: onRecord,
            onStop: onStop,
            onCapture: onCapture,
            onToggleFlash: onToggleFlash,
            onSwitchCamera: onSwitchCamera
        )
    }
    
    public static func previewFrame<Content: View>(
        variant: GlassPreviewFrameVariant = .standard,
        intensity: Double = 0.5,
        palette: LiquidGlassPalette? = nil,
        animationType: GlassPreviewFrameAnimationType = .shimmer,
        borderStyle: GlassBorderStyle = .solid,
        cornerStyle: GlassPreviewFrameCornerStyle = .rounded,
        @ViewBuilder content: () -> Content
    ) -> some View {
        GlassPreviewFrameView(
            variant: variant,
            intensity: intensity,
            palette: palette,
            animationType: animationType,
            borderStyle: borderStyle,
            cornerStyle: cornerStyle,
            content: content
        )
    }
    
    public static func focusRing(
        focusPoint: CGPoint = .center,
        isFocused: Bool = false,
        isAutoFocusing: Bool = false,
        intensity: Double = 0.5,
        palette: LiquidGlassPalette? = nil,
        variant: GlassFocusRingVariant = .standard,
        animationType: GlassFocusRingAnimationType = .pulse
    ) -> some View {
        GlassFocusRingView(
            focusPoint: focusPoint,
            isFocused: isFocused,
            isAutoFocusing: isAutoFocusing,
            intensity: intensity,
            palette: palette,
            variant: variant,
            animationType: animationType
        )
    }
    
    public static func focusRingContainer<Content: View>(
        intensity: Double = 0.5,
        palette: LiquidGlassPalette? = nil,
        variant: GlassFocusRingVariant = .standard,
        animationType: GlassFocusRingAnimationType = .pulse,
        @ViewBuilder content: () -> Content
    ) -> some View {
        GlassFocusRingContainer(
            intensity: intensity,
            palette: palette,
            variant: variant,
            animationType: animationType,
            content: content
        )
    }
    
    public static func controlPanel<Content: View>(
        variant: GlassControlPanelVariant = .standard,
        intensity: Double = 0.5,
        palette: LiquidGlassPalette? = nil,
        animationType: LiquidGlassAnimationType = .shimmer,
        position: GlassControlPanelPosition = .bottom,
        gestureStyle: GlassGestureStyle = .slide,
        @ViewBuilder content: () -> Content
    ) -> some View {
        GlassControlPanelView(
            variant: variant,
            intensity: intensity,
            palette: palette,
            animationType: animationType,
            position: position,
            gestureStyle: gestureStyle,
            content: content
        )
    }
    
    public static func recordingIndicator(
        isRecording: Bool,
        recordingTime: TimeInterval = 0,
        intensity: Double = 0.5,
        palette: LiquidGlassPalette? = nil,
        variant: GlassRecordingIndicatorVariant = .standard,
        animationType: GlassRecordingAnimationType = .pulse
    ) -> some View {
        GlassRecordingIndicatorView(
            isRecording: isRecording,
            recordingTime: recordingTime,
            intensity: intensity,
            palette: palette,
            variant: variant,
            animationType: animationType
        )
    }
    
    // MARK: - Navigation Components
    
    public static func tabBar<Tab: GlassTabItem>(
        tabs: [Tab],
        selectedTab: Binding<Tab.ID>,
        variant: GlassTabBarVariant = .standard,
        intensity: Double = 0.5,
        palette: LiquidGlassPalette? = nil,
        animationType: GlassTabBarAnimationType = .shimmer,
        position: GlassTabBarPosition = .bottom
    ) -> some View {
        GlassTabBarView(
            tabs: tabs,
            selectedTab: selectedTab,
            variant: variant,
            intensity: intensity,
            palette: palette,
            animationType: animationType,
            position: position
        )
    }
    
    // MARK: - Effects
    
    public static func effects<Content: View>(
        effectType: GlassEffectType,
        intensity: Double = 0.5,
        palette: LiquidGlassPalette? = nil,
        isEnabled: Bool = true,
        @ViewBuilder content: () -> Content
    ) -> some View {
        GlassEffectsView(
            effectType: effectType,
            intensity: intensity,
            palette: palette,
            isEnabled: isEnabled,
            content: content
        )
    }
    
    public static func effectsContainer<Content: View>(
        effects: [GlassEffectType],
        intensity: Double = 0.5,
        palette: LiquidGlassPalette? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        GlassEffectsContainer(
            effects: effects,
            intensity: intensity,
            palette: palette,
            content: content
        )
    }
}

// MARK: - View Extensions

extension View {
    public func liquidGlass<Content: View>(
        variant: GlassContainerVariant = .standard,
        intensity: Double = 0.5,
        palette: LiquidGlassPalette? = nil,
        animationType: LiquidGlassAnimationType = .shimmer,
        cornerStyle: GlassCornerStyle = .rounded,
        shadowStyle: GlassShadowStyle = .elevated,
        @ViewBuilder content: () -> Content
    ) -> some View {
        LiquidGlassComponents.container(
            variant: variant,
            intensity: intensity,
            palette: palette,
            animationType: animationType,
            cornerStyle: cornerStyle,
            shadowStyle: shadowStyle,
            content: content
        )
    }
    
    public func glassEffect(
        _ effectType: GlassEffectType,
        intensity: Double = 0.5,
        palette: LiquidGlassPalette? = nil,
        isEnabled: Bool = true
    ) -> some View {
        LiquidGlassComponents.effects(
            effectType: effectType,
            intensity: intensity,
            palette: palette,
            isEnabled: isEnabled
        ) {
            EmptyView()
        }
    }
}

// MARK: - Usage Examples

/*
 
 // Basic Glass Container
 LiquidGlassComponents.container(variant: .standard, intensity: 0.7) {
     Text("Hello, Liquid Glass!")
         .textStyle(TypographyPresets.Glass.title)
 }
 
 // Glass Button with Action
 LiquidGlassComponents.button(
     "Tap Me",
     variant: .elevated,
     size: .medium,
     palette: .ocean,
     animationType: .pulse
 ) {
     print("Button tapped!")
 }
 
 // Glass Card with Content
 LiquidGlassComponents.card(
     variant: .floating,
     intensity: 0.6,
     palette: .sunset,
     animationType: .shimmer,
     isInteractive: true
 ) {
     VStack {
         Text("Glass Card")
             .textStyle(TypographyPresets.Glass.title)
         
         Text("Interactive glass card with beautiful effects")
             .textStyle(TypographyPresets.Glass.body)
     }
 }
 
 // Glass Camera Controls
 LiquidGlassComponents.cameraControls(
     isRecording: true,
     isVideoMode: true,
     flashMode: .auto,
     cameraPosition: .back,
     intensity: 0.8,
     palette: .ocean,
     onRecord: { /* Start recording */ },
     onStop: { /* Stop recording */ },
     onCapture: { /* Capture photo */ },
     onToggleFlash: { /* Toggle flash */ },
     onSwitchCamera: { /* Switch camera */ }
 )
 
 // Glass Tab Bar
 struct ContentView: View {
     @State private var selectedTab = "home"
     
     var body: some View {
         VStack {
             Spacer()
             
             LiquidGlassComponents.tabBar(
                 tabs: [
                     StandardTabItem(id: "home", title: "Home", icon: "house.fill"),
                     StandardTabItem(id: "camera", title: "Camera", icon: "camera.fill"),
                     StandardTabItem(id: "gallery", title: "Gallery", icon: "photo.fill"),
                     StandardTabItem(id: "settings", title: "Settings", icon: "gearshape.fill")
                 ],
                 selectedTab: $selectedTab,
                 variant: .standard,
                 intensity: 0.7,
                 palette: .ocean,
                 animationType: .wave
             )
         }
     }
 }
 
 // Apply Glass Effect to Any View
 Text("Shimmer Effect")
     .glassEffect(.shimmer, intensity: 0.7)
 
 // Combined Effects
 Text("Multiple Effects")
     .glassEffect(.shimmer, intensity: 0.5)
     .glassEffect(.particles, intensity: 0.3)
 
 */