//
//  DualCameraPerformanceMonitor.swift
//  DualApp
//
//  Created by DualApp Team on 10/3/25.
//

import Foundation
import AVFoundation
import CoreMedia
import UIKit

// MARK: - Supporting Types
struct MemorySnapshot: Sendable {
    let timestamp: Date
    let usedMemory: UInt64
    let availableMemory: UInt64
    let memoryPressure: Double
}

struct ThermalSnapshot: Sendable {
    let timestamp: Date
    let thermalState: ProcessInfo.ThermalState
    let thermalPressure: Double
}

struct BatterySnapshot: Sendable {
    let timestamp: Date
    let level: Double
    let state: UIDevice.BatteryState
    let powerSource: PowerSource

    enum PowerSource: Sendable {
        case battery
        case external
        case unknown
    }
}

typealias ThermalState = ProcessInfo.ThermalState
typealias ThermalPressure = Double

// MARK: - Dual Camera Performance Monitor

actor DualCameraPerformanceMonitor {
    
    // MARK: - Properties
    
    private var isMonitoring: Bool = false
    private var monitoringInterval: TimeInterval = 1.0
    private var monitoringTask: Task<Void, Never>?
    
    // MARK: - Performance Metrics
    
    private var currentMetrics: DualCameraPerformanceMetrics = DualCameraPerformanceMetrics()
    private var metricsHistory: [DualCameraPerformanceMetrics] = []
    private let maxHistorySize: Int = 300 // 5 minutes at 1-second intervals
    
    // MARK: - Frame Rate Monitoring
    
    private var frontFrameCount: Int = 0
    private var backFrameCount: Int = 0
    private var lastFrameRateUpdate: Date = Date()
    private var targetFrameRate: Double = 30.0
    
    // MARK: - Memory Monitoring
    
    private var memoryUsageHistory: [MemorySnapshot] = []
    private var lastMemoryCheck: Date = Date()
    
    // MARK: - Thermal Monitoring
    
    private var thermalHistory: [ThermalSnapshot] = []
    private var lastThermalCheck: Date = Date()
    
    // MARK: - Battery Monitoring
    
    private var batteryHistory: [BatterySnapshot] = []
    private var lastBatteryCheck: Date = Date()
    
    // MARK: - Event Stream
    
    let events: AsyncStream<PerformanceEvent>
    private let eventContinuation: AsyncStream<PerformanceEvent>.Continuation
    
    // MARK: - Performance Thresholds
    
    private var performanceThresholds: PerformanceThresholds = PerformanceThresholds()
    
    // MARK: - Initialization
    
    init() {
        (self.events, self.eventContinuation) = AsyncStream<PerformanceEvent>.makeStream()
    }
    
    // MARK: - Public Interface
    
    func startMonitoring() async {
        guard !isMonitoring else { return }
        
        isMonitoring = true
        lastFrameRateUpdate = Date()
        lastMemoryCheck = Date()
        lastThermalCheck = Date()
        lastBatteryCheck = Date()
        
        // Start monitoring task
        monitoringTask = Task {
            await monitoringLoop()
        }
        
        eventContinuation.yield(.monitoringStarted)
    }
    
    func stopMonitoring() async {
        isMonitoring = false
        monitoringTask?.cancel()
        monitoringTask = nil
        
        eventContinuation.yield(.monitoringStopped)
    }
    
    func recordFrame(_ frame: DualCameraFrame) async {
        guard isMonitoring else { return }
        
        switch frame.position {
        case .front:
            frontFrameCount += 1
        case .back:
            backFrameCount += 1
        default:
            break
        }
        
        // Update frame processing time
        let processingTime = Date().timeIntervalSince(frame.timestamp)
        currentMetrics.averageFrameProcessingTime = (currentMetrics.averageFrameProcessingTime + processingTime) / 2
    }
    
    func setTargetFrameRate(_ frameRate: Double) async {
        targetFrameRate = frameRate
        currentMetrics.targetFrameRate = frameRate
        eventContinuation.yield(.targetFrameRateChanged(frameRate))
    }
    
    func setPerformanceThresholds(_ thresholds: PerformanceThresholds) async {
        performanceThresholds = thresholds
        eventContinuation.yield(.thresholdsUpdated(thresholds))
    }
    
    func getCurrentMetrics() async -> DualCameraPerformanceMetrics {
        return currentMetrics
    }
    
    func getMetricsHistory() async -> [DualCameraPerformanceMetrics] {
        return metricsHistory
    }
    
    func getPerformanceRecommendation() async -> PerformanceRecommendation {
        return PerformanceRecommendationEngine.generateRecommendation(
            currentMetrics: currentMetrics,
            history: metricsHistory,
            thresholds: performanceThresholds
        )
    }
    
    // MARK: - Private Methods
    
    private func monitoringLoop() async {
        while isMonitoring && !Task.isCancelled {
            await updatePerformanceMetrics()
            await checkPerformanceThresholds()
            await saveMetricsToHistory()
            
            try? await Task.sleep(nanoseconds: UInt64(monitoringInterval * 1_000_000_000))
        }
    }
    
    private func updatePerformanceMetrics() async {
        let currentTime = Date()
        
        // Update frame rates
        await updateFrameRates(currentTime: currentTime)
        
        // Update memory usage
        await updateMemoryUsage(currentTime: currentTime)
        
        // Update thermal state
        await updateThermalState(currentTime: currentTime)
        
        // Update battery state
        await updateBatteryState(currentTime: currentTime)
        
        // Update timestamp
        currentMetrics.timestamp = currentTime
        
        // Calculate overall performance score
        currentMetrics.overallPerformanceScore = calculateOverallPerformanceScore()
    }
    
    private func updateFrameRates(currentTime: Date) async {
        let timeInterval = currentTime.timeIntervalSince(lastFrameRateUpdate)
        
        if timeInterval >= 1.0 {
            // Calculate frame rates
            let frontFrameRate = Double(frontFrameCount) / timeInterval
            let backFrameRate = Double(backFrameCount) / timeInterval
            
            currentMetrics.frontFrameRate = frontFrameRate
            currentMetrics.backFrameRate = backFrameRate
            currentMetrics.averageFrameRate = (frontFrameRate + backFrameRate) / 2
            
            // Calculate frame rate efficiency
            let targetRate = targetFrameRate
            currentMetrics.frameRateEfficiency = min(1.0, currentMetrics.averageFrameRate / targetRate)
            
            // Reset counters
            frontFrameCount = 0
            backFrameCount = 0
            lastFrameRateUpdate = currentTime
        }
    }
    
    private func updateMemoryUsage(currentTime: Date) async {
        let timeInterval = currentTime.timeIntervalSince(lastMemoryCheck)
        
        if timeInterval >= 5.0 { // Check every 5 seconds
            let memorySnapshot = await captureMemorySnapshot()
            memoryUsageHistory.append(memorySnapshot)
            
            if memoryUsageHistory.count > 60 { // Keep 5 minutes of history
                memoryUsageHistory.removeFirst()
            }
            
            currentMetrics.memoryUsage = Double(memorySnapshot.usedMemory) / Double(memorySnapshot.usedMemory + memorySnapshot.availableMemory)
            // Convert Double to MemoryPressure enum
            let pressureValue = memorySnapshot.memoryPressure
            if pressureValue > 0.8 {
                currentMetrics.memoryPressure = .critical
            } else if pressureValue > 0.6 {
                currentMetrics.memoryPressure = .warning
            } else {
                currentMetrics.memoryPressure = .normal
            }
            
            lastMemoryCheck = currentTime
        }
    }
    
    private func updateThermalState(currentTime: Date) async {
        let timeInterval = currentTime.timeIntervalSince(lastThermalCheck)
        
        if timeInterval >= 2.0 { // Check every 2 seconds
            let thermalState = await ThermalManager.shared.currentThermalState
            let thermalMetrics = await ThermalManager.shared.getCurrentThermalMetrics()

            let snapshot = ThermalSnapshot(
                timestamp: currentTime,
                thermalState: thermalState.processInfoThermalState,
                thermalPressure: thermalMetrics.pressure.doubleValue
            )
            
            thermalHistory.append(snapshot)
            if thermalHistory.count > 150 { // Keep 5 minutes of history
                thermalHistory.removeFirst()
            }
            
            currentMetrics.thermalState = thermalState.processInfoThermalState
            currentMetrics.thermalPressure = thermalMetrics.pressure.doubleValue
            
            lastThermalCheck = currentTime
        }
    }
    
    private func updateBatteryState(currentTime: Date) async {
        let timeInterval = currentTime.timeIntervalSince(lastBatteryCheck)
        
        if timeInterval >= 5.0 { // Check every 5 seconds
            let batteryLevel = await BatteryManager.shared.currentBatteryLevel
            let batteryState = await BatteryManager.shared.currentBatteryLevel
            
            let snapshot = BatterySnapshot(
                timestamp: currentTime,
                level: Double(batteryLevel),
                state: UIDevice.BatteryState.unplugged, // Would get actual state
                powerSource: .battery
            )
            
            batteryHistory.append(snapshot)
            if batteryHistory.count > 60 { // Keep 5 minutes of history
                batteryHistory.removeFirst()
            }
            
            currentMetrics.batteryLevel = Double(batteryLevel)
            currentMetrics.batteryState = UIDevice.BatteryState.unplugged // Would get actual state
            
            lastBatteryCheck = currentTime
        }
    }
    
    private func checkPerformanceThresholds() async {
        var warnings: [String] = []
        var criticalIssues: [String] = []
        
        // Check frame rate
        if currentMetrics.frameRateEfficiency < performanceThresholds.minFrameRateEfficiency {
            if currentMetrics.frameRateEfficiency < performanceThresholds.criticalFrameRateEfficiency {
                criticalIssues.append("Frame rate too low: \(String(format: "%.1f", currentMetrics.averageFrameRate)) fps")
            } else {
                warnings.append("Frame rate below optimal: \(String(format: "%.1f", currentMetrics.averageFrameRate)) fps")
            }
        }
        
        // Check memory usage
        if currentMetrics.memoryUsage > performanceThresholds.maxMemoryUsage {
            if currentMetrics.memoryUsage > performanceThresholds.criticalMemoryUsage {
                criticalIssues.append("Memory usage critical: \(String(format: "%.1f", currentMetrics.memoryUsage * 100))%")
            } else {
                warnings.append("Memory usage high: \(String(format: "%.1f", currentMetrics.memoryUsage * 100))%")
            }
        }
        
        // Check thermal state
        if currentMetrics.thermalState.rawValue >= ThermalState.serious.rawValue {
            if currentMetrics.thermalState.rawValue >= ThermalState.critical.rawValue {
                criticalIssues.append("Thermal state critical: \(currentMetrics.thermalState)")
            } else {
                warnings.append("Thermal state elevated: \(currentMetrics.thermalState)")
            }
        }
        
        // Check battery level
        if currentMetrics.batteryLevel < performanceThresholds.minBatteryLevel {
            if currentMetrics.batteryLevel < performanceThresholds.criticalBatteryLevel {
                criticalIssues.append("Battery level critical: \(String(format: "%.0f", currentMetrics.batteryLevel * 100))%")
            } else {
                warnings.append("Battery level low: \(String(format: "%.0f", currentMetrics.batteryLevel * 100))%")
            }
        }
        
        // Emit events
        for warning in warnings {
            eventContinuation.yield(.performanceWarning(warning))
        }
        
        for issue in criticalIssues {
            eventContinuation.yield(.performanceCritical(issue))
        }
        
        // Update performance status
        if !criticalIssues.isEmpty {
            currentMetrics.performanceStatus = .critical
        } else if !warnings.isEmpty {
            currentMetrics.performanceStatus = .warning
        } else {
            currentMetrics.performanceStatus = .optimal
        }
    }
    
    private func saveMetricsToHistory() async {
        metricsHistory.append(currentMetrics)
        
        if metricsHistory.count > maxHistorySize {
            metricsHistory.removeFirst()
        }
    }
    
    private func calculateOverallPerformanceScore() -> Double {
        var score = 1.0
        
        // Frame rate contribution (40%)
        score *= (0.4 + 0.6 * currentMetrics.frameRateEfficiency)
        
        // Memory usage contribution (20%)
        let memoryScore = max(0, 1 - currentMetrics.memoryUsage)
        score *= (0.8 + 0.2 * memoryScore)
        
        // Thermal state contribution (20%)
        let thermalScore = max(0, 1 - Double(currentMetrics.thermalState.rawValue) / 4.0)
        score *= (0.8 + 0.2 * thermalScore)
        
        // Battery level contribution (20%)
        score *= (0.8 + 0.2 * currentMetrics.batteryLevel)
        
        return max(0, min(1, score))
    }
    
    private func captureMemorySnapshot() async -> MemorySnapshot {
        // This would capture actual memory usage
        return MemorySnapshot(
            timestamp: Date(),
            usedMemory: 100_000_000, // Example value
            availableMemory: 400_000_000, // Example value
            memoryPressure: 0.0
        )
    }
}

