//
//  ErrorRecoveryManager.swift
//  DualApp
//
//  Created by DualApp Team on 10/3/25.
//

import Foundation
import AVFoundation

// MARK: - Error Recovery Manager

actor ErrorRecoveryManager {
    
    // MARK: - Properties
    
    private var recoveryStrategies: [ErrorRecoveryStrategy] = []
    private var errorHistory: [ErrorRecord] = []
    private var maxHistorySize: Int = 100
    
    // MARK: - Recovery State
    
    private var isRecovering: Bool = false
    private var currentRecoveryAttempt: RecoveryAttempt?
    private var maxRetryAttempts: Int = 3
    private var recoveryCooldown: TimeInterval = 5.0
    
    // MARK: - Event Stream
    
    let events: AsyncStream<ErrorRecoveryEvent>
    private let eventContinuation: AsyncStream<ErrorRecoveryEvent>.Continuation
    
    // MARK: - Statistics
    
    private var recoveryStatistics: RecoveryStatistics = RecoveryStatistics()
    
    // MARK: - Initialization
    
    init() {
        (self.events, self.eventContinuation) = AsyncStream<ErrorRecoveryEvent>.makeStream()

        // Initialize recovery strategies
        Task {
            await setupRecoveryStrategies()
        }
    }
    
    // MARK: - Public Interface
    
    func handleError(_ error: Error, context: ErrorContext? = nil) async {
        let errorRecord = ErrorRecord(
            error: error,
            timestamp: Date(),
            context: context,
            recoveryAttempts: 0
        )
        
        errorHistory.append(errorRecord)
        if errorHistory.count > maxHistorySize {
            errorHistory.removeFirst()
        }
        
        eventContinuation.yield(.errorOccurred(errorRecord))
        
        // Attempt recovery if not already recovering
        if !isRecovering {
            await attemptRecovery(for: errorRecord)
        }
    }
    
    func handleCriticalError(_ error: Error, context: ErrorContext? = nil) async {
        let errorRecord = ErrorRecord(
            error: error,
            timestamp: Date(),
            context: context,
            isCritical: true,
            recoveryAttempts: 0
        )
        
        errorHistory.append(errorRecord)
        
        eventContinuation.yield(.criticalErrorOccurred(errorRecord))
        
        // Force recovery for critical errors
        await forceRecovery(for: errorRecord)
    }
    
    func addRecoveryStrategy(_ strategy: ErrorRecoveryStrategy) async {
        recoveryStrategies.append(strategy)
        eventContinuation.yield(.strategyAdded(strategy))
    }
    
    func removeRecoveryStrategy(_ strategy: ErrorRecoveryStrategy) async {
        // Use type and priority to identify strategies since ID comparison is problematic with protocols
        recoveryStrategies.removeAll { existing in
            type(of: existing) == type(of: strategy) && existing.priority == strategy.priority
        }
        eventContinuation.yield(.strategyRemoved(strategy))
    }
    
    func setMaxRetryAttempts(_ attempts: Int) async {
        maxRetryAttempts = max(1, attempts)
        eventContinuation.yield(.maxRetryAttemptsChanged(maxRetryAttempts))
    }
    
    func setRecoveryCooldown(_ cooldown: TimeInterval) async {
        recoveryCooldown = max(1.0, cooldown)
        eventContinuation.yield(.recoveryCooldownChanged(recoveryCooldown))
    }
    
    func getErrorHistory() async -> [ErrorRecord] {
        return errorHistory
    }
    
    func getRecoveryStatistics() async -> RecoveryStatistics {
        return recoveryStatistics
    }
    
    func clearErrorHistory() async {
        errorHistory.removeAll()
        eventContinuation.yield(.errorHistoryCleared)
    }
    
    func forceRecoveryCheck() async {
        // Check for any pending issues and attempt recovery
        await checkSystemHealth()
    }
    
    // MARK: - Private Methods
    
    private func setupRecoveryStrategies() async {
        recoveryStrategies = [
            CameraSessionRecoveryStrategy(),
            ThermalRecoveryStrategy(),
            MemoryRecoveryStrategy(),
            BatteryRecoveryStrategy(),
            FileSystemRecoveryStrategy(),
            HardwareRecoveryStrategy()
        ]
    }
    
    private func attemptRecovery(for errorRecord: ErrorRecord) async {
        guard !isRecovering else { return }
        
        // Check if we've exceeded retry attempts
        if errorRecord.recoveryAttempts >= maxRetryAttempts {
            let failedAttempt = RecoveryAttempt(
                errorRecord: errorRecord,
                timestamp: Date(),
                attemptNumber: errorRecord.recoveryAttempts + 1,
                isForced: false
            )
            eventContinuation.yield(.recoveryFailed(failedAttempt, "Maximum retry attempts exceeded"))
            return
        }
        
        // Check cooldown
        if let lastAttempt = currentRecoveryAttempt,
           Date().timeIntervalSince(lastAttempt.timestamp) < recoveryCooldown {
            return
        }
        
        isRecovering = true
        
        let recoveryAttempt = RecoveryAttempt(
            errorRecord: errorRecord,
            timestamp: Date(),
            attemptNumber: errorRecord.recoveryAttempts + 1,
            isForced: false
        )
        
        currentRecoveryAttempt = recoveryAttempt
        eventContinuation.yield(.recoveryStarted(recoveryAttempt))
        
        // Find applicable recovery strategies
        let applicableStrategies = recoveryStrategies.filter { strategy in
            strategy.canHandle(errorRecord.error)
        }
        
        var recoverySuccessful = false
        
        // Attempt recovery strategies in order of priority
        for strategy in applicableStrategies.sorted(by: { $0.priority > $1.priority }) {
            do {
                let success = try await strategy.recover(from: errorRecord.error, context: errorRecord.context)
                
                if success {
                    recoverySuccessful = true
                    eventContinuation.yield(.recoverySucceeded(recoveryAttempt, strategy))
                    break
                }
            } catch {
                eventContinuation.yield(.strategyFailed(strategy, error))
            }
        }
        
        if recoverySuccessful {
            recoveryStatistics.successfulRecoveries += 1
        } else {
            recoveryStatistics.failedRecoveries += 1
            
            // Update error record with increased attempt count
            if var index = errorHistory.firstIndex(where: { $0.timestamp == errorRecord.timestamp }) {
                errorHistory[index].recoveryAttempts += 1
                
                // Schedule retry if under max attempts
                if errorHistory[index].recoveryAttempts < maxRetryAttempts {
                    Task {
                        try? await Task.sleep(nanoseconds: UInt64(recoveryCooldown * 1_000_000_000))
                        await attemptRecovery(for: errorHistory[index])
                    }
                }
            }
            
            eventContinuation.yield(.recoveryFailed(recoveryAttempt, "All recovery strategies failed"))
        }
        
        isRecovering = false
        currentRecoveryAttempt = nil
    }
    
    private func forceRecovery(for errorRecord: ErrorRecord) async {
        isRecovering = true
        
        let recoveryAttempt = RecoveryAttempt(
            errorRecord: errorRecord,
            timestamp: Date(),
            attemptNumber: 1,
            isForced: true
        )
        
        currentRecoveryAttempt = recoveryAttempt
        eventContinuation.yield(.forcedRecoveryStarted(recoveryAttempt))
        
        // Apply all recovery strategies for critical errors
        var recoverySuccessful = false
        
        for strategy in recoveryStrategies.sorted(by: { $0.priority > $1.priority }) {
            do {
                let success = try await strategy.forceRecover(from: errorRecord.error, context: errorRecord.context)
                
                if success {
                    recoverySuccessful = true
                    eventContinuation.yield(.forcedRecoverySucceeded(recoveryAttempt, strategy))
                    break
                }
            } catch {
                eventContinuation.yield(.strategyFailed(strategy, error))
            }
        }
        
        if recoverySuccessful {
            recoveryStatistics.successfulRecoveries += 1
        } else {
            recoveryStatistics.failedRecoveries += 1
            eventContinuation.yield(.forcedRecoveryFailed(recoveryAttempt, "All forced recovery strategies failed"))
        }
        
        isRecovering = false
        currentRecoveryAttempt = nil
    }
    
    private func checkSystemHealth() async {
        var issues: [SystemIssue] = []
        
        // Check thermal state
        let thermalState = await ThermalManager.shared.currentThermalState
        if thermalState == .critical {
            issues.append(SystemIssue(type: .thermal, severity: .critical, description: "Critical thermal state"))
        }
        
        // Check battery level
        let batteryLevel = await BatteryManager.shared.currentBatteryLevel
        if batteryLevel < 0.1 {
            issues.append(SystemIssue(type: .battery, severity: .critical, description: "Critical battery level"))
        }
        
        // Check memory pressure
        let memoryPressure = await MemoryManager.shared.currentMemoryPressure
        if memoryPressure == .critical {
            issues.append(SystemIssue(type: .memory, severity: .critical, description: "Critical memory pressure"))
        }
        
        // Attempt recovery for critical issues
        for issue in issues where issue.severity == .critical {
            let error = NSError(domain: "SystemHealth", code: 1001, userInfo: [
                NSLocalizedDescriptionKey: issue.description
            ])
            
            let context = ErrorContext(
                component: "SystemHealthMonitor",
                operation: "HealthCheck",
                additionalInfo: ["issueType": issue.type.rawValue]
            )
            
            await handleCriticalError(error, context: context)
        }
    }
}

