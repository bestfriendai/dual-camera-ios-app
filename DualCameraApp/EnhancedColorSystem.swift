//
//  EnhancedColorSystem.swift
//  DualCameraApp
//
//  Enhanced color system with better contrast, accessibility, and iOS 18+ dynamic colors
//

import UIKit

/// Enhanced color system with accessibility support and dynamic colors
class EnhancedColorSystem {
    
    static let shared = EnhancedColorSystem()
    
    private init() {}
    
    // MARK: - Dynamic Color System
    
    /// Dynamic colors that adapt to light/dark mode and accessibility settings
    enum DynamicColor {
        // Primary brand colors
        case primary
        case primaryVariant
        case onPrimary
        case primaryContainer
        case onPrimaryContainer
        
        // Secondary colors
        case secondary
        case secondaryVariant
        case onSecondary
        case secondaryContainer
        case onSecondaryContainer
        
        // Surface colors
        case background
        case onBackground
        case surface
        case onSurface
        case surfaceVariant
        case onSurfaceVariant
        case surfaceTint
        
        // Outline and border colors
        case outline
        case outlineVariant
        
        // Status colors
        case success
        case onSuccess
        case successContainer
        case onSuccessContainer
        
        case warning
        case onWarning
        case warningContainer
        case onWarningContainer
        
        case error
        case onError
        case errorContainer
        case onErrorContainer
        
        case info
        case onInfo
        case infoContainer
        case onInfoContainer
        
        // Specialized colors for camera app
        case recordingActive
        case recordingInactive
        case cameraPreviewBorder
        case controlBackground
        case onControlBackground
        
