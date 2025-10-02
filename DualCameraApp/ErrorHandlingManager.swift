//
//  ErrorHandlingManager.swift
//  DualCameraApp
//
//  Centralized error handling with graceful degradation and user-friendly messages
//

import Foundation
import AVFoundation
import UIKit

enum DualCameraErrorType: String {
    case cameraPermission
    case microphonePermission
    case photoLibraryPermission
    case cameraSetup
    case recordingStart
    case recordingStop
    case storageSpace
    case memoryPressure
    case deviceCompatibility
    case network
    case fileSystem
    case unknown
    
    var title: String {
        switch self {
        case .cameraPermission:
            return "Camera Access Required"
        case .microphonePermission:
            return "Microphone Access Required"
        case .photoLibraryPermission:
            return "Photo Library Access Required"
        case .cameraSetup:
            return "Camera Setup Failed"
        case .recordingStart:
            return "Recording Failed to Start"
        case .recordingStop:
            return "Recording Failed to Stop"
        case .storageSpace:
            return "Storage Space Low"
        case .memoryPressure:
            return "Device Memory Low"
        case .deviceCompatibility:
            return "Device Compatibility Issue"
        case .network:
            return "Network Connection Issue"
        case .fileSystem:
            return "File System Error"
        case .unknown:
            return "An Error Occurred"
        }
    }
    
    var userFriendlyMessage: String {
        switch self {
        case .cameraPermission:
            return "Camera access is required to record videos. Please enable it in Settings."
        case .microphonePermission:
            return "Microphone access is required to record audio with your videos. Please enable it in Settings."
        case .photoLibraryPermission:
            return "Photo library access is required to save your merged videos. Please enable it in Settings."
        case .cameraSetup:
            return "Unable to initialize the cameras. This may happen if another app is using the cameras or if the device needs to be restarted."
        case .recordingStart:
            return "Failed to start recording. Please check available storage space and try again."
        case .recordingStop:
            return "Failed to stop recording properly. The video may still be saved."
        case .storageSpace:
            return "Not enough storage space available. Please free up some space and try again."
        case .memoryPressure:
            return "Device memory is low. Video quality has been temporarily reduced to maintain performance."
        case .deviceCompatibility:
            return "This feature requires a device with multiple cameras and iOS 13+."
        case .network:
            return "Network connection is required for this feature. Please check your connection and try again."
        case .fileSystem:
            return "Unable to access the file system. Please restart the app and try again."
        case .unknown:
            return "An unexpected error occurred. Please try again or restart the app."
        }
    }
    
    var recoveryAction: String {
        switch self {
        case .cameraPermission, .microphonePermission, .photoLibraryPermission:
            return "Open Settings"
        case .cameraSetup, .deviceCompatibility:
            return "Restart App"
        case .recordingStart, .recordingStop, .storageSpace, .fileSystem:
            return "Try Again"
        case .memoryPressure:
            return "Close Other Apps"
        case .network:
            return "Check Connection"
        case .unknown:
            return "Try Again"
        }
    }
    
    var severity: ErrorSeverity {
        switch self {
        case .cameraPermission, .microphonePermission, .photoLibraryPermission, .deviceCompatibility:
            return .critical
        case .cameraSetup, .recordingStart, .recordingStop, .storageSpace, .fileSystem:
            return .high
        case .memoryPressure, .network:
            return .medium
        case .unknown:
            return .low
        }
    }
}

enum ErrorSeverity {
    case critical
    case high
    case medium
    case low
}

class ErrorHandlingManager {
    static let shared = ErrorHandlingManager()
    
    private var errorLog: [(error: DualCameraErrorType, timestamp: Date)] = []
    private let maxLogSize = 100
    
    private init() {}
    
    func getRecentErrors(limit: Int = 10) -> [(error: DualCameraErrorType, timestamp: Date)] {
        Array(errorLog.prefix(limit))
    }
    
    func clearErrorLog() {
        errorLog.removeAll()
    }
    
    // MARK: - Error Handling
    