// MARK: - Supporting Types

enum ErrorRecoveryEvent: Sendable {
    case errorOccurred(ErrorRecord)
    case criticalErrorOccurred(ErrorRecord)
    case recoveryStarted(RecoveryAttempt)
    case recoverySucceeded(RecoveryAttempt, ErrorRecoveryStrategy)
    case recoveryFailed(RecoveryAttempt, String)
    case forcedRecoveryStarted(RecoveryAttempt)
    case forcedRecoverySucceeded(RecoveryAttempt, ErrorRecoveryStrategy)
    case forcedRecoveryFailed(RecoveryAttempt, String)
    case strategyAdded(ErrorRecoveryStrategy)
    case strategyRemoved(ErrorRecoveryStrategy)
    case strategyFailed(ErrorRecoveryStrategy, Error)
    case maxRetryAttemptsChanged(Int)
    case recoveryCooldownChanged(TimeInterval)
    case errorHistoryCleared
}

struct ErrorRecord: Sendable, Identifiable {
    let id = UUID()
    let error: Error
    let timestamp: Date
    let context: ErrorContext?
    let isCritical: Bool
    var recoveryAttempts: Int
    
    init(error: Error, timestamp: Date, context: ErrorContext?, isCritical: Bool = false, recoveryAttempts: Int = 0) {
        self.error = error
        self.timestamp = timestamp
        self.context = context
        self.isCritical = isCritical
        self.recoveryAttempts = recoveryAttempts
    }
    