        var color: UIColor {
            switch self {
            // Primary colors
            case .primary:
                return UIColor { traitCollection in
                    if traitCollection.userInterfaceStyle == .dark {
                        return UIColor(red: 0.0, green: 0.48, blue: 1.0, alpha: 1.0) // Bright blue for dark mode
                    } else {
                        return UIColor(red: 0.0, green: 0.48, blue: 1.0, alpha: 1.0) // Standard blue
                    }
                }
                
            case .primaryVariant:
                return UIColor { traitCollection in
                    if traitCollection.userInterfaceStyle == .dark {
                        return UIColor(red: 0.0, green: 0.38, blue: 0.84, alpha: 1.0)
                    } else {
                        return UIColor(red: 0.0, green: 0.38, blue: 0.84, alpha: 1.0)
                    }
                }
                
            case .onPrimary:
                return UIColor { traitCollection in
                    return UIColor.white
                }
                
            case .primaryContainer:
                return UIColor { traitCollection in
                    if traitCollection.userInterfaceStyle == .dark {
                        return UIColor(red: 0.0, green: 0.28, blue: 0.62, alpha: 1.0)
                    } else {
                        return UIColor(red: 0.85, green: 0.92, blue: 1.0, alpha: 1.0)
                    }
                }
                
            case .onPrimaryContainer:
                return UIColor { traitCollection in
                    if traitCollection.userInterfaceStyle == .dark {
                        return UIColor.white
                    } else {
                        return UIColor(red: 0.0, green: 0.28, blue: 0.62, alpha: 1.0)
                    }
                }
                
            // Secondary colors
            case .secondary:
                return UIColor { traitCollection in
                    if traitCollection.userInterfaceStyle == .dark {
                        return UIColor(red: 0.47, green: 0.47, blue: 0.5, alpha: 1.0)
                    } else {
                        return UIColor(red: 0.47, green: 0.47, blue: 0.5, alpha: 1.0)
                    }
                }
                
            case .secondaryVariant:
                return UIColor { traitCollection in
                    if traitCollection.userInterfaceStyle == .dark {
                        return UIColor(red: 0.58, green: 0.58, blue: 0.61, alpha: 1.0)
                    } else {
                        return UIColor(red: 0.58, green: 0.58, blue: 0.61, alpha: 1.0)
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
                        return UIColor(red: 0.31, green: 0.31, blue: 0.34, alpha: 1.0)
                    } else {
                        return UIColor(red: 0.82, green: 0.82, blue: 0.85, alpha: 1.0)
                    }
                }
                
            case .onSecondaryContainer:
                return UIColor { traitCollection in
                    if traitCollection.userInterfaceStyle == .dark {
                        return UIColor.white
                    } else {
                        return UIColor(red: 0.16, green: 0.16, blue: 0.18, alpha: 1.0)
                    }
                }
                
            // Surface colors
            case .background:
                return UIColor { traitCollection in
                    if traitCollection.userInterfaceStyle == .dark {
                        return UIColor(red: 0.06, green: 0.06, blue: 0.09, alpha: 1.0) // Very dark blue-tinted
                    } else {
                        return UIColor(red: 0.98, green: 0.98, blue: 1.0, alpha: 1.0) // Very light blue-tinted
                    }
                }
                
            case .onBackground:
                return UIColor { traitCollection in
                    if traitCollection.userInterfaceStyle == .dark {
                        return UIColor(red: 0.98, green: 0.98, blue: 1.0, alpha: 1.0)
                    } else {
                        return UIColor(red: 0.06, green: 0.06, blue: 0.09, alpha: 1.0)
                    }
                }
                
            case .surface:
                return UIColor { traitCollection in
                    if traitCollection.userInterfaceStyle == .dark {
                        return UIColor(red: 0.11, green: 0.11, blue: 0.16, alpha: 1.0) // Dark surface
                    } else {
                        return UIColor(red: 0.94, green: 0.94, blue: 0.97, alpha: 1.0) // Light surface
                    }
                }
                
            case .onSurface:
                return UIColor { traitCollection in
                    if traitCollection.userInterfaceStyle == .dark {
                        return UIColor(red: 0.98, green: 0.98, blue: 1.0, alpha: 1.0)
                    } else {
                        return UIColor(red: 0.06, green: 0.06, blue: 0.09, alpha: 1.0)
                    }
                }
                
            case .surfaceVariant:
                return UIColor { traitCollection in
                    if traitCollection.userInterfaceStyle == .dark {
                        return UIColor(red: 0.16, green: 0.16, blue: 0.22, alpha: 1.0)
                    } else {
                        return UIColor(red: 0.89, green: 0.89, blue: 0.93, alpha: 1.0)
                    }
                }
                
            case .onSurfaceVariant:
                return UIColor { traitCollection in
                    if traitCollection.userInterfaceStyle == .dark {
                        return UIColor(red: 0.82, green: 0.82, blue: 0.85, alpha: 1.0)
                    } else {
                        return UIColor(red: 0.31, green: 0.31, blue: 0.34, alpha: 1.0)
                    }
                }
                
            case .surfaceTint:
                return UIColor { traitCollection in
                    return DynamicColor.primary.color
                }
                
            // Outline colors
            case .outline:
                return UIColor { traitCollection in
                    if traitCollection.userInterfaceStyle == .dark {
                        return UIColor(red: 0.47, green: 0.47, blue: 0.5, alpha: 1.0)
                    } else {
                        return UIColor(red: 0.58, green: 0.58, blue: 0.61, alpha: 1.0)
                    }
                }
                
            case .outlineVariant:
                return UIColor { traitCollection in
                    if traitCollection.userInterfaceStyle == .dark {
                        return UIColor(red: 0.31, green: 0.31, blue: 0.34, alpha: 1.0)
                    } else {
                        return UIColor(red: 0.82, green: 0.82, blue: 0.85, alpha: 1.0)
                    }
                }
                
            // Status colors
            case .success:
                return UIColor { traitCollection in
                    if traitCollection.userInterfaceStyle == .dark {
                        return UIColor(red: 0.0, green: 0.8, blue: 0.4, alpha: 1.0)
                    } else {
                        return UIColor(red: 0.0, green: 0.6, blue: 0.3, alpha: 1.0)
                    }
                }
                
            case .onSuccess:
                return UIColor.white
                
            case .successContainer:
                return UIColor { traitCollection in
                    if traitCollection.userInterfaceStyle == .dark {
                        return UIColor(red: 0.0, green: 0.4, blue: 0.2, alpha: 1.0)
                    } else {
                        return UIColor(red: 0.8, green: 1.0, blue: 0.9, alpha: 1.0)
                    }
                }
                
            case .onSuccessContainer:
                return UIColor { traitCollection in
                    if traitCollection.userInterfaceStyle == .dark {
                        return UIColor.white
                    } else {
                        return UIColor(red: 0.0, green: 0.2, blue: 0.1, alpha: 1.0)
                    }
                }
                
            case .warning:
                return UIColor { traitCollection in
                    if traitCollection.userInterfaceStyle == .dark {
                        return UIColor(red: 1.0, green: 0.8, blue: 0.0, alpha: 1.0)
                    } else {
                        return UIColor(red: 0.8, green: 0.6, blue: 0.0, alpha: 1.0)
                    }
                }
                
            case .onWarning:
                return UIColor.black
                
            case .warningContainer:
                return UIColor { traitCollection in
                    if traitCollection.userInterfaceStyle == .dark {
                        return UIColor(red: 0.5, green: 0.4, blue: 0.0, alpha: 1.0)
                    } else {
                        return UIColor(red: 1.0, green: 0.95, blue: 0.8, alpha: 1.0)
                    }
                }
                
            case .onWarningContainer:
                return UIColor { traitCollection in
                    if traitCollection.userInterfaceStyle == .dark {
                        return UIColor.white
                    } else {
                        return UIColor(red: 0.25, green: 0.2, blue: 0.0, alpha: 1.0)
                    }
                }
                
            case .error:
                return UIColor { traitCollection in
                    if traitCollection.userInterfaceStyle == .dark {
                        return UIColor(red: 1.0, green: 0.4, blue: 0.4, alpha: 1.0)
                    } else {
                        return UIColor(red: 0.8, green: 0.2, blue: 0.2, alpha: 1.0)
                    }
                }
                
            case .onError:
                return UIColor.white
                
            case .errorContainer:
                return UIColor { traitCollection in
                    if traitCollection.userInterfaceStyle == .dark {
                        return UIColor(red: 0.5, green: 0.2, blue: 0.2, alpha: 1.0)
                    } else {
                        return UIColor(red: 1.0, green: 0.9, blue: 0.9, alpha: 1.0)
                    }
                }
                
            case .onErrorContainer:
                return UIColor { traitCollection in
                    if traitCollection.userInterfaceStyle == .dark {
                        return UIColor.white
                    } else {
                        return UIColor(red: 0.25, green: 0.1, blue: 0.1, alpha: 1.0)
                    }
                }
                
            case .info:
                return UIColor { traitCollection in
                    if traitCollection.userInterfaceStyle == .dark {
                        return UIColor(red: 0.4, green: 0.8, blue: 1.0, alpha: 1.0)
                    } else {
                        return UIColor(red: 0.2, green: 0.6, blue: 0.8, alpha: 1.0)
                    }
                }
                
            case .onInfo:
                return UIColor.white
                
            case .infoContainer:
                return UIColor { traitCollection in
                    if traitCollection.userInterfaceStyle == .dark {
                        return UIColor(red: 0.2, green: 0.4, blue: 0.5, alpha: 1.0)
                    } else {
                        return UIColor(red: 0.9, green: 0.98, blue: 1.0, alpha: 1.0)
                    }
                }
                
            case .onInfoContainer:
                return UIColor { traitCollection in
                    if traitCollection.userInterfaceStyle == .dark {
                        return UIColor.white
                    } else {
                        return UIColor(red: 0.1, green: 0.3, blue: 0.4, alpha: 1.0)
                    }
                }
                
            // Specialized camera app colors
            case .recordingActive:
                return UIColor { traitCollection in
                    return UIColor(red: 1.0, green: 0.23, blue: 0.19, alpha: 1.0) // Bright red for recording
                }
                
            case .recordingInactive:
                return UIColor { traitCollection in
                    if traitCollection.userInterfaceStyle == .dark {
                        return UIColor(red: 0.6, green: 0.6, blue: 0.6, alpha: 1.0)
                    } else {
                        return UIColor(red: 0.4, green: 0.4, blue: 0.4, alpha: 1.0)
                    }
                }
                
            case .cameraPreviewBorder:
                return UIColor { traitCollection in
                    if traitCollection.userInterfaceStyle == .dark {
                        return UIColor.white.withAlphaComponent(0.3)
                    } else {
                        return UIColor.black.withAlphaComponent(0.2)
                    }
                }
                
            case .controlBackground:
                return UIColor { traitCollection in
                    if traitCollection.userInterfaceStyle == .dark {
                        return UIColor.black.withAlphaComponent(0.6)
                    } else {
                        return UIColor.white.withAlphaComponent(0.8)
                    }
                }
                
            case .onControlBackground:
                return UIColor { traitCollection in
                    if traitCollection.userInterfaceStyle == .dark {
                        return UIColor.white
                    } else {
                        return UIColor.black
                    }
                }
            }
        }
    }
    
