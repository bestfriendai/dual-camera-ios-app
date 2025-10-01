//
//  EnhancedGlassmorphismView.swift
//  DualCameraApp
//
//  Enhanced glassmorphism view with iOS 18+ dynamic materials and adaptive blur
//

import UIKit

/// Enhanced glassmorphism view with dynamic materials that adapt to content behind
class EnhancedGlassmorphismView: UIView {
    
    // MARK: - Properties
    
    private let blurEffect: UIBlurEffect
    private let vibrancyEffect: UIVibrancyEffect
    private let blurView: UIVisualEffectView
    private let vibrancyView: UIVisualEffectView
    private let gradientLayer = CAGradientLayer()
    private let noiseLayer = CALayer()
    private let borderLayer = CAShapeLayer()
    
    // Dynamic material properties
    private var materialStyle: MaterialStyle = .ultraThin
    private var vibrancyStyle: VibrancyStyle = .primary
    private var adaptiveBlur: Bool = true
    private var depthEffect: Bool = true
    
    // Public content view for adding subviews
    let contentView: UIView
    
    // MARK: - Material Styles
    
    enum MaterialStyle {
        case ultraThin
        case thin
        case regular
        case thick
        case chrome
        case systemMaterial
        case systemThickMaterial
        case systemChromeMaterial
        
        @available(iOS 13.0, *)
        var blurEffectStyle: UIBlurEffect.Style {
            switch self {
            case .ultraThin:
                return .systemUltraThinMaterial
            case .thin:
                return .systemThinMaterial
            case .regular:
                return .systemMaterial
            case .thick:
                return .systemThickMaterial
            case .chrome:
                return .systemChromeMaterial
            case .systemMaterial:
                return .systemMaterial
            case .systemThickMaterial:
                return .systemThickMaterial
            case .systemChromeMaterial:
                return .systemChromeMaterial
            }
        }
        
        @available(iOS 13.0, *)
        var vibrancyEffectStyle: UIVibrancyEffectStyle {
            switch self {
            case .ultraThin, .thin:
                return .label
            case .regular, .thick:
                return .secondaryLabel
            case .chrome, .systemMaterial, .systemThickMaterial, .systemChromeMaterial:
                return .tertiaryLabel
            }
        }
    }
    
    enum VibrancyStyle {
        case primary
        case secondary
        case tertiary
        case quaternary
        
        @available(iOS 13.0, *)
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
    
    // MARK: - Initialization
    
    init(material: MaterialStyle = .regular, vibrancy: VibrancyStyle = .primary, adaptiveBlur: Bool = true, depthEffect: Bool = true) {
        self.materialStyle = material
        self.vibrancyStyle = vibrancy
        self.adaptiveBlur = adaptiveBlur
        self.depthEffect = depthEffect
        
        // Create blur effect with modern materials
        if #available(iOS 13.0, *) {
            self.blurEffect = UIBlurEffect(style: material.blurEffectStyle)
            self.vibrancyEffect = UIVibrancyEffect(blurEffect: blurEffect, style: vibrancy.effectStyle)
        } else {
            self.blurEffect = UIBlurEffect(style: .light)
            self.vibrancyEffect = UIVibrancyEffect(blurEffect: blurEffect, style: .label)
        }
        
        self.blurView = UIVisualEffectView(effect: blurEffect)
        self.vibrancyView = UIVisualEffectView(effect: vibrancyEffect)
        self.contentView = UIView()
        
        super.init(frame: .zero)
        setupViews()
        setupDynamicEffects()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Setup
    
    private func setupViews() {
        backgroundColor = .clear
        
        // Enhanced glassmorphism styling with modern corner radius
        layer.cornerRadius = 24
        layer.cornerCurve = .continuous
        
        // Don't clip to bounds for shadow effects
        layer.masksToBounds = false
        clipsToBounds = true
        
        // Setup enhanced border with gradient
        setupBorderLayer()
        
        // Setup multi-layer gradient for depth
        setupGradientLayer()
        
        // Setup noise layer for texture
        setupNoiseLayer()
        
        // Add blur view
        blurView.translatesAutoresizingMaskIntoConstraints = false
        blurView.layer.cornerRadius = 24
        blurView.layer.cornerCurve = .continuous
        blurView.clipsToBounds = true
        addSubview(blurView)
        
        // Add vibrancy view for enhanced text/icon rendering
        vibrancyView.translatesAutoresizingMaskIntoConstraints = false
        blurView.contentView.addSubview(vibrancyView)
        
        // Add content view on top
        contentView.translatesAutoresizingMaskIntoConstraints = false
        contentView.backgroundColor = .clear
        vibrancyView.contentView.addSubview(contentView)
        
        // Setup constraints
        setupConstraints()
        
        // Setup gesture recognizers for dynamic effects
        setupGestureRecognizers()
    }
    
