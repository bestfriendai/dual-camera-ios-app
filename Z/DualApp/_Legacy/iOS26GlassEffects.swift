//
//  iOS26GlassEffects.swift
//  DualCameraApp
//
//  iOS 26 Liquid Glass effect system with accessibility support
//

import SwiftUI
import UIKit
import Metal

@available(iOS 15.0, *)
extension View {
    @ViewBuilder
    func modernGlassEffect(tint: Color = .white, isInteractive: Bool = false) -> some View {
        if #available(iOS 18.0, *) {
            self
                .background(.ultraThinMaterial)
                .overlay {
                    LinearGradient(
                        colors: [
                            tint.opacity(0.3),
                            tint.opacity(0.15),
                            tint.opacity(0.05)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.3), lineWidth: 0.5)
                }
                .shadow(color: .black.opacity(0.2), radius: 12, x: 0, y: 4)
                .scaleEffect(isInteractive ? 1.02 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isInteractive)
        } else {
            self
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
    }
    
    func metalGlassEffect(tint: Color = .white, cornerRadius: CGFloat = 24) -> some View {
        if MTLCreateSystemDefaultDevice() != nil {
            return AnyView(MetalGlassContainer(content: self, tint: tint, cornerRadius: cornerRadius))
        } else {
            return AnyView(self.modernGlassEffect(tint: tint))
        }
    }
    
    func adaptiveGlassEffect(for colorScheme: ColorScheme, accessibilityEnabled: Bool = false) -> some View {
        Group {
            if accessibilityEnabled {
                self
                    .background(colorScheme == .dark ? Color.black.opacity(0.8) : Color.white.opacity(0.9))
                    .overlay {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .strokeBorder(Color.primary, lineWidth: 2)
                    }
            } else {
                self.modernGlassEffect()
            }
        }
    }
}

@available(iOS 15.0, *)
struct GlassButton: View {
    let title: String?
    let systemImage: String?
    let action: () -> Void
    let tint: Color
    let isProminent: Bool
    
    @Environment(\.colorScheme) var colorScheme
    @AccessibilityFocusState private var isFocused: Bool
    @State private var isPressed = false
    
    init(
        title: String? = nil,
        systemImage: String? = nil,
        tint: Color = .white,
        isProminent: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.tint = tint
        self.isProminent = isProminent
        self.action = action
    }
    
    var body: some View {
        Button(action: {
            HapticFeedbackManager.shared.lightImpact()
            action()
        }) {
            HStack(spacing: 8) {
                if let systemImage = systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 16, weight: .semibold))
                }
                if let title = title {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                }
            }
            .foregroundColor(isProminent ? .black : .white)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(minWidth: 44, minHeight: 44)
        }
        .buttonStyle(GlassButtonStyle(tint: tint, isProminent: isProminent))
        .accessibilityFocused($isFocused)
    }
}

@available(iOS 15.0, *)
struct GlassButtonStyle: ButtonStyle {
    let tint: Color
    let isProminent: Bool
    
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.accessibilityReduceTransparency) var reduceTransparency
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background {
                if reduceTransparency {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(colorScheme == .dark ? Color.black.opacity(0.8) : Color.white.opacity(0.9))
                        .overlay {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(tint, lineWidth: 2)
                        }
                } else if isProminent {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(tint.opacity(0.9))
                        .overlay(.ultraThinMaterial)
                        .shadow(color: tint.opacity(0.5), radius: 12, x: 0, y: 4)
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(.ultraThinMaterial)
                        
                        LinearGradient(
                            colors: [
                                tint.opacity(0.4),
                                tint.opacity(0.2),
                                tint.opacity(0.1)
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
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.94 : 1.0)
            .animation(
                reduceMotion ? .none : .spring(response: 0.3, dampingFraction: 0.6),
                value: configuration.isPressed
            )
    }
}

@available(iOS 15.0, *)
struct GlassEffectContainer<Content: View>: View {
    let content: Content
    let tint: Color
    
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.accessibilityReduceTransparency) var reduceTransparency
    
    init(tint: Color = .white, @ViewBuilder content: () -> Content) {
        self.tint = tint
        self.content = content()
    }
    
    var body: some View {
        HStack(spacing: 12) {
            content
        }
        .padding(12)
        .background {
            if reduceTransparency {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(colorScheme == .dark ? Color.black.opacity(0.8) : Color.white.opacity(0.9))
                    .overlay {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .strokeBorder(Color.primary, lineWidth: 2)
                    }
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
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
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.3), lineWidth: 0.5)
                }
                .shadow(color: .black.opacity(0.2), radius: 16, x: 0, y: 8)
            }
        }
    }
}

@available(iOS 15.0, *)
struct MetalGlassContainer<Content: View>: UIViewRepresentable {
    let content: Content
    let tint: Color
    let cornerRadius: CGFloat
    
    init(content: Content, tint: Color, cornerRadius: CGFloat) {
        self.content = content
        self.tint = tint
        self.cornerRadius = cornerRadius
    }
    
    func makeUIView(context: Context) -> LiquidGlassView {
        let glassView = LiquidGlassView()
        glassView.tintColor = UIColor(tint)
        glassView.layer.cornerRadius = cornerRadius
        glassView.layer.masksToBounds = true
        
        let hostingController = UIHostingController(rootView: content)
        hostingController.view.backgroundColor = .clear
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        glassView.addSubview(hostingController.view)
        
        NSLayoutConstraint.activate([
            hostingController.view.topAnchor.constraint(equalTo: glassView.topAnchor),
            hostingController.view.leadingAnchor.constraint(equalTo: glassView.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: glassView.trailingAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: glassView.bottomAnchor)
        ])
        
        return glassView
    }
    
    func updateUIView(_ uiView: LiquidGlassView, context: Context) {
        uiView.tintColor = UIColor(tint)
        uiView.layer.cornerRadius = cornerRadius
    }
}

struct GlassRecordButton: View {
    let isRecording: Bool
    let action: () -> Void
    
    @Environment(\.accessibilityReduceTransparency) var reduceTransparency
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @State private var isPulsing = false
    
    var body: some View {
        Button(action: {
            HapticFeedbackManager.shared.mediumImpact()
            action()
        }) {
            ZStack {
                Circle()
                    .fill(isRecording ? Color.red : Color.white)
                    .frame(width: 70, height: 70)
                
                if isRecording {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.white)
                        .frame(width: 30, height: 30)
                } else {
                    Circle()
                        .strokeBorder(Color.red, lineWidth: 4)
                        .frame(width: 60, height: 60)
                }
            }
        }
        .buttonStyle(RecordButtonStyle(isRecording: isRecording))
        .accessibilityLabel(isRecording ? "Stop Recording" : "Start Recording")
        .accessibilityHint(isRecording ? "Double tap to stop recording" : "Double tap to start recording")
    }
}

struct RecordButtonStyle: ButtonStyle {
    let isRecording: Bool
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.9 : 1.0)
            .shadow(
                color: isRecording ? Color.red.opacity(0.5) : Color.clear,
                radius: isRecording ? 20 : 0,
                x: 0,
                y: 0
            )
            .animation(
                reduceMotion ? .none : .spring(response: 0.3, dampingFraction: 0.6),
                value: configuration.isPressed
            )
    }
}

class GlassEffectHostingController<Content: View>: UIHostingController<Content> {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
    }
}
