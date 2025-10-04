// Dual Camera App - Swift 6.2 Actor-Based Camera Manager
import AVFoundation
import UIKit
import Photos

// MARK: - Camera Event Stream (Replaces Delegate Pattern)

enum CameraEvent: Sendable {
    case startedRecording
    case stoppedRecording
    case error(SendableError)
    case qualityUpdated(VideoQuality)
    case photoCaptured(front: Data?, back: Data?)
    case setupFinished
    case setupProgress(String, Float)
}

struct SendableError: Error, Sendable {
    let message: String
    let underlyingError: String?
    
    init(_ error: Error) {
        self.message = error.localizedDescription
        self.underlyingError = (error as NSError).debugDescription
    }
    
    init(message: String) {
        self.message = message
        self.underlyingError = nil
    }
}

extension VideoQuality: Sendable {}

@available(iOS 15.0, *)
actor DualCameraManager {
    
    // MARK: - Event Stream
    
    let events: AsyncStream<CameraEvent>
    private let eventContinuation: AsyncStream<CameraEvent>.Continuation
    
    // MARK: - Actor-Isolated Properties
    
    private(set) var videoQuality: VideoQuality = .hd1080
    private(set) var activeVideoQuality: VideoQuality = .hd1080
    private(set) var state: CameraState = .notConfigured
    private(set) var isRecording = false
    private var isSetupComplete = false
    
    // Camera devices and inputs - actor-isolated
    private var frontCamera: AVCaptureDevice?
    private var backCamera: AVCaptureDevice?
    private var frontCameraInput: AVCaptureDeviceInput?
    private var backCameraInput: AVCaptureDeviceInput?
    private var audioDevice: AVCaptureDevice?
    private var audioInput: AVCaptureDeviceInput?
    
    // Outputs - actor-isolated
    private var frontMovieOutput: AVCaptureMovieFileOutput?
    private var backMovieOutput: AVCaptureMovieFileOutput?
    private var frontPhotoOutput: AVCapturePhotoOutput?
    private var backPhotoOutput: AVCapturePhotoOutput?
    private var frontDataOutput: AVCaptureVideoDataOutput?
    private var backDataOutput: AVCaptureVideoDataOutput?
    private var audioDataOutput: AVCaptureAudioDataOutput?
    
    // Session - actor-isolated
    private var captureSession: AVCaptureSession?
    
    // Preview layers - these need to be accessed from MainActor
    nonisolated var frontPreviewLayer: AVCaptureVideoPreviewLayer?
    nonisolated var backPreviewLayer: AVCaptureVideoPreviewLayer?
    
    // Recording state - actor-isolated
    private var frontVideoURL: URL?
    private var backVideoURL: URL?
    private var combinedVideoURL: URL?
    private var recordingStartTime: CMTime?
    private var isWriting = false
    
    // Photo capture - actor-isolated
    private var capturedFrontImage: UIImage?
    private var capturedBackImage: UIImage?
    private var photoCaptureCount = 0
    private var isFirstCapture: Bool = true
    
    // Configuration flags - actor-isolated
    private var photoOutputsConfigured = false
    private var movieOutputsConfigured = false
    private var isAudioSessionActive = false
    
    // Triple output - actor-isolated
    private var enableTripleOutput: Bool = true
    private var tripleOutputMode: TripleOutputMode = .allFiles
    private var recordingLayout: RecordingLayout = .pictureInPicture
    
    // Asset writer - actor-isolated
    private var assetWriter: AVAssetWriter?
    private var videoWriterInput: AVAssetWriterInput?
    private var audioWriterInput: AVAssetWriterInput?
    private var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?
    
    // Coordinators - actor-isolated
    private var frameSyncCoordinator: FrameSyncCoordinator?
    private var frameCompositor: FrameCompositor?
    
    // Flash - actor-isolated
    private(set) var isFlashOn: Bool = false
    
    // Setup retry - actor-isolated
    private var setupRetryCount = 0
    private let maxSetupRetries = 3
    
    // Thermal observer
    private var thermalObserver: NSObjectProtocol?
    
    // Audio manager
    private let audioManager = AudioManager()
    
    // MARK: - State
    
    enum CameraState: Sendable {
        case notConfigured
        case configuring
        case configured
        case failed(SendableError)
        case recording
        case paused
    }
    
    enum TripleOutputMode: Sendable {
        case allFiles
        case combinedOnly
        case frontBackOnly
    }
    
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
    
    // MARK: - Initialization
    
    init() {
        // Create event stream
        var continuation: AsyncStream<CameraEvent>.Continuation!
        let stream = AsyncStream<CameraEvent> { cont in
            continuation = cont
        }
        self.events = stream
        self.eventContinuation = continuation
        
        // Initialize frame sync coordinator
        self.frameSyncCoordinator = FrameSyncCoordinator()
    }
    
    deinit {
        eventContinuation.finish()
        if let observer = thermalObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    // MARK: - Public API
    
    func setVideoQuality(_ quality: VideoQuality) async {
        videoQuality = quality
        activeVideoQuality = quality
        emitEvent(.qualityUpdated(quality))
    }
    
    func getVideoQuality() async -> VideoQuality {
        return videoQuality
    }
    
    func getState() async -> CameraState {
        return state
    }
    
    func getIsRecording() async -> Bool {
        return isRecording
    }
    
    func getRecordingURLs() async -> (front: URL?, back: URL?, combined: URL?) {
        return (frontVideoURL, backVideoURL, combinedVideoURL)
    }
    
    func getIsFlashOn() async -> Bool {
        return isFlashOn
    }
    
    // MARK: - Setup
    
    func setupCameras() async {
        guard !isSetupComplete else { return }
        
        state = .configuring
        print("DEBUG: Setting up cameras (attempt \(setupRetryCount + 1)/\(maxSetupRetries))...")
        
        emitEvent(.setupProgress("Discovering cameras...", 0.1))
        
        // Discover devices concurrently
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
                switch type {
                case "front": self.frontCamera = device
                case "back": self.backCamera = device
                case "audio": self.audioDevice = device
                default: break
                }
            }
        }
        
        print("DEBUG: Front camera: \(String(describing: frontCamera?.localizedName))")
        print("DEBUG: Back camera: \(String(describing: backCamera?.localizedName))")
        print("DEBUG: Audio device: \(String(describing: audioDevice?.localizedName))")
        
        emitEvent(.setupProgress("Cameras discovered", 0.3))
        
        guard frontCamera != nil, backCamera != nil else {
            let error = SendableError(message: "Required camera devices could not be initialized")
            await handleSetupError(error)
            return
        }
        
        emitEvent(.setupProgress("Configuring camera session...", 0.5))
        
        do {
            try await configureSession()
            
            emitEvent(.setupProgress("Starting camera session...", 0.8))
            
            isSetupComplete = true
            setupRetryCount = 0
            state = .configured
            
            // Start session
            if let session = captureSession, !session.isRunning {
                print("DEBUG: Starting capture session...")
                session.startRunning()
                print("DEBUG: ✅ Capture session started - isRunning: \(session.isRunning)")
            }
            
            // Setup photo outputs asynchronously
            Task {
                try? await Task.sleep(for: .milliseconds(100))
                do {
                    try await setupPhotoOutputsIfNeeded()
                    print("DEBUG: ✅ Photo outputs prepared for fast capture")
                } catch {
                    print("DEBUG: ⚠️ Failed to prepare photo outputs: \(error)")
                }
            }
            
            emitEvent(.qualityUpdated(videoQuality))
            emitEvent(.setupProgress("Camera ready!", 1.0))
            emitEvent(.setupFinished)
            
            // Configure professional features asynchronously
            Task(priority: .utility) {
                await configureCameraProfessionalFeaturesAsync()
            }
            
        } catch {
            await handleSetupError(SendableError(error))
        }
    }
    
    private func handleSetupError(_ error: SendableError) async {
        state = .failed(error)
        captureSession = nil
        
        if setupRetryCount < maxSetupRetries {
            setupRetryCount += 1
            print("DEBUG: Setup failed, retrying... (attempt \(setupRetryCount))")
            try? await Task.sleep(for: .seconds(1))
            isSetupComplete = false
            await setupCameras()
        } else {
            emitEvent(.error(error))
        }
    }
    
    // MARK: - Private Helper
    
    private func emitEvent(_ event: CameraEvent) {
        eventContinuation.yield(event)
    }
    
    private func configureSession() async throws {
        // Implementation continues from original...
        guard let frontCamera, let backCamera else {
            throw DualCameraError.missingDevices
        }
        
        let isSupported = AVCaptureMultiCamSession.isMultiCamSupported
        guard isSupported else {
            throw DualCameraError.multiCamNotSupported
        }
        
        let session = AVCaptureMultiCamSession()
        captureSession = session
        try configureMinimalSession(session: session, frontCamera: frontCamera, backCamera: backCamera)
    }
    
    private func configureMinimalSession(session: AVCaptureMultiCamSession, frontCamera: AVCaptureDevice, backCamera: AVCaptureDevice) throws {
        // Implementation from original - session configuration
        // This would continue with the full implementation...
    }
    
    private func setupPhotoOutputsIfNeeded() async throws {
        // Implementation from original...
    }
    
    private func configureCameraProfessionalFeaturesAsync() async {
        // Implementation from original...
    }
}
