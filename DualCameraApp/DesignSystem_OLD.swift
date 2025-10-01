//
//  DesignSystem.swift
//  DualCameraApp
//
//  Modern design system with typography, spacing, and visual hierarchy for iOS 18+
//

import UIKit

/// Comprehensive design system for modern iOS 18+ UI
class DesignSystem {
    
    static let shared = DesignSystem()
    
    private init() {}
    
    // MARK: - Typography System
    
    /// Modern typography scale following iOS 18+ design principles
    enum Typography {
        case largeTitle
        case title1
        case title2
        case title3
        case headline
        case subheadline
        case body
        case callout
        case footnote
        case caption1
        case caption2
        
        var font: UIFont {
            switch self {
            case .largeTitle:
                return UIFont.systemFont(ofSize: 34, weight: .bold, design: .rounded)
            case .title1:
                return UIFont.systemFont(ofSize: 28, weight: .bold, design: .rounded)
            case .title2:
                return UIFont.systemFont(ofSize: 22, weight: .bold, design: .rounded)
            case .title3:
                return UIFont.systemFont(ofSize: 20, weight: .semibold, design: .rounded)
            case .headline:
                return UIFont.systemFont(ofSize: 17, weight: .semibold, design: .rounded)
            case .subheadline:
                return UIFont.systemFont(ofSize: 15, weight: .medium, design: .rounded)
            case .body:
                return UIFont.systemFont(ofSize: 17, weight: .regular, design: .rounded)
            case .callout:
                return UIFont.systemFont(ofSize: 16, weight: .medium, design: .rounded)
            case .footnote:
                return UIFont.systemFont(ofSize: 13, weight: .regular, design: .rounded)
            case .caption1:
                return UIFont.systemFont(ofSize: 12, weight: .regular, design: .rounded)
            case .caption2:
                return UIFont.systemFont(ofSize: 11, weight: .regular, design: .rounded)
            }
        }
        
        var lineHeight: CGFloat {
            switch self {
            case .largeTitle:
                return 41
            case .title1:
                return 34
            case .title2:
                return 28
            case .title3:
                return 24
            case .headline:
                return 22
            case .subheadline:
                return 20
            case .body:
                return 22
            case .callout:
                return 21
            case .footnote:
                return 18
            case .caption1:
                return 16
            case .caption2:
                return 13
            }
        }
        
        var letterSpacing: CGFloat {
            switch self {
            case .largeTitle, .title1, .title2:
                return 0.5
            case .title3, .headline:
                return 0.3
            case .subheadline, .body, .callout:
                return 0.2
            case .footnote, .caption1, .caption2:
                return 0.1
            }
        }
    }
    
    // MARK: - Spacing System
    
    /// Modern spacing system based on 8-point grid
    enum Spacing {
        case xs      // 4pt
        case sm      // 8pt
        case md      // 16pt
        case lg      // 24pt
        case xl      // 32pt
        case xxl     // 48pt
        case xxxl    // 64pt
        
        var value: CGFloat {
            switch self {
            case .xs:
                return 4
            case .sm:
                return 8
            case .md:
                return 16
            case .lg:
                return 24
            case .xl:
                return 32
            case .xxl:
                return 48
            case .xxxl:
                return 64
            }
        }
    }
    
    // MARK: - Color System
    
    /// Enhanced color system with better contrast and accessibility
    enum Color {
        // Primary colors
        case primary
        case primaryVariant
        case secondary
        case secondaryVariant
        
        // Semantic colors
        case background
        case surface
        case surfaceVariant
        case onPrimary
        case onSecondary
        case onBackground
        case onSurface
        
        // Status colors
        case success
        case warning
        case error
        case info
        
        // Accent colors
        case accent
        case accentVariant
        
