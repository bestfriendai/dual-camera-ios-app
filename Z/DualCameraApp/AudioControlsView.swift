//
//  AudioControlsView.swift
//  DualCameraApp
//
//  Audio controls UI with source selection, level monitoring, and noise reduction
//

import UIKit

class AudioControlsView: UIView {
    
    // MARK: - Properties
    
    private let containerView = UIView()
    private let titleLabel = UILabel()
    private let controlsStackView = UIStackView()
    
    // Audio source controls
    private let sourceControlContainer = UIView()
    private let sourceLabel = UILabel()
    private let sourceSegmentedControl = UISegmentedControl()
    
    // Audio level monitoring
    private let levelControlContainer = UIView()
    private let levelLabel = UILabel()
    private let levelMeterView = AudioLevelMeterView()
    private let clippingIndicatorView = UIView()
    
    // Noise reduction controls
    private let noiseControlContainer = UIView()
    private let noiseLabel = UILabel()
    private let noiseSwitch = UISwitch()
    private let noiseSlider = UISlider()
    
    // Audio manager
    private var audioManager: AudioManager?
    
    // Callbacks
    var onAudioSourceChanged: ((AudioSource) -> Void)?
    var onNoiseReductionChanged: ((Bool) -> Void)?
    
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
        
        setupContainerView()
        setupTitleLabel()
        setupControlsStackView()
        setupSourceControls()
        setupLevelControls()
        setupNoiseControls()
        setupConstraints()
        
