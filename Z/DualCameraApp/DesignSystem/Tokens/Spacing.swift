//
//  Spacing.swift
//  DualApp
//
//  Created by DualApp Team on 10/3/25.
//

import SwiftUI

// MARK: - Design Spacing

struct DesignSpacing {
    
    // MARK: - Spacing Scale
    
    struct SpacingScale {
        let xs: CGFloat
        let sm: CGFloat
        let md: CGFloat
        let lg: CGFloat
        let xl: CGFloat
        let xl2: CGFloat
        let xl3: CGFloat
        let xl4: CGFloat
        let xl5: CGFloat
        let xl6: CGFloat
        
        static let compact = SpacingScale(
            xs: 2,
            sm: 4,
            md: 8,
            lg: 12,
            xl: 16,
            xl2: 20,
            xl3: 24,
            xl4: 32,
            xl5: 48,
            xl6: 64
        )
        
        static let standard = SpacingScale(
            xs: 4,
            sm: 8,
            md: 16,
            lg: 24,
            xl: 32,
            xl2: 48,
            xl3: 64,
            xl4: 96,
            xl5: 128,
            xl6: 192
        )
        
        static let spacious = SpacingScale(
            xs: 6,
            sm: 12,
            md: 24,
            lg: 36,
            xl: 48,
            xl2: 72,
            xl3: 96,
            xl4: 144,
            xl5: 192,
            xl6: 288
        )
    }
    
    // MARK: - Component Spacing
    
    struct ComponentSpacing {
        let buttonPadding: EdgeInsets
        let cardPadding: EdgeInsets
        let containerPadding: EdgeInsets
        let sectionSpacing: CGFloat
        let itemSpacing: CGFloat
        let controlSpacing: CGFloat
        
        static let compact = ComponentSpacing(
            buttonPadding: EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12),
            cardPadding: EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12),
            containerPadding: EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16),
            sectionSpacing: 16,
            itemSpacing: 8,
            controlSpacing: 12
        )
        
        static let standard = ComponentSpacing(
            buttonPadding: EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16),
            cardPadding: EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16),
            containerPadding: EdgeInsets(top: 24, leading: 24, bottom: 24, trailing: 24),
            sectionSpacing: 24,
            itemSpacing: 12,
            controlSpacing: 16
        )
        
        static let spacious = ComponentSpacing(
            buttonPadding: EdgeInsets(top: 12, leading: 24, bottom: 12, trailing: 24),
            cardPadding: EdgeInsets(top: 24, leading: 24, bottom: 24, trailing: 24),
            containerPadding: EdgeInsets(top: 32, leading: 32, bottom: 32, trailing: 32),
            sectionSpacing: 32,
            itemSpacing: 16,
            controlSpacing: 24
        )
    }
    
    // MARK: - Layout Spacing
    
    struct LayoutSpacing {
        let screenPadding: EdgeInsets
        let contentPadding: EdgeInsets
        let safeAreaMargin: CGFloat
        let statusBarHeight: CGFloat
        let tabBarHeight: CGFloat
        let navigationBarHeight: CGFloat
        
        static let standard = LayoutSpacing(
            screenPadding: EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16),
            contentPadding: EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16),
            safeAreaMargin: 8,
            statusBarHeight: 44,
            tabBarHeight: 83,
            navigationBarHeight: 44
        )
    }
    
    // MARK: - Camera UI Spacing
    
    struct CameraSpacing {
        let controlButtonSize: CGFloat
        let controlButtonSpacing: CGFloat
        let controlPanelPadding: EdgeInsets
        let previewPadding: EdgeInsets
        let settingsItemHeight: CGFloat
        let settingsItemSpacing: CGFloat
        
        static let standard = CameraSpacing(
            controlButtonSize: 44,
            controlButtonSpacing: 16,
            controlPanelPadding: EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16),
            previewPadding: EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8),
            settingsItemHeight: 44,
            settingsItemSpacing: 8
        )
    }
}

// MARK: - Spacing Extensions

extension CGFloat {
    
    // MARK: - Spacing Scale Access
    
