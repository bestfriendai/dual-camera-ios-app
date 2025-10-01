//
//  ContextualControlsView.swift
//  DualCameraApp
//
//  Contextual controls that adapt based on recording mode with modern iOS 18+ UI
//

import UIKit

/// Contextual controls that adapt based on recording mode
class ContextualControlsView: UIView {
    
    // MARK: - Properties
    
    private var currentMode: RecordingMode = .idle
    private var isTransitioning = false
    
    // UI Components
    private let containerView = UIView()
    private let controlsStackView = UIStackView()
    private let primaryControlsContainer = UIView()
    private let secondaryControlsContainer = UIView()
    
    // Recording controls
    private let recordButton = UIButton(type: .system)
    private let stopButton = UIButton(type: .system)
    private let pauseButton = UIButton(type: .system)
    private let resumeButton = UIButton(type: .system)
    
    // Camera controls
    private let flipCameraButton = UIButton(type: .system)
    private let flashButton = UIButton(type: .system)
    private let focusButton = UIButton(type: .system)
    private let zoomButton = UIButton(type: .system)
    
    // Mode controls
    private let photoModeButton = UIButton(type: .system)
    private let videoModeButton = UIButton(type: .system)
    private let slowMotionModeButton = UIButton(type: .system)
    private let timeLapseModeButton = UIButton(type: .system)
    
    // Advanced controls
    private let settingsButton = UIButton(type: .system)
    private let effectsButton = UIButton(type: .system)
    private let timerButton = UIButton(type: .system)
    private let qualityButton = UIButton(type: .system)
    
    // Material containers
    private let primaryMaterialView = EnhancedGlassmorphismView(
        material: .regular,
        vibrancy: .primary,
        adaptiveBlur: true,
        depthEffect: true
    )
    
    private let secondaryMaterialView = EnhancedGlassmorphismView(
        material: .thin,
        vibrancy: .secondary,
        adaptiveBlur: true,
        depthEffect: false
    )
    
    // Callbacks
    var onModeChanged: ((RecordingMode) -> Void)?
    var onControlTapped: ((ControlType) -> Void)?
    
    // MARK: - Recording Mode Enum
    
    enum RecordingMode {
        case idle
        case photo
        case video
        case slowMotion
        case timeLapse
        case paused
        case recording
        
        var description: String {
            switch self {
            case .idle:
                return "Ready"
            case .photo:
                return "Photo"
            case .video:
                return "Video"
            case .slowMotion:
                return "Slow Motion"
            case .timeLapse:
                return "Time Lapse"
            case .paused:
                return "Paused"
            case .recording:
                return "Recording"
            }
        }
    }
    
    // MARK: - Control Type Enum
    
    enum ControlType {
        case record
        case stop
        case pause
        case resume
        case flipCamera
        case flash
        case focus
        case zoom
        case photoMode
        case videoMode
        case slowMotionMode
        case timeLapseMode
        case settings
        case effects
        case timer
        case quality
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
        backgroundColor = .clear
        translatesAutoresizingMaskIntoConstraints = false
        
        setupContainerView()
        setupMaterialViews()
        setupControls()
        setupConstraints()
        updateUIForMode(.idle)
    }
    
    private func setupContainerView() {
        containerView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(containerView)
    }
    
    private func setupMaterialViews() {
        // Primary material view
        primaryMaterialView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(primaryMaterialView)
        
        // Secondary material view
        secondaryMaterialView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(secondaryMaterialView)
        
        // Add control containers to material views
        primaryMaterialView.contentView.addSubview(primaryControlsContainer)
        secondaryMaterialView.contentView.addSubview(secondaryControlsContainer)
    }
    
    private func setupControls() {
        // Setup controls stack view
        controlsStackView.axis = .horizontal
        controlsStackView.distribution = .fillEqually
        controlsStackView.spacing = DesignSystem.Spacing.sm.value
        controlsStackView.translatesAutoresizingMaskIntoConstraints = false
        primaryControlsContainer.addSubview(controlsStackView)
        
        // Setup recording controls
        setupRecordingControls()
        
        // Setup camera controls
        setupCameraControls()
        
        // Setup mode controls
        setupModeControls()
        
        // Setup advanced controls
        setupAdvancedControls()
    }
    
