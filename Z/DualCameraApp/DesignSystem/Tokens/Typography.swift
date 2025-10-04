//
//  Typography.swift
//  DualApp
//
//  Created by DualApp Team on 10/3/25.
//

import SwiftUI

// MARK: - Design Typography

struct DesignTypography {
    
    // MARK: - Font Families
    
    struct FontFamily {
        let primary: String
        let secondary: String
        let monospace: String
        let display: String
        
        static let system = FontFamily(
            primary: "SF Pro Display",
            secondary: "SF Pro Text",
            monospace: "SF Mono",
            display: "SF Pro Display"
        )
        
        static let rounded = FontFamily(
            primary: "SF Pro Rounded",
            secondary: "SF Pro Rounded",
            monospace: "SF Mono",
            display: "SF Pro Rounded"
        )
        
        static let compact = FontFamily(
            primary: "Helvetica Neue",
            secondary: "Helvetica Neue",
            monospace: "Courier New",
            display: "Helvetica Neue"
        )
    }
    
    // MARK: - Font Sizes
    
    struct FontSize {
        let xs: CGFloat
        let sm: CGFloat
        let base: CGFloat
        let lg: CGFloat
        let xl: CGFloat
        let xl2: CGFloat
        let xl3: CGFloat
        let xl4: CGFloat
        let xl5: CGFloat
        let xl6: CGFloat
        
        static let compact = FontSize(
            xs: 10,
            sm: 12,
            base: 14,
            lg: 16,
            xl: 18,
            xl2: 20,
            xl3: 24,
            xl4: 30,
            xl5: 36,
            xl6: 48
        )
        
        static let standard = FontSize(
            xs: 12,
            sm: 14,
            base: 16,
            lg: 18,
            xl: 20,
            xl2: 24,
            xl3: 30,
            xl4: 36,
            xl5: 48,
            xl6: 60
        )
        
        static let large = FontSize(
            xs: 14,
            sm: 16,
            base: 18,
            lg: 20,
            xl: 24,
            xl2: 30,
            xl3: 36,
            xl4: 48,
            xl5: 60,
            xl6: 72
        )
    }
    
    // MARK: - Font Weights
    
    struct FontWeight {
        let thin: Font.Weight
        let light: Font.Weight
        let regular: Font.Weight
        let medium: Font.Weight
        let semibold: Font.Weight
        let bold: Font.Weight
        let heavy: Font.Weight
        let black: Font.Weight
        
        static let system = FontWeight(
            thin: .thin,
            light: .light,
            regular: .regular,
            medium: .medium,
            semibold: .semibold,
            bold: .bold,
            heavy: .heavy,
            black: .black
        )
    }
    
    // MARK: - Line Heights
    
    struct LineHeight {
        let tight: CGFloat
        let snug: CGFloat
        let normal: CGFloat
        let relaxed: CGFloat
        let loose: CGFloat
        
        static let compact = LineHeight(
            tight: 1.0,
            snug: 1.2,
            normal: 1.4,
            relaxed: 1.6,
            loose: 1.8
        )
        
        static let standard = LineHeight(
            tight: 1.1,
            snug: 1.3,
            normal: 1.5,
            relaxed: 1.7,
            loose: 2.0
        )
        
        static let spacious = LineHeight(
            tight: 1.2,
            snug: 1.4,
            normal: 1.6,
            relaxed: 1.8,
            loose: 2.2
        )
    }
    
    // MARK: - Letter Spacing
    
    struct LetterSpacing {
        let tight: CGFloat
        let normal: CGFloat
        let wide: CGFloat
        let wider: CGFloat
        let widest: CGFloat
        
        static let compact = LetterSpacing(
            tight: -0.5,
            normal: 0,
            wide: 0.5,
            wider: 1.0,
            widest: 1.5
        )
        
        static let standard = LetterSpacing(
            tight: -0.25,
            normal: 0,
            wide: 0.25,
            wider: 0.5,
            widest: 1.0
        )
        
        static let spacious = LetterSpacing(
            tight: 0,
            normal: 0.25,
            wide: 0.5,
            wider: 1.0,
            widest: 1.5
        )
    }
    
    // MARK: - Text Styles
    
    struct TextStyle {
        let font: Font
        let lineHeight: CGFloat
        let letterSpacing: CGFloat
        let color: Color
        let weight: Font.Weight
        
        init(
            size: CGFloat,
            weight: Font.Weight = .regular,
            design: Font.Design = .default,
            lineHeight: CGFloat = 1.5,
            letterSpacing: CGFloat = 0,
            color: Color = .primary
        ) {
            self.font = Font.system(size: size, weight: weight, design: design)
            self.lineHeight = lineHeight
            self.letterSpacing = letterSpacing
            self.color = color
            self.weight = weight
        }
    }
    