    static var spacingXS: CGFloat { DesignSpacing.SpacingScale.standard.xs }
    static var spacingSM: CGFloat { DesignSpacing.SpacingScale.standard.sm }
    static var spacingMD: CGFloat { DesignSpacing.SpacingScale.standard.md }
    static var spacingLG: CGFloat { DesignSpacing.SpacingScale.standard.lg }
    static var spacingXL: CGFloat { DesignSpacing.SpacingScale.standard.xl }
    static var spacingXL2: CGFloat { DesignSpacing.SpacingScale.standard.xl2 }
    static var spacingXL3: CGFloat { DesignSpacing.SpacingScale.standard.xl3 }
    static var spacingXL4: CGFloat { DesignSpacing.SpacingScale.standard.xl4 }
    static var spacingXL5: CGFloat { DesignSpacing.SpacingScale.standard.xl5 }
    static var spacingXL6: CGFloat { DesignSpacing.SpacingScale.standard.xl6 }
    
    // MARK: - Spacing Utilities
    
    func scaled(_ factor: CGFloat) -> CGFloat {
        return self * factor
    }
    
    func halved() -> CGFloat {
        return self / 2
    }
    
    func doubled() -> CGFloat {
        return self * 2
    }
}

// MARK: - EdgeInsets Extensions

extension EdgeInsets {
    
    // MARK: - Convenience Initializers
    
    init(all: CGFloat) {
        self.init(top: all, leading: all, bottom: all, trailing: all)
    }
    
    init(horizontal: CGFloat, vertical: CGFloat) {
        self.init(top: vertical, leading: horizontal, bottom: vertical, trailing: horizontal)
    }
    
    init(top: CGFloat = 0, horizontal: CGFloat = 0, bottom: CGFloat = 0) {
        self.init(top: top, leading: horizontal, bottom: bottom, trailing: horizontal)
    }
    
    // MARK: - Spacing Operations
    
    func adding(_ other: EdgeInsets) -> EdgeInsets {
        return EdgeInsets(
            top: self.top + other.top,
            leading: self.leading + other.leading,
            bottom: self.bottom + other.bottom,
            trailing: self.trailing + other.trailing
        )
    }
    
    func subtracting(_ other: EdgeInsets) -> EdgeInsets {
        return EdgeInsets(
            top: max(0, self.top - other.top),
            leading: max(0, self.leading - other.leading),
            bottom: max(0, self.bottom - other.bottom),
            trailing: max(0, self.trailing - other.trailing)
        )
    }
    
    func scaled(_ factor: CGFloat) -> EdgeInsets {
        return EdgeInsets(
            top: self.top * factor,
            leading: self.leading * factor,
            bottom: self.bottom * factor,
            trailing: self.trailing * factor
        )
    }
    
    // MARK: - Common Spacing Patterns
    
    static let none = EdgeInsets(all: 0)
    static let xs = EdgeInsets(all: .spacingXS)
    static let sm = EdgeInsets(all: .spacingSM)
    static let md = EdgeInsets(all: .spacingMD)
    static let lg = EdgeInsets(all: .spacingLG)
    static let xl = EdgeInsets(all: .spacingXL)
    
    static let horizontalXS = EdgeInsets(horizontal: .spacingXS)
    static let horizontalSM = EdgeInsets(horizontal: .spacingSM)
    static let horizontalMD = EdgeInsets(horizontal: .spacingMD)
    static let horizontalLG = EdgeInsets(horizontal: .spacingLG)
    static let horizontalXL = EdgeInsets(horizontal: .spacingXL)
    
    static let verticalXS = EdgeInsets(vertical: .spacingXS)
    static let verticalSM = EdgeInsets(vertical: .spacingSM)
    static let verticalMD = EdgeInsets(vertical: .spacingMD)
    static let verticalLG = EdgeInsets(vertical: .spacingLG)
    static let verticalXL = EdgeInsets(vertical: .spacingXL)
}

// MARK: - View Modifiers

extension View {
    
    // MARK: - Spacing Modifiers
    
    func spacing(_ spacing: CGFloat) -> some View {
        self.padding(spacing)
    }
    
    func spacing(_ edges: Edge.Set, _ spacing: CGFloat) -> some View {
        self.padding(edges, spacing)
    }
    
    func spacing(_ insets: EdgeInsets) -> some View {
        self.padding(insets)
    }
    
    func spacingX(_ spacing: CGFloat) -> some View {
        self.padding(.horizontal, spacing)
    }
    
    func spacingY(_ spacing: CGFloat) -> some View {
        self.padding(.vertical, spacing)
    }
    
    func spacingTop(_ spacing: CGFloat) -> some View {
        self.padding(.top, spacing)
    }
    
    func spacingBottom(_ spacing: CGFloat) -> some View {
        self.padding(.bottom, spacing)
    }
    
    func spacingLeading(_ spacing: CGFloat) -> some View {
        self.padding(.leading, spacing)
    }
    
