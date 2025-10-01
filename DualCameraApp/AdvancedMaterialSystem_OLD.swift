//
//  AdvancedMaterialSystem.swift
//  DualCameraApp
//
//  Advanced material system with prominent vibrancy, depth effects, and dynamic blur materials
//

import UIKit

/// Advanced material system for creating modern iOS 18+ UI components
class AdvancedMaterialSystem {
    
    static let shared = AdvancedMaterialSystem()
    
    private init() {}
    
    // MARK: - Material Presets
    
    /// Creates a prominent glassmorphism container with enhanced depth
    static func createProminentContainer() -> EnhancedGlassmorphismView {
        let container = EnhancedGlassmorphismView(material: .regular)
        
        // Enhanced styling for prominent containers
        container.layer.cornerRadius = 28
        container.layer.shadowColor = UIColor.black.cgColor
        container.layer.shadowOpacity = 0.25
        container.layer.shadowOffset = CGSize(width: 0, height: 12)
        container.layer.shadowRadius = 24
        
        return container
    }
    
    /// Creates a subtle glassmorphism container for secondary content
    static func createSubtleContainer() -> EnhancedGlassmorphismView {
        let container = EnhancedGlassmorphismView(material: .thin)
        
        // Subtle styling for secondary containers
        container.layer.cornerRadius = 20
        container.layer.shadowColor = UIColor.black.cgColor
        container.layer.shadowOpacity = 0.1
        container.layer.shadowOffset = CGSize(width: 0, height: 4)
        container.layer.shadowRadius = 8
        
        return container
    }
    
    static func createChromeContainer() -> EnhancedGlassmorphismView {
        let container = EnhancedGlassmorphismView(material: .regular)
        
        // Chrome styling for controls
        container.layer.cornerRadius = 16
        container.layer.shadowColor = UIColor.black.cgColor
        container.layer.shadowOpacity = 0.2
        container.layer.shadowOffset = CGSize(width: 0, height: 6)
        container.layer.shadowRadius = 12
        
        return container
    }
    
    /// Creates an ultra-thin container for overlays
    static func createUltraThinContainer() -> EnhancedGlassmorphismView {
        let container = EnhancedGlassmorphismView(material: .ultraThin, vibrancy: .tertiary, adaptiveBlur: true, depthEffect: false)
        
        // Ultra-thin styling for overlays
        container.layer.cornerRadius = 12
        container.layer.shadowColor = UIColor.black.cgColor
        container.layer.shadowOpacity = 0.05
        container.layer.shadowOffset = CGSize(width: 0, height: 2)
        container.layer.shadowRadius = 4
        
        return container
    }
    
    // MARK: - Dynamic Material Views
    
    /// Creates a dynamic button with material background
    static func createMaterialButton(
        title: String,
        style: MaterialButtonStyle = .primary,
        icon: UIImage? = nil
    ) -> MaterialButton {
        return MaterialButton(title: title, style: style, icon: icon)
    }
    
    /// Creates a dynamic card with material background
    static func createMaterialCard(
        title: String,
        subtitle: String? = nil,
        style: MaterialCardStyle = .standard
    ) -> MaterialCard {
        return MaterialCard(title: title, subtitle: subtitle, style: style)
    }
    
    /// Creates a floating action button with material effects
    static func createFloatingActionButton(
        icon: UIImage,
        style: FloatingActionButtonStyle = .primary
    ) -> FloatingActionButton {
        return FloatingActionButton(icon: icon, style: style)
    }
    
    // MARK: - Material Animations
    
    /// Creates a spring animation for material transitions
    static func createSpringAnimation(
        damping: CGFloat = 0.8,
        velocity: CGFloat = 0.5
    ) -> UISpringTimingParameters {
        return UISpringTimingParameters(dampingRatio: damping, initialVelocity: CGVector(dx: velocity, dy: velocity))
    }
    
    static func createFadeAnimation(
        duration: TimeInterval = 0.3,
        delay: TimeInterval = 0
    ) -> UIViewPropertyAnimator {
        return UIViewPropertyAnimator(duration: duration, delay: delay, options: [.curveEaseInOut], animations: {})
    }
    
    // MARK: - Material Gradients
    
