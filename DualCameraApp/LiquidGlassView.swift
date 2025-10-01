//
//  LiquidGlassView.swift
//  DualCameraApp
//
//  True iOS 18+ Liquid Glass effect with brightness and luminosity
//

import UIKit

class LiquidGlassView: UIView {
    
    let contentView = UIView()
    private let blurEffectView = UIVisualEffectView()
    private let vibrancyEffectView = UIVisualEffectView()
    private let brightnessLayer = CALayer()
    private let glossLayer = CAGradientLayer()
    private let shineLayer = CAGradientLayer()
    
    var liquidGlassColor: UIColor = .white {
        didSet { updateLiquidGlass() }
    }
    
    var glassIntensity: CGFloat = 0.45 {
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
        
        // Base blur - thinner for more transparency
        let blurEffect = UIBlurEffect(style: .systemThinMaterial)
        blurEffectView.effect = blurEffect
        blurEffectView.layer.cornerRadius = 24
        blurEffectView.layer.cornerCurve = .continuous
        blurEffectView.clipsToBounds = true
        blurEffectView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(blurEffectView)
        
        // Vibrancy for content
        let vibrancyEffect = UIVibrancyEffect(blurEffect: blurEffect, style: .label)
        vibrancyEffectView.effect = vibrancyEffect
        vibrancyEffectView.translatesAutoresizingMaskIntoConstraints = false
        blurEffectView.contentView.addSubview(vibrancyEffectView)
        
        // Brightness layer - KEY FOR LIQUID GLASS
        brightnessLayer.backgroundColor = liquidGlassColor.withAlphaComponent(glassIntensity).cgColor
        brightnessLayer.cornerRadius = 24
        brightnessLayer.cornerCurve = .continuous
        layer.insertSublayer(brightnessLayer, at: 0)
        
        // Glossy gradient overlay for luminosity
        glossLayer.colors = [
            UIColor.white.withAlphaComponent(0.4).cgColor,
            UIColor.white.withAlphaComponent(0.1).cgColor,
            UIColor.white.withAlphaComponent(0.0).cgColor
        ]
        glossLayer.locations = [0.0, 0.3, 1.0]
        glossLayer.startPoint = CGPoint(x: 0, y: 0)
        glossLayer.endPoint = CGPoint(x: 1, y: 1)
        glossLayer.cornerRadius = 24
        glossLayer.cornerCurve = .continuous
        layer.insertSublayer(glossLayer, above: brightnessLayer)
        
        // Shine effect - top highlight
        shineLayer.colors = [
            UIColor.white.withAlphaComponent(0.6).cgColor,
            UIColor.white.withAlphaComponent(0.0).cgColor
        ]
        shineLayer.locations = [0.0, 0.3]
        shineLayer.startPoint = CGPoint(x: 0.5, y: 0)
        shineLayer.endPoint = CGPoint(x: 0.5, y: 0.3)
        shineLayer.cornerRadius = 24
        shineLayer.cornerCurve = .continuous
        layer.insertSublayer(shineLayer, above: glossLayer)
        
        // Bright border
        layer.borderWidth = 1.5
        layer.borderColor = UIColor.white.withAlphaComponent(0.5).cgColor
        layer.cornerRadius = 24
        layer.cornerCurve = .continuous
        
        // Soft shadow for depth
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOffset = CGSize(width: 0, height: 8)
        layer.shadowRadius = 20
        layer.shadowOpacity = 0.2
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
        brightnessLayer.frame = bounds
        glossLayer.frame = bounds
        shineLayer.frame = bounds
    }
    
    private func updateLiquidGlass() {
        brightnessLayer.backgroundColor = liquidGlassColor.withAlphaComponent(glassIntensity).cgColor
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
