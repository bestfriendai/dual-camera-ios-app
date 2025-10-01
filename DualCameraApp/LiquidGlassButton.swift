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
        // NO solid background - pure material
        backgroundColor = .clear
        
        // systemChromeMaterial for buttons - this is the key!
        let blurEffect = UIBlurEffect(style: .systemChromeMaterial)
        blurEffectView.effect = blurEffect
        blurEffectView.layer.cornerRadius = 12
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
        
        // systemChromeMaterial provides natural saturation and shine
        // No additional filters needed - let the material work its magic
        
        // Minimal border - let material shine
        layer.cornerRadius = 12
        layer.cornerCurve = .continuous
        layer.borderWidth = 0.5
        layer.borderColor = UIColor.white.withAlphaComponent(0.15).cgColor
        
        // Glow layer for active states
        glowLayer.backgroundColor = UIColor.clear.cgColor
        glowLayer.shadowColor = UIColor.white.cgColor
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
            self.glowLayer.shadowOpacity = 0.4
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
        // Material adapts automatically
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