        var color: UIColor {
            switch self {
            case .primary:
                return UIColor.systemBlue
            case .primaryVariant:
                return UIColor.systemBlue.withAlphaComponent(0.8)
            case .secondary:
                return UIColor.systemGray
            case .secondaryVariant:
                return UIColor.systemGray2
            case .background:
                return UIColor.systemBackground
            case .surface:
                return UIColor.secondarySystemBackground
            case .surfaceVariant:
                return UIColor.tertiarySystemBackground
            case .onPrimary:
                return UIColor.white
            case .onSecondary:
                return UIColor.label
            case .onBackground:
                return UIColor.label
            case .onSurface:
                return UIColor.secondaryLabel
            case .success:
                return UIColor.systemGreen
            case .warning:
                return UIColor.systemYellow
            case .error:
                return UIColor.systemRed
            case .info:
                return UIColor.systemBlue
            case .accent:
                return UIColor(hex: "007AFF")
            case .accentVariant:
                return UIColor(hex: "0051D5")
            }
        }
    }
    
    // MARK: - Corner Radius System
    
    /// Modern corner radius system
    enum CornerRadius {
        case xs      // 4pt
        case sm      // 8pt
        case md      // 12pt
        case lg      // 16pt
        case xl      // 20pt
        case xxl     // 24pt
        case xxxl    // 32pt
        case full    // 50% of min dimension
        
        var value: CGFloat {
            switch self {
            case .xs:
                return 4
            case .sm:
                return 8
            case .md:
                return 12
            case .lg:
                return 16
            case .xl:
                return 20
            case .xxl:
                return 24
            case .xxxl:
                return 32
            case .full:
                return 0 // Will be calculated dynamically
            }
        }
    }
    
    // MARK: - Shadow System
    
    /// Modern shadow system with depth levels
    enum Shadow {
        case none
        case subtle
        case medium
        case prominent
        case floating
        
        var properties: (color: UIColor, opacity: Float, offset: CGSize, radius: CGFloat) {
            switch self {
            case .none:
                return (UIColor.black, 0, CGSize.zero, 0)
            case .subtle:
                return (UIColor.black, 0.1, CGSize(width: 0, height: 2), 4)
            case .medium:
                return (UIColor.black, 0.2, CGSize(width: 0, height: 4), 8)
            case .prominent:
                return (UIColor.black, 0.3, CGSize(width: 0, height: 8), 16)
            case .floating:
                return (UIColor.black, 0.25, CGSize(width: 0, height: 12), 24)
            }
        }
    }
    
    // MARK: - Animation System
    
    /// Modern animation system with spring physics
    enum Animation {
        case quick
        case standard
        case slow
        case spring
        case bouncy
        
        var duration: TimeInterval {
            switch self {
            case .quick:
                return 0.2
            case .standard:
                return 0.3
            case .slow:
                return 0.5
            case .spring:
                return 0.4
            case .bouncy:
                return 0.6
            }
        }
        
        var dampingRatio: CGFloat {
            switch self {
            case .quick, .standard, .slow:
                return 0.8
            case .spring:
                return 0.7
            case .bouncy:
                return 0.5
            }
        }
        
        var velocity: CGFloat {
            switch self {
            case .quick, .standard, .slow:
                return 0.5
            case .spring:
                return 0.8
            case .bouncy:
                return 1.0
            }
        }
    }
    
    // MARK: - Component Factory
    
    /// Creates a styled label with the design system typography
    static func createLabel(
        text: String,
        typography: Typography,
        color: Color = .onBackground,
        numberOfLines: Int = 1,
        textAlignment: NSTextAlignment = .left
    ) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = typography.font
        label.textColor = color.color
        label.numberOfLines = numberOfLines
        label.textAlignment = textAlignment
        
        // Apply line height and letter spacing
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = typography.lineHeight - typography.font.lineHeight
        paragraphStyle.alignment = textAlignment
        
        let attributedString = NSAttributedString(
            string: text,
            attributes: [
                .font: typography.font,
                .foregroundColor: color.color,
                .kern: typography.letterSpacing,
                .paragraphStyle: paragraphStyle
            ]
        )
        
