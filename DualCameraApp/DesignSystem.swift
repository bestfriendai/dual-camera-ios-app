//
//  DesignSystem.swift
//  DualCameraApp
//
//  Simplified design system for UI consistency
//

import UIKit

class DesignSystem {
    // Colors
    static let primaryColor = UIColor.systemBlue
    static let secondaryColor = UIColor.systemGray
    static let backgroundColor = UIColor.black
    static let textColor = UIColor.white
    
    // Spacing enum
    enum Spacing: CGFloat {
        case xs = 4
        case sm = 8
        case md = 16
        case lg = 24
        case xl = 32
        
        var value: CGFloat { return rawValue }
    }
    
    // Corner radius
    static let cornerRadius: CGFloat = 12
    
    // Typography
    static let titleFont = UIFont.systemFont(ofSize: 20, weight: .bold)
    static let bodyFont = UIFont.systemFont(ofSize: 16, weight: .regular)
    static let captionFont = UIFont.systemFont(ofSize: 12, weight: .regular)
    
    // Button styles
    static func setupButton(_ button: UIButton) {
        button.backgroundColor = primaryColor
        button.layer.cornerRadius = cornerRadius
        button.tintColor = .white
    }
    
    // Semantic colors
    struct SemanticColors {
        static let adaptiveBackground = UIColor { traitCollection in
            return traitCollection.userInterfaceStyle == .dark ? UIColor.black : UIColor.white
        }
        
        static let adaptiveText = UIColor { traitCollection in
            return traitCollection.userInterfaceStyle == .dark ? UIColor.white : UIColor.black
        }
    }
    
    // Layout
    struct Layout {
        static let standardPadding: CGFloat = 16
        static let buttonHeight: CGFloat = 44
    }
}

extension UIView {
    func addHapticFeedback() {}
}
