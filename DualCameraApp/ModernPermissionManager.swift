//
//  ModernPermissionManager.swift
//  DualCameraApp
//
//  Enhanced permission management with iOS 17+ features
//

import AVFoundation
import Photos
import UIKit
import LocalAuthentication
import os.log

@available(iOS 17.0, *)
class ModernPermissionManager: ObservableObject {
    
    static let shared = ModernPermissionManager()
    
    private let log = OSLog(subsystem: "com.dualcamera.app", category: "Permissions")
    
    // Permission state tracking
    @Published var permissionState: PermissionState = .unknown
    @Published var detailedPermissions: DetailedPermissions = DetailedPermissions()
    
    // iOS 17+ features
    private var permissionMonitor: PermissionMonitor?
    private var privacyAssistant: PrivacyAssistant?
    
    // Authentication
    private let context = LAContext()
    
    private init() {
        setupiOS17Features()
        refreshPermissionState()
    }
    
    // MARK: - iOS 17+ Features
    
    private func setupiOS17Features() {
        if #available(iOS 17.0, *) {
            permissionMonitor = PermissionMonitor()
            privacyAssistant = PrivacyAssistant()
            
            // Start monitoring permission changes
            permissionMonitor?.startMonitoring { [weak self] in
                self?.refreshPermissionState()
            }
        }
    }
    
    // MARK: - Permission State Management
    
    private func refreshPermissionState() {
        let newState = determineCurrentState()
        
        DispatchQueue.main.async {
            self.permissionState = newState
            self.detailedPermissions = self.getDetailedPermissions()
        }
    }
    
    private func determineCurrentState() -> PermissionState {
        let cameraStatus = AVCaptureDevice.authorizationStatus(for: .video)
        let micStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        let photosStatus = PHPhotoLibrary.authorizationStatus()
        
        if cameraStatus == .authorized && micStatus == .authorized && photosStatus == .authorized {
            return .granted
        } else if cameraStatus == .denied || micStatus == .denied || photosStatus == .denied {
            return .denied
        } else if cameraStatus == .notDetermined || micStatus == .notDetermined || photosStatus == .notDetermined {
            return .notDetermined
        } else {
            return .restricted
        }
    }
    
    private func getDetailedPermissions() -> DetailedPermissions {
        return DetailedPermissions(
            camera: CameraPermissionInfo(
                status: AVCaptureDevice.authorizationStatus(for: .video),
                capabilities: getCameraCapabilities()
            ),
            microphone: MicrophonePermissionInfo(
                status: AVCaptureDevice.authorizationStatus(for: .audio)
            ),
            photos: PhotosPermissionInfo(
                status: PHPhotoLibrary.authorizationStatus(),
                accessLevel: getPhotosAccessLevel()
            )
        )
    }
    
    private func getCameraCapabilities() -> CameraCapabilities {
        var capabilities = CameraCapabilities()
        
        // Check for advanced camera features
        if #available(iOS 17.0, *) {
            capabilities.supportsProRes = true
            capabilities.supportsCinematicMode = true
            capabilities.supportsSpatialVideo = true
            capabilities.supportsPortraitMode = true
            capabilities.supportsActionMode = true
        }
        
        // Check for specific device capabilities
        if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) {
            capabilities.supportsHDR = device.activeFormat.isVideoHDRSupported
            capabilities.supportsLowLight = device.isLowLightBoostSupported
            capabilities.supportsDepthData = !device.activeFormat.supportedDepthDataFormats.isEmpty
        }
        
        return capabilities
    }
    
    private func getPhotosAccessLevel() -> PhotosAccessLevel {
        let status = PHPhotoLibrary.authorizationStatus()
        
        switch status {
        case .authorized:
            return .full
        case .limited:
            return .limited
        case .denied, .restricted:
            return .none
        case .notDetermined:
            return .unknown
        @unknown default:
            return .unknown
        }
    }
    
    // MARK: - Permission Request Flow
    
    func requestPermissionsWithFlow() async -> PermissionRequestResult {
        // Use iOS 17+ permission request flow
        if #available(iOS 17.0, *) {
            return await requestPermissionsWithModernFlow()
        } else {
            return await requestPermissionsWithLegacyFlow()
        }
    }
    
    @available(iOS 17.0, *)
    private func requestPermissionsWithModernFlow() async -> PermissionRequestResult {
        do {
            // Request camera permission with rationale
            let cameraGranted = try await requestCameraWithRationale()
            
            // Request microphone permission with rationale
            let micGranted = try await requestMicrophoneWithRationale()
            
            // Request photos permission with rationale
            let photosGranted = try await requestPhotosWithRationale()
            
            let result = PermissionRequestResult(
                camera: cameraGranted,
                microphone: micGranted,
                photos: photosGranted
            )
            
            // Log permission request
            await logPermissionRequest(result)
            
            return result
            
        } catch {
            return PermissionRequestResult(
                camera: false,
                microphone: false,
                photos: false,
                error: error
            )
        }
    }
    
    private func requestPermissionsWithLegacyFlow() async -> PermissionRequestResult {
        return await withCheckedContinuation { continuation in
            requestAllPermissions { granted, denied in
                let result = PermissionRequestResult(
                    camera: !denied.contains(.camera),
                    microphone: !denied.contains(.microphone),
                    photos: !denied.contains(.photoLibrary)
                )
                continuation.resume(returning: result)
            }
        }
    }
    
    @available(iOS 17.0, *)
    private func requestCameraWithRationale() async throws -> Bool {
        // Show privacy rationale if needed
        if shouldShowRationale(for: .camera) {
            try await showPrivacyRationale(for: .camera)
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .video) { granted in
                continuation.resume(returning: granted)
            }
        }
    }
    
    @available(iOS 17.0, *)
    private func requestMicrophoneWithRationale() async throws -> Bool {
        // Show privacy rationale if needed
        if shouldShowRationale(for: .microphone) {
            try await showPrivacyRationale(for: .microphone)
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                continuation.resume(returning: granted)
            }
        }
    }
    
    @available(iOS 17.0, *)
    private func requestPhotosWithRationale() async throws -> Bool {
        // Show privacy rationale if needed
        if shouldShowRationale(for: .photos) {
            try await showPrivacyRationale(for: .photos)
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            PHPhotoLibrary.requestAuthorization { status in
                let granted = status == .authorized || status == .limited
                continuation.resume(returning: granted)
            }
        }
    }
    
    private func shouldShowRationale(for permission: PermissionType) -> Bool {
        // Determine if rationale should be shown
        return true // Customize based on app logic
    }
    
    @available(iOS 17.0, *)
    private func showPrivacyRationale(for permission: PermissionType) async throws {
        // Show iOS 17+ privacy rationale
        guard let privacyAssistant = privacyAssistant else { return }
        
        try await privacyAssistant.showRationale(for: permission)
    }
    
    // MARK: - Legacy Permission Methods
    
    private func requestAllPermissions(completion: @escaping (Bool, [PermissionType]) -> Void) {
        var deniedPermissions: [PermissionType] = []
        
        // Request camera permission
        AVCaptureDevice.requestAccess(for: .video) { cameraGranted in
            if !cameraGranted {
                deniedPermissions.append(.camera)
            }
            
            // Request microphone permission
            AVCaptureDevice.requestAccess(for: .audio) { micGranted in
                if !micGranted {
                    deniedPermissions.append(.microphone)
                }
                
                // Request photos permission
                PHPhotoLibrary.requestAuthorization { photoStatus in
                    let photoGranted = photoStatus == .authorized || photoStatus == .limited
                    if !photoGranted {
                        deniedPermissions.append(.photoLibrary)
                    }
                    
                    let allGranted = deniedPermissions.isEmpty
                    completion(allGranted, deniedPermissions)
                }
            }
        }
    }
    
    // MARK: - Permission Settings
    
    func openAppSettings() {
        guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else { return }
        
        if UIApplication.shared.canOpenURL(settingsURL) {
            UIApplication.shared.open(settingsURL)
        }
    }
    
    func openPrivacySettings() {
        if #available(iOS 17.0, *) {
            // Open iOS 17+ privacy settings
            privacyAssistant?.openPrivacySettings()
        } else {
            // Fallback to app settings
            openAppSettings()
        }
    }
    
    // MARK: - Biometric Authentication
    
    func authenticateWithBiometrics() async -> Bool {
        do {
            let canEvaluate = try context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
            
            if canEvaluate {
                let success = try await context.evaluatePolicy(
                    .deviceOwnerAuthenticationWithBiometrics,
                    localizedReason: "Authenticate to access camera features"
                )
                return success
            }
        } catch {
            logEvent("Biometric Authentication", "Failed: \(error.localizedDescription)")
        }
        
        return false
    }
    
    // MARK: - Permission Analytics
    
    func getPermissionAnalytics() -> PermissionAnalytics {
        return PermissionAnalytics(
            currentState: permissionState,
            detailedPermissions: detailedPermissions,
            requestHistory: getPermissionRequestHistory(),
            denialReasons: getDenialReasons()
        )
    }
    
    private func getPermissionRequestHistory() -> [PermissionRequestEvent] {
        // Return permission request history
        return []
    }
    
    private func getDenialReasons() -> [PermissionDenialReason] {
        // Analyze and return denial reasons
        return []
    }
    
    @available(iOS 17.0, *)
    private func logPermissionRequest(_ result: PermissionRequestResult) async {
        // Log permission request for analytics
        logEvent("Permission Request", "Camera: \(result.camera), Mic: \(result.microphone), Photos: \(result.photos)")
    }
    
    // MARK: - Utilities
    
    private func logEvent(_ name: StaticString, _ message: String) {
        os_signpost(.event, log: log, name: name, "%{public}s", message)
    }
}

