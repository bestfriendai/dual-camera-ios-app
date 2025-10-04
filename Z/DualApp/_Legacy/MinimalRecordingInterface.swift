//
//  MinimalRecordingInterface.swift
//  DualCameraApp
//
//  Minimal recording interface with clean, distraction-free experience
//

import UIKit

class MinimalRecordingInterface: UIView {
    
    enum RecordingPhase {
        case idle
        case countingDown(remaining: Int)
        case recording
        case paused
    }
    
    // MARK: - Properties
    
    private(set) var phase: RecordingPhase = .idle {
        didSet { updateUIForPhase() }
    }
    
    private var recordingDuration: TimeInterval = 0
    
    // UI Components
    private let backgroundView = LiquidGlassView()
    private let recordingIndicator = UIView()
    private let recordingTimeLabel = UILabel()
    private let recordButton = ModernLiquidGlassButton()
    private let pauseButton = ModernLiquidGlassButton()
    private let stopButton = ModernLiquidGlassButton()
    private let exitButton = ModernLiquidGlassButton()
    private let controlsStack = UIStackView()
    
    // Animation properties
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
        alpha = 0
        
        backgroundView.translatesAutoresizingMaskIntoConstraints = false
        backgroundView.backgroundColor = UIColor.black.withAlphaComponent(0.3)
        addSubview(backgroundView)
        
