//
//  BatteryManager.swift
//  DualCameraApp
//
//  Manages battery efficiency and optimizes power consumption during recording
//

import Foundation
import UIKit
import AVFoundation
import os.log

class BatteryManager {
    static let shared = BatteryManager()
    
    private let log = OSLog(subsystem: "com.dualcamera.app", category: "Battery")
    
    // Battery monitoring
    private var batteryLevel: Float = 1.0
    private var batteryState: UIDevice.BatteryState = .unknown
    private var lowPowerModeEnabled: Bool = false
    
    // Power consumption tracking
    private var powerConsumptionHistory: [(Date, Double)] = []
    private let maxPowerHistorySamples = 100
    
    enum BatteryOptimizationLevel: Int, CaseIterable {
        case none = 0
        case light = 1
        case moderate = 2
        case aggressive = 3
        case emergency = 4
        
        var description: String {
            switch self {
            case .none: return "No Optimization"
            case .light: return "Light Optimization"
            case .moderate: return "Moderate Optimization"
            case .aggressive: return "Aggressive Optimization"
            case .emergency: return "Emergency Conservation"
            }
        }
    }
    
    private var currentOptimizationLevel: BatteryOptimizationLevel = .none
    
    private struct BatteryThresholds {
        static let warningLevel: Float = 0.2
        static let criticalLevel: Float = 0.1
        static let emergencyLevel: Float = 0.05
        static let shutdownLevel: Float = 0.02
    }
    
    private var baselinePowerConsumption: Double = 0.0
    private var recordingPowerConsumption: Double = 0.0
    private var lastPowerMeasurement: CFTimeInterval = 0
    
    private var originalVideoQuality: VideoQuality?
    private var originalFrameRate: Double?
    private var originalTripleOutputEnabled: Bool?
    private var originalHapticFeedbackEnabled: Bool?
    
    var onBatteryLevelChanged: ((Float, UIDevice.BatteryState) -> Void)?
    var onOptimizationLevelChanged: ((BatteryOptimizationLevel) -> Void)?
    var onLowBatteryWarning: ((String) -> Void)?
    
    private init() {
        setupBatteryMonitoring()
        setupPowerConsumptionTracking()
    }
    
    // MARK: - Battery Monitoring Setup
    
    private func setupBatteryMonitoring() {
        // Enable battery monitoring
        UIDevice.current.isBatteryMonitoringEnabled = true
        
        // Get initial battery state
        batteryLevel = UIDevice.current.batteryLevel
        batteryState = UIDevice.current.batteryState
        lowPowerModeEnabled = ProcessInfo.processInfo.isLowPowerModeEnabled
        
        // Register for battery level changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(batteryLevelChanged),
            name: UIDevice.batteryLevelDidChangeNotification,
            object: nil
        )
        