    private func setupRecordingControls() {
        // Record button
        recordButton.setImage(UIImage(systemName: "record.circle.fill"), for: .normal)
        recordButton.tintColor = EnhancedColorSystem.DynamicColor.recordingActive.color
        recordButton.backgroundColor = EnhancedColorSystem.DynamicColor.controlBackground.color
        recordButton.layer.cornerRadius = 32
        recordButton.layer.cornerCurve = .continuous
        recordButton.translatesAutoresizingMaskIntoConstraints = false
        recordButton.addTarget(self, action: #selector(recordButtonTapped), for: .touchUpInside)
        
        // Stop button
        stopButton.setImage(UIImage(systemName: "stop.circle.fill"), for: .normal)
        stopButton.tintColor = EnhancedColorSystem.DynamicColor.error.color
        stopButton.backgroundColor = EnhancedColorSystem.DynamicColor.controlBackground.color
        stopButton.layer.cornerRadius = 32
        stopButton.layer.cornerCurve = .continuous
        stopButton.translatesAutoresizingMaskIntoConstraints = false
        stopButton.addTarget(self, action: #selector(stopButtonTapped), for: .touchUpInside)
        
        // Pause button
        pauseButton.setImage(UIImage(systemName: "pause.circle.fill"), for: .normal)
        pauseButton.tintColor = EnhancedColorSystem.DynamicColor.warning.color
        pauseButton.backgroundColor = EnhancedColorSystem.DynamicColor.controlBackground.color
        pauseButton.layer.cornerRadius = 32
        pauseButton.layer.cornerCurve = .continuous
        pauseButton.translatesAutoresizingMaskIntoConstraints = false
        pauseButton.addTarget(self, action: #selector(pauseButtonTapped), for: .touchUpInside)
        
        // Resume button
        resumeButton.setImage(UIImage(systemName: "play.circle.fill"), for: .normal)
        resumeButton.tintColor = EnhancedColorSystem.DynamicColor.success.color
        resumeButton.backgroundColor = EnhancedColorSystem.DynamicColor.controlBackground.color
        resumeButton.layer.cornerRadius = 32
        resumeButton.layer.cornerCurve = .continuous
        resumeButton.translatesAutoresizingMaskIntoConstraints = false
        resumeButton.addTarget(self, action: #selector(resumeButtonTapped), for: .touchUpInside)
    }
    
    private func setupCameraControls() {
        // Flip camera button
        flipCameraButton.setImage(UIImage(systemName: "camera.rotate"), for: .normal)
        flipCameraButton.tintColor = EnhancedColorSystem.DynamicColor.onControlBackground.color
        flipCameraButton.backgroundColor = EnhancedColorSystem.DynamicColor.controlBackground.color
        flipCameraButton.layer.cornerRadius = 24
        flipCameraButton.layer.cornerCurve = .continuous
        flipCameraButton.translatesAutoresizingMaskIntoConstraints = false
        flipCameraButton.addTarget(self, action: #selector(flipCameraButtonTapped), for: .touchUpInside)
        
        // Flash button
        flashButton.setImage(UIImage(systemName: "bolt.slash"), for: .normal)
        flashButton.tintColor = EnhancedColorSystem.DynamicColor.onControlBackground.color
        flashButton.backgroundColor = EnhancedColorSystem.DynamicColor.controlBackground.color
        flashButton.layer.cornerRadius = 24
        flashButton.layer.cornerCurve = .continuous
        flashButton.translatesAutoresizingMaskIntoConstraints = false
        flashButton.addTarget(self, action: #selector(flashButtonTapped), for: .touchUpInside)
        
        // Focus button
        focusButton.setImage(UIImage(systemName: "viewfinder"), for: .normal)
        focusButton.tintColor = EnhancedColorSystem.DynamicColor.onControlBackground.color
        focusButton.backgroundColor = EnhancedColorSystem.DynamicColor.controlBackground.color
        focusButton.layer.cornerRadius = 24
        focusButton.layer.cornerCurve = .continuous
        focusButton.translatesAutoresizingMaskIntoConstraints = false
        focusButton.addTarget(self, action: #selector(focusButtonTapped), for: .touchUpInside)
        
        // Zoom button
        zoomButton.setImage(UIImage(systemName: "magnifyingglass"), for: .normal)
        zoomButton.tintColor = EnhancedColorSystem.DynamicColor.onControlBackground.color
        zoomButton.backgroundColor = EnhancedColorSystem.DynamicColor.controlBackground.color
        zoomButton.layer.cornerRadius = 24
        zoomButton.layer.cornerCurve = .continuous
        zoomButton.translatesAutoresizingMaskIntoConstraints = false
        zoomButton.addTarget(self, action: #selector(zoomButtonTapped), for: .touchUpInside)
    }
    
    private func setupModeControls() {
        // Photo mode button
        photoModeButton.setImage(UIImage(systemName: "camera"), for: .normal)
        photoModeButton.tintColor = EnhancedColorSystem.DynamicColor.onControlBackground.color
        photoModeButton.backgroundColor = EnhancedColorSystem.DynamicColor.controlBackground.color
        photoModeButton.layer.cornerRadius = 24
        photoModeButton.layer.cornerCurve = .continuous
        photoModeButton.translatesAutoresizingMaskIntoConstraints = false
        photoModeButton.addTarget(self, action: #selector(photoModeButtonTapped), for: .touchUpInside)
        
        // Video mode button
        videoModeButton.setImage(UIImage(systemName: "video"), for: .normal)
        videoModeButton.tintColor = EnhancedColorSystem.DynamicColor.onControlBackground.color
        videoModeButton.backgroundColor = EnhancedColorSystem.DynamicColor.controlBackground.color
        videoModeButton.layer.cornerRadius = 24
        videoModeButton.layer.cornerCurve = .continuous
        videoModeButton.translatesAutoresizingMaskIntoConstraints = false
        videoModeButton.addTarget(self, action: #selector(videoModeButtonTapped), for: .touchUpInside)
        
        // Slow motion mode button
        slowMotionModeButton.setImage(UIImage(systemName: "timelapse"), for: .normal)
        slowMotionModeButton.tintColor = EnhancedColorSystem.DynamicColor.onControlBackground.color
        slowMotionModeButton.backgroundColor = EnhancedColorSystem.DynamicColor.controlBackground.color
        slowMotionModeButton.layer.cornerRadius = 24
        slowMotionModeButton.layer.cornerCurve = .continuous
        slowMotionModeButton.translatesAutoresizingMaskIntoConstraints = false
        slowMotionModeButton.addTarget(self, action: #selector(slowMotionModeButtonTapped), for: .touchUpInside)
        
        // Time lapse mode button
        timeLapseModeButton.setImage(UIImage(systemName: "clock"), for: .normal)
        timeLapseModeButton.tintColor = EnhancedColorSystem.DynamicColor.onControlBackground.color
        timeLapseModeButton.backgroundColor = EnhancedColorSystem.DynamicColor.controlBackground.color
        timeLapseModeButton.layer.cornerRadius = 24
        timeLapseModeButton.layer.cornerCurve = .continuous
        timeLapseModeButton.translatesAutoresizingMaskIntoConstraints = false
        timeLapseModeButton.addTarget(self, action: #selector(timeLapseModeButtonTapped), for: .touchUpInside)
    }
    
    private func setupAdvancedControls() {
        // Settings button
        settingsButton.setImage(UIImage(systemName: "gearshape"), for: .normal)
        settingsButton.tintColor = EnhancedColorSystem.DynamicColor.onControlBackground.color
        settingsButton.backgroundColor = EnhancedColorSystem.DynamicColor.controlBackground.color
        settingsButton.layer.cornerRadius = 24
        settingsButton.layer.cornerCurve = .continuous
        settingsButton.translatesAutoresizingMaskIntoConstraints = false
        settingsButton.addTarget(self, action: #selector(settingsButtonTapped), for: .touchUpInside)
        
        // Effects button
        effectsButton.setImage(UIImage(systemName: "wand.and.stars"), for: .normal)
        effectsButton.tintColor = EnhancedColorSystem.DynamicColor.onControlBackground.color
        effectsButton.backgroundColor = EnhancedColorSystem.DynamicColor.controlBackground.color
        effectsButton.layer.cornerRadius = 24
        effectsButton.layer.cornerCurve = .continuous
        effectsButton.translatesAutoresizingMaskIntoConstraints = false
        effectsButton.addTarget(self, action: #selector(effectsButtonTapped), for: .touchUpInside)
        
        // Timer button
        timerButton.setImage(UIImage(systemName: "timer"), for: .normal)
        timerButton.tintColor = EnhancedColorSystem.DynamicColor.onControlBackground.color
        timerButton.backgroundColor = EnhancedColorSystem.DynamicColor.controlBackground.color
        timerButton.layer.cornerRadius = 24
        timerButton.layer.cornerCurve = .continuous
        timerButton.translatesAutoresizingMaskIntoConstraints = false
        timerButton.addTarget(self, action: #selector(timerButtonTapped), for: .touchUpInside)
        
        // Quality button
        qualityButton.setImage(UIImage(systemName: "hd"), for: .normal)
        qualityButton.tintColor = EnhancedColorSystem.DynamicColor.onControlBackground.color
        qualityButton.backgroundColor = EnhancedColorSystem.DynamicColor.controlBackground.color
        qualityButton.layer.cornerRadius = 24
        qualityButton.layer.cornerCurve = .continuous
        qualityButton.translatesAutoresizingMaskIntoConstraints = false
        qualityButton.addTarget(self, action: #selector(qualityButtonTapped), for: .touchUpInside)
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // Container view
            containerView.topAnchor.constraint(equalTo: topAnchor),
            containerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            // Primary material view
            primaryMaterialView.topAnchor.constraint(equalTo: containerView.topAnchor),
            primaryMaterialView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            primaryMaterialView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            primaryMaterialView.heightAnchor.constraint(equalToConstant: 80),
            
            // Secondary material view
            secondaryMaterialView.topAnchor.constraint(equalTo: primaryMaterialView.bottomAnchor, constant: DesignSystem.Spacing.sm.value),
            secondaryMaterialView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            secondaryMaterialView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            secondaryMaterialView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            
            // Primary controls container
            primaryControlsContainer.topAnchor.constraint(equalTo: primaryMaterialView.contentView.topAnchor),
            primaryControlsContainer.leadingAnchor.constraint(equalTo: primaryMaterialView.contentView.leadingAnchor, constant: DesignSystem.Spacing.md.value),
            primaryControlsContainer.trailingAnchor.constraint(equalTo: primaryMaterialView.contentView.trailingAnchor, constant: -DesignSystem.Spacing.md.value),
            primaryControlsContainer.bottomAnchor.constraint(equalTo: primaryMaterialView.contentView.bottomAnchor),
            
            // Secondary controls container
            secondaryControlsContainer.topAnchor.constraint(equalTo: secondaryMaterialView.contentView.topAnchor, constant: DesignSystem.Spacing.sm.value),
            secondaryControlsContainer.leadingAnchor.constraint(equalTo: secondaryMaterialView.contentView.leadingAnchor, constant: DesignSystem.Spacing.md.value),
            secondaryControlsContainer.trailingAnchor.constraint(equalTo: secondaryMaterialView.contentView.trailingAnchor, constant: -DesignSystem.Spacing.md.value),
            secondaryControlsContainer.bottomAnchor.constraint(equalTo: secondaryMaterialView.contentView.bottomAnchor, constant: -DesignSystem.Spacing.sm.value),
            
            // Controls stack view
            controlsStackView.topAnchor.constraint(equalTo: primaryControlsContainer.topAnchor),
            controlsStackView.leadingAnchor.constraint(equalTo: primaryControlsContainer.leadingAnchor),
            controlsStackView.trailingAnchor.constraint(equalTo: primaryControlsContainer.trailingAnchor),
            controlsStackView.bottomAnchor.constraint(equalTo: primaryControlsContainer.bottomAnchor),
            
            // Record button
            recordButton.widthAnchor.constraint(equalToConstant: 64),
            recordButton.heightAnchor.constraint(equalToConstant: 64),
            
            // Stop button
            stopButton.widthAnchor.constraint(equalToConstant: 64),
            stopButton.heightAnchor.constraint(equalToConstant: 64),
            
            // Pause button
            pauseButton.widthAnchor.constraint(equalToConstant: 64),
            pauseButton.heightAnchor.constraint(equalToConstant: 64),
            
            // Resume button
            resumeButton.widthAnchor.constraint(equalToConstant: 64),
            resumeButton.heightAnchor.constraint(equalToConstant: 64),
            
            // Camera buttons
            flipCameraButton.widthAnchor.constraint(equalToConstant: 48),
            flipCameraButton.heightAnchor.constraint(equalToConstant: 48),
            
            flashButton.widthAnchor.constraint(equalToConstant: 48),
            flashButton.heightAnchor.constraint(equalToConstant: 48),
            
            focusButton.widthAnchor.constraint(equalToConstant: 48),
            focusButton.heightAnchor.constraint(equalToConstant: 48),
            
            zoomButton.widthAnchor.constraint(equalToConstant: 48),
            zoomButton.heightAnchor.constraint(equalToConstant: 48),
            
            // Mode buttons
            photoModeButton.widthAnchor.constraint(equalToConstant: 48),
            photoModeButton.heightAnchor.constraint(equalToConstant: 48),
            
            videoModeButton.widthAnchor.constraint(equalToConstant: 48),
            videoModeButton.heightAnchor.constraint(equalToConstant: 48),
            
            slowMotionModeButton.widthAnchor.constraint(equalToConstant: 48),
            slowMotionModeButton.heightAnchor.constraint(equalToConstant: 48),
            
            timeLapseModeButton.widthAnchor.constraint(equalToConstant: 48),
            timeLapseModeButton.heightAnchor.constraint(equalToConstant: 48),
            
            // Advanced buttons
            settingsButton.widthAnchor.constraint(equalToConstant: 48),
            settingsButton.heightAnchor.constraint(equalToConstant: 48),
            
            effectsButton.widthAnchor.constraint(equalToConstant: 48),
            effectsButton.heightAnchor.constraint(equalToConstant: 48),
            
            timerButton.widthAnchor.constraint(equalToConstant: 48),
            timerButton.heightAnchor.constraint(equalToConstant: 48),
            
            qualityButton.widthAnchor.constraint(equalToConstant: 48),
            qualityButton.heightAnchor.constraint(equalToConstant: 48)
        ])
    }
    
    // MARK: - UI Updates
    
    /// Updates the UI based on the current recording mode
    func updateUIForMode(_ mode: RecordingMode, animated: Bool = true) {
        guard !isTransitioning else { return }
        
        isTransitioning = true
        currentMode = mode
        
        let updateUI = {
            // Clear all existing controls
            self.controlsStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
            self.secondaryControlsContainer.subviews.forEach { $0.removeFromSuperview() }
            
            // Configure controls based on mode
            switch mode {
            case .idle:
                self.configureIdleMode()
            case .photo:
                self.configurePhotoMode()
            case .video:
                self.configureVideoMode()
            case .slowMotion:
                self.configureSlowMotionMode()
            case .timeLapse:
                self.configureTimeLapseMode()
            case .paused:
                self.configurePausedMode()
            case .recording:
                self.configureRecordingMode()
            }
            
            // Update material appearance
            self.updateMaterialAppearance(for: mode)
        }
        
        if animated {
            UIView.transition(with: self, duration: 0.3, options: .transitionCrossDissolve, animations: updateUI) { _ in
                self.isTransitioning = false
            }
        } else {
            updateUI()
            isTransitioning = false
        }
        
        // Notify mode change
        onModeChanged?(mode)
    }
    
    private func configureIdleMode() {
        // Add mode selection buttons
        controlsStackView.addArrangedSubview(photoModeButton)
        controlsStackView.addArrangedSubview(videoModeButton)
        controlsStackView.addArrangedSubview(slowMotionModeButton)
        controlsStackView.addArrangedSubview(timeLapseModeButton)
        
        // Add camera controls to secondary container
        let secondaryStackView = UIStackView()
        secondaryStackView.axis = .horizontal
        secondaryStackView.distribution = .fillEqually
        secondaryStackView.spacing = DesignSystem.Spacing.sm.value
        
        secondaryStackView.addArrangedSubview(flipCameraButton)
        secondaryStackView.addArrangedSubview(flashButton)
        secondaryStackView.addArrangedSubview(settingsButton)
        
        secondaryControlsContainer.addSubview(secondaryStackView)
        secondaryStackView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            secondaryStackView.topAnchor.constraint(equalTo: secondaryControlsContainer.topAnchor),
            secondaryStackView.leadingAnchor.constraint(equalTo: secondaryControlsContainer.leadingAnchor),
            secondaryStackView.trailingAnchor.constraint(equalTo: secondaryControlsContainer.trailingAnchor),
            secondaryStackView.bottomAnchor.constraint(equalTo: secondaryControlsContainer.bottomAnchor)
        ])
    }
    
    private func configurePhotoMode() {
        // Add photo-specific controls
        controlsStackView.addArrangedSubview(recordButton)
        controlsStackView.addArrangedSubview(timerButton)
        controlsStackView.addArrangedSubview(flashButton)
        
        // Add camera controls to secondary container
        let secondaryStackView = UIStackView()
        secondaryStackView.axis = .horizontal
        secondaryStackView.distribution = .fillEqually
        secondaryStackView.spacing = DesignSystem.Spacing.sm.value
        
        secondaryStackView.addArrangedSubview(flipCameraButton)
        secondaryStackView.addArrangedSubview(focusButton)
        secondaryStackView.addArrangedSubview(settingsButton)
        
        secondaryControlsContainer.addSubview(secondaryStackView)
        secondaryStackView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            secondaryStackView.topAnchor.constraint(equalTo: secondaryControlsContainer.topAnchor),
            secondaryStackView.leadingAnchor.constraint(equalTo: secondaryControlsContainer.leadingAnchor),
            secondaryStackView.trailingAnchor.constraint(equalTo: secondaryControlsContainer.trailingAnchor),
            secondaryStackView.bottomAnchor.constraint(equalTo: secondaryControlsContainer.bottomAnchor)
        ])
    }
    
    private func configureVideoMode() {
        // Add video-specific controls
        controlsStackView.addArrangedSubview(recordButton)
        controlsStackView.addArrangedSubview(flipCameraButton)
        controlsStackView.addArrangedSubview(qualityButton)
        
        // Add secondary controls
        let secondaryStackView = UIStackView()
        secondaryStackView.axis = .horizontal
        secondaryStackView.distribution = .fillEqually
        secondaryStackView.spacing = DesignSystem.Spacing.sm.value
        
        secondaryStackView.addArrangedSubview(flashButton)
        secondaryStackView.addArrangedSubview(focusButton)
        secondaryStackView.addArrangedSubview(effectsButton)
        
        secondaryControlsContainer.addSubview(secondaryStackView)
        secondaryStackView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            secondaryStackView.topAnchor.constraint(equalTo: secondaryControlsContainer.topAnchor),
            secondaryStackView.leadingAnchor.constraint(equalTo: secondaryControlsContainer.leadingAnchor),
            secondaryStackView.trailingAnchor.constraint(equalTo: secondaryControlsContainer.trailingAnchor),
            secondaryStackView.bottomAnchor.constraint(equalTo: secondaryControlsContainer.bottomAnchor)
        ])
    }
    
    private func configureSlowMotionMode() {
        // Similar to video mode but with slow motion specific controls
        configureVideoMode()
    }
    
    private func configureTimeLapseMode() {
        // Similar to video mode but with time lapse specific controls
        configureVideoMode()
    }
    
    private func configurePausedMode() {
        // Add paused controls
        controlsStackView.addArrangedSubview(resumeButton)
        controlsStackView.addArrangedSubview(stopButton)
        controlsStackView.addArrangedSubview(flipCameraButton)
        
        // Minimal secondary controls when paused
        let secondaryStackView = UIStackView()
        secondaryStackView.axis = .horizontal
        secondaryStackView.distribution = .fillEqually
        secondaryStackView.spacing = DesignSystem.Spacing.sm.value
        
        secondaryStackView.addArrangedSubview(flashButton)
        secondaryStackView.addArrangedSubview(settingsButton)
        
        secondaryControlsContainer.addSubview(secondaryStackView)
        secondaryStackView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            secondaryStackView.topAnchor.constraint(equalTo: secondaryControlsContainer.topAnchor),
            secondaryStackView.leadingAnchor.constraint(equalTo: secondaryControlsContainer.leadingAnchor),
            secondaryStackView.trailingAnchor.constraint(equalTo: secondaryControlsContainer.trailingAnchor),
            secondaryStackView.bottomAnchor.constraint(equalTo: secondaryControlsContainer.bottomAnchor)
        ])
    }
    
    private func configureRecordingMode() {
        // Add recording controls
        controlsStackView.addArrangedSubview(stopButton)
        controlsStackView.addArrangedSubview(pauseButton)
        
        // Minimal controls when recording
        let secondaryStackView = UIStackView()
        secondaryStackView.axis = .horizontal
        secondaryStackView.distribution = .fillEqually
        secondaryStackView.spacing = DesignSystem.Spacing.sm.value
        
        secondaryStackView.addArrangedSubview(flipCameraButton)
        secondaryStackView.addArrangedSubview(flashButton)
        
        secondaryControlsContainer.addSubview(secondaryStackView)
        secondaryStackView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            secondaryStackView.topAnchor.constraint(equalTo: secondaryControlsContainer.topAnchor),
            secondaryStackView.leadingAnchor.constraint(equalTo: secondaryControlsContainer.leadingAnchor),
            secondaryStackView.trailingAnchor.constraint(equalTo: secondaryControlsContainer.trailingAnchor),
            secondaryStackView.bottomAnchor.constraint(equalTo: secondaryControlsContainer.bottomAnchor)
        ])
    }
    
    private func updateMaterialAppearance(for mode: RecordingMode) {
        switch mode {
        case .recording:
            primaryMaterialView.updateMaterialStyle(.regular)
            primaryMaterialView.layer.borderColor = EnhancedColorSystem.DynamicColor.recordingActive.color.cgColor
            primaryMaterialView.layer.borderWidth = 2
        case .paused:
            primaryMaterialView.updateMaterialStyle(.systemMaterial)
            primaryMaterialView.layer.borderColor = EnhancedColorSystem.DynamicColor.warning.color.cgColor
            primaryMaterialView.layer.borderWidth = 1
        default:
            primaryMaterialView.updateMaterialStyle(.regular)
            primaryMaterialView.layer.borderWidth = 0
        }
    }
    
    // MARK: - Button Actions
    
    @objc private func recordButtonTapped() {
        onControlTapped?(.record)
        HapticFeedbackManager.shared.recordingStart()
    }
    
    @objc private func stopButtonTapped() {
        onControlTapped?(.stop)
        HapticFeedbackManager.shared.recordingStop()
    }
    
    @objc private func pauseButtonTapped() {
        onControlTapped?(.pause)
        HapticFeedbackManager.shared.mediumImpact()
    }
    
    @objc private func resumeButtonTapped() {
        onControlTapped?(.resume)
        HapticFeedbackManager.shared.mediumImpact()
    }
    
    @objc private func flipCameraButtonTapped() {
        onControlTapped?(.flipCamera)
        HapticFeedbackManager.shared.cameraSwitch()
    }
    
    @objc private func flashButtonTapped() {
        onControlTapped?(.flash)
        HapticFeedbackManager.shared.flashToggle()
        
        // Update flash button icon
        let newImage = flashButton.currentImage == UIImage(systemName: "bolt.slash") ? 
            UIImage(systemName: "bolt.fill") : 
            UIImage(systemName: "bolt.slash")
        flashButton.setImage(newImage, for: .normal)
    }
    
    @objc private func focusButtonTapped() {
        onControlTapped?(.focus)
        HapticFeedbackManager.shared.focusAdjustment()
    }
    
    @objc private func zoomButtonTapped() {
        onControlTapped?(.zoom)
        HapticFeedbackManager.shared.zoomAdjustment()
    }
    
    @objc private func photoModeButtonTapped() {
        onControlTapped?(.photoMode)
        HapticFeedbackManager.shared.selectionChanged()
        updateUIForMode(.photo)
    }
    
    @objc private func videoModeButtonTapped() {
        onControlTapped?(.videoMode)
        HapticFeedbackManager.shared.selectionChanged()
        updateUIForMode(.video)
    }
    
    @objc private func slowMotionModeButtonTapped() {
        onControlTapped?(.slowMotionMode)
        HapticFeedbackManager.shared.selectionChanged()
        updateUIForMode(.slowMotion)
    }
    
    @objc private func timeLapseModeButtonTapped() {
        onControlTapped?(.timeLapseMode)
        HapticFeedbackManager.shared.selectionChanged()
        updateUIForMode(.timeLapse)
    }
    
    @objc private func settingsButtonTapped() {
        onControlTapped?(.settings)
        HapticFeedbackManager.shared.lightImpact()
    }
    
    @objc private func effectsButtonTapped() {
        onControlTapped?(.effects)
        HapticFeedbackManager.shared.lightImpact()
    }
    
    @objc private func timerButtonTapped() {
        onControlTapped?(.timer)
        HapticFeedbackManager.shared.lightImpact()
    }
    
    @objc private func qualityButtonTapped() {
        onControlTapped?(.quality)
        HapticFeedbackManager.shared.qualityChange()
    }
    
    // MARK: - Public Methods
    
    /// Updates the flash button state
    func updateFlashState(isOn: Bool) {
        let imageName = isOn ? "bolt.fill" : "bolt.slash"
        flashButton.setImage(UIImage(systemName: imageName), for: .normal)
    }
    
    /// Updates the recording timer display
    func updateRecordingTimer(elapsedTime: TimeInterval) {
        // This would update a timer label if one was added
    }
    
    /// Updates the recording duration display
    func updateRecordingDuration(duration: String) {
        // This would update a duration label if one was added
    }
    
    /// Enables or disables specific controls
    func setControlEnabled(_ controlType: ControlType, enabled: Bool) {
        let button: UIButton
        
        switch controlType {
        case .record:
            button = recordButton
        case .stop:
            button = stopButton
        case .pause:
            button = pauseButton
        case .resume:
            button = resumeButton
        case .flipCamera:
            button = flipCameraButton
        case .flash:
            button = flashButton
        case .focus:
            button = focusButton
        case .zoom:
            button = zoomButton
        case .photoMode:
            button = photoModeButton
        case .videoMode:
            button = videoModeButton
        case .slowMotionMode:
            button = slowMotionModeButton
        case .timeLapseMode:
            button = timeLapseModeButton
        case .settings:
            button = settingsButton
        case .effects:
            button = effectsButton
        case .timer:
            button = timerButton
        case .quality:
            button = qualityButton
        }
        
        button.isEnabled = enabled
        button.alpha = enabled ? 1.0 : 0.5
    }
}