    // MARK: - Accessibility Support
    
    /// High contrast variants for better accessibility
    enum HighContrastColor {
        case primary
        case secondary
        case background
        case surface
        case text
        case border
        
        var color: UIColor {
            switch self {
            case .primary:
                return UIColor { traitCollection in
                    if traitCollection.accessibilityContrast == .high {
                        return UIColor.systemBlue
                    } else {
                        return DynamicColor.primary.color
                    }
                }
                
            case .secondary:
                return UIColor { traitCollection in
                    if traitCollection.accessibilityContrast == .high {
                        return UIColor.systemGray
                    } else {
                        return DynamicColor.secondary.color
                    }
                }
                
            case .background:
                return UIColor { traitCollection in
                    if traitCollection.accessibilityContrast == .high {
                        if traitCollection.userInterfaceStyle == .dark {
                            return UIColor.black
                        } else {
                            return UIColor.white
                        }
                    } else {
                        return DynamicColor.background.color
                    }
                }
                
            case .surface:
                return UIColor { traitCollection in
                    if traitCollection.accessibilityContrast == .high {
                        if traitCollection.userInterfaceStyle == .dark {
                            return UIColor.black
                        } else {
                            return UIColor.white
                        }
                    } else {
                        return DynamicColor.surface.color
                    }
                }
                
            case .text:
                return UIColor { traitCollection in
                    if traitCollection.accessibilityContrast == .high {
                        if traitCollection.userInterfaceStyle == .dark {
                            return UIColor.white
                        } else {
                            return UIColor.black
                        }
                    } else {
                        return DynamicColor.onBackground.color
                    }
                }
                
            case .border:
                return UIColor { traitCollection in
                    if traitCollection.accessibilityContrast == .high {
                        if traitCollection.userInterfaceStyle == .dark {
                            return UIColor.white.withAlphaComponent(0.5)
                        } else {
                            return UIColor.black.withAlphaComponent(0.3)
                        }
                    } else {
                        return DynamicColor.outline.color
                    }
                }
            }
        }
    }
    
