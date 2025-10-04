//
//  LiquidGlassView.swift
//  DualCameraApp
//
//  Legacy glass effect - Consider migrating to ModernGlassView.swift (iOS 26)
//  LOC: 284 lines (can be reduced to ~80 with ModernGlassView)
//

import UIKit
import Metal
import QuartzCore

class LiquidGlassView: UIView {
    
    let contentView = UIView()
    private let gradientLayer = CAGradientLayer()
    private let blurEffectView = UIVisualEffectView()
    private let vibrancyEffectView = UIVisualEffectView()
    
    // Metal rendering disabled - MetalGlassRenderer.swift not in project
    // private var metalRenderer: Any?
    // private var metalLayer: CAMetalLayer?
    private var useMetalRendering: Bool = false
    private weak var backdropView: UIView?
    private var cachedBounds: CGRect = .zero
    private var isAnimating: Bool = false
    
    var liquidGlassColor: UIColor = .white {
        didSet { updateLiquidGlassAppearance() }
    }
    
    var cornerRadius: CGFloat = 24.0 {
        didSet {
            layer.cornerRadius = cornerRadius
            blurEffectView.layer.cornerRadius = cornerRadius
            gradientLayer.cornerRadius = cornerRadius
            setNeedsLayout()
        }
    }
    
    init() {
        super.init(frame: .zero)
        
        // Metal rendering disabled - MetalGlassRenderer.swift not in project
        // if MTLCreateSystemDefaultDevice() != nil && !UIAccessibility.isReduceTransparencyEnabled {
        //     setupMetalRenderer()
        // }
        
        setupLiquidGlass()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // Metal rendering disabled - MetalGlassRenderer.swift not in project
    // private func updateMetalTintColor(_ color: UIColor) {
    //     if let renderer = metalRenderer as? MetalGlassRenderer {
    //         renderer.setTintColor(color)
    //     }
    // }
    // 
    // private func setupMetalRenderer() {
    //     guard let device = MTLCreateSystemDefaultDevice() else { return }
    //     
    //     metalRenderer = MetalGlassRenderer(device: device) as Any
    //     
    //     let metalLayer = CAMetalLayer()
    //     metalLayer.device = device
    //     metalLayer.pixelFormat = .bgra8Unorm
    //     metalLayer.framebufferOnly = false
    //     metalLayer.cornerRadius = cornerRadius
    //     metalLayer.cornerCurve = .continuous
    //     metalLayer.masksToBounds = true
    //     self.metalLayer = metalLayer
    //     
    //     layer.insertSublayer(metalLayer, at: 0)
    //     
    //     blurEffectView.isHidden = true
    //     gradientLayer.isHidden = true
    //     useMetalRendering = true
    //     
    //     NotificationCenter.default.addObserver(
    //         self,
    //         selector: #selector(accessibilityChanged),
    //         name: UIAccessibility.reduceTransparencyStatusDidChangeNotification,
    //         object: nil
    //     )
    // }
    
    private func setupLiquidGlass() {
        // Fallback implementation using UIVisualEffectView (used when Metal is unavailable or accessibility is enabled)
        backgroundColor = .clear
        
        gradientLayer.colors = [
            liquidGlassColor.withAlphaComponent(0.6).cgColor,
            liquidGlassColor.withAlphaComponent(0.3).cgColor,
            liquidGlassColor.withAlphaComponent(0.1).cgColor
        ]
        gradientLayer.locations = [0.0, 0.5, 1.0]
        gradientLayer.startPoint = CGPoint(x: 0, y: 0)
        gradientLayer.endPoint = CGPoint(x: 1, y: 1)
        gradientLayer.cornerCurve = .continuous
        layer.insertSublayer(gradientLayer, at: 0)
        
        let blurEffect = UIBlurEffect(style: .systemThinMaterialDark)
        blurEffectView.effect = blurEffect
        blurEffectView.layer.cornerCurve = .continuous
        blurEffectView.clipsToBounds = true
        blurEffectView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(blurEffectView)
        
        let vibrancyEffect = UIVibrancyEffect(blurEffect: blurEffect, style: .label)
        vibrancyEffectView.effect = vibrancyEffect
        vibrancyEffectView.translatesAutoresizingMaskIntoConstraints = false
        blurEffectView.contentView.addSubview(vibrancyEffectView)
        
        layer.borderWidth = 0.5
        layer.borderColor = UIColor.white.withAlphaComponent(0.3).cgColor
        layer.cornerCurve = .continuous
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOffset = CGSize(width: 0, height: 8)
        layer.shadowRadius = 24
        layer.shadowOpacity = 0.2
        layer.masksToBounds = false
        
        contentView.translatesAutoresizingMaskIntoConstraints = false
        contentView.backgroundColor = .clear
        vibrancyEffectView.contentView.addSubview(contentView)
        
        self.cornerRadius = 24.0
        
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
        guard bounds != cachedBounds else { return }
        let boundsChanged = bounds != cachedBounds
        cachedBounds = bounds
        
        if boundsChanged {
            gradientLayer.frame = bounds
        }
        
        // Metal rendering disabled
        // if boundsChanged && useMetalRendering {
        //     if let metalLayer = metalLayer {
        //         metalLayer.frame = bounds
        //         metalLayer.drawableSize = CGSize(
        //             width: bounds.width * layer.contentsScale,
        //             height: bounds.height * layer.contentsScale
        //         )
        //     }
        // }
        
        if boundsChanged {
            layer.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: cornerRadius).cgPath
        }
    }
    
