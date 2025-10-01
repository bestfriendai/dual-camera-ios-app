import AVFoundation
import UIKit
import Photos

protocol DualCameraManagerDelegate: AnyObject {
    func didStartRecording()
    func didStopRecording()
    func didFailWithError(_ error: Error)
    func didUpdateVideoQuality(to quality: VideoQuality)
    func didCapturePhoto(frontImage: UIImage?, backImage: UIImage?)
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
    private var isDeferredSetupComplete = false
    private(set) var activeVideoQuality: VideoQuality = .hd1080

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

    var recordingLayout: RecordingLayout = .sideBySide
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

    func setupCameras() {
        guard !isSetupComplete else { return }

        print("DEBUG: Setting up cameras...")
        // Get devices immediately (fast operation)
        frontCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
        backCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
        audioDevice = AVCaptureDevice.default(for: .audio)

        print("DEBUG: Front camera: \(frontCamera?.localizedName ?? "nil")")
        print("DEBUG: Back camera: \(backCamera?.localizedName ?? "nil")")
        print("DEBUG: Audio device: \(audioDevice?.localizedName ?? "nil")")

        guard frontCamera != nil, backCamera != nil else {
            let error = DualCameraError.missingDevices
            DispatchQueue.main.async {
                // Use error handling manager
                ErrorHandlingManager.shared.handleError(error)
                self.delegate?.didFailWithError(error)
            }
            return
        }

        // Use ASYNC instead of sync - don't block!
        sessionQueue.async {
            do {
                try self.configureSession()
                self.isSetupComplete = true

                // Notify on main thread
                DispatchQueue.main.async {
                    self.delegate?.didUpdateVideoQuality(to: self.videoQuality)
                }
            } catch {
                DispatchQueue.main.async {
                    // Use error handling manager
                    ErrorHandlingManager.shared.handleError(error)
                    self.delegate?.didFailWithError(error)
                }
                self.captureSession = nil
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

        let backConnection = AVCaptureConnection(inputPorts: [backVideoPort], output: backOutput)
        guard session.canAddConnection(backConnection) else {
            throw DualCameraError.configurationFailed("Unable to link back camera input with movie output.")
        }
        session.addConnection(backConnection)
        if backConnection.isVideoOrientationSupported {
            backConnection.videoOrientation = AVCaptureVideoOrientation.portrait
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
            frontDataOutput.setSampleBufferDelegate(self, queue: self.dataOutputQueue)
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
            }

            let backDataOutput = AVCaptureVideoDataOutput()
            backDataOutput.videoSettings = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
            ]
            backDataOutput.setSampleBufferDelegate(self, queue: self.dataOutputQueue)
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
            }
            
            if let audioPort = audioInput?.ports(
                for: .audio,
                sourceDeviceType: audioDevice?.deviceType,
                sourceDevicePosition: audioDevice?.position ?? .unspecified
            ).first {
                let audioDataOutput = AVCaptureAudioDataOutput()
                audioDataOutput.setSampleBufferDelegate(self, queue: self.audioOutputQueue)
                
                print("DEBUG: Can add audio data output: \(session.canAddOutput(audioDataOutput))")
                if session.canAddOutput(audioDataOutput) {
                    session.addOutputWithNoConnections(audioDataOutput)
                    self.audioDataOutput = audioDataOutput
                    
                    let audioDataConnection = AVCaptureConnection(inputPorts: [audioPort], output: audioDataOutput)
                    print("DEBUG: Can add audio data connection: \(session.canAddConnection(audioDataConnection))")
                    if session.canAddConnection(audioDataConnection) {
                        session.addConnection(audioDataConnection)
                    }
                }
            }
        }