    /// Creates a material-appropriate gradient overlay
    static func createMaterialGradient(
        colors: [UIColor],
        style: GradientStyle = .linear
    ) -> CAGradientLayer {
        let gradient = CAGradientLayer()
        
        // Convert colors to CGColor with appropriate alpha for materials
        let cgColors = colors.map { color in
            color.withAlphaComponent(color.cgColor.alpha * 0.8).cgColor
        }
        
        gradient.colors = cgColors
        
        switch style {
        case .linear:
            gradient.type = .axial
            gradient.startPoint = CGPoint(x: 0, y: 0)
            gradient.endPoint = CGPoint(x: 1, y: 1)
        case .radial:
            gradient.type = .radial
            gradient.startPoint = CGPoint(x: 0.5, y: 0.5)
            gradient.endPoint = CGPoint(x: 1, y: 1)
        }
        
        return gradient
    }
    
    // MARK: - Material Shadows
    
    /// Creates an appropriate shadow for material components
    static func createMaterialShadow(
        style: ShadowStyle = .medium
    ) -> (color: UIColor, opacity: Float, offset: CGSize, radius: CGFloat) {
        switch style {
        case .subtle:
            return (
                color: UIColor.black,
                opacity: 0.1,
                offset: CGSize(width: 0, height: 2),
                radius: 4
            )
        case .medium:
            return (
                color: UIColor.black,
                opacity: 0.2,
                offset: CGSize(width: 0, height: 6),
                radius: 12
            )
        case .prominent:
            return (
                color: UIColor.black,
                opacity: 0.3,
                offset: CGSize(width: 0, height: 12),
                radius: 24
            )
        case .floating:
            return (
                color: UIColor.black,
                opacity: 0.25,
                offset: CGSize(width: 0, height: 8),
                radius: 16
            )
        }
    }
}

// MARK: - Material Button

class MaterialButton: UIButton {
    
    private let materialView = EnhancedGlassmorphismView(material: .thin)
    
    private let buttonTitleLabel = UILabel()
    private let iconImageView = UIImageView()
    private let hapticLayer = CAShapeLayer()
    
    var style: MaterialButtonStyle = .primary {
        didSet {
            updateStyle()
        }
    }
    
    init(title: String, style: MaterialButtonStyle = .primary, icon: UIImage? = nil) {
        self.style = style
        super.init(frame: .zero)
        setupButton(title: title, icon: icon)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupButton(title: "", icon: nil)
    }
    
    private func setupButton(title: String, icon: UIImage?) {
        // Setup material background
        materialView.translatesAutoresizingMaskIntoConstraints = false
        insertSubview(materialView, at: 0)
        
        // Setup title label
        buttonTitleLabel.text = title
        buttonTitleLabel.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        buttonTitleLabel.textColor = .white
        buttonTitleLabel.textAlignment = .center
        buttonTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        materialView.contentView.addSubview(titleLabel)
        
        // Setup icon image view
        if let icon = icon {
            iconImageView.image = icon.withTintColor(.white, renderingMode: .alwaysOriginal)
            iconImageView.contentMode = .scaleAspectFit
            iconImageView.translatesAutoresizingMaskIntoConstraints = false
            materialView.contentView.addSubview(iconImageView)
        }
        
        // Setup haptic layer
        hapticLayer.fillColor = UIColor.white.withAlphaComponent(0.1).cgColor
        hapticLayer.opacity = 0
        layer.insertSublayer(hapticLayer, below: materialView.layer)
        
        // Setup constraints
        setupConstraints()
        
        // Add touch handlers
        addTarget(self, action: #selector(touchDown), for: [.touchDown, .touchDragEnter])
        addTarget(self, action: #selector(touchUp), for: [.touchUpInside, .touchDragExit, .touchCancel])
        
        updateStyle()
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            materialView.topAnchor.constraint(equalTo: topAnchor),
            materialView.leadingAnchor.constraint(equalTo: leadingAnchor),
            materialView.trailingAnchor.constraint(equalTo: trailingAnchor),
            materialView.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            buttonTitleLabel.centerYAnchor.constraint(equalTo: materialView.contentView.centerYAnchor),
            buttonTitleLabel.centerXAnchor.constraint(equalTo: materialView.contentView.centerXAnchor)
        ])
        
        if iconImageView.image != nil {
            NSLayoutConstraint.activate([
                iconImageView.centerYAnchor.constraint(equalTo: materialView.contentView.centerYAnchor),
                iconImageView.trailingAnchor.constraint(equalTo: buttonTitleLabel.leadingAnchor, constant: -8),
                iconImageView.widthAnchor.constraint(equalToConstant: 20),
                iconImageView.heightAnchor.constraint(equalToConstant: 20)
            ])
        }
    }
    
