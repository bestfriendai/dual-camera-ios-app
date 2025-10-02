//
//  iOS18LiquidGlassView.swift
//  DualCameraApp
//
//  iOS 18+ Liquid Glass with Dynamic Materials and Adaptive Blur
//

import UIKit
import SwiftUI

/// iOS 18+ Liquid Glass view with dynamic materials and adaptive blur
@available(iOS 15.0, *)
class iOS18LiquidGlassView: UIView {
    
    // MARK: - Properties
    
    private let backgroundView = UIView()
    private let gradientLayer = CAGradientLayer()
    private let noiseLayer = CALayer()
    private let materialView = UIVisualEffectView()
    private let vibrancyView = UIVisualEffectView()
    private let borderLayer = CAShapeLayer()
    
    // Dynamic properties
    private var materialStyle: MaterialStyle = .systemThinMaterial
    private var vibrancyStyle: VibrancyStyle = .primary
    private var adaptiveMode: AdaptiveMode = .automatic
    private var liquidColor: UIColor = .white
    private var intensity: Float = 1.0
    
    // Public content view
    let contentView = UIView()
    
    // MARK: - Material Styles
    
    enum MaterialStyle: CaseIterable {
        case systemUltraThinMaterial
        case systemThinMaterial
        case systemMaterial
        case systemThickMaterial
        case systemChromeMaterial
        
        @available(iOS 15.0, *)
        var blurEffectStyle: UIBlurEffect.Style {
            switch self {
            case .systemUltraThinMaterial:
                return .systemUltraThinMaterial
            case .systemThinMaterial:
                return .systemThinMaterial
            case .systemMaterial:
                return .systemMaterial
            case .systemThickMaterial:
                return .systemThickMaterial
            case .systemChromeMaterial:
                return .systemChromeMaterial
            }
        }
        
        var vibrancyStyle: UIVibrancyEffectStyle {
            switch self {
            case .systemUltraThinMaterial, .systemThinMaterial:
                return .label
            case .systemMaterial:
                return .secondaryLabel
            case .systemThickMaterial, .systemChromeMaterial:
                return .tertiaryLabel
            }
        }
    }
    
    enum VibrancyStyle: CaseIterable {
        case primary
        case secondary
        case tertiary
        case quaternary
        
        var effectStyle: UIVibrancyEffectStyle {
            switch self {
            case .primary:
                return .label
            case .secondary:
                return .secondaryLabel
            case .tertiary:
                return .tertiaryLabel
            case .quaternary:
                return .quaternaryLabel
            }
        }
    }
    
    enum AdaptiveMode {
        case automatic
        case light
        case dark
        case highContrast
        case reducedTransparency
    }
    
    // MARK: - Initialization
    
