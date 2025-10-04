//
//  PermissionManager.swift
//  DualCameraApp
//
//  Centralized permission management for camera, microphone, and photo library
//

import AVFoundation
import Photos
import UIKit

// MARK: - Permission Types

enum PermissionType {
    case camera
    case microphone
    case photoLibrary
    
    var title: String {
        switch self {
        case .camera: return "Camera Access"
        case .microphone: return "Microphone Access"
        case .photoLibrary: return "Photo Library Access"
        }
    }
    
    var message: String {
        switch self {
        case .camera:
            return "This app needs camera access to record videos from both front and back cameras simultaneously."
        case .microphone:
            return "This app needs microphone access to record audio with your videos."
        case .photoLibrary:
            return "This app needs photo library access to save your merged videos."
        }
    }
}

enum PermissionStatus {
    case authorized
    case denied
    case notDetermined
    case restricted
}

class PermissionManager {

    static let shared = PermissionManager()

    // Cache permission status to avoid redundant checks
    private var cachedCameraStatus: PermissionStatus?
    private var cachedMicrophoneStatus: PermissionStatus?
    private var cachedPhotoLibraryStatus: PermissionStatus?
    private var lastPermissionCheckTime: Date?
    private let cacheValidityDuration: TimeInterval = 2.0 // Cache valid for 2 seconds

    private init() {}
    
    // MARK: - Permission Status Checks

    func cameraPermissionStatus() -> PermissionStatus {
        // Use cache if valid
        if let cached = cachedCameraStatus, isCacheValid() {
            return cached
        }

        let status = AVCaptureDevice.authorizationStatus(for: .video)
        let permissionStatus = convertAVAuthorizationStatus(status)
        cachedCameraStatus = permissionStatus
        updateCacheTime()
        return permissionStatus
    }

    func microphonePermissionStatus() -> PermissionStatus {
        // Use cache if valid
        if let cached = cachedMicrophoneStatus, isCacheValid() {
            return cached
        }

        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        let permissionStatus = convertAVAuthorizationStatus(status)
        cachedMicrophoneStatus = permissionStatus
        updateCacheTime()
        return permissionStatus
    }

    func photoLibraryPermissionStatus() -> PermissionStatus {
        // Use cache if valid
        if let cached = cachedPhotoLibraryStatus, isCacheValid() {
            return cached
        }

        let status = PHPhotoLibrary.authorizationStatus()
        let permissionStatus = convertPHAuthorizationStatus(status)
        cachedPhotoLibraryStatus = permissionStatus
        updateCacheTime()
        return permissionStatus
    }

    private func isCacheValid() -> Bool {
        guard let lastCheck = lastPermissionCheckTime else { return false }
        return Date().timeIntervalSince(lastCheck) < cacheValidityDuration
    }

    private func updateCacheTime() {
        lastPermissionCheckTime = Date()
    }

    private func invalidateCache() {
        cachedCameraStatus = nil
        cachedMicrophoneStatus = nil
        cachedPhotoLibraryStatus = nil
        lastPermissionCheckTime = nil
    }
    
    private func convertAVAuthorizationStatus(_ status: AVAuthorizationStatus) -> PermissionStatus {
        switch status {
        case .authorized:
            return .authorized
        case .denied:
            return .denied
        case .notDetermined:
            return .notDetermined
        case .restricted:
            return .restricted
        @unknown default:
            return .denied
        }
    }
    
    private func convertPHAuthorizationStatus(_ status: PHAuthorizationStatus) -> PermissionStatus {
        switch status {
        case .authorized, .limited:
            return .authorized
        case .denied:
            return .denied
        case .notDetermined:
            return .notDetermined
        case .restricted:
            return .restricted
        @unknown default:
            return .denied
        }
    }
    
    // MARK: - Permission Requests
    
    func requestCameraPermission(completion: @escaping (Bool) -> Void) {
        print("DEBUG: Requesting camera permission...")
        invalidateCache() // Invalidate cache before requesting
        AVCaptureDevice.requestAccess(for: .video) { granted in
            print("DEBUG: Camera permission granted: \(granted)")
            DispatchQueue.main.async {
                completion(granted)
            }
        }
    }