    func spacingTrailing(_ spacing: CGFloat) -> some View {
        self.padding(.trailing, spacing)
    }
    
    // MARK: - Layout Spacing
    
    func spacingBetween(_ spacing: CGFloat) -> some View {
        self.spacing(spacing)
    }
    
    func spacingBetweenComponents() -> some View {
        self.spacing(DesignSpacing.ComponentSpacing.standard.itemSpacing)
    }
    
    func spacingBetweenSections() -> some View {
        self.spacing(DesignSpacing.ComponentSpacing.standard.sectionSpacing)
    }
    
    func spacingForControls() -> some View {
        self.spacing(DesignSpacing.ComponentSpacing.standard.controlSpacing)
    }
    
    // MARK: - Component Spacing
    
    func buttonSpacing() -> some View {
        self.padding(DesignSpacing.ComponentSpacing.standard.buttonPadding)
    }
    
    func cardSpacing() -> some View {
        self.padding(DesignSpacing.ComponentSpacing.standard.cardPadding)
    }
    
    func containerSpacing() -> some View {
        self.padding(DesignSpacing.ComponentSpacing.standard.containerPadding)
    }
    
    func contentSpacing() -> some View {
        self.padding(DesignSpacing.LayoutSpacing.standard.contentPadding)
    }
    
    func screenSpacing() -> some View {
        self.padding(DesignSpacing.LayoutSpacing.standard.screenPadding)
    }
    
    // MARK: - Camera UI Spacing
    
    func cameraControlSpacing() -> some View {
        self.padding(DesignSpacing.CameraSpacing.standard.controlPanelPadding)
    }
    
    func cameraPreviewSpacing() -> some View {
        self.padding(DesignSpacing.CameraSpacing.standard.previewPadding)
    }
    
    // MARK: - Responsive Spacing
    
    func responsiveSpacing(_ compact: CGFloat, standard: CGFloat, spacious: CGFloat) -> some View {
        let spacing: CGFloat
        switch UIScreen.main.bounds.width {
        case 0..<375:
            spacing = compact
        case 375..<414:
            spacing = standard
        default:
            spacing = spacious
        }
        return self.padding(spacing)
    }
    
    func adaptiveSpacing() -> some View {
        self.responsiveSpacing(
            compact: DesignSpacing.SpacingScale.compact.md,
            standard: DesignSpacing.SpacingScale.standard.md,
            spacious: DesignSpacing.SpacingScale.spacious.md
        )
    }
}

// MARK: - Stack Spacing

extension VStack {
    init(spacing: DesignSpacing.ComponentSpacing, @ViewBuilder content: () -> Content) {
        self.init(spacing: spacing.itemSpacing, content: content)
    }
    
    init(sectionSpacing: DesignSpacing.ComponentSpacing, @ViewBuilder content: () -> Content) {
        self.init(spacing: spacing.sectionSpacing, content: content)
    }
    
    init(controlSpacing: DesignSpacing.ComponentSpacing, @ViewBuilder content: () -> Content) {
        self.init(spacing: spacing.controlSpacing, content: content)
    }
}

extension HStack {
    init(spacing: DesignSpacing.ComponentSpacing, @ViewBuilder content: () -> Content) {
        self.init(spacing: spacing.itemSpacing, content: content)
    }
    
    init(sectionSpacing: DesignSpacing.ComponentSpacing, @ViewBuilder content: () -> Content) {
        self.init(spacing: spacing.sectionSpacing, content: content)
    }
    
    init(controlSpacing: DesignSpacing.ComponentSpacing, @ViewBuilder content: () -> Content) {
        self.init(spacing: spacing.controlSpacing, content: content)
    }
}

// MARK: - Grid Spacing

struct GridSpacing {
    let columns: Int
    let spacing: CGFloat
    let padding: EdgeInsets
    
    static let standard = GridSpacing(
        columns: 2,
        spacing: .spacingMD,
        padding: .horizontalMD
    )
    
    static let compact = GridSpacing(
        columns: 3,
        spacing: .spacingSM,
        padding: .horizontalSM
    )
    
    static let spacious = GridSpacing(
        columns: 2,
        spacing: .spacingLG,
        padding: .horizontalLG
    )
}

// MARK: - Layout Helpers

struct LayoutHelper {
    
    // MARK: - Responsive Layout
    
    static func columnsForWidth(_ width: CGFloat) -> Int {
        switch width {
        case 0..<375:
            return 1
        case 375..<414:
            return 2
        case 414..<768:
            return 2
        default:
            return 3
        }
    }
    
