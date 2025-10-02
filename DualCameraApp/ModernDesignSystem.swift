//
//  ModernDesignSystem.swift
//  DualCameraApp
//
//  iOS 18+ Modern Design System with Material 3 principles
//

import UIKit
import SwiftUI

/// Modern design system following iOS 18+ and Material 3 guidelines
@available(iOS 15.0, *)
class ModernDesignSystem {
    
    static let shared = ModernDesignSystem()
    
    private init() {}
    
    // MARK: - Color System (Material 3 inspired)
    
    enum ColorToken {
        // Primary brand colors
        case primary
        case onPrimary
        case primaryContainer
        case onPrimaryContainer
        
        // Secondary colors
        case secondary
        case onSecondary
        case secondaryContainer
        case onSecondaryContainer
        
        // Tertiary colors
        case tertiary
        case onTertiary
        case tertiaryContainer
        case onTertiaryContainer
        
        // Surface colors
        case surface
        case onSurface
        case surfaceVariant
        case onSurfaceVariant
        case surfaceTint
        case inverseSurface
        case inverseOnSurface
        
        // Outline colors
        case outline
        case outlineVariant
        
        // Camera-specific colors
        case recordingActive
        case recordingInactive
        case cameraPreviewBorder
        case controlBackground
        
        var color: UIColor {
            switch self {
            // Primary colors - Dynamic blue that adapts to interface style
            case .primary:
                return UIColor { traitCollection in
                    if traitCollection.userInterfaceStyle == .dark {
                        return UIColor(red: 0.27, green: 0.51, blue: 0.96, alpha: 1.0) // Bright blue
                    } else {
                        return UIColor(red: 0.13, green: 0.59, blue: 0.95, alpha: 1.0) // Standard blue
                    }
                }
                
            case .onPrimary:
                return UIColor.white
                
            case .primaryContainer:
                return UIColor { traitCollection in
                    if traitCollection.userInterfaceStyle == .dark {
                        return UIColor(red: 0.06, green: 0.28, blue: 0.63, alpha: 1.0)
                    } else {
                        return UIColor(red: 0.91, green: 0.94, blue: 1.0, alpha: 1.0)
                    }
                }
                
            case .onPrimaryContainer:
                return UIColor { traitCollection in
                    if traitCollection.userInterfaceStyle == .dark {
                        return UIColor.white
                    } else {
                        return UIColor(red: 0.04, green: 0.31, blue: 0.71, alpha: 1.0)
                    }
                }
                
            // Secondary colors
            case .secondary:
                return UIColor { traitCollection in
                    if traitCollection.userInterfaceStyle == .dark {
                        return UIColor(red: 0.84, green: 0.74, blue: 0.62, alpha: 1.0)
                    } else {
                        return UIColor(red: 0.62, green: 0.49, blue: 0.36, alpha: 1.0)
                    }
                }
                
            case .onSecondary:
                return UIColor { traitCollection in
                    if traitCollection.userInterfaceStyle == .dark {
                        return UIColor.black
                    } else {
                        return UIColor.white
                    }
                }
                
            case .secondaryContainer:
                return UIColor { traitCollection in
                    if traitCollection.userInterfaceStyle == .dark {
                        return UIColor(red: 0.31, green: 0.26, blue: 0.20, alpha: 1.0)
                    } else {
                        return UIColor(red: 1.0, green: 0.96, blue: 0.89, alpha: 1.0)
                    }
                }
                
            case .onSecondaryContainer:
                return UIColor { traitCollection in
                    if traitCollection.userInterfaceStyle == .dark {
                        return UIColor.white
                    } else {
                        return UIColor(red: 0.23, green: 0.18, blue: 0.10, alpha: 1.0)
                    }
                }
                
            // Tertiary colors
            case .tertiary:
                return UIColor { traitCollection in
                    if traitCollection.userInterfaceStyle == .dark {
                        return UIColor(red: 0.82, green: 0.65, blue: 0.84, alpha: 1.0)
                    } else {
                        return UIColor(red: 0.76, green: 0.52, blue: 0.80, alpha: 1.0)
                    }
                }
                
            case .onTertiary:
                return UIColor { traitCollection in
                    if traitCollection.userInterfaceStyle == .dark {
                        return UIColor.black
                    } else {
                        return UIColor.white
                    }
                }
                
            case .tertiaryContainer:
                return UIColor { traitCollection in
                    if traitCollection.userInterfaceStyle == .dark {
                        return UIColor(red: 0.32, green: 0.22, blue: 0.34, alpha: 1.0)
                    } else {
                        return UIColor(red: 1.0, green: 0.92, blue: 1.0, alpha: 1.0)
                    }
                }
                
            case .onTertiaryContainer:
                return UIColor { traitCollection in
                    if traitCollection.userInterfaceStyle == .dark {
                        return UIColor.white
                    } else {
                        return UIColor(red: 0.29, green: 0.15, blue: 0.33, alpha: 1.0)
                    }
                }
                
            // Surface colors
            case .surface:
                return UIColor { traitCollection in
                    if traitCollection.userInterfaceStyle == .dark {
                        return UIColor(red: 0.10, green: 0.11, blue: 0.13, alpha: 1.0)
                    } else {
                        return UIColor(red: 0.98, green: 0.98, blue: 0.98, alpha: 1.0)
                    }
                }
                
            case .onSurface:
                return UIColor { traitCollection in
                    if traitCollection.userInterfaceStyle == .dark {
                        return UIColor(red: 0.98, green: 0.98, blue: 0.98, alpha: 1.0)
                    } else {
                        return UIColor(red: 0.11, green: 0.12, blue: 0.13, alpha: 1.0)
                    }
                }
                
            case .surfaceVariant:
                return UIColor { traitCollection in
                    if traitCollection.userInterfaceStyle == .dark {
                        return UIColor(red: 0.15, green: 0.16, blue: 0.18, alpha: 1.0)
                    } else {
                        return UIColor(red: 0.92, green: 0.92, blue: 0.93, alpha: 1.0)
                    }
                }
                
            case .onSurfaceVariant:
                return UIColor { traitCollection in
                    if traitCollection.userInterfaceStyle == .dark {
                        return UIColor(red: 0.82, green: 0.82, blue: 0.84, alpha: 1.0)
                    } else {
                        return UIColor(red: 0.25, green: 0.26, blue: 0.28, alpha: 1.0)
                    }
                }
                
            case .surfaceTint:
                return ColorToken.primary.color
                
            case .inverseSurface:
                return UIColor { traitCollection in
                    if traitCollection.userInterfaceStyle == .dark {
                        return UIColor(red: 0.95, green: 0.95, blue: 0.96, alpha: 1.0)
                    } else {
                        return UIColor(red: 0.11, green: 0.12, blue: 0.13, alpha: 1.0)
                    }
                }
                
            case .inverseOnSurface:
                return UIColor { traitCollection in
                    if traitCollection.userInterfaceStyle == .dark {
                        return UIColor(red: 0.11, green: 0.12, blue: 0.13, alpha: 1.0)
                    } else {
                        return UIColor(red: 0.95, green: 0.95, blue: 0.96, alpha: 1.0)
                    }
                }
                
            // Outline colors
            case .outline:
                return UIColor { traitCollection in
                    if traitCollection.userInterfaceStyle == .dark {
                        return UIColor(red: 0.47, green: 0.48, blue: 0.50, alpha: 1.0)
                    } else {
                        return UIColor(red: 0.53, green: 0.54, blue: 0.56, alpha: 1.0)
                    }
                }
                
            case .outlineVariant:
                return UIColor { traitCollection in
                    if traitCollection.userInterfaceStyle == .dark {
                        return UIColor(red: 0.31, green: 0.32, blue: 0.34, alpha: 1.0)
                    } else {
                        return UIColor(red: 0.82, green: 0.82, blue: 0.84, alpha: 1.0)
                    }
                }
                
            // Camera-specific colors
            case .recordingActive:
                return UIColor { traitCollection in
                    return UIColor(red: 1.0, green: 0.23, blue: 0.19, alpha: 1.0)
                }
                
            case .recordingInactive:
                return UIColor { traitCollection in
                    if traitCollection.userInterfaceStyle == .dark {
                        return UIColor(red: 0.60, green: 0.60, blue: 0.60, alpha: 1.0)
                    } else {
                        return UIColor(red: 0.40, green: 0.40, blue: 0.40, alpha: 1.0)
                    }
                }
                
            case .cameraPreviewBorder:
                return UIColor { traitCollection in
                    if traitCollection.userInterfaceStyle == .dark {
                        return UIColor.white.withAlphaComponent(0.15)
                    } else {
                        return UIColor.black.withAlphaComponent(0.10)
                    }
                }
                
            case .controlBackground:
                return UIColor { traitCollection in
                    if traitCollection.userInterfaceStyle == .dark {
                        return UIColor.black.withAlphaComponent(0.40)
                    } else {
                        return UIColor.white.withAlphaComponent(0.60)
                    }
                }
            }
        }
    }
    
