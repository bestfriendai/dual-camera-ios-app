//
//  AdaptiveQualityManager.swift
//  DualCameraApp
//
//  Automatically adjusts recording quality based on device performance and conditions
//

import Foundation
import UIKit
import AVFoundation
import os.log

class AdaptiveQualityManager {
    static let shared = AdaptiveQualityManager()
    
    private let log = OSLog(subsystem: "com.dualcamera.app", category: "AdaptiveQuality")
    
    // Quality adaptation settings
    private var isAdaptiveQualityEnabled: Bool = true
    private var adaptationTimer: Timer?
    private let adaptationInterval: TimeInterval = 2.0 // Check every 2 seconds
    
    // Performance metrics for adaptation
    private var frameRateHistory: [Double] = []
    private var cpuUsageHistory: [Double] = []
    private var memoryUsageHistory: [Double] = []
    private var thermalStateHistory: [ProcessInfo.ThermalState] = []
    
    private let maxHistorySamples = 30
    
    // Quality levels
    enum QualityLevel: Int, CaseIterable {
        case ultraHigh = 4  // 4K
        case high = 3       // 1080p
        case medium = 2     // 720p
        case low = 1        // 480p (if supported)
        
        var videoQuality: VideoQuality {
            switch self {
            case .ultraHigh: return .uhd4k
            case .high: return .hd1080
            case .medium: return .hd720
            case .low: return .hd720 // Fallback to 720p
            }
        }
        
        var frameRate: Double {
            switch self {
            case .ultraHigh: return 30
            case .high: return 30
            case .medium: return 30
            case .low: return 24
            }
        }
        
        var bitRate: Int {
            switch self {
            case .ultraHigh: return 20_000_000  // 20 Mbps
            case .high: return 10_000_000       // 10 Mbps
            case .medium: return 5_000_000       // 5 Mbps
            case .low: return 2_500_000          // 2.5 Mbps
            }
        }
        
        var description: String {
            switch self {
            case .ultraHigh: return "4K Ultra HD"
            case .high: return "1080p Full HD"
            case .medium: return "720p HD"
            case .low: return "720p Standard"
            }
        }
    }
    
    // Current quality state
    private var currentQualityLevel: QualityLevel = .high
    private var targetQualityLevel: QualityLevel = .high
    private var originalQualityLevel: QualityLevel?
    
    // Adaptation thresholds
    private struct AdaptationThresholds {
        // Frame rate thresholds (percentage of target)
        static let frameRateExcellent: Double = 98    // 98%+
        static let frameRateGood: Double = 95         // 95%+
        static let frameRateFair: Double = 90         // 90%+
        static let frameRatePoor: Double = 85         // 85%-
        
        // CPU usage thresholds (percentage)
        static let cpuExcellent: Double = 40         // < 40%
        static let cpuGood: Double = 60              // < 60%
        static let cpuFair: Double = 80              // < 80%
        static let cpuPoor: Double = 80              // 80%+
        
        // Memory usage thresholds (MB)
        static let memoryExcellent: Double = 150     // < 150MB
        static let memoryGood: Double = 200          // < 200MB
        static let memoryFair: Double = 250          // < 250MB
        static let memoryPoor: Double = 250          // 250MB+
        
        // Thermal state thresholds
        static let thermalExcellent = ProcessInfo.ThermalState.nominal
        static let thermalGood = ProcessInfo.ThermalState.nominal
        static let thermalFair = ProcessInfo.ThermalState.fair
        static let thermalPoor = ProcessInfo.ThermalState.serious
    }
    
    // Adaptation hysteresis to prevent rapid changes
    private var lastAdaptationTime: CFTimeInterval = 0
    private let adaptationCooldown: TimeInterval = 5.0 // 5 seconds between adaptations
    
    // Callbacks for quality changes
    var onQualityLevelChanged: ((QualityLevel, String) -> Void)?
    var onQualityRestored: ((QualityLevel) -> Void)?
    
    private init() {
        setupAdaptiveQuality()
    }
    
    // MARK: - Adaptive Quality Setup
    
