//
//  ErrorRecoveryManager.swift
//  DualCameraApp
//
//  Advanced error recovery with automatic retry and graceful degradation
//

import Foundation
import AVFoundation
import UIKit
import os

class ErrorRecoveryManager {
    static let shared = ErrorRecoveryManager()
    
    private let logger = Logger(subsystem: "com.dualcamera.app", category: "ErrorRecovery")
    
    // Error recovery state
    private var isRecovering = false
    private var recoveryAttempts: [String: Int] = [:]
    private var lastRecoveryTime: CFTimeInterval = 0
    private let recoveryCooldown: TimeInterval = 2.0 // 2 seconds between recovery attempts
    
    // Error recovery strategies
    enum RecoveryStrategy {
        case retry
        case restart
        case degrade
        case fallback
        case abort
        
        var description: String {
            switch self {
            case .retry: return "Retry"
            case .restart: return "Restart"
            case .degrade: return "Degrade"
            case .fallback: return "Fallback"
            case .abort: return "Abort"
            }
        }
    }
    
    // Error recovery configuration
    struct RecoveryConfig {
        let maxRetries: Int
        let retryDelay: TimeInterval
        let strategy: RecoveryStrategy
        
        static let `default` = RecoveryConfig(maxRetries: 3, retryDelay: 1.0, strategy: .retry)
        static let aggressive = RecoveryConfig(maxRetries: 5, retryDelay: 0.5, strategy: .retry)
        static let conservative = RecoveryConfig(maxRetries: 2, retryDelay: 2.0, strategy: .degrade)
    }
    
    // Error type configurations
    private var recoveryConfigs: [String: RecoveryConfig] = [:]
    
    // Recovery history
    private var recoveryHistory: [(Date, String, RecoveryStrategy, Bool)] = []
    private let maxRecoveryHistorySamples = 100
    
    // Recovery callbacks
    var onRecoveryStarted: ((String, RecoveryStrategy) -> Void)?
    var onRecoveryCompleted: ((String, RecoveryStrategy, Bool) -> Void)?
    var onRecoveryFailed: ((String, Int) -> Void)?
    
    private init() {
        setupRecoveryConfigs()
    }
    
    // MARK: - Recovery Configuration Setup
    
    private func setupRecoveryConfigs() {
        // Camera setup errors
        recoveryConfigs["cameraSetup"] = RecoveryConfig(maxRetries: 3, retryDelay: 1.0, strategy: .restart)
        
        // Recording errors
        recoveryConfigs["recordingStart"] = RecoveryConfig(maxRetries: 2, retryDelay: 0.5, strategy: .retry)
        recoveryConfigs["recordingStop"] = RecoveryConfig(maxRetries: 1, retryDelay: 0.2, strategy: .fallback)
        
        // Memory errors
        recoveryConfigs["memoryPressure"] = RecoveryConfig(maxRetries: 1, retryDelay: 0.5, strategy: .degrade)
        recoveryConfigs["outOfMemory"] = RecoveryConfig(maxRetries: 1, retryDelay: 1.0, strategy: .fallback)
        
        // Storage errors
        recoveryConfigs["storageFull"] = RecoveryConfig(maxRetries: 1, retryDelay: 2.0, strategy: .degrade)
        recoveryConfigs["fileSystem"] = RecoveryConfig(maxRetries: 2, retryDelay: 1.0, strategy: .retry)
        
        // Thermal errors
        recoveryConfigs["thermalThrottling"] = RecoveryConfig(maxRetries: 1, retryDelay: 5.0, strategy: .degrade)
        recoveryConfigs["thermalShutdown"] = RecoveryConfig(maxRetries: 1, retryDelay: 10.0, strategy: .abort)
        
        // Permission errors
        recoveryConfigs["cameraPermission"] = RecoveryConfig(maxRetries: 1, retryDelay: 0.0, strategy: .abort)
        recoveryConfigs["microphonePermission"] = RecoveryConfig(maxRetries: 1, retryDelay: 0.0, strategy: .abort)
        
        // Network errors
        recoveryConfigs["network"] = RecoveryConfig(maxRetries: 3, retryDelay: 2.0, strategy: .retry)
        
        logEvent("Error Recovery", "Initialized recovery configurations")
    }
    
