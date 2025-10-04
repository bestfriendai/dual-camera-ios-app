// Dual Camera App
// Legacy glassmorphism - Consider migrating to ModernGlassView.swift (iOS 26)
// LOC: 280 lines (can be reduced to ~80 with ModernGlassView)
import UIKit
import Metal
import QuartzCore

/// Modern glassmorphism view with frosted glass effect, blur, and depth
class GlassmorphismView: UIView {

    private let blurEffect: UIBlurEffect
    private let vibrancyEffect: UIVibrancyEffect
    private let blurView: UIVisualEffectView
    private let vibrancyView: UIVisualEffectView
    private let gradientLayer = CAGradientLayer()
    // Metal rendering disabled - MetalGlassRenderer.swift not in project
    // private var metalRenderer: MetalGlassRenderer?
    // private var metalLayer: CAMetalLayer?
    private var useMetalRendering: Bool = false
    private var cachedBounds: CGRect = .zero
    private var cachedShadowPath: CGPath?
    private var isAnimating: Bool = false

    // Public content view for adding subviews
    let contentView: UIView

    init(style: BlurStyle = .regular) {
        // Use modern iOS materials for best glassmorphism effect
        if #available(iOS 13.0, *) {
            switch style {
            case .regular:
                self.blurEffect = UIBlurEffect(style: .systemUltraThinMaterial)
            case .prominent:
                self.blurEffect = UIBlurEffect(style: .systemThinMaterial)
            case .subtle:
                self.blurEffect = UIBlurEffect(style: .systemUltraThinMaterialLight)
            }
        } else {
            self.blurEffect = UIBlurEffect(style: .light)
        }

        self.vibrancyEffect = UIVibrancyEffect(blurEffect: blurEffect, style: .label)
        self.blurView = UIVisualEffectView(effect: blurEffect)
        self.vibrancyView = UIVisualEffectView(effect: vibrancyEffect)
        self.contentView = UIView()

        super.init(frame: .zero)
        setupViews()
        