        // Register for battery state changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(batteryStateChanged),
            name: UIDevice.batteryStateDidChangeNotification,
            object: nil
        )
        
        // Register for low power mode changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(lowPowerModeChanged),
            name: .NSProcessInfoPowerStateDidChange,
            object: nil
        )
        
        // Start periodic battery checks
        Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            self?.checkBatteryStatus()
        }
        
        logEvent("Battery Manager", "Initialized with level: \(String(format: "%.0f", batteryLevel * 100))%, state: \(batteryStateDescription(batteryState))")
    }
    
    @objc private func batteryLevelChanged() {
        let newLevel = UIDevice.current.batteryLevel
        let previousLevel = batteryLevel
        
        if newLevel != previousLevel {
            batteryLevel = newLevel
            checkBatteryOptimization()
            
            logEvent("Battery Level", "Changed to \(String(format: "%.0f", batteryLevel * 100))%")
            
            // Notify callbacks
            DispatchQueue.main.async {
                self.onBatteryLevelChanged?(self.batteryLevel, self.batteryState)
            }
        }
    }
    
    @objc private func batteryStateChanged() {
        let newState = UIDevice.current.batteryState
        
        if newState != batteryState {
            batteryState = newState
            checkBatteryOptimization()
            
            logEvent("Battery State", "Changed to \(batteryStateDescription(batteryState))")
            
            // Notify callbacks
            DispatchQueue.main.async {
                self.onBatteryLevelChanged?(self.batteryLevel, self.batteryState)
            }
        }
    }
    
    @objc private func lowPowerModeChanged() {
        let newLowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
        
        if newLowPowerMode != lowPowerModeEnabled {
            lowPowerModeEnabled = newLowPowerMode
            checkBatteryOptimization()
            
            logEvent("Low Power Mode", "Changed to \(lowPowerModeEnabled ? "Enabled" : "Disabled")")
        }
    }
    
    private func checkBatteryStatus() {
        checkBatteryOptimization()
        estimatePowerConsumption()
    }
    
    private func checkBatteryOptimization() {
        let newOptimizationLevel = determineOptimizationLevel()
        
        if newOptimizationLevel != currentOptimizationLevel {
            let previousLevel = currentOptimizationLevel
            currentOptimizationLevel = newOptimizationLevel
            
            // Store original settings before first optimization
            if previousLevel == .none && newOptimizationLevel != .none {
                storeOriginalSettings()
            }
            
            // Apply optimization
            applyBatteryOptimization(level: newOptimizationLevel)
            
            logEvent("Battery Optimization", "Changed from \(previousLevel.description) to \(newOptimizationLevel.description)")
            
            // Notify callbacks
            DispatchQueue.main.async {
                self.onOptimizationLevelChanged?(newOptimizationLevel)
            }
        }
    }
    
    private func determineOptimizationLevel() -> BatteryOptimizationLevel {
        // Check low power mode first
        if lowPowerModeEnabled {
            return .moderate
        }
        
        // Determine based on battery level
        switch batteryLevel {
        case BatteryThresholds.emergencyLevel..<BatteryThresholds.criticalLevel:
            return .emergency
        case BatteryThresholds.criticalLevel..<BatteryThresholds.warningLevel:
            return .aggressive
        case BatteryThresholds.warningLevel..<0.3: // 30%
            return .moderate
        case 0.3..<0.5: // 30-50%
            return .light
        default:
            return .none
        }
    }
    
    private func storeOriginalSettings() {
        originalVideoQuality = SettingsManager.shared.videoQuality
        originalFrameRate = 30.0 // Default frame rate
        originalTripleOutputEnabled = SettingsManager.shared.enableTripleOutput
        originalHapticFeedbackEnabled = SettingsManager.shared.enableHapticFeedback
        
        logEvent("Battery Optimization", "Stored original settings")
    }
    
    private func applyBatteryOptimization(level: BatteryOptimizationLevel) {
        switch level {
        case .none:
            restoreOriginalSettings()
            
        case .light:
            applyLightOptimization()
            
        case .moderate:
            applyModerateOptimization()
            
        case .aggressive:
            applyAggressiveOptimization()
            
        case .emergency:
            applyEmergencyOptimization()
        }
    }
    
    private func applyLightOptimization() {
        // Reduce frame rate slightly
        // This would be implemented in the camera manager
        
        // Enable adaptive quality
        SettingsManager.shared.recordingQualityAdaptive = true
        
        logEvent("Battery Optimization", "Applied light optimization")
    }
    
    private func applyModerateOptimization() {
        // Reduce video quality
        if let originalQuality = originalVideoQuality {
            switch originalQuality {
            case .uhd4k:
                SettingsManager.shared.videoQuality = .hd1080
            case .hd1080:
                SettingsManager.shared.videoQuality = .hd720
            case .hd720:
                SettingsManager.shared.videoQuality = .hd720 // Stay at 720p
            }
        }
        
        // Enable adaptive quality
        SettingsManager.shared.recordingQualityAdaptive = true
        
        // Reduce frame rate
        // This would be implemented in the camera manager
        
        logEvent("Battery Optimization", "Applied moderate optimization")
    }
    
    private func applyAggressiveOptimization() {
        // Force 720p quality
        SettingsManager.shared.videoQuality = .hd720
        
        // Disable triple output
        SettingsManager.shared.enableTripleOutput = false
        
        // Reduce frame rate
        // This would be implemented in the camera manager
        
        // Disable haptic feedback
        SettingsManager.shared.enableHapticFeedback = false
        
        logEvent("Battery Optimization", "Applied aggressive optimization")
    }
    
    private func applyEmergencyOptimization() {
        // Force lowest quality
        SettingsManager.shared.videoQuality = .hd720
        
        // Disable all non-essential features
        SettingsManager.shared.enableTripleOutput = false
        SettingsManager.shared.enableHapticFeedback = false
        
        // Reduce frame rate to minimum
        // This would be implemented in the camera manager
        
        // Show warning
        DispatchQueue.main.async {
            self.onLowBatteryWarning?("Critical battery level. Please connect to a power source or stop recording.")
        }
        
        logEvent("Battery Optimization", "Applied emergency optimization")
    }
    
    private func restoreOriginalSettings() {
        guard let originalQuality = originalVideoQuality,
              let originalTripleOutput = originalTripleOutputEnabled,
              let originalHapticFeedback = originalHapticFeedbackEnabled else {
            return
        }
        
        // Restore settings
        SettingsManager.shared.videoQuality = originalQuality
        SettingsManager.shared.enableTripleOutput = originalTripleOutput
        SettingsManager.shared.enableHapticFeedback = originalHapticFeedback
        
        logEvent("Battery Optimization", "Restored original settings")
    }
    
    // MARK: - Power Consumption Tracking
    
    private func setupPowerConsumptionTracking() {
        // Measure baseline power consumption
        baselinePowerConsumption = estimateCurrentPowerConsumption()
        
        logEvent("Power Consumption", "Baseline: \(String(format: "%.2f", baselinePowerConsumption))W")
    }
    
    private func estimatePowerConsumption() {
        let currentTime = CACurrentMediaTime()
        
        // Only estimate every 10 seconds
        if currentTime - lastPowerMeasurement > 10.0 {
            lastPowerMeasurement = currentTime
            
            let currentConsumption = estimateCurrentPowerConsumption()
            recordingPowerConsumption = currentConsumption - baselinePowerConsumption
            
            // Record in history
            powerConsumptionHistory.append((Date(), recordingPowerConsumption))
            
            // Keep only recent samples
            if powerConsumptionHistory.count > maxPowerHistorySamples {
                powerConsumptionHistory.removeFirst()
            }
            
            logEvent("Power Consumption", "Recording: \(String(format: "%.2f", recordingPowerConsumption))W")
        }
    }
    
    private func estimateCurrentPowerConsumption() -> Double {
        // This is a simplified estimation
        // In a real implementation, you would use more sophisticated methods
        
        var estimatedConsumption = baselinePowerConsumption
        
        // Factor in recording quality
        switch SettingsManager.shared.videoQuality {
        case .uhd4k:
            estimatedConsumption += 4.0 // 4K consumes more power
        case .hd1080:
            estimatedConsumption += 2.5
        case .hd720:
            estimatedConsumption += 1.5
        }
        
        // Factor in triple output
        if SettingsManager.shared.enableTripleOutput {
            estimatedConsumption += 1.0
        }
        
        // Factor in thermal state (higher temperature = more power)
        let thermalState = ThermalManager.shared.getCurrentThermalState()
        switch thermalState {
        case .serious:
            estimatedConsumption += 0.5
        case .critical:
            estimatedConsumption += 1.0
        default:
            break
        }
        
        return estimatedConsumption
    }
    
    // MARK: - Battery Life Prediction
    
    func estimateRemainingRecordingTime() -> TimeInterval {
        guard batteryLevel > 0 && recordingPowerConsumption > 0 else { return 0 }
        
        // Estimate battery capacity (in Wh)
        let estimatedBatteryCapacity: Double = 10.0 // 10Wh for typical iPhone
        
        // Calculate remaining energy
        let remainingEnergy = estimatedBatteryCapacity * Double(batteryLevel)
        
        // Estimate remaining time in seconds
        let remainingTime = remainingEnergy / recordingPowerConsumption
        
        return remainingTime
    }
    
    func getBatteryStatistics() -> [String: Any] {
        let avgPowerConsumption = powerConsumptionHistory.isEmpty ? 0 : 
            powerConsumptionHistory.map { $0.1 }.reduce(0, +) / Double(powerConsumptionHistory.count)
        
        return [
            "batteryLevel": batteryLevel,
            "batteryState": batteryStateDescription(batteryState),
            "lowPowerModeEnabled": lowPowerModeEnabled,
            "optimizationLevel": currentOptimizationLevel.description,
            "baselinePowerConsumption": baselinePowerConsumption,
            "recordingPowerConsumption": recordingPowerConsumption,
            "averagePowerConsumption": avgPowerConsumption,
            "estimatedRemainingTime": estimateRemainingRecordingTime()
        ]
    }
    
    // MARK: - Public Interface
    
    func getCurrentBatteryLevel() -> Float {
        return batteryLevel
    }
    
    func getCurrentBatteryState() -> UIDevice.BatteryState {
        return batteryState
    }
    
    func getCurrentOptimizationLevel() -> BatteryOptimizationLevel {
        return currentOptimizationLevel
    }
    
    func isLowPowerModeEnabled() -> Bool {
        return lowPowerModeEnabled
    }
    
    func isBatteryOptimizationActive() -> Bool {
        return currentOptimizationLevel != .none
    }
    
    func forceBatteryOptimizationCheck() {
        checkBatteryOptimization()
    }
    
    func resetBatteryOptimization() {
        currentOptimizationLevel = .none
        restoreOriginalSettings()
        
        logEvent("Battery Manager", "Reset battery optimization")
    }
    
    // MARK: - Helper Methods
    
    private func batteryStateDescription(_ state: UIDevice.BatteryState) -> String {
        switch state {
        case .unknown: return "Unknown"
        case .unplugged: return "Unplugged"
        case .charging: return "Charging"
        case .full: return "Full"
        @unknown default: return "Unknown"
        }
    }
    
    private func logEvent(_ name: StaticString, _ message: String = "") {
        os_signpost(.event, log: log, name: name, "%{public}s", message)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