    // MARK: - Error Recovery Interface
    
    func attemptRecovery(for error: Error, errorType: String? = nil, completion: @escaping (Bool) -> Void) {
        let errorType = errorType ?? determineErrorType(from: error)
        let config = recoveryConfigs[errorType] ?? RecoveryConfig.default
        
        // Check if we're already recovering
        if isRecovering {
            logEvent("Error Recovery", "Already recovering, queuing \(errorType)")
            DispatchQueue.main.asyncAfter(deadline: .now() + recoveryCooldown) {
                self.attemptRecovery(for: error, errorType: errorType, completion: completion)
            }
            return
        }
        
        // Check recovery cooldown
        let currentTime = CACurrentMediaTime()
        if currentTime - lastRecoveryTime < recoveryCooldown {
            logEvent("Error Recovery", "Recovery cooldown active for \(errorType)")
            DispatchQueue.main.asyncAfter(deadline: .now() + recoveryCooldown) {
                self.attemptRecovery(for: error, errorType: errorType, completion: completion)
            }
            return
        }
        
        // Check retry count
        let retryCount = recoveryAttempts[errorType] ?? 0
        if retryCount >= config.maxRetries {
            logEvent("Error Recovery", "Max retries exceeded for \(errorType)")
            recordRecovery(errorType: errorType, strategy: config.strategy, success: false)
            onRecoveryFailed?(errorType, retryCount)
            completion(false)
            return
        }
        
        // Start recovery
        isRecovering = true
        lastRecoveryTime = currentTime
        recoveryAttempts[errorType] = retryCount + 1
        
        logEvent("Error Recovery", "Starting recovery for \(errorType) with strategy \(config.strategy.description) (attempt \(retryCount + 1)/\(config.maxRetries))")
        
        // Notify callbacks
        DispatchQueue.main.async {
            self.onRecoveryStarted?(errorType, config.strategy)
        }
        
        // Apply recovery strategy
        DispatchQueue.global(qos: .userInitiated).async {
            let success = self.applyRecoveryStrategy(error: error, errorType: errorType, config: config)
            
            DispatchQueue.main.async {
                self.isRecovering = false
                
                if success {
                    // Reset retry count on success
                    self.recoveryAttempts.removeValue(forKey: errorType)
                    self.logEvent("Error Recovery", "Recovery successful for \(errorType)")
                } else {
                    self.logEvent("Error Recovery", "Recovery failed for \(errorType)")
                }
                
                // Record recovery
                self.recordRecovery(errorType: errorType, strategy: config.strategy, success: success)
                
                // Notify callbacks
                self.onRecoveryCompleted?(errorType, config.strategy, success)
                
                // If recovery failed and we have retries left, try again
                if !success && retryCount + 1 < config.maxRetries {
                    DispatchQueue.main.asyncAfter(deadline: .now() + config.retryDelay) {
                        self.attemptRecovery(for: error, errorType: errorType, completion: completion)
                    }
                } else {
                    completion(success)
                }
            }
        }
    }
    
    private func applyRecoveryStrategy(error: Error, errorType: String, config: RecoveryConfig) -> Bool {
        switch config.strategy {
        case .retry:
            return applyRetryStrategy(error: error, errorType: errorType)
            
        case .restart:
            return applyRestartStrategy(error: error, errorType: errorType)
            
        case .degrade:
            return applyDegradeStrategy(error: error, errorType: errorType)
            
        case .fallback:
            return applyFallbackStrategy(error: error, errorType: errorType)
            
        case .abort:
            return applyAbortStrategy(error: error, errorType: errorType)
        }
    }
    
    // MARK: - Recovery Strategies
    
    private func applyRetryStrategy(error: Error, errorType: String) -> Bool {
        logEvent("Recovery Strategy", "Applying retry for \(errorType)")
        
        switch errorType {
        case "cameraSetup":
            return retryCameraSetup()
            
        case "recordingStart":
            return retryRecordingStart()
            
        case "recordingStop":
            return retryRecordingStop()
            
        case "fileSystem":
            return retryFileSystemOperation()
            
        case "network":
            return retryNetworkOperation()
            
        default:
            return false
        }
    }
    