    func requestMicrophonePermission(completion: @escaping (Bool) -> Void) {
        print("DEBUG: Requesting microphone permission...")
        invalidateCache() // Invalidate cache before requesting
        AVCaptureDevice.requestAccess(for: .audio) { granted in
            print("DEBUG: Microphone permission granted: \(granted)")
            DispatchQueue.main.async {
                completion(granted)
            }
        }
    }

    func requestPhotoLibraryPermission(completion: @escaping (Bool) -> Void) {
        print("DEBUG: Requesting photo library permission...")
        invalidateCache() // Invalidate cache before requesting
        PHPhotoLibrary.requestAuthorization { status in
            let granted = status == .authorized || status == .limited
            print("DEBUG: Photo library permission granted: \(granted) (status: \(status))")
            DispatchQueue.main.async {
                completion(granted)
            }
        }
    }

    // MARK: - Parallel Permission Requests (OPTIMIZED)

    /// Request all permissions in parallel for faster UX
    func requestAllPermissionsParallel(completion: @escaping (Bool, [PermissionType]) -> Void) {
        print("DEBUG: Requesting all permissions in parallel...")
        invalidateCache()

        let dispatchGroup = DispatchGroup()
        var deniedPermissions: [PermissionType] = []
        let syncQueue = DispatchQueue(label: "PermissionManager.Sync")

        // Check current status first
        let currentCameraStatus = cameraPermissionStatus()
        let currentMicStatus = microphonePermissionStatus()
        let currentPhotoStatus = photoLibraryPermissionStatus()

        // Request camera permission if needed
        if currentCameraStatus == .notDetermined {
            dispatchGroup.enter()
            AVCaptureDevice.requestAccess(for: .video) { granted in
                if !granted {
                    syncQueue.async {
                        deniedPermissions.append(.camera)
                    }
                }
                dispatchGroup.leave()
            }
        } else if currentCameraStatus != .authorized {
            deniedPermissions.append(.camera)
        }

        // Request microphone permission if needed
        if currentMicStatus == .notDetermined {
            dispatchGroup.enter()
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                if !granted {
                    syncQueue.async {
                        deniedPermissions.append(.microphone)
                    }
                }
                dispatchGroup.leave()
            }
        } else if currentMicStatus != .authorized {
            deniedPermissions.append(.microphone)
        }

        // Request photo library permission if needed
        if currentPhotoStatus == .notDetermined {
            dispatchGroup.enter()
            PHPhotoLibrary.requestAuthorization { status in
                let granted = status == .authorized || status == .limited
                if !granted {
                    syncQueue.async {
                        deniedPermissions.append(.photoLibrary)
                    }
                }
                dispatchGroup.leave()
            }
        } else if currentPhotoStatus != .authorized {
            deniedPermissions.append(.photoLibrary)
        }