// MARK: - Supporting Types

enum PerformanceEvent: Sendable {
    case monitoringStarted
    case monitoringStopped
    case targetFrameRateChanged(Double)
    case thresholdsUpdated(PerformanceThresholds)
    case performanceWarning(String)
    case performanceCritical(String)
    case metricsUpdated(DualCameraPerformanceMetrics)
}

struct DualCameraPerformanceMetrics: Sendable {
    var timestamp: Date = Date()
    var frontFrameRate: Double = 0
    var backFrameRate: Double = 0
    var averageFrameRate: Double = 0
    var targetFrameRate: Double = 30.0
    var frameRateEfficiency: Double = 1.0
    var averageFrameProcessingTime: TimeInterval = 0
    var memoryUsage: Double = 0
    var memoryPressure: MemoryPressure = .normal
    var thermalState: ThermalState = .nominal
    var thermalPressure: ThermalPressure = 0.0
    var batteryLevel: Double = 1.0
    var batteryState: UIDevice.BatteryState = .unplugged
    var overallPerformanceScore: Double = 1.0
    var performanceStatus: PerformanceStatus = .optimal
    
    var formattedAverageFrameRate: String {
        return String(format: "%.1f fps", averageFrameRate)
    }
    
    var formattedMemoryUsage: String {
        return String(format: "%.1f%%", memoryUsage * 100)
    }
    
