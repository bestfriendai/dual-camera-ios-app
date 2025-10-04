//
//  AccessibilityAwareGlass.swift
//  DualCameraApp
//
//  Accessibility-aware glass effects with WCAG compliance and Metal rendering support.
//  Provides dynamic adaptation to Reduce Transparency, Increase Contrast, and Metal capabilities.
//

import SwiftUI
import UIKit

@available(iOS 15.0, *)
extension UIView {
    func applyAccessibleGlassEffect(tint: UIColor = .white, isHighContrast: Bool = false) {
        if UIAccessibility.isReduceTransparencyEnabled || isHighContrast {
            backgroundColor = tint.withAlphaComponent(0.95)
            layer.borderWidth = 2.0
            layer.borderColor = tint.cgColor
            layer.cornerRadius = 12
            layer.cornerCurve = .continuous
        } else {
            let blurEffect = UIBlurEffect(style: .systemUltraThinMaterial)
            let blurView = UIVisualEffectView(effect: blurEffect)
            blurView.frame = bounds
            blurView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            blurView.layer.cornerRadius = 12
            blurView.layer.cornerCurve = .continuous
            blurView.clipsToBounds = true
            insertSubview(blurView, at: 0)
        }
    }
}

@available(iOS 15.0, *)
struct AccessibilityAwareGlassModifier: ViewModifier {
    let tint: Color
    let requiresHighContrast: Bool
    
    @Environment(\.accessibilityReduceTransparency) var reduceTransparency
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @Environment(\.colorScheme) var colorScheme
    @AccessibilityFocusState private var isFocused: Bool
    
    func body(content: Content) -> some View {
        content
            .padding()
            .background {
                if reduceTransparency || requiresHighContrast {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(colorScheme == .dark ? Color.black.opacity(0.9) : Color.white.opacity(0.95))
                        .overlay {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(tint, lineWidth: 2)
                        }
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(.ultraThinMaterial)
                        
                        LinearGradient(
                            colors: [
                                tint.opacity(0.3),
                                tint.opacity(0.15),
                                tint.opacity(0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.3), lineWidth: 0.5)
                    }
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityFocused($isFocused)
    }
}

extension View {
    func accessibleGlassEffect(tint: Color = .white, requiresHighContrast: Bool = false) -> some View {
        modifier(AccessibilityAwareGlassModifier(tint: tint, requiresHighContrast: requiresHighContrast))
    }
}

@available(iOS 15.0, *)
@MainActor
class AccessibilityGlassEffectManager {
    static let shared = AccessibilityGlassEffectManager()
    
    private(set) var isReduceTransparencyEnabled = false
    private(set) var isIncreaseContrastEnabled = false
    private(set) var isReduceMotionEnabled = false
    private(set) var isMetalRenderingRecommended: Bool = false
    
    private init() {
        updateAccessibilitySettings()
        setupNotifications()
    }
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(accessibilitySettingsChanged),
            name: UIAccessibility.reduceTransparencyStatusDidChangeNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(accessibilitySettingsChanged),
            name: UIAccessibility.darkerSystemColorsStatusDidChangeNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(accessibilitySettingsChanged),
            name: UIAccessibility.reduceMotionStatusDidChangeNotification,
            object: nil
        )
    }
    
    @objc private func accessibilitySettingsChanged() {
        updateAccessibilitySettings()
        NotificationCenter.default.post(name: .accessibilityGlassSettingsChanged, object: nil)
        NotificationCenter.default.post(name: .metalRenderingSettingsChanged, object: nil)
    }
    
    private func updateAccessibilitySettings() {
        isReduceTransparencyEnabled = UIAccessibility.isReduceTransparencyEnabled
        isIncreaseContrastEnabled = UIAccessibility.isDarkerSystemColorsEnabled
        isReduceMotionEnabled = UIAccessibility.isReduceMotionEnabled
        // Metal rendering disabled - MetalGlassRenderer.swift not in project
        isMetalRenderingRecommended = false
        // if #available(iOS 15.0, *) {
        //     isMetalRenderingRecommended = !isReduceTransparencyEnabled && MetalGlassRenderer.isMetalRenderingAvailable()
        // } else {
        //     isMetalRenderingRecommended = false
        // }
    }
    
    func shouldUseHighContrastGlass() -> Bool {
        return isReduceTransparencyEnabled || isIncreaseContrastEnabled
    }
    
