//
//  DesignSystem.swift
//  DualCameraApp
//
//  iOS 26 Camera App Design System
//

import UIKit

/// iOS 26 Camera App Design System with performance optimization utilities.
/// Provides design tokens, styling methods, and performance optimization helpers.
/// Use `optimizeGlassView()` to apply rasterization, `preRenderShadowPath()` for shadow optimization.
class DesignSystem {
    
    // MARK: - Colors (iOS 26 Camera Style)
    static let primaryColor = UIColor.white
    static let secondaryColor = UIColor.white.withAlphaComponent(0.6)
    static let backgroundColor = UIColor.black
    static let textColor = UIColor.white
    static let accentColor = UIColor.systemYellow
    static let recordingColor = UIColor.systemRed
    
    // MARK: - Spacing
    enum Spacing: CGFloat {
        case xs = 4
        case sm = 8
        case md = 12
        case lg = 16
        case xl = 24
        case xxl = 32
        
        var value: CGFloat { return rawValue }
    }
    
    // MARK: - Corner Radius
    static let smallCornerRadius: CGFloat = 8
    static let mediumCornerRadius: CGFloat = 12
    static let largeCornerRadius: CGFloat = 20
    static let buttonCornerRadius: CGFloat = 20
    
    // MARK: - Typography (iOS Style)
    static let titleFont = UIFont.systemFont(ofSize: 17, weight: .semibold)
    static let bodyFont = UIFont.systemFont(ofSize: 15, weight: .regular)
    static let captionFont = UIFont.systemFont(ofSize: 13, weight: .regular)
    static let smallCaptionFont = UIFont.systemFont(ofSize: 11, weight: .regular)
    static let monospacedFont = UIFont.monospacedSystemFont(ofSize: 15, weight: .medium)
    
    // MARK: - Button Dimensions
    struct ButtonDimensions {
        static let iconButtonSize: CGFloat = 40
        static let recordButtonSize: CGFloat = 70
        static let smallButtonHeight: CGFloat = 36
        static let standardButtonHeight: CGFloat = 44
    }
    
    // MARK: - Effects
    @MainActor static let blurEffect = UIBlurEffect(style: .systemUltraThinMaterialDark)
    @MainActor static let lightBlurEffect = UIBlurEffect(style: .systemThinMaterialDark)
    
    // MARK: - Shadows
    static func applyShadow(to layer: CALayer) {
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.3
        layer.shadowOffset = CGSize(width: 0, height: 2)
        layer.shadowRadius = 8
    }
    
    // MARK: - Button Styles
    @MainActor static func styleButton(_ button: UIButton, isPrimary: Bool = false) {
        button.layer.cornerRadius = buttonCornerRadius
        button.tintColor = primaryColor
        
        if isPrimary {
            button.backgroundColor = accentColor
        }
    }
    
    // MARK: - Blur Views
    @MainActor static func createBlurView(style: UIBlurEffect.Style = .systemUltraThinMaterialDark) -> UIVisualEffectView {
        let blurView = UIVisualEffectView(effect: UIBlurEffect(style: style))
        blurView.layer.cornerRadius = largeCornerRadius
        blurView.clipsToBounds = true
        return blurView
    }
    
    enum PerformanceLevel { case high, medium, low }

    @MainActor static func optimizeGlassView(_ view: UIView, forPerformance level: PerformanceLevel) {
        switch level {
        case .high:
            view.layer.shouldRasterize = false
        case .medium:
            view.layer.shouldRasterize = true
            view.layer.rasterizationScale = UIScreen.main.scale
        case .low:
            view.layer.shouldRasterize = true
            view.layer.rasterizationScale = UIScreen.main.scale * 0.75
        }
    }

    static func preRenderShadowPath(for layer: CALayer, bounds: CGRect, cornerRadius: CGFloat) {
        let shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: cornerRadius).cgPath
        layer.shadowPath = shadowPath
    }

    @MainActor static func optimizeLayerForAnimation(_ layer: CALayer, isAnimating: Bool) {
        if isAnimating {
            layer.shouldRasterize = false
        } else {
            layer.shouldRasterize = true
            layer.rasterizationScale = UIScreen.main.scale
        }
    }
    
    // MARK: - Layout
    struct Layout {
        static let standardPadding: CGFloat = 16
        static let edgePadding: CGFloat = 20
        static let buttonSpacing: CGFloat = 12
        static let controlBarHeight: CGFloat = 100
        static let topBarHeight: CGFloat = 50
    }
    
    // MARK: - Animation
    struct Animation {
        static let standardDuration: TimeInterval = 0.3
        static let quickDuration: TimeInterval = 0.15
        static let springDamping: CGFloat = 0.7
        static let springVelocity: CGFloat = 0.5
        static let highFrameRate = CAFrameRateRange(minimum: 60, maximum: 120, preferred: 60)
        static let standardFrameRate = CAFrameRateRange(minimum: 30, maximum: 60, preferred: 60)
    }
    
    static func createDisplayLink(target: Any, selector: Selector, preferHighFrameRate: Bool = true) -> CADisplayLink {
        let displayLink = CADisplayLink(target: target, selector: selector)
        displayLink.preferredFrameRateRange = preferHighFrameRate ? Animation.highFrameRate : Animation.standardFrameRate
        displayLink.add(to: .main, forMode: .common)
        return displayLink
    }
}

extension UIView {
    func addHapticFeedback() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
    
    func addSelectionHaptic() {
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
    }
}
