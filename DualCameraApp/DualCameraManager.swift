// Dual Camera App
import AVFoundation
import UIKit
import Photos

protocol DualCameraManagerDelegate: AnyObject {
    func didStartRecording()
    func didStopRecording()
    func didFailWithError(_ error: Error)
    func didUpdateVideoQuality(to quality: VideoQuality)
    func didCapturePhoto(frontImage: UIImage?, backImage: UIImage?)
    func didFinishCameraSetup()
}

enum VideoQuality: String, CaseIterable {
    case hd720 = "720p HD"
    case hd1080 = "1080p Full HD"
    case uhd4k = "4K Ultra HD"

    var dimensions: CMVideoDimensions {
        switch self {
        case .hd720:
            return CMVideoDimensions(width: 1280, height: 720)
        case .hd1080:
            return CMVideoDimensions(width: 1920, height: 1080)
        case .uhd4k:
            return CMVideoDimensions(width: 3840, height: 2160)
        }
    }

    var renderSize: CGSize {
        switch self {
        case .hd720:
            return CGSize(width: 1280, height: 720)
        case .hd1080:
            return CGSize(width: 1920, height: 1080)
        case .uhd4k:
            return CGSize(width: 3840, height: 2160)
        }
    }
}

final class DualCameraManager: NSObject {
    weak var delegate: DualCameraManagerDelegate?

    var videoQuality: VideoQuality = .hd1080 {
        didSet {
            activeVideoQuality = videoQuality
            DispatchQueue.main.async {
                self.delegate?.didUpdateVideoQuality(to: self.videoQuality)
            }
        }
    }

    private let sessionQueue = DispatchQueue(label: "DualCameraManager.SessionQueue")

    private var captureSession: AVCaptureSession?

    var frontCamera: AVCaptureDevice?
    var backCamera: AVCaptureDevice?
    private var frontCameraInput: AVCaptureDeviceInput?
    private var backCameraInput: AVCaptureDeviceInput?

    private var audioDevice: AVCaptureDevice?
    private var audioInput: AVCaptureDeviceInput?

    private var frontMovieOutput: AVCaptureMovieFileOutput?
    private var backMovieOutput: AVCaptureMovieFileOutput?

    private var frontPhotoOutput: AVCapturePhotoOutput?
    private var backPhotoOutput: AVCapturePhotoOutput?

    var frontPreviewLayer: AVCaptureVideoPreviewLayer?
    var backPreviewLayer: AVCaptureVideoPreviewLayer?

    private var frontVideoURL: URL?
    private var backVideoURL: URL?
    private var combinedVideoURL: URL?

    private var capturedFrontImage: UIImage?
    private var capturedBackImage: UIImage?
    private var photoCaptureCount = 0

    private var isRecording = false
    private var isSetupComplete = false
    private(set) var activeVideoQuality: VideoQuality = .hd1080
    
    enum CameraState {
        case notConfigured
        case configuring
        case configured
        case failed(Error)
        case recording
        case paused
    }
    
    private(set) var state: CameraState = .notConfigured {
        didSet {
            DispatchQueue.main.async { [weak self] in
                self?.handleStateChange(from: oldValue, to: self?.state ?? .notConfigured)
            }
        }
    }
    
    private func handleStateChange(from oldState: CameraState, to newState: CameraState) {
        switch (oldState, newState) {
        case (.recording, .configured), (.recording, .paused):
            delegate?.didStopRecording()
        case (_, .configured):
            delegate?.didFinishCameraSetup()
        case (_, .recording):
            delegate?.didStartRecording()
        case (_, .failed(let error)):
            delegate?.didFailWithError(error)
        default:
            break
        }
    }

    // MARK: - Triple Output Properties
    private var frontDataOutput: AVCaptureVideoDataOutput?
    private var backDataOutput: AVCaptureVideoDataOutput?
    private var audioDataOutput: AVCaptureAudioDataOutput?
    private let dataOutputQueue = DispatchQueue(label: "com.dualcamera.dataoutput", qos: .userInitiated)
    private let audioOutputQueue = DispatchQueue(label: "com.dualcamera.audiooutput", qos: .userInitiated)
    private let compositionQueue = DispatchQueue(label: "com.dualcamera.composition", qos: .userInitiated)

    private var frameCompositor: FrameCompositor?
    private var assetWriter: AVAssetWriter?
    private var videoWriterInput: AVAssetWriterInput?
    private var audioWriterInput: AVAssetWriterInput?
    private var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?

    private var frontFrameBuffer: CMSampleBuffer?
    private var backFrameBuffer: CMSampleBuffer?
    private let frameSyncQueue = DispatchQueue(label: "com.dualcamera.framesync")

    private var recordingStartTime: CMTime?
    private var isWriting = false

    enum RecordingLayout {
        case sideBySide
        case pictureInPicture
        case overlay
    }
    
    var recordingLayout: RecordingLayout = .pictureInPicture  // Changed to PIP mode
    var enableTripleOutput: Bool = true
    var tripleOutputMode: TripleOutputMode = .allFiles
    
    // Audio management
    private let audioManager = AudioManager()

    private enum DualCameraError: LocalizedError {
        case multiCamNotSupported
        case missingDevices
        case configurationFailed(String)
        case tripleOutputFailed(String)

        var errorDescription: String? {
            switch self {
            case .multiCamNotSupported:
                return "This device does not support simultaneous front and back camera capture."
            case .missingDevices:
                return "Required camera devices could not be initialized."
            case .configurationFailed(let reason):
                return reason
            case .tripleOutputFailed(let reason):
                return "Triple output recording failed: \(reason)"
            }
        }
    }
    
    enum TripleOutputMode {
        case allFiles        // Save front, back, and combined as separate files
        case combinedOnly    // Save only the combined file
        case frontBackOnly   // Save front and back files, no combined
    }

    private var setupRetryCount = 0
    private let maxSetupRetries = 3
    
    private var thermalObserver: NSObjectProtocol?
    