    var errorDescription: String {
        return error.localizedDescription
    }
    
    var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        return formatter.string(from: timestamp)
    }
}

struct ErrorContext: Sendable {
    let component: String
    let operation: String
    let additionalInfo: [String: String]

    init(component: String, operation: String, additionalInfo: [String: String] = [:]) {
        self.component = component
        self.operation = operation
        self.additionalInfo = additionalInfo
    }
}

struct RecoveryAttempt: Sendable {
    let errorRecord: ErrorRecord
    let timestamp: Date
    let attemptNumber: Int
    let isForced: Bool
    
    init(errorRecord: ErrorRecord, timestamp: Date, attemptNumber: Int, isForced: Bool = false) {
        self.errorRecord = errorRecord
        self.timestamp = timestamp
        self.attemptNumber = attemptNumber
        self.isForced = isForced
    }
    
    var description: String {
        return "\(isForced ? "Forced" : "Automatic") recovery attempt #\(attemptNumber) for \(errorRecord.errorDescription)"
    }
}

struct RecoveryStatistics: Sendable {
    var successfulRecoveries: Int = 0
    var failedRecoveries: Int = 0
    var totalRecoveryTime: TimeInterval = 0
    var averageRecoveryTime: TimeInterval = 0
    
    var totalRecoveryAttempts: Int {
        return successfulRecoveries + failedRecoveries
    }
    
    var successRate: Double {
        return totalRecoveryAttempts > 0 ? Double(successfulRecoveries) / Double(totalRecoveryAttempts) : 0
    }
    
    var formattedSuccessRate: String {
        return String(format: "%.1f%%", successRate * 100)
    }
    
    var formattedAverageRecoveryTime: String {
        return String(format: "%.2f seconds", averageRecoveryTime)
    }
}

struct SystemIssue: Sendable {
    let type: SystemIssueType
    let severity: Severity
    let description: String
    
    enum SystemIssueType: String, Sendable {
        case thermal = "Thermal"
        case battery = "Battery"
        case memory = "Memory"
        case storage = "Storage"
        case camera = "Camera"
        case hardware = "Hardware"
    }
    
    enum Severity: String, Sendable {
        case low = "Low"
        case medium = "Medium"
        case high = "High"
        case critical = "Critical"
    }
}

// MARK: - Error Recovery Strategy Protocol

protocol ErrorRecoveryStrategy: Sendable, Identifiable {
    var priority: Int { get }
    
    func canHandle(_ error: Error) -> Bool
    func recover(from error: Error, context: ErrorContext?) async throws -> Bool
    func forceRecover(from error: Error, context: ErrorContext?) async throws -> Bool
}

// MARK: - Concrete Recovery Strategies

struct CameraSessionRecoveryStrategy: ErrorRecoveryStrategy {
    let id = "camera_session_recovery"
    let priority = 100
    
    func canHandle(_ error: Error) -> Bool {
        return error is DualCameraError || 
               error.localizedDescription.contains("camera") ||
               error.localizedDescription.contains("session")
    }
    
    func recover(from error: Error, context: ErrorContext?) async throws -> Bool {
        // Attempt to restart camera session
        // This would involve reinitializing the dual camera session
        
        // Simulate recovery attempt
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        return true // Placeholder
    }
    