    private func updateStyle() {
        switch style {
        case .primary:
            materialView.updateMaterialStyle(.regular)
            layer.cornerRadius = 16
        case .secondary:
            materialView.updateMaterialStyle(.thin)
            layer.cornerRadius = 12
        case .chrome:
            materialView.updateMaterialStyle(.prominent)
            layer.cornerRadius = 8
        case .destructive:
            materialView.updateMaterialStyle(.regular)
            buttonTitleLabel.textColor = .systemRed
            layer.cornerRadius = 16
        }
    }
    
    @objc private func touchDown() {
        UIView.animate(withDuration: 0.1) {
            self.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
            self.hapticLayer.opacity = 1
        }
        
        HapticFeedbackManager.shared.lightImpact()
    }
    
    @objc private func touchUp() {
        UIView.animate(withDuration: 0.2) {
            self.transform = .identity
            self.hapticLayer.opacity = 0
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        hapticLayer.path = UIBezierPath(roundedRect: bounds, cornerRadius: layer.cornerRadius).cgPath
        hapticLayer.frame = bounds
    }
}

// MARK: - Material Card

class MaterialCard: UIView {
    
    private let materialView = EnhancedGlassmorphismView(material: .regular, vibrancy: .primary, adaptiveBlur: true, depthEffect: true)
    
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let iconImageView = UIImageView()
    
    var style: MaterialCardStyle = .standard {
        didSet {
            updateStyle()
        }
    }
    
    init(title: String, subtitle: String? = nil, style: MaterialCardStyle = .standard) {
        self.style = style
        super.init(frame: .zero)
        setupCard(title: title, subtitle: subtitle)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupCard(title: "", subtitle: nil)
    }
    
    private func setupCard(title: String, subtitle: String?) {
        // Setup material background
        materialView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(materialView)
        
        // Setup title label
        buttonTitleLabel.text = title
        buttonTitleLabel.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        buttonTitleLabel.textColor = .white
        buttonTitleLabel.numberOfLines = 0
        buttonTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        materialView.contentView.addSubview(titleLabel)
        
        // Setup subtitle label
        if let subtitle = subtitle {
            subbuttonTitleLabel.text = subtitle
            subbuttonTitleLabel.font = UIFont.systemFont(ofSize: 14, weight: .regular)
            subbuttonTitleLabel.textColor = UIColor.white.withAlphaComponent(0.8)
            subbuttonTitleLabel.numberOfLines = 0
            subbuttonTitleLabel.translatesAutoresizingMaskIntoConstraints = false
            materialView.contentView.addSubview(subtitleLabel)
        }
        
        // Setup constraints
        setupConstraints()
        
        updateStyle()
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            materialView.topAnchor.constraint(equalTo: topAnchor),
            materialView.leadingAnchor.constraint(equalTo: leadingAnchor),
            materialView.trailingAnchor.constraint(equalTo: trailingAnchor),
            materialView.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            buttonTitleLabel.topAnchor.constraint(equalTo: materialView.contentView.topAnchor, constant: 16),
            buttonTitleLabel.leadingAnchor.constraint(equalTo: materialView.contentView.leadingAnchor, constant: 16),
            buttonTitleLabel.trailingAnchor.constraint(equalTo: materialView.contentView.trailingAnchor, constant: -16)
        ])
        
        if !subbuttonTitleLabel.text.isNilOrEmpty {
            NSLayoutConstraint.activate([
                subbuttonTitleLabel.topAnchor.constraint(equalTo: buttonTitleLabel.bottomAnchor, constant: 4),
                subbuttonTitleLabel.leadingAnchor.constraint(equalTo: materialView.contentView.leadingAnchor, constant: 16),
                subbuttonTitleLabel.trailingAnchor.constraint(equalTo: materialView.contentView.trailingAnchor, constant: -16),
                subbuttonTitleLabel.bottomAnchor.constraint(equalTo: materialView.contentView.bottomAnchor, constant: -16)
            ])
        } else {
            NSLayoutConstraint.activate([
                buttonTitleLabel.bottomAnchor.constraint(equalTo: materialView.contentView.bottomAnchor, constant: -16)
            ])
        }
    }
    
    private func updateStyle() {
        switch style {
        case .standard:
            materialView.updateMaterialStyle(.systemMaterial)
            layer.cornerRadius = 16
        case .prominent:
            materialView.updateMaterialStyle(.regular)
            layer.cornerRadius = 20
        case .subtle:
            materialView.updateMaterialStyle(.thin)
            layer.cornerRadius = 12
        }
    }
}

// MARK: - Floating Action Button

class FloatingActionButton: UIButton {
    
    private let materialView = EnhancedGlassmorphismView(material: .regular)
    
