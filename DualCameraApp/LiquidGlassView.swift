//
//  LiquidGlassView.swift
//  DualCameraApp
//
//  True iOS 18+ Liquid Glass effect with brightness and luminosity
//

import UIKit

class LiquidGlassView: UIView {
    
    let contentView = UIView()
    private let gradientLayer = CAGradientLayer()  // KEY: Gradient BEHIND blur
    private let blurEffectView = UIVisualEffectView()
    private let vibrancyEffectView = UIVisualEffectView()
    
    var liquidGlassColor: UIColor = .white {
        didSet { updateLiquidGlass() }
    }
    
    init() {
        super.init(frame: .zero)
        setupLiquidGlass()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupLiquidGlass()
    }
    
    private func setupLiquidGlass() {
        backgroundColor = .clear
        
        // STEP 1: Gradient BEHIND everything (this is the KEY!)
        gradientLayer.colors = [
            liquidGlassColor.withAlphaComponent(0.7).cgColor,
            liquidGlassColor.withAlphaComponent(0.4).cgColor,
            liquidGlassColor.withAlphaComponent(0.2).cgColor
        ]
        gradientLayer.locations = [0.0, 0.5, 1.0]
        gradientLayer.startPoint = CGPoint(x: 0, y: 0)
        gradientLayer.endPoint = CGPoint(x: 1, y: 1)
        gradientLayer.cornerRadius = 20
        gradientLayer.cornerCurve = .continuous
        layer.insertSublayer(gradientLayer, at: 0)  // BEHIND everything!
        
        // STEP 2: Thin material on top (lets gradient show through)
        let blurEffect = UIBlurEffect(style: .systemThinMaterial)
        blurEffectView.effect = blurEffect
        blurEffectView.layer.cornerRadius = 20
        blurEffectView.layer.cornerCurve = .continuous
        blurEffectView.clipsToBounds = true
        blurEffectView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(blurEffectView)
        
        // STEP 3: Vibrancy for content
        let vibrancyEffect = UIVibrancyEffect(blurEffect: blurEffect, style: .label)
        vibrancyEffectView.effect = vibrancyEffect
        vibrancyEffectView.translatesAutoresizingMaskIntoConstraints = false
        blurEffectView.contentView.addSubview(vibrancyEffectView)
        
        // Subtle border
        layer.borderWidth = 0.5
        layer.borderColor = UIColor.white.withAlphaComponent(0.3).cgColor
        layer.cornerRadius = 20
        layer.cornerCurve = .continuous
        
        // Soft shadow for depth
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOffset = CGSize(width: 0, height: 4)
        layer.shadowRadius = 16
        layer.shadowOpacity = 0.15
        layer.masksToBounds = false
        
        // Content view setup
        contentView.translatesAutoresizingMaskIntoConstraints = false
        contentView.backgroundColor = .clear
        vibrancyEffectView.contentView.addSubview(contentView)
        
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
            
            contentView.topAnchor.constraint(equalTo: vibrancyEffectView.contentView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: vibrancyEffectView.contentView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: vibrancyEffectView.contentView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: vibrancyEffectView.contentView.bottomAnchor)
        ])
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = bounds
    }
    
    private func updateLiquidGlass() {
        // Update gradient colors
        gradientLayer.colors = [
            liquidGlassColor.withAlphaComponent(0.7).cgColor,
            liquidGlassColor.withAlphaComponent(0.4).cgColor,
            liquidGlassColor.withAlphaComponent(0.2).cgColor
        ]
    }
    
    func pulse() {
        UIView.animate(withDuration: 0.2, delay: 0, options: [.curveEaseInOut]) {
            self.transform = CGAffineTransform(scaleX: 0.98, y: 0.98)
        } completion: { _ in
            UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.6, initialSpringVelocity: 0.5) {
                self.transform = .identity
            }
        }
    }
}
