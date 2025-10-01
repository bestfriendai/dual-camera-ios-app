//
//  AppleCameraButton.swift
//  DualCameraApp
//
//  Clean, minimal button like Apple's Camera app
//

import UIKit

class AppleCameraButton: UIButton {
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupAppleStyle()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupAppleStyle()
    }
    
    private func setupAppleStyle() {
        // Apple's style: Clean white icon, no background
        tintColor = .white
        backgroundColor = .clear
        
        // Modern SF Symbol configuration
        let config = UIImage.SymbolConfiguration(pointSize: 22, weight: .medium, scale: .large)
        setPreferredSymbolConfiguration(config, forImageIn: .normal)
        
        // Subtle shadow for depth
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOffset = CGSize(width: 0, height: 1)
        layer.shadowRadius = 3
        layer.shadowOpacity = 0.3
        
        // Touch feedback
        addTarget(self, action: #selector(touchDown), for: .touchDown)
        addTarget(self, action: #selector(touchUp), for: [.touchUpInside, .touchUpOutside, .touchCancel])
    }
    
    @objc private func touchDown() {
        UIView.animate(withDuration: 0.1) {
            self.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
            self.alpha = 0.6
        }
        HapticFeedbackManager.shared.lightImpact()
    }
    
    @objc private func touchUp() {
        UIView.animate(withDuration: 0.15, delay: 0, usingSpringWithDamping: 0.5, initialSpringVelocity: 0.5) {
            self.transform = .identity
            self.alpha = 1.0
        }
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
        // Apple's record button: Simple white circle
        backgroundColor = .white
        layer.cornerRadius = 35 // Will be 70x70
        
        // Shadow for depth
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOffset = CGSize(width: 0, height: 3)
        layer.shadowRadius = 10
        layer.shadowOpacity = 0.3
        
        // Touch feedback
        addTarget(self, action: #selector(touchDown), for: .touchDown)
        addTarget(self, action: #selector(touchUp), for: [.touchUpInside, .touchUpOutside, .touchCancel])
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
        UIView.animate(withDuration: 0.1) {
            self.transform = CGAffineTransform(scaleX: 0.85, y: 0.85)
        }
        HapticFeedbackManager.shared.mediumImpact()
    }
    
    @objc private func touchUp() {
        UIView.animate(withDuration: 0.2, delay: 0, usingSpringWithDamping: 0.6, initialSpringVelocity: 0.5) {
            if self.isRecording {
                self.transform = CGAffineTransform(scaleX: 0.6, y: 0.6)
            } else {
                self.transform = .identity
            }
        }
    }
}