    private func applyRestartStrategy(error: Error, errorType: String) -> Bool {
        logEvent("Recovery Strategy", "Applying restart for \(errorType)")
        
        switch errorType {
        case "cameraSetup":
            return restartCameraSetup()
            
        case "recordingStart":
            return restartRecording()
            
        default:
            return false
        }
    }
    
    private func applyDegradeStrategy(error: Error, errorType: String) -> Bool {
        logEvent("Recovery Strategy", "Applying degradation for \(errorType)")
        
        switch errorType {
        case "memoryPressure":
            return degradeForMemoryPressure()
            
        case "storageFull":
            return degradeForStoragePressure()
            
        case "thermalThrottling":
            return degradeForThermalPressure()
            
        default:
            return false
        }
    }
    
    private func applyFallbackStrategy(error: Error, errorType: String) -> Bool {
        logEvent("Recovery Strategy", "Applying fallback for \(errorType)")
        
        switch errorType {
        case "recordingStop":
            return fallbackRecordingStop()
            
        case "outOfMemory":
            return fallbackOutOfMemory()
            
        default:
            return false
        }
    }
    
    private func applyAbortStrategy(error: Error, errorType: String) -> Bool {
        logEvent("Recovery Strategy", "Applying abort for \(errorType)")
        
        switch errorType {
        case "cameraPermission":
            return abortForPermissionError()
            
        case "microphonePermission":
            return abortForPermissionError()
            
        case "thermalShutdown":
            return abortForThermalShutdown()
            
        default:
            return false
        }
    }
    
    // MARK: - Specific Recovery Implementations
    
    private func retryCameraSetup() -> Bool {
        // Reset camera manager and retry setup
        NotificationCenter.default.post(name: .retryCameraSetup, object: nil)
        return true
    }
    
    private func retryRecordingStart() -> Bool {
        // Retry starting recording
        NotificationCenter.default.post(name: .retryRecordingStart, object: nil)
        return true
    }
    
    private func retryRecordingStop() -> Bool {
        // Retry stopping recording
        NotificationCenter.default.post(name: .retryRecordingStop, object: nil)
        return true
    }
    
    private func retryFileSystemOperation() -> Bool {
        // Clear temporary files and retry
        MemoryManager.shared.clearTemporaryFiles()
        return true
    }
    
    private func retryNetworkOperation() -> Bool {
        // Retry network operation
        return true
    }
    
    private func restartCameraSetup() -> Bool {
        // Stop and restart camera setup
        NotificationCenter.default.post(name: .restartCameraSetup, object: nil)
        return true
    }
    
    private func restartRecording() -> Bool {
        // Stop and restart recording
        NotificationCenter.default.post(name: .restartRecording, object: nil)
        return true
    }
    
    private func degradeForMemoryPressure() -> Bool {
        // Apply memory degradation
        MemoryManager.shared.optimizeMemoryUsage()
        AdaptiveQualityManager.shared.setQualityLevel(.medium, manual: false)
        return true
    }
    
    private func degradeForStoragePressure() -> Bool {
        // Apply storage degradation
        SettingsManager.shared.videoQuality = .hd720
        SettingsManager.shared.enableTripleOutput = false
        return true
    }
    
    private func degradeForThermalPressure() -> Bool {
        // Apply thermal degradation
        ThermalManager.shared.forceThermalCheck()
        return true
    }
    
    private func fallbackRecordingStop() -> Bool {
        // Force stop recording and save what we have
        NotificationCenter.default.post(name: .forceStopRecording, object: nil)
        return true
    }
    
    private func fallbackOutOfMemory() -> Bool {
        // Emergency memory cleanup
        MemoryManager.shared.optimizeMemoryUsage()
        SettingsManager.shared.enableTripleOutput = false
        return true
    }
    
    private func abortForPermissionError() -> Bool {
        // Show permission error and abort
        ErrorHandlingManager.shared.handleCustomError(type: .cameraPermission)
        return false
    }
    
    private func abortForThermalShutdown() -> Bool {
        // Show thermal error and abort
        ErrorHandlingManager.shared.handleCustomError(type: .deviceCompatibility)
        return false
    }
    
    // MARK: - Helper Methods
    
