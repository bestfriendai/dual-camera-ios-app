//
//  ModernPermissionCoordinator.swift
//  DualCameraApp
//
//  Concurrent permission requests for faster startup
//

import AVFoundation
import Photos
import UIKit

@available(iOS 15.0, *)
final class ModernPermissionCoordinator: @unchecked Sendable {
    
    func requestAllPermissionsConcurrently() async -> (granted: Bool, denied: [PermissionType]) {
        async let cameraGranted = requestCameraPermission()
        async let microphoneGranted = requestMicrophonePermission()
        async let photoLibraryGranted = requestPhotoLibraryPermission()
        
        let (camera, microphone, photoLibrary) = await (cameraGranted, microphoneGranted, photoLibraryGranted)
        
        var deniedPermissions: [PermissionType] = []
        
        if !camera {
            deniedPermissions.append(.camera)
        }
        if !microphone {
            deniedPermissions.append(.microphone)
        }
        if !photoLibrary {
            deniedPermissions.append(.photoLibrary)
        }
        
        let allGranted = deniedPermissions.isEmpty
        return (allGranted, deniedPermissions)
    }
    
    func checkCurrentStatus() -> (allGranted: Bool, denied: [PermissionType]) {
        var deniedPermissions: [PermissionType] = []
        
        let cameraStatus = AVCaptureDevice.authorizationStatus(for: .video)
        let microphoneStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        let photoLibraryStatus = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        
        if cameraStatus != .authorized {
            deniedPermissions.append(.camera)
        }
        if microphoneStatus != .authorized {
            deniedPermissions.append(.microphone)
        }
        if photoLibraryStatus != .authorized {
            deniedPermissions.append(.photoLibrary)
        }
        
        return (deniedPermissions.isEmpty, deniedPermissions)
    }
    
    private func requestCameraPermission() async -> Bool {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        
        switch status {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .video)
        default:
            return false
        }
    }
    
    private func requestMicrophonePermission() async -> Bool {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        
        switch status {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .audio)
        default:
            return false
        }
    }
    
    private func requestPhotoLibraryPermission() async -> Bool {
        let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        
        switch status {
        case .authorized, .limited:
            return true
        case .notDetermined:
            let newStatus = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
            return newStatus == .authorized || newStatus == .limited
        default:
            return false
        }
    }
    
    func presentDeniedAlert(deniedPermissions: [PermissionType], from viewController: UIViewController) {
        guard !deniedPermissions.isEmpty else { return }
        
        _ = deniedPermissions.map { $0.title }.joined(separator: ", ")
        
        var detailedMessage = "This app needs the following permissions:\n\n"
        for permission in deniedPermissions {
            detailedMessage += "• \(permission.title)\n"
        }
        detailedMessage += "\nPlease enable them in Settings."
        
        DispatchQueue.main.async {
            let alert = UIAlertController(
                title: "Permissions Required",
                message: detailedMessage,
                preferredStyle: .alert
            )
            
            alert.addAction(UIAlertAction(title: "Open Settings", style: .default) { _ in
                if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsURL)
                }
            })
            
            alert.addAction(UIAlertAction(title: "Not Now", style: .cancel))
            
            viewController.present(alert, animated: true)
        }
    }
}