    var formattedBatteryLevel: String {
        return String(format: "%.0f%%", batteryLevel * 100)
    }
    
    var formattedPerformanceScore: String {
        return String(format: "%.1f", overallPerformanceScore * 100)
    }
}

enum PerformanceStatus: String, Sendable {
    case optimal = "Optimal"
    case warning = "Warning"
    case critical = "Critical"
    
    var color: String {
        switch self {
        case .optimal:
            return "green"
        case .warning:
            return "yellow"
        case .critical:
            return "red"
        }
    }
}

struct PerformanceThresholds: Sendable {
    var minFrameRateEfficiency: Double = 0.8
    var criticalFrameRateEfficiency: Double = 0.5
    var maxMemoryUsage: Double = 0.8
    var criticalMemoryUsage: Double = 0.9
    var minBatteryLevel: Double = 0.2
    var criticalBatteryLevel: Double = 0.1
    var maxFrameProcessingTime: TimeInterval = 0.033 // 33ms for 30fps
    var criticalFrameProcessingTime: TimeInterval = 0.050 // 50ms
    
    static let `default` = PerformanceThresholds()
    
    static let aggressive = PerformanceThresholds(
        minFrameRateEfficiency: 0.9,
        criticalFrameRateEfficiency: 0.7,
        maxMemoryUsage: 0.6,
        criticalMemoryUsage: 0.8,
        minBatteryLevel: 0.3,
        criticalBatteryLevel: 0.15
    )
    
