//
//  LiquidDesignSystem.swift
//  DualCameraApp
//
//  Unified iOS 18 Liquid Glass Design System
//

import UIKit

final class LiquidDesignSystem: @unchecked Sendable {
    
    nonisolated(unsafe) static let shared = LiquidDesignSystem()
    private init() {}
    
    enum DesignTokens {
        enum Colors {
            static let primary = UIColor.white
            static let secondary = UIColor.white.withAlphaComponent(0.6)
            static let background = UIColor.black
            static let accent = UIColor.systemYellow
            static let recording = UIColor.systemRed
            static let liquidGlass = UIColor.white
        }
        
        enum Spacing {
            static let xs: CGFloat = 4
            static let sm: CGFloat = 8
            static let md: CGFloat = 12
            static let lg: CGFloat = 16
            static let xl: CGFloat = 24
            static let xxl: CGFloat = 32
        }
        
        enum CornerRadius {
            static let small: CGFloat = 8
            static let medium: CGFloat = 12
            static let large: CGFloat = 20
            static let xlarge: CGFloat = 24
        }
        
        enum Typography {
            static let title = UIFont.systemFont(ofSize: 17, weight: .semibold)
            static let body = UIFont.systemFont(ofSize: 15, weight: .regular)
            static let caption = UIFont.systemFont(ofSize: 13, weight: .regular)
            static let monospaced = UIFont.monospacedSystemFont(ofSize: 15, weight: .medium)
        }
        
        enum Shadow {
            static let color = UIColor.black.cgColor
            static let opacity: Float = 0.15
            static let offset = CGSize(width: 0, height: 4)
            static let radius: CGFloat = 16
        }
    }
    
    nonisolated(unsafe) private static var sharedNoiseTexture: UIImage?
    
    static func noiseTexture() -> UIImage {
        if let cached = sharedNoiseTexture {
            return cached
        }
        
        let size = CGSize(width: 200, height: 200)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        let image = renderer.image { context in
            for y in 0..<Int(size.height) {
                for x in 0..<Int(size.width) {
                    let value = CGFloat.random(in: 0.95...1.0)
                    context.cgContext.setFillColor(UIColor(white: value, alpha: 1).cgColor)
                    context.cgContext.fill(CGRect(x: x, y: y, width: 1, height: 1))
                }
            }
        }
        
        sharedNoiseTexture = image
        return image
    }
}



final class ModernLiquidGlassButton: UIButton {
    
    private let gradientLayer = CAGradientLayer()
    private let noiseLayer = CALayer()
    private let blurEffectView = UIVisualEffectView()
    private let vibrancyEffectView = UIVisualEffectView()
    private let glowLayer = CALayer()
    private let contentContainer = UIView()
    
    private var cachedBounds: CGRect = .zero
    private var cachedCornerRadius: CGFloat = 0
    private var hasMovedSubviews: Bool = false
    private var isAnimating: Bool = false
    
    var liquidColor: UIColor = LiquidDesignSystem.DesignTokens.Colors.liquidGlass {
        didSet { updateAppearance() }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupButton()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupButton()
    }
    