    func handleError(_ error: Error, in viewController: UIViewController? = nil, completion: (() -> Void)? = nil) {
        let errorType = determineErrorType(from: error)
        
        logError(error, type: errorType)
        
        if SettingsManager.shared.enableHapticFeedback {
            HapticFeedbackManager.shared.errorOccurred()
        }
        
        if let viewController = viewController {
            showErrorAlert(errorType: errorType, in: viewController, completion: completion)
        }
        
        attemptGracefulDegradation(for: errorType)
    }
    
    func handleCustomError(type: DualCameraErrorType, in viewController: UIViewController? = nil, completion: (() -> Void)? = nil) {
        logCustomError(type)
        
        if SettingsManager.shared.enableHapticFeedback {
            HapticFeedbackManager.shared.errorOccurred()
        }
        
        if let viewController = viewController {
            showErrorAlert(errorType: type, in: viewController, completion: completion)
        }
        
        attemptGracefulDegradation(for: type)
    }
    
    private func determineErrorType(from error: Error) -> DualCameraErrorType {
        let errorDescription = error.localizedDescription.lowercased()
        
        if errorDescription.contains("camera") && errorDescription.contains("permission") {
            return .cameraPermission
        } else if errorDescription.contains("microphone") && errorDescription.contains("permission") {
            return .microphonePermission
        } else if errorDescription.contains("photo") && errorDescription.contains("permission") {
            return .photoLibraryPermission
        } else if errorDescription.contains("camera") && (errorDescription.contains("setup") || errorDescription.contains("initialize")) {
            return .cameraSetup
        } else if errorDescription.contains("recording") && errorDescription.contains("start") {
            return .recordingStart
        } else if errorDescription.contains("recording") && errorDescription.contains("stop") {
            return .recordingStop
        } else if errorDescription.contains("storage") || errorDescription.contains("space") {
            return .storageSpace
        } else if errorDescription.contains("memory") {
            return .memoryPressure
        } else if errorDescription.contains("device") && errorDescription.contains("compatibility") {
            return .deviceCompatibility
        } else if errorDescription.contains("network") || errorDescription.contains("connection") {
            return .network
        } else if errorDescription.contains("file") {
            return .fileSystem
        } else {
            return .unknown
        }
    }
    