    // MARK: - Predefined Text Styles
    
    struct TextStyles {
        
        // MARK: - Display Styles
        
        static let displayLarge = TextStyle(
            size: 60,
            weight: .bold,
            design: .rounded,
            lineHeight: 1.1,
            letterSpacing: -0.5,
            color: DesignColors.textPrimary
        )
        
        static let displayMedium = TextStyle(
            size: 48,
            weight: .bold,
            design: .rounded,
            lineHeight: 1.2,
            letterSpacing: -0.25,
            color: DesignColors.textPrimary
        )
        
        static let displaySmall = TextStyle(
            size: 36,
            weight: .semibold,
            design: .rounded,
            lineHeight: 1.3,
            letterSpacing: 0,
            color: DesignColors.textPrimary
        )
        
        // MARK: - Heading Styles
        
        static let headingLarge = TextStyle(
            size: 30,
            weight: .semibold,
            design: .rounded,
            lineHeight: 1.3,
            letterSpacing: 0,
            color: DesignColors.textPrimary
        )
        
        static let headingMedium = TextStyle(
            size: 24,
            weight: .semibold,
            design: .rounded,
            lineHeight: 1.4,
            letterSpacing: 0,
            color: DesignColors.textPrimary
        )
        
        static let headingSmall = TextStyle(
            size: 20,
            weight: .medium,
            design: .rounded,
            lineHeight: 1.4,
            letterSpacing: 0,
            color: DesignColors.textPrimary
        )
        
        // MARK: - Title Styles
        
        static let titleLarge = TextStyle(
            size: 18,
            weight: .medium,
            design: .default,
            lineHeight: 1.4,
            letterSpacing: 0,
            color: DesignColors.textPrimary
        )
        
        static let titleMedium = TextStyle(
            size: 16,
            weight: .medium,
            design: .default,
            lineHeight: 1.5,
            letterSpacing: 0,
            color: DesignColors.textPrimary
        )
        
        static let titleSmall = TextStyle(
            size: 14,
            weight: .medium,
            design: .default,
            lineHeight: 1.5,
            letterSpacing: 0,
            color: DesignColors.textPrimary
        )
        
        // MARK: - Body Styles
        
        static let bodyLarge = TextStyle(
            size: 16,
            weight: .regular,
            design: .default,
            lineHeight: 1.6,
            letterSpacing: 0,
            color: DesignColors.textPrimary
        )
        
        static let bodyMedium = TextStyle(
            size: 14,
            weight: .regular,
            design: .default,
            lineHeight: 1.5,
            letterSpacing: 0,
            color: DesignColors.textPrimary
        )
        
        static let bodySmall = TextStyle(
            size: 12,
            weight: .regular,
            design: .default,
            lineHeight: 1.4,
            letterSpacing: 0,
            color: DesignColors.textSecondary
        )
        
        // MARK: - Label Styles
        
        static let labelLarge = TextStyle(
            size: 14,
            weight: .medium,
            design: .default,
            lineHeight: 1.4,
            letterSpacing: 0.25,
            color: DesignColors.textPrimary
        )
        
        static let labelMedium = TextStyle(
            size: 12,
            weight: .medium,
            design: .default,
            lineHeight: 1.3,
            letterSpacing: 0.25,
            color: DesignColors.textSecondary
        )
        
        static let labelSmall = TextStyle(
            size: 10,
            weight: .medium,
            design: .default,
            lineHeight: 1.3,
            letterSpacing: 0.5,
            color: DesignColors.textTertiary
        )
        
        // MARK: - Caption Styles
        
        static let caption = TextStyle(
            size: 10,
            weight: .regular,
            design: .default,
            lineHeight: 1.3,
            letterSpacing: 0.25,
            color: DesignColors.textTertiary
        )
        
        // MARK: - Code Styles
        
        static let code = TextStyle(
            size: 14,
            weight: .regular,
            design: .monospaced,
            lineHeight: 1.4,
            letterSpacing: 0,
            color: DesignColors.textPrimary
        )
        
        static let codeSmall = TextStyle(
            size: 12,
            weight: .regular,
            design: .monospaced,
            lineHeight: 1.3,
            letterSpacing: 0,
            color: DesignColors.textSecondary
        )
        
        // MARK: - Button Styles
        
        static let buttonLarge = TextStyle(
            size: 16,
            weight: .semibold,
            design: .rounded,
            lineHeight: 1.2,
            letterSpacing: 0.5,
            color: DesignColors.textOnGlass
        )
        