    // MARK: - Color Utilities
    
    /// Returns the appropriate color based on accessibility settings
    static func adaptiveColor(
        _ dynamicColor: DynamicColor,
        highContrastVariant: HighContrastColor? = nil
    ) -> UIColor {
        if let highContrastVariant = highContrastVariant {
            return UIColor { traitCollection in
                if traitCollection.accessibilityContrast == .high {
                    return highContrastVariant.color.resolvedColor(with: traitCollection)
                } else {
                    return dynamicColor.color.resolvedColor(with: traitCollection)
                }
            }
        } else {
            return dynamicColor.color
        }
    }
    
    /// Creates a gradient with dynamic colors
    static func createDynamicGradient(
        colors: [DynamicColor],
        locations: [NSNumber]? = nil,
        startPoint: CGPoint = CGPoint(x: 0, y: 0),
        endPoint: CGPoint = CGPoint(x: 1, y: 1)
    ) -> CAGradientLayer {
        let gradient = CAGradientLayer()
        gradient.startPoint = startPoint
        gradient.endPoint = endPoint
        gradient.locations = locations
        
        // The colors will be updated dynamically in updateGradientColors
        return gradient
    }
    
    /// Updates gradient colors for current trait collection
    static func updateGradientColors(
        _ gradient: CAGradientLayer,
        colors: [DynamicColor],
        traitCollection: UITraitCollection
    ) {
        gradient.colors = colors.map { $0.color.resolvedColor(with: traitCollection).cgColor }
    }
    
    /// Checks if two colors have sufficient contrast
    static func hasSufficientContrast(
        between color1: UIColor,
        and color2: UIColor,
        ratio: CGFloat = 4.5
    ) -> Bool {
        return color1.contrastRatio(with: color2) >= ratio
    }
    