    private func setupBorderLayer() {
        borderLayer.fillColor = UIColor.clear.cgColor
        borderLayer.strokeColor = UIColor.white.withAlphaComponent(0.25).cgColor
        borderLayer.lineWidth = 1.5
        borderLayer.lineDashPattern = [8, 4]
        borderLayer.lineCap = .round
        borderLayer.opacity = 0.8
        layer.addSublayer(borderLayer)
    }
    
    private func setupGradientLayer() {
        gradientLayer.colors = [
            UIColor.white.withAlphaComponent(0.15).cgColor,
            UIColor.white.withAlphaComponent(0.08).cgColor,
            UIColor.white.withAlphaComponent(0.03).cgColor,
            UIColor.clear.cgColor
        ]
        gradientLayer.locations = [0.0, 0.4, 0.7, 1.0]
        gradientLayer.startPoint = CGPoint(x: 0, y: 0)
        gradientLayer.endPoint = CGPoint(x: 1, y: 1)
        layer.insertSublayer(gradientLayer, at: 0)
    }
    
    private func setupNoiseLayer() {
        noiseLayer.contents = createNoiseImage().cgImage
        noiseLayer.opacity = 0.03
        noiseLayer.compositingFilter = "overlayBlendMode"
        layer.insertSublayer(noiseLayer, at: 1)
    }
    
    private func createNoiseImage() -> UIImage {
        let size = CGSize(width: 100, height: 100)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { context in
            // Create random noise pattern
            for y in 0..<Int(size.height) {
                for x in 0..<Int(size.width) {
                    let value = CGFloat.random(in: 0...1)
                    context.cgContext.setFillColor(UIColor(white: value, alpha: 1).cgColor)
                    context.cgContext.fill(CGRect(x: x, y: y, width: 1, height: 1))
                }
            }
        }
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            blurView.topAnchor.constraint(equalTo: topAnchor),
            blurView.leadingAnchor.constraint(equalTo: leadingAnchor),
            blurView.trailingAnchor.constraint(equalTo: trailingAnchor),
            blurView.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            vibrancyView.topAnchor.constraint(equalTo: blurView.contentView.topAnchor),
            vibrancyView.leadingAnchor.constraint(equalTo: blurView.contentView.leadingAnchor),
            vibrancyView.trailingAnchor.constraint(equalTo: blurView.contentView.trailingAnchor),
            vibrancyView.bottomAnchor.constraint(equalTo: blurView.contentView.bottomAnchor),
            
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
    }
    
    private func setupDynamicEffects() {
        if adaptiveBlur {
            setupAdaptiveBlur()
        }
        
        if depthEffect {
            setupDepthEffects()
        }
    }
    
    private func setupAdaptiveBlur() {
        // Monitor background changes and adapt blur accordingly
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(adaptiveBlurChanged),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }
    
    private func setupDepthEffects() {
        // Add subtle shadow for depth
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.15
        layer.shadowOffset = CGSize(width: 0, height: 8)
        layer.shadowRadius = 16
        layer.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: 24).cgPath
    }
    
    // MARK: - Dynamic Effects
    