    private func setupButton() {
        backgroundColor = .clear
        
        gradientLayer.colors = [
            liquidColor.withAlphaComponent(0.4).cgColor,
            liquidColor.withAlphaComponent(0.2).cgColor
        ]
        gradientLayer.locations = [0.0, 1.0]
        gradientLayer.startPoint = CGPoint(x: 0, y: 0)
        gradientLayer.endPoint = CGPoint(x: 1, y: 1)
        gradientLayer.cornerRadius = LiquidDesignSystem.DesignTokens.CornerRadius.medium
        gradientLayer.cornerCurve = .continuous
        layer.insertSublayer(gradientLayer, at: 0)
        
        noiseLayer.contents = LiquidDesignSystem.noiseTexture().cgImage
        noiseLayer.opacity = 0.015
        noiseLayer.compositingFilter = "overlayBlendMode"
        noiseLayer.cornerRadius = LiquidDesignSystem.DesignTokens.CornerRadius.medium
        noiseLayer.cornerCurve = .continuous
        layer.insertSublayer(noiseLayer, at: 1)
        
        let blurEffect = UIBlurEffect(style: .systemUltraThinMaterialDark)
        blurEffectView.effect = blurEffect
        blurEffectView.layer.cornerRadius = LiquidDesignSystem.DesignTokens.CornerRadius.medium
        blurEffectView.layer.cornerCurve = .continuous
        blurEffectView.clipsToBounds = true
        blurEffectView.isUserInteractionEnabled = false
        blurEffectView.translatesAutoresizingMaskIntoConstraints = false
        insertSubview(blurEffectView, at: 0)
        
        let vibrancyEffect = UIVibrancyEffect(blurEffect: blurEffect, style: .label)
        vibrancyEffectView.effect = vibrancyEffect
        vibrancyEffectView.isUserInteractionEnabled = false
        vibrancyEffectView.translatesAutoresizingMaskIntoConstraints = false
        blurEffectView.contentView.addSubview(vibrancyEffectView)
        
        contentContainer.isUserInteractionEnabled = false
        contentContainer.translatesAutoresizingMaskIntoConstraints = false
        vibrancyEffectView.contentView.addSubview(contentContainer)
        
        layer.cornerRadius = LiquidDesignSystem.DesignTokens.CornerRadius.medium
        layer.cornerCurve = .continuous
        layer.borderWidth = 1.5
        layer.borderColor = UIColor.white.withAlphaComponent(0.35).cgColor
        
        glowLayer.backgroundColor = UIColor.clear.cgColor
        glowLayer.shadowColor = liquidColor.cgColor
        glowLayer.shadowOffset = .zero
        glowLayer.shadowRadius = 12
        glowLayer.shadowOpacity = 0
        glowLayer.cornerRadius = LiquidDesignSystem.DesignTokens.CornerRadius.medium
        glowLayer.cornerCurve = .continuous
        layer.insertSublayer(glowLayer, at: 0)
        
        let shadowPath = UIBezierPath(roundedRect: CGRect(x: 0, y: 0, width: 100, height: 100), cornerRadius: LiquidDesignSystem.DesignTokens.CornerRadius.medium).cgPath
        glowLayer.shadowPath = shadowPath
        
        tintColor = .white
        setTitleColor(.white, for: .normal)
        titleLabel?.font = LiquidDesignSystem.DesignTokens.Typography.body
        
        NSLayoutConstraint.activate([
            blurEffectView.topAnchor.constraint(equalTo: topAnchor),
            blurEffectView.leadingAnchor.constraint(equalTo: leadingAnchor),
            blurEffectView.trailingAnchor.constraint(equalTo: trailingAnchor),
            blurEffectView.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            vibrancyEffectView.topAnchor.constraint(equalTo: blurEffectView.contentView.topAnchor),
            vibrancyEffectView.leadingAnchor.constraint(equalTo: blurEffectView.contentView.leadingAnchor),
            vibrancyEffectView.trailingAnchor.constraint(equalTo: blurEffectView.contentView.trailingAnchor),
            vibrancyEffectView.bottomAnchor.constraint(equalTo: blurEffectView.contentView.bottomAnchor),
            
            contentContainer.topAnchor.constraint(equalTo: vibrancyEffectView.contentView.topAnchor),
            contentContainer.leadingAnchor.constraint(equalTo: vibrancyEffectView.contentView.leadingAnchor),
            contentContainer.trailingAnchor.constraint(equalTo: vibrancyEffectView.contentView.trailingAnchor),
            contentContainer.bottomAnchor.constraint(equalTo: vibrancyEffectView.contentView.bottomAnchor)
        ])
        
        DispatchQueue.main.async { [weak self] in
            self?.moveSubviewsToContentContainer()
        }
        
        addTarget(self, action: #selector(touchDown), for: [.touchDown, .touchDragEnter])
        addTarget(self, action: #selector(touchUp), for: [.touchUpInside, .touchUpOutside, .touchCancel, .touchDragExit])
    }
    
    private func moveSubviewsToContentContainer() {
        guard !hasMovedSubviews else { return }
        
        if let imageView = self.imageView, imageView.superview != contentContainer {
            imageView.tintColor = .white
            imageView.isUserInteractionEnabled = false
            imageView.removeFromSuperview()
            contentContainer.addSubview(imageView)
        }
        
        if let titleLabel = self.titleLabel, titleLabel.superview != contentContainer {
            titleLabel.textColor = .white
            titleLabel.isUserInteractionEnabled = false
            titleLabel.removeFromSuperview()
            contentContainer.addSubview(titleLabel)
        }
        
        hasMovedSubviews = true
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        guard bounds != cachedBounds else { return }
        cachedBounds = bounds
        
        let cornerRadius = min(bounds.width, bounds.height) / 2
        if cornerRadius != cachedCornerRadius {
            cachedCornerRadius = cornerRadius
            layer.cornerRadius = cornerRadius
            blurEffectView.layer.cornerRadius = cornerRadius
            glowLayer.cornerRadius = cornerRadius
        }
        
        gradientLayer.frame = bounds
        noiseLayer.frame = bounds
        glowLayer.frame = bounds
        glowLayer.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: cornerRadius).cgPath
        
        if !hasMovedSubviews {
            moveSubviewsToContentContainer()
        }
    }
    
    enum PerformanceLevel { case high, medium, low }
    
    func optimizeForPerformance(level: PerformanceLevel) {
        switch level {
        case .high:
            layer.shouldRasterize = false
        case .medium:
            layer.shouldRasterize = true
            layer.rasterizationScale = UIScreen.main.scale
        case .low:
            layer.shouldRasterize = true
            layer.rasterizationScale = UIScreen.main.scale * 0.75
        }
    }
    
    @objc private func touchDown() {
        isAnimating = true
        layer.shouldRasterize = false
        HapticFeedbackManager.shared.lightImpact()
        UIView.animate(withDuration: 0.15, delay: 0, options: [.beginFromCurrentState, .allowUserInteraction, .curveEaseOut]) {
            self.transform = CGAffineTransform(scaleX: 0.94, y: 0.94)
            self.glowLayer.shadowOpacity = 0.5
        }
    }
    
    @objc private func touchUp() {
        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.6, initialSpringVelocity: 0.8, options: [.beginFromCurrentState, .allowUserInteraction]) {
            self.transform = .identity
            self.glowLayer.shadowOpacity = 0
        } completion: { _ in
            self.isAnimating = false
        }
    }
    