    private func setupThermalMonitoring() {
        thermalObserver = NotificationCenter.default.addObserver(
            forName: ProcessInfo.thermalStateDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleThermalStateChange()
        }
    }
    
    private func handleThermalStateChange() {
        switch ProcessInfo.processInfo.thermalState {
        case .critical, .serious:
            reduceQualityForMemoryPressure()
            frameCompositor?.flushBufferPool()
            PerformanceMonitor.shared.logEvent("Thermal", "Reduced quality - thermal state: \(ProcessInfo.processInfo.thermalState)")
        case .nominal, .fair:
            restoreQualityAfterMemoryPressure()
            PerformanceMonitor.shared.logEvent("Thermal", "Restored quality - thermal state: \(ProcessInfo.processInfo.thermalState)")
        @unknown default:
            break
        }
    }
    
    func setupCameras() {
        setupThermalMonitoring()
        guard !isSetupComplete else { return }

        state = .configuring
        print("DEBUG: Setting up cameras (attempt \(setupRetryCount + 1)/\(maxSetupRetries))...")

        // OPTIMIZATION: Discover devices on background queue
        DispatchQueue.global(qos: .userInitiated).async {
            self.frontCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
            self.backCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
            self.audioDevice = AVCaptureDevice.default(for: .audio)

            print("DEBUG: Front camera: \(self.frontCamera?.localizedName ?? "nil")")
            print("DEBUG: Back camera: \(self.backCamera?.localizedName ?? "nil")")
            print("DEBUG: Audio device: \(self.audioDevice?.localizedName ?? "nil")")

            guard self.frontCamera != nil, self.backCamera != nil else {
                let error = DualCameraError.missingDevices
                DispatchQueue.main.async {
                    ErrorHandlingManager.shared.handleError(error)
                    self.delegate?.didFailWithError(error)
                }
                return
            }

            // OPTIMIZATION: Configure audio session asynchronously
            DispatchQueue.global(qos: .utility).async {
                self.configureAudioSession()
            }

            // Continue with session configuration on session queue
            self.sessionQueue.async {
                do {
                    try self.configureSession()
                    self.isSetupComplete = true
                    self.setupRetryCount = 0
                    self.state = .configured

                    // Notify delegate that setup is complete
                    DispatchQueue.main.async {
                        self.delegate?.didUpdateVideoQuality(to: self.videoQuality)
                        self.delegate?.didFinishCameraSetup()
                    }

                    // Start session immediately on sessionQueue
                    // Preview layers can be assigned to a running session
                    if let session = self.captureSession, !session.isRunning {
                        print("DEBUG: Starting capture session...")
                        session.startRunning()
                        print("DEBUG: ✅ Capture session started - isRunning: \(session.isRunning)")
                    }

                    // OPTIMIZATION: Configure professional features in background
                    DispatchQueue.global(qos: .utility).async {
                        self.configureCameraProfessionalFeatures()
                    }
                } catch {
                    self.state = .failed(error)
                    self.captureSession = nil

                    if self.setupRetryCount < self.maxSetupRetries {
                        self.setupRetryCount += 1
                        print("DEBUG: Setup failed, retrying... (attempt \(self.setupRetryCount))")
                        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 1.0) {
                            self.isSetupComplete = false
                            self.setupCameras()
                        }
                    } else {
                        DispatchQueue.main.async {
                            ErrorHandlingManager.shared.handleError(error)
                            self.delegate?.didFailWithError(error)
                        }
                    }
                }
            }
        }
    }

    private func configureSession() throws {
        guard let frontCamera, let backCamera else {
            print("DEBUG: Missing camera devices")
            throw DualCameraError.missingDevices
        }

        if #available(iOS 13.0, *) {
            let isSupported = AVCaptureMultiCamSession.isMultiCamSupported
            print("DEBUG: MultiCam supported: \(isSupported)")
            guard isSupported else {
                print("DEBUG: MultiCam not supported, throwing error")
                throw DualCameraError.multiCamNotSupported
            }

            let session = AVCaptureMultiCamSession()
            captureSession = session
            try configureMultiCamSession(session: session, frontCamera: frontCamera, backCamera: backCamera)
        } else {
            throw DualCameraError.multiCamNotSupported
        }
    }

    @available(iOS 13.0, *)
    private func configureMultiCamSession(session: AVCaptureMultiCamSession, frontCamera: AVCaptureDevice, backCamera: AVCaptureDevice) throws {
        session.beginConfiguration()
        defer { session.commitConfiguration() }

        let selectedQuality = videoQuality
        activeVideoQuality = selectedQuality

        // STEP 1: Add inputs (fast)
        let frontInput = try AVCaptureDeviceInput(device: frontCamera)
        guard session.canAddInput(frontInput) else {
            throw DualCameraError.configurationFailed("Unable to add front camera input to capture session.")
        }
        session.addInputWithNoConnections(frontInput)
        frontCameraInput = frontInput

        let backInput = try AVCaptureDeviceInput(device: backCamera)
        guard session.canAddInput(backInput) else {
            throw DualCameraError.configurationFailed("Unable to add back camera input to capture session.")
        }
        session.addInputWithNoConnections(backInput)
        backCameraInput = backInput

        if let audioDevice {
            let audioInput = try AVCaptureDeviceInput(device: audioDevice)
            if session.canAddInput(audioInput) {
                session.addInputWithNoConnections(audioInput)
                self.audioInput = audioInput
            }
        }

        // STEP 2: Get video ports (needed for connections)
        guard
            let frontVideoPort = frontInput.ports(
                for: .video,
                sourceDeviceType: frontCamera.deviceType,
                sourceDevicePosition: .front
            ).first,
            let backVideoPort = backInput.ports(
                for: .video,
                sourceDeviceType: backCamera.deviceType,
                sourceDevicePosition: .back
            ).first
        else {
            throw DualCameraError.configurationFailed("Failed to obtain camera ports for preview and recording.")
        }

        // STEP 3: Setup PREVIEW LAYERS FIRST (most important for perceived speed)
        let frontPreviewLayer = AVCaptureVideoPreviewLayer(sessionWithNoConnection: session)
        frontPreviewLayer.videoGravity = .resizeAspectFill
        let frontPreviewConnection = AVCaptureConnection(
            inputPort: frontVideoPort,
            videoPreviewLayer: frontPreviewLayer
        )
        guard session.canAddConnection(frontPreviewConnection) else {
            throw DualCameraError.configurationFailed("Unable to configure front preview layer.")
        }
        session.addConnection(frontPreviewConnection)
        if frontPreviewConnection.isVideoOrientationSupported {
            frontPreviewConnection.videoOrientation = AVCaptureVideoOrientation.portrait
        }
        self.frontPreviewLayer = frontPreviewLayer

        let backPreviewLayer = AVCaptureVideoPreviewLayer(sessionWithNoConnection: session)
        backPreviewLayer.videoGravity = .resizeAspectFill
        let backPreviewConnection = AVCaptureConnection(
            inputPort: backVideoPort,
            videoPreviewLayer: backPreviewLayer
        )
        guard session.canAddConnection(backPreviewConnection) else {
            throw DualCameraError.configurationFailed("Unable to configure back preview layer.")
        }
        session.addConnection(backPreviewConnection)
        if backPreviewConnection.isVideoOrientationSupported {
            backPreviewConnection.videoOrientation = AVCaptureVideoOrientation.portrait
        }
        self.backPreviewLayer = backPreviewLayer

        // STEP 4: Setup movie outputs (needed for recording)
        let frontOutput = AVCaptureMovieFileOutput()
        guard session.canAddOutput(frontOutput) else {
            throw DualCameraError.configurationFailed("Unable to add front movie output to capture session.")
        }
        session.addOutputWithNoConnections(frontOutput)
        frontMovieOutput = frontOutput

        let backOutput = AVCaptureMovieFileOutput()
        guard session.canAddOutput(backOutput) else {
            throw DualCameraError.configurationFailed("Unable to add back movie output to capture session.")
        }
        session.addOutputWithNoConnections(backOutput)
        backMovieOutput = backOutput

        // STEP 5: Connect movie outputs to cameras
        var frontConnectionPorts: [AVCaptureInput.Port] = [frontVideoPort]
        if let audioPort = audioInput?.ports(
            for: .audio,
            sourceDeviceType: audioDevice?.deviceType,
            sourceDevicePosition: audioDevice?.position ?? .unspecified
        ).first {
            frontConnectionPorts.append(audioPort)
        }

        let frontConnection = AVCaptureConnection(inputPorts: frontConnectionPorts, output: frontOutput)
        guard session.canAddConnection(frontConnection) else {
            throw DualCameraError.configurationFailed("Unable to link front camera input with movie output.")
        }
        session.addConnection(frontConnection)
        if frontConnection.isVideoOrientationSupported {
            frontConnection.videoOrientation = AVCaptureVideoOrientation.portrait
        }
        
        // Enable video stabilization for front camera (professional feature)
        if frontConnection.isVideoStabilizationSupported {
            frontConnection.preferredVideoStabilizationMode = .cinematicExtended
            print("DEBUG: Front camera - Cinematic Extended stabilization enabled")
        }

        let backConnection = AVCaptureConnection(inputPorts: [backVideoPort], output: backOutput)
        guard session.canAddConnection(backConnection) else {
            throw DualCameraError.configurationFailed("Unable to link back camera input with movie output.")
        }
        session.addConnection(backConnection)
        if backConnection.isVideoOrientationSupported {
            backConnection.videoOrientation = AVCaptureVideoOrientation.portrait
        }
        
        // Enable video stabilization for back camera
        if backConnection.isVideoStabilizationSupported {
            backConnection.preferredVideoStabilizationMode = .cinematicExtended
            print("DEBUG: Back camera - Cinematic Extended stabilization enabled")
        }

        // Setup photo outputs
        let frontPhotoOutput = AVCapturePhotoOutput()
        print("DEBUG: Can add front photo output: \(session.canAddOutput(frontPhotoOutput))")
        if session.canAddOutput(frontPhotoOutput) {
            session.addOutputWithNoConnections(frontPhotoOutput)
            self.frontPhotoOutput = frontPhotoOutput

            let frontPhotoConnection = AVCaptureConnection(inputPorts: [frontVideoPort], output: frontPhotoOutput)
            print("DEBUG: Can add front photo connection: \(session.canAddConnection(frontPhotoConnection))")
            if session.canAddConnection(frontPhotoConnection) {
                session.addConnection(frontPhotoConnection)
                if frontPhotoConnection.isVideoOrientationSupported {
                    frontPhotoConnection.videoOrientation = .portrait
                }
            }
        }

        let backPhotoOutput = AVCapturePhotoOutput()
        print("DEBUG: Can add back photo output: \(session.canAddOutput(backPhotoOutput))")
        if session.canAddOutput(backPhotoOutput) {
            session.addOutputWithNoConnections(backPhotoOutput)
            self.backPhotoOutput = backPhotoOutput

            let backPhotoConnection = AVCaptureConnection(inputPorts: [backVideoPort], output: backPhotoOutput)
            print("DEBUG: Can add back photo connection: \(session.canAddConnection(backPhotoConnection))")
            if session.canAddConnection(backPhotoConnection) {
                session.addConnection(backPhotoConnection)
                if backPhotoConnection.isVideoOrientationSupported {
                    backPhotoConnection.videoOrientation = .portrait
                }
            }
        }

        // Setup triple output data outputs
        if self.enableTripleOutput {
            print("DEBUG: Setting up data outputs")
            let frontDataOutput = AVCaptureVideoDataOutput()
            frontDataOutput.videoSettings = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
            ]
            frontDataOutput.alwaysDiscardsLateVideoFrames = true

            print("DEBUG: Can add front data output: \(session.canAddOutput(frontDataOutput))")
            if session.canAddOutput(frontDataOutput) {
                session.addOutputWithNoConnections(frontDataOutput)
                self.frontDataOutput = frontDataOutput

                let frontDataConnection = AVCaptureConnection(inputPorts: [frontVideoPort], output: frontDataOutput)
                print("DEBUG: Can add front data connection: \(session.canAddConnection(frontDataConnection))")
                if session.canAddConnection(frontDataConnection) {
                    session.addConnection(frontDataConnection)
                    if frontDataConnection.isVideoOrientationSupported {
                        frontDataConnection.videoOrientation = .portrait
                    }
                }
                
                frontDataOutput.setSampleBufferDelegate(self, queue: self.dataOutputQueue)
            }

            let backDataOutput = AVCaptureVideoDataOutput()
            backDataOutput.videoSettings = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
            ]
            backDataOutput.alwaysDiscardsLateVideoFrames = true

            print("DEBUG: Can add back data output: \(session.canAddOutput(backDataOutput))")
            if session.canAddOutput(backDataOutput) {
                session.addOutputWithNoConnections(backDataOutput)
                self.backDataOutput = backDataOutput

                let backDataConnection = AVCaptureConnection(inputPorts: [backVideoPort], output: backDataOutput)
                print("DEBUG: Can add back data connection: \(session.canAddConnection(backDataConnection))")
                if session.canAddConnection(backDataConnection) {
                    session.addConnection(backDataConnection)
                    if backDataConnection.isVideoOrientationSupported {
                        backDataConnection.videoOrientation = .portrait
                    }
                }
                
                backDataOutput.setSampleBufferDelegate(self, queue: self.dataOutputQueue)
            }
            
            if let audioPort = audioInput?.ports(
                for: .audio,
                sourceDeviceType: audioDevice?.deviceType,
                sourceDevicePosition: audioDevice?.position ?? .unspecified
            ).first {
                let audioDataOutput = AVCaptureAudioDataOutput()
                
                print("DEBUG: Can add audio data output: \(session.canAddOutput(audioDataOutput))")
                if session.canAddOutput(audioDataOutput) {
                    session.addOutputWithNoConnections(audioDataOutput)
                    self.audioDataOutput = audioDataOutput
                    
                    let audioDataConnection = AVCaptureConnection(inputPorts: [audioPort], output: audioDataOutput)
                    print("DEBUG: Can add audio data connection: \(session.canAddConnection(audioDataConnection))")
                    if session.canAddConnection(audioDataConnection) {
                        session.addConnection(audioDataConnection)
                    }
                    
                    audioDataOutput.setSampleBufferDelegate(self, queue: self.audioOutputQueue)
                }
            }
        }

        print("DEBUG: ✅ Configuration complete - all outputs configured successfully")
    }
    
    // MARK: - Audio Configuration
    private func configureAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            
            // Configure for recording with playback
            try audioSession.setCategory(.playAndRecord, mode: .videoRecording, options: [.defaultToSpeaker, .allowBluetoothA2DP])
            
            // Set preferred sample rate to 44.1kHz (standard for video)
            try audioSession.setPreferredSampleRate(44100.0)
            
            // Set preferred I/O buffer duration to minimize latency
            try audioSession.setPreferredIOBufferDuration(0.005)
            
            // Activate the session
            try audioSession.setActive(true)
            
            print("DEBUG: ✅ Audio session configured for recording")
            print("DEBUG: Audio session sample rate: \(audioSession.sampleRate)")
            print("DEBUG: Audio session category: \(audioSession.category)")
            
        } catch {
            print("DEBUG: ⚠️ Failed to configure audio session: \(error)")
        }
    }
    
    // MARK: - Professional Camera Features
    private func configureCameraProfessionalFeatures() {
        // Configure Center Stage for front camera (iOS 14.5+)
        if #available(iOS 14.5, *), let frontCamera = frontCamera {
            do {
                try frontCamera.lockForConfiguration()
                
                // Enable Center Stage (auto-framing feature)
                if frontCamera.isCenterStageActive {
                    print("DEBUG: ✅ Center Stage is already active")
                } else {
                    // Try to enable Center Stage globally
                    if #available(iOS 14.5, *) {
                        // Enable Center Stage (it will only work if device supports it)
                        AVCaptureDevice.isCenterStageEnabled = true
                        print("DEBUG: ✅ Attempted to enable Center Stage")
                        
                        if #available(iOS 15.4, *) {
                            frontCamera.automaticallyAdjustsFaceDrivenAutoFocusEnabled = true
                            print("DEBUG: ✅ Face-driven autofocus enabled")
                        }
                    }
                }
                
                frontCamera.unlockForConfiguration()
            } catch {
                print("DEBUG: ⚠️ Error configuring Center Stage: \(error)")
            }
        }
        
        // Configure HDR Video for both cameras
        configureHDRVideo(for: frontCamera, position: "Front")
        configureHDRVideo(for: backCamera, position: "Back")
        
        // Configure optimal format for each camera
        configureOptimalFormat(for: frontCamera, position: "Front")
        configureOptimalFormat(for: backCamera, position: "Back")
    }
    
    private func configureHDRVideo(for device: AVCaptureDevice?, position: String) {
        guard let device = device else { return }
        
        do {
            try device.lockForConfiguration()
            
            // Enable HDR video if supported
            if device.activeFormat.isVideoHDRSupported {
                device.automaticallyAdjustsVideoHDREnabled = true
                print("DEBUG: ✅ HDR Video enabled for \(position) camera")
            } else {
                print("DEBUG: ℹ️ HDR Video not supported on \(position) camera")
            }
            
            device.unlockForConfiguration()
        } catch {
            print("DEBUG: ⚠️ Error configuring HDR for \(position) camera: \(error)")
        }
    }
    
    private func configureOptimalFormat(for device: AVCaptureDevice?, position: String) {
        guard let device = device else { return }
        
        do {
            try device.lockForConfiguration()
            
            // Find best format for the current quality setting
            let desiredDimensions = activeVideoQuality.dimensions
            var bestFormat: AVCaptureDevice.Format?
            var bestScore = 0
            
            for format in device.formats {
                let dimensions = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
                
                // Score based on resolution match and HDR support
                var score = 0
                if dimensions.width == desiredDimensions.width && 
                   dimensions.height == desiredDimensions.height {
                    score += 100
                }
                if format.isVideoHDRSupported {
                    score += 50
                }
                if format.videoSupportedFrameRateRanges.contains(where: { $0.maxFrameRate >= 60 }) {
                    score += 25
                }
                
                if score > bestScore {
                    bestScore = score
                    bestFormat = format
                }
            }
            
            if let bestFormat = bestFormat {
                device.activeFormat = bestFormat
                print("DEBUG: ✅ Optimal format selected for \(position) camera (score: \(bestScore))")
            }
            
            device.unlockForConfiguration()
        } catch {
            print("DEBUG: ⚠️ Error configuring format for \(position) camera: \(error)")
        }
    }

    // MARK: - Session Control
    func startSessions() {
        guard let session = captureSession else {
            print("DEBUG: No capture session to start")
            return
        }

        print("DEBUG: Starting capture session...")
        sessionQueue.async {
            // Only start if not already running and setup is complete
            guard !session.isRunning && self.isSetupComplete else {
                print("DEBUG: Cannot start session - isRunning: \(session.isRunning), setupComplete: \(self.isSetupComplete)")
                return
            }

            session.startRunning()
            print("DEBUG: ✅ Capture session started successfully - isRunning: \(session.isRunning)")
        }
    }

    func stopSessions() {
        guard isSetupComplete, let session = captureSession else { return }

        sessionQueue.async {
            if session.isRunning {
                session.stopRunning()
            }
        }
    }

    // MARK: - Photo Capture
    func capturePhoto() {
        sessionQueue.async {
            guard self.isSetupComplete else { return }
            
            self.capturedFrontImage = nil
            self.capturedBackImage = nil
            self.photoCaptureCount = 0
            
            let settings = AVCapturePhotoSettings()
            settings.flashMode = self.isFlashOn ? .on : .off
            
            if let frontPhotoOutput = self.frontPhotoOutput {
                frontPhotoOutput.capturePhoto(with: settings, delegate: self)
            }
            
            if let backPhotoOutput = self.backPhotoOutput {
                backPhotoOutput.capturePhoto(with: settings, delegate: self)
            }
        }
    }
    
    // MARK: - Recording
    func startRecording() {
        sessionQueue.async {
            guard self.isSetupComplete, !self.isRecording else {
                print("DEBUG: Cannot start recording - setupComplete: \(self.isSetupComplete), alreadyRecording: \(self.isRecording)")
                return
            }
            
            // CRITICAL: Check permissions before recording
            let cameraStatus = AVCaptureDevice.authorizationStatus(for: .video)
            let audioStatus = AVCaptureDevice.authorizationStatus(for: .audio)
            let photoStatus = PHPhotoLibrary.authorizationStatus()
            
            guard cameraStatus == .authorized else {
                print("DEBUG: ⚠️ CRITICAL: Camera permission not granted!")
                DispatchQueue.main.async {
                    let error = DualCameraError.configurationFailed("Camera permission required. Please enable in Settings.")
                    ErrorHandlingManager.shared.handleError(error)
                    self.delegate?.didFailWithError(error)
                }
                return
            }
            
            guard audioStatus == .authorized else {
                print("DEBUG: ⚠️ CRITICAL: Microphone permission not granted!")
                DispatchQueue.main.async {
                    let error = DualCameraError.configurationFailed("Microphone permission required. Please enable in Settings.")
                    ErrorHandlingManager.shared.handleError(error)
                    self.delegate?.didFailWithError(error)
                }
                return
            }
            
            guard photoStatus == .authorized || photoStatus == .limited else {
                print("DEBUG: ⚠️ CRITICAL: Photo Library permission not granted!")
                DispatchQueue.main.async {
                    let error = DualCameraError.configurationFailed("Photo Library permission required to save videos. Please enable in Settings.")
                    ErrorHandlingManager.shared.handleError(error)
                    self.delegate?.didFailWithError(error)
                }
                return
            }
            
            // CRITICAL: Check if session is running before recording
            guard let session = self.captureSession, session.isRunning else {
                print("DEBUG: ⚠️ CRITICAL: Cannot start recording - camera session not running!")
                DispatchQueue.main.async {
                    let error = DualCameraError.configurationFailed("Camera session not running. Please restart the app.")
                    ErrorHandlingManager.shared.handleError(error)
                    self.delegate?.didFailWithError(error)
                }
                return
            }

            print("DEBUG: ✅ Starting recording... session running: \(session.isRunning), permissions verified")
            
            // Performance monitoring
            PerformanceMonitor.shared.beginRecording()
            
            // Configure audio for recording
            // self.audioManager.configureForRecording()
            
            // Check storage space before recording
            if !self.checkStorageSpace() {
                DispatchQueue.main.async {
                    ErrorHandlingManager.shared.handleCustomError(type: .storageSpace)
                }
                return
            }
            
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let timestamp = Int(Date().timeIntervalSince1970)

            // Initialize recording URLs based on triple output mode
            self.initializeRecordingURLs(timestamp: timestamp, documentsPath: documentsPath)

            // Start individual camera recordings based on mode
            self.startIndividualRecordings()

            // Setup triple output (combined video) if needed
            if self.enableTripleOutput && self.tripleOutputMode != .frontBackOnly {
                let combinedURL = documentsPath.appendingPathComponent("combined_\(timestamp).mp4")
                self.combinedVideoURL = combinedURL
                self.setupAssetWriter()
                print("DEBUG: Setup triple output recording to \(combinedURL.path)")
            }
            
            self.isRecording = true
            self.state = .recording
            print("DEBUG: ✅ Recording started successfully - isRecording: \(self.isRecording)")

            DispatchQueue.main.async {
                self.delegate?.didStartRecording()
            }
        }
    }
    
    private func initializeRecordingURLs(timestamp: Int, documentsPath: URL) {
        switch tripleOutputMode {
        case .allFiles:
            frontVideoURL = documentsPath.appendingPathComponent("front_\(timestamp).mov")
            backVideoURL = documentsPath.appendingPathComponent("back_\(timestamp).mov")
            
        case .combinedOnly:
            frontVideoURL = nil
            backVideoURL = nil
            
        case .frontBackOnly:
            frontVideoURL = documentsPath.appendingPathComponent("front_\(timestamp).mov")
            backVideoURL = documentsPath.appendingPathComponent("back_\(timestamp).mov")
        }
    }
    
    private func startIndividualRecordings() {
        switch tripleOutputMode {
        case .allFiles, .frontBackOnly:
            guard let frontOutput = frontMovieOutput, 
                  let frontURL = frontVideoURL,
                  !frontOutput.isRecording else {
                print("DEBUG: ⚠️ Front camera output not available or already recording")
                return
            }
            
            guard let backOutput = backMovieOutput,
                  let backURL = backVideoURL,
                  !backOutput.isRecording else {
                print("DEBUG: ⚠️ Back camera output not available or already recording")
                return
            }
            
            print("DEBUG: Starting front camera recording to \(frontURL.lastPathComponent)")
            frontOutput.startRecording(to: frontURL, recordingDelegate: self)
            
            print("DEBUG: Starting back camera recording to \(backURL.lastPathComponent)")
            backOutput.startRecording(to: backURL, recordingDelegate: self)
            
            print("DEBUG: ✅ Both camera outputs started recording")
            
        case .combinedOnly:
            print("DEBUG: Combined only mode - triple output will handle all recording")
        }
    }
    
    private func checkStorageSpace() -> Bool {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        
        do {
            let attributes = try FileManager.default.attributesOfFileSystem(forPath: documentsPath.path)
            if let freeSize = attributes[.systemFreeSize] as? NSNumber {
                let freeMB = freeSize.int64Value / (1024 * 1024)
                // Require at least 500MB of free space
                return freeMB > 500
            }
        } catch {
            print("Error checking storage space: \(error)")
        }
        
        return false
    }

    func stopRecording() {
        sessionQueue.async {
            guard self.isRecording else {
                print("DEBUG: Not recording, cannot stop")
                return
            }

            print("DEBUG: Stopping recording...")
            
            if self.frontMovieOutput?.isRecording == true {
                self.frontMovieOutput?.stopRecording()
                print("DEBUG: Stopped front camera recording")
            }

            if self.backMovieOutput?.isRecording == true {
                self.backMovieOutput?.stopRecording()
                print("DEBUG: Stopped back camera recording")
            }

            if self.enableTripleOutput {
                self.finishAssetWriter()
                print("DEBUG: Finished triple output recording")
            }

            self.isRecording = false
            self.state = .configured
            
            PerformanceMonitor.shared.endRecording()
            
            print("DEBUG: Recording stopped")
        }
    }

    // MARK: - Flash Control
    private(set) var isFlashOn: Bool = false

    func toggleFlash() {
        sessionQueue.async {
            guard let backCamera = self.backCamera, backCamera.hasTorch else { return }
            do {
                try backCamera.lockForConfiguration()
                if backCamera.torchMode == .on {
                    backCamera.torchMode = .off
                    self.isFlashOn = false
                } else {
                    try backCamera.setTorchModeOn(level: AVCaptureDevice.maxAvailableTorchLevel)
                    self.isFlashOn = true
                }
                backCamera.unlockForConfiguration()
            } catch {
                print("Flash toggle error: \(error)")
            }
        }
    }

    // MARK: - URL Helper
    func getRecordingURLs() -> (front: URL?, back: URL?, combined: URL?) {
        return (frontVideoURL, backVideoURL, combinedVideoURL)
    }

    // MARK: - Zoom Control
    func setZoom(for position: AVCaptureDevice.Position, scale: CGFloat) {
        sessionQueue.async {
            let camera = position == .front ? self.frontCamera : self.backCamera
            guard let device = camera else { return }

            do {
                try device.lockForConfiguration()
                let maxZoom = min(device.activeFormat.videoMaxZoomFactor, 5.0)
                let zoom = max(1.0, min(scale, maxZoom))
                device.videoZoomFactor = zoom
                device.unlockForConfiguration()
            } catch {
                print("Zoom error: \(error)")
            }
        }
    }

    // MARK: - Focus and Exposure Control
    func setFocusAndExposure(for position: AVCaptureDevice.Position, at point: CGPoint) {
        sessionQueue.async {
            let camera = position == .front ? self.frontCamera : self.backCamera
            guard let device = camera else { return }

            do {
                try device.lockForConfiguration()

                if device.isFocusPointOfInterestSupported && device.isFocusModeSupported(.autoFocus) {
                    device.focusPointOfInterest = point
                    device.focusMode = .autoFocus
                }

                if device.isExposurePointOfInterestSupported && device.isExposureModeSupported(.autoExpose) {
                    device.exposurePointOfInterest = point
                    device.exposureMode = .autoExpose
                }

                device.unlockForConfiguration()
            } catch {
                print("Focus/Exposure error: \(error)")
            }
        }
    }
    
    // MARK: - Performance Management
    
    func reduceQualityForMemoryPressure() {
        sessionQueue.async {
            if self.activeVideoQuality == .uhd4k {
                self.videoQuality = .hd1080
            } else if self.activeVideoQuality == .hd1080 {
                self.videoQuality = .hd720
            }
            
            self.frameCompositor?.setCurrentQualityLevel(0.7)
            self.frameCompositor?.flushBufferPool()
            
            PerformanceMonitor.shared.logEvent("Performance", "Reduced quality due to memory pressure")
        }
    }
    
    func restoreQualityAfterMemoryPressure() {
        sessionQueue.async {
            // Gradually restore quality
            self.frameCompositor?.setCurrentQualityLevel(1.0)
            
            PerformanceMonitor.shared.logEvent("Performance", "Restored quality after memory pressure")
        }
    }
    
    func getPerformanceMetrics() -> [String: Any] {
        return PerformanceMonitor.shared.getPerformanceSummary()
    }

}