    static func spacingForWidth(_ width: CGFloat) -> CGFloat {
        switch width {
        case 0..<375:
            return DesignSpacing.SpacingScale.compact.md
        case 375..<414:
            return DesignSpacing.SpacingScale.standard.md
        default:
            return DesignSpacing.SpacingScale.spacious.md
        }
    }
    
    static func paddingForWidth(_ width: CGFloat) -> EdgeInsets {
        let spacing = spacingForWidth(width)
        return EdgeInsets(horizontal: spacing, vertical: spacing)
    }
    
    // MARK: - Safe Area Helpers
    
    static func safeAreaInsets() -> EdgeInsets {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            return EdgeInsets()
        }
        
        let safeArea = window.safeAreaInsets
        return EdgeInsets(
            top: safeArea.top,
            leading: safeArea.left,
            bottom: safeArea.bottom,
            trailing: safeArea.right
        )
    }
    
    static func screenBounds() -> CGRect {
        return UIScreen.main.bounds
    }
    
    static func safeAreaBounds() -> CGRect {
        let bounds = screenBounds()
        let insets = safeAreaInsets()
        
        return CGRect(
            x: bounds.minX + insets.leading,
            y: bounds.minY + insets.top,
            width: bounds.width - insets.leading - insets.trailing,
            height: bounds.height - insets.top - insets.bottom
        )
    }
}

// MARK: - Spacing Presets

struct SpacingPresets {
    
    // MARK: - Glass Component Spacing
    
    struct Glass {
        static let buttonPadding = EdgeInsets(horizontal: 16, vertical: 8)
        static let cardPadding = EdgeInsets(all: 16)
        static let containerPadding = EdgeInsets(all: 24)
        static let controlPadding = EdgeInsets(horizontal: 12, vertical: 8)
        static let iconPadding = EdgeInsets(all: 8)
        static let textPadding = EdgeInsets(horizontal: 12, vertical: 6)
    }
    
    // MARK: - Camera UI Spacing
    
    struct Camera {
        static let controlButtonSpacing: CGFloat = 16
        static let controlPanelPadding = EdgeInsets(horizontal: 16, vertical: 12)
        static let previewPadding = EdgeInsets(all: 8)
        static let settingsItemHeight: CGFloat = 44
        static let settingsItemSpacing: CGFloat = 8
        static let toolbarHeight: CGFloat = 60
        static let toolbarPadding = EdgeInsets(horizontal: 16, vertical: 8)
    }
    
    // MARK: - Form Spacing
    
    struct Form {
        static let fieldSpacing: CGFloat = 16
        static let sectionSpacing: CGFloat = 24
        static let fieldPadding = EdgeInsets(horizontal: 16, vertical: 12)
        static let labelSpacing: CGFloat = 4
        static let buttonSpacing: CGFloat = 12
    }
    
    // MARK: - List Spacing
    
    struct List {
        static let itemSpacing: CGFloat = 0
        static let itemPadding = EdgeInsets(horizontal: 16, vertical: 12)
        static let sectionSpacing: CGFloat = 24
        static let sectionPadding = EdgeInsets(horizontal: 16, vertical: 8)
        static let groupSpacing: CGFloat = 16
    }
}

// MARK: - Responsive Spacing

struct ResponsiveSpacing {
    
    static func spacingForSizeCategory(_ category: UIContentSizeCategory) -> CGFloat {
        switch category {
        case .extraSmall, .small:
            return DesignSpacing.SpacingScale.compact.md
        case .medium, .large:
            return DesignSpacing.SpacingScale.standard.md
        case .extraLarge, .extraExtraLarge, .extraExtraExtraLarge:
            return DesignSpacing.SpacingScale.spacious.md
        default:
            return DesignSpacing.SpacingScale.standard.md
        }
    }
    
    static func paddingForSizeCategory(_ category: UIContentSizeCategory) -> EdgeInsets {
        let spacing = spacingForSizeCategory(category)
        return EdgeInsets(horizontal: spacing, vertical: spacing)
    }
    
    static func isCompactSize() -> Bool {
        let sizeCategory = UIApplication.shared.preferredContentSizeCategory
        return sizeCategory == .extraSmall || sizeCategory == .small
    }
    
    static func isSpaciousSize() -> Bool {
        let sizeCategory = UIApplication.shared.preferredContentSizeCategory
        return sizeCategory == .extraLarge || 
               sizeCategory == .extraExtraLarge || 
               sizeCategory == .extraExtraExtraLarge
    }
}