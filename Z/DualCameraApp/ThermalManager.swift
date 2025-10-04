//
//  ThermalManager.swift
//  DualApp
//
//  Created by DualApp Team on 10/3/25.
//

import Foundation
import SwiftUI
import UIKit

// MARK: - Thermal Manager Actor

actor ThermalManager: Sendable {
    // MARK: - Singleton
    
    static let shared = ThermalManager()
    
    // MARK: - State Properties
    
    private(set) var currentThermalState: ThermalManagerState = .nominal
    private(set) var thermalPressure: ThermalPressure = .none
    private(set) var temperatureTrend: TemperatureTrend = .stable
    private(set) var lastStateChange: Date = Date()
    
    // MARK: - Thermal History
    
    private var thermalHistory: [ThermalSnapshot] = []
    private let maxHistorySize = 100
    private var stateChangeCount: Int = 0
    
    // MARK: - Configuration
    
    private var thermalMitigationEnabled: Bool = true
    private var mitigationThreshold: ThermalState = .serious
    private var recoveryThreshold: ThermalState = .fair
    private var adaptivePerformanceEnabled: Bool = true
    
    // MARK: - Event Stream
    
    let events: AsyncStream<ThermalEvent>
    private let eventContinuation: AsyncStream<ThermalEvent>.Continuation
    
    // MARK: - Monitoring
    
    private var monitoringTask: Task<Void, Never>?
    private let monitoringInterval: TimeInterval = 2.0
    private var isMitigating: Bool = false
    
    // MARK: - Initialization
    
    private init() {
        (self.events, self.eventContinuation) = AsyncStream<ThermalEvent>.makeStream()
        
        Task {
            await setupThermalMonitoring()
            await startMonitoring()
        }
    }
    
    // MARK: - Public Interface
    
    func startMonitoring() async {
        stopMonitoring()
        
        monitoringTask = Task {
            while !Task.isCancelled {
                await updateThermalStatus()
                try? await Task.sleep(nanoseconds: UInt64(monitoringInterval * 1_000_000_000))
            }
        }
    }
    
    func stopMonitoring() async {
        monitoringTask?.cancel()
        monitoringTask = nil
    }
    
    func setThermalMitigationEnabled(_ enabled: Bool) async {
        thermalMitigationEnabled = enabled
        eventContinuation.yield(.mitigationChanged(enabled))
        
        if !enabled {
            await disableThermalMitigation()
        }
    }
    
    func setMitigationThreshold(_ threshold: ThermalState) async {
        mitigationThreshold = threshold
        eventContinuation.yield(.thresholdChanged(threshold))
    }
    
    func setAdaptivePerformanceEnabled(_ enabled: Bool) async {
        adaptivePerformanceEnabled = enabled
        eventContinuation.yield(.adaptivePerformanceChanged(enabled))
    }
    
    func getThermalPrediction(for timeInterval: TimeInterval) async -> ThermalPrediction {
        return ThermalPredictionEngine.predict(
            for: timeInterval,
            history: thermalHistory,
            currentState: currentThermalState,
            trend: temperatureTrend
        )
    }
    
    func shouldThrottlePerformance() async -> Bool {
        guard thermalMitigationEnabled else { return false }
        
        switch currentThermalState {
        case .critical:
            return true
        case .serious:
            return true
        case .fair:
            return thermalPressure == .moderate || thermalPressure == .high
        case .nominal:
            return false
        case .unknown:
            return false
        }
    }
    
    func getRecommendedFrameRate() async -> Int32 {
        guard thermalMitigationEnabled else { return 60 }
        
        switch currentThermalState {
        case .critical:
            return 15
        case .serious:
            return 24
        case .fair:
            return thermalPressure == .high ? 24 : 30
        case .nominal:
            return 60
        case .unknown:
            return 30
        }
    }
    
    func getRecommendedVideoQuality() async -> VideoQuality {
        guard thermalMitigationEnabled else { return .uhd4k }
        
        switch currentThermalState {
        case .critical:
            return .hd720
        case .serious:
            return .hd1080
        case .fair:
            return thermalPressure == .high ? .hd1080 : .uhd4k
        case .nominal:
            return .uhd4k
        case .unknown:
            return .hd1080
        }
    }
    
    func forceThermalMitigation() async {
        await applyThermalMitigation(level: .aggressive)
        eventContinuation.yield(.mitigationForced)
    }
    
    func getCurrentThermalMetrics() async -> ThermalMetrics {
        return ThermalMetrics(
            currentState: currentThermalState,
            pressure: thermalPressure,
            trend: temperatureTrend,
            timeInCurrentState: Date().timeIntervalSince(lastStateChange),
            stateChangeCount: stateChangeCount,
            isMitigating: isMitigating
        )
    }
    
    // MARK: - Private Methods
    
    private func setupThermalMonitoring() async {
        // Register for thermal state notifications
        NotificationCenter.default.addObserver(
            forName: ProcessInfo.thermalStateDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.updateThermalStatus()
            }
        }
    }
    
    private func updateThermalStatus() async {
        let previousState = currentThermalState
        let previousPressure = thermalPressure
        
        // Get current thermal state from system
        let systemThermalState = ProcessInfo.processInfo.thermalState
        currentThermalState = ThermalState(from: systemThermalState)
        
        // Calculate thermal pressure
        thermalPressure = calculateThermalPressure()
        
        // Determine temperature trend
        temperatureTrend = calculateTemperatureTrend()
        
        // Create snapshot
        let snapshot = ThermalSnapshot(
            timestamp: Date(),
            state: currentThermalState,
            pressure: thermalPressure,
            trend: temperatureTrend
        )
        
        // Add to history
        thermalHistory.append(snapshot)
        if thermalHistory.count > maxHistorySize {
            thermalHistory.removeFirst()
        }
        
        // Check for state changes
        if currentThermalState != previousState {
            await handleThermalStateChange(from: previousState, to: currentThermalState)
        }
        
        // Check for pressure changes
        if thermalPressure != previousPressure {
            eventContinuation.yield(.pressureChanged(thermalPressure))
        }
        
        // Apply thermal mitigation if needed
        if thermalMitigationEnabled {
            await applyThermalMitigationIfNeeded()
        }
        
        // Emit status update
        eventContinuation.yield(.statusUpdated(snapshot))
    }
    
    private func calculateThermalPressure() -> ThermalPressure {
        // Calculate pressure based on current state and historical data
        switch currentThermalState {
        case .critical:
            return .critical
        case .serious:
            return thermalHistory.suffix(5).allSatisfy({ $0.state == .serious }) ? .high : .moderate
        case .fair:
            return temperatureTrend == .rising ? .moderate : .low
        case .nominal:
            return temperatureTrend == .rising ? .low : .none
        case .unknown:
            return .none
        }
    }
    
    private func calculateTemperatureTrend() -> TemperatureTrend {
        guard thermalHistory.count >= 3 else { return .stable }
        
        let recentHistory = Array(thermalHistory.suffix(10))
        let stateValues = recentHistory.map { snapshot -> Double in
            switch snapshot.state {
            case .nominal: return 0
            case .fair: return 1
            case .serious: return 2
            case .critical: return 3
            case .unknown: return 0
            }
        }
        
        // Simple trend calculation
        let firstHalf = Array(stateValues.prefix(stateValues.count / 2))
        let secondHalf = Array(stateValues.suffix(stateValues.count / 2))
        
        let firstAverage = firstHalf.reduce(0, +) / Double(firstHalf.count)
        let secondAverage = secondHalf.reduce(0, +) / Double(secondHalf.count)
        
        let difference = secondAverage - firstAverage
        
        if difference > 0.3 {
            return .rising
        } else if difference < -0.3 {
            return .falling
        } else {
            return .stable
        }
    }
    
    private func handleThermalStateChange(from previousState: ThermalState, to newState: ThermalState) async {
        lastStateChange = Date()
        stateChangeCount += 1
        
        eventContinuation.yield(.stateChanged(from: previousState, to: newState))
        
        // Handle different state transitions
        if newState.rawValue > previousState.rawValue {
            // Temperature is rising
            await handleTemperatureIncrease(from: previousState, to: newState)
        } else {
            // Temperature is falling
            await handleTemperatureDecrease(from: previousState, to: newState)
        }
    }
    
    private func handleTemperatureIncrease(from previousState: ThermalState, to newState: ThermalState) async {
        switch newState {
        case .serious, .critical:
            eventContinuation.yield(.warning(newState))
            await applyThermalMitigation(level: .aggressive)
        case .fair:
            eventContinuation.yield(.caution(newState))
            await applyThermalMitigation(level: .moderate)
        default:
            break
        }
    }
    
    private func handleTemperatureDecrease(from previousState: ThermalState, to newState: ThermalState) async {
        if newState <= recoveryThreshold && isMitigating {
            await reduceThermalMitigation()
            eventContinuation.yield(.recovery(newState))
        }
    }
    
    private func applyThermalMitigationIfNeeded() async {
        guard !isMitigating else { return }
        
        if currentThermalState.rawValue >= mitigationThreshold.rawValue {
            await applyThermalMitigation(level: .moderate)
        }
    }
    
    private func applyThermalMitigation(level: ThermalMitigationLevel) async {
        isMitigating = true
        
        switch level {
        case .light:
            await applyLightMitigation()
        case .moderate:
            await applyModerateMitigation()
        case .aggressive:
            await applyAggressiveMitigation()
        }
        
        eventContinuation.yield(.mitigationApplied(level))
    }
    
    private func applyLightMitigation() async {
        // Reduce frame rates slightly
        // Lower screen brightness if possible
        // Reduce animation complexity
        
        if adaptivePerformanceEnabled {
            // Notify performance managers to adjust
        }
    }
    
    private func applyModerateMitigation() async {
        await applyLightMitigation()
        
        // Reduce video quality
        // Limit background processing
        // Disable non-essential features
        
        eventContinuation.yield(.performanceLimited)
    }
    
    private func applyAggressiveMitigation() async {
        await applyModerateMitigation()
        
        // Force stop recording if active
        // Drastically reduce frame rates
        // Disable high-performance features
        
        eventContinuation.yield(.criticalMitigation)
    }
    
    private func reduceThermalMitigation() async {
        guard isMitigating else { return }
        
        // Gradually restore performance
        // Increase frame rates
        // Re-enable features
        
        isMitigating = false
        eventContinuation.yield(.mitigationReduced)
    }
    
    private func disableThermalMitigation() async {
        isMitigating = false
        // Restore full performance
        eventContinuation.yield(.mitigationDisabled)
    }
    
    deinit {
        Task { [weak self] in
            await self?.stopMonitoring()
        }
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - Thermal Event

enum ThermalEvent: Sendable {
    case statusUpdated(ThermalSnapshot)
    case stateChanged(from: ThermalState, to: ThermalState)
    case pressureChanged(ThermalPressure)
    case warning(ThermalState)
    case caution(ThermalState)
    case recovery(ThermalState)
    case mitigationChanged(Bool)
    case thresholdChanged(ThermalState)
    case adaptivePerformanceChanged(Bool)
    case mitigationApplied(ThermalMitigationLevel)
    case mitigationReduced
    case mitigationDisabled
    case mitigationForced
    case performanceLimited
    case criticalMitigation
}

// MARK: - Thermal State

enum ThermalManagerState: Int, CaseIterable, Sendable {
    case nominal = 0
    case fair = 1
    case serious = 2
    case critical = 3
    case unknown = 4
    
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

    var processInfoThermalState: ProcessInfo.ThermalState {
        switch self {
        case .nominal:
            return .nominal
        case .fair:
            return .fair
        case .serious:
            return .serious
        case .critical:
            return .critical
        case .unknown:
            return .nominal // Default to nominal for unknown
        }
    }
    
    var description: String {
        switch self {
        case .nominal:
            return "Normal"
        case .fair:
            return "Warm"
        case .serious:
            return "Hot"
        case .critical:
            return "Critical"
        case .unknown:
            return "Unknown"
        }
    }
    
    var color: Color {
        switch self {
        case .nominal:
            return .green
        case .fair:
            return .yellow
        case .serious:
            return .orange
        case .critical:
            return .red
        case .unknown:
            return .gray
        }
    }
    
    var icon: String {
        switch self {
        case .nominal:
            return "thermometer.snowflake"
        case .fair:
            return "thermometer.low"
        case .serious:
            return "thermometer.high"
        case .critical:
            return "thermometer.sun"
        case .unknown:
            return "thermometer"
        }
    }
}

// MARK: - Thermal Pressure

enum ThermalPressure: Int, CaseIterable, Sendable {
    case none = 0
    case low = 1
    case moderate = 2
    case high = 3
    case critical = 4
    
    var doubleValue: Double {
        switch self {
        case .none:
            return 0.0
        case .low:
            return 0.25
        case .moderate:
            return 0.5
        case .high:
            return 0.75
        case .critical:
            return 1.0
        }
    }

    var description: String {
        switch self {
        case .none:
            return "None"
        case .low:
            return "Low"
        case .moderate:
            return "Moderate"
        case .high:
            return "High"
        case .critical:
            return "Critical"
        }
    }
}

// MARK: - Temperature Trend

enum TemperatureTrend: String, CaseIterable, Sendable {
    case stable = "Stable"
    case rising = "Rising"
    case falling = "Falling"
    
    var icon: String {
        switch self {
        case .stable:
            return "arrow.right"
        case .rising:
            return "arrow.up"
        case .falling:
            return "arrow.down"
        }
    }
    
    var color: Color {
        switch self {
        case .stable:
            return .blue
        case .rising:
            return .red
        case .falling:
            return .green
        }
    }
}

// MARK: - Thermal Mitigation Level

enum ThermalMitigationLevel: String, CaseIterable, Sendable {
    case light = "Light"
    case moderate = "Moderate"
    case aggressive = "Aggressive"
    
    var description: String {
        switch self {
        case .light:
            return "Light performance reduction"
        case .moderate:
            return "Moderate performance reduction"
        case .aggressive:
            return "Aggressive performance reduction"
        }
    }
}

// MARK: - Thermal Snapshot

struct ThermalSnapshot: Sendable {
    let timestamp: Date
    let state: ThermalState
    let pressure: ThermalPressure
    let trend: TemperatureTrend
}

// MARK: - Thermal Metrics

struct ThermalMetrics: Sendable {
    let currentState: ThermalState
    let pressure: ThermalPressure
    let trend: TemperatureTrend
    let timeInCurrentState: TimeInterval
    let stateChangeCount: Int
    let isMitigating: Bool
    
    var formattedTimeInCurrentState: String {
        let minutes = Int(timeInCurrentState) / 60
        let seconds = Int(timeInCurrentState) % 60
        
        if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        } else {
            return "\(seconds)s"
        }
    }
}

