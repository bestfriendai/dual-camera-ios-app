//
//  Colors.swift
//  DualApp
//
//  Created by DualApp Team on 10/3/25.
//

import SwiftUI

// MARK: - Design System Colors

struct DesignColors {
    
    // MARK: - Primary Colors
    
    static let primary = Color(red: 0.0, green: 0.48, blue: 1.0)
    static let primaryVariant = Color(red: 0.0, green: 0.36, blue: 0.8)
    static let primaryLight = Color(red: 0.4, green: 0.7, blue: 1.0)
    static let primaryDark = Color(red: 0.0, green: 0.3, blue: 0.7)
    
    // MARK: - Secondary Colors
    
    static let secondary = Color(red: 0.96, green: 0.96, blue: 0.98)
    static let secondaryVariant = Color(red: 0.9, green: 0.9, blue: 0.95)
    static let secondaryLight = Color(red: 0.98, green: 0.98, blue: 1.0)
    static let secondaryDark = Color(red: 0.85, green: 0.85, blue: 0.9)
    
    // MARK: - Background Colors
    
    static let background = Color(red: 0.05, green: 0.05, blue: 0.1)
    static let surface = Color(red: 0.1, green: 0.1, blue: 0.15)
    static let surfaceVariant = Color(red: 0.15, green: 0.15, blue: 0.2)
    static let backgroundLight = Color(red: 0.08, green: 0.08, blue: 0.12)
    static let backgroundDark = Color(red: 0.02, green: 0.02, blue: 0.05)
    
    // MARK: - Glass Colors
    
    static let glassBackground = Color.white.opacity(0.1)
    static let glassBorder = Color.white.opacity(0.2)
    static let glassShadow = Color.black.opacity(0.3)
    static let glassHighlight = Color.white.opacity(0.4)
    static let glassReflection = Color.white.opacity(0.6)
    
    // MARK: - Status Colors
    
    static let success = Color(red: 0.2, green: 0.8, blue: 0.4)
    static let successLight = Color(red: 0.4, green: 0.9, blue: 0.6)
    static let successDark = Color(red: 0.1, green: 0.6, blue: 0.3)
    
    static let warning = Color(red: 1.0, green: 0.6, blue: 0.0)
    static let warningLight = Color(red: 1.0, green: 0.8, blue: 0.2)
    static let warningDark = Color(red: 0.8, green: 0.4, blue: 0.0)
    
    static let error = Color(red: 1.0, green: 0.2, blue: 0.2)
    static let errorLight = Color(red: 1.0, green: 0.4, blue: 0.4)
    static let errorDark = Color(red: 0.8, green: 0.1, blue: 0.1)
    
    static let info = Color(red: 0.2, green: 0.6, blue: 1.0)
    static let infoLight = Color(red: 0.4, green: 0.8, blue: 1.0)
    static let infoDark = Color(red: 0.1, green: 0.4, blue: 0.8)
    
    // MARK: - Text Colors
    
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.8)
    static let textTertiary = Color.white.opacity(0.6)
    static let textOnGlass = Color.white
    static let textOnGlassSecondary = Color.white.opacity(0.9)
    static let textOnGlassTertiary = Color.white.opacity(0.7)
    static let textDisabled = Color.white.opacity(0.4)
    
    // MARK: - Recording Colors
    
    static let recordingActive = Color.red
    static let recordingActiveLight = Color(red: 1.0, green: 0.3, blue: 0.3)
    static let recordingActiveDark = Color(red: 0.8, green: 0.0, blue: 0.0)
    
    static let recordingInactive = Color.gray
    static let recordingInactiveLight = Color.gray.opacity(0.7)
    static let recordingInactiveDark = Color.gray.opacity(0.9)
    
    static let recordingPaused = Color.orange
    static let recordingPausedLight = Color(red: 1.0, green: 0.7, blue: 0.2)
    static let recordingPausedDark = Color(red: 0.8, green: 0.4, blue: 0.0)
    
    // MARK: - Camera Control Colors
    
    static let cameraControl = Color.white.opacity(0.9)
    static let cameraControlActive = DesignColors.primary
    static let cameraControlDisabled = Color.gray.opacity(0.5)
    static let cameraControlHover = Color.white.opacity(0.95)
    static let cameraControlPressed = Color.white.opacity(0.8)
    
    // MARK: - Accent Colors
    
    static let accent = Color(red: 0.0, green: 0.8, blue: 0.8)
    static let accentLight = Color(red: 0.2, green: 0.9, blue: 0.9)
    static let accentDark = Color(red: 0.0, green: 0.6, blue: 0.6)
    
    // MARK: - Semantic Colors
    
    static let batteryFull = Color.green
    static let batteryMedium = Color.yellow
    static let batteryLow = Color.orange
    static let batteryCritical = Color.red
    
    static let thermalNormal = Color.green
    static let thermalWarm = Color.yellow
    static let thermalHot = Color.orange
    static let thermalCritical = Color.red
    
    static let memoryNormal = Color.green
    static let memoryWarning = Color.yellow
    static let memoryCritical = Color.red
}

