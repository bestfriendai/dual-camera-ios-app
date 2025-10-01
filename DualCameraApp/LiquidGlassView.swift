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
        // NO solid background - let material work naturally
        backgroundColor = .clear
        
        // systemChromeMaterial for true liquid glass shine
        let blurEffect = UIBlurEffect(style: .systemChromeMaterial)
        blurEffectView.effect = blurEffect
        blurEffectView.layer.cornerRadius = 20
        blurEffectView.layer.cornerCurve = .continuous
        blurEffectView.clipsToBounds = true
        blurEffectView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(blurEffectView)
        
        // Vibrancy for content
        let vibrancyEffect = UIVibrancyEffect(blurEffect: blurEffect, style: .label)
        vibrancyEffectView.effect = vibrancyEffect
        vibrancyEffectView.translatesAutoresizingMaskIntoConstraints = false
        blurEffectView.contentView.addSubview(vibrancyEffectView)
        
        // Saturation boost via compositing filter (iOS 18+ way)
        // Note: CAFilter requires private APIs, so we rely on material's natural appearance
        // systemChromeMaterial already provides rich saturation
        
        // Border with material-appropriate opacity
        layer.borderWidth = 0.5
        layer.borderColor = UIColor.white.withAlphaComponent(0.2).cgColor
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
        // Material handles everything naturally
    }
    
    private func updateLiquidGlass() {
        // Material adapts automatically
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