    @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        switch gesture.state {
        case .began:
            animatePressDown()
        case .ended, .cancelled:
            animatePressUp()
        default:
            break
        }
    }
    
    @objc private func adaptiveBlurChanged() {
        // Adapt blur intensity based on current environment
        updateMaterialForCurrentEnvironment()
    }
    
    private func updateMaterialForCurrentEnvironment() {
        guard adaptiveBlur else { return }
        
        let newMaterial: MaterialStyle
        
        if traitCollection.userInterfaceStyle == .dark {
            newMaterial = .systemThickMaterial
        } else {
            newMaterial = .systemMaterial
        }
        
        updateMaterial(newMaterial)
    }
    
    private func updateMaterial(_ material: MaterialStyle) {
        guard #available(iOS 13.0, *) else { return }
        
        let newBlurEffect = UIBlurEffect(style: material.blurEffectStyle)
        let newVibrancyEffect = UIVibrancyEffect(blurEffect: newBlurEffect, style: vibrancyStyle.effectStyle)
        
        UIView.animate(withDuration: 0.3) {
            self.blurView.effect = newBlurEffect
            self.vibrancyView.effect = newVibrancyEffect
        }
    }
    
    // MARK: - Animations
    
    private func animatePressDown() {
        UIView.animate(withDuration: 0.1, delay: 0, options: [.curveEaseInOut]) {
            self.transform = CGAffineTransform(scaleX: 0.98, y: 0.98)
            self.alpha = 0.9
            self.borderLayer.opacity = 1.0
        }
    }
    
    private func animatePressUp() {
        UIView.animate(withDuration: 0.2, delay: 0, options: [.curveEaseInOut]) {
            self.transform = .identity
            self.alpha = 1.0
            self.borderLayer.opacity = 0.8
        }
    }
    
    // MARK: - Public Methods
    
    /// Animate the glassmorphism effect with a subtle pulse
    func pulse() {
        UIView.animate(withDuration: 0.3, delay: 0, options: [.curveEaseInOut, .allowUserInteraction]) {
            self.transform = CGAffineTransform(scaleX: 0.98, y: 0.98)
            self.borderLayer.opacity = 1.0
        } completion: { _ in
            UIView.animate(withDuration: 0.3, delay: 0, options: [.curveEaseInOut, .allowUserInteraction]) {
                self.transform = .identity
                self.borderLayer.opacity = 0.8
            }
        }
    }
    
    /// Update the material style with animation
    func updateMaterialStyle(_ style: MaterialStyle, animated: Bool = true) {
        materialStyle = style

        guard #available(iOS 13.0, *) else { return }

        let applyChanges = {
            let newBlurEffect = UIBlurEffect(style: style.blurEffectStyle)
            self.blurView.effect = newBlurEffect
            self.vibrancyView.effect = UIVibrancyEffect(blurEffect: newBlurEffect, style: self.vibrancyStyle.effectStyle)
        }

        if animated {
            UIView.animate(withDuration: 0.3, animations: applyChanges)
        } else {
            applyChanges()
        }
    }
    
    /// Update the vibrancy style with animation
    func updateVibrancyStyle(_ style: VibrancyStyle, animated: Bool = true) {
        vibrancyStyle = style

        guard #available(iOS 13.0, *) else { return }

        let applyChanges = {
            let activeBlurEffect = (self.blurView.effect as? UIBlurEffect) ?? self.blurEffect
            self.vibrancyView.effect = UIVibrancyEffect(blurEffect: activeBlurEffect, style: style.effectStyle)
        }

        if animated {
            UIView.animate(withDuration: 0.3, animations: applyChanges)
        } else {
            applyChanges()
        }
    }
    
    /// Enable or disable adaptive blur
    func setAdaptiveBlur(_ enabled: Bool) {
        adaptiveBlur = enabled
        if enabled {
            setupAdaptiveBlur()
            updateMaterialForCurrentEnvironment()
        }
    }
    
    /// Enable or disable depth effects
    func setDepthEffect(_ enabled: Bool) {
        depthEffect = enabled
        if enabled {
            setupDepthEffects()
        } else {
            layer.shadowOpacity = 0
        }
    }
    
    // MARK: - Layout
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        // Update gradient layer frame
        gradientLayer.frame = bounds
        
        // Update noise layer frame
        noiseLayer.frame = bounds
        
        // Update border layer path
        let borderPath = UIBezierPath(roundedRect: bounds.insetBy(dx: 1.5, dy: 1.5), cornerRadius: 22.5)
        borderLayer.path = borderPath.cgPath
        
        // Update shadow path
        layer.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: 24).cgPath
    }
    
    // MARK: - Trait Collection
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            updateMaterialForCurrentEnvironment()
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}