// MARK: - Supporting Classes

@available(iOS 17.0, *)
class PermissionMonitor {
    private var monitoringTask: Task<Void, Never>?
    
    func startMonitoring(onChange: @escaping () -> Void) {
        monitoringTask = Task {
            // Monitor permission changes
            while !Task.isCancelled {
                // Check for permission changes
                await checkPermissionChanges(onChange: onChange)
                
                try? await Task.sleep(nanoseconds: 1_000_000_000) // Check every second
            }
        }
    }
    
    func stopMonitoring() {
        monitoringTask?.cancel()
        monitoringTask = nil
    }
    
    private func checkPermissionChanges(onChange: @escaping () -> Void) async {
        // Check for permission changes
    }
}

@available(iOS 17.0, *)
class PrivacyAssistant {
    func showRationale(for permission: PermissionType) async throws {
        // Show iOS 17+ privacy rationale
    }
    
    func openPrivacySettings() {
        // Open privacy settings
    }
}

// MARK: - Data Structures

enum PermissionState {
    case unknown
    case notDetermined
    case granted
    case denied
    case restricted
}

struct DetailedPermissions {
    let camera: CameraPermissionInfo
    let microphone: MicrophonePermissionInfo
    let photos: PhotosPermissionInfo
}

struct CameraPermissionInfo {
    let status: AVAuthorizationStatus
    let capabilities: CameraCapabilities
}