        label.attributedText = attributedString
        return label
    }
    
    /// Creates a styled button with the design system
    static func createButton(
        title: String,
        style: ButtonStyle = .primary,
        typography: Typography = .callout
    ) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = typography.font
        
        switch style {
        case .primary:
            button.backgroundColor = Color.primary.color
            button.setTitleColor(Color.onPrimary.color, for: .normal)
            button.layer.cornerRadius = CornerRadius.md.value
            button.layer.shadowColor = Color.primary.color.cgColor
            button.layer.shadowOpacity = 0.3
            button.layer.shadowOffset = CGSize(width: 0, height: 4)
            button.layer.shadowRadius = 8
            
        case .secondary:
            button.backgroundColor = Color.surface.color
            button.setTitleColor(Color.primary.color, for: .normal)
            button.layer.cornerRadius = CornerRadius.md.value
            button.layer.borderWidth = 1
            button.layer.borderColor = Color.primary.color.cgColor
            
        case .ghost:
            button.backgroundColor = UIColor.clear
            button.setTitleColor(Color.primary.color, for: .normal)
            button.layer.cornerRadius = CornerRadius.sm.value
            
        case .destructive:
            button.backgroundColor = Color.error.color
            button.setTitleColor(Color.onPrimary.color, for: .normal)
            button.layer.cornerRadius = CornerRadius.md.value
            button.layer.shadowColor = Color.error.color.cgColor
            button.layer.shadowOpacity = 0.3
            button.layer.shadowOffset = CGSize(width: 0, height: 4)
            button.layer.shadowRadius = 8
        }
        
        return button
    }
    
    /// Creates a styled container view with the design system
    static func createContainer(
        backgroundColor: Color = .surface,
        cornerRadius: CornerRadius = .lg,
        shadow: Shadow = .subtle
    ) -> UIView {
        let container = UIView()
        container.backgroundColor = backgroundColor.color
        container.layer.cornerRadius = cornerRadius.value
        
        let shadowProps = shadow.properties
        container.layer.shadowColor = shadowProps.color.cgColor
        container.layer.shadowOpacity = shadowProps.opacity
        container.layer.shadowOffset = shadowProps.offset
        container.layer.shadowRadius = shadowProps.radius
        container.layer.masksToBounds = false
        
        return container
    }
    
    /// Creates a stack view with the design system spacing
    static func createStackView(
        axis: NSLayoutConstraint.Axis,
        spacing: Spacing = .md,
        alignment: UIStackView.Alignment = .fill,
        distribution: UIStackView.Distribution = .fill
    ) -> UIStackView {
        let stackView = UIStackView()
        stackView.axis = axis
        stackView.spacing = spacing.value
        stackView.alignment = alignment
        stackView.distribution = distribution
        return stackView
    }
    
    // MARK: - Layout Helpers
    
    /// Applies consistent padding to a view
    static func applyPadding(
        to view: UIView,
        padding: Spacing = .md
    ) {
        view.translatesAutoresizingMaskIntoConstraints = false
        // This would be used with constraint setup in the calling code
    }
    
    /// Creates a constraint with design system spacing
    static func spacingConstraint(
        from view: UIView,
        to anchor: NSLayoutAnchor<NSLayoutYAxisAnchor>,
        spacing: Spacing,
        relation: NSLayoutConstraint.Relation = .equal
    ) -> NSLayoutConstraint {
        switch relation {
        case .equal:
            return view.topAnchor.constraint(equalTo: anchor, constant: spacing.value)
        case .greaterThanOrEqual:
            return view.topAnchor.constraint(greaterThanOrEqualTo: anchor, constant: spacing.value)
        case .lessThanOrEqual:
            return view.topAnchor.constraint(lessThanOrEqualTo: anchor, constant: spacing.value)
        @unknown default:
            return view.topAnchor.constraint(equalTo: anchor, constant: spacing.value)
        }
    }
    
    // MARK: - Animation Helpers
    
    /// Creates a spring animation with design system parameters
    static func createSpringAnimator(
        animation: Animation = .standard,
        animations: @escaping () -> Void
    ) -> UIViewPropertyAnimator {
        let timingParameters = UISpringTimingParameters(
            dampingRatio: animation.dampingRatio,
            initialVelocity: CGVector(dx: animation.velocity, dy: animation.velocity)
        )
        
        return UIViewPropertyAnimator(
            duration: animation.duration,
            timingParameters: timingParameters
        )
    }
    
    /// Applies a shadow to a view using the design system
    static func applyShadow(
        to view: UIView,
        shadow: Shadow = .subtle
    ) {
        let shadowProps = shadow.properties
        view.layer.shadowColor = shadowProps.color.cgColor
        view.layer.shadowOpacity = shadowProps.opacity
        view.layer.shadowOffset = shadowProps.offset
        view.layer.shadowRadius = shadowProps.radius
        view.layer.masksToBounds = false
        
        // Update shadow path for better performance
        if view.layer.cornerRadius > 0 {
            view.layer.shadowPath = UIBezierPath(
                roundedRect: view.bounds,
                cornerRadius: view.layer.cornerRadius
            ).cgPath
        }
    }
}

