import UIKit
import AVFoundation

class ViewController: UIViewController {

    // Internal so VideoMerger extension can access it
    internal let dualCameraManager = DualCameraManager()
    
    
    private let frontCameraView = UIView()
    private let backCameraView = UIView()
    private let controlsContainer = GlassmorphismView()
    private let recordButton = UIButton(type: .system)
    internal let statusLabel = UILabel()  // Changed to internal for VideoMerger access
    internal let mergeVideosButton = UIButton(type: .system)  // Changed to internal for VideoMerger access
    private let flashButton = UIButton(type: .system)
    private let swapCameraButton = UIButton(type: .system)
    private let qualityButton = UIButton(type: .system)
    private let galleryButton = UIButton(type: .system)
    private let recordingTimerLabel = UILabel()
    internal let progressView = UIProgressView(progressViewStyle: .default)  // For export progress
    internal let activityIndicator = UIActivityIndicatorView(style: .large)  // For loading

    private var isRecording = false
    private var recordingTimer: Timer?
    private var recordingDuration = 0
    private var isFrontViewPrimary = true
    private var frontZoomScale: CGFloat = 1.0
    private var backZoomScale: CGFloat = 1.0
    private var isCameraSetupComplete = false

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        requestCameraPermissions()
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

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Stop recording if in progress to free up memory
        if isRecording {
            dualCameraManager.stopRecording()
            statusLabel.text = "Recording stopped due to low memory"
        }
    }
    
    
    private func setupUI() {
        view.backgroundColor = .black
        
        
        setupCameraViews()
        
        
        setupControls()
        
        
        setupConstraints()
    }
    
    private func setupCameraViews() {
        // Front camera view
        frontCameraView.backgroundColor = .darkGray
        frontCameraView.layer.cornerRadius = 20
        frontCameraView.layer.masksToBounds = true
        frontCameraView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(frontCameraView)

        // Back camera view
        backCameraView.backgroundColor = .darkGray
        backCameraView.layer.cornerRadius = 20
        backCameraView.layer.masksToBounds = true
        backCameraView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(backCameraView)

        // Add gesture recognizers
        setupGestureRecognizers()
    }

    private func setupGestureRecognizers() {
        // Pinch to zoom for front camera
        let frontPinch = UIPinchGestureRecognizer(target: self, action: #selector(handleFrontPinch(_:)))
        frontCameraView.addGestureRecognizer(frontPinch)

        // Pinch to zoom for back camera
        let backPinch = UIPinchGestureRecognizer(target: self, action: #selector(handleBackPinch(_:)))
        backCameraView.addGestureRecognizer(backPinch)

        // Tap to focus for front camera
        let frontTap = UITapGestureRecognizer(target: self, action: #selector(handleFrontTap(_:)))
        frontCameraView.addGestureRecognizer(frontTap)

        // Tap to focus for back camera
        let backTap = UITapGestureRecognizer(target: self, action: #selector(handleBackTap(_:)))
        backCameraView.addGestureRecognizer(backTap)

        frontCameraView.isUserInteractionEnabled = true
        backCameraView.isUserInteractionEnabled = true
    }
    
    private func setupControls() {
        
        controlsContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(controlsContainer)
        
        
        recordButton.setImage(UIImage(systemName: "record.circle.fill"), for: .normal)
        recordButton.tintColor = .systemRed
        recordButton.translatesAutoresizingMaskIntoConstraints = false
        recordButton.addTarget(self, action: #selector(recordButtonTapped), for: .touchUpInside)
        controlsContainer.contentView.addSubview(recordButton)
        
        
        statusLabel.text = "Ready to record"
        statusLabel.textColor = .white
        statusLabel.font = UIFont.systemFont(ofSize: 16)
        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 0
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        controlsContainer.contentView.addSubview(statusLabel)
        
        
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
        
        
        flashButton.setImage(UIImage(systemName: "bolt.slash.fill"), for: .normal)
        flashButton.tintColor = .white
        flashButton.translatesAutoresizingMaskIntoConstraints = false
        flashButton.addTarget(self, action: #selector(flashButtonTapped), for: .touchUpInside)
        controlsContainer.contentView.addSubview(flashButton)
        
        
        swapCameraButton.setImage(UIImage(systemName: "arrow.up.arrow.down.circle.fill"), for: .normal)
        swapCameraButton.tintColor = .white
        swapCameraButton.translatesAutoresizingMaskIntoConstraints = false
        swapCameraButton.addTarget(self, action: #selector(swapCameraButtonTapped), for: .touchUpInside)
        controlsContainer.contentView.addSubview(swapCameraButton)

        // Quality button
        qualityButton.setTitle("1080p", for: .normal)
        qualityButton.setTitleColor(.white, for: .normal)
        qualityButton.backgroundColor = .systemGray.withAlphaComponent(0.7)
        qualityButton.layer.cornerRadius = 8
        qualityButton.titleLabel?.font = UIFont.systemFont(ofSize: 12, weight: .medium)
        qualityButton.translatesAutoresizingMaskIntoConstraints = false
        qualityButton.addTarget(self, action: #selector(qualityButtonTapped), for: .touchUpInside)
        view.addSubview(qualityButton)

        // Gallery button
        galleryButton.setImage(UIImage(systemName: "photo.on.rectangle"), for: .normal)
        galleryButton.tintColor = .white
        galleryButton.backgroundColor = .systemGray.withAlphaComponent(0.7)
        galleryButton.layer.cornerRadius = 8
        galleryButton.translatesAutoresizingMaskIntoConstraints = false
        galleryButton.addTarget(self, action: #selector(galleryButtonTapped), for: .touchUpInside)
        view.addSubview(galleryButton)
        
        
        recordingTimerLabel.text = "00:00"
        recordingTimerLabel.textColor = .white
        recordingTimerLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 16, weight: .bold)
        recordingTimerLabel.isHidden = true
        recordingTimerLabel.translatesAutoresizingMaskIntoConstraints = false
        controlsContainer.contentView.addSubview(recordingTimerLabel)

        // Progress view for export
        progressView.translatesAutoresizingMaskIntoConstraints = false
        progressView.progressTintColor = .systemBlue
        progressView.trackTintColor = .systemGray
        progressView.isHidden = true
        controlsContainer.contentView.addSubview(progressView)

        // Activity indicator
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        activityIndicator.color = .white
        activityIndicator.hidesWhenStopped = true
        view.addSubview(activityIndicator)
    }
    
    private func setupConstraints() {
        updateCameraViewConstraints()
        
        NSLayoutConstraint.activate([
            
            controlsContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            controlsContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            controlsContainer.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            controlsContainer.heightAnchor.constraint(equalToConstant: 180),
            
            
            recordButton.centerXAnchor.constraint(equalTo: controlsContainer.centerXAnchor),
            recordButton.topAnchor.constraint(equalTo: controlsContainer.topAnchor, constant: 20),
            recordButton.widthAnchor.constraint(equalToConstant: 70),
            recordButton.heightAnchor.constraint(equalToConstant: 70),
            
            
            statusLabel.centerXAnchor.constraint(equalTo: controlsContainer.centerXAnchor),
            statusLabel.topAnchor.constraint(equalTo: recordButton.bottomAnchor, constant: 10),
            statusLabel.leadingAnchor.constraint(equalTo: controlsContainer.leadingAnchor, constant: 20),
            statusLabel.trailingAnchor.constraint(equalTo: controlsContainer.trailingAnchor, constant: -20),
            
            
            mergeVideosButton.centerXAnchor.constraint(equalTo: controlsContainer.centerXAnchor),
            mergeVideosButton.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 10),
            mergeVideosButton.widthAnchor.constraint(equalToConstant: 120),
            mergeVideosButton.heightAnchor.constraint(equalToConstant: 30),
            
            
            flashButton.centerYAnchor.constraint(equalTo: recordButton.centerYAnchor),
            flashButton.leadingAnchor.constraint(equalTo: controlsContainer.leadingAnchor, constant: 30),
            
            
            swapCameraButton.centerYAnchor.constraint(equalTo: recordButton.centerYAnchor),
            swapCameraButton.trailingAnchor.constraint(equalTo: controlsContainer.trailingAnchor, constant: -30),
            

            recordingTimerLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            recordingTimerLabel.bottomAnchor.constraint(equalTo: controlsContainer.topAnchor, constant: -10),

            // Progress view constraints
            progressView.leadingAnchor.constraint(equalTo: controlsContainer.leadingAnchor, constant: 20),
            progressView.trailingAnchor.constraint(equalTo: controlsContainer.trailingAnchor, constant: -20),
            progressView.bottomAnchor.constraint(equalTo: controlsContainer.bottomAnchor, constant: -10),

            // Activity indicator constraints
            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor),

            // Quality button constraints
            qualityButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
            qualityButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            qualityButton.widthAnchor.constraint(equalToConstant: 60),
            qualityButton.heightAnchor.constraint(equalToConstant: 30),

            // Gallery button constraints
            galleryButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
            galleryButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            galleryButton.widthAnchor.constraint(equalToConstant: 40),
            galleryButton.heightAnchor.constraint(equalToConstant: 30)
        ])
    }
    
    private func updateCameraViewConstraints() {
        
        frontCameraView.removeFromSuperview()
        backCameraView.removeFromSuperview()
        view.insertSubview(frontCameraView, at: 0)
        view.insertSubview(backCameraView, at: 0)
        
        
        let primaryView = isFrontViewPrimary ? frontCameraView : backCameraView
        let secondaryView = isFrontViewPrimary ? backCameraView : frontCameraView
        
        NSLayoutConstraint.deactivate(view.constraints)
        setupConstraints()
        
        NSLayoutConstraint.activate([
            primaryView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            primaryView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            primaryView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            primaryView.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.5),
            
            secondaryView.widthAnchor.constraint(equalTo: primaryView.widthAnchor, multiplier: 0.3),
            secondaryView.heightAnchor.constraint(equalTo: primaryView.heightAnchor, multiplier: 0.3),
            secondaryView.bottomAnchor.constraint(equalTo: primaryView.bottomAnchor, constant: -10),
            secondaryView.trailingAnchor.constraint(equalTo: primaryView.trailingAnchor, constant: -10)
        ])
    }
    
    private func setupDualCamera() {
        dualCameraManager.delegate = self
        
        
        setupPreviewLayers()
    }
    
    private func setupPreviewLayers() {
        
        if let frontPreviewLayer = dualCameraManager.frontPreviewLayer {
            frontPreviewLayer.frame = frontCameraView.bounds
            frontCameraView.layer.addSublayer(frontPreviewLayer)
        }
        
        
        if let backPreviewLayer = dualCameraManager.backPreviewLayer {
            backPreviewLayer.frame = backCameraView.bounds
            backCameraView.layer.addSublayer(backPreviewLayer)
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        
        dualCameraManager.frontPreviewLayer?.frame = frontCameraView.bounds
        dualCameraManager.backPreviewLayer?.frame = backCameraView.bounds
    }
    
    private func requestCameraPermissions() {
        AVCaptureDevice.requestAccess(for: .video) { [weak self] videoGranted in
            if videoGranted {
                AVCaptureDevice.requestAccess(for: .audio) { [weak self] audioGranted in
                    DispatchQueue.main.async {
                        if !audioGranted {
                            self?.showPermissionAlert(type: "Audio")
                        }
                        // Setup cameras after permissions are granted
                        self?.setupCamerasAfterPermissions()
                    }
                }
            } else {
                DispatchQueue.main.async {
                    self?.showPermissionAlert(type: "Camera")
                }
            }
        }
    }

    private func setupCamerasAfterPermissions() {
        // Setup camera manager
        dualCameraManager.setupCameras()

        // Setup delegate and preview layers
        setupDualCamera()

        // Mark setup as complete
        isCameraSetupComplete = true

        // Start sessions
        dualCameraManager.startSessions()

        // Update status
        statusLabel.text = "Ready to record"
    }
    
    private func showPermissionAlert(type: String) {
        let alert = UIAlertController(
            title: "\(type) Permission Required",
            message: "This app needs \(type.lowercased()) permission. Please enable it in Settings.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Settings", style: .default) { _ in
            if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(settingsURL)
            }
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        present(alert, animated: true)
    }
    
    
    @objc private func recordButtonTapped() {
        if isRecording {
            dualCameraManager.stopRecording()
        } else {
            dualCameraManager.startRecording()
        }
    }
    
    @objc private func mergeVideosButtonTapped() {
        let urls = dualCameraManager.getRecordingURLs()
        if let frontURL = urls.front, let backURL = urls.back {
            
            let alert = UIAlertController(title: "Select Merge Style", message: nil, preferredStyle: .actionSheet)
            alert.addAction(UIAlertAction(title: "Side-by-Side", style: .default) { _ in
                self.mergeVideos(frontURL: frontURL, backURL: backURL, layout: .sideBySide)
            })
            alert.addAction(UIAlertAction(title: "Picture-in-Picture", style: .default) { _ in
                self.mergeVideos(frontURL: frontURL, backURL: backURL, layout: .pip)
            })
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            present(alert, animated: true)
        }
    }
    
    @objc private func flashButtonTapped() {
        dualCameraManager.toggleFlash()
        let imageName = dualCameraManager.isFlashOn ? "bolt.fill" : "bolt.slash.fill"
        flashButton.setImage(UIImage(systemName: imageName), for: .normal)
    }
    
    @objc private func swapCameraButtonTapped() {
        isFrontViewPrimary.toggle()
        updateCameraViewConstraints()

        UIView.animate(withDuration: 0.3) {
            self.view.layoutIfNeeded()
        }
    }

    @objc private func qualityButtonTapped() {
        let alert = UIAlertController(title: "Video Quality", message: "Select recording quality", preferredStyle: .actionSheet)

        for quality in VideoQuality.allCases {
            let action = UIAlertAction(title: quality.rawValue, style: .default) { [weak self] _ in
                self?.dualCameraManager.videoQuality = quality
                self?.qualityButton.setTitle(quality.rawValue.components(separatedBy: " ").first, for: .normal)
            }
            if dualCameraManager.videoQuality == quality {
                action.setValue(true, forKey: "checked")
            }
            alert.addAction(action)
        }

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    @objc private func galleryButtonTapped() {
        let galleryVC = VideoGalleryViewController()
        let navController = UINavigationController(rootViewController: galleryVC)
        navController.modalPresentationStyle = .fullScreen
        present(navController, animated: true)
    }
    
    private func updateRecordingState(_ recording: Bool) {
        isRecording = recording
        
        DispatchQueue.main.async {
            let imageName = recording ? "stop.circle.fill" : "record.circle.fill"
            self.recordButton.setImage(UIImage(systemName: imageName), for: .normal)
            
            self.mergeVideosButton.isEnabled = !recording
            self.mergeVideosButton.alpha = recording ? 0.5 : 1.0
            
            self.flashButton.isEnabled = !recording
            self.swapCameraButton.isEnabled = !recording
            
            if recording {
                self.startTimer()
            } else {
                self.stopTimer()
            }
        }
    }
    
    private func startTimer() {
        recordingDuration = 0
        recordingTimerLabel.isHidden = false
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.recordingDuration += 1
            let minutes = self.recordingDuration / 60
            let seconds = self.recordingDuration % 60
            self.recordingTimerLabel.text = String(format: "%02d:%02d", minutes, seconds)
        }
    }
    
    private func stopTimer() {
        recordingTimer?.invalidate()
        recordingTimer = nil
        recordingTimerLabel.isHidden = true
        recordingTimerLabel.text = "00:00"
    }

    // MARK: - Gesture Handlers
    @objc private func handleFrontPinch(_ gesture: UIPinchGestureRecognizer) {
        if gesture.state == .changed {
            frontZoomScale *= gesture.scale
            frontZoomScale = max(1.0, min(frontZoomScale, 5.0))
            dualCameraManager.setZoom(for: .front, scale: frontZoomScale)
            gesture.scale = 1.0
        }
    }

    @objc private func handleBackPinch(_ gesture: UIPinchGestureRecognizer) {
        if gesture.state == .changed {
            backZoomScale *= gesture.scale
            backZoomScale = max(1.0, min(backZoomScale, 5.0))
            dualCameraManager.setZoom(for: .back, scale: backZoomScale)
            gesture.scale = 1.0
        }
    }

    @objc private func handleFrontTap(_ gesture: UITapGestureRecognizer) {
        let location = gesture.location(in: frontCameraView)
        let point = CGPoint(
            x: location.x / frontCameraView.bounds.width,
            y: location.y / frontCameraView.bounds.height
        )
        dualCameraManager.setFocusAndExposure(for: .front, at: point)
        showFocusIndicator(at: location, in: frontCameraView)
    }

    @objc private func handleBackTap(_ gesture: UITapGestureRecognizer) {
        let location = gesture.location(in: backCameraView)
        let point = CGPoint(
            x: location.x / backCameraView.bounds.width,
            y: location.y / backCameraView.bounds.height
        )
        dualCameraManager.setFocusAndExposure(for: .back, at: point)
        showFocusIndicator(at: location, in: backCameraView)
    }

    private func showFocusIndicator(at point: CGPoint, in view: UIView) {
        // Create focus indicator
        let focusView = UIView(frame: CGRect(x: 0, y: 0, width: 80, height: 80))
        focusView.center = point
        focusView.layer.borderColor = UIColor.systemYellow.cgColor
        focusView.layer.borderWidth = 2
        focusView.layer.cornerRadius = 40
        focusView.alpha = 0
        view.addSubview(focusView)

        // Animate
        UIView.animate(withDuration: 0.3, animations: {
            focusView.alpha = 1
            focusView.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        }) { _ in
            UIView.animate(withDuration: 0.3, delay: 0.5, animations: {
                focusView.alpha = 0
            }) { _ in
                focusView.removeFromSuperview()
            }
        }
    }
}


extension ViewController: DualCameraManagerDelegate {
    func didStartRecording() {
        DispatchQueue.main.async {
            self.updateRecordingState(true)
            self.statusLabel.text = "Recording..."
        }
    }
    
    func didStopRecording() {
        DispatchQueue.main.async {
            self.updateRecordingState(false)
            self.statusLabel.text = "Recording stopped"
            self.mergeVideosButton.isEnabled = true
            self.mergeVideosButton.alpha = 1.0
        }
    }
    
    func didFailWithError(_ error: Error) {
        DispatchQueue.main.async {
            self.updateRecordingState(false)
            self.statusLabel.text = "Error: \(error.localizedDescription)"
        }
    }
}