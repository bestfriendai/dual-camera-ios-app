//
//  PermissionManager.swift
//  DualCameraApp
//
//  Centralized permission management for camera, microphone, and photo library
//

import AVFoundation
import Photos
import UIKit

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
    
    private init() {}
    
    // MARK: - Permission Status Checks
    
    func cameraPermissionStatus() -> PermissionStatus {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        return convertAVAuthorizationStatus(status)
    }
    
    func microphonePermissionStatus() -> PermissionStatus {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        return convertAVAuthorizationStatus(status)
    }
    
    func photoLibraryPermissionStatus() -> PermissionStatus {
        let status = PHPhotoLibrary.authorizationStatus()
        return convertPHAuthorizationStatus(status)
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
        AVCaptureDevice.requestAccess(for: .video) { granted in
            DispatchQueue.main.async {
                completion(granted)
            }
        }
    }
    
    func requestMicrophonePermission(completion: @escaping (Bool) -> Void) {
        AVCaptureDevice.requestAccess(for: .audio) { granted in
            DispatchQueue.main.async {
                completion(granted)
            }
        }
    }
    
    func requestPhotoLibraryPermission(completion: @escaping (Bool) -> Void) {
        PHPhotoLibrary.requestAuthorization { status in
            DispatchQueue.main.async {
                completion(status == .authorized || status == .limited)
            }
        }
    }
    
    // MARK: - Comprehensive Permission Flow
    
    /// Request all required permissions in sequence
    func requestAllPermissions(completion: @escaping (Bool, [PermissionType]) -> Void) {
        var deniedPermissions: [PermissionType] = []
        
        // Step 1: Request camera permission
        requestCameraPermission { [weak self] cameraGranted in
            guard let self = self else { return }
            
            if !cameraGranted {
                deniedPermissions.append(.camera)
                completion(false, deniedPermissions)
                return
            }
            
            // Step 2: Request microphone permission
            self.requestMicrophonePermission { micGranted in
                if !micGranted {
                    deniedPermissions.append(.microphone)
                }
                
                // Step 3: Request photo library permission
                self.requestPhotoLibraryPermission { photoGranted in
                    if !photoGranted {
                        deniedPermissions.append(.photoLibrary)
                    }
                    
                    // All permissions requested
                    let allGranted = deniedPermissions.isEmpty
                    completion(allGranted, deniedPermissions)
                }
            }
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

