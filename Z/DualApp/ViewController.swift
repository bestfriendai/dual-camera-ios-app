//
//  ViewController.swift
//  DualCameraApp
//
//  Enhanced dual-camera app with glassmorphism UI and robust error handling
//

import UIKit
import AVFoundation
import os.signpost

class ViewController: UIViewController {

    // MARK: - Properties
    private lazy var appController = CameraAppController()
    private let log = OSLog(subsystem: "com.dualcamera.app", category: "ViewController")
    private var viewLoadSignpostID: OSSignpostID?
    private var cameraInitSignpostID: OSSignpostID?

    private var controllerState = CameraAppController.State(phase: .idle, isRecording: false, statusMessage: nil)
    private var isCameraSetupComplete = false
    private var hasInitializedController = false
    var isRecording = false
    var recordingTimer: Timer?
    var recordingStartTime: Date?
    var isFrontViewPrimary = true
    var isPhotoMode = false
    var isGridVisible = false
    var isPresentingAlert = false

    private var dualCameraManager: DualCameraManager { appController.cameraManager }

    // MARK: - UI Components - Camera Views
    // CRITICAL: Use lazy initialization to avoid blocking app launch
    lazy var cameraStackView = UIStackView()
    lazy var frontCameraPreview = CameraPreviewView()
    lazy var backCameraPreview = CameraPreviewView()
    lazy var topGradient = CAGradientLayer()
    lazy var bottomGradient = CAGradientLayer()
    lazy var recordButton = AppleRecordButton()
    let statusLabel = UILabel()
    let recordingTimerLabel = UILabel()
    lazy var timerBlurView = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))
    lazy var flashButton = AppleCameraButton()
    lazy var swapCameraButton = AppleCameraButton()
    lazy var qualityButton = AppleCameraButton()
    lazy var galleryButton = AppleCameraButton()
    lazy var gridButton = AppleCameraButton()
    lazy var modeSegmentedControl = UISegmentedControl(items: ["Video", "Photo"])
    lazy var mergeVideosButton = AppleCameraButton()
    let progressView = UIProgressView(progressViewStyle: .default)
    let activityIndicator = UIActivityIndicatorView(style: .large)
    let gridOverlayView = UIView()
    let storageLabel = UILabel()
    let permissionStatusLabel = UILabel()
    
    // MARK: - Enhanced Recording Controls
    lazy var visualCountdownView = UIView()
    private var isCountingDown = false
    private var countdownTimer: Timer?
    private let settingsManager = SettingsManagerStub()

    // MARK: - Triple Output Controls
    lazy var tripleOutputControlView = UIView()
    lazy var tripleOutputButton = AppleCameraButton()

    // MARK: - Advanced Camera Controls
    lazy var cameraControlsView = UIView()
    private var advancedCameraControlsManager: AdvancedCameraControlsManagerStub?
    private var showAdvancedControls = false

    // MARK: - Audio Controls
    lazy var audioControlsView = UIView()
    private var showAudioControls = false
    lazy var audioSourceButton = AppleCameraButton()
    
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
        let startTime = CACurrentMediaTime()
        
        let signpostID = OSSignpostID(log: log)
        viewLoadSignpostID = signpostID
        os_signpost(.begin, log: log, name: "ViewController Load", signpostID: signpostID)

        setupMinimalUI()
        bindController()

        let uiSetupTime = CACurrentMediaTime() - startTime
        print("⏱️ VIEWCONTROLLER: Minimal UI setup completed in \(String(format: "%.3f", uiSetupTime))s")

        Task(priority: .userInitiated) {
            await self.performDeferredUISetup()
        }

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 30_000_000_000)
            self.checkForEmergencyFallback()
        }
        
        os_signpost(.end, log: log, name: "ViewController Load", signpostID: signpostID)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        print("👁️ VIEWCONTROLLER: viewDidAppear called, hasInitialized: \(hasInitializedController)")

        guard !hasInitializedController else { 
            print("👁️ VIEWCONTROLLER: Already initialized, skipping")
            return 
        }
        hasInitializedController = true

        let signpostID = OSSignpostID(log: log)
        cameraInitSignpostID = signpostID
        os_signpost(.begin, log: log, name: "Camera Initialization", signpostID: signpostID)
        
        StartupOptimizer.shared.beginPhase(.permissionCheck)

        Task { @MainActor in
            self.appController.start()
        }
    }
    
    // MARK: - Optimized Setup Methods

    private func setupMinimalUI() {
        view.backgroundColor = .black
        
        cameraStackView.axis = .vertical
        cameraStackView.alignment = .fill
        cameraStackView.distribution = .fillEqually
        cameraStackView.spacing = 0
        cameraStackView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(cameraStackView)
        
        frontCameraPreview.title = "Front Camera"
        frontCameraPreview.translatesAutoresizingMaskIntoConstraints = false
        frontCameraPreview.backgroundColor = .black
        
        backCameraPreview.title = "Back Camera"
        backCameraPreview.translatesAutoresizingMaskIntoConstraints = false
        backCameraPreview.backgroundColor = .black
        
        cameraStackView.addArrangedSubview(frontCameraPreview)
        cameraStackView.addArrangedSubview(backCameraPreview)
        
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        activityIndicator.color = .white
        activityIndicator.hidesWhenStopped = true
        view.addSubview(activityIndicator)
        
        statusLabel.text = ""
        statusLabel.textColor = .white
        statusLabel.font = UIFont.systemFont(ofSize: 12, weight: .medium)
        statusLabel.textAlignment = .center
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(statusLabel)
        
        NSLayoutConstraint.activate([
            cameraStackView.topAnchor.constraint(equalTo: view.topAnchor),
            cameraStackView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            cameraStackView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            cameraStackView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            
            statusLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 60),
            statusLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])
        
        showLoadingState()
    }

    private func performDeferredUISetup() async {
        try? await Task.sleep(nanoseconds: 50_000_000)
        
        await MainActor.run {
            setupNotifications()
            setupErrorHandling()
            setupDeferredControls()
            setupGradients()
            setupDeferredConstraints()
            setupGestureRecognizers()
            setupGridOverlay()
            frontCameraPreview.completeSetup()
            backCameraPreview.completeSetup()
        }
        
        await performBackgroundSetup()
        print("✅ VIEWCONTROLLER: Deferred UI setup complete")
    }

    private func performBackgroundSetup() async {
        await Task(priority: .utility) {
            await MainActor.run {
                self.startStorageMonitoring()
                self.setupEnhancedControls()
                self.setupPerformanceMonitoring()
                self.warmUpCameraSystem()
            }
            print("✅ VIEWCONTROLLER: Background setup complete")
        }.value
    }

    // MARK: - UI Setup
    private func setupFullUI() {
        print("VIEWCONTROLLER: Setting up full UI")

        setupNotifications()
        setupErrorHandling()
        setupDeferredControls()
        setupGradients()
        setupDeferredConstraints()
        setupGestureRecognizers()

        frontCameraPreview.completeSetup()
        backCameraPreview.completeSetup()

        showLoadingState()

        print("VIEWCONTROLLER: Full UI setup complete")
    }
    
    private func showLoadingState() {
        // Show loading state immediately on main thread (no async delay)
        activityIndicator.startAnimating()
        statusLabel.text = "Preparing camera..."
        statusLabel.isHidden = false
        progressView.isHidden = false
        progressView.progress = 0.0
        frontCameraPreview.showLoading(message: "Initializing...")
        backCameraPreview.showLoading(message: "Initializing...")

        print("✅ VIEWCONTROLLER: Loading state displayed")
    }
    
    private func hideLoadingState() {
        activityIndicator.stopAnimating()
        progressView.isHidden = true
        frontCameraPreview.hideLoading()
        backCameraPreview.hideLoading()
    }

    private func bindController() {
        appController.onStateChange = { [weak self] state in
            self?.handleStateChange(state)
        }

        appController.onPreviewLayersReady = { [weak self] frontLayer, backLayer in
            self?.handlePreviewLayersReady(frontLayer: frontLayer, backLayer: backLayer)
        }

        appController.onRecordingStateChange = { [weak self] isRecording in
            self?.handleRecordingStateChange(isRecording: isRecording)
        }

        appController.onPhotoCaptured = { [weak self] front, back in
            self?.handlePhotoCaptured(frontImage: front, backImage: back)
        }

        appController.onError = { [weak self] error in
            self?.handleControllerError(error)
        }

        appController.onVideoQualityChange = { [weak self] quality in
            self?.qualityButton.setTitle(quality.rawValue, for: .normal)
        }

        appController.onSetupProgress = { [weak self] message, progress in
            self?.handleSetupProgress(message: message, progress: progress)
        }

        appController.onSimulatorModeRequested = { [weak self] in
            self?.setupSimulatorMode()
        }

        dualCameraManager.enableTripleOutput = true
        dualCameraManager.tripleOutputMode = .allFiles
    }

    private func handleStateChange(_ state: CameraAppController.State) {
        controllerState = state

        if let message = state.statusMessage {
            statusLabel.text = message
            statusLabel.isHidden = false
        }

        switch state.phase {
        case .idle:
            break
        case .requestingPermissions:
            print("📱 VIEWCONTROLLER: Requesting permissions...")
            statusLabel.text = "Requesting permissions..."
            statusLabel.isHidden = false
            showLoadingState()
        case .settingUp:
            print("📱 VIEWCONTROLLER: Setting up camera...")
            // Status message will be updated by progress callbacks
            statusLabel.isHidden = false
            showLoadingState()
        case .ready:
            print("✅ VIEWCONTROLLER: Camera ready!")
            hideLoadingState()
            statusLabel.text = "Ready to record"
            statusLabel.isHidden = false
        case .permissionsDenied(let deniedPermissions):
            print("⚠️ VIEWCONTROLLER: Permissions denied: \(deniedPermissions)")
            hideLoadingState()
            presentPermissionsAlert(for: deniedPermissions)
        case .error(let message):
            print("❌ VIEWCONTROLLER: Error: \(message)")
            hideLoadingState()
            statusLabel.text = "⚠️ \(message)"
            statusLabel.isHidden = false
        }
    }

    private func handlePreviewLayersReady(frontLayer: AVCaptureVideoPreviewLayer?, backLayer: AVCaptureVideoPreviewLayer?) {
        StartupOptimizer.shared.endPhase(.previewSetup)
        
        guard frontLayer != nil, backLayer != nil else {
            statusLabel.text = "Camera setup failed"
            statusLabel.isHidden = false
            return
        }

        let completionTime = CACurrentMediaTime()
        print("⏱️ VIEWCONTROLLER: Camera setup completed at \(String(format: "%.3f", completionTime))s")
        print("VIEWCONTROLLER: Preview layers ready - attaching to views")

        setupPreviewLayers()
        hideLoadingState()
        isCameraSetupComplete = true
        frontCameraPreview.isActive = true
        backCameraPreview.isActive = true
        statusLabel.text = "Ready to record"
        statusLabel.isHidden = false

        if view.window != nil {
            appController.startSessions()
        }

        let totalStartupTime = completionTime
        print("🚀 TOTAL STARTUP TIME: \(String(format: "%.3f", totalStartupTime))s")
        
        StartupOptimizer.shared.completeStartup()
        PerformanceMonitor.shared.endCameraSetup()
        
        if let signpostID = cameraInitSignpostID {
            os_signpost(.end, log: log, name: "Camera Initialization", signpostID: signpostID)
        }
    }

    private func handleSetupProgress(message: String, progress: Float) {
        DispatchQueue.main.async {
            self.statusLabel.text = message
            self.progressView.setProgress(progress, animated: true)

            // Update camera preview loading messages
            if progress < 0.5 {
                self.frontCameraPreview.showLoading(message: message)
                self.backCameraPreview.showLoading(message: message)
            } else if progress >= 0.8 {
                self.frontCameraPreview.showLoading(message: "Almost ready...")
                self.backCameraPreview.showLoading(message: "Almost ready...")
            }

            print("📱 VIEWCONTROLLER: Setup progress: \(message) (\(Int(progress * 100))%)")
        }
    }

    private func handleRecordingStateChange(isRecording: Bool) {
        DispatchQueue.main.async {
            if isRecording {
                print("VIEWCONTROLLER: Recording started")
                self.isRecording = true
                self.recordButton.setRecording(true, animated: true)
                self.timerBlurView.isHidden = false
                self.recordingTimerLabel.isHidden = false
                self.recordingStartTime = Date()

                self.frontCameraPreview.startRecordingAnimation()
                self.backCameraPreview.startRecordingAnimation()

                self.recordingTimer?.invalidate()
                self.recordingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                    guard let self = self, let startTime = self.recordingStartTime else { return }
                    let elapsed = Int(Date().timeIntervalSince(startTime))
                    let minutes = elapsed / 60
                    let seconds = elapsed % 60
                    self.recordingTimerLabel.text = String(format: "%02d:%02d", minutes, seconds)
                }

                self.statusLabel.text = "Recording..."
                self.statusLabel.isHidden = false

                self.swapCameraButton.isEnabled = false
                self.qualityButton.isEnabled = false
                self.modeSegmentedControl.isEnabled = false
                self.tripleOutputButton.isEnabled = false
                self.audioSourceButton.isEnabled = false
            } else {
                print("VIEWCONTROLLER: Recording stopped")
                self.isRecording = false
                self.recordButton.setRecording(false, animated: true)
                self.timerBlurView.isHidden = true
                self.recordingTimerLabel.isHidden = true
                self.recordingTimer?.invalidate()
                self.recordingTimer = nil

                self.frontCameraPreview.stopRecordingAnimation()
                self.backCameraPreview.stopRecordingAnimation()

                self.statusLabel.text = "Recording saved ✓"
                self.statusLabel.isHidden = false
                self.mergeVideosButton.isEnabled = true
                self.mergeVideosButton.alpha = 1.0

                self.swapCameraButton.isEnabled = true
                self.qualityButton.isEnabled = true
                self.modeSegmentedControl.isEnabled = true
                self.tripleOutputButton.isEnabled = true
                self.audioSourceButton.isEnabled = true

                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    self.statusLabel.text = "Ready to record"
                }
            }
        }
    }

    private func handlePhotoCaptured(frontImage: UIImage?, backImage: UIImage?) {
        DispatchQueue.main.async {
            self.statusLabel.text = "Photo captured ✓"

            let flashView = UIView(frame: self.view.bounds)
            flashView.backgroundColor = .white
            flashView.alpha = 0.8
            self.view.addSubview(flashView)

            UIView.animate(withDuration: 0.1, animations: {
                flashView.alpha = 0
            }) { _ in
                flashView.removeFromSuperview()
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                self.statusLabel.text = "Ready to capture"
            }
        }
    }

    private func handleControllerError(_ error: Error) {
        DispatchQueue.main.async {
            self.statusLabel.text = "⚠️ Error: \(error.localizedDescription)"
            self.statusLabel.isHidden = false
            self.frontCameraPreview.showError(message: "Error occurred")
            self.backCameraPreview.showError(message: "Error occurred")

            let alert = UIAlertController(
                title: "Camera Error",
                message: error.localizedDescription,
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            self.presentAlertSafely(alert)
        }
    }

    private func presentPermissionsAlert(for deniedPermissions: [PermissionType]) {
        guard !deniedPermissions.isEmpty else { return }

        _ = deniedPermissions.map { $0.title }.joined(separator: ", ")

        // Create a more detailed message
        var detailedMessage = "This app needs the following permissions to work:\n\n"
        for permission in deniedPermissions {
            detailedMessage += "• \(permission.title)\n"
        }
        detailedMessage += "\nPlease enable them in Settings to use the app."

        DispatchQueue.main.async {
            self.statusLabel.text = "⚠️ Permissions Required"
            self.statusLabel.isHidden = false

            // Show error state in preview views
            if self.frontCameraPreview.superview != nil {
                self.frontCameraPreview.showError(message: "Permission required")
            }
            if self.backCameraPreview.superview != nil {
                self.backCameraPreview.showError(message: "Permission required")
            }

            guard !self.isPresentingAlert else { return }

            let alert = UIAlertController(
                title: "📷 Permissions Required",
                message: detailedMessage,
                preferredStyle: .alert
            )

            alert.addAction(UIAlertAction(title: "Open Settings", style: .default) { _ in
                if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsURL)
                }
                // When user returns from Settings, check permissions again
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self.appController.retryPermissions()
                }
            })

            alert.addAction(UIAlertAction(title: "Not Now", style: .cancel) { _ in
                self.statusLabel.text = "App requires permissions to function"
                self.statusLabel.isHidden = false
            })

            self.presentAlertSafely(alert)
        }
    }
    
    // Hide status bar for fullscreen camera experience
    nonisolated override var prefersStatusBarHidden: Bool {
        return true
    }
    
    nonisolated override var prefersHomeIndicatorAutoHidden: Bool {
        return true
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        print("VIEWCONTROLLER: viewWillAppear - cameraSetupComplete: \(isCameraSetupComplete)")
        if isCameraSetupComplete {
            appController.startSessions()
        } else {
            print("VIEWCONTROLLER: Camera not setup yet, will start when setup completes")
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if isCameraSetupComplete {
            appController.stopSessions()
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
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
        
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        
        topGradient.frame = CGRect(x: 0, y: 0, width: view.bounds.width, height: 150)
        bottomGradient.frame = CGRect(x: 0, y: view.bounds.height - 220, width: view.bounds.width, height: 220)
        
        if let frontLayer = dualCameraManager.frontPreviewLayer {
            frontLayer.frame = frontCameraPreview.bounds
        }
        
        if let backLayer = dualCameraManager.backPreviewLayer {
            backLayer.frame = backCameraPreview.bounds
        }
        
        CATransaction.commit()
    }
    
    private func setupGestureRecognizers() {
        let frontPinch = UIPinchGestureRecognizer(target: self, action: #selector(handleFrontPinch(_:)))
        frontCameraPreview.addGestureRecognizer(frontPinch)

        let frontTap = UITapGestureRecognizer(target: self, action: #selector(handleFrontTap(_:)))
        frontCameraPreview.addGestureRecognizer(frontTap)

        let backPinch = UIPinchGestureRecognizer(target: self, action: #selector(handleBackPinch(_:)))
        backCameraPreview.addGestureRecognizer(backPinch)

        let backTap = UITapGestureRecognizer(target: self, action: #selector(handleBackTap(_:)))
        backCameraPreview.addGestureRecognizer(backTap)
        
        frontCameraPreview.isUserInteractionEnabled = true
        backCameraPreview.isUserInteractionEnabled = true
    }
    
    private func setupDeferredControls() {
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
        
        // Storage label
        storageLabel.textColor = .white.withAlphaComponent(0.7)
        storageLabel.font = UIFont.systemFont(ofSize: 11, weight: .medium)
        storageLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(storageLabel)
    }
    
    private func setupGridOverlay() {
        gridOverlayView.translatesAutoresizingMaskIntoConstraints = false
        gridOverlayView.isUserInteractionEnabled = false
        gridOverlayView.isHidden = true
        view.addSubview(gridOverlayView)
        
        NSLayoutConstraint.activate([
            gridOverlayView.topAnchor.constraint(equalTo: cameraStackView.topAnchor),
            gridOverlayView.leadingAnchor.constraint(equalTo: cameraStackView.leadingAnchor),
            gridOverlayView.trailingAnchor.constraint(equalTo: cameraStackView.trailingAnchor),
            gridOverlayView.bottomAnchor.constraint(equalTo: cameraStackView.bottomAnchor)
        ])
        
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
    
    private func setupEnhancedControls() {
        // Disabled - using stub implementation
        // visualCountdownView.translatesAutoresizingMaskIntoConstraints = false
        // view.addSubview(visualCountdownView)
        
        // Load saved settings
        loadUserSettings()
    }
    
    private func loadUserSettings() {
        // Apply saved video quality
        appController.setVideoQuality(settingsManager.videoQuality)
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
        appController.startRecording()
    }

    private func setupDeferredConstraints() {
        NSLayoutConstraint.activate([
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
            storageLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
        ])
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
            appController.stopRecording()
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

    // MARK: - Emergency Fallback UI

    private func setupEmergencyFallbackUI() {
        // Create a minimal UI that always shows something
        let emergencyLabel = UILabel()
        emergencyLabel.text = "Dual Camera App"
        emergencyLabel.textColor = .white
        emergencyLabel.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        emergencyLabel.textAlignment = .center
        emergencyLabel.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(emergencyLabel)
        NSLayoutConstraint.activate([
            emergencyLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emergencyLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -100)
        ])

        let emergencyStatusLabel = UILabel()
        emergencyStatusLabel.text = "Loading..."
        emergencyStatusLabel.textColor = .lightGray
        emergencyStatusLabel.font = UIFont.systemFont(ofSize: 16)
        emergencyStatusLabel.textAlignment = .center
        emergencyStatusLabel.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(emergencyStatusLabel)
        NSLayoutConstraint.activate([
            emergencyStatusLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emergencyStatusLabel.topAnchor.constraint(equalTo: emergencyLabel.bottomAnchor, constant: 20)
        ])

        print("🚨 VIEWCONTROLLER: Emergency fallback UI set up")
    }

    private func checkForEmergencyFallback() {
        // If we're still not ready after 30 seconds, show emergency UI
        let isReady = {
            switch appController.state.phase {
            case .ready:
                return true
            default:
                return false
            }
        }()

        if !isCameraSetupComplete && !isReady {
            print("🚨 VIEWCONTROLLER: Emergency fallback triggered - showing basic UI")
            showEmergencyFallbackState()
        }
    }

    private func showEmergencyFallbackState() {
        DispatchQueue.main.async {
            self.hideLoadingState()
            self.statusLabel.text = "Camera initialization failed. Please restart the app."
            self.statusLabel.isHidden = false

            // Show a retry button
            let retryButton = UIButton(type: .system)
            retryButton.setTitle("Retry", for: .normal)
            retryButton.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .medium)
            retryButton.backgroundColor = UIColor.systemBlue
            retryButton.setTitleColor(.white, for: .normal)
            retryButton.layer.cornerRadius = 8
            retryButton.translatesAutoresizingMaskIntoConstraints = false
            retryButton.addTarget(self, action: #selector(self.retrySetup), for: .touchUpInside)

            self.view.addSubview(retryButton)
            NSLayoutConstraint.activate([
                retryButton.centerXAnchor.constraint(equalTo: self.view.centerXAnchor),
                retryButton.centerYAnchor.constraint(equalTo: self.view.centerYAnchor, constant: 50),
                retryButton.widthAnchor.constraint(equalToConstant: 120),
                retryButton.heightAnchor.constraint(equalToConstant: 44)
            ])
        }
    }

    @objc private func retrySetup() {
        print("🔄 VIEWCONTROLLER: User requested retry")
        // Reset state and try again
        hasInitializedController = false
        isCameraSetupComplete = false

        // Remove retry button
        view.subviews.forEach { subview in
            if let button = subview as? UIButton, button.titleLabel?.text == "Retry" {
                button.removeFromSuperview()
            }
        }

        // Show loading state and retry
        showLoadingState()
        appController.start()
    }
    
    @objc private func handleMemoryWarning() {
        print("VIEWCONTROLLER: Memory warning received")
        
        // Reduce quality temporarily
        appController.reduceQualityForMemoryPressure()
        
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
            appController.stopRecording()
        }
        if isCameraSetupComplete {
            appController.stopSessions()
        }
    }

    @objc private func appDidBecomeActive() {
        if isCameraSetupComplete {
            revalidatePermissionsAndStartSession()
        } else if case .permissionsDenied = controllerState.phase {
            appController.retryPermissions()
        }
    }
    
    private func revalidatePermissionsAndStartSession() {
        let permissionManager = PermissionManager.shared
        let cameraStatus = permissionManager.cameraPermissionStatus()
        let micStatus = permissionManager.microphonePermissionStatus()
        let photoStatus = permissionManager.photoLibraryPermissionStatus()
        
        if cameraStatus != .authorized {
            statusLabel.text = "Camera permission revoked"
            frontCameraPreview.showError(message: "Camera permission required")
            backCameraPreview.showError(message: "Camera permission required")
            
            let alert = UIAlertController(
                title: "Camera Permission Required",
                message: "Please enable camera access in Settings to continue using this app.",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "Open Settings", style: .default) { _ in
                if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsURL)
                }
            })
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            presentAlertSafely(alert)
            return
        }
        
        if micStatus != .authorized {
            statusLabel.text = "Microphone permission revoked"
            
            let alert = UIAlertController(
                title: "Microphone Permission Required",
                message: "Please enable microphone access in Settings to record audio with videos.",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "Open Settings", style: .default) { _ in
                if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsURL)
                }
            })
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            presentAlertSafely(alert)
            return
        }
        
        if photoStatus != .authorized {
            statusLabel.text = "Photo Library permission revoked"
            
            let alert = UIAlertController(
                title: "Photo Library Permission Required",
                message: "Please enable photo library access in Settings to save videos.",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "Open Settings", style: .default) { _ in
                if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsURL)
                }
            })
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            presentAlertSafely(alert)
            return
        }
        
        appController.startSessions()
        statusLabel.text = "Ready to record"
    }

    // MARK: - Camera Setup

    private func setupPreviewLayers() {
        print("VIEWCONTROLLER: Setting up preview layers")

        guard let frontLayer = dualCameraManager.frontPreviewLayer,
              let backLayer = dualCameraManager.backPreviewLayer else {
            print("VIEWCONTROLLER: ⚠️ Preview layers not available - frontLayer: \(dualCameraManager.frontPreviewLayer != nil), backLayer: \(dualCameraManager.backPreviewLayer != nil)")
            handleCameraSetupFailure()
            return
        }

        print("VIEWCONTROLLER: Assigning preview layers to views")
        print("VIEWCONTROLLER: Front preview bounds: \(frontCameraPreview.bounds)")
        print("VIEWCONTROLLER: Back preview bounds: \(backCameraPreview.bounds)")

        frontCameraPreview.previewLayer = frontLayer
        backCameraPreview.previewLayer = backLayer
        
        frontLayer.videoGravity = .resizeAspectFill
        backLayer.videoGravity = .resizeAspectFill

        view.setNeedsLayout()
        view.layoutIfNeeded()

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        frontLayer.frame = frontCameraPreview.bounds
        backLayer.frame = backCameraPreview.bounds
        CATransaction.commit()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.view.setNeedsLayout()
            self.view.layoutIfNeeded()
        }

        print("VIEWCONTROLLER: ✅ Preview layers assigned")
        print("VIEWCONTROLLER: Front layer frame: \(frontLayer.frame)")
        print("VIEWCONTROLLER: Back layer frame: \(backLayer.frame)")
        print("VIEWCONTROLLER: Front layer connection: \(frontLayer.connection?.isActive ?? false)")
        print("VIEWCONTROLLER: Back layer connection: \(backLayer.connection?.isActive ?? false)")
    }

    private func setupSimulatorMode() {
        // Simulator mode - show placeholder content
        frontCameraPreview.showError(message: "Simulator Mode\nFront Camera")
        backCameraPreview.showError(message: "Simulator Mode\nBack Camera")
        frontCameraPreview.hideLoading()
        backCameraPreview.hideLoading()

        activityIndicator.stopAnimating()
        statusLabel.text = "Simulator Mode - Demo Ready"
        isCameraSetupComplete = true

        // Enable basic functionality for testing UI
        frontCameraPreview.isActive = true
        backCameraPreview.isActive = true


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
            appController.capturePhoto()
            animateCaptureFlash()
            return
        }

        if isRecording {
            print("VIEWCONTROLLER: Stopping recording...")
            appController.stopRecording()
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
            appController.startRecording()
        }
    }

    @objc private func flashButtonTapped() {
        appController.toggleFlash()
        let imageName = appController.isFlashOn ? "bolt.fill" : "bolt.slash.fill"
        let flashImg = UIImage(systemName: imageName)?.withRenderingMode(.alwaysTemplate)
        flashButton.setImage(flashImg, for: .normal)
        flashButton.tintColor = appController.isFlashOn ? .systemYellow : .white
        flashButton.imageView?.tintColor = appController.isFlashOn ? .systemYellow : .white
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
                self?.appController.setVideoQuality(quality)
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
