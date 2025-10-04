// Dual Camera App
import UIKit

class TimerControl: UIButton {
    
    enum TimerDuration: Int {
        case off = 0
        case three = 3
        case ten = 10
        
        var icon: String {
            switch self {
            case .off: return "timer"
            case .three: return "timer"
            case .ten: return "timer"
            }
        }
        
        var title: String {
            switch self {
            case .off: return "Off"
            case .three: return "3s"
            case .ten: return "10s"
            }
        }
        
        var next: TimerDuration {
            switch self {
            case .off: return .three
            case .three: return .ten
            case .ten: return .off
            }
        }
    }
    
    var currentDuration: TimerDuration = .off {
        didSet {
            updateUI()
        }
    }
    
    var onDurationChanged: ((TimerDuration) -> Void)?
    
    private let durationLabel = UILabel()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
    
    private func setupUI() {
        let blurEffect = UIBlurEffect(style: .systemUltraThinMaterialDark)
        let blurView = UIVisualEffectView(effect: blurEffect)
        blurView.isUserInteractionEnabled = false
        blurView.layer.cornerRadius = 20
        blurView.clipsToBounds = true
        blurView.translatesAutoresizingMaskIntoConstraints = false
        
        insertSubview(blurView, at: 0)
        
        NSLayoutConstraint.activate([
            blurView.topAnchor.constraint(equalTo: topAnchor),
            blurView.leadingAnchor.constraint(equalTo: leadingAnchor),
            blurView.trailingAnchor.constraint(equalTo: trailingAnchor),
            blurView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        
        layer.cornerRadius = 20
        clipsToBounds = true
        
        let config = UIImage.SymbolConfiguration(pointSize: 20, weight: .medium)
        setPreferredSymbolConfiguration(config, forImageIn: .normal)
        
        tintColor = .white
        
        durationLabel.font = .systemFont(ofSize: 10, weight: .bold)
        durationLabel.textColor = .white
        durationLabel.textAlignment = .center
        durationLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(durationLabel)
        
        NSLayoutConstraint.activate([
            durationLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            durationLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -2)
        ])
        
        addTarget(self, action: #selector(toggleTimer), for: .touchUpInside)
        
        updateUI()
    }
    
    private func updateUI() {
        setImage(UIImage(systemName: currentDuration.icon), for: .normal)
        
        switch currentDuration {
        case .off:
            tintColor = .white.withAlphaComponent(0.6)
            durationLabel.alpha = 0
        case .three, .ten:
            tintColor = .systemYellow
            durationLabel.text = currentDuration.title
            durationLabel.alpha = 1
        }
    }
    
    @objc private func toggleTimer() {
        currentDuration = currentDuration.next
        onDurationChanged?(currentDuration)
        
        UIView.animate(withDuration: 0.2) {
            self.transform = CGAffineTransform(scaleX: 1.2, y: 1.2)
        } completion: { _ in
            UIView.animate(withDuration: 0.2) {
                self.transform = .identity
            }
        }
    }
}