    /// Returns a color with adjusted luminance for better contrast
    static func adjustedColorForContrast(
        _ color: UIColor,
        against backgroundColor: UIColor,
        targetRatio: CGFloat = 4.5
    ) -> UIColor {
        var adjustedColor = color
        
        while !hasSufficientContrast(between: adjustedColor, and: backgroundColor, ratio: targetRatio) {
            // Adjust luminance
            let currentLuminance = adjustedColor.luminance
            let bgLuminance = backgroundColor.luminance
            
            if bgLuminance > 0.5 {
                // Dark background, make color lighter
                adjustedColor = adjustedColor.adjustingLuminance(by: 0.1)
            } else {
                // Light background, make color darker
                adjustedColor = adjustedColor.adjustingLuminance(by: -0.1)
            }
            
            // Prevent infinite loop
            if adjustedColor.luminance <= 0.0 || adjustedColor.luminance >= 1.0 {
                break
            }
        }
        
        return adjustedColor
    }
}

// MARK: - UIColor Extensions for Color System

extension UIColor {
    
    /// Calculates the relative luminance of a color
    var luminance: CGFloat {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        
        getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        // Normalize to 0-1 range
        red = red <= 0.03928 ? red / 12.92 : pow((red + 0.055) / 1.055, 2.4)
        green = green <= 0.03928 ? green / 12.92 : pow((green + 0.055) / 1.055, 2.4)
        blue = blue <= 0.03928 ? blue / 12.92 : pow((blue + 0.055) / 1.055, 2.4)
        
        return 0.2126 * red + 0.7152 * green + 0.0722 * blue
    }
    
    /// Calculates the contrast ratio between two colors
    func contrastRatio(with otherColor: UIColor) -> CGFloat {
        let luminance1 = luminance
        let luminance2 = otherColor.luminance
        
        let lighter = max(luminance1, luminance2)
        let darker = min(luminance1, luminance2)
        
        return (lighter + 0.05) / (darker + 0.05)
    }
    
    /// Adjusts the luminance of a color
    func adjustingLuminance(by amount: CGFloat) -> UIColor {
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        
        getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        
        let newBrightness = max(0.0, min(1.0, brightness + amount))
        
        return UIColor(hue: hue, saturation: saturation, brightness: newBrightness, alpha: alpha)
    }
    
    /// Returns a color with reduced opacity for better readability
    func withReducedOpacity(for readability: Bool = true) -> UIColor {
        if readability {
            return withAlphaComponent(0.8)
        } else {
            return self
        }
    }
    
    /// Creates a color that adapts to the current trait collection
    static func adaptive(
        light: UIColor,
        dark: UIColor,
        highContrastLight: UIColor? = nil,
        highContrastDark: UIColor? = nil
    ) -> UIColor {
        return UIColor { traitCollection in
            if traitCollection.accessibilityContrast == .high {
                if traitCollection.userInterfaceStyle == .dark {
                    return highContrastDark ?? dark
                } else {
                    return highContrastLight ?? light
                }
            } else {
                if traitCollection.userInterfaceStyle == .dark {
                    return dark
                } else {
                    return light
                }
            }
        }
    }
}

// MARK: - Color Theme Manager

class ColorThemeManager {
    
    static let shared = ColorThemeManager()
    
    private init() {}
    
    /// Current theme mode
    enum ThemeMode {
        case system
        case light
        case dark
        case highContrast
    }
    
    var currentTheme: ThemeMode = .system {
        didSet {
            updateTheme()
        }
    }
    
    /// Updates the app's appearance based on current theme
    private func updateTheme() {
        DispatchQueue.main.async {
            switch self.currentTheme {
            case .system:
                // Let system decide
                break
            case .light:
                // Force light mode
                break
            case .dark:
                // Force dark mode
                break
            case .highContrast:
                // Enable high contrast
                break
            }
        }
    }
    
    /// Returns the appropriate color for the current theme
    func color(for dynamicColor: EnhancedColorSystem.DynamicColor) -> UIColor {
        switch currentTheme {
        case .system:
            return dynamicColor.color
        case .light:
            return dynamicColor.color.resolvedColor(with: UITraitCollection(userInterfaceStyle: .light))
        case .dark:
            return dynamicColor.color.resolvedColor(with: UITraitCollection(userInterfaceStyle: .dark))
        case .highContrast:
            // Return high contrast variant if available
            return dynamicColor.color
        }
    }
}