// MARK: - Liquid Glass Colors

struct LiquidGlassColors {
    
    // MARK: - Glass Variants
    
    static let clear = Color.white.opacity(0.05)
    static let frosted = Color.white.opacity(0.1)
    static let blurred = Color.white.opacity(0.15)
    static let tinted = Color.blue.opacity(0.1)
    static let crystal = Color.white.opacity(0.03)
    static let matte = Color.white.opacity(0.12)
    static let glossy = Color.white.opacity(0.08)
    static let satin = Color.white.opacity(0.07)
    
    // MARK: - Animated Colors
    
    static let shimmer = Color.white.opacity(0.3)
    static let shimmerBright = Color.white.opacity(0.5)
    static let shimmerDim = Color.white.opacity(0.2)
    
    static let glow = Color.blue.opacity(0.2)
    static let glowBright = Color.blue.opacity(0.4)
    static let glowDim = Color.blue.opacity(0.1)
    
    static let pulse = Color.white.opacity(0.1)
    static let pulseActive = Color.white.opacity(0.15)
    static let pulseInactive = Color.white.opacity(0.05)
    
    // MARK: - Depth Colors
    
    static let near = Color.white.opacity(0.2)
    static let mid = Color.white.opacity(0.1)
    static let far = Color.white.opacity(0.05)
    static let distant = Color.white.opacity(0.02)
    
    // MARK: - Tinted Glass Variants
    
    static let blueTint = Color.blue.opacity(0.1)
    static let blueTintLight = Color.blue.opacity(0.05)
    static let blueTintDark = Color.blue.opacity(0.15)
    
    static let purpleTint = Color.purple.opacity(0.1)
    static let purpleTintLight = Color.purple.opacity(0.05)
    static let purpleTintDark = Color.purple.opacity(0.15)
    
    static let pinkTint = Color.pink.opacity(0.1)
    static let pinkTintLight = Color.pink.opacity(0.05)
    static let pinkTintDark = Color.pink.opacity(0.15)
    
    static let greenTint = Color.green.opacity(0.1)
    static let greenTintLight = Color.green.opacity(0.05)
    static let greenTintDark = Color.green.opacity(0.15)
    
    static let orangeTint = Color.orange.opacity(0.1)
    static let orangeTintLight = Color.orange.opacity(0.05)
    static let orangeTintDark = Color.orange.opacity(0.15)
    
    // MARK: - Gradient Colors
    
    static let gradientStart = Color.white.opacity(0.15)
    static let gradientMid = Color.white.opacity(0.08)
    static let gradientEnd = Color.white.opacity(0.02)
    
    static let blueGradientStart = Color.blue.opacity(0.2)
    static let blueGradientMid = Color.blue.opacity(0.1)
    static let blueGradientEnd = Color.blue.opacity(0.05)
    
    // MARK: - Interactive States
    
    static let idle = Color.white.opacity(0.1)
    static let hover = Color.white.opacity(0.15)
    static let pressed = Color.white.opacity(0.2)
    static let focused = Color.white.opacity(0.12)
    static let disabled = Color.white.opacity(0.05)
    
    // MARK: - Surface Effects
    
    static let surfaceReflection = Color.white.opacity(0.4)
    static let surfaceShadow = Color.black.opacity(0.2)
    static let surfaceHighlight = Color.white.opacity(0.3)
    static let surfaceContour = Color.white.opacity(0.15)
    