    private func setupAdaptiveQuality() {
        // Initialize with current settings
        currentQualityLevel = qualityLevelFromVideoQuality(SettingsManager.shared.videoQuality)
        targetQualityLevel = currentQualityLevel
        originalQualityLevel = currentQualityLevel
        
        // Start adaptation monitoring
        startAdaptiveMonitoring()
        
        logEvent("Adaptive Quality", "Initialized with level: \(currentQualityLevel.description)")
    }
    
    private func startAdaptiveMonitoring() {
        adaptationTimer = Timer.scheduledTimer(withTimeInterval: adaptationInterval, repeats: true) { [weak self] _ in
            self?.performQualityAdaptation()
        }
    }
    
    private func performQualityAdaptation() {
        guard isAdaptiveQualityEnabled else { return }
        
        // Collect current performance metrics
        collectPerformanceMetrics()
        
        // Calculate performance score
        let performanceScore = calculatePerformanceScore()
        
        // Determine target quality level
        let newTargetLevel = determineTargetQualityLevel(performanceScore: performanceScore)
        
        // Apply quality change if needed
        if newTargetLevel != targetQualityLevel {
            applyQualityChange(to: newTargetLevel, reason: "Performance score: \(String(format: "%.1f", performanceScore))")
        }
    }
    
    private func collectPerformanceMetrics() {
        let currentFrameRate = 30.0
        frameRateHistory.append(currentFrameRate)
        if frameRateHistory.count > maxHistorySamples {
            frameRateHistory.removeFirst()
        }
        
        let currentCpuUsage = getCurrentCPUUsage()
        cpuUsageHistory.append(currentCpuUsage)
        if cpuUsageHistory.count > maxHistorySamples {
            cpuUsageHistory.removeFirst()
        }
        
        let currentMemoryUsage = 0.0
        memoryUsageHistory.append(currentMemoryUsage)
        if memoryUsageHistory.count > maxHistorySamples {
            memoryUsageHistory.removeFirst()
        }
        
        // Get current thermal state
        let currentThermalState = ThermalManager.shared.getCurrentThermalState()
        thermalStateHistory.append(currentThermalState)
        if thermalStateHistory.count > maxHistorySamples {
            thermalStateHistory.removeFirst()
        }
    }
    
    private func calculatePerformanceScore() -> Double {
        var totalScore: Double = 0
        var componentCount: Double = 0
        
        // Frame rate score (0-100)
        if !frameRateHistory.isEmpty {
            let avgFrameRate = frameRateHistory.reduce(0, +) / Double(frameRateHistory.count)
            let targetFrameRate = currentQualityLevel.frameRate
            let frameRatePercentage = (avgFrameRate / targetFrameRate) * 100
            
            let frameRateScore: Double
            switch frameRatePercentage {
            case AdaptationThresholds.frameRateExcellent...:
                frameRateScore = 100
            case AdaptationThresholds.frameRateGood..<AdaptationThresholds.frameRateExcellent:
                frameRateScore = 80
            case AdaptationThresholds.frameRateFair..<AdaptationThresholds.frameRateGood:
                frameRateScore = 60
            case AdaptationThresholds.frameRatePoor..<AdaptationThresholds.frameRateFair:
                frameRateScore = 40
            default:
                frameRateScore = 20
            }
            
            totalScore += frameRateScore
            componentCount += 1
        }
        
        // CPU usage score (0-100)
        if !cpuUsageHistory.isEmpty {
            let avgCpuUsage = cpuUsageHistory.reduce(0, +) / Double(cpuUsageHistory.count)
            
            let cpuScore: Double
            switch avgCpuUsage {
            case 0..<AdaptationThresholds.cpuExcellent:
                cpuScore = 100
            case AdaptationThresholds.cpuExcellent..<AdaptationThresholds.cpuGood:
                cpuScore = 80
            case AdaptationThresholds.cpuGood..<AdaptationThresholds.cpuFair:
                cpuScore = 60
            case AdaptationThresholds.cpuFair..<AdaptationThresholds.cpuPoor:
                cpuScore = 40
            default:
                cpuScore = 20
            }
            
            totalScore += cpuScore
            componentCount += 1
        }
        
        // Memory usage score (0-100)
        if !memoryUsageHistory.isEmpty {
            let avgMemoryUsage = memoryUsageHistory.reduce(0, +) / Double(memoryUsageHistory.count)
            
            let memoryScore: Double
            switch avgMemoryUsage {
            case 0..<AdaptationThresholds.memoryExcellent:
                memoryScore = 100
            case AdaptationThresholds.memoryExcellent..<AdaptationThresholds.memoryGood:
                memoryScore = 80
            case AdaptationThresholds.memoryGood..<AdaptationThresholds.memoryFair:
                memoryScore = 60
            case AdaptationThresholds.memoryFair..<AdaptationThresholds.memoryPoor:
                memoryScore = 40
            default:
                memoryScore = 20
            }
            
            totalScore += memoryScore
            componentCount += 1
        }
        
        // Thermal state score (0-100)
        if !thermalStateHistory.isEmpty {
            let mostCommonThermalState = getMostCommonThermalState()
            
            let thermalScore: Double
            switch mostCommonThermalState {
            case AdaptationThresholds.thermalExcellent, AdaptationThresholds.thermalGood:
                thermalScore = 100
            case AdaptationThresholds.thermalFair:
                thermalScore = 70
            case AdaptationThresholds.thermalPoor:
                thermalScore = 40
            default:
                thermalScore = 20
            }
            
            totalScore += thermalScore
            componentCount += 1
        }
        
        return componentCount > 0 ? totalScore / componentCount : 50
    }
    
