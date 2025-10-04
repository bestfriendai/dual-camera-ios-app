# Liquid Glass Design System

A comprehensive, modern glassmorphism design system for SwiftUI applications, featuring advanced liquid glass effects, smooth animations, and interactive components.

## Overview

The Liquid Glass Design System provides a set of highly customizable, reusable UI components that create beautiful glass-like interfaces with depth, blur, and transparency effects. It's designed specifically for camera applications but can be used in any SwiftUI project.

## Features

- **Advanced Glass Effects**: Multiple glass variants with customizable blur, transparency, and depth
- **Rich Animations**: Shimmer, pulse, glow, wave, breathing, and morphing effects
- **Interactive Components**: Touch-responsive controls with haptic feedback
- **Camera-Specific Components**: Specialized components for camera interfaces
- **Accessibility Support**: Full VoiceOver and accessibility features
- **Performance Optimized**: Efficient rendering with fallbacks for older devices
- **Customizable Palettes**: Pre-defined color palettes with easy customization

## Components

### Core Components

#### GlassContainer
A versatile glass container with multiple variants and animation effects.

```swift
LiquidGlassComponents.container(
    variant: .standard,
    intensity: 0.7,
    palette: .ocean,
    animationType: .shimmer
) {
    Text("Hello, Liquid Glass!")
        .textStyle(TypographyPresets.Glass.title)
}
```

**Variants**: `.minimal`, `.standard`, `.elevated`, `.floating`, `.immersive`, `.dramatic`

**Animation Types**: `.shimmer`, `.pulse`, `.glow`, `.wave`, `.morphing`, `.breathing`

#### GlassButton
Interactive glass button with haptic feedback and state animations.

```swift
LiquidGlassComponents.button(
    "Tap Me",
    variant: .elevated,
    size: .medium,
    palette: .ocean,
    animationType: .pulse
) {
    print("Button tapped!")
}
```

**Variants**: `.minimal`, `.standard`, `.elevated`, `.floating`, `.dramatic`

**Sizes**: `.small`, `.medium`, `.large`, `.extraLarge`

#### GlassCard
Glass card with depth effects and interactive states.

```swift
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
```

#### GlassToolbar
Floating toolbar with glass effects and controls.

```swift
LiquidGlassComponents.toolbar(
    variant: .elevated,
    intensity: 0.7,
    palette: .ocean,
    animationType: .wave,
    position: .bottom
) {
    HStack {
        // Toolbar content
    }
}
```

#### GlassModal
Modal with glass blur effects and smooth animations.

```swift
LiquidGlassComponents.modal(
    isPresented: $showModal,
    variant: .standard,
    intensity: 0.7,
    palette: .ocean,
    presentationStyle: .center
) {
    Text("Modal Content")
}
```

### Camera Components

#### GlassCameraControls
Camera controls with liquid glass recording button.

```swift
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
```

#### GlassPreviewFrame
Camera preview frame with animated borders.

```swift
LiquidGlassComponents.previewFrame(
    variant: .cinematic,
    intensity: 0.7,
    palette: .ocean,
    animationType: .wave,
    borderStyle: .neon
) {
    // Preview content
}
```

#### GlassFocusRing
Focus ring with smooth animations and visual feedback.

```swift
LiquidGlassComponents.focusRing(
    focusPoint: .center,
    isFocused: true,
    intensity: 0.7,
    palette: .ocean,
    variant: .cinematic,
    animationType: .pulse
)
```

#### GlassControlPanel
Gesture-based control panel with glass effects.

```swift
LiquidGlassComponents.controlPanel(
    variant: .standard,
    intensity: 0.7,
    palette: .ocean,
    gestureStyle: .slide
) {
    HStack {
        // Control content
    }
}
```

#### GlassRecordingIndicator
Recording indicator with pulsing effects.

```swift
LiquidGlassComponents.recordingIndicator(
    isRecording: true,
    recordingTime: 65,
    intensity: 0.7,
    variant: .prominent,
    animationType: .pulse
)
```

