// Dual Camera App
import Foundation
import AVFoundation
import UIKit
import os.signpost

@available(iOS 15.0, *)
@MainActor
final class CameraAppController: NSObject {
    private let log = OSLog(subsystem: "com.dualcamera.app", category: "CameraAppController")
    private var permissionSignpostID: OSSignpostID?
    private var cameraSetupSignpostID: OSSignpostID?
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
    var onSetupProgress: ((String, Float) -> Void)?

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
         recordingRepository: RecordingRepository = .shared) {
        self.permissionCoordinator = permissionCoordinator
        self.recordingRepository = recordingRepository
        self.cameraManager = DualCameraManager()
        super.init()
        self.cameraManager.delegate = self
    }

    // MARK: - Lifecycle Controls

    func start() {
        let signpostID = OSSignpostID(log: log)
        permissionSignpostID = signpostID
        os_signpost(.begin, log: log, name: "Permission Check", signpostID: signpostID)

        #if targetEnvironment(simulator)
        hasRequestedPermissions = true
        StartupOptimizer.shared.endPhase(.permissionCheck)
        os_signpost(.end, log: log, name: "Permission Check", signpostID: signpostID)
        proceedWithCameraSetup()
        return
        #endif

        let (alreadyGranted, currentlyDenied) = permissionCoordinator.checkCurrentStatus()

        if alreadyGranted {
            hasRequestedPermissions = true
            StartupOptimizer.shared.endPhase(.permissionCheck)
            os_signpost(.end, log: log, name: "Permission Check", signpostID: signpostID)
            proceedWithCameraSetup()
            return
        }

        requestPermissionsWithFallback()
    }

    private func proceedWithCameraSetup() {
        StartupOptimizer.shared.beginPhase(.cameraDiscovery)
        
        let signpostID = OSSignpostID(log: log)
        cameraSetupSignpostID = signpostID
        os_signpost(.begin, log: log, name: "Camera Setup", signpostID: signpostID)
        
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
        PerformanceMonitor.shared.beginCameraSetup()
        Task(priority: .userInitiated) {
            self.cameraManager.setupCameras()
        }
        #endif
    }

    private func requestPermissionsWithFallback() {

        guard !hasRequestedPermissions else {
            print("⚠️ CameraAppController: Permissions already requested this session")
            return
        }

        hasRequestedPermissions = true
        updateState { state in
            state.phase = .requestingPermissions
            state.statusMessage = "Requesting permissions..."
        }

        // Use a shorter timeout and faster fallback
        Task { @MainActor in
            do {
                // Reduced timeout to 10 seconds to prevent long hangs
                let permissionResult = try await withTimeout(seconds: 10) {
                    if #available(iOS 15.0, *) {
                        let modernCoordinator = ModernPermissionCoordinator()
                        return await modernCoordinator.requestAllPermissionsConcurrently()
                    } else {
                        return await self.permissionCoordinator.requestAllPermissions()
                    }
                }

                let (granted, denied) = permissionResult

                if granted {
                    StartupOptimizer.shared.endPhase(.permissionCheck)
                    if let signpostID = self.permissionSignpostID {
                        os_signpost(.end, log: self.log, name: "Permission Check", signpostID: signpostID)
                    }
                    self.proceedWithCameraSetup()
                } else {
                    StartupOptimizer.shared.endPhase(.permissionCheck)
                    if let signpostID = self.permissionSignpostID {
                        os_signpost(.end, log: self.log, name: "Permission Check", signpostID: signpostID)
                    }
                    self.updateState { state in
                        state.phase = .permissionsDenied(denied)
                        state.statusMessage = "Permissions required - tap to open Settings"
                    }
                }
            } catch {
                StartupOptimizer.shared.endPhase(.permissionCheck)
                if let signpostID = self.permissionSignpostID {
                    os_signpost(.end, log: self.log, name: "Permission Check", signpostID: signpostID)
                }
                self.handlePermissionTimeout()
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
        onStateChange?(state)
    }
}

// MARK: - DualCameraManagerDelegate

@MainActor
extension CameraAppController: DualCameraManagerDelegate {
    func didStartRecording() {
        updateState { state in
            state.isRecording = true
            state.statusMessage = "Recording..."
        }
        onRecordingStateChange?(true)
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
                state.statusMessage = "Recording stopped"
            }
            onRecordingStateChange?(false)
        }
    }

    func didCapturePhoto(frontImage: UIImage?, backImage: UIImage?) {
        onPhotoCaptured?(frontImage, backImage)
    }

    func didFailWithError(_ error: Error) {
        updateState { state in
            state.phase = .error(message: error.localizedDescription)
            state.statusMessage = "Error"
        }
        onError?(error)
    }

    func didUpdateVideoQuality(to quality: VideoQuality) {
        onVideoQualityChange?(quality)
    }

    func didFinishCameraSetup() {
        StartupOptimizer.shared.beginPhase(.previewSetup)
        
        if let signpostID = cameraSetupSignpostID {
            os_signpost(.end, log: log, name: "Camera Setup", signpostID: signpostID)
        }
        
        updateState { state in
            state.phase = .ready
            state.statusMessage = "Ready to record"
        }
        onPreviewLayersReady?(cameraManager.frontPreviewLayer, cameraManager.backPreviewLayer)
    }

    func didUpdateSetupProgress(_ message: String, progress: Float) {
        os_signpost(.event, log: log, name: "Setup Progress", "%{public}s - %.0f%%", message, progress * 100)
        
        updateState { state in
            state.statusMessage = message
        }
        onSetupProgress?(message, progress)
        print("📱 CameraAppController: Setup progress: \(message) (\(Int(progress * 100))%)")
    }
}

// MARK: - Emergency Fallback & Timeout Handling

extension CameraAppController {
    private func handlePermissionTimeout() {
        print("🚨 CameraAppController: Handling permission timeout - using emergency fallback")

        updateState { state in
            state.phase = .settingUp
            state.statusMessage = "Starting with limited permissions..."
        }

        // Try to proceed anyway - some permissions might have been granted
        #if targetEnvironment(simulator)
        self.updateState { state in
            state.phase = .ready
            state.statusMessage = "Simulator Mode - Demo Ready"
        }
        self.onSimulatorModeRequested?()
        #else
        // Attempt camera setup with whatever permissions we have
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.cameraManager.setupCameras()
        }
        #endif
    }

    // Timeout utility function
    private func withTimeout<T>(seconds: TimeInterval, operation: @escaping () async throws -> T) async throws -> T {
        return try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                return try await operation()
            }

            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw TimeoutError()
            }

            guard let result = try await group.next() else {
                throw TimeoutError()
            }

            group.cancelAll()
            return result
        }
    }
}

struct TimeoutError: Error {
    let localizedDescription = "Operation timed out"
}