// MARK: - Thermal Prediction Engine

struct ThermalPredictionEngine {
    static func predict(
        for timeInterval: TimeInterval,
        history: [ThermalSnapshot],
        currentState: ThermalState,
        trend: TemperatureTrend
    ) -> ThermalPrediction {
        
        guard !history.isEmpty else {
            return ThermalPrediction(
                predictedState: currentState,
                confidence: 0,
                timeToThreshold: nil
            )
        }
        
        // Predict state based on trend
        let predictedState = predictState(currentState: currentState, trend: trend, timeInterval: timeInterval)
        
        // Calculate confidence based on trend consistency
        let confidence = calculateConfidence(from: history, trend: trend)
        
        // Estimate time to serious/critical threshold
        let timeToThreshold = calculateTimeToThreshold(
            currentState: currentState,
            trend: trend,
            history: history
        )
        
        return ThermalPrediction(
            predictedState: predictedState,
            confidence: confidence,
            timeToThreshold: timeToThreshold
        )
    }
    
    private static func predictState(currentState: ThermalState, trend: TemperatureTrend, timeInterval: TimeInterval) -> ThermalState {
        switch (currentState, trend) {
        case (.nominal, .rising):
            return timeInterval > 300 ? .fair : .nominal
        case (.fair, .rising):
            return timeInterval > 180 ? .serious : .fair
        case (.serious, .rising):
            return timeInterval > 120 ? .critical : .serious
        case (.fair, .falling):
            return timeInterval > 300 ? .nominal : .fair
        case (.serious, .falling):
            return timeInterval > 300 ? .fair : .serious
        case (.critical, .falling):
            return timeInterval > 300 ? .serious : .critical
        default:
            return currentState
        }
    }
    
