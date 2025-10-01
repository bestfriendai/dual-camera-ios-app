//
//  LiquidGlassButton.swift
//  DualCameraApp
//
//  True iOS 18+ Liquid Glass button with brightness and luminosity
//

import UIKit

class LiquidGlassButton: UIButton {
    
    private let gradientLayer = CAGradientLayer()  // KEY: Gradient BEHIND
    private let blurEffectView = UIVisualEffectView()
    private let vibrancyEffectView = UIVisualEffectView()
    private let glowLayer = CALayer()
    private let contentContainer = UIView()
    
    var liquidGlassColor: UIColor = .white {
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
        
        // STEP 1: Gradient BEHIND (Apple's way!)
        gradientLayer.colors = [
            liquidGlassColor.withAlphaComponent(0.6).cgColor,
            liquidGlassColor.withAlphaComponent(0.3).cgColor
        ]
        gradientLayer.locations = [0.0, 1.0]
        gradientLayer.startPoint = CGPoint(x: 0, y: 0)
        gradientLayer.endPoint = CGPoint(x: 1, y: 1)
        gradientLayer.cornerRadius = 12
        gradientLayer.cornerCurve = .continuous
        layer.insertSublayer(gradientLayer, at: 0)
        
        // STEP 2: Thin material on top
        let blurEffect = UIBlurEffect(style: .systemThinMaterial)
        blurEffectView.effect = blurEffect
        blurEffectView.layer.cornerRadius = 12
        blurEffectView.layer.cornerCurve = .continuous
        blurEffectView.clipsToBounds = true
        blurEffectView.isUserInteractionEnabled = false
        blurEffectView.translatesAutoresizingMaskIntoConstraints = false
        insertSubview(blurEffectView, at: 0)
        
        // STEP 3: Vibrancy for icons
        let vibrancyEffect = UIVibrancyEffect(blurEffect: blurEffect, style: .label)
        vibrancyEffectView.effect = vibrancyEffect
        vibrancyEffectView.isUserInteractionEnabled = false
        vibrancyEffectView.translatesAutoresizingMaskIntoConstraints = false
        blurEffectView.contentView.addSubview(vibrancyEffectView)
        
        // Content container
        contentContainer.isUserInteractionEnabled = false
        contentContainer.translatesAutoresizingMaskIntoConstraints = false
        vibrancyEffectView.contentView.addSubview(contentContainer)
        
        // Subtle border
        layer.cornerRadius = 12
        layer.cornerCurve = .continuous
        layer.borderWidth = 0.5
        layer.borderColor = UIColor.white.withAlphaComponent(0.25).cgColor
        
        // Glow layer for active states
        glowLayer.backgroundColor = UIColor.clear.cgColor
        glowLayer.shadowColor = liquidGlassColor.cgColor
        glowLayer.shadowOffset = .zero
        glowLayer.shadowRadius = 10
        glowLayer.shadowOpacity = 0
        glowLayer.cornerRadius = 12
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
        gradientLayer.frame = bounds
        glowLayer.frame = bounds
        
        // Move imageView to vibrancy
        if let imageView = self.imageView, imageView.superview != contentContainer {
            imageView.removeFromSuperview()
            contentContainer.addSubview(imageView)
        }
    }
    
    @objc private func touchDown() {
        UIView.animate(withDuration: 0.1, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5) {
            self.transform = CGAffineTransform(scaleX: 0.94, y: 0.94)
            self.glowLayer.shadowOpacity = 0.5
        }
        HapticFeedbackManager.shared.lightImpact()
    }
    
    @objc private func touchUp() {
        UIView.animate(withDuration: 0.2, delay: 0, usingSpringWithDamping: 0.6, initialSpringVelocity: 0.5) {
            self.transform = .identity
            self.glowLayer.shadowOpacity = 0
        }
    }
    
    private func updateAppearance() {
        // Update gradient colors
        gradientLayer.colors = [
            liquidGlassColor.withAlphaComponent(0.6).cgColor,
            liquidGlassColor.withAlphaComponent(0.3).cgColor
        ]
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