        setupRecordingIndicator()
        setupRecordingTimeLabel()
        setupButtons()
        setupControlsContainer()
        setupConstraints()
    }
    
    private func setupRecordingIndicator() {
        recordingIndicator.backgroundColor = LiquidDesignSystem.DesignTokens.Colors.recording
        recordingIndicator.layer.cornerRadius = 6
        recordingIndicator.translatesAutoresizingMaskIntoConstraints = false
        recordingIndicator.alpha = 0
        
        addSubview(recordingIndicator)
        
        pulseAnimation = CABasicAnimation(keyPath: "transform.scale")
        pulseAnimation?.fromValue = 1.0
        pulseAnimation?.toValue = 1.3
        pulseAnimation?.duration = 1.0
        pulseAnimation?.timingFunction = CAMediaTimingFunction(name: .easeOut)
        pulseAnimation?.autoreverses = true
        pulseAnimation?.repeatCount = .infinity
    }
    
    private func setupRecordingTimeLabel() {
        recordingTimeLabel.font = LiquidDesignSystem.DesignTokens.Typography.title
        recordingTimeLabel.textColor = .white
        recordingTimeLabel.textAlignment = .center
        recordingTimeLabel.text = "00:00"
        recordingTimeLabel.translatesAutoresizingMaskIntoConstraints = false
        recordingTimeLabel.alpha = 0
        recordingTimeLabel.adjustsFontForContentSizeCategory = true
        recordingTimeLabel.isAccessibilityElement = true
        recordingTimeLabel.accessibilityTraits = .updatesFrequently
        
        addSubview(recordingTimeLabel)
    }
    
    private func setupButtons() {
        recordButton.setImage(UIImage(systemName: "record.circle.fill"), for: .normal)
        recordButton.translatesAutoresizingMaskIntoConstraints = false
        recordButton.addTarget(self, action: #selector(recordButtonTapped), for: .touchUpInside)
        recordButton.accessibilityLabel = "Record"
        
        pauseButton.setImage(UIImage(systemName: "pause.circle.fill"), for: .normal)
        pauseButton.translatesAutoresizingMaskIntoConstraints = false
        pauseButton.addTarget(self, action: #selector(pauseButtonTapped), for: .touchUpInside)
        pauseButton.alpha = 0
        pauseButton.accessibilityLabel = "Pause recording"
        
        stopButton.setImage(UIImage(systemName: "stop.circle.fill"), for: .normal)
        stopButton.translatesAutoresizingMaskIntoConstraints = false
        stopButton.addTarget(self, action: #selector(stopButtonTapped), for: .touchUpInside)
        stopButton.alpha = 0
        stopButton.accessibilityLabel = "Stop recording"
        
        exitButton.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        exitButton.translatesAutoresizingMaskIntoConstraints = false
        exitButton.addTarget(self, action: #selector(exitButtonTapped), for: .touchUpInside)
        exitButton.accessibilityLabel = "Exit minimal mode"
    }
    
    private func setupControlsContainer() {
        controlsStack.axis = .horizontal
        controlsStack.spacing = LiquidDesignSystem.DesignTokens.Spacing.lg
        controlsStack.distribution = .equalSpacing
        controlsStack.alignment = .center
        controlsStack.translatesAutoresizingMaskIntoConstraints = false
        
        controlsStack.addArrangedSubview(recordButton)
        controlsStack.addArrangedSubview(pauseButton)
        controlsStack.addArrangedSubview(stopButton)
        
        addSubview(controlsStack)
        addSubview(exitButton)
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            backgroundView.topAnchor.constraint(equalTo: topAnchor),
            backgroundView.leadingAnchor.constraint(equalTo: leadingAnchor),
            backgroundView.trailingAnchor.constraint(equalTo: trailingAnchor),
            backgroundView.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            recordingIndicator.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: LiquidDesignSystem.DesignTokens.Spacing.xl),
            recordingIndicator.centerXAnchor.constraint(equalTo: centerXAnchor),
            recordingIndicator.widthAnchor.constraint(equalToConstant: 12),
            recordingIndicator.heightAnchor.constraint(equalToConstant: 12),
            
            recordingTimeLabel.topAnchor.constraint(equalTo: recordingIndicator.bottomAnchor, constant: LiquidDesignSystem.DesignTokens.Spacing.sm),
            recordingTimeLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            
            controlsStack.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: -LiquidDesignSystem.DesignTokens.Spacing.xl),
            controlsStack.centerXAnchor.constraint(equalTo: centerXAnchor),
            
            recordButton.widthAnchor.constraint(equalToConstant: 64),
            recordButton.heightAnchor.constraint(equalToConstant: 64),
            
            pauseButton.widthAnchor.constraint(equalToConstant: 64),
            pauseButton.heightAnchor.constraint(equalToConstant: 64),
            
            stopButton.widthAnchor.constraint(equalToConstant: 64),
            stopButton.heightAnchor.constraint(equalToConstant: 64),
            
            exitButton.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: LiquidDesignSystem.DesignTokens.Spacing.lg),
            exitButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -LiquidDesignSystem.DesignTokens.Spacing.lg),
            exitButton.widthAnchor.constraint(equalToConstant: 44),
            exitButton.heightAnchor.constraint(equalToConstant: 44)
        ])
    }
    
    // MARK: - Public Methods
    
    func show(animated: Bool = true) {
        isHidden = false
        
        if animated {
            UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5) {
                self.alpha = 1
            }
        } else {
            alpha = 1
        }
    }
    
    func hide(animated: Bool = true) {
        if animated {
            UIView.animate(withDuration: 0.3, delay: 0, options: [.curveEaseIn]) {
                self.alpha = 0
            } completion: { _ in
                self.isHidden = true
                self.phase = .idle
            }
        } else {
            alpha = 0
            isHidden = true
            phase = .idle
        }
    }
    
    func setPhase(_ newPhase: RecordingPhase) {
        phase = newPhase
    }
    
    func updateDuration(_ duration: TimeInterval) {
        recordingDuration = duration
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        recordingTimeLabel.text = String(format: "%02d:%02d", minutes, seconds)
        recordingTimeLabel.accessibilityValue = "\(minutes) minutes, \(seconds) seconds"
    }
    
    // MARK: - UI State Updates
    
    private func updateUIForPhase() {
        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.5, options: [.allowUserInteraction]) {
            switch self.phase {
            case .idle:
                self.recordingIndicator.alpha = 0
                self.recordingTimeLabel.alpha = 0
                self.recordButton.alpha = 1
                self.pauseButton.alpha = 0
                self.stopButton.alpha = 0
                self.recordingIndicator.layer.removeAnimation(forKey: "pulse")
                
            case .countingDown(let remaining):
                self.recordingTimeLabel.text = "\(remaining)"
                self.recordingTimeLabel.alpha = 1
                self.recordButton.alpha = 0
                
            case .recording:
                self.recordingIndicator.alpha = 1
                self.recordingTimeLabel.alpha = 1
                self.recordButton.alpha = 0
                self.pauseButton.alpha = 1
                self.stopButton.alpha = 1
                
                if let animation = self.pulseAnimation {
                    self.recordingIndicator.layer.add(animation, forKey: "pulse")
                }
                
            case .paused:
                self.recordingIndicator.backgroundColor = LiquidDesignSystem.DesignTokens.Colors.accent
                self.recordingIndicator.layer.removeAnimation(forKey: "pulse")
                self.pauseButton.alpha = 0
                self.recordButton.alpha = 1
                self.recordButton.setImage(UIImage(systemName: "play.circle.fill"), for: .normal)
            }
        }
        
        switch phase {
        case .recording:
            HapticFeedbackManager.shared.recordingStart()
        case .paused, .idle:
            HapticFeedbackManager.shared.mediumImpact()
        case .countingDown:
            HapticFeedbackManager.shared.lightImpact()
        }
    }
    
    // MARK: - Button Actions
    
    @objc private func recordButtonTapped() {
        HapticFeedbackManager.shared.mediumImpact()
        onRecordButtonTapped?()
    }
    
    @objc private func pauseButtonTapped() {
        HapticFeedbackManager.shared.mediumImpact()
        onPauseButtonTapped?()
    }
    
    @objc private func stopButtonTapped() {
        HapticFeedbackManager.shared.heavyImpact()
        onStopButtonTapped?()
    }
    
    @objc private func exitButtonTapped() {
        HapticFeedbackManager.shared.lightImpact()
        onExitButtonTapped?()
    }
}