    private static func calculateConfidence(from history: [ThermalSnapshot], trend: TemperatureTrend) -> Double {
        guard history.count >= 5 else { return 0 }
        
        let recentHistory = Array(history.suffix(10))
        let trendConsistency = recentHistory.filter { $0.trend == trend }.count
        
        return Double(trendConsistency) / Double(recentHistory.count)
    }
    
    private static func calculateTimeToThreshold(
        currentState: ThermalState,
        trend: TemperatureTrend,
        history: [ThermalSnapshot]
    ) -> TimeInterval? {
        
        guard trend == .rising else { return nil }
        
        // Estimate time to serious state
        switch currentState {
        case .nominal:
            return 300 // 5 minutes estimate
        case .fair:
            return 180 // 3 minutes estimate
        case .serious:
            return 120 // 2 minutes estimate
        case .critical, .unknown:
            return nil
        }
    }
}

// MARK: - Thermal Prediction

struct ThermalPrediction: Sendable {
    let predictedState: ThermalState
    let confidence: Double
    let timeToThreshold: TimeInterval?
    
    var riskLevel: ThermalRiskLevel {
        switch predictedState {
        case .nominal, .fair:
            return .low
        case .serious:
            return .medium
        case .critical:
            return .high
        case .unknown:
            return .unknown
        }
    }
    
    var formattedTimeToThreshold: String? {
        guard let timeToThreshold = timeToThreshold else { return nil }
        
        let minutes = Int(timeToThreshold) / 60
        if minutes > 0 {
            return "\(minutes)m"
        } else {
            return "< 1m"
        }
    }
}

// MARK: - Thermal Risk Level

enum ThermalRiskLevel: Sendable {
    case low
    case medium
    case high
    case unknown
}