    private func getMostCommonThermalState() -> ProcessInfo.ThermalState {
        let stateCounts = thermalStateHistory.reduce(into: [:]) { counts, state in
            counts[state, default: 0] += 1
        }
        
        return stateCounts.max { $0.value < $1.value }?.key ?? .nominal
    }
    
    private func determineTargetQualityLevel(performanceScore: Double) -> QualityLevel {
        // Determine target quality based on performance score
        switch performanceScore {
        case 90...:
            return .ultraHigh
        case 75..<90:
            return .high
        case 60..<75:
            return .medium
        default:
            return .low
        }
    }
    
    private func applyQualityChange(to newLevel: QualityLevel, reason: String) {
        let currentTime = CACurrentMediaTime()
        
        // Apply cooldown to prevent rapid changes
        guard currentTime - lastAdaptationTime > adaptationCooldown else {
            logEvent("Adaptive Quality", "Quality change blocked by cooldown")
            return
        }
        
        let previousLevel = currentQualityLevel
        targetQualityLevel = newLevel
        lastAdaptationTime = currentTime
        
        // Apply the quality change
        currentQualityLevel = newLevel
        
        // Update settings
        SettingsManager.shared.videoQuality = newLevel.videoQuality
        
        // Log the change
        logEvent("Adaptive Quality", "Changed from \(previousLevel.description) to \(newLevel.description) - \(reason)")
        
        // Notify callbacks
        DispatchQueue.main.async {
            self.onQualityLevelChanged?(newLevel, reason)
        }
        
        // Schedule quality restoration if conditions improve
        scheduleQualityRestoration()
    }
    
    private func scheduleQualityRestoration() {
        // Cancel any existing restoration timer
        adaptationTimer?.invalidate()
        
        // Check for restoration after 10 seconds
        Timer.scheduledTimer(withTimeInterval: 10.0, repeats: false) { [weak self] _ in
            self?.checkForQualityRestoration()
        }
    }
    