    // MARK: - Typography System (SF Pro + Dynamic Type)
    
    enum TypographyToken {
        case displayLarge
        case displayMedium
        case displaySmall
        case headlineLarge
        case headlineMedium
        case headlineSmall
        case titleLarge
        case titleMedium
        case titleSmall
        case bodyLarge
        case bodyMedium
        case bodySmall
        case labelLarge
        case labelMedium
        case labelSmall
        
        var font: UIFont {
            switch self {
            case .displayLarge:
                return UIFont.systemFont(ofSize: 57, weight: .regular, design: .default)
            case .displayMedium:
                return UIFont.systemFont(ofSize: 45, weight: .regular, design: .default)
            case .displaySmall:
                return UIFont.systemFont(ofSize: 36, weight: .regular, design: .default)
            case .headlineLarge:
                return UIFont.systemFont(ofSize: 32, weight: .regular, design: .default)
            case .headlineMedium:
                return UIFont.systemFont(ofSize: 28, weight: .regular, design: .default)
            case .headlineSmall:
                return UIFont.systemFont(ofSize: 24, weight: .regular, design: .default)
            case .titleLarge:
                return UIFont.systemFont(ofSize: 22, weight: .medium, design: .default)
            case .titleMedium:
                return UIFont.systemFont(ofSize: 16, weight: .medium, design: .default)
            case .titleSmall:
                return UIFont.systemFont(ofSize: 14, weight: .medium, design: .default)
            case .bodyLarge:
                return UIFont.systemFont(ofSize: 16, weight: .regular, design: .default)
            case .bodyMedium:
                return UIFont.systemFont(ofSize: 14, weight: .regular, design: .default)
            case .bodySmall:
                return UIFont.systemFont(ofSize: 12, weight: .regular, design: .default)
            case .labelLarge:
                return UIFont.systemFont(ofSize: 14, weight: .medium, design: .default)
            case .labelMedium:
                return UIFont.systemFont(ofSize: 12, weight: .medium, design: .default)
            case .labelSmall:
                return UIFont.systemFont(ofSize: 11, weight: .medium, design: .default)
            }
        }
        