    init(
        material: MaterialStyle = .systemThinMaterial,
        vibrancy: VibrancyStyle = .primary,
        adaptiveMode: AdaptiveMode = .automatic,
        liquidColor: UIColor = .white,
        intensity: Float = 1.0
    ) {
        self.materialStyle = material
        self.vibrancyStyle = vibrancy
        self.adaptiveMode = adaptiveMode
        self.liquidColor = liquidColor
        self.intensity = intensity
        
        super.init(frame: .zero)
        setupLiquidGlass()
        setupGestureRecognizers()
        updateForCurrentEnvironment()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Setup
    
    private func setupLiquidGlass() {
        backgroundColor = .clear
        
        // Setup background view
        backgroundView.backgroundColor = .clear
        backgroundView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(backgroundView)
        
        // Setup gradient layer (behind everything)
        setupGradientLayer()
        
        // Setup noise layer for texture
        setupNoiseLayer()
        
        // Setup material view
        setupMaterialView()
        
        // Setup vibrancy view
        setupVibrancyView()
        
        // Setup border
        setupBorderLayer()
        
        // Setup content view
        setupContentView()
        
        // Apply constraints
        setupConstraints()
        
        // Apply initial styling
        updateAppearance()
    }
    
    private func setupGradientLayer() {
        gradientLayer.colors = [
            liquidColor.withAlphaComponent(0.6 * CGFloat(intensity)).cgColor,
            liquidColor.withAlphaComponent(0.3 * CGFloat(intensity)).cgColor,
            liquidColor.withAlphaComponent(0.1 * CGFloat(intensity)).cgColor,
            UIColor.clear.cgColor
        ]
        gradientLayer.locations = [0.0, 0.4, 0.7, 1.0]
        gradientLayer.startPoint = CGPoint(x: 0, y: 0)
        gradientLayer.endPoint = CGPoint(x: 1, y: 1)
        gradientLayer.cornerRadius = 24
        gradientLayer.cornerCurve = .continuous
        backgroundView.layer.insertSublayer(gradientLayer, at: 0)
    }
    
    private func setupNoiseLayer() {
        noiseLayer.contents = createNoiseImage().cgImage
        noiseLayer.opacity = 0.02 * intensity
        noiseLayer.compositingFilter = "overlayBlendMode"
        noiseLayer.cornerRadius = 24
        noiseLayer.cornerCurve = .continuous
        backgroundView.layer.insertSublayer(noiseLayer, at: 1)
    }
    
    private func setupMaterialView() {
        let blurEffect = UIBlurEffect(style: materialStyle.blurEffectStyle)
        materialView.effect = blurEffect
        materialView.layer.cornerRadius = 24
        materialView.layer.cornerCurve = .continuous
        materialView.clipsToBounds = true
        materialView.translatesAutoresizingMaskIntoConstraints = false
        backgroundView.addSubview(materialView)
    }
    
    private func setupVibrancyView() {
        let vibrancyEffect = UIVibrancyEffect(
            blurEffect: materialView.effect as! UIBlurEffect,
            style: vibrancyStyle.effectStyle
        )
        vibrancyView.effect = vibrancyEffect
        vibrancyView.translatesAutoresizingMaskIntoConstraints = false
        materialView.contentView.addSubview(vibrancyView)
    }
    
    private func setupBorderLayer() {
        borderLayer.fillColor = UIColor.clear.cgColor
        borderLayer.strokeColor = UIColor.white.withAlphaComponent(0.2 * intensity).cgColor
        borderLayer.lineWidth = 1
        borderLayer.lineDashPattern = [6, 3]
        borderLayer.lineCap = .round
        borderLayer.opacity = 0.8
        layer.addSublayer(borderLayer)
    }
    
    private func setupContentView() {
        contentView.backgroundColor = .clear
        contentView.translatesAutoresizingMaskIntoConstraints = false
        vibrancyView.contentView.addSubview(contentView)
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            backgroundView.topAnchor.constraint(equalTo: topAnchor),
            backgroundView.leadingAnchor.constraint(equalTo: leadingAnchor),
            backgroundView.trailingAnchor.constraint(equalTo: trailingAnchor),
            backgroundView.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            materialView.topAnchor.constraint(equalTo: backgroundView.topAnchor),
            materialView.leadingAnchor.constraint(equalTo: backgroundView.leadingAnchor),
            materialView.trailingAnchor.constraint(equalTo: backgroundView.trailingAnchor),
            materialView.bottomAnchor.constraint(equalTo: backgroundView.bottomAnchor),
            
            vibrancyView.topAnchor.constraint(equalTo: materialView.contentView.topAnchor),
            vibrancyView.leadingAnchor.constraint(equalTo: materialView.contentView.leadingAnchor),
            vibrancyView.trailingAnchor.constraint(equalTo: materialView.contentView.trailingAnchor),
            vibrancyView.bottomAnchor.constraint(equalTo: materialView.contentView.bottomAnchor),
            
            contentView.topAnchor.constraint(equalTo: vibrancyView.contentView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: vibrancyView.contentView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: vibrancyView.contentView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: vibrancyView.contentView.bottomAnchor)
        ])
    }
    
    private func setupGestureRecognizers() {
        let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        longPressGesture.minimumPressDuration = 0.1
        addGestureRecognizer(longPressGesture)
        
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        addGestureRecognizer(panGesture)
    }
    
    // MARK: - Dynamic Updates
    
    private func updateForCurrentEnvironment() {
        switch adaptiveMode {
        case .automatic:
            updateForAutomaticMode()
        case .light:
            updateForLightMode()
        case .dark:
            updateForDarkMode()
        case .highContrast:
            updateForHighContrastMode()
        case .reducedTransparency:
            updateForReducedTransparencyMode()
        }
    }
    
    private func updateForAutomaticMode() {
        let newMaterial: MaterialStyle
        
        if traitCollection.userInterfaceStyle == .dark {
            newMaterial = .systemThickMaterial
        } else {
            newMaterial = .systemThinMaterial
        }
        
        if traitCollection.accessibilityContrast == .high {
            updateMaterialStyle(.systemMaterial, animated: false)
        } else {
            updateMaterialStyle(newMaterial, animated: false)
        }
    }
    
    private func updateForLightMode() {
        updateMaterialStyle(.systemThinMaterial, animated: false)
    }
    
    private func updateForDarkMode() {
        updateMaterialStyle(.systemThickMaterial, animated: false)
    }
    
    private func updateForHighContrastMode() {
        updateMaterialStyle(.systemMaterial, animated: false)
        borderLayer.strokeColor = UIColor.white.withAlphaComponent(0.5).cgColor
        borderLayer.lineWidth = 2
    }
    
    private func updateForReducedTransparencyMode() {
        materialView.effect = nil
        vibrancyView.effect = nil
        gradientLayer.opacity = 0.3
        noiseLayer.opacity = 0
    }
    
    private func updateAppearance() {
        layer.cornerRadius = 24
        layer.cornerCurve = .continuous
        
        // Subtle shadow for depth
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.1 * intensity
        layer.shadowOffset = CGSize(width: 0, height: 4)
        layer.shadowRadius = 12
        layer.masksToBounds = false
    }
    
    // MARK: - Public Methods
    
    /// Updates the material style with animation
    func updateMaterialStyle(_ style: MaterialStyle, animated: Bool = true) {
        materialStyle = style
        
        let updateBlock = {
            let blurEffect = UIBlurEffect(style: style.blurEffectStyle)
            self.materialView.effect = blurEffect
            
            let vibrancyEffect = UIVibrancyEffect(
                blurEffect: blurEffect,
                style: self.vibrancyStyle.effectStyle
            )
            self.vibrancyView.effect = vibrancyEffect
        }
        
        if animated {
            UIView.animate(withDuration: 0.3, animations: updateBlock)
        } else {
            updateBlock()
        }
    }
    
    /// Updates the vibrancy style with animation
    func updateVibrancyStyle(_ style: VibrancyStyle, animated: Bool = true) {
        vibrancyStyle = style
        
        guard let blurEffect = materialView.effect as? UIBlurEffect else { return }
        
        let updateBlock = {
            let vibrancyEffect = UIVibrancyEffect(
                blurEffect: blurEffect,
                style: style.effectStyle
            )
            self.vibrancyView.effect = vibrancyEffect
        }
        
        if animated {
            UIView.animate(withDuration: 0.3, animations: updateBlock)
        } else {
            updateBlock()
        }
    }
    
    /// Updates the liquid color with animation
    func updateLiquidColor(_ color: UIColor, animated: Bool = true) {
        liquidColor = color
        
        let updateBlock = {
            self.gradientLayer.colors = [
                color.withAlphaComponent(0.6 * CGFloat(self.intensity)).cgColor,
                color.withAlphaComponent(0.3 * CGFloat(self.intensity)).cgColor,
                color.withAlphaComponent(0.1 * CGFloat(self.intensity)).cgColor,
                UIColor.clear.cgColor
            ]
        }
        
        if animated {
            let animation = CABasicAnimation(keyPath: "colors")
            animation.duration = 0.3
            animation.fromValue = gradientLayer.colors
            animation.toValue = [
                color.withAlphaComponent(0.6 * CGFloat(intensity)).cgColor,
                color.withAlphaComponent(0.3 * CGFloat(intensity)).cgColor,
                color.withAlphaComponent(0.1 * CGFloat(intensity)).cgColor,
                UIColor.clear.cgColor
            ]
            animation.fillMode = .forwards
            animation.isRemovedOnCompletion = false
            gradientLayer.add(animation, forKey: "colorChange")
        } else {
            updateBlock()
        }
    }
    
    /// Updates the intensity of the liquid glass effect
    func updateIntensity(_ intensity: Float, animated: Bool = true) {
        self.intensity = intensity
        
        let updateBlock = {
            self.gradientLayer.colors = [
                self.liquidColor.withAlphaComponent(0.6 * CGFloat(intensity)).cgColor,
                self.liquidColor.withAlphaComponent(0.3 * CGFloat(intensity)).cgColor,
                self.liquidColor.withAlphaComponent(0.1 * CGFloat(intensity)).cgColor,
                UIColor.clear.cgColor
            ]
            self.noiseLayer.opacity = 0.02 * intensity
            self.borderLayer.strokeColor = UIColor.white.withAlphaComponent(0.2 * intensity).cgColor
            self.layer.shadowOpacity = 0.1 * intensity
        }
        
        if animated {
            UIView.animate(withDuration: 0.3, animations: updateBlock)
        } else {
            updateBlock()
        }
    }
    
    /// Updates the adaptive mode
    func updateAdaptiveMode(_ mode: AdaptiveMode) {
        adaptiveMode = mode
        updateForCurrentEnvironment()
    }
    
    // MARK: - Animations
    
    /// Pulse animation for interaction feedback
    func pulse() {
        UIView.animate(withDuration: 0.15, delay: 0, options: [.curveEaseInOut]) {
            self.transform = CGAffineTransform(scaleX: 0.98, y: 0.98)
            self.borderLayer.opacity = 1.0
        } completion: { _ in
            UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.6, initialSpringVelocity: 0.5) {
                self.transform = .identity
                self.borderLayer.opacity = 0.8
            }
        }
    }
    
    /// Shimmer animation for loading states
    func startShimmer() {
        let shimmerLayer = CAGradientLayer()
        shimmerLayer.colors = [
            UIColor.clear.cgColor,
            UIColor.white.withAlphaComponent(0.3).cgColor,
            UIColor.clear.cgColor
        ]
        shimmerLayer.locations = [0.0, 0.5, 1.0]
        shimmerLayer.startPoint = CGPoint(x: -1, y: 0.5)
        shimmerLayer.endPoint = CGPoint(x: 1, y: 0.5)
        shimmerLayer.cornerRadius = 24
        shimmerLayer.cornerCurve = .continuous
        layer.addSublayer(shimmerLayer)
        
        let animation = CABasicAnimation(keyPath: "transform.translation.x")
        animation.fromValue = -bounds.width
        animation.toValue = bounds.width
        animation.duration = 1.5
        animation.repeatCount = .infinity
        shimmerLayer.add(animation, forKey: "shimmer")
    }
    
    func stopShimmer() {
        layer.sublayers?.removeAll { sublayer in
            sublayer.animationKeys()?.contains("shimmer") == true
        }
    }
    
    // MARK: - Gesture Handlers
    
    @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        switch gesture.state {
        case .began:
            UIView.animate(withDuration: 0.1) {
                self.transform = CGAffineTransform(scaleX: 0.98, y: 0.98)
                self.alpha = 0.9
            }
        case .ended, .cancelled:
            UIView.animate(withDuration: 0.2, delay: 0, usingSpringWithDamping: 0.6, initialSpringVelocity: 0.5) {
                self.transform = .identity
                self.alpha = 1.0
            }
        default:
            break
        }
    }
    
    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: self)
        let rotation = translation.x / 100
        
        switch gesture.state {
        case .changed:
            transform = CGAffineTransform(rotationAngle: rotation).scaledBy(x: 0.98, y: 0.98)
        case .ended, .cancelled:
            UIView.animate(withDuration: 0.4, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.5) {
                self.transform = .identity
            }
        default:
            break
        }
    }
    
    // MARK: - Helper Methods
    
    private func createNoiseImage() -> UIImage {
        let size = CGSize(width: 200, height: 200)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { context in
            // Create subtle noise pattern
            for y in 0..<Int(size.height) {
                for x in 0..<Int(size.width) {
                    let value = CGFloat.random(in: 0.95...1.0)
                    context.cgContext.setFillColor(UIColor(white: value, alpha: 1).cgColor)
                    context.cgContext.fill(CGRect(x: x, y: y, width: 1, height: 1))
                }
            }
        }
    }
    
    // MARK: - Layout
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        gradientLayer.frame = bounds
        noiseLayer.frame = bounds
        
        let borderPath = UIBezierPath(
            roundedRect: bounds.insetBy(dx: 1, dy: 1),
            cornerRadius: 23
        )
        borderLayer.path = borderPath.cgPath
        
        layer.shadowPath = UIBezierPath(
            roundedRect: bounds,
            cornerRadius: 24
        ).cgPath
    }
    
    // MARK: - Trait Collection
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            updateForCurrentEnvironment()
        }
        
        if traitCollection.preferredContentSizeCategory != previousTraitCollection?.preferredContentSizeCategory {
            // Update font sizes if needed
        }
    }
}