// MARK: - Button Styles

enum ButtonStyle {
    case primary
    case secondary
    case ghost
    case destructive
}

// MARK: - UIView Extensions for Design System

extension UIView {
    
    /// Applies design system corner radius
    func applyCornerRadius(_ radius: DesignSystem.CornerRadius) {
        layer.cornerRadius = radius.value == 0 ? min(bounds.width, bounds.height) / 2 : radius.value
        layer.cornerCurve = .continuous
    }
    
    /// Applies design system shadow
    func applyShadow(_ shadow: DesignSystem.Shadow) {
        DesignSystem.applyShadow(to: self, shadow: shadow)
    }
    
    /// Applies design system spacing as constraints
    func constrainToSuperview(
        padding: DesignSystem.Spacing = .md,
        insets: UIEdgeInsets = .zero
    ) {
        guard let superview = superview else { return }
        
        translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            topAnchor.constraint(equalTo: superview.topAnchor, constant: padding.value + insets.top),
            leadingAnchor.constraint(equalTo: superview.leadingAnchor, constant: padding.value + insets.left),
            trailingAnchor.constraint(equalTo: superview.trailingAnchor, constant: -(padding.value + insets.right)),
            bottomAnchor.constraint(equalTo: superview.bottomAnchor, constant: -(padding.value + insets.bottom))
        ])
    }
    
    /// Creates a haptic feedback animation
    func addHapticFeedback() {
        let feedbackGenerator = UIImpactFeedbackGenerator(style: .light)
        feedbackGenerator.prepare()
        
        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(handleHapticTap)))
    }
    
    @objc private func handleHapticTap() {
        let feedbackGenerator = UIImpactFeedbackGenerator(style: .light)
        feedbackGenerator.impactOccurred()
    }
}

// MARK: - UILabel Extensions for Design System

extension UILabel {
    
    /// Configures label with design system typography
    func configure(
        typography: DesignSystem.Typography,
        color: DesignSystem.Color = .onBackground,
        numberOfLines: Int = 1,
        textAlignment: NSTextAlignment = .left
    ) {
        font = typography.font
        textColor = color.color
        self.numberOfLines = numberOfLines
        self.textAlignment = textAlignment
        
        // Apply line height
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = typography.lineHeight - font.lineHeight
        paragraphStyle.alignment = textAlignment
        
        let attributedString = NSAttributedString(
            string: text ?? "",
            attributes: [
                .font: font,
                .foregroundColor: color.color,
                .kern: typography.letterSpacing,
                .paragraphStyle: paragraphStyle
            ]
        )
        
        attributedText = attributedString
    }
}