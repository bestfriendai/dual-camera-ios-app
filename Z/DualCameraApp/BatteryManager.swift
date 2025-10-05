//
//  BatteryManager.swift
//  DualApp
//
//  Created by DualApp Team on 10/3/25.
//

import Foundation
import SwiftUI
import UIKit

// MARK: - Battery Manager Actor

actor BatteryManager: Sendable {
    // MARK: - Singleton

    static let shared = BatteryManager()

    // MARK: - State Properties
    
    private(set) var currentBatteryLevel: Double = 1.0
    private(set) var batteryState: UIDevice.BatteryState = .unknown
    private(set) var powerSourceState: PowerSourceState = .unknown
    private(set) var thermalState: ThermalState = .unknown
    
    // MARK: - Battery-Aware Configuration
    
    private var batteryOptimizationEnabled: Bool = true
    private var lowPowerModeThreshold: Double = 0.2
    private var criticalBatteryThreshold: Double = 0.1
    private var performanceProfile: BatteryPerformanceProfile = .balanced
    
    // MARK: - Event Stream
    
    let events: AsyncStream<BatteryEvent>
    private let eventContinuation: AsyncStream<BatteryEvent>.Continuation
    
    // MARK: - Monitoring
    
    private var monitoringTask: Task<Void, Never>?
    private let monitoringInterval: TimeInterval = 5.0
    private var batteryHistory: [LegacyBatterySnapshot] = []
    private let maxHistorySize = 200
    
    // MARK: - Initialization
    
    init() {
        (self.events, self.eventContinuation) = AsyncStream<BatteryEvent>.makeStream()
        
        Task {
            await setupBatteryMonitoring()
            await startMonitoring()
        }
    }
    
    // MARK: - Public Interface
    
    func startMonitoring() async {
        stopMonitoring()
        
        monitoringTask = Task {
            while !Task.isCancelled {
                await updateBatteryStatus()
                try? await Task.sleep(nanoseconds: UInt64(monitoringInterval * 1_000_000_000))
            }
        }
    }
    
    func stopMonitoring() async {
        monitoringTask?.cancel()
        monitoringTask = nil
    }
    
    func setBatteryOptimizationEnabled(_ enabled: Bool) async {
        batteryOptimizationEnabled = enabled
        eventContinuation.yield(.optimizationChanged(enabled))
        
        if enabled {
            await applyBatteryOptimizations()
        }
    }
    
    func setLowPowerModeThreshold(_ threshold: Double) async {
        lowPowerModeThreshold = max(0.05, min(0.5, threshold))
        eventContinuation.yield(.thresholdChanged(lowPowerModeThreshold))
    }
    
    func setPerformanceProfile(_ profile: BatteryPerformanceProfile) async {
        performanceProfile = profile
        await applyPerformanceProfile()
        eventContinuation.yield(.performanceProfileChanged(profile))
    }
    
    func getBatteryPrediction(for timeInterval: TimeInterval) async -> BatteryPrediction {
        return BatteryPredictionEngine.predict(
            for: timeInterval,
            history: batteryHistory,
            currentLevel: currentBatteryLevel,
            currentState: batteryState
        )
    }
    
    func getOptimalRecordingDuration() async -> TimeInterval {
        guard batteryOptimizationEnabled else {
            return .infinity // No limit if optimization is disabled
        }
        
        let prediction = await getBatteryPrediction(for: 3600) // 1 hour prediction
        let safeMargin = 0.1 // 10% safety margin
        
        switch performanceProfile {
        case .powerSaver:
            return min(300, prediction.estimatedTimeUntilEmpty * (1 - safeMargin))
        case .balanced:
            return min(1800, prediction.estimatedTimeUntilEmpty * (1 - safeMargin))
        case .performance:
            return min(3600, prediction.estimatedTimeUntilEmpty * (1 - safeMargin))
        }
    }
    
    func shouldLimitPerformance() async -> Bool {
        switch performanceProfile {
        case .powerSaver:
            return true
        case .balanced:
            return currentBatteryLevel < lowPowerModeThreshold || batteryState == .unplugged
        case .performance:
            return currentBatteryLevel < criticalBatteryThreshold
        }
    }
    
    func getRecommendedQuality() async -> VideoQuality {
        guard batteryOptimizationEnabled else {
            return .uhd4k // Maximum quality when optimization is disabled
        }
        
        switch (currentBatteryLevel, batteryState, performanceProfile) {
        case (0..<criticalBatteryThreshold, _, _),
             (_, .unplugged, .powerSaver):
            return .hd720
        case (criticalBatteryThreshold..<lowPowerModeThreshold, .unplugged, _),
             (_, .unplugged, .balanced):
            return .hd1080
        default:
            return .uhd4k
        }
    }
    
    // MARK: - Private Methods
    
    private func setupBatteryMonitoring() async {
        UIDevice.current.isBatteryMonitoringEnabled = true
        
        // Register for battery level change notifications
        NotificationCenter.default.addObserver(
            forName: UIDevice.batteryLevelDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.updateBatteryStatus()
            }
        }
        
        // Register for battery state change notifications
        NotificationCenter.default.addObserver(
            forName: UIDevice.batteryStateDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.updateBatteryStatus()
            }
        }
    }
    
    private func updateBatteryStatus() async {
        let previousLevel = currentBatteryLevel
        let previousState = batteryState
        
        // Update current values
        currentBatteryLevel = UIDevice.current.batteryLevel
        batteryState = UIDevice.current.batteryState
        powerSourceState = determinePowerSourceState()
        thermalState = await ThermalManager.shared.currentThermalState
        
        // Create snapshot
        let snapshot = BatterySnapshot(
            timestamp: Date(),
            level: currentBatteryLevel,
            state: batteryState,
            powerSource: powerSourceState,
            thermalState: thermalState
        )
        
        // Add to history
        batteryHistory.append(snapshot)
        if batteryHistory.count > maxHistorySize {
            batteryHistory.removeFirst()
        }
        
        // Check for significant changes
        if abs(currentBatteryLevel - previousLevel) > 0.01 {
            eventContinuation.yield(.levelChanged(currentBatteryLevel))
        }
        
        if batteryState != previousState {
            eventContinuation.yield(.stateChanged(batteryState))
            await handleBatteryStateChange()
        }
        
        // Check for low battery warnings
        await checkBatteryWarnings()
        
        // Apply optimizations if needed
        if batteryOptimizationEnabled {
            await applyBatteryOptimizations()
        }
        
        // Emit status update
        eventContinuation.yield(.statusUpdated(snapshot))
    }
    
    private func determinePowerSourceState() -> PowerSourceState {
        switch batteryState {
        case .charging:
            return .charging
        case .full:
            return .full
        case .unplugged:
            return .battery
        case .unknown:
            return .unknown
        @unknown default:
            return .unknown
        }
    }
    
    private func handleBatteryStateChange() async {
        switch batteryState {
        case .unplugged:
            // Device switched to battery power
            eventContinuation.yield(.powerSourceChanged(.battery))
            await applyBatteryOptimizations()
            
        case .charging:
            // Device started charging
            eventContinuation.yield(.powerSourceChanged(.charging))
            
        case .full:
            // Device fully charged
            eventContinuation.yield(.powerSourceChanged(.full))
            
        default:
            break
        }
    }
    
    private func checkBatteryWarnings() async {
        if currentBatteryLevel <= criticalBatteryThreshold {
            eventContinuation.yield(.criticalBatteryLevel(currentBatteryLevel))
            await applyCriticalBatteryMeasures()
        } else if currentBatteryLevel <= lowPowerModeThreshold {
            eventContinuation.yield(.lowBatteryLevel(currentBatteryLevel))
            await applyLowPowerMeasures()
        }
    }
    
    private func applyBatteryOptimizations() async {
        let shouldLimit = await shouldLimitPerformance()
        
        if shouldLimit {
            // Apply performance limitations
            await limitPerformance()
        } else {
            // Restore normal performance
            await restorePerformance()
        }
    }
    
    private func applyPerformanceProfile() async {
        switch performanceProfile {
        case .powerSaver:
            await applyPowerSaverMode()
        case .balanced:
            await applyBalancedMode()
        case .performance:
            await applyPerformanceMode()
        }
    }
    
    private func applyPowerSaverMode() async {
        // Reduce frame rates
        // Lower video quality
        // Disable background processing
        // Reduce animation complexity
        
        eventContinuation.yield(.optimizationApplied(.powerSaver))
    }
    
    private func applyBalancedMode() async {
        // Moderate performance settings
        // Adaptive quality based on battery level
        
        eventContinuation.yield(.optimizationApplied(.balanced))
    }
    
    private func applyPerformanceMode() async {
        // Maximum performance settings
        // High quality recording
        // Full feature set enabled
        
        eventContinuation.yield(.optimizationApplied(.performance))
    }
    
    private func applyLowPowerMeasures() async {
        // Reduce recording quality
        // Limit recording duration
        // Disable non-essential features
        
        eventContinuation.yield(.lowPowerModeActivated)
    }
    
    private func applyCriticalBatteryMeasures() async {
        // Stop recording if active
        // Force low power mode
        // Disable camera features
        
        eventContinuation.yield(.criticalBatteryModeActivated)
    }
    
    private func limitPerformance() async {
        // Reduce CPU usage
        // Lower frame rates
        // Simplify UI animations
    }
    
    private func restorePerformance() async {
        // Restore normal performance levels
    }
    
    deinit {
        Task { [weak self] in
            await self?.stopMonitoring()
        }
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - Battery Event

enum BatteryEvent: Sendable {
    case statusUpdated(BatterySnapshot)
    case levelChanged(Double)
    case stateChanged(UIDevice.BatteryState)
    case powerSourceChanged(PowerSourceState)
    case lowBatteryLevel(Double)
    case criticalBatteryLevel(Double)
    case optimizationChanged(Bool)
    case thresholdChanged(Double)
    case performanceProfileChanged(BatteryPerformanceProfile)
    case optimizationApplied(BatteryPerformanceProfile)
    case lowPowerModeActivated
    case criticalBatteryModeActivated
}

// MARK: - Battery Snapshot

struct LegacyBatterySnapshot: Sendable {
    let timestamp: Date
    let level: Double
    let state: UIDevice.BatteryState
    let powerSource: PowerSourceState
    let thermalState: ThermalState
    
    var formattedLevel: String {
        return String(format: "%.0f%%", level * 100)
    }
    
    var isCharging: Bool {
        return state == .charging || state == .full
    }
    
    var isLowBattery: Bool {
        return level < 0.2 && !isCharging
    }
    
    var isCriticalBattery: Bool {
        return level < 0.1 && !isCharging
    }
}

// MARK: - Power Source State

enum PowerSourceState: Sendable {
    case battery
    case charging
    case full
    case unknown
    
    var description: String {
        switch self {
        case .battery:
            return "Battery Power"
        case .charging:
            return "Charging"
        case .full:
            return "Fully Charged"
        case .unknown:
            return "Unknown"
        }
    }
}

// MARK: - Battery Performance Profile

enum BatteryPerformanceProfile: String, CaseIterable, Sendable {
    case powerSaver = "Power Saver"
    case balanced = "Balanced"
    case performance = "Performance"
    
    var description: String {
        switch self {
        case .powerSaver:
            return "Maximize battery life with reduced performance"
        case .balanced:
            return "Balance performance and battery usage"
        case .performance:
            return "Maximum performance with higher battery usage"
        }
    }
    
    var icon: String {
        switch self {
        case .powerSaver:
            return "leaf.fill"
        case .balanced:
            return "balance.scale"
        case .performance:
            return "bolt.fill"
        }
    }
}

// MARK: - Battery Prediction Engine

struct BatteryPredictionEngine {
    static func predict(
        for timeInterval: TimeInterval,
        history: [BatterySnapshot],
        currentLevel: Double,
        currentState: UIDevice.BatteryState
    ) -> BatteryPrediction {
        
        guard !history.isEmpty else {
            return BatteryPrediction(
                estimatedLevel: currentLevel,
                estimatedTimeUntilEmpty: .infinity,
                confidence: 0
            )
        }
        
        // Calculate drain rate based on history
        let drainRate = calculateDrainRate(from: history, currentState: currentState)
        
        // Predict future level
        let predictedLevel = max(0, currentLevel - (drainRate * timeInterval / 3600))
        
        // Calculate time until empty
        let timeUntilEmpty = currentLevel > 0 && drainRate > 0 ? (currentLevel / drainRate) * 3600 : .infinity
        
        // Calculate confidence based on data consistency
        let confidence = calculateConfidence(from: history)
        
        return BatteryPrediction(
            estimatedLevel: predictedLevel,
            estimatedTimeUntilEmpty: timeUntilEmpty,
            confidence: confidence
        )
    }
    
    private static func calculateDrainRate(from history: [BatterySnapshot], currentState: UIDevice.BatteryState) -> Double {
        guard history.count >= 2 else { return 0 }
        
        let recentHistory = Array(history.suffix(20)) // Last 20 snapshots
        var totalDrainRate: Double = 0
        var validSamples = 0
        
        for i in 1..<recentHistory.count {
            let previous = recentHistory[i-1]
            let current = recentHistory[i]
            
            // Only calculate drain when not charging
            if current.state != .charging && current.state != .full {
                let timeDiff = current.timestamp.timeIntervalSince(previous.timestamp)
                let levelDiff = previous.level - current.level
                
                if timeDiff > 0 && levelDiff > 0 {
                    let hourlyDrainRate = (levelDiff / timeDiff) * 3600
                    totalDrainRate += hourlyDrainRate
                    validSamples += 1
                }
            }
        }
        
        return validSamples > 0 ? totalDrainRate / Double(validSamples) : 0
    }
    
    private static func calculateConfidence(from history: [BatterySnapshot]) -> Double {
        guard history.count >= 3 else { return 0 }
        
        let recentHistory = Array(history.suffix(10))
        let levels = recentHistory.map { $0.level }
        
        // Calculate variance in battery levels
        let mean = levels.reduce(0, +) / Double(levels.count)
        let variance = levels.map { pow($0 - mean, 2) }.reduce(0, +) / Double(levels.count)
        
        // Lower variance = higher confidence
        return max(0, 1 - variance * 10)
    }
}

// MARK: - Battery Prediction

struct BatteryPrediction: Sendable {
    let estimatedLevel: Double
    let estimatedTimeUntilEmpty: TimeInterval
    let confidence: Double
    
    var formattedTimeUntilEmpty: String {
        if estimatedTimeUntilEmpty == .infinity {
            return "∞"
        }
        
        let hours = Int(estimatedTimeUntilEmpty) / 3600
        let minutes = (Int(estimatedTimeUntilEmpty) % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    var riskLevel: BatteryRiskLevel {
        switch estimatedLevel {
        case 0.3...:
            return .low
        case 0.1..<0.3:
            return .medium
        default:
            return .high
        }
    }
}

// MARK: - Battery Risk Level

enum BatteryRiskLevel: Sendable {
    case low
    case medium
    case high
}

// MARK: - Thermal State

enum BatteryThermalState: Sendable {
    case unknown
    case nominal
    case fair
    case serious
    case critical
    
    init(from processInfoThermalState: ProcessInfo.ThermalState) {
        switch processInfoThermalState {
        case .nominal:
            self = .nominal
        case .fair:
            self = .fair
        case .serious:
            self = .serious
        case .critical:
            self = .critical
        @unknown default:
            self = .unknown
        }
    }
}