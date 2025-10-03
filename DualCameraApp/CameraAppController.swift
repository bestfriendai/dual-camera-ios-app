// Dual Camera App
import Foundation
import AVFoundation
import UIKit

/// High-level controller that coordinates permissions and the dual camera pipeline while
/// publishing state changes for the UI layers.
final class CameraAppController: NSObject {
    struct State {
        enum Phase {
            case idle
            case requestingPermissions
            case permissionsDenied([PermissionType])
            case settingUp
            case ready
            case error(message: String)
        }

        var phase: Phase
        var isRecording: Bool
        var statusMessage: String?
        var recordingDuration: TimeInterval?
    }

    // MARK: - Public callbacks

    var onStateChange: ((State) -> Void)?
    var onPreviewLayersReady: ((AVCaptureVideoPreviewLayer?, AVCaptureVideoPreviewLayer?) -> Void)?
    var onRecordingStateChange: ((Bool) -> Void)?
    var onPhotoCaptured: ((UIImage?, UIImage?) -> Void)?
    var onError: ((Error) -> Void)?
    var onVideoQualityChange: ((VideoQuality) -> Void)?
    var onSimulatorModeRequested: (() -> Void)?
    var onRecordingSaved: ((RecordingRepository.Recording) -> Void)?

    // MARK: - Dependencies

    private let permissionCoordinator: PermissionCoordinator
    private let recordingRepository: RecordingRepository
    let cameraManager: DualCameraManager

    // MARK: - State

    private(set) var state: State = State(phase: .idle, isRecording: false, statusMessage: nil) {
        didSet { dispatchStateChange() }
    }

    private var hasRequestedPermissions = false

    // MARK: - Initialization

    init(permissionCoordinator: PermissionCoordinator = PermissionCoordinator(),
         recordingRepository: RecordingRepository = .shared,
         cameraManager: DualCameraManager = DualCameraManager()) {
        self.permissionCoordinator = permissionCoordinator
        self.recordingRepository = recordingRepository
        self.cameraManager = cameraManager
        super.init()
        self.cameraManager.delegate = self
    }

    // MARK: - Lifecycle Controls

    func start() {
        // Check if permissions are already granted before requesting
        let (alreadyGranted, currentlyDenied) = permissionCoordinator.checkCurrentStatus()

        if alreadyGranted {
            // Permissions already granted - skip to camera setup
            print("✅ CameraAppController: Permissions already granted, skipping request")
            hasRequestedPermissions = true
            updateState { state in
                state.phase = .settingUp
                state.statusMessage = "Loading camera..."
            }
            self.cameraManager.enableTripleOutput = true
            self.cameraManager.tripleOutputMode = .allFiles

            #if targetEnvironment(simulator)
            self.updateState { state in
                state.phase = .ready
                state.statusMessage = "Simulator Mode - Demo Ready"
            }
            self.onSimulatorModeRequested?()
            #else
            self.cameraManager.setupCameras()
            #endif
            return
        }

        // Only request if not already requested this session
        guard !hasRequestedPermissions else {
            print("⚠️ CameraAppController: Permissions already requested this session")
            return
        }

        hasRequestedPermissions = true
        updateState { state in
            state.phase = .requestingPermissions
            state.statusMessage = "Requesting permissions..."
        }

        Task { @MainActor in
            let (granted, denied) = await permissionCoordinator.requestAllPermissions()

            if granted {
                self.updateState { state in
                    state.phase = .settingUp
                    state.statusMessage = "Loading camera..."
                }
                self.cameraManager.enableTripleOutput = true
                self.cameraManager.tripleOutputMode = .allFiles

                #if targetEnvironment(simulator)
                self.updateState { state in
                    state.phase = .ready
                    state.statusMessage = "Simulator Mode - Demo Ready"
                }
                self.onSimulatorModeRequested?()
                #else
                self.cameraManager.setupCameras()
                #endif
            } else {
                // DON'T reset hasRequestedPermissions - keep it true to prevent repeated requests
                print("⚠️ CameraAppController: Permissions denied: \(denied)")
                self.updateState { state in
                    state.phase = .permissionsDenied(denied)
                    state.statusMessage = "Permissions required - tap to open Settings"
                }
            }
        }
    }

