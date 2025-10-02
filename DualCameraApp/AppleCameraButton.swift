//
//  AppleCameraButton.swift
//  DualCameraApp
//
//  Clean, minimal button like Apple's Camera app
//

import UIKit

class AppleCameraButton: UIButton {
    
    convenience init() {
        self.init(frame: .zero)
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupAppleStyle()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupAppleStyle()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        if let imageView = self.imageView {
            imageView.tintColor = .white
            imageView.isUserInteractionEnabled = false
            bringSubviewToFront(imageView)
        }
        if let titleLabel = self.titleLabel {
            titleLabel.textColor = .white
            titleLabel.isUserInteractionEnabled = false
            bringSubviewToFront(titleLabel)
        }
        
        // Ensure button can receive touches
        self.isUserInteractionEnabled = true
    }
    
    private func setupAppleStyle() {
        backgroundColor = .clear
        imageView?.contentMode = .center
        
        let blurEffect = UIBlurEffect(style: .systemUltraThinMaterialDark)
        let blurView = UIVisualEffectView(effect: blurEffect)
        blurView.isUserInteractionEnabled = false
        blurView.layer.cornerRadius = 20
        blurView.layer.cornerCurve = .continuous
        blurView.clipsToBounds = true
        blurView.translatesAutoresizingMaskIntoConstraints = false
        blurView.tag = 9999
        
        if viewWithTag(9999) == nil {
            insertSubview(blurView, at: 0)
        }
        
        NSLayoutConstraint.activate([
            blurView.topAnchor.constraint(equalTo: topAnchor),
            blurView.leadingAnchor.constraint(equalTo: leadingAnchor),
            blurView.trailingAnchor.constraint(equalTo: trailingAnchor),
            blurView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        
        layer.cornerRadius = 20
        layer.cornerCurve = .continuous
        clipsToBounds = false
        
        tintColor = .white
        setTitleColor(.white, for: .normal)
        
        if let imageView = self.imageView {
            imageView.tintColor = .white
        }
        if let titleLabel = self.titleLabel {
            titleLabel.textColor = .white
            titleLabel.font = UIFont.systemFont(ofSize: 15, weight: .semibold)
        }
        
        let config = UIImage.SymbolConfiguration(pointSize: 20, weight: .medium, scale: .medium)
        setPreferredSymbolConfiguration(config, forImageIn: .normal)
        
        isUserInteractionEnabled = true
        
        addTarget(self, action: #selector(touchDown), for: [.touchDown, .touchDragEnter])
        addTarget(self, action: #selector(touchUp), for: [.touchUpInside, .touchUpOutside, .touchCancel, .touchDragExit])
    }
    
    @objc private func touchDown() {
        UIView.animate(withDuration: 0.1, delay: 0, options: [.beginFromCurrentState, .allowUserInteraction], animations: {
            self.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
        }, completion: nil)
        HapticFeedbackManager.shared.lightImpact()
    }
    
    @objc private func touchUp() {
        UIView.animate(withDuration: 0.15, delay: 0, options: [.beginFromCurrentState, .allowUserInteraction, .curveEaseOut], animations: {
            self.transform = .identity
        }, completion: nil)
    }
}

class AppleRecordButton: UIButton {
    
    private var isRecording = false
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupRecordButton()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupRecordButton()
    }
    
    private func setupRecordButton() {
        backgroundColor = .white
        layer.cornerRadius = 35
        layer.cornerCurve = .continuous
        clipsToBounds = false
        
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOffset = CGSize(width: 0, height: 4)
        layer.shadowRadius = 12
        layer.shadowOpacity = 0.4
        
        layer.borderWidth = 3
        layer.borderColor = UIColor.white.withAlphaComponent(0.3).cgColor
        
        isUserInteractionEnabled = true
        
        addTarget(self, action: #selector(touchDown), for: [.touchDown, .touchDragEnter])
        addTarget(self, action: #selector(touchUp), for: [.touchUpInside, .touchUpOutside, .touchCancel, .touchDragExit])
    }
    
    func setRecording(_ recording: Bool, animated: Bool = true) {
        isRecording = recording
        
        let changes = {
            if recording {
                // Red square for recording
                self.backgroundColor = .systemRed
                self.layer.cornerRadius = 10
                self.transform = CGAffineTransform(scaleX: 0.6, y: 0.6)
            } else {
                // White circle for ready
                self.backgroundColor = .white
                self.layer.cornerRadius = 35
                self.transform = .identity
            }
        }
        
        if animated {
            UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.5, animations: changes)
        } else {
            changes()
        }
    }
    
    @objc private func touchDown() {
        UIView.animate(withDuration: 0.1, delay: 0, options: [.beginFromCurrentState, .allowUserInteraction], animations: {
            self.transform = CGAffineTransform(scaleX: 0.85, y: 0.85)
        })
        HapticFeedbackManager.shared.mediumImpact()
    }
    
    @objc private func touchUp() {
        UIView.animate(withDuration: 0.2, delay: 0, options: [.beginFromCurrentState, .allowUserInteraction, .curveEaseOut], animations: {
            if self.isRecording {
                self.transform = CGAffineTransform(scaleX: 0.6, y: 0.6)
            } else {
                self.transform = .identity
            }
        })
    }
}