        // Mark deferred setup as complete
        self.isDeferredSetupComplete = true
        print("DEBUG: Configuration complete - all outputs configured successfully")
    }

    // MARK: - Deferred Setup (runs in background after camera is visible)
    @available(iOS 13.0, *)
    private func setupDeferredOutputs(session: AVCaptureMultiCamSession, frontVideoPort: AVCaptureInput.Port, backVideoPort: AVCaptureInput.Port) {
        print("DEBUG: Starting deferred setup")

        sessionQueue.async {
            print("DEBUG: Deferred setup in session queue")
            session.beginConfiguration()
            defer { session.commitConfiguration() }

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
                frontDataOutput.setSampleBufferDelegate(self, queue: self.dataOutputQueue)
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
                }

                let backDataOutput = AVCaptureVideoDataOutput()
                backDataOutput.videoSettings = [
                    kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
                ]
                backDataOutput.setSampleBufferDelegate(self, queue: self.dataOutputQueue)
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
                }
            }
        }

        // Mark deferred setup as complete
        self.isDeferredSetupComplete = true
        print("DEBUG: Deferred setup complete")
    }

    // MARK: - Session Control
    func startSessions() {
        guard let session = captureSession else {
            print("DEBUG: No capture session to start")
            return
        }

        print("DEBUG: Starting capture session...")
        sessionQueue.async {
            // Only start if not already running, setup is complete, and deferred setup is complete
            guard !session.isRunning && self.isSetupComplete && self.isDeferredSetupComplete else {
                print("DEBUG: Cannot start session - isRunning: \(session.isRunning), setupComplete: \(self.isSetupComplete), deferredComplete: \(self.isDeferredSetupComplete)")
                // If deferred setup isn't complete yet, schedule to start later
                if self.isSetupComplete && !self.isDeferredSetupComplete {
                    DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 0.5) {
                        self.startSessions()
                    }
                }
                return
            }

            session.startRunning()
            print("DEBUG: Capture session started successfully")
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

            print("DEBUG: Starting recording... session running: \(self.captureSession?.isRunning ?? false)")
            
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
                self.combinedVideoURL = documentsPath.appendingPathComponent("combined_\(timestamp).mp4")
                self.setupAssetWriter()
                print("DEBUG: Setup triple output recording to \(self.combinedVideoURL!)")
            }
            
            // Start audio recording
            let audioURL = documentsPath.appendingPathComponent("audio_\(timestamp).m4a")
            let audioStarted = self.audioManager.startAudioRecording(to: audioURL)
            if audioStarted {
                print("DEBUG: Audio recording started")
            } else {
                print("DEBUG: Failed to start audio recording")
            }

            self.isRecording = true
            print("DEBUG: Recording started successfully")

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
            // Individual files not needed for combined only mode
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
            // Start front camera recording
            if let frontOutput = frontMovieOutput, let frontURL = frontVideoURL {
                frontOutput.startRecording(to: frontURL, recordingDelegate: self)
                print("DEBUG: Started front camera recording to \(frontURL)")
            } else {
                print("DEBUG: Front camera output or URL not available")
                let error = DualCameraError.configurationFailed("Front camera output not available")
                DispatchQueue.main.async {
                    ErrorHandlingManager.shared.handleError(error)
                }
            }
            
            // Start back camera recording
            if let backOutput = backMovieOutput, let backURL = backVideoURL {
                backOutput.startRecording(to: backURL, recordingDelegate: self)
                print("DEBUG: Started back camera recording to \(backURL)")
            } else {
                print("DEBUG: Back camera output or URL not available")
                let error = DualCameraError.configurationFailed("Back camera output not available")
                DispatchQueue.main.async {
                    ErrorHandlingManager.shared.handleError(error)
                }
            }
            
        case .combinedOnly:
            // Don't start individual recordings for combined only mode
            print("DEBUG: Skipping individual recordings for combined only mode")
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

            // Stop triple output
            if self.enableTripleOutput {
                self.finishAssetWriter()
                print("DEBUG: Finished triple output recording")
            }

            self.isRecording = false
            
            // Performance monitoring
            PerformanceMonitor.shared.endRecording()
            
            print("DEBUG: Recording stopped")
        }
    }

    // MARK: - Flash Control
    private(set) var isFlashOn: Bool = false

    func toggleFlash() {
        sessionQueue.sync {
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
            // Reduce video quality temporarily
            if self.activeVideoQuality == .uhd4k {
                self.videoQuality = .hd1080
            } else if self.activeVideoQuality == .hd1080 {
                self.videoQuality = .hd720
            }
            
            // Reduce frame compositor quality
            self.frameCompositor?.setCurrentQualityLevel(0.7)
            
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
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        if let error {
            print("DEBUG: Recording error for \(outputFileURL.lastPathComponent): \(error)")
            DispatchQueue.main.async {
                ErrorHandlingManager.shared.handleError(error)
                self.delegate?.didFailWithError(error)
            }
            return
        }

        print("DEBUG: Recording finished successfully to: \(outputFileURL)")
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: outputFileURL.path)
            let fileSize = attributes[.size] as? Int64 ?? 0
            print("DEBUG: Recorded file size: \(fileSize) bytes")
            
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

        let frontFinished = frontMovieOutput?.isRecording == false
        let backFinished = backMovieOutput?.isRecording == false
        print("DEBUG: Front finished: \(frontFinished), Back finished: \(backFinished)")

        if frontFinished && backFinished {
            print("DEBUG: Both recordings finished, notifying delegate")
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
              audioWriterInput.isReadyForMoreMediaData else {
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
            frameCompositor = FrameCompositor(layout: recordingLayout, quality: activeVideoQuality)
        }

        let presentationTime = CMSampleBufferGetPresentationTimeStamp(front)

        // Set recording start time on first frame
        if recordingStartTime == nil {
            recordingStartTime = presentationTime
        }

        // Calculate relative time
        guard let startTime = recordingStartTime else {
            PerformanceMonitor.shared.endFrameProcessing()
            return
        }
        let relativeTime = CMTimeSubtract(presentationTime, startTime)

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

            // Video settings
            let videoSettings: [String: Any] = [
                AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoWidthKey: activeVideoQuality.renderSize.width,
                AVVideoHeightKey: activeVideoQuality.renderSize.height,
                AVVideoCompressionPropertiesKey: [
                    AVVideoAverageBitRateKey: 10_000_000,
                    AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel
                ]
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
            writer.startSession(atSourceTime: .zero)

            isWriting = true
            recordingStartTime = nil

        } catch {
            print("Failed to setup asset writer: \(error)")
        }
    }

    private func finishAssetWriter() {
        guard let assetWriter = assetWriter, isWriting else { return }

        isWriting = false

        videoWriterInput?.markAsFinished()
        audioWriterInput?.markAsFinished()

        assetWriter.finishWriting { [weak self] in
            if assetWriter.status == .completed {
                print("Combined video saved successfully")
                if let combinedURL = self?.combinedVideoURL {
                    self?.saveVideoToPhotosLibrary(url: combinedURL)
                }
            } else if let error = assetWriter.error {
                print("Asset writer error: \(error)")
            }

            self?.assetWriter = nil
            self?.videoWriterInput = nil
            self?.audioWriterInput = nil
            self?.pixelBufferAdaptor = nil
            self?.frameCompositor = nil
            self?.recordingStartTime = nil
        }
    }
}