        static let buttonMedium = TextStyle(
            size: 14,
            weight: .semibold,
            design: .rounded,
            lineHeight: 1.2,
            letterSpacing: 0.5,
            color: DesignColors.textOnGlass
        )
        
        static let buttonSmall = TextStyle(
            size: 12,
            weight: .medium,
            design: .rounded,
            lineHeight: 1.2,
            letterSpacing: 0.5,
            color: DesignColors.textOnGlass
        )
    }
}

// MARK: - Typography Extensions

extension Font {
    
    // MARK: - Custom Font Methods
    
    static func display(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        return Font.system(size: size, weight: weight, design: .rounded)
    }
    
    static func body(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        return Font.system(size: size, weight: weight, design: .default)
    }
    
    static func title(size: CGFloat, weight: Font.Weight = .medium) -> Font {
        return Font.system(size: size, weight: weight, design: .rounded)
    }
    
    static func label(size: CGFloat, weight: Font.Weight = .medium) -> Font {
        return Font.system(size: size, weight: weight, design: .default)
    }
    
    static func code(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        return Font.system(size: size, weight: weight, design: .monospaced)
    }
    
    // MARK: - Responsive Font Methods
    
    static func responsive(_ size: CGFloat, weight: Font.Weight = .regular, design: Font.Design = .default) -> Font {
        let scaledSize = size * DynamicTypeScale.current
        return Font.system(size: scaledSize, weight: weight, design: design)
    }
    
    static func adaptive(min: CGFloat, max: CGFloat, weight: Font.Weight = .regular, design: Font.Design = .default) -> Font {
        let size = max(min, min(max, min * DynamicTypeScale.current))
        return Font.system(size: size, weight: weight, design: design)
    }
}

// MARK: - View Modifiers

extension View {
    
    func textStyle(_ style: DesignTypography.TextStyle) -> some View {
        self
            .font(style.font)
            .foregroundColor(style.color)
            .lineSpacing(style.lineHeight * style.font.size - style.font.size)
            .tracking(style.letterSpacing)
    }
    
    func textStyle(_ style: DesignTypography.TextStyle, color: Color) -> some View {
        self
            .font(style.font)
            .foregroundColor(color)
            .lineSpacing(style.lineHeight * style.font.size - style.font.size)
            .tracking(style.letterSpacing)
    }
    
    func typographyDisplay(size: CGFloat = 60, weight: Font.Weight = .bold) -> some View {
        self.font(.display(size: size, weight: weight))
    }
    
    func typographyTitle(size: CGFloat = 24, weight: Font.Weight = .semibold) -> some View {
        self.font(.title(size: size, weight: weight))
    }
    
    func typographyBody(size: CGFloat = 16, weight: Font.Weight = .regular) -> some View {
        self.font(.body(size: size, weight: weight))
    }
    
    func typographyLabel(size: CGFloat = 14, weight: Font.Weight = .medium) -> some View {
        self.font(.label(size: size, weight: weight))
    }
    
    func typographyCode(size: CGFloat = 14, weight: Font.Weight = .regular) -> some View {
        self.font(.code(size: size, weight: weight))
    }
    
    func typographyResponsive(size: CGFloat, weight: Font.Weight = .regular, design: Font.Design = .default) -> some View {
        self.font(.responsive(size, weight: weight, design: design))
    }
    
    func typographyAdaptive(min: CGFloat, max: CGFloat, weight: Font.Weight = .regular, design: Font.Design = .default) -> some View {
        self.font(.adaptive(min: min, max: max, weight: weight, design: design))
    }
}

// MARK: - Dynamic Type Support

struct DynamicTypeScale {
    static var current: CGFloat {
        #if os(iOS)
        return UIFont.preferredFont(forTextStyle: .body).pointSize / 17.0
        #else
        return 1.0
        #endif
    }
    
    static var isAccessibilityCategory: Bool {
        #if os(iOS)
        let contentSize = UIApplication.shared.preferredContentSizeCategory
        return contentSize.isAccessibilityCategory
        #else
        return false
        #endif
    }
}

// MARK: - Typography Presets

struct TypographyPresets {
    
    // MARK: - Glass Typography
    
    struct Glass {
        static let title = DesignTypography.TextStyle(
            size: 24,
            weight: .semibold,
            design: .rounded,
            lineHeight: 1.3,
            letterSpacing: 0,
            color: DesignColors.textOnGlass
        )
        
        static let subtitle = DesignTypography.TextStyle(
            size: 18,
            weight: .medium,
            design: .rounded,
            lineHeight: 1.4,
            letterSpacing: 0,
            color: DesignColors.textOnGlassSecondary
        )
        
