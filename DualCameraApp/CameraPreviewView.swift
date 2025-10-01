//
//  CameraPreviewView.swift
//  DualCameraApp
//
//  Enhanced camera preview view with glassmorphism and visual feedback
//

import UIKit
import AVFoundation

class CameraPreviewView: UIView {
    
    // MARK: - Properties
    
    var previewLayer: AVCaptureVideoPreviewLayer? {
        didSet {
            setupPreviewLayer()
        }
    }
    
    private let titleLabel = UILabel()
    private let statusIndicator = UIView()
    private let focusIndicator = UIView()
    private let loadingIndicator = UIActivityIndicatorView(style: .large)
    private let placeholderLabel = UILabel()
    
    var title: String = "" {
        didSet {
            titleLabel.text = title
        }
    }
    
    var isActive: Bool = false {
        didSet {
            updateStatusIndicator()
        }
    }
    
    // MARK: - Initialization
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    // MARK: - Setup
    
    private func setupView() {
        backgroundColor = UIColor(white: 0.1, alpha: 1.0)
        layer.cornerRadius = 20
        layer.cornerCurve = .continuous
        layer.masksToBounds = true
        
        // Add subtle border
        layer.borderWidth = 2
        layer.borderColor = UIColor.white.withAlphaComponent(0.2).cgColor
        
        // Setup title label
        titleLabel.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        titleLabel.textColor = .white
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        titleLabel.layer.cornerRadius = 8
        titleLabel.layer.masksToBounds = true
        titleLabel.layer.borderWidth = 1
        titleLabel.layer.borderColor = UIColor.white.withAlphaComponent(0.3).cgColor
        addSubview(titleLabel)
        
        // Setup status indicator
        statusIndicator.translatesAutoresizingMaskIntoConstraints = false
        statusIndicator.backgroundColor = .systemGray
        statusIndicator.layer.cornerRadius = 6
        statusIndicator.layer.borderWidth = 2
        statusIndicator.layer.borderColor = UIColor.white.cgColor
        addSubview(statusIndicator)
        
        // Setup focus indicator
        focusIndicator.translatesAutoresizingMaskIntoConstraints = false
        focusIndicator.layer.borderWidth = 2
        focusIndicator.layer.borderColor = UIColor.systemYellow.cgColor
        focusIndicator.layer.cornerRadius = 4
        focusIndicator.alpha = 0
        addSubview(focusIndicator)
        
        // Setup loading indicator
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        loadingIndicator.color = .white
        loadingIndicator.hidesWhenStopped = true
        addSubview(loadingIndicator)
        
        // Setup placeholder
        placeholderLabel.translatesAutoresizingMaskIntoConstraints = false
        placeholderLabel.text = "Camera Initializing..."
        placeholderLabel.textColor = .white
        placeholderLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        placeholderLabel.textAlignment = .center
        placeholderLabel.numberOfLines = 0
        addSubview(placeholderLabel)
        
        // Constraints
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            titleLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            titleLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 100),
            titleLabel.heightAnchor.constraint(equalToConstant: 28),
            
            statusIndicator.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            statusIndicator.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            statusIndicator.widthAnchor.constraint(equalToConstant: 12),
            statusIndicator.heightAnchor.constraint(equalToConstant: 12),
            
            focusIndicator.widthAnchor.constraint(equalToConstant: 80),
            focusIndicator.heightAnchor.constraint(equalToConstant: 80),
            
            loadingIndicator.centerXAnchor.constraint(equalTo: centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: centerYAnchor),
            
            placeholderLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            placeholderLabel.centerYAnchor.constraint(equalTo: centerYAnchor, constant: 40),
            placeholderLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            placeholderLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20)
        ])
        
        loadingIndicator.startAnimating()
    }
    
    private func setupPreviewLayer() {
        guard let previewLayer = previewLayer else { return }
        
        // Remove old preview layer if exists
        layer.sublayers?.first(where: { $0 is AVCaptureVideoPreviewLayer })?.removeFromSuperlayer()
        
        // Configure preview layer
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = bounds
        
        // Insert at bottom so UI elements are on top
        layer.insertSublayer(previewLayer, at: 0)
        
        // Hide placeholder and loading
        placeholderLabel.isHidden = true
        loadingIndicator.stopAnimating()
        
        // Animate border to indicate active
        animateBorderActivation()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer?.frame = bounds
    }
    
    // MARK: - Visual Feedback
    
    private func updateStatusIndicator() {
        UIView.animate(withDuration: 0.3) {
            self.statusIndicator.backgroundColor = self.isActive ? .systemGreen : .systemGray
        }
    }
    
    func showFocusIndicator(at point: CGPoint) {
        focusIndicator.center = point
        
        UIView.animate(withDuration: 0.2, animations: {
            self.focusIndicator.alpha = 1.0
            self.focusIndicator.transform = CGAffineTransform(scaleX: 1.2, y: 1.2)
        }) { _ in
            UIView.animate(withDuration: 0.2, delay: 0.5, animations: {
                self.focusIndicator.alpha = 0
                self.focusIndicator.transform = .identity
            })
        }
    }
    
    func animateBorderActivation() {
        let animation = CABasicAnimation(keyPath: "borderColor")
        animation.fromValue = UIColor.white.withAlphaComponent(0.2).cgColor
        animation.toValue = UIColor.systemBlue.withAlphaComponent(0.6).cgColor
        animation.duration = 0.5
        animation.autoreverses = true
        layer.add(animation, forKey: "borderColorAnimation")
    }
    
    func showError(message: String) {
        placeholderLabel.text = "⚠️ " + message
        placeholderLabel.isHidden = false
        loadingIndicator.stopAnimating()
        
        layer.borderColor = UIColor.systemRed.withAlphaComponent(0.6).cgColor
    }
    
    func showLoading(message: String = "Initializing...") {
        placeholderLabel.text = message
        placeholderLabel.isHidden = false
        loadingIndicator.startAnimating()
    }
    
    // MARK: - Recording Indicator
    
    func startRecordingAnimation() {
        // Pulse border during recording
        let pulseAnimation = CABasicAnimation(keyPath: "borderColor")
        pulseAnimation.fromValue = UIColor.systemRed.withAlphaComponent(0.8).cgColor
        pulseAnimation.toValue = UIColor.systemRed.withAlphaComponent(0.3).cgColor
        pulseAnimation.duration = 1.0
        pulseAnimation.autoreverses = true
        pulseAnimation.repeatCount = .infinity
        layer.add(pulseAnimation, forKey: "recordingPulse")
        
        statusIndicator.backgroundColor = .systemRed
    }
    
    func stopRecordingAnimation() {
        layer.removeAnimation(forKey: "recordingPulse")
        layer.borderColor = UIColor.white.withAlphaComponent(0.2).cgColor
        statusIndicator.backgroundColor = .systemGreen
    }
    
    // MARK: - Performance Management
    
    func clearCache() {
        // Clear any cached images or resources
        layer.sublayers?.forEach { layer in
            if layer is AVCaptureVideoPreviewLayer {
                // Don't remove preview layer, but clear any caches
                layer.contents = nil
            }
        }
        
        // Reset any image caches
        if let previewLayer = previewLayer {
            previewLayer.connection?.automaticallyAdjustsVideoMirroring = false
            previewLayer.connection?.automaticallyAdjustsVideoMirroring = true
        }
    }
    
    func reducePerformanceForMemoryPressure() {
        // Reduce visual effects temporarily
        layer.removeAllAnimations()
        statusIndicator.layer.removeAllAnimations()
        
        // Reduce border complexity
        layer.borderWidth = 1
        layer.borderColor = UIColor.white.withAlphaComponent(0.1).cgColor
        
        // Hide non-essential UI elements
        focusIndicator.alpha = 0
    }
    
    func restorePerformanceAfterMemoryPressure() {
        // Restore visual effects
        layer.borderWidth = 2
        layer.borderColor = UIColor.white.withAlphaComponent(0.2).cgColor
        
        // Restore status indicator
        updateStatusIndicator()
    }
}

