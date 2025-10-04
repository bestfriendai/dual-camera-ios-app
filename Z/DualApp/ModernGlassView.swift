//
//  ModernGlassView.swift
//  DualCameraApp
//
//  iOS 26 Liquid Glass implementation with automatic accessibility adaptation
//

import SwiftUI

@available(iOS 26.0, *)
struct ModernGlassView<Content: View>: View {
    @Environment(\.accessibilityReduceTransparency) var reduceTransparency
    
    let content: Content
    let tintColor: Color
    let intensity: Double
    let cornerRadius: CGFloat
    
    init(
        tintColor: Color = .white,
        intensity: Double = 0.8,
        cornerRadius: CGFloat = 24,
        @ViewBuilder content: () -> Content
    ) {
        self.tintColor = tintColor
        self.intensity = intensity
        self.cornerRadius = cornerRadius
        self.content = content()
    }
    
    var body: some View {
        content
            .background(.liquidGlass.tint(tintColor))
            .glassIntensity(reduceTransparency ? 0.0 : intensity)
            .glassBorder(.adaptive)
            .cornerRadius(cornerRadius, style: .continuous)
            .shadow(color: .black.opacity(0.2), radius: 16, x: 0, y: 8)
    }
}

@available(iOS 16.0, *)
struct ModernGlassViewFallback<Content: View>: View {
    @Environment(\.accessibilityReduceTransparency) var reduceTransparency
    
    let content: Content
    let tintColor: Color
    let intensity: Double
    let cornerRadius: CGFloat
    
    init(
        tintColor: Color = .white,
        intensity: Double = 0.8,
        cornerRadius: CGFloat = 24,
        @ViewBuilder content: () -> Content
    ) {
        self.tintColor = tintColor
        self.intensity = intensity
        self.cornerRadius = cornerRadius
        self.content = content()
    }
    
    var body: some View {
        content
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(
                            reduceTransparency 
                            ? Color(white: 0.2)
                            : LinearGradient(
                                colors: [
                                    tintColor.opacity(0.25 * intensity),
                                    tintColor.opacity(0.1 * intensity)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    if !reduceTransparency {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(.ultraThinMaterial)
                    }
                    
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(
                            tintColor.opacity(reduceTransparency ? 0.6 : 0.3),
                            lineWidth: reduceTransparency ? 2 : 1
                        )
                }
            )
            .shadow(color: .black.opacity(reduceTransparency ? 0.4 : 0.2), radius: 16, x: 0, y: 8)
    }
}