    private func checkForQualityRestoration() {
        guard let originalLevel = originalQualityLevel else { return }
        
        // Only restore if current level is lower than original
        guard currentQualityLevel.rawValue < originalLevel.rawValue else { return }
        
        // Check if performance can support higher quality
        collectPerformanceMetrics()
        let performanceScore = calculatePerformanceScore()
        
        if performanceScore > 85 { // Excellent performance
            let previousLevel = currentQualityLevel
            currentQualityLevel = originalLevel
            targetQualityLevel = originalLevel
            
            // Update settings
            SettingsManager.shared.videoQuality = originalLevel.videoQuality
            
            logEvent("Adaptive Quality", "Restored to \(originalLevel.description) - Performance improved")
            
            // Notify callbacks
            DispatchQueue.main.async {
                self.onQualityRestored?(originalLevel)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func qualityLevelFromVideoQuality(_ videoQuality: VideoQuality) -> QualityLevel {
        switch videoQuality {
        case .uhd4k: return .ultraHigh
        case .hd1080: return .high
        case .hd720: return .medium
        }
    }
    
    private func getCurrentCPUUsage() -> Double {
        return 50.0
    }
    
    // MARK: - Public Interface
    
    func setAdaptiveQualityEnabled(_ enabled: Bool) {
        isAdaptiveQualityEnabled = enabled
        
        if enabled {
            startAdaptiveMonitoring()
            logEvent("Adaptive Quality", "Enabled adaptive quality")
        } else {
            adaptationTimer?.invalidate()
            logEvent("Adaptive Quality", "Disabled adaptive quality")
        }
    }
    
    func getCurrentQualityLevel() -> QualityLevel {
        return currentQualityLevel
    }
    
    func getTargetQualityLevel() -> QualityLevel {
        return targetQualityLevel
    }
    
    func setQualityLevel(_ level: QualityLevel, manual: Bool = false) {
        let previousLevel = currentQualityLevel
        currentQualityLevel = level
        targetQualityLevel = level
        
        if manual {
            originalQualityLevel = level
        }
        
        // Update settings
        SettingsManager.shared.videoQuality = level.videoQuality
        
        logEvent("Adaptive Quality", "Manually set to \(level.description)")
        
        // Notify callbacks
        DispatchQueue.main.async {
            self.onQualityLevelChanged?(level, manual ? "Manual change" : "System change")
        }
    }
    
    func getPerformanceMetrics() -> [String: Any] {
        let avgFrameRate = frameRateHistory.isEmpty ? 0 : frameRateHistory.reduce(0, +) / Double(frameRateHistory.count)
        let avgCpuUsage = cpuUsageHistory.isEmpty ? 0 : cpuUsageHistory.reduce(0, +) / Double(cpuUsageHistory.count)
        let avgMemoryUsage = memoryUsageHistory.isEmpty ? 0 : memoryUsageHistory.reduce(0, +) / Double(memoryUsageHistory.count)
        let performanceScore = calculatePerformanceScore()
        
        return [
            "currentQualityLevel": currentQualityLevel.rawValue,
            "targetQualityLevel": targetQualityLevel.rawValue,
            "averageFrameRate": avgFrameRate,
            "averageCpuUsage": avgCpuUsage,
            "averageMemoryUsage": avgMemoryUsage,
            "performanceScore": performanceScore,
            "isAdaptiveEnabled": isAdaptiveQualityEnabled
        ]
    }
    
    func resetAdaptiveQuality() {
        // Reset to original quality
        if let originalLevel = originalQualityLevel {
            setQualityLevel(originalLevel, manual: false)
        }
        
        // Clear history
        frameRateHistory.removeAll()
        cpuUsageHistory.removeAll()
        memoryUsageHistory.removeAll()
        thermalStateHistory.removeAll()
        
        logEvent("Adaptive Quality", "Reset adaptive quality system")
    }
    
    // MARK: - Frame Rate Stabilization
    
    func stabilizeFrameRate() -> Double {
        guard !frameRateHistory.isEmpty else { return currentQualityLevel.frameRate }
        
        let avgFrameRate = frameRateHistory.reduce(0, +) / Double(frameRateHistory.count)
        let targetFrameRate = currentQualityLevel.frameRate
        let frameRateVariance = frameRateHistory.map { abs($0 - avgFrameRate) }.reduce(0, +) / Double(frameRateHistory.count)
        
        // If frame rate is unstable, reduce target
        if frameRateVariance > 5.0 { // High variance
            return max(24, targetFrameRate - 6)
        } else if frameRateVariance > 2.0 { // Medium variance
            return max(24, targetFrameRate - 3)
        }
        
        return targetFrameRate
    }
    
    private func logEvent(_ name: StaticString, _ message: String = "") {
        os_signpost(.event, log: log, name: name, "%{public}s", message)
    }
    
    deinit {
        adaptationTimer?.invalidate()
    }
}