// MARK: - SwiftUI Integration

@available(iOS 15.0, *)
struct iOS18LiquidGlassViewRepresentable: UIViewRepresentable {
    
    let material: iOS18LiquidGlassView.MaterialStyle
    let vibrancy: iOS18LiquidGlassView.VibrancyStyle
    let adaptiveMode: iOS18LiquidGlassView.AdaptiveMode
    let liquidColor: UIColor
    let intensity: Float
    let content: AnyView
    
    init(
        material: iOS18LiquidGlassView.MaterialStyle = .systemThinMaterial,
        vibrancy: iOS18LiquidGlassView.VibrancyStyle = .primary,
        adaptiveMode: iOS18LiquidGlassView.AdaptiveMode = .automatic,
        liquidColor: UIColor = .white,
        intensity: Float = 1.0,
        @ViewBuilder content: () -> AnyView
    ) {
        self.material = material
        self.vibrancy = vibrancy
        self.adaptiveMode = adaptiveMode
        self.liquidColor = liquidColor
        self.intensity = intensity
        self.content = content()
    }
    
    func makeUIView(context: Context) -> iOS18LiquidGlassView {
        let liquidGlassView = iOS18LiquidGlassView(
            material: material,
            vibrancy: vibrancy,
            adaptiveMode: adaptiveMode,
            liquidColor: liquidColor,
            intensity: intensity
        )
        
        // Add SwiftUI content
        let hostingController = UIHostingController(rootView: content)
        hostingController.view.backgroundColor = .clear
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        liquidGlassView.contentView.addSubview(hostingController.view)
        
        NSLayoutConstraint.activate([
            hostingController.view.topAnchor.constraint(equalTo: liquidGlassView.contentView.topAnchor),
            hostingController.view.leadingAnchor.constraint(equalTo: liquidGlassView.contentView.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: liquidGlassView.contentView.trailingAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: liquidGlassView.contentView.bottomAnchor)
        ])
        
        return liquidGlassView
    }
    
    func updateUIView(_ uiView: iOS18LiquidGlassView, context: Context) {
        // Update properties if needed
    }
}