    private let iconImageView = UIImageView()
    private let pulseLayer = CAShapeLayer()
    
    var style: FloatingActionButtonStyle = .primary {
        didSet {
            updateStyle()
        }
    }
    
    init(icon: UIImage, style: FloatingActionButtonStyle = .primary) {
        self.style = style
        super.init(frame: .zero)
        setupButton(icon: icon)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupButton(icon: UIImage())
    }
    
    private func setupButton(icon: UIImage) {
        // Setup material background
        materialView.translatesAutoresizingMaskIntoConstraints = false
        insertSubview(materialView, at: 0)
        
        // Setup icon
        iconImageView.image = icon.withTintColor(.white, renderingMode: .alwaysOriginal)
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        materialView.contentView.addSubview(iconImageView)
        
        // Setup pulse layer
        pulseLayer.fillColor = UIColor.white.cgColor
        pulseLayer.opacity = 0
        layer.insertSublayer(pulseLayer, below: materialView.layer)
        
        // Setup constraints
        NSLayoutConstraint.activate([
            materialView.topAnchor.constraint(equalTo: topAnchor),
            materialView.leadingAnchor.constraint(equalTo: leadingAnchor),
            materialView.trailingAnchor.constraint(equalTo: trailingAnchor),
            materialView.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            iconImageView.centerXAnchor.constraint(equalTo: materialView.contentView.centerXAnchor),
            iconImageView.centerYAnchor.constraint(equalTo: materialView.contentView.centerYAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 24),
            iconImageView.heightAnchor.constraint(equalToConstant: 24)
        ])
        
        // Add touch handlers
        addTarget(self, action: #selector(touchDown), for: [.touchDown, .touchDragEnter])
        addTarget(self, action: #selector(touchUp), for: [.touchUpInside, .touchDragExit, .touchCancel])
        
        updateStyle()
    }
    
    private func updateStyle() {
        let size: CGFloat
        let shadow = AdvancedMaterialSystem.createMaterialShadow(style: .floating)
        
        switch style {
        case .primary:
            size = 56
            layer.shadowColor = shadow.color.cgColor
            layer.shadowOpacity = shadow.opacity
            layer.shadowOffset = shadow.offset
            layer.shadowRadius = shadow.radius
        case .small:
            size = 44
            layer.shadowColor = shadow.color.cgColor
            layer.shadowOpacity = shadow.opacity * 0.8
            layer.shadowOffset = CGSize(width: 0, height: 4)
            layer.shadowRadius = 8
        case .large:
            size = 64
            layer.shadowColor = shadow.color.cgColor
            layer.shadowOpacity = shadow.opacity
            layer.shadowOffset = shadow.offset
            layer.shadowRadius = shadow.radius
        }
        
        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: size),
            widthAnchor.constraint(equalToConstant: size)
        ])
        
        layer.cornerRadius = size / 2
        materialView.layer.cornerRadius = size / 2
    }
    
    @objc private func touchDown() {
        UIView.animate(withDuration: 0.1) {
            self.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
        }
        
        // Add pulse effect
        let pulseAnimation = CABasicAnimation(keyPath: "transform.scale")
        pulseAnimation.fromValue = 1.0
        pulseAnimation.toValue = 1.3
        pulseAnimation.duration = 0.6
        pulseAnimation.timingFunction = CAMediaTimingFunction(name: .easeOut)
        pulseAnimation.autoreverses = false
        
        pulseLayer.add(pulseAnimation, forKey: "pulse")
        
        UIView.animate(withDuration: 0.3) {
            self.pulseLayer.opacity = 0.3
        }
        
        HapticFeedbackManager.shared.mediumImpact()
    }
    
    @objc private func touchUp() {
        UIView.animate(withDuration: 0.2) {
            self.transform = .identity
        }
        
        UIView.animate(withDuration: 0.3) {
            self.pulseLayer.opacity = 0
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        pulseLayer.path = UIBezierPath(ovalIn: bounds).cgPath
        pulseLayer.frame = bounds
    }
}

// MARK: - Supporting Enums

enum MaterialButtonStyle {
    case primary
    case secondary
    case chrome
    case destructive
}

enum MaterialCardStyle {
    case standard
    case prominent
    case subtle
}

enum FloatingActionButtonStyle {
    case primary
    case small
    case large
}

enum GradientStyle {
    case linear
    case radial
}

enum ShadowStyle {
    case subtle
    case medium
    case prominent
    case floating
}

// MARK: - String Extension

extension Optional where Wrapped == String {
    var isNilOrEmpty: Bool {
        return self?.isEmpty ?? true
    }
}