        updateUIForCurrentSettings()
    }
    
    private func setupContainerView() {
        containerView.backgroundColor = UIColor.black.withAlphaComponent(0.3)
        containerView.layer.cornerRadius = 16
        containerView.layer.borderWidth = 1
        containerView.layer.borderColor = UIColor.white.withAlphaComponent(0.2).cgColor
        containerView.translatesAutoresizingMaskIntoConstraints = false
        
        addSubview(containerView)
    }
    
    private func setupTitleLabel() {
        titleLabel.text = "Audio Settings"
        titleLabel.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        titleLabel.textColor = .white
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        containerView.addSubview(titleLabel)
    }
    
    private func setupControlsStackView() {
        controlsStackView.axis = .vertical
        controlsStackView.spacing = 16
        controlsStackView.translatesAutoresizingMaskIntoConstraints = false
        
        containerView.addSubview(controlsStackView)
    }
    
    private func setupSourceControls() {
        sourceLabel.text = "Audio Source"
        sourceLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        sourceLabel.textColor = .white
        sourceLabel.translatesAutoresizingMaskIntoConstraints = false
        
        sourceSegmentedControl.backgroundColor = UIColor.white.withAlphaComponent(0.1)
        sourceSegmentedControl.selectedSegmentTintColor = UIColor.systemBlue.withAlphaComponent(0.7)
        sourceSegmentedControl.setTitleTextAttributes([.foregroundColor: UIColor.white], for: .normal)
        sourceSegmentedControl.setTitleTextAttributes([.foregroundColor: UIColor.black], for: .selected)
        sourceSegmentedControl.layer.cornerRadius = 8
        sourceSegmentedControl.translatesAutoresizingMaskIntoConstraints = false
        
        sourceSegmentedControl.addTarget(self, action: #selector(sourceChanged(_:)), for: .valueChanged)
        
        sourceControlContainer.addSubview(sourceLabel)
        sourceControlContainer.addSubview(sourceSegmentedControl)
        
        controlsStackView.addArrangedSubview(sourceControlContainer)
    }
    
    private func setupLevelControls() {
        levelLabel.text = "Audio Level"
        levelLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        levelLabel.textColor = .white
        levelLabel.translatesAutoresizingMaskIntoConstraints = false
        
        levelMeterView.translatesAutoresizingMaskIntoConstraints = false
        
        clippingIndicatorView.backgroundColor = .systemRed
        clippingIndicatorView.layer.cornerRadius = 4
        clippingIndicatorView.translatesAutoresizingMaskIntoConstraints = false
        clippingIndicatorView.alpha = 0
        clippingIndicatorView.isHidden = true
        
        levelControlContainer.addSubview(levelLabel)
        levelControlContainer.addSubview(levelMeterView)
        levelControlContainer.addSubview(clippingIndicatorView)
        
        controlsStackView.addArrangedSubview(levelControlContainer)
    }
    
    private func setupNoiseControls() {
        noiseLabel.text = "Noise Reduction"
        noiseLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        noiseLabel.textColor = .white
        noiseLabel.translatesAutoresizingMaskIntoConstraints = false
        
        noiseSwitch.isOn = true
        noiseSwitch.onTintColor = .systemBlue
        noiseSwitch.translatesAutoresizingMaskIntoConstraints = false
        
        noiseSwitch.addTarget(self, action: #selector(noiseSwitchChanged(_:)), for: .valueChanged)
        
        noiseSlider.minimumValue = 0.0
        noiseSlider.maximumValue = 1.0
        noiseSlider.value = 0.8
        noiseSlider.tintColor = .systemBlue
        noiseSlider.translatesAutoresizingMaskIntoConstraints = false
        
        noiseSlider.addTarget(self, action: #selector(noiseSliderChanged(_:)), for: .valueChanged)
        
        noiseControlContainer.addSubview(noiseLabel)
        noiseControlContainer.addSubview(noiseSwitch)
        noiseControlContainer.addSubview(noiseSlider)
        
        controlsStackView.addArrangedSubview(noiseControlContainer)
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: topAnchor),
            containerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            titleLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            
            controlsStackView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            controlsStackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            controlsStackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            controlsStackView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -16),
            
            // Source controls
            sourceLabel.topAnchor.constraint(equalTo: sourceControlContainer.topAnchor),
            sourceLabel.leadingAnchor.constraint(equalTo: sourceControlContainer.leadingAnchor),
            sourceLabel.trailingAnchor.constraint(equalTo: sourceControlContainer.trailingAnchor),
            
            sourceSegmentedControl.topAnchor.constraint(equalTo: sourceLabel.bottomAnchor, constant: 8),
            sourceSegmentedControl.leadingAnchor.constraint(equalTo: sourceControlContainer.leadingAnchor),
            sourceSegmentedControl.trailingAnchor.constraint(equalTo: sourceControlContainer.trailingAnchor),
            sourceSegmentedControl.heightAnchor.constraint(equalToConstant: 32),
            sourceSegmentedControl.bottomAnchor.constraint(equalTo: sourceControlContainer.bottomAnchor),
            
            // Level controls
            levelLabel.topAnchor.constraint(equalTo: levelControlContainer.topAnchor),
            levelLabel.leadingAnchor.constraint(equalTo: levelControlContainer.leadingAnchor),
            levelLabel.trailingAnchor.constraint(equalTo: levelControlContainer.trailingAnchor),
            
            levelMeterView.topAnchor.constraint(equalTo: levelLabel.bottomAnchor, constant: 8),
            levelMeterView.leadingAnchor.constraint(equalTo: levelControlContainer.leadingAnchor),
            levelMeterView.trailingAnchor.constraint(equalTo: levelControlContainer.trailingAnchor),
            levelMeterView.heightAnchor.constraint(equalToConstant: 20),
            
            clippingIndicatorView.topAnchor.constraint(equalTo: levelMeterView.bottomAnchor, constant: 8),
            clippingIndicatorView.centerXAnchor.constraint(equalTo: levelControlContainer.centerXAnchor),
            clippingIndicatorView.widthAnchor.constraint(equalToConstant: 8),
            clippingIndicatorView.heightAnchor.constraint(equalToConstant: 8),
            clippingIndicatorView.bottomAnchor.constraint(equalTo: levelControlContainer.bottomAnchor),
            
            // Noise controls
            noiseLabel.topAnchor.constraint(equalTo: noiseControlContainer.topAnchor),
            noiseLabel.leadingAnchor.constraint(equalTo: noiseControlContainer.leadingAnchor),
            noiseLabel.trailingAnchor.constraint(equalTo: noiseControlContainer.trailingAnchor),
            
            noiseSwitch.topAnchor.constraint(equalTo: noiseLabel.bottomAnchor, constant: 8),
            noiseSwitch.leadingAnchor.constraint(equalTo: noiseControlContainer.leadingAnchor),
            
            noiseSlider.topAnchor.constraint(equalTo: noiseSwitch.bottomAnchor, constant: 8),
            noiseSlider.leadingAnchor.constraint(equalTo: noiseControlContainer.leadingAnchor),
            noiseSlider.trailingAnchor.constraint(equalTo: noiseControlContainer.trailingAnchor),
            noiseSlider.bottomAnchor.constraint(equalTo: noiseControlContainer.bottomAnchor)
        ])
    }
    
    // MARK: - Actions
    
    @objc private func sourceChanged(_ sender: UISegmentedControl) {
        guard let audioManager = audioManager else { return }

        Task {
            let availableSources = await audioManager.getAvailableAudioSources()
            guard sender.selectedSegmentIndex < availableSources.count else { return }

            let selectedSource = availableSources[sender.selectedSegmentIndex]
            await audioManager.setAudioSource(selectedSource)

            await MainActor.run {
                onAudioSourceChanged?(selectedSource)

                // Haptic feedback
                HapticFeedbackManager.shared.selectionChanged()
            }
        }
    }
    
    @objc private func noiseSwitchChanged(_ sender: UISwitch) {
        guard let audioManager = audioManager else { return }

        Task {
            await audioManager.setNoiseReductionEnabled(sender.isOn)

            await MainActor.run {
                noiseSlider.isEnabled = sender.isOn
                onNoiseReductionChanged?(sender.isOn)

                // Haptic feedback
                HapticFeedbackManager.shared.selectionChanged()
            }
        }
    }
    
    @objc private func noiseSliderChanged(_ sender: UISlider) {
        guard let audioManager = audioManager else { return }

        Task {
            await audioManager.setNoiseReductionGain(sender.value)
        }
    }
    
    // MARK: - UI Updates
    
    private func updateUIForCurrentSettings() {
        guard let audioManager = audioManager else { return }

        Task {
            // Update source segmented control
            let availableSources = await audioManager.getAvailableAudioSources()
            let currentSource = await audioManager.currentAudioSource
            let isNoiseReductionEnabled = await audioManager.isNoiseReductionEnabled

            await MainActor.run {
                sourceSegmentedControl.removeAllSegments()

                for (index, source) in availableSources.enumerated() {
                    sourceSegmentedControl.insertSegment(withTitle: source.displayName, at: index, animated: false)

                    if source == currentSource {
                        sourceSegmentedControl.selectedSegmentIndex = index
                    }
                }

                // Update noise reduction controls
                noiseSwitch.isOn = isNoiseReductionEnabled
                noiseSlider.isEnabled = isNoiseReductionEnabled
            }
        }
    }
    
    private func updateAudioLevel(_ level: Float) {
        levelMeterView.updateLevel(level)
        
        // Show clipping indicator if needed
        if level > 0.95 {
            showClippingIndicator()
        }
    }
    
    private func showClippingIndicator() {
        clippingIndicatorView.isHidden = false
        clippingIndicatorView.alpha = 1.0
        
        UIView.animate(withDuration: 0.5, delay: 0, options: [.curveEaseOut]) {
            self.clippingIndicatorView.alpha = 0.0
        } completion: { _ in
            self.clippingIndicatorView.isHidden = true
        }
        
        // Haptic feedback for clipping
        HapticFeedbackManager.shared.warning()
    }
    
    // MARK: - Public Methods
    
    func setAudioManager(_ manager: AudioManager) {
        audioManager = manager

        // Set up callbacks
        Task {
            // Note: These properties are not fully implemented in AudioManager
            // For now, we'll skip setting up the callbacks
            // TODO: Implement proper callback mechanism in AudioManager
        }

        updateUIForCurrentSettings()
    }
    
    func setEnabled(_ enabled: Bool) {
        sourceSegmentedControl.isEnabled = enabled
        noiseSwitch.isEnabled = enabled
        noiseSlider.isEnabled = enabled && noiseSwitch.isOn
        
        alpha = enabled ? 1.0 : 0.6
    }
    
    func startAudioLevelMonitoring() {
        Task {
            await audioManager?.startAudioLevelMonitoring()
        }
    }

    func stopAudioLevelMonitoring() {
        Task {
            await audioManager?.stopAudioLevelMonitoring()
        }
    }
    
    // MARK: - Animation
    
    func animateSelection() {
        UIView.animate(withDuration: 0.2, animations: {
            self.transform = CGAffineTransform(scaleX: 0.98, y: 0.98)
        }) { _ in
            UIView.animate(withDuration: 0.2) {
                self.transform = .identity
            }
        }
    }
}

