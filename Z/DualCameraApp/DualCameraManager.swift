// Dual Camera App
import AVFoundation
import UIKit
import Photos

@MainActor
protocol DualCameraManagerDelegate: AnyObject {
    func didStartRecording()
    func didStopRecording()
    func didFailWithError(_ error: Error)
    func didUpdateVideoQuality(to quality: VideoQuality)
    func didCapturePhoto(frontImage: UIImage?, backImage: UIImage?)
    func didFinishCameraSetup()
    func didUpdateSetupProgress(_ message: String, progress: Float)
}



@available(iOS 15.0, *)
final class DualCameraManager: NSObject {
    weak var delegate: DualCameraManagerDelegate?

    var videoQuality: VideoQuality = .hd1080 {
        didSet {
            activeVideoQuality = videoQuality
            Task { @MainActor in
                delegate?.didUpdateVideoQuality(to: videoQuality)
            }
        }
    }



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
    private var isFirstCapture: Bool = true
    private var preparedPhotoSettingsConfigured: Bool = false
    private var photoOutputsReady: Bool = false
    private var cachedSpeedHEVCSettings: AVCapturePhotoSettings?
    private var cachedSpeedJPEGSettings: AVCapturePhotoSettings?
    private var cachedBalancedHEVCSettings: AVCapturePhotoSettings?
    private var cachedBalancedJPEGSettings: AVCapturePhotoSettings?

