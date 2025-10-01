//
//  ModernGlassButton.swift
//  DualCameraApp
//
//  Modern iOS 18+ glassmorphism button with liquid glass effect
//

import UIKit

class ModernGlassButton: UIButton {
    
    private let blurEffectView = UIVisualEffectView()
    private let vibrancyEffectView = UIVisualEffectView()
    private let contentContainer = UIView()
    private let glowLayer = CALayer()
    
    var glassColor: UIColor = UIColor.white.withAlphaComponent(0.15) {
        didSet { updateAppearance() }
    }
    
    var borderColor: UIColor = UIColor.white.withAlphaComponent(0.2) {
        didSet { updateAppearance() }
    }
    
    var glowColor: UIColor = UIColor.white.withAlphaComponent(0.3) {
        didSet { updateAppearance() }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupGlassEffect()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupGlassEffect()
    }
    
    private func setupGlassEffect() {
        // Ultra-thin material blur
        let blurEffect = UIBlurEffect(style: .systemUltraThinMaterial)
        blurEffectView.effect = blurEffect
        blurEffectView.layer.cornerRadius = 12
        blurEffectView.layer.cornerCurve = .continuous
        blurEffectView.clipsToBounds = true
        blurEffectView.isUserInteractionEnabled = false
        blurEffectView.translatesAutoresizingMaskIntoConstraints = false
        insertSubview(blurEffectView, at: 0)
        
        // Vibrancy effect for content
        let vibrancyEffect = UIVibrancyEffect(blurEffect: blurEffect, style: .label)
        vibrancyEffectView.effect = vibrancyEffect
        vibrancyEffectView.isUserInteractionEnabled = false
        vibrancyEffectView.translatesAutoresizingMaskIntoConstraints = false
        blurEffectView.contentView.addSubview(vibrancyEffectView)
        
        // Content container
        contentContainer.isUserInteractionEnabled = false
        contentContainer.translatesAutoresizingMaskIntoConstraints = false
        vibrancyEffectView.contentView.addSubview(contentContainer)
        
        // Move image view to vibrancy container
        if let imageView = self.imageView {
            imageView.removeFromSuperview()
            contentContainer.addSubview(imageView)
        }
        
        // Border and glass tint
        layer.cornerRadius = 12
        layer.cornerCurve = .continuous
        layer.borderWidth = 1
        layer.borderColor = borderColor.cgColor
        backgroundColor = glassColor
        
        // Glow layer
        glowLayer.backgroundColor = UIColor.clear.cgColor
        glowLayer.shadowColor = glowColor.cgColor
        glowLayer.shadowOffset = .zero
        glowLayer.shadowRadius = 8
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
        glowLayer.frame = bounds
        
        // Ensure imageView is in vibrancy container
        if let imageView = self.imageView, imageView.superview != contentContainer {
            imageView.removeFromSuperview()
            contentContainer.addSubview(imageView)
        }
    }
    
    @objc private func touchDown() {
        // Spring animation on touch
        UIView.animate(withDuration: 0.15, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.5) {
            self.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
            self.glowLayer.shadowOpacity = 0.5
        }
        
        // Haptic feedback
        HapticFeedbackManager.shared.lightImpact()
    }
    
    @objc private func touchUp() {
        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.6, initialSpringVelocity: 0.5) {
            self.transform = .identity
            self.glowLayer.shadowOpacity = 0
        }
    }
    
    private func updateAppearance() {
        backgroundColor = glassColor
        layer.borderColor = borderColor.cgColor
        glowLayer.shadowColor = glowColor.cgColor
    }
    
    func setGlowEnabled(_ enabled: Bool, animated: Bool = true) {
        let opacity: Float = enabled ? 0.6 : 0
        
        if animated {
            UIView.animate(withDuration: 0.3) {
                self.glowLayer.shadowOpacity = opacity
            }
        } else {
            glowLayer.shadowOpacity = opacity
        }
    }
}