// MARK: - Audio Level Meter View

class AudioLevelMeterView: UIView {
    
    // MARK: - Properties
    
    private let backgroundLayer = CAShapeLayer()
    private let levelLayer = CAShapeLayer()
    private let peakLayer = CAShapeLayer()
    
    private var currentLevel: Float = 0.0
    private var peakLevel: Float = 0.0
    private var peakDecayTimer: Timer?
    
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
        backgroundColor = UIColor.clear
        
        // Setup background layer
        backgroundLayer.fillColor = UIColor.white.withAlphaComponent(0.2).cgColor
        backgroundLayer.strokeColor = UIColor.clear.cgColor
        layer.addSublayer(backgroundLayer)
        
        // Setup level layer
        levelLayer.fillColor = UIColor.systemGreen.cgColor
        levelLayer.strokeColor = UIColor.clear.cgColor
        layer.addSublayer(levelLayer)
        
        // Setup peak layer
        peakLayer.fillColor = UIColor.systemYellow.cgColor
        peakLayer.strokeColor = UIColor.clear.cgColor
        layer.addSublayer(peakLayer)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        let cornerRadius = bounds.height / 2
        let path = UIBezierPath(roundedRect: bounds, cornerRadius: cornerRadius)
        
        backgroundLayer.path = path.cgPath
        backgroundLayer.frame = bounds
        
