//
//  MinimalRecordingInterface.swift
//  DualCameraApp
//
//  Minimal recording interface with clean, distraction-free experience
//

import UIKit

/// Minimal recording interface with clean, distraction-free experience
class MinimalRecordingInterface: UIView {
    
    // MARK: - Properties
    
    private var isVisible = false
    private var isRecording = false
    private var isPaused = false
    private var recordingDuration: TimeInterval = 0
    
    // UI Components
    private let backgroundView = UIView()
    private let recordingIndicator = UIView()
    private let recordingTimeLabel = UILabel()
    private let recordButton = UIButton(type: .system)
    private let pauseButton = UIButton(type: .system)
    private let stopButton = UIButton(type: .system)
    private let exitButton = UIButton(type: .system)
    private let controlsContainer = UIView()
    
    // Material views
    private let backgroundMaterial = EnhancedGlassmorphismView(
        material: .ultraThin,
        vibrancy: .primary,
        adaptiveBlur: true,
        depthEffect: false
    )
    
    private let controlsMaterial = EnhancedGlassmorphismView(
        material: .systemThickMaterial,
        vibrancy: .primary,
        adaptiveBlur: true,
        depthEffect: true
    )
    
    // Animation properties
    private var recordingTimer: Timer?
    private var pulseAnimation: CABasicAnimation?
    
    // Callbacks
    var onRecordButtonTapped: (() -> Void)?
    var onPauseButtonTapped: (() -> Void)?
    var onStopButtonTapped: (() -> Void)?
    var onExitButtonTapped: (() -> Void)?
    
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
        backgroundColor = .clear
        isHidden = true
        alpha = 0
        