        // Metal rendering disabled
        // if MetalGlassRenderer.isMetalRenderingAvailable() {
        //     setupMetalRendering()
        // }
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(accessibilityChanged),
            name: UIAccessibility.reduceTransparencyStatusDidChangeNotification,
            object: nil
        )
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        backgroundColor = .clear

        // Glassmorphism styling with rounded corners
        layer.cornerRadius = 24
        layer.cornerCurve = .continuous

        // Don't clip to bounds for shadow
        layer.masksToBounds = false
        clipsToBounds = true

        // Enhanced multi-layer border effect
        layer.borderColor = UIColor.white.withAlphaComponent(0.25).cgColor
        layer.borderWidth = 1.5

        // Add gradient overlay for enhanced glass effect
        gradientLayer.colors = [
            UIColor.white.withAlphaComponent(0.15).cgColor,
            UIColor.white.withAlphaComponent(0.05).cgColor
        ]
        gradientLayer.locations = [0.0, 1.0]
        gradientLayer.startPoint = CGPoint(x: 0, y: 0)
        gradientLayer.endPoint = CGPoint(x: 1, y: 1)
        layer.insertSublayer(gradientLayer, at: 0)

        // Add blur view
        blurView.translatesAutoresizingMaskIntoConstraints = false
        blurView.layer.cornerRadius = 24
        blurView.layer.cornerCurve = .continuous
        blurView.clipsToBounds = true
        addSubview(blurView)

        // Add vibrancy view for enhanced text/icon rendering
        vibrancyView.translatesAutoresizingMaskIntoConstraints = false
        blurView.contentView.addSubview(vibrancyView)

        // Add content view on top
        contentView.translatesAutoresizingMaskIntoConstraints = false
        contentView.backgroundColor = .clear
        vibrancyView.contentView.addSubview(contentView)

        // Setup constraints
        NSLayoutConstraint.activate([
            blurView.topAnchor.constraint(equalTo: topAnchor),
            blurView.leadingAnchor.constraint(equalTo: leadingAnchor),
            blurView.trailingAnchor.constraint(equalTo: trailingAnchor),
            blurView.bottomAnchor.constraint(equalTo: bottomAnchor),

            vibrancyView.topAnchor.constraint(equalTo: blurView.contentView.topAnchor),
            vibrancyView.leadingAnchor.constraint(equalTo: blurView.contentView.leadingAnchor),
            vibrancyView.trailingAnchor.constraint(equalTo: blurView.contentView.trailingAnchor),
            vibrancyView.bottomAnchor.constraint(equalTo: blurView.contentView.bottomAnchor),

            contentView.topAnchor.constraint(equalTo: vibrancyView.contentView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: vibrancyView.contentView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: vibrancyView.contentView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: vibrancyView.contentView.bottomAnchor)
        ])
    }

    private func updateShadowPath() {
        let cornerRadius: CGFloat = 24
        let shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: cornerRadius).cgPath
        
        if cachedShadowPath == nil || bounds != cachedBounds {
            layer.shadowColor = UIColor.black.cgColor
            layer.shadowOpacity = 0.15
            layer.shadowOffset = CGSize(width: 0, height: 8)
            layer.shadowRadius = 16
            layer.shadowPath = shadowPath
            cachedShadowPath = shadowPath
        }
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
        //             width: bounds.width * UIScreen.main.scale,
        //             height: bounds.height * UIScreen.main.scale
        //         )
        //     }
        // }
        
        updateShadowPath()
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

    // MARK: - Metal Rendering (Disabled - MetalGlassRenderer.swift not in project)
    
    // private func setupMetalRendering() {
    //     guard let device = MTLCreateSystemDefaultDevice() else { return }
    //     
    //     metalRenderer = MetalGlassRenderer(device: device)
    //     
    //     let layer = CAMetalLayer()
    //     layer.device = device
    //     layer.pixelFormat = .bgra8Unorm
    //     layer.framebufferOnly = false
    //     layer.frame = bounds
    //     layer.drawableSize = CGSize(
    //         width: bounds.width * UIScreen.main.scale,
    //         height: bounds.height * UIScreen.main.scale
    //     )
    //     
    //     self.layer.insertSublayer(layer, at: 0)
    //     self.metalLayer = layer
    //     
    //     blurView.isHidden = true
    //     useMetalRendering = true
    // }
    // 
    // private func startMetalRendering() {
    //     guard let metalLayer = metalLayer,
    //           let metalRenderer = metalRenderer,
    //           let backdropView = superview else { return }
    //     metalRenderer.startRendering(layer: metalLayer, backdropView: backdropView)
    // }
    // 
    // private func stopMetalRendering() {
    //     metalRenderer?.stopRendering()
    // }
    
    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        
        // Metal rendering disabled
        // if useMetalRendering {
        //     if superview != nil {
        //         startMetalRendering()
        //     } else {
        //         stopMetalRendering()
        //     }
        // }
    }
    
    @objc private func accessibilityChanged() {
        updateRenderingMode()
    }
    
    private func updateRenderingMode() {
        // Metal rendering disabled
        // if UIAccessibility.isReduceTransparencyEnabled {
        //     if useMetalRendering {
        //         stopMetalRendering()
        //         metalLayer?.isHidden = true
        //         blurView.isHidden = false
        //     }
        // } else {
        //     if useMetalRendering {
        //         metalLayer?.isHidden = false
        //         blurView.isHidden = true
        //         startMetalRendering()
        //     }
        // }
    }
    
    // MARK: - Animation Support

    /// Animate the glassmorphism effect with a subtle pulse
    func pulse() {
        isAnimating = true
        layer.shouldRasterize = false
        UIView.animate(withDuration: 0.3, delay: 0, options: [.curveEaseInOut, .allowUserInteraction]) {
            self.transform = CGAffineTransform(scaleX: 0.98, y: 0.98)
        } completion: { _ in
            UIView.animate(withDuration: 0.3, delay: 0, options: [.curveEaseInOut, .allowUserInteraction]) {
                self.transform = .identity
            } completion: { _ in
                self.isAnimating = false
            }
        }
    }

    func enableRasterization(_ enabled: Bool) {
        layer.shouldRasterize = enabled && !isAnimating
        layer.rasterizationScale = UIScreen.main.scale
    }
    
    deinit {
        // Metal rendering disabled
        // stopMetalRendering()
        NotificationCenter.default.removeObserver(self)
    }

    enum BlurStyle {
        case regular
        case prominent
        case subtle
    }
}