    // MARK: - Animation Colors
    
    static let waveOverlay = Color.blue.opacity(0.1)
    static let particleGlow = Color.white.opacity(0.6)
    static let trailEffect = Color.blue.opacity(0.3)
    static let rippleEffect = Color.white.opacity(0.2)
}

// MARK: - Color Extensions

extension Color {
    
    // MARK: - Initializers
    
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
    
    init(rgba: UInt32) {
        let r = Double((rgba >> 24) & 0xFF) / 255.0
        let g = Double((rgba >> 16) & 0xFF) / 255.0
        let b = Double((rgba >> 8) & 0xFF) / 255.0
        let a = Double(rgba & 0xFF) / 255.0
        
        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
    
    // MARK: - Glass Modifiers
    
    func glass(opacity: Double = 0.1) -> Color {
        return self.opacity(opacity)
    }
    
    func glassTint(_ color: Color, opacity: Double = 0.1) -> Color {
        return Color(UIColor.blend(color: UIColor(self), with: UIColor(color), alpha: opacity))
    }
    
    func liquidGlass(intensity: Double = 0.5) -> Color {
        return self.opacity(intensity * 0.1)
    }
    
    func liquidGlassTint(_ tint: LiquidGlassTint, intensity: Double = 0.5) -> Color {
        let baseColor = self.opacity(intensity * 0.1)
        let tintColor = tint.color.opacity(intensity * 0.05)
        return Color(UIColor.blend(color: UIColor(baseColor), with: UIColor(tintColor), alpha: 0.5))
    }
    
    // MARK: - Animation Modifiers
    
    func shimmering(baseOpacity: Double = 0.3) -> Color {
        return self.opacity(baseOpacity)
    }
    
    func glowing(baseIntensity: Double = 0.2) -> Color {
        return self.opacity(baseIntensity)
    }
    
    func pulsing(baseOpacity: Double = 0.1) -> Color {
        return self.opacity(baseOpacity)
    }
    
    // MARK: - Depth Modifiers
    
    func depth(_ level: GlassDepth) -> Color {
        return self.opacity(level.opacity)
    }
    
    // MARK: - State Modifiers
    
    func interactive(_ state: InteractiveState) -> Color {
        switch state {
        case .idle:
            return self.opacity(0.1)
        case .hover:
            return self.opacity(0.15)
        case .pressed:
            return self.opacity(0.2)
        case .focused:
            return self.opacity(0.12)
        case .disabled:
            return self.opacity(0.05)
        }
    }
    
    // MARK: - Utility Methods
    
    func lighter(by percentage: Double = 0.2) -> Color {
        return self.opacity(min(1.0, self.opacity + percentage))
    }
    
    func darker(by percentage: Double = 0.2) -> Color {
        return self.opacity(max(0.0, self.opacity - percentage))
    }
    
    func withAlpha(_ alpha: Double) -> Color {
        return self.opacity(alpha)
    }
}

// MARK: - Liquid Glass Tint

enum LiquidGlassTint: CaseIterable {
    case clear
    case blue
    case purple
    case pink
    case green
    case orange
    
    var color: Color {
        switch self {
        case .clear:
            return .white
        case .blue:
            return .blue
        case .purple:
            return .purple
        case .pink:
            return .pink
        case .green:
            return .green
        case .orange:
            return .orange
        }
    }
    
    var name: String {
        switch self {
        case .clear:
            return "Clear"
        case .blue:
            return "Blue"
        case .purple:
            return "Purple"
        case .pink:
            return "Pink"
        case .green:
            return "Green"
        case .orange:
            return "Orange"
        }
    }
}

// MARK: - Glass Depth

enum GlassDepth: CaseIterable {
    case distant
    case far
    case mid
    case near
    case surface
    
    var opacity: Double {
        switch self {
        case .distant:
            return 0.02
        case .far:
            return 0.05
        case .mid:
            return 0.1
        case .near:
            return 0.2
        case .surface:
            return 0.3
        }
    }
    
    var name: String {
        switch self {
        case .distant:
            return "Distant"
        case .far:
            return "Far"
        case .mid:
            return "Mid"
        case .near:
            return "Near"
        case .surface:
            return "Surface"
        }
    }
}

// MARK: - Interactive State

enum InteractiveState: CaseIterable {
    case idle
    case hover
    case pressed
    case focused
    case disabled
    