        // Wait for all requests to complete
        dispatchGroup.notify(queue: .main) {
            let allGranted = deniedPermissions.isEmpty
            print("DEBUG: All permissions completed - granted: \(allGranted), denied: \(deniedPermissions)")
            completion(allGranted, deniedPermissions)
        }
    }
    
    // MARK: - Comprehensive Permission Flow
    
    /// Request all required permissions in sequence with better UX
    func requestAllPermissions(completion: @escaping (Bool, [PermissionType]) -> Void) {
        var deniedPermissions: [PermissionType] = []
        
        // Check current status first to avoid unnecessary requests
        let currentCameraStatus = cameraPermissionStatus()
        let currentMicStatus = microphonePermissionStatus()
        
        // Request camera permission if needed
        if currentCameraStatus == .notDetermined {
            requestCameraPermission { [weak self] cameraGranted in
                guard let self = self else { return }
                
                if !cameraGranted {
                    deniedPermissions.append(.camera)
                }
                
                // Continue with microphone
                self.requestMicrophoneIfNeeded(currentStatus: currentMicStatus, initialDenied: deniedPermissions, completion: completion)
            }
        } else if currentCameraStatus == .authorized {
            requestMicrophoneIfNeeded(currentStatus: currentMicStatus, initialDenied: deniedPermissions, completion: completion)
        } else {
            deniedPermissions.append(.camera)
            requestMicrophoneIfNeeded(currentStatus: currentMicStatus, initialDenied: deniedPermissions, completion: completion)
        }
    }
    
    private func requestMicrophoneIfNeeded(currentStatus: PermissionStatus, initialDenied: [PermissionType], completion: @escaping (Bool, [PermissionType]) -> Void) {
        if currentStatus == .notDetermined {
            requestMicrophonePermission { [weak self] micGranted in
                guard let self = self else { return }
                
                var deniedPermissions = initialDenied
                if !micGranted {
                    deniedPermissions.append(.microphone)
                }
                
                self.requestPhotoLibraryIfNeeded(initialDenied: deniedPermissions, completion: completion)
            }
        } else if currentStatus == .authorized {
            requestPhotoLibraryIfNeeded(initialDenied: initialDenied, completion: completion)
        } else {
            var deniedPermissions = initialDenied
            deniedPermissions.append(.microphone)
            requestPhotoLibraryIfNeeded(initialDenied: deniedPermissions, completion: completion)
        }
    }
    
    private func requestPhotoLibraryIfNeeded(initialDenied: [PermissionType], completion: @escaping (Bool, [PermissionType]) -> Void) {
        let currentPhotoStatus = photoLibraryPermissionStatus()
        
        if currentPhotoStatus == .notDetermined {
            requestPhotoLibraryPermission { photoGranted in
                var deniedPermissions = initialDenied
                if !photoGranted {
                    deniedPermissions.append(.photoLibrary)
                }
                
                let allGranted = deniedPermissions.isEmpty
                completion(allGranted, deniedPermissions)
            }
        } else if currentPhotoStatus != .authorized {
            var deniedPermissions = initialDenied
            deniedPermissions.append(.photoLibrary)
            let allGranted = deniedPermissions.isEmpty
            completion(allGranted, deniedPermissions)
        } else {
            let allGranted = initialDenied.isEmpty
            completion(allGranted, initialDenied)
        }
    }
    
    /// Check if all required permissions are granted
    func allPermissionsGranted() -> Bool {
        return cameraPermissionStatus() == .authorized &&
               microphonePermissionStatus() == .authorized &&
               photoLibraryPermissionStatus() == .authorized
    }
    
    // MARK: - User-Friendly Alerts
    
    func showPermissionAlert(for type: PermissionType, from viewController: UIViewController) {
        let alert = UIAlertController(
            title: type.title + " Required",
            message: type.message + "\n\nPlease enable it in Settings to use this feature.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Open Settings", style: .default) { _ in
            if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(settingsURL)
            }
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        viewController.present(alert, animated: true)
    }
    
    func showMultiplePermissionsAlert(deniedPermissions: [PermissionType], from viewController: UIViewController) {
        let permissionNames = deniedPermissions.map { $0.title }.joined(separator: ", ")
        
        let alert = UIAlertController(
            title: "Permissions Required",
            message: "This app requires the following permissions to function properly:\n\n\(permissionNames)\n\nPlease enable them in Settings.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Open Settings", style: .default) { _ in
            if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(settingsURL)
            }
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        viewController.present(alert, animated: true)
    }
    
    // MARK: - Permission Status UI
    
    /// Get a user-friendly status message for display
    func getStatusMessage() -> String {
        let cameraStatus = cameraPermissionStatus()
        let micStatus = microphonePermissionStatus()
        let photoStatus = photoLibraryPermissionStatus()
        
        if cameraStatus == .authorized && micStatus == .authorized && photoStatus == .authorized {
            return "✓ All permissions granted"
        }
        
        var messages: [String] = []
        
        if cameraStatus != .authorized {
            messages.append("Camera: \(statusString(cameraStatus))")
        }
        if micStatus != .authorized {
            messages.append("Microphone: \(statusString(micStatus))")
        }
        if photoStatus != .authorized {
            messages.append("Photos: \(statusString(photoStatus))")
        }
        
        return messages.joined(separator: "\n")
    }
    
    private func statusString(_ status: PermissionStatus) -> String {
        switch status {
        case .authorized:
            return "✓ Granted"
        case .denied:
            return "✗ Denied"
        case .notDetermined:
            return "? Not Asked"
        case .restricted:
            return "⊘ Restricted"
        }
    }
}