    private func showErrorAlert(errorType: DualCameraErrorType, in viewController: UIViewController, completion: (() -> Void)?) {
        let alert = UIAlertController(
            title: errorType.title,
            message: errorType.userFriendlyMessage,
            preferredStyle: .alert
        )
        
        // Add recovery action
        alert.addAction(UIAlertAction(title: errorType.recoveryAction, style: .default) { _ in
            self.handleRecoveryAction(for: errorType, in: viewController)
            completion?()
        })
        
        // Add cancel action for non-critical errors
        if errorType.severity != .critical {
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
                completion?()
            })
        }
        
        // Present alert
        viewController.present(alert, animated: true)
    }
    
    private func handleRecoveryAction(for errorType: DualCameraErrorType, in viewController: UIViewController) {
        switch errorType {
        case .cameraPermission, .microphonePermission, .photoLibraryPermission:
            // Open app settings
            if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(settingsURL)
            }
            
        case .cameraSetup, .deviceCompatibility:
            // Restart app
            restartApp()
            
        case .recordingStart, .recordingStop, .storageSpace, .fileSystem:
            // Try to recover automatically
            attemptAutomaticRecovery(for: errorType)
            
        case .memoryPressure:
            // Suggest closing other apps
            showMemoryWarning()
            
        case .network:
            // Show network settings
            showNetworkSettings()
            
        case .unknown:
            // Try automatic recovery
            attemptAutomaticRecovery(for: errorType)
        }
    }
    
    private func attemptGracefulDegradation(for errorType: DualCameraErrorType) {
        switch errorType {
        case .storageSpace:
            // Reduce video quality to save space
            SettingsManager.shared.videoQuality = .hd720
            
        case .memoryPressure:
            // Reduce quality and disable triple output
            SettingsManager.shared.recordingQualityAdaptive = true
            SettingsManager.shared.enableTripleOutput = false
            
        case .cameraSetup:
            // Try single camera mode if dual camera fails
            SettingsManager.shared.enableTripleOutput = false
            SettingsManager.shared.recordingQualityAdaptive = true

        case .deviceCompatibility:
            // Disable advanced features on incompatible devices
            SettingsManager.shared.enableTripleOutput = false
            SettingsManager.shared.videoQuality = .hd720
            
        default:
            break
        }
    }
    
    private func attemptAutomaticRecovery(for errorType: DualCameraErrorType) {
        switch errorType {
        case .recordingStart:
            // Try to free up storage and retry
            clearTemporaryFiles()
            
        case .recordingStop:
            // Force stop recording and save what we have
            NotificationCenter.default.post(name: .forceStopRecording, object: nil)
            
        case .fileSystem:
            // Reset file system state
            resetFileSystemState()
            
        default:
            break
        }
    }
    
    private func clearTemporaryFiles() {
        // Clear temporary files to free up space
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(at: documentsPath, includingPropertiesForKeys: [.creationDateKey])
            let now = Date()
            
            // Delete temporary files older than 1 hour
            for url in fileURLs {
                if url.lastPathComponent.contains("temp") {
                    if let creationDate = try? url.resourceValues(forKeys: [.creationDateKey]).creationDate {
                        let hoursSinceCreation = Calendar.current.dateComponents([.hour], from: creationDate, to: now).hour ?? 0
                        if hoursSinceCreation > 1 {
                            try? FileManager.default.removeItem(at: url)
                        }
                    }
                }
            }
        } catch {
            print("Error clearing temporary files: \(error)")
        }
    }
    
    private func resetFileSystemState() {
        // Reset file system state
        // This would be implemented based on specific needs
    }
    
    private func showMemoryWarning() {
        // Show memory warning with suggestions
        NotificationCenter.default.post(name: .showMemoryWarning, object: nil)
    }
    
    private func showNetworkSettings() {
        // Show network settings
        // This would open the network settings or show a network status view
    }
    
    private func restartApp() {
        // Restart the app
        DispatchQueue.main.async {
            if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                scene.windows.first?.rootViewController = UIStoryboard(name: "Main", bundle: nil).instantiateInitialViewController()
            }
        }
    }
    
    // MARK: - Error Logging
    
    private func logError(_ error: Error, type: DualCameraErrorType) {
        print("ERROR: \(type.title) - \(error.localizedDescription)")
        
        errorLog.insert((error: type, timestamp: Date()), at: 0)
        if errorLog.count > maxLogSize {
            errorLog.removeLast()
        }
        
        PerformanceMonitor.shared.logEvent("Error", "\(type.rawValue): \(error.localizedDescription)")
    }
    
    private func logCustomError(_ type: DualCameraErrorType) {
        print("ERROR: \(type.title) - \(type.userFriendlyMessage)")
        
        errorLog.insert((error: type, timestamp: Date()), at: 0)
        if errorLog.count > maxLogSize {
            errorLog.removeLast()
        }
        
        PerformanceMonitor.shared.logEvent("Error", "\(type.rawValue): \(type.userFriendlyMessage)")
    }
    
    // MARK: - Error Recovery State
    
    func isInRecoveryState() -> Bool {
        // Check if the app is currently in a recovery state
        return UserDefaults.standard.bool(forKey: "ErrorHandlingManager.InRecoveryState")
    }
    
    func setRecoveryState(_ inRecovery: Bool) {
        UserDefaults.standard.set(inRecovery, forKey: "ErrorHandlingManager.InRecoveryState")
    }
    
    func clearRecoveryState() {
        UserDefaults.standard.removeObject(forKey: "ErrorHandlingManager.InRecoveryState")
    }
}

// MARK: - Notification Extensions

extension Notification.Name {
    static let forceStopRecording = Notification.Name("ForceStopRecording")
    static let showMemoryWarning = Notification.Name("ShowMemoryWarning")
    static let errorRecovered = Notification.Name("ErrorRecovered")
}

// MARK: - Error Recovery Delegate

protocol ErrorRecoveryDelegate: AnyObject {
    func didRecoverFromError(_ errorType: DualCameraErrorType)
    func didFailToRecoverFromError(_ errorType: DualCameraErrorType)
}