    var name: String {
        switch self {
        case .idle:
            return "Idle"
        case .hover:
            return "Hover"
        case .pressed:
            return "Pressed"
        case .focused:
            return "Focused"
        case .disabled:
            return "Disabled"
        }
    }
}

// MARK: - UIColor Extension for Blending

extension UIColor {
    
    static func blend(color: UIColor, with otherColor: UIColor, alpha: CGFloat) -> UIColor {
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        
        color.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        otherColor.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        
        let r = r1 * (1 - alpha) + r2 * alpha
        let g = g1 * (1 - alpha) + g2 * alpha
        let b = b1 * (1 - alpha) + b2 * alpha
        let a = a1 * (1 - alpha) + a2 * alpha
        
        return UIColor(red: r, green: g, blue: b, alpha: a)
    }
    
    static func multiply(color: UIColor, with otherColor: UIColor) -> UIColor {
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        
        color.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        otherColor.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        
        let r = r1 * r2
        let g = g1 * g2
        let b = b1 * b2
        let a = a1 * a2
        
        return UIColor(red: r, green: g, blue: b, alpha: a)
    }
    
    static func screen(color: UIColor, with otherColor: UIColor) -> UIColor {
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        
        color.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        otherColor.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        
        let r = 1 - (1 - r1) * (1 - r2)
        let g = 1 - (1 - g1) * (1 - g2)
        let b = 1 - (1 - b1) * (1 - b2)
        let a = 1 - (1 - a1) * (1 - a2)
        
        return UIColor(red: r, green: g, blue: b, alpha: a)
    }
    
    static func overlay(color: UIColor, with otherColor: UIColor) -> UIColor {
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        
        color.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        otherColor.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        
        let r = r1 < 0.5 ? 2 * r1 * r2 : 1 - 2 * (1 - r1) * (1 - r2)
        let g = g1 < 0.5 ? 2 * g1 * g2 : 1 - 2 * (1 - g1) * (1 - g2)
        let b = b1 < 0.5 ? 2 * b1 * b2 : 1 - 2 * (1 - b1) * (1 - b2)
        let a = a1 < 0.5 ? 2 * a1 * a2 : 1 - 2 * (1 - a1) * (1 - a2)
        
        return UIColor(red: r, green: g, blue: b, alpha: a)
    }
}

// MARK: - Color Palette Generator

struct ColorPalette {
    
    // MARK: - Predefined Palettes
    
    static let ocean = LiquidGlassPalette(
        name: "Ocean",
        tints: [.blue, .cyan, .teal],
        baseColor: .blue,
        accentColor: .cyan
    )
    
    static let sunset = LiquidGlassPalette(
        name: "Sunset",
        tints: [.orange, .pink, .purple],
        baseColor: .orange,
        accentColor: .pink
    )
    
    static let forest = LiquidGlassPalette(
        name: "Forest",
        tints: [.green, .mint, .teal],
        baseColor: .green,
        accentColor: .mint
    )
    
    static let galaxy = LiquidGlassPalette(
        name: "Galaxy",
        tints: [.purple, .pink, .blue],
        baseColor: .purple,
        accentColor: .pink
    )
    
    static let monochrome = LiquidGlassPalette(
        name: "Monochrome",
        tints: [.clear],
        baseColor: .white,
        accentColor: .gray
    )
    
    // MARK: - All Palettes
    
    static let allPalettes: [LiquidGlassPalette] = [
        .ocean, .sunset, .forest, .galaxy, .monochrome
    ]
}

// MARK: - Liquid Glass Palette

struct LiquidGlassPalette: Identifiable {
    let id = UUID()
    let name: String
    let tints: [LiquidGlassTint]
    let baseColor: Color
    let accentColor: Color
    
    var primaryTint: LiquidGlassTint {
        return tints.first ?? .clear
    }
    
    var secondaryTint: LiquidGlassTint? {
        return tints.count > 1 ? tints[1] : nil
    }
    
    var tertiaryTint: LiquidGlassTint? {
        return tints.count > 2 ? tints[2] : nil
    }
}