        updateLevelLayer()
        updatePeakLayer()
    }
    
    // MARK: - Level Updates
    
    func updateLevel(_ level: Float) {
        currentLevel = max(0.0, min(1.0, level))
        
        // Update peak level
        if level > peakLevel {
            peakLevel = level
            resetPeakDecayTimer()
        }
        
        updateLevelLayer()
        updatePeakLayer()
        
        // Update color based on level
        updateLevelColor()
    }
    
    private func updateLevelLayer() {
        let levelWidth = bounds.width * CGFloat(currentLevel)
        let levelRect = CGRect(x: 0, y: 0, width: levelWidth, height: bounds.height)
        let cornerRadius = bounds.height / 2
        let path = UIBezierPath(roundedRect: levelRect, cornerRadius: cornerRadius)
        
        levelLayer.path = path.cgPath
        levelLayer.frame = bounds
    }
    
    private func updatePeakLayer() {
        let peakWidth = max(2, bounds.width * 0.02)
        let peakX = bounds.width * CGFloat(peakLevel) - peakWidth / 2
        let peakRect = CGRect(x: peakX, y: 0, width: peakWidth, height: bounds.height)
        let cornerRadius = peakWidth / 2
        let path = UIBezierPath(roundedRect: peakRect, cornerRadius: cornerRadius)
        
        peakLayer.path = path.cgPath
        peakLayer.frame = bounds
    }
    
    private func updateLevelColor() {
        let color: UIColor
        
        if currentLevel < 0.7 {
            color = .systemGreen
        } else if currentLevel < 0.9 {
            color = .systemYellow
        } else {
            color = .systemRed
        }
        
        levelLayer.fillColor = color.cgColor
    }
    
    private func resetPeakDecayTimer() {
        peakDecayTimer?.invalidate()
        
        peakDecayTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
            self?.peakLevel *= 0.9
            self?.updatePeakLayer()
            
            // Continue decaying if still above threshold
            if self?.peakLevel ?? 0 > 0.01 {
                self?.resetPeakDecayTimer()
            }
        }
    }
    
    // MARK: - Reset
    
    func reset() {
        currentLevel = 0.0
        peakLevel = 0.0
        peakDecayTimer?.invalidate()
        
        updateLevelLayer()
        updatePeakLayer()
        updateLevelColor()
    }
}