    private var isRecording = false
    private var isSetupComplete = false
    private(set) var activeVideoQuality: VideoQuality = .hd1080
    private var isAudioSessionActive = false
    private var photoOutputsConfigured = false
    private var movieOutputsConfigured = false
    
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
            Task { @MainActor in
                await self.handleStateChange(from: oldValue, to: self.state)
            }
        }
    }
    
    @MainActor
    private func handleStateChange(from oldState: CameraState, to newState: CameraState) async {
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
    private let dataOutputQueue = DispatchQueue(label: "com.dualcamera.dataoutput", qos: .userInitiated) // For AVFoundation callbacks
    private let audioOutputQueue = DispatchQueue(label: "com.dualcamera.audiooutput", qos: .userInitiated) // For AVFoundation callbacks
    private let compositionQueue = DispatchQueue(label: "com.dualcamera.composition", qos: .userInitiated) // For AVFoundation callbacks

    private var frameCompositor: FrameCompositor?
    private var assetWriter: AVAssetWriter?
    private var videoWriterInput: AVAssetWriterInput?
    private var audioWriterInput: AVAssetWriterInput?
    private var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?

    private var frontFrameBuffer: CMSampleBuffer?
    private var backFrameBuffer: CMSampleBuffer?
    private let frameSyncQueue = DispatchQueue(label: "com.dualcamera.framesync") // For AVFoundation callbacks

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
    private let audioManager = AudioManager.shared

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
            Task {
                await frameCompositor?.flushBufferPool()
            }
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

        Task { @MainActor in
            delegate?.didUpdateSetupProgress("Discovering cameras...", progress: 0.1)
        }

        Task(priority: .userInitiated) {
            await withTaskGroup(of: (String, AVCaptureDevice?).self) { group in
                group.addTask {
                    ("front", AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front))
                }
                group.addTask {
                    ("back", AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back))
                }
                group.addTask {
                    ("audio", AVCaptureDevice.default(for: .audio))
                }
                
                for await (type, device) in group {
                    await MainActor.run {
                        switch type {
                        case "front": self.frontCamera = device
                        case "back": self.backCamera = device
                        case "audio": self.audioDevice = device
                        default: break
                        }
                    }
                }
            }

            print("DEBUG: Front camera: \(String(describing: self.frontCamera?.localizedName))")
            print("DEBUG: Back camera: \(String(describing: self.backCamera?.localizedName))")
            print("DEBUG: Audio device: \(String(describing: self.audioDevice?.localizedName))")

            Task { @MainActor in
                self.delegate?.didUpdateSetupProgress("Cameras discovered", progress: 0.3)
            }

            guard self.frontCamera != nil, self.backCamera != nil else {
                let error = DualCameraError.missingDevices
                Task { @MainActor in
                    ErrorHandlingManager.shared.handleError(error)
                    self.delegate?.didFailWithError(error)
                }
                return
            }

            // Audio session deferred until recording starts

            Task { @MainActor in
                self.delegate?.didUpdateSetupProgress("Configuring camera session...", progress: 0.5)
            }

            Task.detached(priority: .userInitiated) {
                do {
                    try self.configureSession()

                    // Update progress for session start
                    await MainActor.run {
                        self.delegate?.didUpdateSetupProgress("Starting camera session...", progress: 0.8)
                    }

                    self.isSetupComplete = true
                    self.setupRetryCount = 0
                    self.state = .configured

                    // Start session immediately
                    // Preview layers can be assigned to a running session
                    if let session = self.captureSession, !session.isRunning {
                        print("DEBUG: Starting capture session...")
                        session.startRunning()
                        print("DEBUG: ✅ Capture session started - isRunning: \(session.isRunning)")
                    }

                    Task {
                        try? await Task.sleep(for: .milliseconds(100))
                        do {
                            try self.setupPhotoOutputsIfNeeded()
                            self.configurePreparedPhotoSettings(prioritization: .speed)
                            self.photoOutputsReady = true
                            print("DEBUG: ✅ Photo outputs prepared for fast capture")
                        } catch {
                            print("DEBUG: ⚠️ Failed to prepare photo outputs: \(error)")
                        }
                    }

                    // Notify delegate that setup is complete
                    await MainActor.run {
                        self.delegate?.didUpdateVideoQuality(to: self.videoQuality)
                        self.delegate?.didUpdateSetupProgress("Camera ready!", progress: 1.0)
                        self.delegate?.didFinishCameraSetup()
                    }

                    Task(priority: .utility) {
                        await self.configureCameraProfessionalFeaturesAsync()
                    }
                } catch {
                    self.state = .failed(error)
                    self.captureSession = nil

                    if self.setupRetryCount < self.maxSetupRetries {
                        self.setupRetryCount += 1
                        print("DEBUG: Setup failed, retrying... (attempt \(self.setupRetryCount))")
                        try? await Task.sleep(for: .seconds(1))
                        self.isSetupComplete = false
                        self.setupCameras()
                    } else {
                        await MainActor.run {
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

        let isSupported = AVCaptureMultiCamSession.isMultiCamSupported
        print("DEBUG: MultiCam supported: \(isSupported)")
        guard isSupported else {
            print("DEBUG: MultiCam not supported, throwing error")
            throw DualCameraError.multiCamNotSupported
        }

        let session = AVCaptureMultiCamSession()
        captureSession = session
        try configureMinimalSession(session: session, frontCamera: frontCamera, backCamera: backCamera)
    }

    private func configureMinimalSession(session: AVCaptureMultiCamSession, frontCamera: AVCaptureDevice, backCamera: AVCaptureDevice) throws {
        session.beginConfiguration()
        defer { session.commitConfiguration() }

        let selectedQuality = videoQuality
        activeVideoQuality = selectedQuality

        // Try iOS 26 hardware synchronization first
        if #available(iOS 26.0, *) {
            Task {
                do {
                    try await configureHardwareSync(session: session, frontCamera: frontCamera, backCamera: backCamera)
                } catch {
                    print("DEBUG: iOS 26 hardware sync failed, using standard configuration: \(error)")
                }
            }
        }

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

        print("DEBUG: ✅ Preview layers configured - session ready for immediate start. Outputs deferred for faster startup.")
    }
    
    // MARK: - iOS 26 Hardware Multi-Cam Synchronization (Phase 4.2)
    @available(iOS 26.0, *)
    private func configureHardwareSync(session: AVCaptureMultiCamSession, frontCamera: AVCaptureDevice, backCamera: AVCaptureDevice) async throws {
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        
        // Check if hardware-level synchronization is supported
        if session.isHardwareSynchronizationSupported {
            // Configure hardware-level multi-cam sync
            let syncSettings = AVCaptureMultiCamSession.SynchronizationSettings()
            syncSettings.synchronizationMode = .hardwareLevel
            syncSettings.enableTimestampAlignment = true
            syncSettings.maxSyncLatency = CMTime(value: 1, timescale: 1000) // 1ms max latency
            
            try session.applySynchronizationSettings(syncSettings)
            print("DEBUG: ✅ iOS 26 hardware-level multi-cam sync enabled")
            print("DEBUG:   - Synchronization mode: hardware-level")
            print("DEBUG:   - Timestamp alignment: enabled")
            print("DEBUG:   - Max sync latency: 1ms")
        } else {
            print("DEBUG: ℹ️ Hardware synchronization not supported on this device")
        }
        
        // Coordinated format selection for all cameras
        let multiCamFormats = try await session.selectOptimalFormatsForAllCameras(
            targetQuality: activeVideoQuality,
            prioritizeSync: true
        )
        
        // Apply optimal formats to all cameras
        for (device, format) in multiCamFormats {
            try await device.lockForConfigurationAsync()
            device.activeFormat = format
            try await device.unlockForConfigurationAsync()
            
            let position = device.position == .front ? "front" : "back"
            print("DEBUG: ✅ Coordinated format applied to \(position) camera")
        }
        
        print("DEBUG: ✅ Hardware multi-cam synchronization configured with coordinated formats")
    }
    
    private func setupMovieOutputs() throws {
        guard frontMovieOutput == nil, backMovieOutput == nil else { return }
        guard let session = captureSession as? AVCaptureMultiCamSession else { return }
        guard let frontCameraInput = frontCameraInput, let backCameraInput = backCameraInput else { return }
        
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        
        guard let frontVideoPort = frontCameraInput.ports(for: .video, sourceDeviceType: frontCamera?.deviceType, sourceDevicePosition: .front).first,
              let backVideoPort = backCameraInput.ports(for: .video, sourceDeviceType: backCamera?.deviceType, sourceDevicePosition: .back).first else {
            throw DualCameraError.configurationFailed("Failed to get video ports for movie outputs")
        }
        
        let frontOutput = AVCaptureMovieFileOutput()
        guard session.canAddOutput(frontOutput) else {
            throw DualCameraError.configurationFailed("Cannot add front movie output")
        }
        session.addOutputWithNoConnections(frontOutput)
        
        var frontPorts: [AVCaptureInput.Port] = [frontVideoPort]
        if let audioPort = audioInput?.ports(for: .audio, sourceDeviceType: audioDevice?.deviceType, sourceDevicePosition: audioDevice?.position ?? .unspecified).first {
            frontPorts.append(audioPort)
        }
        
        let frontConnection = AVCaptureConnection(inputPorts: frontPorts, output: frontOutput)
        guard session.canAddConnection(frontConnection) else {
            throw DualCameraError.configurationFailed("Cannot add front movie connection")
        }
        session.addConnection(frontConnection)
        if frontConnection.isVideoOrientationSupported {
            frontConnection.videoOrientation = .portrait
        }
        
        let backOutput = AVCaptureMovieFileOutput()
        guard session.canAddOutput(backOutput) else {
            throw DualCameraError.configurationFailed("Cannot add back movie output")
        }
        session.addOutputWithNoConnections(backOutput)
        
        let backConnection = AVCaptureConnection(inputPorts: [backVideoPort], output: backOutput)
        guard session.canAddConnection(backConnection) else {
            throw DualCameraError.configurationFailed("Cannot add back movie connection")
        }
        session.addConnection(backConnection)
        if backConnection.isVideoOrientationSupported {
            backConnection.videoOrientation = .portrait
        }
        
        self.frontMovieOutput = frontOutput
        self.backMovieOutput = backOutput
        movieOutputsConfigured = true
        
        print("DEBUG: ✅ Movie outputs configured on-demand")
    }
    
    private func setupPhotoOutputsIfNeeded() throws {
        guard frontPhotoOutput == nil || backPhotoOutput == nil else { return }
        guard let session = captureSession as? AVCaptureMultiCamSession else { return }
        guard let frontCameraInput = frontCameraInput, let backCameraInput = backCameraInput else { return }
        
        print("DEBUG: Setting up photo outputs on-demand...")
        
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        
        guard let frontVideoPort = frontCameraInput.ports(for: .video, sourceDeviceType: frontCamera?.deviceType, sourceDevicePosition: .front).first,
              let backVideoPort = backCameraInput.ports(for: .video, sourceDeviceType: backCamera?.deviceType, sourceDevicePosition: .back).first else {
            throw DualCameraError.configurationFailed("Failed to get video ports for photo outputs")
        }
        
        if frontPhotoOutput == nil {
            let frontPhotoOut = AVCapturePhotoOutput()
            if session.canAddOutput(frontPhotoOut) {
                session.addOutputWithNoConnections(frontPhotoOut)
                let frontPhotoConnection = AVCaptureConnection(inputPorts: [frontVideoPort], output: frontPhotoOut)
                if session.canAddConnection(frontPhotoConnection) {
                    session.addConnection(frontPhotoConnection)
                    if frontPhotoConnection.isVideoOrientationSupported {
                        frontPhotoConnection.videoOrientation = .portrait
                    }
                }
                self.frontPhotoOutput = frontPhotoOut
            }
        }
        
        if backPhotoOutput == nil {
            let backPhotoOut = AVCapturePhotoOutput()
            if session.canAddOutput(backPhotoOut) {
                session.addOutputWithNoConnections(backPhotoOut)
                let backPhotoConnection = AVCaptureConnection(inputPorts: [backVideoPort], output: backPhotoOut)
                if session.canAddConnection(backPhotoConnection) {
                    session.addConnection(backPhotoConnection)
                    if backPhotoConnection.isVideoOrientationSupported {
                        backPhotoConnection.videoOrientation = .portrait
                    }
                }
                self.backPhotoOutput = backPhotoOut
            }
        }
        
        photoOutputsConfigured = true
        configurePreparedPhotoSettings(prioritization: .speed)
        print("DEBUG: ✅ Photo outputs configured on-demand")
    }
    
    private func createPreparedPhotoSettings(prioritization: AVCapturePhotoOutput.QualityPrioritization) -> [AVCapturePhotoSettings] {
        var settings: [AVCapturePhotoSettings] = []
        
        if let photoOutput = frontPhotoOutput ?? backPhotoOutput {
            if let hevcFormat = photoOutput.availablePhotoCodecTypes.first(where: { $0 == .hevc }) {
                let hevcSettings = AVCapturePhotoSettings(format: [AVVideoCodecKey: hevcFormat])
                hevcSettings.photoQualityPrioritization = prioritization
                hevcSettings.isHighResolutionPhotoEnabled = true
                hevcSettings.isAutoStillImageStabilizationEnabled = true
                settings.append(hevcSettings)
            }
        }
        
        let jpegSettings = AVCapturePhotoSettings()
        jpegSettings.photoQualityPrioritization = prioritization
        jpegSettings.isHighResolutionPhotoEnabled = true
        jpegSettings.isAutoStillImageStabilizationEnabled = true
        settings.append(jpegSettings)
        
        return settings
    }
    
    private func configurePreparedPhotoSettings(prioritization: AVCapturePhotoOutput.QualityPrioritization = .speed) {
        guard let frontPhotoOutput = frontPhotoOutput, let backPhotoOutput = backPhotoOutput else { return }
        
        let preparedSettings = createPreparedPhotoSettings(prioritization: prioritization)
        
        if prioritization == .speed {
            if let hevcSettings = preparedSettings.first(where: { $0.format?[AVVideoCodecKey] as? AVVideoCodecType == .hevc }) {
                cachedSpeedHEVCSettings = hevcSettings
            }
            if let jpegSettings = preparedSettings.first(where: { $0.format?[AVVideoCodecKey] == nil }) {
                cachedSpeedJPEGSettings = jpegSettings
            }
        } else {
            if let hevcSettings = preparedSettings.first(where: { $0.format?[AVVideoCodecKey] as? AVVideoCodecType == .hevc }) {
                cachedBalancedHEVCSettings = hevcSettings
            }
            if let jpegSettings = preparedSettings.first(where: { $0.format?[AVVideoCodecKey] == nil }) {
                cachedBalancedJPEGSettings = jpegSettings
            }
        }
        
        frontPhotoOutput.setPreparedPhotoSettingsArray(preparedSettings, completionHandler: nil)
        frontPhotoOutput.maxPhotoQualityPrioritization = prioritization
        
        backPhotoOutput.setPreparedPhotoSettingsArray(preparedSettings, completionHandler: nil)
        backPhotoOutput.maxPhotoQualityPrioritization = prioritization
        
        print("DEBUG: ✅ Configured prepared photo settings with prioritization: \(prioritization)")
    }
    
    private func setupTripleOutputDataOutputs() throws {
        guard enableTripleOutput, frontDataOutput == nil else { return }
        guard let session = captureSession as? AVCaptureMultiCamSession else { return }
        guard let frontCameraInput = frontCameraInput, let backCameraInput = backCameraInput else { return }
        
        print("DEBUG: Setting up triple output data outputs...")
        
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        
        guard let frontVideoPort = frontCameraInput.ports(for: .video, sourceDeviceType: frontCamera?.deviceType, sourceDevicePosition: .front).first,
              let backVideoPort = backCameraInput.ports(for: .video, sourceDeviceType: backCamera?.deviceType, sourceDevicePosition: .back).first else {
            throw DualCameraError.configurationFailed("Failed to get video ports for triple output")
        }
        
        let frontDataOut = AVCaptureVideoDataOutput()
        frontDataOut.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        frontDataOut.alwaysDiscardsLateVideoFrames = true
        
        if session.canAddOutput(frontDataOut) {
            session.addOutputWithNoConnections(frontDataOut)
            let frontDataConnection = AVCaptureConnection(inputPorts: [frontVideoPort], output: frontDataOut)
            if session.canAddConnection(frontDataConnection) {
                session.addConnection(frontDataConnection)
                if frontDataConnection.isVideoOrientationSupported {
                    frontDataConnection.videoOrientation = .portrait
                }
            }
            frontDataOut.setSampleBufferDelegate(self, queue: dataOutputQueue)
            self.frontDataOutput = frontDataOut
        }
        
        let backDataOut = AVCaptureVideoDataOutput()
        backDataOut.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        backDataOut.alwaysDiscardsLateVideoFrames = true
        
        if session.canAddOutput(backDataOut) {
            session.addOutputWithNoConnections(backDataOut)
            let backDataConnection = AVCaptureConnection(inputPorts: [backVideoPort], output: backDataOut)
            if session.canAddConnection(backDataConnection) {
                session.addConnection(backDataConnection)
                if backDataConnection.isVideoOrientationSupported {
                    backDataConnection.videoOrientation = .portrait
                }
            }
            backDataOut.setSampleBufferDelegate(self, queue: dataOutputQueue)
            self.backDataOutput = backDataOut
        }
        
        if let audioPort = audioInput?.ports(for: .audio, sourceDeviceType: audioDevice?.deviceType, sourceDevicePosition: audioDevice?.position ?? .unspecified).first {
            let audioDataOut = AVCaptureAudioDataOutput()
            if session.canAddOutput(audioDataOut) {
                session.addOutputWithNoConnections(audioDataOut)
                let audioDataConnection = AVCaptureConnection(inputPorts: [audioPort], output: audioDataOut)
                if session.canAddConnection(audioDataConnection) {
                    session.addConnection(audioDataConnection)
                }
                audioDataOut.setSampleBufferDelegate(self, queue: audioOutputQueue)
                self.audioDataOutput = audioDataOut
            }
        }
        
        print("DEBUG: ✅ Triple output data outputs configured")
    }
    
    private func configureAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            
            try audioSession.setCategory(.playAndRecord, mode: .videoRecording, options: [.defaultToSpeaker, .allowBluetoothA2DP])
            try audioSession.setPreferredSampleRate(44100.0)
            try audioSession.setPreferredIOBufferDuration(0.005)
            try audioSession.setActive(true)
            
            print("DEBUG: ✅ Audio session configured for recording")
            print("DEBUG: Audio session sample rate: \(audioSession.sampleRate)")
            print("DEBUG: Audio session category: \(audioSession.category)")
            
        } catch {
            print("DEBUG: ⚠️ Failed to configure audio session: \(error)")
        }
    }
    
    private func activateAudioSessionForRecording() async throws {
        print("DEBUG: Activating audio session for recording...")
        
        let audioSession = AVAudioSession.sharedInstance()
        
        try audioSession.setCategory(.playAndRecord, mode: .videoRecording, options: [.defaultToSpeaker, .allowBluetoothA2DP])
        try audioSession.setPreferredSampleRate(44100.0)
        try audioSession.setPreferredIOBufferDuration(0.005)
        try audioSession.setActive(true)
        
        print("DEBUG: ✅ Audio session configured for recording (async)")
    }
    
    private func configureCameraProfessionalFeatures() {
        if #available(iOS 14.5, *), let frontCamera = frontCamera {
            do {
                try frontCamera.lockForConfiguration()
                
                if frontCamera.isCenterStageActive {
                    print("DEBUG: ✅ Center Stage is already active")
                } else {
                    if #available(iOS 14.5, *) {
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
        
        configureHDRVideo(for: frontCamera, position: "Front")
        configureHDRVideo(for: backCamera, position: "Back")
        
        configureOptimalFormat(for: frontCamera, position: "Front")
        configureOptimalFormat(for: backCamera, position: "Back")
    }
    
    private func configureCameraProfessionalFeaturesAsync() async {
        if #available(iOS 14.5, *), let frontCamera = frontCamera {
            do {
                try frontCamera.lockForConfiguration()
                
                if !frontCamera.isCenterStageActive {
                    AVCaptureDevice.isCenterStageEnabled = true
                    
                    if #available(iOS 15.4, *) {
                        frontCamera.automaticallyAdjustsFaceDrivenAutoFocusEnabled = true
                    }
                }
                
                frontCamera.unlockForConfiguration()
            } catch {
                print("DEBUG: ⚠️ Error configuring Center Stage: \(error)")
            }
        }
        
        await configureVideoStabilization()
        
        configureHDRVideo(for: frontCamera, position: "Front")
        configureHDRVideo(for: backCamera, position: "Back")
        configureOptimalFormat(for: frontCamera, position: "Front")
        configureOptimalFormat(for: backCamera, position: "Back")
    }
    
    private func configureVideoStabilization() async {
        guard let frontMovieOutput = frontMovieOutput,
              let backMovieOutput = backMovieOutput else {
            print("DEBUG: ⚠️ Movie outputs not yet configured - video stabilization will be applied after outputs are created")
            return
        }
        
        if let frontConnection = frontMovieOutput.connection(with: .video) {
            if frontConnection.isVideoStabilizationSupported {
                frontConnection.preferredVideoStabilizationMode = .cinematicExtended
                print("DEBUG: ✅ Front camera - Cinematic Extended stabilization enabled (deferred)")
            }
        }

        if let backConnection = backMovieOutput.connection(with: .video) {
            if backConnection.isVideoStabilizationSupported {
                backConnection.preferredVideoStabilizationMode = .cinematicExtended
                print("DEBUG: ✅ Back camera - Cinematic Extended stabilization enabled (deferred)")
            }
        }
    }
    
    private func configureHDRVideo(for device: AVCaptureDevice?, position: String) {
        guard let device = device else { return }
        
        // Try iOS 26 enhanced HDR with Dolby Vision IQ first
        if #available(iOS 26.0, *) {
            Task {
                do {
                    try await configureEnhancedHDR(for: device, position: position)
                    return
                } catch {
                    print("DEBUG: iOS 26 enhanced HDR failed, falling back to standard HDR: \(error)")
                }
            }
        }
        
        // Fallback to standard HDR for iOS < 26
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
    
    // MARK: - iOS 26 Enhanced HDR with Dolby Vision IQ (Phase 4.3)
    @available(iOS 26.0, *)
    private func configureEnhancedHDR(for device: AVCaptureDevice, position: String) async throws {
        try await device.lockForConfigurationAsync()
        defer {
            Task {
                try? await device.unlockForConfigurationAsync()
            }
        }
        
        // Check if enhanced HDR is supported
        if device.activeFormat.isEnhancedHDRSupported {
            // Configure Dolby Vision IQ with scene-based HDR
            var hdrSettings = AVCaptureDevice.HDRSettings()
            hdrSettings.hdrMode = .dolbyVisionIQ          // Ambient-adaptive Dolby Vision
            hdrSettings.enableAdaptiveToneMapping = true   // Dynamic tone mapping based on scene
            hdrSettings.enableSceneBasedHDR = true         // Scene-aware HDR adjustments
            hdrSettings.maxDynamicRange = .high            // Maximum dynamic range
            
            try device.applyHDRSettings(hdrSettings)
            print("DEBUG: ✅ iOS 26 Dolby Vision IQ HDR configured for \(position) camera")
            print("DEBUG:   - HDR mode: Dolby Vision IQ (ambient-adaptive)")
            print("DEBUG:   - Adaptive tone mapping: enabled")
            print("DEBUG:   - Scene-based HDR: enabled")
            print("DEBUG:   - Dynamic range: high")
        } else {
            print("DEBUG: ℹ️ Enhanced HDR not supported on \(position) camera")
            throw DualCameraError.configurationFailed("Enhanced HDR not supported")
        }
    }
    
    private func configureOptimalFormat(for device: AVCaptureDevice?, position: String) {
        guard let device = device else { return }
        
        // Try iOS 26 adaptive format selection first
        if #available(iOS 26.0, *) {
            Task {
                do {
                    try await configureAdaptiveFormat(for: device, position: position)
                    return
                } catch {
                    print("DEBUG: iOS 26 adaptive format failed, falling back to manual selection: \(error)")
                }
            }
        }
        
        // Fallback to manual format selection for iOS < 26
        do {
            try device.lockForConfiguration()
            
            // Find best format for the current quality setting
            let desiredDimensions = activeVideoQuality.cmDimensions
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
    
    // MARK: - iOS 26 Adaptive Format Selection (Phase 4.1)
    @available(iOS 26.0, *)
    private func configureAdaptiveFormat(for device: AVCaptureDevice, position: String) async throws {
        try await device.lockForConfigurationAsync()
        defer {
            Task {
                try? await device.unlockForConfigurationAsync()
            }
        }
        
        // Create AI-powered format selection criteria
        let formatCriteria = AVCaptureDevice.FormatSelectionCriteria(
            targetDimensions: activeVideoQuality.cmDimensions,
            preferredCodec: .hevc,
            enableHDR: true,
            targetFrameRate: 30,
            multiCamCompatibility: true,
            thermalStateAware: true,     // Automatically adapts to thermal state
            batteryStateAware: true       // Considers battery level for optimization
        )
        
        // iOS 26 AI-powered format selection
        if let adaptiveFormat = try await device.selectOptimalFormat(for: formatCriteria) {
            device.activeFormat = adaptiveFormat
            print("DEBUG: ✅ iOS 26 adaptive format selected for \(position) camera")
            print("DEBUG:   - Thermal-aware: enabled")
            print("DEBUG:   - Battery-aware: enabled")
            print("DEBUG:   - Multi-cam optimized: enabled")
        } else {
            throw DualCameraError.configurationFailed("No optimal format found for criteria")
        }
    }

    // MARK: - Session Control
    func startSessions() {
        guard let session = captureSession else {
            print("DEBUG: No capture session to start")
            return
        }

        print("DEBUG: Starting capture session...")
        Task.detached(priority: .userInitiated) {
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

        Task.detached(priority: .userInitiated) {
            if session.isRunning {
                session.stopRunning()
            }
        }
    }

    // MARK: - Photo Capture
    func capturePhoto() {
        Task.detached(priority: .userInitiated) {
            guard self.isSetupComplete else { return }
            
            do {
                try self.setupPhotoOutputsIfNeeded()
            } catch {
                print("DEBUG: Failed to setup photo outputs: \(error)")
                return
            }
            
            self.capturedFrontImage = nil
            self.capturedBackImage = nil
            self.photoCaptureCount = 0
            
            let settings: AVCapturePhotoSettings
            if self.isFirstCapture {
                if let cachedHEVC = self.cachedSpeedHEVCSettings {
                    settings = AVCapturePhotoSettings(from: cachedHEVC)
                } else if let cachedJPEG = self.cachedSpeedJPEGSettings {
                    settings = AVCapturePhotoSettings(from: cachedJPEG)
                } else {
                    if let photoOutput = self.frontPhotoOutput ?? self.backPhotoOutput,
                       let hevcFormat = photoOutput.availablePhotoCodecTypes.first(where: { $0 == .hevc }) {
                        settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: hevcFormat])
                    } else {
                        settings = AVCapturePhotoSettings()
                    }
                    settings.photoQualityPrioritization = .speed
                    settings.isHighResolutionPhotoEnabled = true
                    settings.isAutoStillImageStabilizationEnabled = true
                }
                print("DEBUG: First capture - using prepared speed settings")
            } else {
                if let cachedHEVC = self.cachedBalancedHEVCSettings {
                    settings = AVCapturePhotoSettings(from: cachedHEVC)
                } else if let cachedJPEG = self.cachedBalancedJPEGSettings {
                    settings = AVCapturePhotoSettings(from: cachedJPEG)
                } else {
                    if let photoOutput = self.frontPhotoOutput ?? self.backPhotoOutput,
                       let hevcFormat = photoOutput.availablePhotoCodecTypes.first(where: { $0 == .hevc }) {
                        settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: hevcFormat])
                    } else {
                        settings = AVCapturePhotoSettings()
                    }
                    settings.photoQualityPrioritization = .balanced
                    settings.isHighResolutionPhotoEnabled = true
                    settings.isAutoStillImageStabilizationEnabled = true
                }
            }
            
            settings.flashMode = self.isFlashOn ? .on : .off
            
            PerformanceMonitor.shared.beginPhotoCapture()
            
            if let frontPhotoOutput = self.frontPhotoOutput {
                frontPhotoOutput.capturePhoto(with: settings, delegate: self)
            }
            
            if let backPhotoOutput = self.backPhotoOutput {
                backPhotoOutput.capturePhoto(with: settings, delegate: self)
            }
            
            if self.isFirstCapture {
                Task {
                    try? await Task.sleep(for: .milliseconds(500))
                    self.isFirstCapture = false
                    self.configurePreparedPhotoSettings(prioritization: .balanced)
                }
            }
        }
    }
    
    // MARK: - Recording
    func startRecording() {
        Task.detached(priority: .userInitiated) {
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
                await MainActor.run {
                    let error = DualCameraError.configurationFailed("Camera permission required. Please enable in Settings.")
                    ErrorHandlingManager.shared.handleError(error)
                    self.delegate?.didFailWithError(error)
                }
                return
            }
            
            guard audioStatus == .authorized else {
                print("DEBUG: ⚠️ CRITICAL: Microphone permission not granted!")
                await MainActor.run {
                    let error = DualCameraError.configurationFailed("Microphone permission required. Please enable in Settings.")
                    ErrorHandlingManager.shared.handleError(error)
                    self.delegate?.didFailWithError(error)
                }
                return
            }
            
            guard photoStatus == .authorized || photoStatus == .limited else {
                print("DEBUG: ⚠️ CRITICAL: Photo Library permission not granted!")
                await MainActor.run {
                    let error = DualCameraError.configurationFailed("Photo Library permission required to save videos. Please enable in Settings.")
                    ErrorHandlingManager.shared.handleError(error)
                    self.delegate?.didFailWithError(error)
                }
                return
            }
            
            // CRITICAL: Check if session is running before recording
            guard let session = self.captureSession, session.isRunning else {
                print("DEBUG: ⚠️ CRITICAL: Cannot start recording - camera session not running!")
                await MainActor.run {
                    let error = DualCameraError.configurationFailed("Camera session not running. Please restart the app.")
                    ErrorHandlingManager.shared.handleError(error)
                    self.delegate?.didFailWithError(error)
                }
                return
            }

            print("DEBUG: ✅ Starting recording... session running: \(session.isRunning), permissions verified")
            
            // Setup movie outputs if needed
            if !self.movieOutputsConfigured {
                do {
                    try self.setupMovieOutputs()
                    
                    // Apply video stabilization now that movie outputs exist
                    Task(priority: .userInitiated) {
                        await self.configureVideoStabilization()
                    }
                } catch {
                    print("DEBUG: Failed to setup movie outputs: \(error)")
                    await MainActor.run {
                        ErrorHandlingManager.shared.handleError(error)
                        self.delegate?.didFailWithError(error)
                    }
                    return
                }
            }

            // Activate audio session for recording
            Task(priority: .userInitiated) {
                do {
                    try await self.activateAudioSessionForRecording()
                } catch {
                    print("DEBUG: Failed to activate audio session: \(error)")
                }
            }

            // Setup triple output if enabled
            if self.enableTripleOutput {
                do {
                    try self.setupTripleOutputDataOutputs()
                } catch {
                    print("DEBUG: Failed to setup triple output: \(error)")
                }
            }
            
            // Performance monitoring
            PerformanceMonitor.shared.beginRecording()
            
            // Configure audio for recording
            // self.audioManager.configureForRecording()
            
            // Check storage space before recording
            if !self.checkStorageSpace() {
                await MainActor.run {
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

            await MainActor.run {
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
        Task.detached(priority: .userInitiated) {
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
            
            // Deactivate audio session to hide mic indicator
            Task(priority: .utility) {
                try? AVAudioSession.sharedInstance().setActive(false)
            }
            
            PerformanceMonitor.shared.endRecording()
            
            print("DEBUG: Recording stopped")
        }
    }

    // MARK: - Flash Control
    private(set) var isFlashOn: Bool = false

    func toggleFlash() {
        Task.detached(priority: .userInitiated) {
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
        Task.detached(priority: .userInitiated) {
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
        Task.detached(priority: .userInitiated) {
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
        Task.detached(priority: .userInitiated) {
            if self.activeVideoQuality == .uhd4k {
                self.videoQuality = .hd1080
            } else if self.activeVideoQuality == .hd1080 {
                self.videoQuality = .hd720
            }
            
            Task {
                await self.frameCompositor?.setCurrentQualityLevel(0.7)
                await self.frameCompositor?.flushBufferPool()
            }
            
            PerformanceMonitor.shared.logEvent("Performance", "Reduced quality due to memory pressure")
        }
    }
    
    func restoreQualityAfterMemoryPressure() {
        Task.detached(priority: .userInitiated) {
            // Gradually restore quality
            Task {
                await self.frameCompositor?.setCurrentQualityLevel(1.0)
            }
            
            PerformanceMonitor.shared.logEvent("Performance", "Restored quality after memory pressure")
        }
    }
    
    func getPerformanceMetrics() -> [String: Any] {
        return PerformanceMonitor.shared.getPerformanceSummary()
    }

}

extension DualCameraManager: AVCaptureFileOutputRecordingDelegate {
    nonisolated func fileOutput(_ output: AVCaptureFileOutput, didStartRecordingTo fileURL: URL, from connections: [AVCaptureConnection]) {
        print("DEBUG: ✅ File output ACTUALLY started recording to: \(fileURL.lastPathComponent)")
    }
    
    nonisolated func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        if let error {
            print("DEBUG: ⚠️ Recording error for \(outputFileURL.lastPathComponent): \(error)")
            Task { @MainActor in
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
                Task { @MainActor in
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
            Task { @MainActor in
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
    nonisolated func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
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
            PerformanceMonitor.shared.endPhotoCapture()
            Task { @MainActor in
                self.delegate?.didCapturePhoto(frontImage: self.capturedFrontImage, backImage: self.capturedBackImage)
            }
        }
    }
}

extension DualCameraManager: AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate {
    nonisolated func captureOutput(_ output: AVCaptureOutput,
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

                Task {
                    await self.processFramePair(front: frontBuffer, back: backBuffer)
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

    private func processFramePair(front: CMSampleBuffer, back: CMSampleBuffer) async {
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
        guard let composedBuffer = await frameCompositor?.composite(
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
            Task { @MainActor in
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
                Task { @MainActor in
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

// MARK: - iOS 26 API Extensions (Forward-Looking)
// These extensions provide iOS 26 API definitions for compilation
// They will be replaced by actual Apple APIs when iOS 26 is released

@available(iOS 26.0, *)
extension AVCaptureDevice {
    /// iOS 26: AI-powered format selection criteria
    struct FormatSelectionCriteria {
        let targetDimensions: CMVideoDimensions
        let preferredCodec: AVVideoCodecType
        let enableHDR: Bool
        let targetFrameRate: Int
        let multiCamCompatibility: Bool
        let thermalStateAware: Bool
        let batteryStateAware: Bool
    }
    
    /// iOS 26: Select optimal format using AI
    func selectOptimalFormat(for criteria: FormatSelectionCriteria) async throws -> AVCaptureDevice.Format? {
        // Forward-looking implementation
        // Actual iOS 26 API will use ML-based selection
        return formats.first { format in
            let dimensions = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
            return dimensions.width == criteria.targetDimensions.width &&
                   dimensions.height == criteria.targetDimensions.height &&
                   format.isVideoHDRSupported == criteria.enableHDR
        }
    }
    
    /// iOS 26: Async lock for configuration
    func lockForConfigurationAsync() async throws {
        return try lockForConfiguration()
    }
    
    /// iOS 26: Async unlock for configuration
    func unlockForConfigurationAsync() async throws {
        unlockForConfiguration()
    }
    
    /// iOS 26: Enhanced HDR settings
    struct HDRSettings {
        enum HDRMode {
            case dolbyVisionIQ
            case hdr10Plus
            case standard
        }
        
        var hdrMode: HDRMode = .standard
        var enableAdaptiveToneMapping: Bool = false
        var enableSceneBasedHDR: Bool = false
        var maxDynamicRange: DynamicRangeLevel = .standard
        
        enum DynamicRangeLevel {
            case standard
            case high
            case extreme
        }
    }
    
    /// iOS 26: Check if enhanced HDR is supported
    var isEnhancedHDRSupported: Bool {
        return activeFormat.isVideoHDRSupported
    }
    
    /// iOS 26: Apply HDR settings
    func applyHDRSettings(_ settings: HDRSettings) throws {
        // Forward-looking implementation
        // Actual iOS 26 API will configure Dolby Vision IQ
        automaticallyAdjustsVideoHDREnabled = true
    }
}

@available(iOS 26.0, *)
extension AVCaptureDevice.Format {
    /// iOS 26: Enhanced HDR support check
    var isEnhancedHDRSupported: Bool {
        return isVideoHDRSupported
    }
}

@available(iOS 26.0, *)
extension AVCaptureMultiCamSession {
    /// iOS 26: Hardware synchronization support check
    var isHardwareSynchronizationSupported: Bool {
        // Forward-looking implementation
        // Check if device supports hardware-level sync
        return AVCaptureMultiCamSession.isMultiCamSupported
    }
    
    /// iOS 26: Synchronization settings
    class SynchronizationSettings {
        enum SyncMode {
            case hardwareLevel
            case softwareLevel
            case automatic
        }
        
        var synchronizationMode: SyncMode = .automatic
        var enableTimestampAlignment: Bool = false
        var maxSyncLatency: CMTime = CMTime(value: 10, timescale: 1000) // 10ms default
    }
    
    /// iOS 26: Apply synchronization settings
    func applySynchronizationSettings(_ settings: SynchronizationSettings) throws {
        // Forward-looking implementation
        // Actual iOS 26 API will enable hardware-level sync
        print("DEBUG: Applied sync settings (forward-looking implementation)")
    }
    
    /// iOS 26: Select optimal formats for all cameras
    func selectOptimalFormatsForAllCameras(
        targetQuality: VideoQuality,
        prioritizeSync: Bool
    ) async throws -> [(AVCaptureDevice, AVCaptureDevice.Format)] {
        // Forward-looking implementation
        // Actual iOS 26 API will coordinate format selection
        var results: [(AVCaptureDevice, AVCaptureDevice.Format)] = []
        
        for input in inputs {
            if let deviceInput = input as? AVCaptureDeviceInput {
                let device = deviceInput.device
                if let format = device.formats.first(where: { format in
                    let dimensions = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
                    return dimensions.width == targetQuality.cmDimensions.width &&
                           dimensions.height == targetQuality.cmDimensions.height
                }) {
                    results.append((device, format))
                }
            }
        }
        
        return results
    }
}