        var scaledFont: UIFont {
            return UIFontMetrics.default.scaledFont(for: font)
        }
        
        var lineHeight: CGFloat {
            switch self {
            case .displayLarge:
                return 64
            case .displayMedium:
                return 52
            case .displaySmall:
                return 44
            case .headlineLarge:
                return 40
            case .headlineMedium:
                return 36
            case .headlineSmall:
                return 32
            case .titleLarge:
                return 28
            case .titleMedium:
                return 24
            case .titleSmall:
                return 20
            case .bodyLarge:
                return 24
            case .bodyMedium:
                return 20
            case .bodySmall:
                return 16
            case .labelLarge:
                return 20
            case .labelMedium:
                return 16
            case .labelSmall:
                return 16
            }
        }
        
        var letterSpacing: CGFloat {
            switch self {
            case .displayLarge, .displayMedium, .displaySmall:
                return 0.0
            case .headlineLarge, .headlineMedium, .headlineSmall:
                return 0.0
            case .titleLarge, .titleMedium, .titleSmall:
                return 0.1
            case .bodyLarge, .bodyMedium, .bodySmall:
                return 0.25
            case .labelLarge, .labelMedium, .labelSmall:
                return 0.4
            }
        }
    }
    
    // MARK: - Spacing System (8dp grid)
    
