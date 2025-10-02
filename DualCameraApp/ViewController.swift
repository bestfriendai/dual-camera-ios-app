//
//  ViewController.swift
//  DualCameraApp
//
//  Enhanced dual-camera app with glassmorphism UI and robust error handling
//

import UIKit
import AVFoundation

class ViewController: UIViewController {

    // MARK: - Properties
    let dualCameraManager = DualCameraManager()
    let permissionManager = PermissionManager.shared

    var isCameraSetupComplete = false
    var isRecording = false
    var recordingTimer: Timer?
    var recordingStartTime: Date?
    var isFrontViewPrimary = true
    var isPhotoMode = false
    var isGridVisible = false
    var isPresentingAlert = false

    // MARK: - UI Components - Camera Views
    let cameraStackView = UIStackView()
    let frontCameraPreview = CameraPreviewView()
    let backCameraPreview = CameraPreviewView()
    let topGradient = CAGradientLayer()
    let bottomGradient = CAGradientLayer()
    let recordButton = AppleRecordButton()
    let statusLabel = UILabel()
    let recordingTimerLabel = UILabel()
    let timerBlurView = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))
    let flashButton = AppleCameraButton()
    let swapCameraButton = AppleCameraButton()
    let qualityButton = AppleCameraButton()
    let galleryButton = AppleCameraButton()
    let gridButton = AppleCameraButton()
    let modeSegmentedControl = UISegmentedControl(items: ["Video", "Photo"])
    let mergeVideosButton = AppleCameraButton()
    let progressView = UIProgressView(progressViewStyle: .default)
    let activityIndicator = UIActivityIndicatorView(style: .large)
    let gridOverlayView = UIView()
    let storageLabel = UILabel()
    let permissionStatusLabel = UILabel()
    
    // MARK: - Enhanced Recording Controls
    let visualCountdownView = UIView()
    private var isCountingDown = false
    private var countdownTimer: Timer?
    private let settingsManager = SettingsManagerStub()
    
    // MARK: - Triple Output Controls
    let tripleOutputControlView = UIView()
    let tripleOutputButton = AppleCameraButton()
    
    // MARK: - Advanced Camera Controls
    let cameraControlsView = UIView()
    private var advancedCameraControlsManager: AdvancedCameraControlsManagerStub?
    private var showAdvancedControls = false
    
    // MARK: - Audio Controls
    let audioControlsView = UIView()
    private var showAudioControls = false
    let audioSourceButton = AppleCameraButton()
    
    // MARK: - Stub Classes
    class SettingsManagerStub {
        var videoQuality: VideoQuality = .hd1080
        var enableGrid: Bool = false
        var enableHapticFeedback: Bool = true
        var enableVisualCountdown: Bool = false
        var countdownDuration: Int = 3
    }
    
    class AdvancedCameraControlsManagerStub {
        // Placeholder
    }
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()

        StartupOptimizer.shared.beginStartupOptimization()
        PerformanceMonitor.shared.beginAppLaunch()
        PerformanceMonitor.shared.beginCameraSetup()

        setupUI()
        
        DispatchQueue.main.async {
            self.setupNotifications()
            self.setupErrorHandling()
        }
        
        StartupOptimizer.shared.beginPhase(.permissionCheck)
        requestCameraPermissions()

        DispatchQueue.global(qos: .utility).async {
            self.warmUpCameraSystem()
            
            DispatchQueue.main.async {
                self.startStorageMonitoring()
                self.setupEnhancedControls()
                self.setupPerformanceMonitoring()
            }
        }

        PerformanceMonitor.shared.endAppLaunch()
    }
    
    // Hide status bar for fullscreen camera experience
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    override var prefersHomeIndicatorAutoHidden: Bool {
        return true
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        print("VIEWCONTROLLER: viewWillAppear - cameraSetupComplete: \(isCameraSetupComplete)")
        if isCameraSetupComplete {
            dualCameraManager.startSessions()
        } else {
            print("VIEWCONTROLLER: Camera not setup yet, will start when setup completes")
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if isCameraSetupComplete {
            dualCameraManager.stopSessions()
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Setup
    private func setupUI() {
        // Black background (camera fills screen)
        view.backgroundColor = .black
        
        // Camera views
        setupCameraViews()
        
        // Apple-style dark gradients
        setupGradients()
        
        // Controls
        setupControls()
        
        // Constraints
        setupConstraints()
    }
    
    private func setupGradients() {
        // Top gradient - Apple Camera style
        topGradient.colors = [
            UIColor.black.withAlphaComponent(0.6).cgColor,
            UIColor.black.withAlphaComponent(0.0).cgColor
        ]
        topGradient.locations = [0.0, 1.0]
        topGradient.startPoint = CGPoint(x: 0.5, y: 0)
        topGradient.endPoint = CGPoint(x: 0.5, y: 1)
        view.layer.addSublayer(topGradient)
        
        // Bottom gradient - Apple Camera style
        bottomGradient.colors = [
            UIColor.black.withAlphaComponent(0.0).cgColor,
            UIColor.black.withAlphaComponent(0.7).cgColor
        ]
        bottomGradient.locations = [0.0, 1.0]
        bottomGradient.startPoint = CGPoint(x: 0.5, y: 0)
        bottomGradient.endPoint = CGPoint(x: 0.5, y: 1)
        view.layer.addSublayer(bottomGradient)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        // Update gradient frames
        topGradient.frame = CGRect(x: 0, y: 0, width: view.bounds.width, height: 150)
        bottomGradient.frame = CGRect(x: 0, y: view.bounds.height - 220, width: view.bounds.width, height: 220)
    }
    
    private func setupCameraViews() {
        // Change to vertical layout - front on top, back on bottom
        cameraStackView.axis = .vertical
        cameraStackView.alignment = .fill
        cameraStackView.distribution = .fillEqually
        cameraStackView.spacing = 0
        cameraStackView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(cameraStackView)

        // Configure front camera preview - top half, full width, no rounded corners
        frontCameraPreview.title = "Front Camera"
        frontCameraPreview.translatesAutoresizingMaskIntoConstraints = false
        frontCameraPreview.isUserInteractionEnabled = true
        frontCameraPreview.layer.cornerRadius = 0
        frontCameraPreview.clipsToBounds = true

        // Configure back camera preview - bottom half, full width, no rounded corners
        backCameraPreview.title = "Back Camera"
        backCameraPreview.translatesAutoresizingMaskIntoConstraints = false
        backCameraPreview.isUserInteractionEnabled = true
        backCameraPreview.layer.cornerRadius = 0
        backCameraPreview.clipsToBounds = true

        cameraStackView.addArrangedSubview(frontCameraPreview)
        cameraStackView.addArrangedSubview(backCameraPreview)

        // Gestures for front camera
        let frontPinch = UIPinchGestureRecognizer(target: self, action: #selector(handleFrontPinch(_:)))
        frontCameraPreview.addGestureRecognizer(frontPinch)

        let frontTap = UITapGestureRecognizer(target: self, action: #selector(handleFrontTap(_:)))
        frontCameraPreview.addGestureRecognizer(frontTap)

        // Gestures for back camera
        let backPinch = UIPinchGestureRecognizer(target: self, action: #selector(handleBackPinch(_:)))
        backCameraPreview.addGestureRecognizer(backPinch)

        let backTap = UITapGestureRecognizer(target: self, action: #selector(handleBackTap(_:)))
        backCameraPreview.addGestureRecognizer(backTap)
    }
    
    private func setupControls() {
        // APPLE MINIMAL STYLE - No containers, just gradients and buttons
        
        // Record button - Apple's simple white circle
        recordButton.translatesAutoresizingMaskIntoConstraints = false
        recordButton.addTarget(self, action: #selector(recordButtonTapped), for: .touchUpInside)
        view.addSubview(recordButton)
        
        // Recording timer - iOS 26 style (top center with blur)
        timerBlurView.layer.cornerRadius = 18
        timerBlurView.clipsToBounds = true
        timerBlurView.translatesAutoresizingMaskIntoConstraints = false
        timerBlurView.isHidden = true
        view.addSubview(timerBlurView)
        
        recordingTimerLabel.text = "0:00"
        recordingTimerLabel.textColor = .systemRed
        recordingTimerLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 17, weight: .semibold)
        recordingTimerLabel.textAlignment = .center
        recordingTimerLabel.translatesAutoresizingMaskIntoConstraints = false
        timerBlurView.contentView.addSubview(recordingTimerLabel)
        
        // Status label - minimized
        statusLabel.text = ""
        statusLabel.textColor = .white
        statusLabel.font = UIFont.systemFont(ofSize: 12, weight: .medium)
        statusLabel.textAlignment = .center
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(statusLabel)
        
        // Flash button - Apple minimal
        let flashImg = UIImage(systemName: "bolt.slash.fill")?.withRenderingMode(.alwaysTemplate)
        flashButton.setImage(flashImg, for: .normal)
        flashButton.tintColor = .white
        flashButton.imageView?.tintColor = .white
        flashButton.translatesAutoresizingMaskIntoConstraints = false
        flashButton.addTarget(self, action: #selector(flashButtonTapped), for: .touchUpInside)
        view.addSubview(flashButton)

        // Swap camera button - modern glassmorphism
        let swapImg = UIImage(systemName: "arrow.triangle.2.circlepath")?.withRenderingMode(.alwaysTemplate)
        swapCameraButton.setImage(swapImg, for: .normal)
        swapCameraButton.tintColor = .white
        swapCameraButton.imageView?.tintColor = .white
        swapCameraButton.translatesAutoresizingMaskIntoConstraints = false
        swapCameraButton.addTarget(self, action: #selector(swapCameraButtonTapped), for: .touchUpInside)
        swapCameraButton.backgroundColor = .clear
        view.addSubview(swapCameraButton)
        
        // Merge button - iOS 26 style
        mergeVideosButton.setTitle("Merge", for: .normal)
        mergeVideosButton.setTitleColor(.white, for: .normal)
        mergeVideosButton.titleLabel?.font = UIFont.systemFont(ofSize: 15, weight: .semibold)
        mergeVideosButton.translatesAutoresizingMaskIntoConstraints = false
        mergeVideosButton.addTarget(self, action: #selector(mergeVideosButtonTapped), for: .touchUpInside)
        mergeVideosButton.isEnabled = false
        mergeVideosButton.alpha = 0.5
        view.addSubview(mergeVideosButton)
        
        // Progress view
        progressView.translatesAutoresizingMaskIntoConstraints = false
        progressView.progressTintColor = .systemBlue
        progressView.trackTintColor = .systemGray
        progressView.isHidden = true
        view.addSubview(progressView)
        
        // Top controls - iOS 26 style
        qualityButton.setTitle("HD", for: .normal)
        qualityButton.setTitleColor(.white, for: .normal)
        qualityButton.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        qualityButton.translatesAutoresizingMaskIntoConstraints = false
        qualityButton.addTarget(self, action: #selector(qualityButtonTapped), for: .touchUpInside)
        view.addSubview(qualityButton)
        
        let galleryImg = UIImage(systemName: "photo.on.rectangle")?.withRenderingMode(.alwaysTemplate)
        galleryButton.setImage(galleryImg, for: .normal)
        galleryButton.tintColor = .white
        galleryButton.imageView?.tintColor = .white
        galleryButton.translatesAutoresizingMaskIntoConstraints = false
        galleryButton.addTarget(self, action: #selector(galleryButtonTapped), for: .touchUpInside)
        view.addSubview(galleryButton)
        
        let gridImg = UIImage(systemName: "grid")?.withRenderingMode(.alwaysTemplate)
        gridButton.setImage(gridImg, for: .normal)
        gridButton.tintColor = .white
        gridButton.imageView?.tintColor = .white
        gridButton.translatesAutoresizingMaskIntoConstraints = false
        gridButton.addTarget(self, action: #selector(gridButtonTapped), for: .touchUpInside)
        view.addSubview(gridButton)
        
        // Triple output mode button
        tripleOutputButton.setTitle("All", for: .normal)
        tripleOutputButton.setTitleColor(.white, for: .normal)
        tripleOutputButton.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        tripleOutputButton.translatesAutoresizingMaskIntoConstraints = false
        tripleOutputButton.addTarget(self, action: #selector(tripleOutputButtonTapped), for: .touchUpInside)
        view.addSubview(tripleOutputButton)
        
        // Audio source button
        let micImg = UIImage(systemName: "mic.fill")?.withRenderingMode(.alwaysTemplate)
        audioSourceButton.setImage(micImg, for: .normal)
        audioSourceButton.tintColor = .white
        audioSourceButton.imageView?.tintColor = .white
        audioSourceButton.translatesAutoresizingMaskIntoConstraints = false
        audioSourceButton.addTarget(self, action: #selector(audioSourceButtonTapped), for: .touchUpInside)
        view.addSubview(audioSourceButton)
        
        modeSegmentedControl.selectedSegmentIndex = 0
        modeSegmentedControl.translatesAutoresizingMaskIntoConstraints = false
        modeSegmentedControl.addTarget(self, action: #selector(modeChanged), for: .valueChanged)
        modeSegmentedControl.backgroundColor = .clear
        modeSegmentedControl.selectedSegmentTintColor = UIColor.systemYellow
        modeSegmentedControl.setTitleTextAttributes([
            .foregroundColor: UIColor.white.withAlphaComponent(0.6),
            .font: UIFont.systemFont(ofSize: 13, weight: .medium)
        ], for: .normal)
        modeSegmentedControl.setTitleTextAttributes([
            .foregroundColor: UIColor.black,
            .font: UIFont.systemFont(ofSize: 13, weight: .semibold)
        ], for: .selected)
        view.addSubview(modeSegmentedControl)
        
        // Grid overlay
        gridOverlayView.translatesAutoresizingMaskIntoConstraints = false
        gridOverlayView.isUserInteractionEnabled = false
        gridOverlayView.isHidden = true
        view.addSubview(gridOverlayView)
        setupGridLines()
        
        // Storage label
        storageLabel.textColor = .white.withAlphaComponent(0.7)
        storageLabel.font = UIFont.systemFont(ofSize: 11, weight: .medium)
        storageLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(storageLabel)
        
        // Activity indicator
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        activityIndicator.color = .white
        activityIndicator.hidesWhenStopped = true
        view.addSubview(activityIndicator)
        activityIndicator.startAnimating()
    }
    
    private func setupEnhancedControls() {
        // Disabled - using stub implementation
        // visualCountdownView.translatesAutoresizingMaskIntoConstraints = false
        // view.addSubview(visualCountdownView)
        
        // Load saved settings
        loadUserSettings()
    }
    
    private func loadUserSettings() {
        // Apply saved video quality
        dualCameraManager.videoQuality = settingsManager.videoQuality
        qualityButton.setTitle(settingsManager.videoQuality.rawValue, for: .normal)
        
        // Apply other saved settings
        if settingsManager.enableGrid {
            gridButtonTapped()
        }
        
        // Initialize haptic feedback settings
        HapticFeedbackManager.shared.updateHapticSettings(enabled: settingsManager.enableHapticFeedback)
    }

    private func beginRecordingCountdown() {
        guard !isCountingDown else { return }

        let duration = max(1, settingsManager.countdownDuration)
        isCountingDown = true
        statusLabel.text = "Recording begins in \(duration)s"
        if settingsManager.enableHapticFeedback {
            HapticFeedbackManager.shared.countdownTick(seconds: duration)
        }
        // visualCountdownView.startCountdown(from: duration)
        // Simulate countdown with timer
        var remaining = duration
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            remaining -= 1
            if remaining <= 0 {
                timer.invalidate()
                self?.startRecordingAfterCountdown()
            } else {
                self?.updateCountdownDisplay(seconds: remaining)
            }
        }
    }

    private func cancelRecordingCountdown() {
        isCountingDown = false
        countdownTimer?.invalidate()
        // visualCountdownView.stopCountdown()
        statusLabel.text = "Ready to record"
    }

    private func updateCountdownDisplay(seconds: Int) {
        guard isCountingDown else { return }
        if settingsManager.enableHapticFeedback {
            HapticFeedbackManager.shared.countdownTick(seconds: seconds)
        }
        statusLabel.text = seconds > 0 ? "Recording in \(seconds)s" : "Recording..."
    }

    private func startRecordingAfterCountdown() {
        guard isCountingDown else { return }
        isCountingDown = false
        dualCameraManager.startRecording()
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // Camera stack view - full screen vertical layout (front top, back bottom)
            cameraStackView.topAnchor.constraint(equalTo: view.topAnchor),
            cameraStackView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            cameraStackView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            cameraStackView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            // Record button - Apple style centered at bottom
            recordButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            recordButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -40),
            recordButton.widthAnchor.constraint(equalToConstant: 70),
            recordButton.heightAnchor.constraint(equalToConstant: 70),

            // Timer blur view
            timerBlurView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            timerBlurView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            timerBlurView.widthAnchor.constraint(equalToConstant: 80),
            timerBlurView.heightAnchor.constraint(equalToConstant: 36),
            
            // Recording timer label
            recordingTimerLabel.centerXAnchor.constraint(equalTo: timerBlurView.centerXAnchor),
            recordingTimerLabel.centerYAnchor.constraint(equalTo: timerBlurView.centerYAnchor),
            
            // Status label (hidden by default)
            statusLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 60),
            statusLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            // Flash button - left of record button
            flashButton.centerYAnchor.constraint(equalTo: recordButton.centerYAnchor),
            flashButton.trailingAnchor.constraint(equalTo: recordButton.leadingAnchor, constant: -40),
            flashButton.widthAnchor.constraint(equalToConstant: 40),
            flashButton.heightAnchor.constraint(equalToConstant: 40),

            // Gallery button - right of record button
            galleryButton.centerYAnchor.constraint(equalTo: recordButton.centerYAnchor),
            galleryButton.leadingAnchor.constraint(equalTo: recordButton.trailingAnchor, constant: 40),
            galleryButton.widthAnchor.constraint(equalToConstant: 40),
            galleryButton.heightAnchor.constraint(equalToConstant: 40),
            
            // Swap camera button - top right corner
            swapCameraButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            swapCameraButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            swapCameraButton.widthAnchor.constraint(equalToConstant: 40),
            swapCameraButton.heightAnchor.constraint(equalToConstant: 40),

            // Merge button - top of controls area
            mergeVideosButton.topAnchor.constraint(equalTo: view.topAnchor, constant: 15),
            mergeVideosButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            mergeVideosButton.widthAnchor.constraint(equalToConstant: 120),
            mergeVideosButton.heightAnchor.constraint(equalToConstant: 35),

            // Progress view
            progressView.bottomAnchor.constraint(equalTo: mergeVideosButton.topAnchor, constant: -10),
            progressView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 15),
            progressView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -15),

            // Mode segmented control - bottom above record button
            modeSegmentedControl.bottomAnchor.constraint(equalTo: recordButton.topAnchor, constant: -30),
            modeSegmentedControl.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            modeSegmentedControl.widthAnchor.constraint(equalToConstant: 160),
            modeSegmentedControl.heightAnchor.constraint(equalToConstant: 28),

            // Quality button - overlay at top left
            qualityButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            qualityButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            qualityButton.widthAnchor.constraint(equalToConstant: 50),
            qualityButton.heightAnchor.constraint(equalToConstant: 40),

            // Grid button - top left corner
            gridButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            gridButton.trailingAnchor.constraint(equalTo: swapCameraButton.leadingAnchor, constant: -12),
            gridButton.widthAnchor.constraint(equalToConstant: 40),
            gridButton.heightAnchor.constraint(equalToConstant: 40),
            
            // Triple output button - below quality button
            tripleOutputButton.topAnchor.constraint(equalTo: qualityButton.bottomAnchor, constant: 12),
            tripleOutputButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            tripleOutputButton.widthAnchor.constraint(equalToConstant: 50),
            tripleOutputButton.heightAnchor.constraint(equalToConstant: 40),
            
            // Audio source button - below triple output button
            audioSourceButton.topAnchor.constraint(equalTo: tripleOutputButton.bottomAnchor, constant: 12),
            audioSourceButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            audioSourceButton.widthAnchor.constraint(equalToConstant: 40),
            audioSourceButton.heightAnchor.constraint(equalToConstant: 40),

            // Grid overlay
            gridOverlayView.topAnchor.constraint(equalTo: cameraStackView.topAnchor),
            gridOverlayView.leadingAnchor.constraint(equalTo: cameraStackView.leadingAnchor),
            gridOverlayView.trailingAnchor.constraint(equalTo: cameraStackView.trailingAnchor),
            gridOverlayView.bottomAnchor.constraint(equalTo: cameraStackView.bottomAnchor),

            // Storage label
            storageLabel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -10),
            storageLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            // Activity indicator
            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    private func setupGridLines() {
        for i in 1...2 {
            let horizontalLine = UIView()
            horizontalLine.backgroundColor = .white.withAlphaComponent(0.5)
            horizontalLine.translatesAutoresizingMaskIntoConstraints = false
            gridOverlayView.addSubview(horizontalLine)

            NSLayoutConstraint.activate([
                horizontalLine.leadingAnchor.constraint(equalTo: gridOverlayView.leadingAnchor),
                horizontalLine.trailingAnchor.constraint(equalTo: gridOverlayView.trailingAnchor),
                horizontalLine.heightAnchor.constraint(equalToConstant: 1),
                horizontalLine.topAnchor.constraint(equalTo: gridOverlayView.topAnchor, constant: CGFloat(i) * gridOverlayView.frame.height / 3)
            ])

            let verticalLine = UIView()
            verticalLine.backgroundColor = .white.withAlphaComponent(0.5)
            verticalLine.translatesAutoresizingMaskIntoConstraints = false
            gridOverlayView.addSubview(verticalLine)

            NSLayoutConstraint.activate([
                verticalLine.topAnchor.constraint(equalTo: gridOverlayView.topAnchor),
                verticalLine.bottomAnchor.constraint(equalTo: gridOverlayView.bottomAnchor),
                verticalLine.widthAnchor.constraint(equalToConstant: 1),
                verticalLine.leadingAnchor.constraint(equalTo: gridOverlayView.leadingAnchor, constant: CGFloat(i) * gridOverlayView.frame.width / 3)
            ])
        }
    }

    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillResignActive),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        
        // Memory warning notification
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
        
        // Error recovery notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleForceStopRecording),
            name: .forceStopRecording,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleErrorRecovered),
            name: .errorRecovered,
            object: nil
        )
    }
    
    private func setupErrorHandling() {
        // Set up error handling manager
        ErrorHandlingManager.shared.setRecoveryState(false)
    }
    
    @objc private func handleForceStopRecording() {
        if isRecording {
            dualCameraManager.stopRecording()
            statusLabel.text = "Recording stopped due to error"
        }
    }
    
    @objc private func handleErrorRecovered() {
        statusLabel.text = "Error recovered ✓"
        
        // Restore performance after recovery
        frontCameraPreview.restorePerformanceAfterMemoryPressure()
        backCameraPreview.restorePerformanceAfterMemoryPressure()
        
        // Clear recovery state
        ErrorHandlingManager.shared.clearRecoveryState()
        
        // Update status after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.statusLabel.text = "Ready to record"
        }
    }
    
    private func setupPerformanceMonitoring() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
                self?.logPerformanceMetrics()
            }
        }
    }
    
    private func warmUpCameraSystem() {
        // Optimized camera warmup with minimal overhead
        let warmupQueue = DispatchQueue(label: "camera.warmup", qos: .userInitiated)
        
        warmupQueue.async {
            // Pre-discover camera devices
            let discoverySession = AVCaptureDevice.DiscoverySession(
                deviceTypes: [.builtInWideAngleCamera, .builtInTelephotoCamera, .builtInUltraWideCamera],
                mediaType: .video,
                position: .unspecified
            )
            _ = discoverySession.devices
            
            // Pre-warm Metal device for frame composition
            _ = MTLCreateSystemDefaultDevice()
            
            PerformanceMonitor.shared.logEvent("Camera Warmup", "Camera system warmed up")
        }
    }
    
    @objc private func handleMemoryWarning() {
        print("VIEWCONTROLLER: Memory warning received")
        
        // Reduce quality temporarily
        dualCameraManager.reduceQualityForMemoryPressure()
        
        // Clear any non-essential caches
        clearTemporaryCaches()
        
        // Notify user if needed
        showMemoryWarning()
    }
    
    private func clearTemporaryCaches() {
        // Clear image caches and temporary data
        URLCache.shared.removeAllCachedResponses()
        
        // Clear any preview layer caches
        frontCameraPreview.clearCache()
        backCameraPreview.clearCache()
        
        PerformanceMonitor.shared.logEvent("Memory Management", "Cleared temporary caches")
    }
    
    private func showMemoryWarning() {
        // Use error handling manager for memory warnings
        ErrorHandlingManager.shared.handleCustomError(type: .memoryPressure, in: self) {
            // Additional recovery actions if needed
            self.frontCameraPreview.reducePerformanceForMemoryPressure()
            self.backCameraPreview.reducePerformanceForMemoryPressure()
        }
    }
    
    private func logPerformanceMetrics() {
        let metrics = PerformanceMonitor.shared.getPerformanceSummary()
        let avgFrameRate = metrics["averageFrameRate"] as? Double ?? 0
        let currentMemory = metrics["currentMemoryUsage"] as? Double ?? 0
        
        print("Performance Metrics - Frame Rate: \(String(format: "%.1f", avgFrameRate)) fps, Memory: \(String(format: "%.1f", currentMemory)) MB")
        
        // Log to performance monitor
        PerformanceMonitor.shared.logMemoryUsage()
        PerformanceMonitor.shared.logCPUUsage()
    }

    @objc private func appWillResignActive() {
        if isRecording {
            dualCameraManager.stopRecording()
        }
        if isCameraSetupComplete {
            dualCameraManager.stopSessions()
        }
    }

    @objc private func appDidBecomeActive() {
        if isCameraSetupComplete {
            dualCameraManager.startSessions()
        }
    }

    // MARK: - Camera Setup
    private func requestCameraPermissions() {
        print("VIEWCONTROLLER: Requesting camera permissions...")
        statusLabel.text = "Requesting permissions..."

        permissionManager.requestAllPermissions { [weak self] allGranted, deniedPermissions in
            guard let self = self else { return }

            if allGranted {
                print("VIEWCONTROLLER: All permissions granted")
                self.statusLabel.text = "Permissions granted ✓"
                self.setupCamerasAfterPermissions()
            } else {
                print("VIEWCONTROLLER: Permissions denied: \(deniedPermissions.map { $0.title })")
                self.statusLabel.text = "Permissions required"

                // Show alert for denied permissions
                let permissionNames = deniedPermissions.map { $0.title }.joined(separator: ", ")
                let message = "This app requires the following permissions to function properly:\n\n\(permissionNames)\n\nPlease enable them in Settings."

                let alert = UIAlertController(
                    title: "Permissions Required",
                    message: message,
                    preferredStyle: .alert
                )

                alert.addAction(UIAlertAction(title: "Open Settings", style: .default) { _ in
                    if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(settingsURL)
                    }
                })

                alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

                self.presentAlertSafely(alert)

                // Show which permissions are missing
                self.frontCameraPreview.showError(message: "Camera permission required")
                self.backCameraPreview.showError(message: "Camera permission required")
            }
        }
    }

    private func setupCamerasAfterPermissions() {
        print("VIEWCONTROLLER: Setting up cameras after permissions granted")
        
        StartupOptimizer.shared.beginPhase(.cameraDiscovery)
        
        dualCameraManager.delegate = self
        
        dualCameraManager.enableTripleOutput = true
        dualCameraManager.tripleOutputMode = .allFiles

        frontCameraPreview.showLoading(message: "Initializing cameras...")
        backCameraPreview.showLoading(message: "Initializing cameras...")

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            #if targetEnvironment(simulator)
            print("VIEWCONTROLLER: Running on simulator, setting up demo mode")
            // Simulator doesn't have real cameras, show demo mode
            DispatchQueue.main.async {
                self.setupSimulatorMode()
                StartupOptimizer.shared.completeStartup()
            }
            #else
            print("VIEWCONTROLLER: Running on device, setting up real cameras")
            self.dualCameraManager.setupCameras()
            #endif
        }
    }

    private func setupPreviewLayers() {
        print("VIEWCONTROLLER: Setting up preview layers")
        
        guard let frontLayer = dualCameraManager.frontPreviewLayer,
              let backLayer = dualCameraManager.backPreviewLayer else {
            print("VIEWCONTROLLER: ⚠️ Preview layers not available")
            handleCameraSetupFailure()
            return
        }

        print("VIEWCONTROLLER: Assigning preview layers to views")
        
        // CRITICAL FIX: Assign preview layers and force layout
        frontCameraPreview.previewLayer = frontLayer
        backCameraPreview.previewLayer = backLayer
        
        // Force immediate layout to ensure frames are correct
        view.setNeedsLayout()
        view.layoutIfNeeded()
        
        // Update preview layer frames to match view bounds
        frontLayer.frame = frontCameraPreview.bounds
        backLayer.frame = backCameraPreview.bounds
        
        print("VIEWCONTROLLER: ✅ Preview layers assigned - Front: \(frontCameraPreview.bounds), Back: \(backCameraPreview.bounds)")
    }

    private func setupSimulatorMode() {
        // Simulator mode - show placeholder content
        frontCameraPreview.showError(message: "Simulator Mode\nFront Camera")
        backCameraPreview.showError(message: "Simulator Mode\nBack Camera")

        activityIndicator.stopAnimating()
        statusLabel.text = "Simulator Mode - Demo Ready"
        isCameraSetupComplete = true

        // Enable basic functionality for testing UI
        frontCameraPreview.isActive = true
        backCameraPreview.isActive = true

        PerformanceMonitor.shared.endCameraSetup()
    }

    private func handleCameraSetupFailure() {
        statusLabel.text = "Camera setup failed"
        frontCameraPreview.showError(message: "Failed to initialize")
        backCameraPreview.showError(message: "Failed to initialize")
        activityIndicator.stopAnimating()

        // Show alert with troubleshooting
        let alert = UIAlertController(
            title: "Camera Setup Failed",
            message: "Unable to initialize dual cameras. This feature requires a device with multiple cameras and iOS 13+.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        presentAlertSafely(alert)
    }

    // MARK: - Actions
    @objc private func recordButtonTapped() {
        print("VIEWCONTROLLER: Record button tapped, isPhotoMode: \(isPhotoMode), isRecording: \(isRecording), cameraSetupComplete: \(isCameraSetupComplete)")
        
        // CRITICAL: Check if camera is ready
        guard isCameraSetupComplete else {
            print("VIEWCONTROLLER: ⚠️ Camera not ready yet")
            statusLabel.text = "Camera initializing..."
            return
        }
        
        if isPhotoMode {
            dualCameraManager.capturePhoto()
            animateCaptureFlash()
            return
        }

        if isRecording {
            print("VIEWCONTROLLER: Stopping recording...")
            dualCameraManager.stopRecording()
            return
        }

        if isCountingDown {
            cancelRecordingCountdown()
            return
        }

        print("VIEWCONTROLLER: Starting recording...")
        if settingsManager.enableVisualCountdown {
            beginRecordingCountdown()
        } else {
            dualCameraManager.startRecording()
        }
    }

    @objc private func flashButtonTapped() {
        dualCameraManager.toggleFlash()
        let imageName = dualCameraManager.isFlashOn ? "bolt.fill" : "bolt.slash.fill"
        let flashImg = UIImage(systemName: imageName)?.withRenderingMode(.alwaysTemplate)
        flashButton.setImage(flashImg, for: .normal)
        flashButton.tintColor = dualCameraManager.isFlashOn ? .systemYellow : .white
        flashButton.imageView?.tintColor = dualCameraManager.isFlashOn ? .systemYellow : .white
    }

    @objc private func swapCameraButtonTapped() {
        isFrontViewPrimary.toggle()
        updateCameraStackOrder()
    }

    private func updateCameraStackOrder() {
        let orderedViews: [UIView] = isFrontViewPrimary ?
            [frontCameraPreview, backCameraPreview] :
            [backCameraPreview, frontCameraPreview]

        UIView.animate(withDuration: 0.3, delay: 0, options: [.curveEaseInOut]) {
            for view in self.cameraStackView.arrangedSubviews {
                self.cameraStackView.removeArrangedSubview(view)
                view.removeFromSuperview()
            }

            for view in orderedViews {
                self.cameraStackView.addArrangedSubview(view)
            }

            self.view.layoutIfNeeded()
        }
    }

    @objc private func qualityButtonTapped() {
        let alert = UIAlertController(title: "Video Quality", message: nil, preferredStyle: .actionSheet)

        for quality in VideoQuality.allCases {
            alert.addAction(UIAlertAction(title: quality.rawValue, style: .default) { [weak self] _ in
                self?.dualCameraManager.videoQuality = quality
                self?.qualityButton.setTitle(quality.rawValue, for: .normal)
            })
        }

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    @objc private func galleryButtonTapped() {
        let galleryVC = VideoGalleryViewController()
        galleryVC.modalPresentationStyle = .fullScreen
        present(galleryVC, animated: true)
    }

    @objc private func gridButtonTapped() {
        isGridVisible.toggle()
        gridOverlayView.isHidden = !isGridVisible
        gridButton.tintColor = isGridVisible ? .systemYellow : .white
    }
    
    @objc private func tripleOutputButtonTapped() {
        let alert = UIAlertController(title: "Triple Output Mode", message: "Choose which files to save during recording", preferredStyle: .actionSheet)
        
        alert.addAction(UIAlertAction(title: "All Files (Front, Back, Combined)", style: .default) { [weak self] _ in
            self?.dualCameraManager.tripleOutputMode = .allFiles
            self?.tripleOutputButton.setTitle("All", for: .normal)
        })
        
        alert.addAction(UIAlertAction(title: "Combined Only", style: .default) { [weak self] _ in
            self?.dualCameraManager.tripleOutputMode = .combinedOnly
            self?.tripleOutputButton.setTitle("1x", for: .normal)
        })
        
        alert.addAction(UIAlertAction(title: "Front & Back Only", style: .default) { [weak self] _ in
            self?.dualCameraManager.tripleOutputMode = .frontBackOnly
            self?.tripleOutputButton.setTitle("2x", for: .normal)
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }
    
    @objc private func audioSourceButtonTapped() {
        let alert = UIAlertController(title: "Audio Source", message: "Select the microphone to use for recording", preferredStyle: .actionSheet)
        
        alert.addAction(UIAlertAction(title: "Built-in Microphone", style: .default) { [weak self] _ in
            self?.audioSourceButton.tintColor = .white
        })
        
        alert.addAction(UIAlertAction(title: "Bluetooth Microphone", style: .default) { [weak self] _ in
            self?.audioSourceButton.tintColor = .systemBlue
        })
        
        alert.addAction(UIAlertAction(title: "Headset Microphone", style: .default) { [weak self] _ in
            self?.audioSourceButton.tintColor = .systemGreen
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    @objc private func modeChanged() {
        isPhotoMode = modeSegmentedControl.selectedSegmentIndex == 1
        updateUIForMode()
    }

    private func updateUIForMode() {
        if isPhotoMode {
            recordButton.setImage(UIImage(systemName: "camera.circle.fill"), for: .normal)
            recordingTimerLabel.isHidden = true
        } else {
            recordButton.setImage(UIImage(systemName: "record.circle.fill"), for: .normal)
        }
    }

    @objc private func mergeVideosButtonTapped() {
        let urls = dualCameraManager.getRecordingURLs()
        guard let frontURL = urls.front,
              let backURL = urls.back else {
            statusLabel.text = "No recordings to merge"
            return
        }
        
        statusLabel.text = "Merging videos..."
        progressView.isHidden = false
        progressView.progress = 0.0
        
        let merger = VideoMerger()
        merger.mergeVideos(frontURL: frontURL, backURL: backURL, layout: VideoMerger.VideoLayout.sideBySide, quality: dualCameraManager.videoQuality) { [weak self] (result: Result<URL, Error>) in
            DispatchQueue.main.async {
                self?.progressView.isHidden = true
                switch result {
                case .success(let url):
                    self?.statusLabel.text = "Videos merged successfully ✓"
                    print("Merged video saved to: \(url)")
                case .failure(let error):
                    self?.statusLabel.text = "Merge failed: \(error.localizedDescription)"
                    print("Merge failed: \(error)")
                }
            }
        }
    }

    // MARK: - Gesture Handlers
    @objc private func handleFrontPinch(_ gesture: UIPinchGestureRecognizer) {
        guard let device = dualCameraManager.frontCamera else { return }

        if gesture.state == .changed {
            let maxZoom = min(device.activeFormat.videoMaxZoomFactor, 10.0)
            let pinchVelocity = gesture.velocity
            var zoomFactor = device.videoZoomFactor + (pinchVelocity > 0 ? 0.1 : -0.1)
            zoomFactor = max(1.0, min(zoomFactor, maxZoom))

            do {
                try device.lockForConfiguration()
                device.videoZoomFactor = zoomFactor
                device.unlockForConfiguration()
            } catch {
                print("Error adjusting zoom: \(error)")
            }
        }
    }

    @objc private func handleBackPinch(_ gesture: UIPinchGestureRecognizer) {
        guard let device = dualCameraManager.backCamera else { return }

        if gesture.state == .changed {
            let maxZoom = min(device.activeFormat.videoMaxZoomFactor, 10.0)
            let pinchVelocity = gesture.velocity
            var zoomFactor = device.videoZoomFactor + (pinchVelocity > 0 ? 0.1 : -0.1)
            zoomFactor = max(1.0, min(zoomFactor, maxZoom))

            do {
                try device.lockForConfiguration()
                device.videoZoomFactor = zoomFactor
                device.unlockForConfiguration()
            } catch {
                print("Error adjusting zoom: \(error)")
            }
        }
    }

    @objc private func handleFrontTap(_ gesture: UITapGestureRecognizer) {
        let point = gesture.location(in: frontCameraPreview)
        focusCamera(dualCameraManager.frontCamera, at: point, in: frontCameraPreview)
        frontCameraPreview.showFocusIndicator(at: point)
    }

    @objc private func handleBackTap(_ gesture: UITapGestureRecognizer) {
        let point = gesture.location(in: backCameraPreview)
        focusCamera(dualCameraManager.backCamera, at: point, in: backCameraPreview)
        backCameraPreview.showFocusIndicator(at: point)
    }

    private func focusCamera(_ device: AVCaptureDevice?, at point: CGPoint, in view: UIView) {
        guard let device = device else { return }

        let focusPoint = CGPoint(x: point.y / view.bounds.height, y: 1.0 - point.x / view.bounds.width)

        do {
            try device.lockForConfiguration()
            if device.isFocusPointOfInterestSupported {
                device.focusPointOfInterest = focusPoint
                device.focusMode = .autoFocus
            }
            if device.isExposurePointOfInterestSupported {
                device.exposurePointOfInterest = focusPoint
                device.exposureMode = .autoExpose
            }
            device.unlockForConfiguration()

            showFocusIndicator(at: point, in: view)
        } catch {
            print("Error focusing camera: \(error)")
        }
    }

    private func showFocusIndicator(at point: CGPoint, in view: UIView) {
        let focusView = UIView(frame: CGRect(x: 0, y: 0, width: 80, height: 80))
        focusView.center = point
        focusView.layer.borderColor = UIColor.systemYellow.cgColor
        focusView.layer.borderWidth = 2
        focusView.layer.cornerRadius = 40
        focusView.alpha = 0
        view.addSubview(focusView)

        UIView.animate(withDuration: 0.3, animations: {
            focusView.alpha = 1
        }) { _ in
            UIView.animate(withDuration: 0.3, delay: 0.5, animations: {
                focusView.alpha = 0
            }) { _ in
                focusView.removeFromSuperview()
            }
        }
    }

    private func animateCaptureFlash() {
        let flashView = UIView(frame: view.bounds)
        flashView.backgroundColor = .white
        flashView.alpha = 0
        view.addSubview(flashView)

        UIView.animate(withDuration: 0.1, animations: {
            flashView.alpha = 1
        }) { _ in
            UIView.animate(withDuration: 0.2) {
                flashView.alpha = 0
            } completion: { _ in
                flashView.removeFromSuperview()
            }
        }
    }

    private func presentAlertSafely(_ alertController: UIAlertController) {
        guard !isPresentingAlert else { return }

        isPresentingAlert = true

        present(alertController, animated: true) { [weak self] in
            // Reset the flag when the alert is dismissed
            self?.isPresentingAlert = false
        }
    }

    // MARK: - Storage Monitoring
    private func startStorageMonitoring() {
        Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            DispatchQueue.global(qos: .utility).async {
                self?.updateStorageLabel()
            }
        }
        updateStorageLabel()
    }

    private func updateStorageLabel() {
        if let attributes = try? FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory()),
           let freeSize = attributes[.systemFreeSize] as? NSNumber {
            let freeGB = Double(freeSize.int64Value) / 1_000_000_000
            
            DispatchQueue.main.async {
                self.storageLabel.text = String(format: "%.1f GB free", freeGB)
                
                // Check for low storage warning
                if freeGB < 1.0 {
                    self.showLowStorageWarning(freeGB: freeGB)
                }
            }
        }
    }
    
    private func showLowStorageWarning(freeGB: Double) {
        let alert = UIAlertController(
            title: "Low Storage Space",
            message: "Only \(String(format: "%.1f", freeGB)) GB of storage available. Consider deleting old recordings.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Open Gallery", style: .default) { _ in
            self.galleryButtonTapped()
        })
        
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        
        present(alert, animated: true)
    }
}

// MARK: - DualCameraManagerDelegate
extension ViewController: DualCameraManagerDelegate {
    func didStartRecording() {
        print("VIEWCONTROLLER: didStartRecording called")
        isRecording = true
        
        // CRITICAL FIX: Update the AppleRecordButton visual state
        recordButton.setRecording(true, animated: true)
        
        // Show timer blur view
        timerBlurView.isHidden = false
        recordingTimerLabel.isHidden = false
        recordingStartTime = Date()

        // Enhanced visual feedback on camera previews
        frontCameraPreview.startRecordingAnimation()
        backCameraPreview.startRecordingAnimation()

        recordingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self, let startTime = self.recordingStartTime else { return }
            let elapsed = Int(Date().timeIntervalSince(startTime))
            let minutes = elapsed / 60
            let seconds = elapsed % 60
            self.recordingTimerLabel.text = String(format: "%02d:%02d", minutes, seconds)
        }

        statusLabel.text = "Recording..."

        // Disable certain controls during recording
        swapCameraButton.isEnabled = false
        qualityButton.isEnabled = false
        modeSegmentedControl.isEnabled = false
        tripleOutputButton.isEnabled = false
        audioSourceButton.isEnabled = false
    }

    func didStopRecording() {
        print("VIEWCONTROLLER: didStopRecording called")
        isRecording = false
        
        // CRITICAL FIX: Update the AppleRecordButton visual state
        recordButton.setRecording(false, animated: true)
        
        // Hide timer blur view
        timerBlurView.isHidden = true
        recordingTimerLabel.isHidden = true
        recordingTimer?.invalidate()
        recordingTimer = nil

        // Stop visual feedback
        frontCameraPreview.stopRecordingAnimation()
        backCameraPreview.stopRecordingAnimation()

        statusLabel.text = "Recording saved ✓"
        mergeVideosButton.isEnabled = true
        mergeVideosButton.alpha = 1.0

        // Re-enable controls
        swapCameraButton.isEnabled = true
        qualityButton.isEnabled = true
        modeSegmentedControl.isEnabled = true
        tripleOutputButton.isEnabled = true
        audioSourceButton.isEnabled = true

        // Show success feedback
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.statusLabel.text = "Ready to record"
        }
    }

    func didCapturePhoto(frontImage: UIImage?, backImage: UIImage?) {
        statusLabel.text = "Photo captured ✓"

        // Flash effect
        let flashView = UIView(frame: view.bounds)
        flashView.backgroundColor = .white
        flashView.alpha = 0.8
        view.addSubview(flashView)

        UIView.animate(withDuration: 0.1, animations: {
            flashView.alpha = 0
        }) { _ in
            flashView.removeFromSuperview()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.statusLabel.text = "Ready to capture"
        }
    }

    func didFailWithError(_ error: Error) {
        statusLabel.text = "⚠️ Error: \(error.localizedDescription)"

        // Show error on preview views
        frontCameraPreview.showError(message: "Error occurred")
        backCameraPreview.showError(message: "Error occurred")

        // Show detailed alert
        let alert = UIAlertController(
            title: "Camera Error",
            message: error.localizedDescription,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        presentAlertSafely(alert)
    }

    func didUpdateVideoQuality(to quality: VideoQuality) {
        qualityButton.setTitle(quality.rawValue, for: .normal)
    }
    
    func didFinishCameraSetup() {
        print("VIEWCONTROLLER: didFinishCameraSetup called")
        setupPreviewLayers()
        activityIndicator.stopAnimating()
        timerBlurView.isHidden = true
        statusLabel.text = ""
        isCameraSetupComplete = true
        frontCameraPreview.isActive = true
        backCameraPreview.isActive = true
        PerformanceMonitor.shared.endCameraSetup()
        
        // CRITICAL: Start the camera session immediately after setup
        print("VIEWCONTROLLER: Starting camera sessions after setup...")
        dualCameraManager.startSessions()
        
        // Complete startup optimization
        StartupOptimizer.shared.completeStartup()
        
        // Log startup metrics
        let metrics = StartupOptimizer.shared.getStartupMetrics()
        print("STARTUP METRICS: \(metrics)")
    }
}