    private func determineErrorType(from error: Error) -> String {
        let errorDescription = error.localizedDescription.lowercased()
        
        if errorDescription.contains("camera") && errorDescription.contains("permission") {
            return "cameraPermission"
        } else if errorDescription.contains("microphone") && errorDescription.contains("permission") {
            return "microphonePermission"
        } else if errorDescription.contains("camera") && (errorDescription.contains("setup") || errorDescription.contains("initialize")) {
            return "cameraSetup"
        } else if errorDescription.contains("recording") && errorDescription.contains("start") {
            return "recordingStart"
        } else if errorDescription.contains("recording") && errorDescription.contains("stop") {
            return "recordingStop"
        } else if errorDescription.contains("storage") || errorDescription.contains("space") {
            return "storageFull"
        } else if errorDescription.contains("memory") {
            return "memoryPressure"
        } else if errorDescription.contains("thermal") {
            return "thermalThrottling"
        } else if errorDescription.contains("network") {
            return "network"
        } else if errorDescription.contains("file") {
            return "fileSystem"
        } else {
            return "unknown"
        }
    }
    
    private func recordRecovery(errorType: String, strategy: RecoveryStrategy, success: Bool) {
        recoveryHistory.append((Date(), errorType, strategy, success))
        
        // Keep only recent samples
        if recoveryHistory.count > maxRecoveryHistorySamples {
            recoveryHistory.removeFirst()
        }
    }
    
    // MARK: - Public Interface
    
    func getRecoveryStatistics() -> [String: Any] {
        let totalRecoveries = recoveryHistory.count
        let successfulRecoveries = recoveryHistory.filter { $0.3 }.count
        let successRate = totalRecoveries > 0 ? Double(successfulRecoveries) / Double(totalRecoveries) * 100 : 0
        
        // Count by strategy
        var strategyCounts: [String: Int] = [:]
        for (_, _, strategy, _) in recoveryHistory {
            strategyCounts[strategy.description, default: 0] += 1
        }
        
        // Count by error type
        var errorTypeCounts: [String: Int] = [:]
        for (_, errorType, _, _) in recoveryHistory {
            errorTypeCounts[errorType, default: 0] += 1
        }
        
        return [
            "totalRecoveries": totalRecoveries,
            "successfulRecoveries": successfulRecoveries,
            "successRate": successRate,
            "strategyCounts": strategyCounts,
            "errorTypeCounts": errorTypeCounts,
            "isRecovering": isRecovering,
            "recoveryAttempts": recoveryAttempts
        ]
    }
    
    func resetRecoveryState() {
        isRecovering = false
        recoveryAttempts.removeAll()
        recoveryHistory.removeAll()
        
        logEvent("Error Recovery", "Reset recovery state")
    }
    
    func isRecoveryInProgress() -> Bool {
        return isRecovering
    }
    
    private func logEvent(_ name: StaticString, _ message: String = "") {
        if message.isEmpty {
            logger.notice("\(String(describing: name), privacy: .public)")
        } else {
            logger.notice("\(String(describing: name), privacy: .public): \(message, privacy: .public)")
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - Notification Extensions

extension Notification.Name {
    static let retryCameraSetup = Notification.Name("RetryCameraSetup")
    static let restartCameraSetup = Notification.Name("RestartCameraSetup")
    static let retryRecordingStart = Notification.Name("RetryRecordingStart")
    static let retryRecordingStop = Notification.Name("RetryRecordingStop")
    static let restartRecording = Notification.Name("RestartRecording")
    static let forceStopRecording = Notification.Name("ForceStopRecording")
    static let errorRecovered = Notification.Name("ErrorRecovered")
}

extension ErrorRecoveryManager {
    func handleError(_ error: Error, type: String, presentingViewController: UIViewController?) {
        logger.error("Handling error: \(type) - \(error.localizedDescription)")
        
        attemptRecovery(for: error, errorType: type) { success in
            if success {
                NotificationCenter.default.post(name: .errorRecovered, object: nil)
            }
        }
        
        DispatchQueue.main.async {
            guard let vc = presentingViewController else { return }
            
            let alert = UIAlertController(
                title: "Error",
                message: error.localizedDescription,
                preferredStyle: .alert
            )
            
            alert.addAction(UIAlertAction(title: "OK", style: .cancel))
            vc.present(alert, animated: true)
        }
    }
}