    enum SpacingToken {
        case xs      // 4dp
        case sm      // 8dp
        case md      // 16dp
        case lg      // 24dp
        case xl      // 32dp
        case xxl     // 48dp
        case xxxl    // 64dp
        
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
    
    // MARK: - Shape System (Material 3 corner radius)
    
    enum ShapeToken {
        case none
        case xs      // 4dp
        case sm      // 8dp
        case md      // 12dp
        case lg      // 16dp
        case xl      // 20dp
        case xxl     // 24dp
        case xxxl    // 28dp
        case full    // 50%
        
        var cornerRadius: CGFloat {
            switch self {
            case .none:
                return 0
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
                return 28
            case .full:
                return -1 // Indicates full circle
            }
        }
    }
    
    // MARK: - Elevation System (Material 3 shadows)
    
    enum ElevationToken {
        case level0
        case level1
        case level2
        case level3
        case level4
        case level5
        
        var shadowProperties: (color: UIColor, opacity: Float, offset: CGSize, radius: CGFloat) {
            switch self {
            case .level0:
                return (UIColor.black, 0, CGSize.zero, 0)
            case .level1:
                return (UIColor.black, 0.05, CGSize(width: 0, height: 1), 2)
            case .level2:
                return (UIColor.black, 0.08, CGSize(width: 0, height: 2), 4)
            case .level3:
                return (UIColor.black, 0.11, CGSize(width: 0, height: 4), 8)
            case .level4:
                return (UIColor.black, 0.14, CGSize(width: 0, height: 6), 12)
            case .level5:
                return (UIColor.black, 0.17, CGSize(width: 0, height: 8), 16)
            }
        }
    }
    
    // MARK: - Component Factory
    
    /// Creates a modern button with Material 3 styling
    static func createModernButton(
        title: String,
        style: ButtonStyle = .filled,
        size: ButtonSize = .medium,
        typography: TypographyToken = .labelLarge
    ) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = typography.scaledFont
        
        switch style {
        case .filled:
            button.backgroundColor = ColorToken.primary.color
            button.setTitleColor(ColorToken.onPrimary.color, for: .normal)
            button.layer.cornerRadius = ShapeToken.md.cornerRadius
            
        case .tonal:
            button.backgroundColor = ColorToken.secondaryContainer.color
            button.setTitleColor(ColorToken.onSecondaryContainer.color, for: .normal)
            button.layer.cornerRadius = ShapeToken.md.cornerRadius
            
        case .outlined:
            button.backgroundColor = UIColor.clear
            button.setTitleColor(ColorToken.primary.color, for: .normal)
            button.layer.cornerRadius = ShapeToken.md.cornerRadius
            button.layer.borderWidth = 1
            button.layer.borderColor = ColorToken.outline.color.cgColor
            
        case .text:
            button.backgroundColor = UIColor.clear
            button.setTitleColor(ColorToken.primary.color, for: .normal)
            button.layer.cornerRadius = ShapeToken.sm.cornerRadius
        }
        
        // Apply elevation
        let elevation = style.elevation
        let shadowProps = elevation.shadowProperties
        button.layer.shadowColor = shadowProps.color.cgColor
        button.layer.shadowOpacity = shadowProps.opacity
        button.layer.shadowOffset = shadowProps.offset
        button.layer.shadowRadius = shadowProps.radius
        button.layer.masksToBounds = false
        
