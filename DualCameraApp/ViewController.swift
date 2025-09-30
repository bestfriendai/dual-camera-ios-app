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

    // MARK: - UI Components - Camera Views
    let cameraStackView = UIStackView()
    let frontCameraPreview = CameraPreviewView()
    let backCameraPreview = CameraPreviewView()

    // MARK: - UI Components - Controls
    let controlsContainer = GlassmorphismView(style: .regular)
    let topControlsContainer = GlassmorphismView(style: .subtle)
    let recordButton = UIButton(type: .system)
    let statusLabel = UILabel()
    let recordingTimerLabel = UILabel()
    let flashButton = UIButton(type: .system)
    let swapCameraButton = UIButton(type: .system)
    let qualityButton = UIButton(type: .system)
    let galleryButton = UIButton(type: .system)
    let gridButton = UIButton(type: .system)
    let modeSegmentedControl = UISegmentedControl(items: ["Video", "Photo"])
    let mergeVideosButton = UIButton(type: .system)
    let progressView = UIProgressView(progressViewStyle: .default)
    let activityIndicator = UIActivityIndicatorView(style: .large)
    let gridOverlayView = UIView()
    let storageLabel = UILabel()
    let permissionStatusLabel = UILabel()
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        PerformanceMonitor.shared.beginAppLaunch()
        PerformanceMonitor.shared.beginCameraSetup()
        
        setupUI()
        setupNotifications()
        
        // Warm up camera system
        DispatchQueue.global(qos: .userInitiated).async {
            _ = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
            _ = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
        }
        
        // Request permissions
        requestCameraPermissions()
        
        // Start storage monitoring
        DispatchQueue.global(qos: .utility).async {
            self.startStorageMonitoring()
        }
        
        PerformanceMonitor.shared.endAppLaunch()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if isCameraSetupComplete {
            dualCameraManager.startSessions()
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
        view.backgroundColor = .black
        
        // Camera views
        setupCameraViews()
        
        // Controls
        setupControls()
        
        // Constraints
        setupConstraints()
    }
    
    private func setupCameraViews() {
        cameraStackView.axis = .vertical
        cameraStackView.alignment = .fill
        cameraStackView.distribution = .fillEqually
        cameraStackView.spacing = 16
        cameraStackView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(cameraStackView)

        // Configure front camera preview
        frontCameraPreview.title = "Front Camera"
        frontCameraPreview.translatesAutoresizingMaskIntoConstraints = false
        frontCameraPreview.isUserInteractionEnabled = true

        // Configure back camera preview
        backCameraPreview.title = "Back Camera"
        backCameraPreview.translatesAutoresizingMaskIntoConstraints = false
        backCameraPreview.isUserInteractionEnabled = true

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
        // Top controls container
        topControlsContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(topControlsContainer)

        // Bottom controls container
        controlsContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(controlsContainer)

        // Record button - larger and more prominent
        recordButton.setImage(UIImage(systemName: "record.circle.fill"), for: .normal)
        recordButton.tintColor = .systemRed
        recordButton.translatesAutoresizingMaskIntoConstraints = false
        recordButton.addTarget(self, action: #selector(recordButtonTapped), for: .touchUpInside)
        recordButton.contentVerticalAlignment = .fill
        recordButton.contentHorizontalAlignment = .fill
        controlsContainer.contentView.addSubview(recordButton)
        
        // Status label
        statusLabel.text = "Initializing..."
        statusLabel.textColor = .white
        statusLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 0
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        controlsContainer.contentView.addSubview(statusLabel)
        
        // Recording timer
        recordingTimerLabel.text = "00:00"
        recordingTimerLabel.textColor = .systemRed
        recordingTimerLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 16, weight: .bold)
        recordingTimerLabel.textAlignment = .center
        recordingTimerLabel.isHidden = true
        recordingTimerLabel.translatesAutoresizingMaskIntoConstraints = false
        controlsContainer.contentView.addSubview(recordingTimerLabel)
        
        // Flash button
        flashButton.setImage(UIImage(systemName: "bolt.slash.fill"), for: .normal)
        flashButton.tintColor = .white
        flashButton.translatesAutoresizingMaskIntoConstraints = false
        flashButton.addTarget(self, action: #selector(flashButtonTapped), for: .touchUpInside)
        controlsContainer.contentView.addSubview(flashButton)
        
        // Swap camera button
        swapCameraButton.setImage(UIImage(systemName: "arrow.up.arrow.down.circle.fill"), for: .normal)
        swapCameraButton.tintColor = .white
        swapCameraButton.translatesAutoresizingMaskIntoConstraints = false
        swapCameraButton.addTarget(self, action: #selector(swapCameraButtonTapped), for: .touchUpInside)
        controlsContainer.contentView.addSubview(swapCameraButton)
        
        // Merge button
        mergeVideosButton.setTitle("Merge Videos", for: .normal)
        mergeVideosButton.setTitleColor(.white, for: .normal)
        mergeVideosButton.backgroundColor = .systemBlue.withAlphaComponent(0.7)
        mergeVideosButton.layer.cornerRadius = 15
        mergeVideosButton.titleLabel?.font = UIFont.systemFont(ofSize: 14)
        mergeVideosButton.translatesAutoresizingMaskIntoConstraints = false
        mergeVideosButton.addTarget(self, action: #selector(mergeVideosButtonTapped), for: .touchUpInside)
        mergeVideosButton.isEnabled = false
        mergeVideosButton.alpha = 0.5
        controlsContainer.contentView.addSubview(mergeVideosButton)
        
        // Progress view
        progressView.translatesAutoresizingMaskIntoConstraints = false
        progressView.progressTintColor = .systemBlue
        progressView.trackTintColor = .systemGray
        progressView.isHidden = true
        controlsContainer.contentView.addSubview(progressView)
        
        // Top controls
        qualityButton.setTitle("1080p", for: .normal)
        qualityButton.setTitleColor(.white, for: .normal)
        qualityButton.backgroundColor = .systemGray.withAlphaComponent(0.7)
        qualityButton.layer.cornerRadius = 8
        qualityButton.titleLabel?.font = UIFont.systemFont(ofSize: 12, weight: .medium)
        qualityButton.translatesAutoresizingMaskIntoConstraints = false
        qualityButton.addTarget(self, action: #selector(qualityButtonTapped), for: .touchUpInside)
        view.addSubview(qualityButton)
        
        galleryButton.setImage(UIImage(systemName: "photo.on.rectangle"), for: .normal)
        galleryButton.tintColor = .white
        galleryButton.backgroundColor = .systemGray.withAlphaComponent(0.7)
        galleryButton.layer.cornerRadius = 8
        galleryButton.translatesAutoresizingMaskIntoConstraints = false
        galleryButton.addTarget(self, action: #selector(galleryButtonTapped), for: .touchUpInside)
        view.addSubview(galleryButton)
        
        gridButton.setImage(UIImage(systemName: "grid"), for: .normal)
        gridButton.tintColor = .white
        gridButton.backgroundColor = .systemGray.withAlphaComponent(0.7)
        gridButton.layer.cornerRadius = 8
        gridButton.translatesAutoresizingMaskIntoConstraints = false
        gridButton.addTarget(self, action: #selector(gridButtonTapped), for: .touchUpInside)
        view.addSubview(gridButton)
        
        modeSegmentedControl.selectedSegmentIndex = 0
        modeSegmentedControl.translatesAutoresizingMaskIntoConstraints = false
        modeSegmentedControl.addTarget(self, action: #selector(modeChanged), for: .valueChanged)
        modeSegmentedControl.backgroundColor = UIColor.white.withAlphaComponent(0.2)
        modeSegmentedControl.selectedSegmentTintColor = .white
        modeSegmentedControl.setTitleTextAttributes([.foregroundColor: UIColor.white], for: .normal)
        modeSegmentedControl.setTitleTextAttributes([.foregroundColor: UIColor.black], for: .selected)
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

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // Camera stack view
            cameraStackView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 60),
            cameraStackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            cameraStackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            cameraStackView.bottomAnchor.constraint(equalTo: controlsContainer.topAnchor, constant: -20),

            // Controls container
            controlsContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            controlsContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            controlsContainer.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            controlsContainer.heightAnchor.constraint(equalToConstant: 200),

            // Record button
            recordButton.centerXAnchor.constraint(equalTo: controlsContainer.contentView.centerXAnchor),
            recordButton.centerYAnchor.constraint(equalTo: controlsContainer.contentView.centerYAnchor, constant: -20),
            recordButton.widthAnchor.constraint(equalToConstant: 80),
            recordButton.heightAnchor.constraint(equalToConstant: 80),

            // Status label
            statusLabel.topAnchor.constraint(equalTo: controlsContainer.contentView.topAnchor, constant: 15),
            statusLabel.leadingAnchor.constraint(equalTo: controlsContainer.contentView.leadingAnchor, constant: 15),
            statusLabel.trailingAnchor.constraint(equalTo: controlsContainer.contentView.trailingAnchor, constant: -15),

            // Recording timer
            recordingTimerLabel.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 10),
            recordingTimerLabel.centerXAnchor.constraint(equalTo: controlsContainer.contentView.centerXAnchor),

            // Flash button
            flashButton.centerYAnchor.constraint(equalTo: recordButton.centerYAnchor),
            flashButton.trailingAnchor.constraint(equalTo: recordButton.leadingAnchor, constant: -30),
            flashButton.widthAnchor.constraint(equalToConstant: 44),
            flashButton.heightAnchor.constraint(equalToConstant: 44),

            // Swap camera button
            swapCameraButton.centerYAnchor.constraint(equalTo: recordButton.centerYAnchor),
            swapCameraButton.leadingAnchor.constraint(equalTo: recordButton.trailingAnchor, constant: 30),
            swapCameraButton.widthAnchor.constraint(equalToConstant: 44),
            swapCameraButton.heightAnchor.constraint(equalToConstant: 44),

            // Merge button
            mergeVideosButton.bottomAnchor.constraint(equalTo: controlsContainer.contentView.bottomAnchor, constant: -15),
            mergeVideosButton.centerXAnchor.constraint(equalTo: controlsContainer.contentView.centerXAnchor),
            mergeVideosButton.widthAnchor.constraint(equalToConstant: 120),
            mergeVideosButton.heightAnchor.constraint(equalToConstant: 35),

            // Progress view
            progressView.bottomAnchor.constraint(equalTo: mergeVideosButton.topAnchor, constant: -10),
            progressView.leadingAnchor.constraint(equalTo: controlsContainer.contentView.leadingAnchor, constant: 15),
            progressView.trailingAnchor.constraint(equalTo: controlsContainer.contentView.trailingAnchor, constant: -15),

            // Mode segmented control
            modeSegmentedControl.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
            modeSegmentedControl.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            modeSegmentedControl.widthAnchor.constraint(equalToConstant: 200),
            modeSegmentedControl.heightAnchor.constraint(equalToConstant: 32),

            // Quality button
            qualityButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
            qualityButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            qualityButton.widthAnchor.constraint(equalToConstant: 60),
            qualityButton.heightAnchor.constraint(equalToConstant: 32),

            // Gallery button
            galleryButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
            galleryButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            galleryButton.widthAnchor.constraint(equalToConstant: 44),
            galleryButton.heightAnchor.constraint(equalToConstant: 32),

            // Grid button
            gridButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
            gridButton.trailingAnchor.constraint(equalTo: galleryButton.leadingAnchor, constant: -10),
            gridButton.widthAnchor.constraint(equalToConstant: 44),
            gridButton.heightAnchor.constraint(equalToConstant: 32),

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
        statusLabel.text = "Requesting permissions..."

        permissionManager.requestAllPermissions { [weak self] allGranted, deniedPermissions in
            guard let self = self else { return }

            if allGranted {
                self.statusLabel.text = "Permissions granted ✓"
                self.setupCamerasAfterPermissions()
            } else {
                self.statusLabel.text = "Permissions required"
                self.permissionManager.showMultiplePermissionsAlert(
                    deniedPermissions: deniedPermissions,
                    from: self
                )

                // Show which permissions are missing
                self.frontCameraPreview.showError(message: "Camera permission required")
                self.backCameraPreview.showError(message: "Camera permission required")
            }
        }
    }

    private func setupCamerasAfterPermissions() {
        dualCameraManager.delegate = self

        frontCameraPreview.showLoading(message: "Initializing cameras...")
        backCameraPreview.showLoading(message: "Initializing cameras...")

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            self.dualCameraManager.setupCameras()

            // Poll for preview layers with timeout
            var attempts = 0
            while (self.dualCameraManager.frontPreviewLayer == nil ||
                   self.dualCameraManager.backPreviewLayer == nil) && attempts < 50 {
                Thread.sleep(forTimeInterval: 0.02)
                attempts += 1
            }

            DispatchQueue.main.async {
                if self.dualCameraManager.frontPreviewLayer != nil &&
                   self.dualCameraManager.backPreviewLayer != nil {
                    self.setupPreviewLayers()
                    self.activityIndicator.stopAnimating()
                    self.statusLabel.text = "Ready to record"
                    self.isCameraSetupComplete = true
                    self.frontCameraPreview.isActive = true
                    self.backCameraPreview.isActive = true
                    PerformanceMonitor.shared.endCameraSetup()
                } else {
                    self.handleCameraSetupFailure()
                }
            }
        }
    }

    private func setupPreviewLayers() {
        guard let frontLayer = dualCameraManager.frontPreviewLayer,
              let backLayer = dualCameraManager.backPreviewLayer else {
            handleCameraSetupFailure()
            return
        }

        // Assign preview layers to custom preview views
        frontCameraPreview.previewLayer = frontLayer
        backCameraPreview.previewLayer = backLayer
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
        present(alert, animated: true)
    }

    // MARK: - Actions
    @objc private func recordButtonTapped() {
        if isPhotoMode {
            dualCameraManager.capturePhoto()
            animateCaptureFlash()
        } else {
            if isRecording {
                dualCameraManager.stopRecording()
            } else {
                dualCameraManager.startRecording()
            }
        }
    }

    @objc private func flashButtonTapped() {
        dualCameraManager.toggleFlash()
        let imageName = dualCameraManager.isFlashOn ? "bolt.fill" : "bolt.slash.fill"
        flashButton.setImage(UIImage(systemName: imageName), for: .normal)
    }

    @objc private func swapCameraButtonTapped() {
        isFrontViewPrimary.toggle()
        updateCameraStackOrder()
    }

    private func updateCameraStackOrder() {
        let orderedViews: [UIView] = isFrontViewPrimary ?
            [frontCameraPreview, backCameraPreview] :
            [backCameraPreview, frontCameraPreview]

        UIView.animate(withDuration: 0.3) {
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
        // Gallery functionality - simplified for now
        statusLabel.text = "Gallery coming soon..."
    }

    @objc private func gridButtonTapped() {
        isGridVisible.toggle()
        gridOverlayView.isHidden = !isGridVisible
        gridButton.tintColor = isGridVisible ? .systemYellow : .white
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
        // Merge functionality - simplified for now
        statusLabel.text = "Merging videos..."
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
            }
        }
    }
}

// MARK: - DualCameraManagerDelegate
extension ViewController: DualCameraManagerDelegate {
    func didStartRecording() {
        isRecording = true
        recordButton.tintColor = .white
        recordButton.setImage(UIImage(systemName: "stop.circle.fill"), for: .normal)
        recordingTimerLabel.isHidden = false
        recordingStartTime = Date()

        // Visual feedback on camera previews
        frontCameraPreview.startRecordingAnimation()
        backCameraPreview.startRecordingAnimation()

        // Pulse the record button
        controlsContainer.pulse()

        recordingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self, let startTime = self.recordingStartTime else { return }
            let elapsed = Int(Date().timeIntervalSince(startTime))
            let minutes = elapsed / 60
            let seconds = elapsed % 60
            self.recordingTimerLabel.text = String(format: "🔴 %02d:%02d", minutes, seconds)
        }

        statusLabel.text = "Recording..."

        // Disable certain controls during recording
        swapCameraButton.isEnabled = false
        qualityButton.isEnabled = false
        modeSegmentedControl.isEnabled = false
    }

    func didStopRecording() {
        isRecording = false
        recordButton.tintColor = .systemRed
        recordButton.setImage(UIImage(systemName: "record.circle.fill"), for: .normal)
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
        present(alert, animated: true)
    }

    func didUpdateVideoQuality(to quality: VideoQuality) {
        qualityButton.setTitle(quality.rawValue, for: .normal)
    }
}