    func shouldDisableAnimations() -> Bool {
        return isReduceMotionEnabled
    }
    
    func recommendedAnimationDuration() -> TimeInterval {
        return isReduceMotionEnabled ? 0.0 : 0.3
    }
    
    func shouldUseMetalRendering() -> Bool {
        return isMetalRenderingRecommended
    }
    
    func recommendedBlurRadius() -> Float {
        if isReduceTransparencyEnabled {
            return 0.0
        } else if isIncreaseContrastEnabled {
            return 1.0
        } else {
            return 3.0
        }
    }
    
    func recommendedFresnelStrength() -> Float {
        if isReduceTransparencyEnabled {
            return 0.0
        } else if isIncreaseContrastEnabled {
            return 0.1
        } else {
            return 0.3
        }
    }
    
    func shouldEnableRasterization() -> Bool {
        if UIAccessibility.isReduceMotionEnabled { return true }
        if UIAccessibility.isReduceTransparencyEnabled { return true }
        return false
    }

    func recommendedFrameRate() -> CAFrameRateRange {
        if UIAccessibility.isReduceMotionEnabled {
            return CAFrameRateRange(minimum: 30, maximum: 60, preferred: 60)
        }
        return CAFrameRateRange(minimum: 60, maximum: 120, preferred: 60)
    }

    func shouldCacheBackdrop() -> Bool {
        if UIAccessibility.isReduceMotionEnabled { return true }
        if UIAccessibility.isReduceTransparencyEnabled { return true }
        return false
    }

    func recommendedBackdropCacheInterval() -> Int {
        if UIAccessibility.isReduceMotionEnabled { return Int.max }
        if UIAccessibility.isReduceTransparencyEnabled { return 100 }
        return 10
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

extension Notification.Name {
    static let accessibilityGlassSettingsChanged = Notification.Name("AccessibilityGlassSettingsChanged")
    static let metalRenderingSettingsChanged = Notification.Name("MetalRenderingSettingsChanged")
}

// Metal rendering disabled - MetalGlassRenderer.swift not in project
// @available(iOS 15.0, *)
// extension MetalGlassRenderer {
//     func applyAccessibilitySettings() {
//         let manager = AccessibilityGlassEffectManager.shared
//         self.blurRadius = manager.recommendedBlurRadius()
//         self.fresnelStrength = manager.recommendedFresnelStrength()
//     }
// }

@available(iOS 15.0, *)
struct ContrastChecker {
    static func meetsWCAGAAStandard(foreground: UIColor, background: UIColor) -> Bool {
        let ratio = calculateContrastRatio(foreground: foreground, background: background)
        return ratio >= 4.5
    }
    
    static func meetsWCAGAAAStandard(foreground: UIColor, background: UIColor) -> Bool {
        let ratio = calculateContrastRatio(foreground: foreground, background: background)
        return ratio >= 7.0
    }
    
    private static func calculateContrastRatio(foreground: UIColor, background: UIColor) -> CGFloat {
        let fgLuminance = relativeLuminance(of: foreground)
        let bgLuminance = relativeLuminance(of: background)
        
        let lighter = max(fgLuminance, bgLuminance)
        let darker = min(fgLuminance, bgLuminance)
        
        return (lighter + 0.05) / (darker + 0.05)
    }
    
    private static func relativeLuminance(of color: UIColor) -> CGFloat {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        
        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        func adjust(_ component: CGFloat) -> CGFloat {
            if component <= 0.03928 {
                return component / 12.92
            } else {
                return pow((component + 0.055) / 1.055, 2.4)
            }
        }
        
        let r = adjust(red)
        let g = adjust(green)
        let b = adjust(blue)
        
        return 0.2126 * r + 0.7152 * g + 0.0722 * b
    }
}

@available(iOS 15.0, *)
extension GlassmorphismView {
    func applyAccessibilityOptimizations() {
        let manager = AccessibilityGlassEffectManager.shared
        self.enableRasterization(manager.shouldEnableRasterization())
    }
}

extension LiquidGlassView {
    func applyAccessibilityOptimizations() {
        let manager = AccessibilityGlassEffectManager.shared
        self.enableRasterization(manager.shouldEnableRasterization())
        // Metal rendering disabled
        // if let renderer = metalRenderer {
        //     renderer.setBackdropStatic(manager.shouldCacheBackdrop())
        // }
    }
}
