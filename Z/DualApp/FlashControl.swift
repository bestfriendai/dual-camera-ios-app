// Dual Camera App
import UIKit
import AVFoundation

class FlashControl: UIButton {
    
    enum FlashMode {
        case off
        case on
        case auto
        
        var icon: String {
            switch self {
            case .off: return "bolt.slash.fill"
            case .on: return "bolt.fill"
            case .auto: return "bolt.badge.automatic.fill"
            }
        }
        
        var title: String {
            switch self {
            case .off: return "Off"
            case .on: return "On"
            case .auto: return "Auto"
            }
        }
        
        var next: FlashMode {
            switch self {
            case .off: return .on
            case .on: return .auto
            case .auto: return .off
            }
        }
        
        var avFlashMode: AVCaptureDevice.FlashMode {
            switch self {
            case .off: return .off
            case .on: return .on
            case .auto: return .auto
            }
        }
    }
    
    var currentMode: FlashMode = .off {
        didSet {
            updateUI()
        }
    }
    
    var onModeChanged: ((FlashMode) -> Void)?
    
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
        
        addTarget(self, action: #selector(toggleFlash), for: .touchUpInside)
        
        updateUI()
    }
    
    private func updateUI() {
        setImage(UIImage(systemName: currentMode.icon), for: .normal)
        
        switch currentMode {
        case .off:
            tintColor = .white.withAlphaComponent(0.6)
        case .on:
            tintColor = .systemYellow
        case .auto:
            tintColor = .white
        }
    }
    
    @objc private func toggleFlash() {
        currentMode = currentMode.next
        onModeChanged?(currentMode)
        
        UIView.animate(withDuration: 0.2) {
            self.transform = CGAffineTransform(scaleX: 1.2, y: 1.2)
        } completion: { _ in
            UIView.animate(withDuration: 0.2) {
                self.transform = .identity
            }
        }
    }
}