    func forceRecover(from error: Error, context: ErrorContext?) async throws -> Bool {
        // Force restart camera session with full reinitialization
        
        // Simulate force recovery
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        
        return true // Placeholder
    }
}

struct ThermalRecoveryStrategy: ErrorRecoveryStrategy {
    let id = "thermal_recovery"
    let priority = 90
    
    func canHandle(_ error: Error) -> Bool {
        return error.localizedDescription.contains("thermal") ||
               error.localizedDescription.contains("temperature")
    }
    
    func recover(from error: Error, context: ErrorContext?) async throws -> Bool {
        // Reduce performance to lower thermal load
        await ThermalManager.shared.setThermalMitigationEnabled(true)
        
        // Wait for temperature to decrease
        try await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
        
        return true
    }
    
    func forceRecover(from error: Error, context: ErrorContext?) async throws -> Bool {
        // Force aggressive thermal mitigation
        await ThermalManager.shared.forceThermalMitigation()
        
        // Wait longer for recovery
        try await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
        
        return true
    }
}

struct MemoryRecoveryStrategy: ErrorRecoveryStrategy {
    let id = "memory_recovery"
    let priority = 85
    
    func canHandle(_ error: Error) -> Bool {
        return error.localizedDescription.contains("memory") ||
               error.localizedDescription.contains("allocation")
    }
    
    func recover(from error: Error, context: ErrorContext?) async throws -> Bool {
        // Request memory cleanup
        await MemoryManager.shared.requestMemoryCleanup()
        
        // Wait for cleanup to complete
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        
        return true
    }
    
    func forceRecover(from error: Error, context: ErrorContext?) async throws -> Bool {
        // Force aggressive memory cleanup
        await MemoryManager.shared.optimizeForHighMemoryUsage()
        
        // Wait for aggressive cleanup
        try await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
        
        return true
    }
}

struct BatteryRecoveryStrategy: ErrorRecoveryStrategy {
    let id = "battery_recovery"
    let priority = 80
    
    func canHandle(_ error: Error) -> Bool {
        return error.localizedDescription.contains("battery") ||
               error.localizedDescription.contains("power")
    }
    
    func recover(from error: Error, context: ErrorContext?) async throws -> Bool {
        // Enable battery optimization
        await BatteryManager.shared.setBatteryOptimizationEnabled(true)
        
        // Set power saver profile
        await BatteryManager.shared.setPerformanceProfile(.powerSaver)
        
        return true
    }
    
    func forceRecover(from error: Error, context: ErrorContext?) async throws -> Bool {
        // Force maximum battery optimization
        await BatteryManager.shared.setPerformanceProfile(.powerSaver)
        
        // Reduce recording quality to minimum
        // This would involve updating the camera configuration
        
        return true
    }
}

struct FileSystemRecoveryStrategy: ErrorRecoveryStrategy {
    let id = "filesystem_recovery"
    let priority = 70
    
    func canHandle(_ error: Error) -> Bool {
        return error.localizedDescription.contains("disk") ||
               error.localizedDescription.contains("storage") ||
               error.localizedDescription.contains("file")
    }
    
    func recover(from error: Error, context: ErrorContext?) async throws -> Bool {
        // Clear temporary files
        await clearTemporaryFiles()
        
        // Check available space
        let availableSpace = getAvailableDiskSpace()
        
        return availableSpace > 100_000_000 // At least 100MB available
    }
    
    func forceRecover(from error: Error, context: ErrorContext?) async throws -> Bool {
        // Force cleanup of all caches
        await clearAllCaches()
        
        // Clear old recordings if necessary
        await clearOldRecordings()
        
        return true
    }
    
    private func clearTemporaryFiles() async {
        // Implementation would clear temporary files
    }
    
    private func clearAllCaches() async {
        // Implementation would clear all caches
    }
    
    private func clearOldRecordings() async {
        // Implementation would clear old recordings
    }
    
    private func getAvailableDiskSpace() -> Int64 {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        do {
            let attributes = try FileManager.default.attributesOfFileSystem(forPath: documentsPath.path)
            return attributes[.systemFreeSize] as? Int64 ?? 0
        } catch {
            return 0
        }
    }
}

struct HardwareRecoveryStrategy: ErrorRecoveryStrategy {
    let id = "hardware_recovery"
    let priority = 60
    
    func canHandle(_ error: Error) -> Bool {
        return error.localizedDescription.contains("hardware") ||
               error.localizedDescription.contains("device")
    }
    
    func recover(from error: Error, context: ErrorContext?) async throws -> Bool {
        // Attempt hardware reset
        // This would involve reinitializing hardware components
        
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        
        return true
    }
    
    func forceRecover(from error: Error, context: ErrorContext?) async throws -> Bool {
        // Force hardware reinitialization
        // This would involve a complete hardware reset
        
        try await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
        
        return true
    }
}