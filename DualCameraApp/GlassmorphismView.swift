import UIKit

/// Modern glassmorphism view with frosted glass effect, blur, and depth
class GlassmorphismView: UIView {

    private let blurEffect: UIBlurEffect
    private let vibrancyEffect: UIVibrancyEffect
    private let blurView: UIVisualEffectView
    private let vibrancyView: UIVisualEffectView
    private let gradientLayer = CAGradientLayer()

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

        // Subtle shadow for depth (glassmorphism signature)
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.15
        layer.shadowOffset = CGSize(width: 0, height: 8)
        layer.shadowRadius = 16

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

    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = bounds
    }

    // MARK: - Animation Support

    /// Animate the glassmorphism effect with a subtle pulse
    func pulse() {
        UIView.animate(withDuration: 0.3, delay: 0, options: [.curveEaseInOut, .allowUserInteraction]) {
            self.transform = CGAffineTransform(scaleX: 0.98, y: 0.98)
        } completion: { _ in
            UIView.animate(withDuration: 0.3, delay: 0, options: [.curveEaseInOut, .allowUserInteraction]) {
                self.transform = .identity
            }
        }
    }

    enum BlurStyle {
        case regular
        case prominent
        case subtle
    }
}