    enum PerformanceLevel { case high, medium, low }
    
    func optimizeForPerformance(level: PerformanceLevel) {
        switch level {
        case .high:
            layer.shouldRasterize = false
            blurEffectView.layer.shouldRasterize = false
        case .medium:
            layer.shouldRasterize = true
            layer.rasterizationScale = UIScreen.main.scale
            blurEffectView.layer.shouldRasterize = true
            blurEffectView.layer.rasterizationScale = UIScreen.main.scale
        case .low:
            layer.shouldRasterize = true
            layer.rasterizationScale = UIScreen.main.scale * 0.75
        }
    }
    
    private func updateLiquidGlassAppearance() {
        // Metal rendering disabled
        // if useMetalRendering {
        //     updateMetalTintColor(liquidGlassColor)
        // }
        
        gradientLayer.colors = [
            liquidGlassColor.withAlphaComponent(0.6).cgColor,
            liquidGlassColor.withAlphaComponent(0.3).cgColor,
            liquidGlassColor.withAlphaComponent(0.1).cgColor
        ]
    }
    
    func pulse() {
        isAnimating = true
        layer.shouldRasterize = false
        UIView.animate(withDuration: 0.2, delay: 0, options: [.curveEaseInOut]) {
            self.transform = CGAffineTransform(scaleX: 0.98, y: 0.98)
        } completion: { _ in
            UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.6, initialSpringVelocity: 0.5) {
                self.transform = .identity
            } completion: { _ in
                self.isAnimating = false
            }
        }
    }
    
    func enableRasterization(_ enabled: Bool) {
        layer.shouldRasterize = enabled && !isAnimating && !useMetalRendering
        layer.rasterizationScale = UIScreen.main.scale
        blurEffectView.layer.shouldRasterize = enabled && !isAnimating && !useMetalRendering
        blurEffectView.layer.rasterizationScale = UIScreen.main.scale
    }
    
    // Metal rendering disabled
    // private func startMetalRendering() {
    //     guard useMetalRendering,
    //           let metalLayer = metalLayer,
    //           let superview = superview,
    //           let renderer = metalRenderer as? MetalGlassRenderer else { return }
    //     
    //     backdropView = superview
    //     renderer.startRendering(layer: metalLayer, backdropView: superview)
    // }
    // 
    // private func stopMetalRendering() {
    //     if let renderer = metalRenderer as? MetalGlassRenderer {
    //         renderer.stopRendering()
    //     }
    //     backdropView = nil
    // }
    
    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        
        // Metal rendering disabled
        // if superview != nil {
        //     startMetalRendering()
        // } else {
        //     stopMetalRendering()
        // }
    }
    
    private func updateAccessibilityMode() {
        // Metal rendering disabled
        // let shouldUseAccessibilityMode = UIAccessibility.isReduceTransparencyEnabled
        // 
        // if shouldUseAccessibilityMode && useMetalRendering {
        //     stopMetalRendering()
        //     blurEffectView.isHidden = false
        //     gradientLayer.isHidden = false
        //     metalLayer?.isHidden = true
        // } else if !shouldUseAccessibilityMode && useMetalRendering {
        //     blurEffectView.isHidden = true
        //     gradientLayer.isHidden = true
        //     metalLayer?.isHidden = false
        //     startMetalRendering()
        // }
    }
    
    @objc private func accessibilityChanged() {
        updateAccessibilityMode()
    }
    
    deinit {
        // Metal rendering disabled
        // stopMetalRendering()
        NotificationCenter.default.removeObserver(self)
    }
}