    static let lenient = PerformanceThresholds(
        minFrameRateEfficiency: 0.6,
        criticalFrameRateEfficiency: 0.3,
        maxMemoryUsage: 0.9,
        criticalMemoryUsage: 0.95,
        minBatteryLevel: 0.1,
        criticalBatteryLevel: 0.05
    )
}

struct PerformanceRecommendation: Sendable {
    let priority: RecommendationPriority
    let message: String
    let suggestedActions: [String]
    let estimatedImpact: String
    
    enum RecommendationPriority: String, Sendable, Comparable {
        case low = "Low"
        case medium = "Medium"
        case high = "High"
        case critical = "Critical"
        
        var color: String {
            switch self {
            case .low:
                return "blue"
            case .medium:
                return "yellow"
            case .high:
                return "orange"
            case .critical:
                return "red"
            }
        }

        static func < (lhs: RecommendationPriority, rhs: RecommendationPriority) -> Bool {
            let order: [RecommendationPriority] = [.low, .medium, .high, .critical]
            guard let lhsIndex = order.firstIndex(of: lhs),
                  let rhsIndex = order.firstIndex(of: rhs) else {
                return false
            }
            return lhsIndex < rhsIndex
        }
    }
}

struct PerformanceRecommendationEngine {
    static func generateRecommendation(
        currentMetrics: DualCameraPerformanceMetrics,
        history: [DualCameraPerformanceMetrics],
        thresholds: PerformanceThresholds
    ) -> PerformanceRecommendation {
        
        var priority: PerformanceRecommendation.RecommendationPriority = .low
        var message = "Performance is optimal"
        var suggestedActions: [String] = []
        var estimatedImpact = "No impact"
        
        // Analyze frame rate
        if currentMetrics.frameRateEfficiency < thresholds.criticalFrameRateEfficiency {
            priority = .critical
            message = "Frame rate is critically low"
            suggestedActions = [
                "Reduce video quality",
                "Disable one camera",
                "Close other apps",
                "Restart recording"
            ]
            estimatedImpact = "Significant improvement in smoothness"
        } else if currentMetrics.frameRateEfficiency < thresholds.minFrameRateEfficiency {
            priority = .high
            message = "Frame rate is below optimal"
            suggestedActions = [
                "Reduce video quality",
                "Disable non-essential features"
            ]
            estimatedImpact = "Improved recording smoothness"
        }
        
        // Analyze memory usage
        if currentMetrics.memoryUsage > thresholds.criticalMemoryUsage {
            priority = max(priority, .critical)
            message = "Memory usage is critically high"
            suggestedActions.append("Restart app")
            estimatedImpact = "Prevent app crashes"
        } else if currentMetrics.memoryUsage > thresholds.maxMemoryUsage {
            priority = max(priority, .medium)
            if message == "Performance is optimal" {
                message = "Memory usage is high"
            }
            suggestedActions.append("Clear cache")
            estimatedImpact = "Improved stability"
        }
        
        // Analyze thermal state
        if currentMetrics.thermalState == .critical {
            priority = max(priority, .critical)
            message = "Device is overheating"
            suggestedActions = [
                "Stop recording",
                "Let device cool down",
                "Move to cooler environment"
            ]
            estimatedImpact = "Prevent thermal throttling and damage"
        } else if currentMetrics.thermalState == .serious {
            priority = max(priority, .high)
            if message == "Performance is optimal" {
                message = "Device is getting hot"
            }
            suggestedActions.append("Reduce recording quality")
            estimatedImpact = "Reduce thermal stress"
        }
        
        // Analyze battery level
        if currentMetrics.batteryLevel < thresholds.criticalBatteryLevel {
            priority = max(priority, .critical)
            message = "Battery level is critically low"
            suggestedActions = [
                "Connect charger",
                "Stop recording",
                "Enable low power mode"
            ]
            estimatedImpact = "Prevent unexpected shutdown"
        } else if currentMetrics.batteryLevel < thresholds.minBatteryLevel {
            priority = max(priority, .medium)
            if message == "Performance is optimal" {
                message = "Battery level is low"
            }
            suggestedActions.append("Connect charger")
            estimatedImpact = "Extend recording time"
        }
        
        return PerformanceRecommendation(
            priority: priority,
            message: message,
            suggestedActions: suggestedActions,
            estimatedImpact: estimatedImpact
        )
    }
}