import UIKit

class GlassmorphismView: UIView {

    private let blurEffect = UIBlurEffect(style: .light)
    private let vibrancyEffect: UIVibrancyEffect

    private let blurView: UIVisualEffectView
    private let vibrancyView: UIVisualEffectView

    // Public content view for adding subviews
    let contentView: UIView

    init() {
        self.vibrancyEffect = UIVibrancyEffect(blurEffect: blurEffect)
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

        // Glassmorphism styling
        layer.cornerRadius = 20
        layer.masksToBounds = true
        layer.borderColor = UIColor.white.withAlphaComponent(0.2).cgColor
        layer.borderWidth = 1.5

        // Add blur view
        blurView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(blurView)

        // Add vibrancy view
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
}