        return button
    }
    
    /// Creates a modern container with Material 3 styling
    static func createModernContainer(
        backgroundColor: ColorToken = .surface,
        cornerRadius: ShapeToken = .md,
        elevation: ElevationToken = .level1,
        padding: SpacingToken = .md
    ) -> UIView {
        let container = UIView()
        container.backgroundColor = backgroundColor.color
        container.layer.cornerRadius = cornerRadius.cornerRadius
        container.layer.cornerCurve = .continuous
        
        // Apply elevation
        let shadowProps = elevation.shadowProperties
        container.layer.shadowColor = shadowProps.color.cgColor
        container.layer.shadowOpacity = shadowProps.opacity
        container.layer.shadowOffset = shadowProps.offset
        container.layer.shadowRadius = shadowProps.radius
        container.layer.masksToBounds = false
        
        // Apply padding
        container.layoutMargins = UIEdgeInsets(
            top: padding.value,
            left: padding.value,
            bottom: padding.value,
            right: padding.value
        )
        
        return container
    }
    
    /// Creates a modern label with typography and color tokens
    static func createModernLabel(
        text: String,
        typography: TypographyToken = .bodyMedium,
        color: ColorToken = .onSurface,
        numberOfLines: Int = 1
    ) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = typography.scaledFont
        label.textColor = color.color
        label.numberOfLines = numberOfLines
        
        // Apply line height and letter spacing
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = typography.lineHeight - typography.font.lineHeight
        paragraphStyle.alignment = .left
        
        let attributedString = NSAttributedString(
            string: text,
            attributes: [
                .font: typography.scaledFont,
                .foregroundColor: color.color,
                .kern: typography.letterSpacing,
                .paragraphStyle: paragraphStyle
            ]
        )
        
        label.attributedText = attributedString
        label.adjustsFontForContentSizeCategory = true
        
        return label
    }
}

// MARK: - Button Styles

enum ButtonStyle {
    case filled
    case tonal
    case outlined
    case text
    
    var elevation: ModernDesignSystem.ElevationToken {
        switch self {
        case .filled, .tonal:
            return .level1
        case .outlined, .text:
            return .level0
        }
    }
}

enum ButtonSize {
    case small
    case medium
    case large
    
    var height: CGFloat {
        switch self {
        case .small:
            return 32
        case .medium:
            return 40
        case .large:
            return 48
        }
    }
}

// MARK: - SwiftUI Integration

@available(iOS 15.0, *)
extension Color {
    init(token: ModernDesignSystem.ColorToken) {
        self.init(uiColor: token.color)
    }
}

@available(iOS 15.0, *)
extension Font {
    init(token: ModernDesignSystem.TypographyToken) {
        self.init(token.scaledFont)
    }
}

// MARK: - UIView Extensions

@available(iOS 15.0, *)
extension UIView {
    
    /// Applies modern design system styling
    func applyModernDesign(
        backgroundColor: ModernDesignSystem.ColorToken = .surface,
        cornerRadius: ModernDesignSystem.ShapeToken = .md,
        elevation: ModernDesignSystem.ElevationToken = .level1
    ) {
        self.backgroundColor = backgroundColor.color
        layer.cornerRadius = cornerRadius.cornerRadius
        layer.cornerCurve = .continuous
        
        let shadowProps = elevation.shadowProperties
        layer.shadowColor = shadowProps.color.cgColor
        layer.shadowOpacity = shadowProps.opacity
        layer.shadowOffset = shadowProps.offset
        layer.shadowRadius = shadowProps.radius
        layer.masksToBounds = false
    }
    
    /// Updates shadow path for better performance
    func updateShadowPath() {
        if layer.cornerRadius > 0 {
            layer.shadowPath = UIBezierPath(
                roundedRect: bounds,
                cornerRadius: layer.cornerRadius
            ).cgPath
        }
    }
    
    override open func layoutSubviews() {
        super.layoutSubviews()
        updateShadowPath()
    }
}