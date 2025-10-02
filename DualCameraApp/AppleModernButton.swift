import UIKit

class AppleModernButton: UIButton {
    
    enum ButtonStyle {
        case primary
        case secondary
        case icon
        case record
    }
    
    private let style: ButtonStyle
    private var iconImageView: UIImageView?
    private let blurEffect = UIBlurEffect(style: .systemUltraThinMaterialDark)
    private lazy var blurView: UIVisualEffectView = {
        let view = UIVisualEffectView(effect: blurEffect)
        view.isUserInteractionEnabled = false
        view.layer.cornerRadius = 20
        view.clipsToBounds = true
        return view
    }()
    
    init(style: ButtonStyle) {
        self.style = style
        super.init(frame: .zero)
        setupButton()
    }
    
    required init?(coder: NSCoder) {
        self.style = .secondary
        super.init(coder: coder)
        setupButton()
    }
    
    private func setupButton() {
        switch style {
        case .primary:
            setupPrimaryStyle()
        case .secondary:
            setupSecondaryStyle()
        case .icon:
            setupIconStyle()
        case .record:
            setupRecordStyle()
        }
        
        addTarget(self, action: #selector(touchDown), for: [.touchDown, .touchDragEnter])
        addTarget(self, action: #selector(touchUp), for: [.touchUpInside, .touchUpOutside, .touchDragExit, .touchCancel])
    }
    
    private func setupPrimaryStyle() {
        backgroundColor = UIColor.white.withAlphaComponent(0.25)
        layer.cornerRadius = 20
        layer.cornerCurve = .continuous
        layer.borderWidth = 1.5
        layer.borderColor = UIColor.white.withAlphaComponent(0.4).cgColor
        tintColor = .white
        titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        setTitleColor(.white, for: .normal)
        contentEdgeInsets = UIEdgeInsets(top: 12, left: 20, bottom: 12, right: 20)
    }
    
    private func setupSecondaryStyle() {
        insertSubview(blurView, at: 0)
        blurView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            blurView.topAnchor.constraint(equalTo: topAnchor),
            blurView.leadingAnchor.constraint(equalTo: leadingAnchor),
            blurView.trailingAnchor.constraint(equalTo: trailingAnchor),
            blurView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        
        layer.cornerRadius = 20
        clipsToBounds = true
        tintColor = .white
        titleLabel?.font = .systemFont(ofSize: 15, weight: .medium)
        setTitleColor(.white, for: .normal)
        contentEdgeInsets = UIEdgeInsets(top: 10, left: 16, bottom: 10, right: 16)
    }
    
    private func setupIconStyle() {
        insertSubview(blurView, at: 0)
        blurView.translatesAutoresizingMaskIntoConstraints = false
        blurView.layer.cornerRadius = 20
        blurView.layer.cornerCurve = .continuous
        NSLayoutConstraint.activate([
            blurView.topAnchor.constraint(equalTo: topAnchor),
            blurView.leadingAnchor.constraint(equalTo: leadingAnchor),
            blurView.trailingAnchor.constraint(equalTo: trailingAnchor),
            blurView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        
        layer.cornerRadius = 20
        layer.cornerCurve = .continuous
        layer.borderWidth = 1.5
        layer.borderColor = UIColor.white.withAlphaComponent(0.3).cgColor
        clipsToBounds = true
        tintColor = .white
        
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: 40),
            heightAnchor.constraint(equalToConstant: 40)
        ])
    }
    
    private func setupRecordStyle() {
        layer.cornerRadius = 35
        backgroundColor = .clear
        layer.borderWidth = 4
        layer.borderColor = UIColor.white.cgColor
        
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: 70),
            heightAnchor.constraint(equalToConstant: 70)
        ])
    }
    
    @objc private func touchDown() {
        UIView.animate(withDuration: 0.1, delay: 0, options: [.curveEaseOut, .allowUserInteraction], animations: {
            self.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
            self.alpha = 0.8
        })
    }
    
    @objc private func touchUp() {
        UIView.animate(withDuration: 0.2, delay: 0, options: [.curveEaseOut, .allowUserInteraction], animations: {
            self.transform = .identity
            self.alpha = 1.0
        })
    }
    
    func setRecording(_ recording: Bool) {
        guard style == .record else { return }
        
        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.6, initialSpringVelocity: 0, options: [.curveEaseInOut], animations: {
            if recording {
                self.layer.borderColor = UIColor.systemRed.cgColor
                self.backgroundColor = UIColor.systemRed
                self.transform = CGAffineTransform(scaleX: 0.6, y: 0.6)
                self.layer.cornerRadius = 8
            } else {
                self.layer.borderColor = UIColor.white.cgColor
                self.backgroundColor = .clear
                self.transform = .identity
                self.layer.cornerRadius = 35
            }
        })
    }
}