    func retryPermissions() {
        // Check current status first
        let (alreadyGranted, _) = permissionCoordinator.checkCurrentStatus()

        if alreadyGranted {
            // Permissions now granted - proceed to setup
            print("✅ CameraAppController: Permissions now granted")
            updateState { state in
                state.phase = .settingUp
                state.statusMessage = "Loading camera..."
            }
            self.cameraManager.enableTripleOutput = true
            self.cameraManager.tripleOutputMode = .allFiles

            #if targetEnvironment(simulator)
            self.updateState { state in
                state.phase = .ready
                state.statusMessage = "Simulator Mode - Demo Ready"
            }
            self.onSimulatorModeRequested?()
            #else
            self.cameraManager.setupCameras()
            #endif
        } else {
            // Still denied - show settings
            print("⚠️ CameraAppController: Permissions still denied, need to open Settings")
        }
    }
    
    func presentPermissionSettings(from viewController: UIViewController) {
        let (_, denied) = permissionCoordinator.checkCurrentStatus()
        permissionCoordinator.presentDeniedAlert(deniedPermissions: denied, from: viewController)
    }

    func startSessions() {
        cameraManager.startSessions()
    }

    func stopSessions() {
        cameraManager.stopSessions()
    }

    func startRecording() {
        cameraManager.startRecording()
    }

    func stopRecording() {
        cameraManager.stopRecording()
    }

    func toggleFlash() {
        cameraManager.toggleFlash()
    }

    var isFlashOn: Bool {
        cameraManager.isFlashOn
    }

    func capturePhoto() {
        cameraManager.capturePhoto()
    }

    func setVideoQuality(_ quality: VideoQuality) {
        cameraManager.videoQuality = quality
    }

    func reduceQualityForMemoryPressure() {
        cameraManager.reduceQualityForMemoryPressure()
    }

    // MARK: - Helpers

    private func updateState(_ transform: (inout State) -> Void) {
        var newState = state
        transform(&newState)
        state = newState
    }

    private func dispatchStateChange() {
        let currentState = state
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.onStateChange?(currentState)
        }
    }
}

// MARK: - DualCameraManagerDelegate

extension CameraAppController: DualCameraManagerDelegate {
    func didStartRecording() {
        updateState { state in
            state.isRecording = true
            state.statusMessage = "Recording..."
        }
        DispatchQueue.main.async { [weak self] in
            self?.onRecordingStateChange?(true)
        }
    }

    func didStopRecording() {
        let urls = cameraManager.getRecordingURLs()
        
        if let frontURL = urls.front, let backURL = urls.back {
            recordingRepository.add(frontURL: frontURL, backURL: backURL) { [weak self] result in
                guard let self = self else { return }
                
                switch result {
                case .success(let recording):
                    self.updateState { state in
                        state.isRecording = false
                        state.statusMessage = "Recording saved"
                    }
                    self.onRecordingSaved?(recording)
                case .failure(let error):
                    self.updateState { state in
                        state.isRecording = false
                        state.statusMessage = "Error saving recording"
                    }
                    self.onError?(error)
                }
                
                self.onRecordingStateChange?(false)
            }
        } else {
            updateState { state in
                state.isRecording = false
                state.statusMessage = "Recording saved"
            }
            DispatchQueue.main.async { [weak self] in
                self?.onRecordingStateChange?(false)
            }
        }
    }

    func didCapturePhoto(frontImage: UIImage?, backImage: UIImage?) {
        DispatchQueue.main.async { [weak self] in
            self?.onPhotoCaptured?(frontImage, backImage)
        }
    }

    func didFailWithError(_ error: Error) {
        updateState { state in
            state.phase = .error(message: error.localizedDescription)
            state.statusMessage = "Error"
        }
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.onError?(error)
        }
    }

    func didUpdateVideoQuality(to quality: VideoQuality) {
        DispatchQueue.main.async { [weak self] in
            self?.onVideoQualityChange?(quality)
        }
    }

    func didFinishCameraSetup() {
        updateState { state in
            state.phase = .ready
            state.statusMessage = "Ready to record"
        }
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.onPreviewLayersReady?(self.cameraManager.frontPreviewLayer, self.cameraManager.backPreviewLayer)
        }
    }
}
