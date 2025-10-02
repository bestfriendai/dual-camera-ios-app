import UIKit
import AVFoundation

class CameraPreviewView: UIView {
    
    var previewLayer: AVCaptureVideoPreviewLayer? {
        didSet {
            setupPreviewLayer()
        }
    }
    
    private let headerContainer = UIView()
    private let titleLabel = UILabel()
    private let statusIndicator = UIView()
    private let statusPulseLayer = CAShapeLayer()
    private let focusIndicator = UIView()
    private let loadingIndicator = UIActivityIndicatorView(style: .large)
    private let placeholderLabel = UILabel()
    private let glassFrameView = LiquidGlassView()
    private let metricsLabel = UILabel()
    
    private var displayLink: CADisplayLink?
    private var frameCount = 0
    private var lastFPSUpdate = CACurrentMediaTime()
    private var currentFPS: Int = 0
    
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
    
    var showPerformanceMetrics: Bool = false {
        didSet {
            metricsLabel.isHidden = !showPerformanceMetrics
        }
    }
    
    private var isFullySetup = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupMinimalView()
        // Defer heavy setup to avoid blocking app launch
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupMinimalView()
        // Defer heavy setup to avoid blocking app launch
    }

    private func setupMinimalView() {
        // Only essential setup for initial display
        backgroundColor = UIColor(white: 0.05, alpha: 1.0)
        layer.cornerRadius = 24
        layer.cornerCurve = .continuous
        layer.masksToBounds = true
        layer.borderWidth = 0.5
        layer.borderColor = UIColor.white.withAlphaComponent(0.1).cgColor
    }

    func completeSetup() {
        guard !isFullySetup else { return }
        isFullySetup = true

        setupView()
        startFPSMonitoring()
    }
    
    deinit {
        stopFPSMonitoring()
    }
    
    private func setupView() {
        backgroundColor = UIColor(white: 0.05, alpha: 1.0)
        layer.cornerRadius = 24
        layer.cornerCurve = .continuous
        layer.masksToBounds = true
        
        setupGlassFrame()
        setupHeader()
        setupFocusIndicator()
        setupLoadingState()
        setupMetricsDisplay()
        
        layer.borderWidth = 0.5
        layer.borderColor = UIColor.white.withAlphaComponent(0.1).cgColor
    }
    
    private func setupGlassFrame() {
        glassFrameView.translatesAutoresizingMaskIntoConstraints = false
        glassFrameView.liquidGlassColor = .systemBlue
        glassFrameView.alpha = 0
        addSubview(glassFrameView)
        
        NSLayoutConstraint.activate([
            glassFrameView.topAnchor.constraint(equalTo: topAnchor),
            glassFrameView.leadingAnchor.constraint(equalTo: leadingAnchor),
            glassFrameView.trailingAnchor.constraint(equalTo: trailingAnchor),
            glassFrameView.heightAnchor.constraint(equalToConstant: 4)
        ])
    }
    
    private func setupHeader() {
        headerContainer.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        headerContainer.translatesAutoresizingMaskIntoConstraints = false
        addSubview(headerContainer)
        
        titleLabel.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
        titleLabel.textColor = .white
        titleLabel.textAlignment = .left
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        headerContainer.addSubview(titleLabel)
        
        statusIndicator.translatesAutoresizingMaskIntoConstraints = false
        statusIndicator.backgroundColor = .systemGray
        statusIndicator.layer.cornerRadius = 4
        headerContainer.addSubview(statusIndicator)
        
        statusPulseLayer.fillColor = UIColor.clear.cgColor
        statusPulseLayer.strokeColor = UIColor.systemGreen.cgColor
        statusPulseLayer.lineWidth = 2
        statusPulseLayer.opacity = 0
        statusIndicator.layer.addSublayer(statusPulseLayer)
        
        NSLayoutConstraint.activate([
            headerContainer.topAnchor.constraint(equalTo: topAnchor),
            headerContainer.leadingAnchor.constraint(equalTo: leadingAnchor),
            headerContainer.trailingAnchor.constraint(equalTo: trailingAnchor),
            headerContainer.heightAnchor.constraint(equalToConstant: 36),
            
            titleLabel.leadingAnchor.constraint(equalTo: headerContainer.leadingAnchor, constant: 12),
            titleLabel.centerYAnchor.constraint(equalTo: headerContainer.centerYAnchor),
            
            statusIndicator.trailingAnchor.constraint(equalTo: headerContainer.trailingAnchor, constant: -12),
            statusIndicator.centerYAnchor.constraint(equalTo: headerContainer.centerYAnchor),
            statusIndicator.widthAnchor.constraint(equalToConstant: 8),
            statusIndicator.heightAnchor.constraint(equalToConstant: 8)
        ])
    }
    
    private func setupFocusIndicator() {
        focusIndicator.translatesAutoresizingMaskIntoConstraints = false
        focusIndicator.layer.borderWidth = 2
        focusIndicator.layer.borderColor = UIColor.systemYellow.cgColor
        focusIndicator.layer.cornerRadius = 4
        focusIndicator.layer.shadowColor = UIColor.black.cgColor
        focusIndicator.layer.shadowOffset = CGSize(width: 0, height: 2)
        focusIndicator.layer.shadowRadius = 4
        focusIndicator.layer.shadowOpacity = 0.3
        focusIndicator.alpha = 0
        addSubview(focusIndicator)
        
        NSLayoutConstraint.activate([
            focusIndicator.widthAnchor.constraint(equalToConstant: 80),
            focusIndicator.heightAnchor.constraint(equalToConstant: 80)
        ])
    }
    
    private func setupLoadingState() {
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        loadingIndicator.color = .white
        loadingIndicator.hidesWhenStopped = true
        addSubview(loadingIndicator)
        
        placeholderLabel.translatesAutoresizingMaskIntoConstraints = false
        placeholderLabel.text = "Initializing Camera..."
        placeholderLabel.textColor = .white.withAlphaComponent(0.8)
        placeholderLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        placeholderLabel.textAlignment = .center
        placeholderLabel.numberOfLines = 0
        addSubview(placeholderLabel)
        
        NSLayoutConstraint.activate([
            loadingIndicator.centerXAnchor.constraint(equalTo: centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -20),
            
            placeholderLabel.topAnchor.constraint(equalTo: loadingIndicator.bottomAnchor, constant: 16),
            placeholderLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            placeholderLabel.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 20),
            placeholderLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -20)
        ])
        
        loadingIndicator.startAnimating()
    }
    
    private func setupMetricsDisplay() {
        metricsLabel.translatesAutoresizingMaskIntoConstraints = false
        metricsLabel.font = UIFont.monospacedSystemFont(ofSize: 11, weight: .medium)
        metricsLabel.textColor = UIColor.systemGreen
        metricsLabel.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        metricsLabel.layer.cornerRadius = 6
        metricsLabel.layer.masksToBounds = true
        metricsLabel.textAlignment = .center
        metricsLabel.isHidden = true
        addSubview(metricsLabel)
        
        NSLayoutConstraint.activate([
            metricsLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),
            metricsLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            metricsLabel.heightAnchor.constraint(equalToConstant: 24),
            metricsLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 80)
        ])
    }
    
    private func setupPreviewLayer() {
        guard let previewLayer = previewLayer else { return }
        
        layer.sublayers?.first(where: { $0 is AVCaptureVideoPreviewLayer })?.removeFromSuperlayer()
        
        previewLayer.videoGravity = .resizeAspectFill
        
        if let connection = previewLayer.connection, connection.isVideoOrientationSupported {
            connection.videoOrientation = .portrait
        }
        
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layer.insertSublayer(previewLayer, at: 0)
        previewLayer.frame = bounds
        CATransaction.commit()
        
        setNeedsLayout()
        layoutIfNeeded()
        
        DispatchQueue.main.async {
            self.setNeedsLayout()
            self.layoutIfNeeded()
        }
        
        placeholderLabel.isHidden = true
        loadingIndicator.stopAnimating()
        
        animatePreviewActivation()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        if let previewLayer = previewLayer {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            previewLayer.frame = bounds
            
            if let connection = previewLayer.connection, connection.isVideoOrientationSupported {
                let orientation: AVCaptureVideoOrientation
                if #available(iOS 13.0, *) {
                    let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene
                    switch windowScene?.interfaceOrientation {
                    case .portrait:
                        orientation = .portrait
                    case .portraitUpsideDown:
                        orientation = .portraitUpsideDown
                    case .landscapeLeft:
                        orientation = .landscapeLeft
                    case .landscapeRight:
                        orientation = .landscapeRight
                    default:
                        orientation = .portrait
                    }
                } else {
                    orientation = .portrait
                }
                connection.videoOrientation = orientation
            }
            
            CATransaction.commit()
        }
        
        let statusPath = UIBezierPath(
            arcCenter: CGPoint(x: 4, y: 4),
            radius: 6,
            startAngle: 0,
            endAngle: .pi * 2,
            clockwise: true
        )
        statusPulseLayer.path = statusPath.cgPath
    }
    
    private func startFPSMonitoring() {
        displayLink = CADisplayLink(target: self, selector: #selector(updateFPS))
        displayLink?.preferredFrameRateRange = CAFrameRateRange(minimum: 60, maximum: 120, preferred: 60)
        displayLink?.add(to: .main, forMode: .common)
    }
    
    private func stopFPSMonitoring() {
        displayLink?.invalidate()
        displayLink = nil
    }
    
    @objc private func updateFPS() {
        frameCount += 1
        let currentTime = CACurrentMediaTime()
        let elapsed = currentTime - lastFPSUpdate
        
        if elapsed >= 1.0 {
            currentFPS = Int(Double(frameCount) / elapsed)
            frameCount = 0
            lastFPSUpdate = currentTime
            
            if showPerformanceMetrics {
                metricsLabel.text = "\(currentFPS) FPS"
                
                if currentFPS >= 55 {
                    metricsLabel.textColor = .systemGreen
                } else if currentFPS >= 30 {
                    metricsLabel.textColor = .systemYellow
                } else {
                    metricsLabel.textColor = .systemRed
                }
            }
        }
    }
    
    private func updateStatusIndicator() {
        UIView.animate(withDuration: 0.3, delay: 0, options: [.curveEaseInOut]) {
            self.statusIndicator.backgroundColor = self.isActive ? .systemGreen : .systemGray
        }
        
        if isActive {
            let pulseAnimation = CABasicAnimation(keyPath: "opacity")
            pulseAnimation.fromValue = 0.8
            pulseAnimation.toValue = 0
            pulseAnimation.duration = 1.5
            pulseAnimation.repeatCount = .infinity
            pulseAnimation.timingFunction = CAMediaTimingFunction(name: .easeOut)
            
            let scaleAnimation = CABasicAnimation(keyPath: "transform.scale")
            scaleAnimation.fromValue = 1.0
            scaleAnimation.toValue = 2.0
            scaleAnimation.duration = 1.5
            scaleAnimation.repeatCount = .infinity
            scaleAnimation.timingFunction = CAMediaTimingFunction(name: .easeOut)
            
            statusPulseLayer.add(pulseAnimation, forKey: "pulse")
            statusPulseLayer.add(scaleAnimation, forKey: "scale")
        } else {
            statusPulseLayer.removeAllAnimations()
        }
    }
    
    func showFocusIndicator(at point: CGPoint) {
        focusIndicator.center = point
        
        UIView.animate(withDuration: 0.15, delay: 0, options: [.curveEaseOut]) {
            self.focusIndicator.alpha = 1.0
            self.focusIndicator.transform = CGAffineTransform(scaleX: 1.3, y: 1.3)
        } completion: { _ in
            UIView.animate(withDuration: 0.2, delay: 0, options: [.curveEaseInOut]) {
                self.focusIndicator.transform = .identity
            } completion: { _ in
                UIView.animate(withDuration: 0.3, delay: 0.5, options: [.curveEaseIn]) {
                    self.focusIndicator.alpha = 0
                }
            }
        }
        
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
    
    private func animatePreviewActivation() {
        glassFrameView.alpha = 1.0
        
        let shimmerAnimation = CABasicAnimation(keyPath: "opacity")
        shimmerAnimation.fromValue = 1.0
        shimmerAnimation.toValue = 0.0
        shimmerAnimation.duration = 1.0
        shimmerAnimation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        shimmerAnimation.fillMode = .forwards
        shimmerAnimation.isRemovedOnCompletion = false
        
        glassFrameView.layer.add(shimmerAnimation, forKey: "activation")
        
        UIView.animate(withDuration: 0.5, delay: 0.8, options: [.curveEaseOut]) {
            self.glassFrameView.alpha = 0
        }
    }
    
    func startRecordingAnimation() {
        layer.borderWidth = 2
        layer.borderColor = UIColor.systemRed.withAlphaComponent(0.8).cgColor
        
        let pulseAnimation = CABasicAnimation(keyPath: "borderColor")
        pulseAnimation.fromValue = UIColor.systemRed.withAlphaComponent(0.9).cgColor
        pulseAnimation.toValue = UIColor.systemRed.withAlphaComponent(0.3).cgColor
        pulseAnimation.duration = 1.0
        pulseAnimation.autoreverses = true
        pulseAnimation.repeatCount = .infinity
        pulseAnimation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        layer.add(pulseAnimation, forKey: "recordingPulse")
        
        statusIndicator.backgroundColor = .systemRed
        
        glassFrameView.liquidGlassColor = .systemRed
        UIView.animate(withDuration: 0.3) {
            self.glassFrameView.alpha = 0.6
        }
    }
    
    func stopRecordingAnimation() {
        layer.removeAnimation(forKey: "recordingPulse")
        
        UIView.animate(withDuration: 0.3, delay: 0, options: [.curveEaseInOut]) {
            self.layer.borderWidth = 0.5
            self.layer.borderColor = UIColor.white.withAlphaComponent(0.1).cgColor
            self.glassFrameView.alpha = 0
        }
        
        if isActive {
            statusIndicator.backgroundColor = .systemGreen
        } else {
            statusIndicator.backgroundColor = .systemGray
        }
    }
    
    func showError(message: String) {
        placeholderLabel.text = "⚠️ " + message
        placeholderLabel.textColor = .systemRed
        placeholderLabel.isHidden = false
        loadingIndicator.stopAnimating()
        
        layer.borderWidth = 2
        layer.borderColor = UIColor.systemRed.withAlphaComponent(0.6).cgColor
        
        glassFrameView.liquidGlassColor = .systemRed
        UIView.animate(withDuration: 0.3) {
            self.glassFrameView.alpha = 0.8
        }
    }
    
    func showLoading(message: String = "Initializing...") {
        placeholderLabel.text = message
        placeholderLabel.textColor = .white.withAlphaComponent(0.8)
        placeholderLabel.isHidden = false
        loadingIndicator.startAnimating()
    }
    
    func hideLoading() {
        placeholderLabel.isHidden = true
        loadingIndicator.stopAnimating()
    }
    
    func clearCache() {
        layer.sublayers?.forEach { layer in
            if layer is AVCaptureVideoPreviewLayer {
                layer.contents = nil
            }
        }
    }
    
    func optimizeForPerformance(level: PerformanceLevel) {
        switch level {
        case .high:
            layer.shouldRasterize = false
            displayLink?.preferredFrameRateRange = CAFrameRateRange(minimum: 60, maximum: 120, preferred: 60)
            
        case .medium:
            layer.shouldRasterize = true
            layer.rasterizationScale = UIScreen.main.scale * 0.8
            displayLink?.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 60, preferred: 60)
            
        case .low:
            layer.shouldRasterize = true
            layer.rasterizationScale = UIScreen.main.scale * 0.5
            displayLink?.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 30, preferred: 30)
            layer.removeAllAnimations()
            statusPulseLayer.removeAllAnimations()
        }
    }
    
    func reducePerformanceForMemoryPressure() {
        layer.removeAllAnimations()
        statusPulseLayer.removeAllAnimations()
        
        layer.borderWidth = 0.5
        layer.borderColor = UIColor.white.withAlphaComponent(0.05).cgColor
        
        focusIndicator.alpha = 0
        
        displayLink?.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 30, preferred: 30)
        
        layer.shouldRasterize = true
        layer.rasterizationScale = UIScreen.main.scale * 0.5
    }
    
    func restorePerformanceAfterMemoryPressure() {
        layer.borderWidth = 0.5
        layer.borderColor = UIColor.white.withAlphaComponent(0.1).cgColor
        
        displayLink?.preferredFrameRateRange = CAFrameRateRange(minimum: 60, maximum: 120, preferred: 60)
        
        layer.shouldRasterize = false
        
        updateStatusIndicator()
    }
    
    enum PerformanceLevel {
        case high
        case medium
        case low
    }
}