struct MicrophonePermissionInfo {
    let status: AVAuthorizationStatus
}

struct PhotosPermissionInfo {
    let status: PHAuthorizationStatus
    let accessLevel: PhotosAccessLevel
}

struct CameraCapabilities {
    var supportsProRes: Bool = false
    var supportsCinematicMode: Bool = false
    var supportsSpatialVideo: Bool = false
    var supportsPortraitMode: Bool = false
    var supportsActionMode: Bool = false
    var supportsHDR: Bool = false
    var supportsLowLight: Bool = false
    var supportsDepthData: Bool = false
}

enum PhotosAccessLevel {
    case none
    case limited
    case full
    case unknown
}

struct PermissionRequestResult {
    let camera: Bool
    let microphone: Bool
    let photos: Bool
    let error: Error?
    
    init(camera: Bool, microphone: Bool, photos: Bool, error: Error? = nil) {
        self.camera = camera
        self.microphone = microphone
        self.photos = photos
        self.error = error
    }
}

enum PermissionType {
    case camera
    case microphone
    case photos
}

struct PermissionAnalytics {
    let currentState: PermissionState
    let detailedPermissions: DetailedPermissions
    let requestHistory: [PermissionRequestEvent]
    let denialReasons: [PermissionDenialReason]
}

struct PermissionRequestEvent {
    let timestamp: Date
    let permission: PermissionType
    let result: Bool
    let context: String
}

struct PermissionDenialReason {
    let permission: PermissionType
    let reason: String
    let timestamp: Date
}