    private func updateAppearance() {
        gradientLayer.colors = [
            liquidColor.withAlphaComponent(0.4).cgColor,
            liquidColor.withAlphaComponent(0.2).cgColor
        ]
        glowLayer.shadowColor = liquidColor.cgColor
    }
    
    func setGlowEnabled(_ enabled: Bool, animated: Bool = true) {
        let opacity: Float = enabled ? 0.7 : 0
        if animated {
            let animation = CABasicAnimation(keyPath: "shadowOpacity")
            animation.toValue = opacity
            animation.duration = 0.3
            glowLayer.add(animation, forKey: "shadowOpacity")
        }
        glowLayer.shadowOpacity = opacity
    }
    
    func setRecording(_ recording: Bool, animated: Bool = true) {
        if animated {
            UIView.animate(withDuration: 0.3) {
                self.setGlowEnabled(recording, animated: false)
                if recording {
                    self.layer.borderColor = UIColor.systemRed.cgColor
                    self.glowLayer.shadowColor = UIColor.systemRed.cgColor
                } else {
                    self.layer.borderColor = UIColor.white.withAlphaComponent(0.35).cgColor
                    self.glowLayer.shadowColor = self.liquidColor.cgColor
                }
            }
        } else {
            setGlowEnabled(recording, animated: false)
            if recording {
                layer.borderColor = UIColor.systemRed.cgColor
                glowLayer.shadowColor = UIColor.systemRed.cgColor
            } else {
                layer.borderColor = UIColor.white.withAlphaComponent(0.35).cgColor
                glowLayer.shadowColor = liquidColor.cgColor
            }
        }
    }
    
    func enableRasterization(_ enabled: Bool) {
        layer.shouldRasterize = enabled && !isAnimating
        layer.rasterizationScale = UIScreen.main.scale
    }
}

typealias AppleCameraButton = ModernLiquidGlassButton
typealias AppleModernButton = ModernLiquidGlassButton
typealias AppleRecordButton = ModernLiquidGlassButton
typealias ModernGlassButton = ModernLiquidGlassButton