extension DualCameraManager: AVCaptureFileOutputRecordingDelegate {
    func fileOutput(_ output: AVCaptureFileOutput, didStartRecordingTo fileURL: URL, from connections: [AVCaptureConnection]) {
        print("DEBUG: ✅ File output ACTUALLY started recording to: \(fileURL.lastPathComponent)")
        // This callback confirms the recording has actually begun writing to disk
    }
    
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        if let error {
            print("DEBUG: ⚠️ Recording error for \(outputFileURL.lastPathComponent): \(error)")
            DispatchQueue.main.async {
                ErrorHandlingManager.shared.handleError(error)
                self.delegate?.didFailWithError(error)
            }
            return
        }

        print("DEBUG: ✅ Recording finished successfully to: \(outputFileURL.lastPathComponent)")
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: outputFileURL.path)
            let fileSize = attributes[.size] as? Int64 ?? 0
            print("DEBUG: Recorded file size: \(fileSize) bytes (\(fileSize / 1024)KB)")
            
            if fileSize < 1024 {
                let error = DualCameraError.configurationFailed("Recording file is too small, likely failed")
                DispatchQueue.main.async {
                    ErrorHandlingManager.shared.handleError(error)
                    self.delegate?.didFailWithError(error)
                }
                return
            }
        } catch {
            print("DEBUG: Could not get file size: \(error)")
        }

        saveVideoToPhotosLibrary(url: outputFileURL)

        let frontFinished = tripleOutputMode == .combinedOnly || frontMovieOutput?.isRecording == false
        let backFinished = tripleOutputMode == .combinedOnly || backMovieOutput?.isRecording == false
        print("DEBUG: Front finished: \(frontFinished), Back finished: \(backFinished)")

        if frontFinished && backFinished && !isRecording {
            print("DEBUG: All recordings finished, notifying delegate")
            DispatchQueue.main.async {
                self.delegate?.didStopRecording()
            }
        }
    }
    
    private func saveVideoToPhotosLibrary(url: URL) {
        PHPhotoLibrary.requestAuthorization { status in
            switch status {
            case .authorized, .limited:
                PHPhotoLibrary.shared().performChanges({
                    PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
                }) { success, error in
                    if success {
                        print("DEBUG: Video saved to Photos: \(url.lastPathComponent)")
                    } else {
                        print("DEBUG: Failed to save video to Photos: \(error?.localizedDescription ?? "unknown error")")
                    }
                }
            case .denied, .restricted:
                print("DEBUG: Photos access denied, cannot save video")
            case .notDetermined:
                print("DEBUG: Photos permission not determined")
            @unknown default:
                print("DEBUG: Unknown Photos permission status")
            }
        }
    }
}

