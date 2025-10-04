//
//  ThermalManager.swift
//  DualCameraApp
//
//  Manages device thermal state and implements adaptive performance controls
//

import Foundation
import UIKit
import AVFoundation
import os.log

class ThermalManager {
    static let shared = ThermalManager()
    
    private let log = OSLog(subsystem: "com.dualcamera.app", category: "Thermal")
    
    // Thermal state tracking
    private var currentThermalState: ProcessInfo.ThermalState = .nominal
    private var thermalStateHistory: [(Date, ProcessInfo.ThermalState)] = []
    private let maxThermalHistorySamples = 100
    
    enum ThermalMitigationLevel: Int {
        case none = 0
        case light = 1
        case moderate = 2
        case severe = 3
        case emergency = 4
        
        var description: String {
            switch self {
            case .none: return "None"
            case .light: return "Light"
            case .moderate: return "Moderate"
            case .severe: return "Severe"
            case .emergency: return "Emergency"
            }
        }
    }
    
    private var currentMitigationLevel: ThermalMitigationLevel = .none
    
    // Thermal thresholds (in seconds)
    private struct ThermalThresholds {
        static let lightDuration: TimeInterval = 30   // 30 seconds in fair state
        static let moderateDuration: TimeInterval = 60 // 60 seconds in serious state
        static let severeDuration: TimeInterval = 30   // 30 seconds in critical state
        static let cooldownDuration: TimeInterval = 120 // 2 minutes to cool down
    }
    
    // Timers for thermal management
    private var thermalTimer: Timer?
    private var mitigationTimer: Timer?
    private var cooldownTimer: Timer?
    
    // Performance impact tracking
    private var originalVideoQuality: VideoQuality?
    private var originalFrameRate: Double?
    private var originalTripleOutputEnabled: Bool?
    
    // Callbacks for thermal events
    var onThermalStateChanged: ((ProcessInfo.ThermalState) -> Void)?
    var onMitigationLevelChanged: ((ThermalMitigationLevel) -> Void)?
    var onThermalWarning: ((String) -> Void)?
    
    private init() {
        setupThermalMonitoring()
    }
    
    // MARK: - Thermal Monitoring Setup
    
    private func setupThermalMonitoring() {
        // Initial thermal state
        currentThermalState = ProcessInfo.processInfo.thermalState
        thermalStateHistory.append((Date(), currentThermalState))
        
        // Register for thermal state changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(thermalStateChanged),
            name: ProcessInfo.thermalStateDidChangeNotification,
            object: nil
        )
        
        // Start periodic thermal checks
        startThermalMonitoring()
        