        static let body = DesignTypography.TextStyle(
            size: 16,
            weight: .regular,
            design: .default,
            lineHeight: 1.5,
            letterSpacing: 0,
            color: DesignColors.textOnGlass
        )
        
        static let caption = DesignTypography.TextStyle(
            size: 12,
            weight: .regular,
            design: .default,
            lineHeight: 1.4,
            letterSpacing: 0.25,
            color: DesignColors.textOnGlassTertiary
        )
    }
    
    // MARK: - Camera UI Typography
    
    struct Camera {
        static let controlLabel = DesignTypography.TextStyle(
            size: 12,
            weight: .medium,
            design: .rounded,
            lineHeight: 1.2,
            letterSpacing: 0.5,
            color: DesignColors.textOnGlass
        )
        
        static let statusText = DesignTypography.TextStyle(
            size: 14,
            weight: .semibold,
            design: .rounded,
            lineHeight: 1.3,
            letterSpacing: 0,
            color: DesignColors.textPrimary
        )
        
        static let timerText = DesignTypography.TextStyle(
            size: 32,
            weight: .bold,
            design: .rounded,
            lineHeight: 1.1,
            letterSpacing: -0.5,
            color: DesignColors.recordingActive
        )
        
        static let settingsLabel = DesignTypography.TextStyle(
            size: 16,
            weight: .medium,
            design: .default,
            lineHeight: 1.4,
            letterSpacing: 0,
            color: DesignColors.textPrimary
        )
    }
    
    // MARK: - Accessibility Typography
    
    struct Accessibility {
        static let largeText = DesignTypography.TextStyle(
            size: 24,
            weight: .regular,
            design: .default,
            lineHeight: 1.6,
            letterSpacing: 0,
            color: DesignColors.textPrimary
        )
        
        static let highContrast = DesignTypography.TextStyle(
            size: 16,
            weight: .semibold,
            design: .default,
            lineHeight: 1.5,
            letterSpacing: 0.25,
            color: DesignColors.textPrimary
        )
        
        static let reducedMotion = DesignTypography.TextStyle(
            size: 16,
            weight: .regular,
            design: .default,
            lineHeight: 1.5,
            letterSpacing: 0,
            color: DesignColors.textPrimary
        )
    }
}

// MARK: - Text Style Builder

struct TextStyleBuilder {
    private var size: CGFloat = 16
    private var weight: Font.Weight = .regular
    private var design: Font.Design = .default
    private var lineHeight: CGFloat = 1.5
    private var letterSpacing: CGFloat = 0
    private var color: Color = .primary
    
    func size(_ size: CGFloat) -> TextStyleBuilder {
        var builder = self
        builder.size = size
        return builder
    }
    
    func weight(_ weight: Font.Weight) -> TextStyleBuilder {
        var builder = self
        builder.weight = weight
        return builder
    }
    
    func design(_ design: Font.Design) -> TextStyleBuilder {
        var builder = self
        builder.design = design
        return builder
    }
    
    func lineHeight(_ lineHeight: CGFloat) -> TextStyleBuilder {
        var builder = self
        builder.lineHeight = lineHeight
        return builder
    }
    
    func letterSpacing(_ letterSpacing: CGFloat) -> TextStyleBuilder {
        var builder = self
        builder.letterSpacing = letterSpacing
        return builder
    }
    
    func color(_ color: Color) -> TextStyleBuilder {
        var builder = self
        builder.color = color
        return builder
    }
    
    func build() -> DesignTypography.TextStyle {
        return DesignTypography.TextStyle(
            size: size,
            weight: weight,
            design: design,
            lineHeight: lineHeight,
            letterSpacing: letterSpacing,
            color: color
        )
    }
}

// MARK: - Convenience Extensions

extension DesignTypography.TextStyle {
    
    func withColor(_ color: Color) -> DesignTypography.TextStyle {
        return DesignTypography.TextStyle(
            size: font.size,
            weight: weight,
            design: font.design ?? .default,
            lineHeight: lineHeight,
            letterSpacing: letterSpacing,
            color: color
        )
    }
    
    func withWeight(_ weight: Font.Weight) -> DesignTypography.TextStyle {
        return DesignTypography.TextStyle(
            size: font.size,
            weight: weight,
            design: font.design ?? .default,
            lineHeight: lineHeight,
            letterSpacing: letterSpacing,
            color: color
        )
    }
    
    func withSize(_ size: CGFloat) -> DesignTypography.TextStyle {
        return DesignTypography.TextStyle(
            size: size,
            weight: weight,
            design: font.design ?? .default,
            lineHeight: lineHeight,
            letterSpacing: letterSpacing,
            color: color
        )
    }
}