// Dual Camera App
import AVFoundation
import Photos
import UIKit

final class PermissionCoordinator: @unchecked Sendable {
    
    enum PermissionState {
        case notRequested
        case requesting
        case granted
        case partiallyGranted([PermissionType])
        case denied([PermissionType])
    }
    
    private(set) var state: PermissionState = .notRequested
    
    private let permissionManager: PermissionManager
    
    init(permissionManager: PermissionManager = .shared) {
        self.permissionManager = permissionManager
    }
    
    nonisolated func requestAllPermissions() async -> (granted: Bool, denied: [PermissionType]) {
        state = .requesting
        
        return await withCheckedContinuation { continuation in
            permissionManager.requestAllPermissionsParallel { [weak self] allGranted, deniedPermissions in
                guard let self = self else {
                    continuation.resume(returning: (false, [.camera, .microphone, .photoLibrary]))
                    return
                }
                
                if allGranted {
                    self.state = .granted
                } else if deniedPermissions.count < 3 {
                    self.state = .partiallyGranted(deniedPermissions)
                } else {
                    self.state = .denied(deniedPermissions)
                }
                
                continuation.resume(returning: (allGranted, deniedPermissions))
            }
        }
    }
    
    func checkCurrentStatus() -> (granted: Bool, denied: [PermissionType]) {
        var deniedPermissions: [PermissionType] = []
        
        if permissionManager.cameraPermissionStatus() != .authorized {
            deniedPermissions.append(.camera)
        }
        
        if permissionManager.microphonePermissionStatus() != .authorized {
            deniedPermissions.append(.microphone)
        }
        
        if permissionManager.photoLibraryPermissionStatus() != .authorized {
            deniedPermissions.append(.photoLibrary)
        }
        
        let allGranted = deniedPermissions.isEmpty
        
        if allGranted {
            state = .granted
        } else {
            state = .denied(deniedPermissions)
        }
        
        return (allGranted, deniedPermissions)
    }
    
    @MainActor func presentPermissionPrimer(from viewController: UIViewController, completion: @escaping () -> Void) {
        let alert = UIAlertController(
            title: "Permissions Required",
            message: "This app needs access to your camera, microphone, and photo library to record and save dual-camera videos.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Continue", style: .default) { _ in
            completion()
        })
        
        viewController.present(alert, animated: true)
    }
    
    @MainActor func presentDeniedAlert(deniedPermissions: [PermissionType], from viewController: UIViewController) {
        if deniedPermissions.count == 1, let permission = deniedPermissions.first {
            permissionManager.showPermissionAlert(for: permission, from: viewController)
        } else if deniedPermissions.count > 1 {
            permissionManager.showMultiplePermissionsAlert(deniedPermissions: deniedPermissions, from: viewController)
        }
    }
}