        logEvent("Thermal Manager", "Initialized with state: \(thermalStateDescription(currentThermalState))")
    }
    
    @objc private func thermalStateChanged() {
        let newThermalState = ProcessInfo.processInfo.thermalState
        
        if newThermalState != currentThermalState {
            let previousState = currentThermalState
            currentThermalState = newThermalState
            
            // Record state change
            thermalStateHistory.append((Date(), currentThermalState))
            
            // Keep only recent samples
            if thermalStateHistory.count > maxThermalHistorySamples {
                thermalStateHistory.removeFirst()
            }
            
            logEvent("Thermal State", "Changed from \(thermalStateDescription(previousState)) to \(thermalStateDescription(currentThermalState))")
            
            checkThermalConditions()
            
            // Notify callbacks
            DispatchQueue.main.async {
                self.onThermalStateChanged?(self.currentThermalState)
            }
        }
    }
    
    private func startThermalMonitoring() {
        thermalTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.checkThermalConditions()
        }
    }
    
    private func checkThermalConditions() {
        // Analyze thermal state history to determine mitigation needs
        let recentHistory = thermalStateHistory.suffix(20) // Last 20 samples (100 seconds)
        
        let timeInFair = calculateTimeInState(.fair, in: Array(recentHistory))
        let timeInSerious = calculateTimeInState(.serious, in: Array(recentHistory))
        let timeInCritical = calculateTimeInState(.critical, in: Array(recentHistory))
        
        // Determine appropriate mitigation level
        let newMitigationLevel = determineMitigationLevel(
            timeInFair: timeInFair,
            timeInSerious: timeInSerious,
            timeInCritical: timeInCritical
        )
        
        if newMitigationLevel != currentMitigationLevel {
            applyMitigationLevel(newMitigationLevel)
        }
    }
    
    private func calculateTimeInState(_ state: ProcessInfo.ThermalState, in history: [(Date, ProcessInfo.ThermalState)]) -> TimeInterval {
        guard history.count >= 2 else { return 0 }
        
        var totalTime: TimeInterval = 0
        let sortedHistory = history.sorted { $0.0 < $1.0 }
        
        for i in 0..<(sortedHistory.count - 1) {
            let (currentDate, currentState) = sortedHistory[i]
            let (nextDate, _) = sortedHistory[i + 1]
            
            if currentState == state {
                totalTime += nextDate.timeIntervalSince(currentDate)
            }
        }
        
        // Add time from last entry to now if still in that state
        if let (lastDate, lastState) = sortedHistory.last, lastState == state {
            totalTime += Date().timeIntervalSince(lastDate)
        }
        
        return totalTime
    }
    
    private func determineMitigationLevel(timeInFair: TimeInterval, timeInSerious: TimeInterval, timeInCritical: TimeInterval) -> ThermalMitigationLevel {
        if currentThermalState == .critical {
            return .emergency
        }
        
        // Serious state - severe mitigation after threshold
        if currentThermalState == .serious && timeInSerious > ThermalThresholds.severeDuration {
            return .severe
        }
        
        // Fair state - moderate mitigation after threshold
        if currentThermalState == .fair && timeInFair > ThermalThresholds.moderateDuration {
            return .moderate
        }
        
        // Light mitigation for extended fair state
        if currentThermalState == .fair && timeInFair > ThermalThresholds.lightDuration {
            return .light
        }
        
        // No mitigation needed
        return .none
    }
    
    // MARK: - Thermal Mitigation
    
    private func applyMitigationLevel(_ level: ThermalMitigationLevel) {
        let previousLevel = currentMitigationLevel
        currentMitigationLevel = level
        
        logEvent("Thermal Mitigation", "Changed from \(previousLevel.description) to \(level.description)")
        
        // Store original settings before first mitigation
        if previousLevel == .none && level != .none {
            storeOriginalSettings()
        }
        
        // Apply mitigation based on level
        switch level {
        case .none:
            restoreOriginalSettings()
            
        case .light:
            applyLightMitigation()
            
        case .moderate:
            applyModerateMitigation()
            
        case .severe:
            applySevereMitigation()
            
        case .emergency:
            applySevereMitigation()
        }
        
        scheduleMitigationRestoration()
        
        DispatchQueue.main.async {
            self.onMitigationLevelChanged?(level)
            
            if level == .severe || level == .emergency {
                self.onThermalWarning?("Device is overheating. Performance has been reduced to prevent shutdown.")
            }
        }
    }
    
    private func storeOriginalSettings() {
        originalVideoQuality = SettingsManager.shared.videoQuality
        originalFrameRate = 30.0 // Default frame rate
        originalTripleOutputEnabled = SettingsManager.shared.enableTripleOutput
        
        logEvent("Thermal Mitigation", "Stored original settings for restoration")
    }
    
    private func applyLightMitigation() {
        // Reduce frame rate slightly
        // This would be implemented in the camera manager
        
        logEvent("Thermal Mitigation", "Applied light mitigation")
    }
    
    private func applyModerateMitigation() {
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
        
        logEvent("Thermal Mitigation", "Applied moderate mitigation - reduced quality")
    }
    
    private func applySevereMitigation() {
        // Force 720p quality
        SettingsManager.shared.videoQuality = .hd720
        
        // Disable triple output
        SettingsManager.shared.enableTripleOutput = false
        
        // Reduce frame rate
        // This would be implemented in the camera manager
        
        logEvent("Thermal Mitigation", "Applied severe mitigation - disabled features")
    }
    
    private func applyCriticalMitigation() {
        // Force lowest quality
        SettingsManager.shared.videoQuality = .hd720
        
        // Disable all non-essential features
        SettingsManager.shared.enableTripleOutput = false
        SettingsManager.shared.enableHapticFeedback = false
        SettingsManager.shared.recordingQualityAdaptive = true
        
        // Suggest stopping recording
        DispatchQueue.main.async {
            self.onThermalWarning?("Critical temperature reached. Please stop recording to allow device to cool down.")
        }
        
        logEvent("Thermal Mitigation", "Applied critical mitigation - maximum reduction")
    }
    
    private func restoreOriginalSettings() {
        guard let originalQuality = originalVideoQuality,
              let originalTripleOutput = originalTripleOutputEnabled else {
            return
        }
        
        // Restore settings gradually
        SettingsManager.shared.videoQuality = originalQuality
        SettingsManager.shared.enableTripleOutput = originalTripleOutput
        
        // Restore other settings as needed
        
        logEvent("Thermal Mitigation", "Restored original settings")
    }
    
    private func scheduleMitigationRestoration() {
        // Cancel any existing timers
        mitigationTimer?.invalidate()
        cooldownTimer?.invalidate()
        
        // Schedule restoration based on current thermal state
        let restorationDelay: TimeInterval
        
        switch currentThermalState {
        case .nominal:
            restorationDelay = 30 // Quick restoration when cool
        case .fair:
            restorationDelay = 60 // Wait a minute in fair state
        case .serious:
            restorationDelay = 120 // Wait 2 minutes in serious state
        case .critical:
            restorationDelay = 300
        @unknown default:
            restorationDelay = 60
        }
        
        mitigationTimer = Timer.scheduledTimer(withTimeInterval: restorationDelay, repeats: false) { [weak self] _ in
            self?.attemptMitigationRestoration()
        }
    }
    
    private func attemptMitigationRestoration() {
        // Only restore if thermal state has improved
        if currentThermalState == .nominal || currentThermalState == .fair {
            let newLevel = determineMitigationLevel(timeInFair: 0, timeInSerious: 0, timeInCritical: 0)
            
            if newLevel.rawValue < currentMitigationLevel.rawValue {
                applyMitigationLevel(newLevel)
            }
        }
    }
    
    // MARK: - Public Interface
    
    func getCurrentThermalState() -> ProcessInfo.ThermalState {
        return currentThermalState
    }
    
    func getCurrentMitigationLevel() -> ThermalMitigationLevel {
        return currentMitigationLevel
    }
    
    func getThermalHistory() -> [(Date, ProcessInfo.ThermalState)] {
        return thermalStateHistory
    }
    
    func isThermalMitigationActive() -> Bool {
        return currentMitigationLevel != .none
    }
    
    func forceThermalCheck() {
        checkThermalConditions()
    }
    
    func resetThermalManagement() {
        // Cancel all timers
        thermalTimer?.invalidate()
        mitigationTimer?.invalidate()
        cooldownTimer?.invalidate()
        
        // Reset state
        currentMitigationLevel = .none
        thermalStateHistory.removeAll()
        
        // Restart monitoring
        startThermalMonitoring()
        
        logEvent("Thermal Manager", "Reset thermal management system")
    }
    
    // MARK: - Helper Methods
    
    private func thermalStateDescription(_ state: ProcessInfo.ThermalState) -> String {
        switch state {
        case .nominal: return "Nominal"
        case .fair: return "Fair"
        case .serious: return "Serious"
        case .critical: return "Critical"
        @unknown default: return "Unknown"
        }
    }
    
    private func logEvent(_ name: StaticString, _ message: String = "") {
        os_signpost(.event, log: log, name: name, "%{public}s", message)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        thermalTimer?.invalidate()
        mitigationTimer?.invalidate()
        cooldownTimer?.invalidate()
    }
}