        setupBackground()
        setupRecordingIndicator()
        setupRecordingTimeLabel()
        setupButtons()
        setupControlsContainer()
        setupConstraints()
    }
    
    private func setupBackground() {
        backgroundView.translatesAutoresizingMaskIntoConstraints = false
        backgroundView.backgroundColor = UIColor.black.withAlphaComponent(0.3)
        addSubview(backgroundView)
        
        backgroundMaterial.translatesAutoresizingMaskIntoConstraints = false
        backgroundMaterial.contentView.addSubview(backgroundView)
        addSubview(backgroundMaterial)
    }
    
    private func setupRecordingIndicator() {
        recordingIndicator.backgroundColor = EnhancedColorSystem.DynamicColor.recordingActive.color
        recordingIndicator.layer.cornerRadius = 6
        recordingIndicator.translatesAutoresizingMaskIntoConstraints = false
        recordingIndicator.alpha = 0
        
        addSubview(recordingIndicator)
        
        // Setup pulse animation
        setupPulseAnimation()
    }
    
    private func setupPulseAnimation() {
        pulseAnimation = CABasicAnimation(keyPath: "transform.scale")
        pulseAnimation?.fromValue = 1.0
        pulseAnimation?.toValue = 1.3
        pulseAnimation?.duration = 1.0
        pulseAnimation?.timingFunction = CAMediaTimingFunction(name: .easeOut)
        pulseAnimation?.autoreverses = true
        pulseAnimation?.repeatCount = .infinity
    }
    
    private func setupRecordingTimeLabel() {
        recordingTimeLabel.font = DesignSystem.Typography.title3.font
        recordingTimeLabel.textColor = EnhancedColorSystem.DynamicColor.onBackground.color
        recordingTimeLabel.textAlignment = .center
        recordingTimeLabel.text = "00:00"
        recordingTimeLabel.translatesAutoresizingMaskIntoConstraints = false
        recordingTimeLabel.alpha = 0
        
        addSubview(recordingTimeLabel)
    }
    
    private func setupButtons() {
        // Record button
        recordButton.setImage(UIImage(systemName: "record.circle.fill"), for: .normal)
        recordButton.tintColor = EnhancedColorSystem.DynamicColor.recordingActive.color
        recordButton.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        recordButton.layer.cornerRadius = 32
        recordButton.layer.cornerCurve = .continuous
        recordButton.translatesAutoresizingMaskIntoConstraints = false
        recordButton.addTarget(self, action: #selector(recordButtonTapped), for: .touchUpInside)
        
        // Pause button
        pauseButton.setImage(UIImage(systemName: "pause.circle.fill"), for: .normal)
        pauseButton.tintColor = EnhancedColorSystem.DynamicColor.warning.color
        pauseButton.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        pauseButton.layer.cornerRadius = 32
        pauseButton.layer.cornerCurve = .continuous
        pauseButton.translatesAutoresizingMaskIntoConstraints = false
        pauseButton.addTarget(self, action: #selector(pauseButtonTapped), for: .touchUpInside)
        pauseButton.isHidden = true
        
        // Stop button
        stopButton.setImage(UIImage(systemName: "stop.circle.fill"), for: .normal)
        stopButton.tintColor = EnhancedColorSystem.DynamicColor.error.color
        stopButton.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        stopButton.layer.cornerRadius = 32
        stopButton.layer.cornerCurve = .continuous
        stopButton.translatesAutoresizingMaskIntoConstraints = false
        stopButton.addTarget(self, action: #selector(stopButtonTapped), for: .touchUpInside)
        stopButton.isHidden = true
        
        // Exit button
        exitButton.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        exitButton.tintColor = EnhancedColorSystem.DynamicColor.onBackground.color
        exitButton.backgroundColor = UIColor.black.withAlphaComponent(0.3)
        exitButton.layer.cornerRadius = 20
        exitButton.layer.cornerCurve = .continuous
        exitButton.translatesAutoresizingMaskIntoConstraints = false
        exitButton.addTarget(self, action: #selector(exitButtonTapped), for: .touchUpInside)
        
        // Add buttons to controls container
        controlsContainer.addSubview(recordButton)
        controlsContainer.addSubview(pauseButton)
        controlsContainer.addSubview(stopButton)
        controlsContainer.addSubview(exitButton)
    }
    
    private func setupControlsContainer() {
        controlsMaterial.translatesAutoresizingMaskIntoConstraints = false
        controlsMaterial.layer.cornerRadius = 40
        controlsMaterial.layer.cornerCurve = .continuous
        controlsMaterial.contentView.addSubview(controlsContainer)
        addSubview(controlsMaterial)
        
        controlsContainer.translatesAutoresizingMaskIntoConstraints = false
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // Background material
            backgroundMaterial.topAnchor.constraint(equalTo: topAnchor),
            backgroundMaterial.leadingAnchor.constraint(equalTo: leadingAnchor),
            backgroundMaterial.trailingAnchor.constraint(equalTo: trailingAnchor),
            backgroundMaterial.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            // Background view
            backgroundView.topAnchor.constraint(equalTo: backgroundMaterial.contentView.topAnchor),
            backgroundView.leadingAnchor.constraint(equalTo: backgroundMaterial.contentView.leadingAnchor),
            backgroundView.trailingAnchor.constraint(equalTo: backgroundMaterial.contentView.trailingAnchor),
            backgroundView.bottomAnchor.constraint(equalTo: backgroundMaterial.contentView.bottomAnchor),
            
            // Recording indicator
            recordingIndicator.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: DesignSystem.Spacing.xl.value),
            recordingIndicator.centerXAnchor.constraint(equalTo: centerXAnchor),
            recordingIndicator.widthAnchor.constraint(equalToConstant: 12),
            recordingIndicator.heightAnchor.constraint(equalToConstant: 12),
            
            // Recording time label
            recordingTimeLabel.topAnchor.constraint(equalTo: recordingIndicator.bottomAnchor, constant: DesignSystem.Spacing.sm.value),
            recordingTimeLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            
            // Controls material
            controlsMaterial.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: -DesignSystem.Spacing.xl.value),
            controlsMaterial.centerXAnchor.constraint(equalTo: centerXAnchor),
            controlsMaterial.widthAnchor.constraint(equalToConstant: 200),
            controlsMaterial.heightAnchor.constraint(equalToConstant: 80),
            
            // Controls container
            controlsContainer.topAnchor.constraint(equalTo: controlsMaterial.contentView.topAnchor),
            controlsContainer.leadingAnchor.constraint(equalTo: controlsMaterial.contentView.leadingAnchor),
            controlsContainer.trailingAnchor.constraint(equalTo: controlsMaterial.contentView.trailingAnchor),
            controlsContainer.bottomAnchor.constraint(equalTo: controlsMaterial.contentView.bottomAnchor),
            
            // Record button
            recordButton.centerXAnchor.constraint(equalTo: controlsContainer.centerXAnchor),
            recordButton.centerYAnchor.constraint(equalTo: controlsContainer.centerYAnchor),
            recordButton.widthAnchor.constraint(equalToConstant: 64),
            recordButton.heightAnchor.constraint(equalToConstant: 64),
            
            // Pause button
            pauseButton.centerXAnchor.constraint(equalTo: controlsContainer.centerXAnchor),
            pauseButton.centerYAnchor.constraint(equalTo: controlsContainer.centerYAnchor),
            pauseButton.widthAnchor.constraint(equalToConstant: 64),
            pauseButton.heightAnchor.constraint(equalToConstant: 64),
            
            // Stop button
            stopButton.centerXAnchor.constraint(equalTo: controlsContainer.centerXAnchor),
            stopButton.centerYAnchor.constraint(equalTo: controlsContainer.centerYAnchor),
            stopButton.widthAnchor.constraint(equalToConstant: 64),
            stopButton.heightAnchor.constraint(equalToConstant: 64),
            
            // Exit button
            exitButton.topAnchor.constraint(equalTo: controlsContainer.topAnchor, constant: DesignSystem.Spacing.sm.value),
            exitButton.trailingAnchor.constraint(equalTo: controlsContainer.trailingAnchor, constant: -DesignSystem.Spacing.sm.value),
            exitButton.widthAnchor.constraint(equalToConstant: 40),
            exitButton.heightAnchor.constraint(equalToConstant: 40)
        ])
    }
    
    // MARK: - Public Methods
    
    /// Shows the minimal recording interface
    func show(animated: Bool = true) {
        guard !isVisible else { return }
        
        isVisible = true
        
        let showAnimation = {
            self.alpha = 1
        }
        
        if animated {
            UIView.animate(withDuration: 0.3, delay: 0, options: [.curveEaseOut]) {
                showAnimation()
            }
        } else {
            showAnimation()
        }
    }
    
    /// Hides the minimal recording interface
    func hide(animated: Bool = true) {
        guard isVisible else { return }
        
        isVisible = false
        
        let hideAnimation = {
            self.alpha = 0
        }
        
        if animated {
            UIView.animate(withDuration: 0.3, delay: 0, options: [.curveEaseIn]) {
                hideAnimation()
            } completion: { _ in
                self.isHidden = true
            }
        } else {
            hideAnimation()
            isHidden = true
        }
    }
    
    /// Updates the interface for recording state
    func updateForRecordingState(_ isRecording: Bool) {
        self.isRecording = isRecording
        
        if isRecording {
            startRecordingUI()
        } else {
            stopRecordingUI()
        }
    }
    
    /// Updates the interface for paused state
    func updateForPausedState(_ isPaused: Bool) {
        self.isPaused = isPaused
        
        if isPaused {
            pauseRecordingUI()
        } else {
            resumeRecordingUI()
        }
    }
    
    /// Updates the recording duration display
    func updateRecordingDuration(_ duration: TimeInterval) {
        recordingDuration = duration
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        recordingTimeLabel.text = String(format: "%02d:%02d", minutes, seconds)
    }
    
    // MARK: - UI State Updates
    
    private func startRecordingUI() {
        // Show recording indicator with animation
        UIView.animate(withDuration: 0.3) {
            self.recordingIndicator.alpha = 1
            self.recordingTimeLabel.alpha = 1
        }
        
        // Add pulse animation to recording indicator
        if let pulseAnimation = pulseAnimation {
            recordingIndicator.layer.add(pulseAnimation, forKey: "pulse")
        }
        
        // Update buttons
        recordButton.isHidden = true
        pauseButton.isHidden = false
        stopButton.isHidden = false
        
        // Start recording timer
        startRecordingTimer()
        
        // Update background material
        backgroundMaterial.updateMaterialStyle(.ultraThin)
        
        // Haptic feedback
        HapticFeedbackManager.shared.recordingStart()
    }
    
    private func stopRecordingUI() {
        // Hide recording indicator with animation
        UIView.animate(withDuration: 0.3) {
            self.recordingIndicator.alpha = 0
            self.recordingTimeLabel.alpha = 0
        }
        
        // Remove pulse animation
        recordingIndicator.layer.removeAnimation(forKey: "pulse")
        
        // Update buttons
        recordButton.isHidden = false
        pauseButton.isHidden = true
        stopButton.isHidden = true
        
        // Stop recording timer
        stopRecordingTimer()
        
        // Reset recording duration
        recordingDuration = 0
        updateRecordingDuration(0)
        
        // Update background material
        backgroundMaterial.updateMaterialStyle(.ultraThin)
        
        // Haptic feedback
        HapticFeedbackManager.shared.recordingStop()
    }
    
    private func pauseRecordingUI() {
        // Update recording indicator
        recordingIndicator.backgroundColor = EnhancedColorSystem.DynamicColor.warning.color
        
        // Update buttons
        pauseButton.isHidden = true
        recordButton.isHidden = false
        recordButton.setImage(UIImage(systemName: "play.circle.fill"), for: .normal)
        recordButton.tintColor = EnhancedColorSystem.DynamicColor.success.color
        
        // Stop recording timer
        stopRecordingTimer()
        
        // Haptic feedback
        HapticFeedbackManager.shared.mediumImpact()
    }
    
    private func resumeRecordingUI() {
        // Update recording indicator
        recordingIndicator.backgroundColor = EnhancedColorSystem.DynamicColor.recordingActive.color
        
        // Update buttons
        recordButton.isHidden = true
        pauseButton.isHidden = false
        recordButton.setImage(UIImage(systemName: "record.circle.fill"), for: .normal)
        recordButton.tintColor = EnhancedColorSystem.DynamicColor.recordingActive.color
        
        // Start recording timer
        startRecordingTimer()
        
        // Haptic feedback
        HapticFeedbackManager.shared.mediumImpact()
    }
    
    // MARK: - Recording Timer
    
    private func startRecordingTimer() {
        stopRecordingTimer()
        
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.recordingDuration += 0.1
            self.updateRecordingDuration(self.recordingDuration)
        }
    }
    
    private func stopRecordingTimer() {
        recordingTimer?.invalidate()
        recordingTimer = nil
    }
    
    // MARK: - Button Actions
    
    @objc private func recordButtonTapped() {
        if isRecording {
            if isPaused {
                // Resume recording
                onRecordButtonTapped?()
            } else {
                // Pause recording
                onPauseButtonTapped?()
            }
        } else {
            // Start recording
            onRecordButtonTapped?()
        }
        
        // Haptic feedback
        HapticFeedbackManager.shared.mediumImpact()
    }
    
    @objc private func pauseButtonTapped() {
        onPauseButtonTapped?()
        
        // Haptic feedback
        HapticFeedbackManager.shared.mediumImpact()
    }
    
    @objc private func stopButtonTapped() {
        onStopButtonTapped?()
        
        // Haptic feedback
        HapticFeedbackManager.shared.heavyImpact()
    }
    
    @objc private func exitButtonTapped() {
        onExitButtonTapped?()
        
        // Haptic feedback
        HapticFeedbackManager.shared.lightImpact()
    }
    
    // MARK: - Touch Handling
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        
        // Provide subtle haptic feedback on touch
        HapticFeedbackManager.shared.lightImpact()
    }
    
    // MARK: - Accessibility
    
    override var isAccessibilityElement: Bool {
        get { return true }
        set { }
    }
    
    override var accessibilityLabel: String? {
        get {
            if isRecording {
                return isPaused ? "Recording paused" : "Recording in progress"
            } else {
                return "Minimal recording interface"
            }
        }
        set { }
    }
    
    override var accessibilityValue: String? {
        get {
            let minutes = Int(recordingDuration) / 60
            let seconds = Int(recordingDuration) % 60
            return String(format: "%02d:%02d", minutes, seconds)
        }
        set { }
    }
    
    override var accessibilityTraits: UIAccessibilityTraits {
        get {
            if isRecording {
                return .updatesFrequently
            } else {
                return .button
            }
        }
        set { }
    }
    
    override func accessibilityActivate() -> Bool {
        if isRecording {
            if isPaused {
                recordButtonTapped()
            } else {
                pauseButtonTapped()
            }
        } else {
            recordButtonTapped()
        }
        return true
    }
}