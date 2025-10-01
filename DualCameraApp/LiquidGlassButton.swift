//
//  LiquidGlassButton.swift
//  DualCameraApp
//
//  True iOS 18+ Liquid Glass button with brightness and luminosity
//

import UIKit

class LiquidGlassButton: UIButton {
    
    private let blurEffectView = UIVisualEffectView()
    private let vibrancyEffectView = UIVisualEffectView()
    private let brightnessLayer = CALayer()
    private let glossLayer = CAGradientLayer()
    private let glowLayer = CALayer()
    private let contentContainer = UIView()
    
    var liquidGlassColor: UIColor = .white {
        didSet { updateAppearance() }
    }
    
    var glassIntensity: CGFloat = 0.5 {
        didSet { updateAppearance() }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLiquidGlass()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupLiquidGlass()
    }
    
    private func setupLiquidGlass() {
        backgroundColor = .clear
        
        // Thin blur base
        let blurEffect = UIBlurEffect(style: .systemThinMaterial)
        blurEffectView.effect = blurEffect
        blurEffectView.layer.cornerRadius = 14
        blurEffectView.layer.cornerCurve = .continuous
        blurEffectView.clipsToBounds = true
        blurEffectView.isUserInteractionEnabled = false
        blurEffectView.translatesAutoresizingMaskIntoConstraints = false
        insertSubview(blurEffectView, at: 0)
        
        // Vibrancy for icons
        let vibrancyEffect = UIVibrancyEffect(blurEffect: blurEffect, style: .label)
        vibrancyEffectView.effect = vibrancyEffect
        vibrancyEffectView.isUserInteractionEnabled = false
        vibrancyEffectView.translatesAutoresizingMaskIntoConstraints = false
        blurEffectView.contentView.addSubview(vibrancyEffectView)
        
        // Content container
        contentContainer.isUserInteractionEnabled = false
        contentContainer.translatesAutoresizingMaskIntoConstraints = false
        vibrancyEffectView.contentView.addSubview(contentContainer)
        
        // Brightness layer - BRIGHT for liquid glass
        brightnessLayer.backgroundColor = liquidGlassColor.withAlphaComponent(glassIntensity).cgColor
        brightnessLayer.cornerRadius = 14
        brightnessLayer.cornerCurve = .continuous
        layer.insertSublayer(brightnessLayer, at: 0)
        
        // Glossy gradient
        glossLayer.colors = [
            UIColor.white.withAlphaComponent(0.5).cgColor,
            UIColor.white.withAlphaComponent(0.1).cgColor,
            UIColor.clear.cgColor
        ]
        glossLayer.locations = [0.0, 0.4, 1.0]
        glossLayer.startPoint = CGPoint(x: 0, y: 0)
        glossLayer.endPoint = CGPoint(x: 1, y: 1)
        glossLayer.cornerRadius = 14
        glossLayer.cornerCurve = .continuous
        layer.insertSublayer(glossLayer, above: brightnessLayer)
        
        // Bright border
        layer.cornerRadius = 14
        layer.cornerCurve = .continuous
        layer.borderWidth = 1.5
        layer.borderColor = UIColor.white.withAlphaComponent(0.6).cgColor
        
        // Glow layer
        glowLayer.backgroundColor = UIColor.clear.cgColor
        glowLayer.shadowColor = liquidGlassColor.cgColor
        glowLayer.shadowOffset = .zero
        glowLayer.shadowRadius = 12
        glowLayer.shadowOpacity = 0
        glowLayer.cornerRadius = 14
        glowLayer.cornerCurve = .continuous
        layer.insertSublayer(glowLayer, at: 0)
        
        // Constraints
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
        
        // Touch animations
        addTarget(self, action: #selector(touchDown), for: .touchDown)
        addTarget(self, action: #selector(touchUp), for: [.touchUpInside, .touchUpOutside, .touchCancel])
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        brightnessLayer.frame = bounds
        glossLayer.frame = bounds
        glowLayer.frame = bounds
        
        // Move imageView to vibrancy
        if let imageView = self.imageView, imageView.superview != contentContainer {
            imageView.removeFromSuperview()
            contentContainer.addSubview(imageView)
        }
    }
    
    @objc private func touchDown() {
        UIView.animate(withDuration: 0.12, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.5) {
            self.transform = CGAffineTransform(scaleX: 0.92, y: 0.92)
            self.glowLayer.shadowOpacity = 0.6
        }
        HapticFeedbackManager.shared.lightImpact()
    }
    
    @objc private func touchUp() {
        UIView.animate(withDuration: 0.25, delay: 0, usingSpringWithDamping: 0.5, initialSpringVelocity: 0.5) {
            self.transform = .identity
            self.glowLayer.shadowOpacity = 0
        }
    }
    
    private func updateAppearance() {
        brightnessLayer.backgroundColor = liquidGlassColor.withAlphaComponent(glassIntensity).cgColor
        glowLayer.shadowColor = liquidGlassColor.cgColor
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
}