extension DualCameraManager: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error {
            print("Photo capture error: \(error)")
            return
        }

        guard let imageData = photo.fileDataRepresentation(),
              let image = UIImage(data: imageData) else {
            print("Failed to convert photo to image")
            return
        }

        if output == frontPhotoOutput {
            capturedFrontImage = image
        } else if output == backPhotoOutput {
            capturedBackImage = image
        }

        photoCaptureCount += 1

        if photoCaptureCount == 2 {
            DispatchQueue.main.async {
                self.delegate?.didCapturePhoto(frontImage: self.capturedFrontImage, backImage: self.capturedBackImage)
            }
        }
    }
}

// MARK: - Triple Output Implementation
extension DualCameraManager: AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput,
                      didOutput sampleBuffer: CMSampleBuffer,
                      from connection: AVCaptureConnection) {

        guard isRecording, enableTripleOutput else { return }

        if output == audioDataOutput {
            appendAudioSampleBuffer(sampleBuffer)
            return
        }

        PerformanceMonitor.shared.recordFrame()
        
        frameSyncQueue.sync {
            if output == frontDataOutput {
                frontFrameBuffer = sampleBuffer
            } else if output == backDataOutput {
                backFrameBuffer = sampleBuffer
            }

            if let frontBuffer = frontFrameBuffer,
               let backBuffer = backFrameBuffer {

                compositionQueue.async {
                    self.processFramePair(front: frontBuffer, back: backBuffer)
                }

                frontFrameBuffer = nil
                backFrameBuffer = nil
            }
        }
    }
    
    private func appendAudioSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
        guard let audioWriterInput = audioWriterInput,
              audioWriterInput.isReadyForMoreMediaData,
              recordingStartTime != nil else {
            return
        }
        
        audioWriterInput.append(sampleBuffer)
    }

    private func processFramePair(front: CMSampleBuffer, back: CMSampleBuffer) {
        // Performance monitoring
        PerformanceMonitor.shared.beginFrameProcessing()
        
        guard let frontPixelBuffer = CMSampleBufferGetImageBuffer(front),
              let backPixelBuffer = CMSampleBufferGetImageBuffer(back),
              assetWriter != nil,
              let videoWriterInput = videoWriterInput,
              let pixelBufferAdaptor = pixelBufferAdaptor else {
            PerformanceMonitor.shared.endFrameProcessing()
            return
        }

        // Initialize compositor if needed
        if frameCompositor == nil {
            // Use pictureInPicture layout by default (matches recordingLayout)
            frameCompositor = FrameCompositor(layout: .pictureInPicture, quality: activeVideoQuality)
        }

        let presentationTime = CMSampleBufferGetPresentationTimeStamp(front)

        // Set recording start time on first frame
        if recordingStartTime == nil {
            recordingStartTime = presentationTime
            print("DEBUG: First frame received - setting recording start time: \(CMTimeGetSeconds(presentationTime))s")
        }

        // Calculate relative time from start
        guard let startTime = recordingStartTime else {
            PerformanceMonitor.shared.endFrameProcessing()
            return
        }
        let relativeTime = CMTimeSubtract(presentationTime, startTime)
        
        // Ensure time is valid and positive
        guard relativeTime.seconds >= 0 else {
            print("DEBUG: ⚠️ Negative relative time: \(relativeTime.seconds)s - skipping frame")
            PerformanceMonitor.shared.endFrameProcessing()
            return
        }

        // Compose frames with performance monitoring
        guard let composedBuffer = frameCompositor?.composite(
            frontBuffer: frontPixelBuffer,
            backBuffer: backPixelBuffer,
            timestamp: relativeTime
        ) else {
            PerformanceMonitor.shared.endFrameProcessing()
            return
        }

        // Write to asset writer
        if videoWriterInput.isReadyForMoreMediaData {
            pixelBufferAdaptor.append(composedBuffer, withPresentationTime: relativeTime)
        }
        
        PerformanceMonitor.shared.endFrameProcessing()
    }

    private func setupAssetWriter() {
        guard let combinedURL = combinedVideoURL else { return }

        // Remove existing file if any
        try? FileManager.default.removeItem(at: combinedURL)

        do {
            let writer = try AVAssetWriter(outputURL: combinedURL, fileType: .mp4)
            
            // Verify writer status before proceeding
            guard writer.status == .unknown else {
                print("DEBUG: ⚠️ Asset writer in unexpected state: \(writer.status.rawValue)")
                return
            }

            let codec: AVVideoCodecType
            if #available(iOS 11.0, *) {
                codec = .hevc
                print("DEBUG: ✅ Using H.265/HEVC codec for superior quality")
            } else {
                codec = .h264
                print("DEBUG: Using H.264 codec (fallback)")
            }
            
            let bitrate: Int
            switch activeVideoQuality {
            case .hd720:
                bitrate = 8_000_000
            case .hd1080:
                bitrate = 15_000_000
            case .uhd4k:
                bitrate = 30_000_000
            }
            
            var compressionProperties: [String: Any] = [
                AVVideoAverageBitRateKey: bitrate,
                AVVideoMaxKeyFrameIntervalKey: 60,
                AVVideoAllowFrameReorderingKey: true,
                AVVideoExpectedSourceFrameRateKey: 30
            ]
            
            if codec == .h264 {
                compressionProperties[AVVideoProfileLevelKey] = AVVideoProfileLevelH264HighAutoLevel
            }
            
            let videoSettings: [String: Any] = [
                AVVideoCodecKey: codec,
                AVVideoWidthKey: activeVideoQuality.renderSize.width,
                AVVideoHeightKey: activeVideoQuality.renderSize.height,
                AVVideoCompressionPropertiesKey: compressionProperties
            ]

            let videoWriterInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
            videoWriterInput.expectsMediaDataInRealTime = true

            let sourcePixelBufferAttributes: [String: Any] = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey as String: activeVideoQuality.renderSize.width,
                kCVPixelBufferHeightKey as String: activeVideoQuality.renderSize.height,
                kCVPixelBufferMetalCompatibilityKey as String: true
            ]

            let pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(
                assetWriterInput: videoWriterInput,
                sourcePixelBufferAttributes: sourcePixelBufferAttributes
            )

            if writer.canAdd(videoWriterInput) {
                writer.add(videoWriterInput)
            }

            // Audio settings
            let audioSettings: [String: Any] = [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: 44100,
                AVNumberOfChannelsKey: 2,
                AVEncoderBitRateKey: 128000
            ]

            let audioWriterInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
            audioWriterInput.expectsMediaDataInRealTime = true

            if writer.canAdd(audioWriterInput) {
                writer.add(audioWriterInput)
            }

            self.assetWriter = writer
            self.videoWriterInput = videoWriterInput
            self.audioWriterInput = audioWriterInput
            self.pixelBufferAdaptor = pixelBufferAdaptor

            writer.startWriting()
            
            // Verify writing started successfully
            guard writer.status == .writing else {
                print("DEBUG: ⚠️ Failed to start asset writer - status: \(writer.status.rawValue)")
                if let error = writer.error {
                    print("DEBUG: Asset writer error: \(error)")
                }
                return
            }
            
            // Start session at source time zero for proper duration calculation
            writer.startSession(atSourceTime: .zero)

            isWriting = true
            // Reset recording start time so first frame sets it properly
            recordingStartTime = nil
            print("DEBUG: ✅ Asset writer started successfully (session time: .zero)")

        } catch {
            print("DEBUG: ⚠️ Failed to setup asset writer: \(error)")
            DispatchQueue.main.async {
                ErrorHandlingManager.shared.handleError(error)
            }
        }
    }

    private func finishAssetWriter() {
        guard let assetWriter = assetWriter, isWriting else { return }

        isWriting = false

        videoWriterInput?.markAsFinished()
        audioWriterInput?.markAsFinished()

        assetWriter.finishWriting { [weak self] in
            guard let self = self else { return }
            
            if assetWriter.status == .completed {
                print("DEBUG: ✅ Combined video saved successfully")
                if let combinedURL = self.combinedVideoURL {
                    do {
                        let attributes = try FileManager.default.attributesOfItem(atPath: combinedURL.path)
                        let fileSize = attributes[.size] as? Int64 ?? 0
                        print("DEBUG: Combined video file size: \(fileSize) bytes (\(fileSize / 1024)KB)")
                    } catch {
                        print("DEBUG: Could not get combined file size: \(error)")
                    }
                    self.saveVideoToPhotosLibrary(url: combinedURL)
                }
            } else if let error = assetWriter.error {
                print("DEBUG: ⚠️ Asset writer error: \(error)")
                DispatchQueue.main.async {
                    ErrorHandlingManager.shared.handleError(error)
                    self.delegate?.didFailWithError(error)
                }
            }

            self.assetWriter = nil
            self.videoWriterInput = nil
            self.audioWriterInput = nil
            self.pixelBufferAdaptor = nil
            self.frameCompositor = nil
            self.recordingStartTime = nil
        }
    }
}