### Navigation Components

#### GlassTabBar
Tab bar with smooth transitions and glass effects.

```swift
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
```

### Effects

#### GlassEffects
Interactive glass effects that can be applied to any view.

```swift
LiquidGlassComponents.effects(
    effectType: .shimmer,
    intensity: 0.7,
    palette: .ocean
) {
    Text("Shimmer Effect")
}
```

**Effect Types**: `.shimmer`, `.ripple`, `.particles`, `.morphing`, `.liquidDeformation`

You can also apply effects directly to any view:

```swift
Text("Hello")
    .glassEffect(.shimmer, intensity: 0.7)
```

## Color Palettes

The design system includes several pre-defined color palettes:

- **Ocean**: Blues and cyans for a calm, aquatic feel
- **Sunset**: Warm oranges and pinks for a vibrant, energetic feel
- **Forest**: Greens and teals for a natural, organic feel
- **Galaxy**: Purples and pinks for a cosmic, mysterious feel
- **Monochrome**: Grayscale for a clean, minimal look

## Customization

### Creating Custom Palettes

```swift
let customPalette = LiquidGlassPalette(
    name: "Custom",
    tints: [.blue, .purple, .pink],
    baseColor: .blue,
    accentColor: .purple
)
```

### Adjusting Intensity

All components support an `intensity` parameter (0.0 to 1.0) that controls the strength of glass effects:

```swift
LiquidGlassComponents.container(
    intensity: 0.3  // Subtle glass effect
) {
    // Content
}
```

### Combining Effects

You can combine multiple effects for richer visual experiences:

```swift
LiquidGlassComponents.effectsContainer(
    effects: [.shimmer, .particles],
    intensity: 0.7
) {
    // Content
}
```

## Performance Considerations

The Liquid Glass Design System is optimized for performance with several features:

- **Lazy Animation Initialization**: Animations start only when components appear
- **Effect Disabling**: Effects can be disabled for older devices
- **Reduced Motion Support**: Respects system accessibility settings
- **Efficient Rendering**: Uses SwiftUI's native rendering capabilities

## Accessibility

All components include comprehensive accessibility support:

- **VoiceOver Labels**: Descriptive labels for screen readers
- **Accessibility Traits**: Proper traits for different interaction types
- **Haptic Feedback**: Tactile feedback for interactions
- **High Contrast Support**: Adapts to system accessibility settings
- **Reduced Motion**: Respects user preferences for motion reduction

## Usage Tips

1. **Use Appropriate Intensity**: Higher intensity values create more pronounced glass effects but may impact performance
2. **Choose Compatible Palettes**: Select palettes that match your app's visual identity
3. **Limit Active Animations**: Too many simultaneous animations can impact performance
4. **Test on Target Devices**: Verify performance on your minimum supported devices
5. **Respect Accessibility Settings**: The system automatically adapts to user preferences

## Migration Guide

If you're migrating from an older version or a different design system:

1. **Import the Components**: Add `import LiquidGlassComponents` to your files
2. **Replace Basic Components**: Start with high-visibility components like buttons and cards
3. **Adjust Intensity**: Fine-tune the intensity to match your design requirements
4. **Test Animations**: Verify that animations perform well on target devices
5. **Update Accessibility**: Ensure all interactive elements have proper accessibility labels

## Troubleshooting

### Common Issues

**Animations not appearing**: Check that the component is visible and not hidden by another view.

**Performance issues**: Reduce the number of simultaneous animations or lower the intensity.

**Colors not displaying correctly**: Verify that your palette is properly configured and that the intensity is set appropriately.

**Accessibility issues**: Ensure that all interactive elements have proper labels and traits.

### Getting Help

For issues, questions, or feature requests, please refer to the component documentation or create an issue in the project repository.

## Future Enhancements

The Liquid Glass Design System is actively developed with planned enhancements including:

- Additional animation types
- More component variants
- Enhanced performance optimizations
- Expanded accessibility features
- New color palettes

## License

This project is licensed under the MIT License. See the LICENSE file for details.