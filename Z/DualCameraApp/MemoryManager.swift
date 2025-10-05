//
//  MemoryManager.swift
//  DualApp
//
//  Created by DualApp Team on 10/3/25.
//

import Foundation
import SwiftUI
import Combine

// MARK: - Memory Manager Actor

actor MemoryManager: Sendable {
    // MARK: - Singleton

    static let shared = MemoryManager()

    // MARK: - State Properties
    
    private(set) var currentMemoryPressure: MemoryManagerPressure = .normal
    private(set) var availableMemory: UInt64 = 0
    private(set) var usedMemory: UInt64 = 0
    private(set) var memoryWarningThreshold: Double = 0.8
    
    // MARK: - Predictive Properties
    
    private var memoryHistory: [LegacyMemorySnapshot] = []
    private var predictionModel: MemoryPredictionModel
    private let maxHistorySize = 100
    
    // MARK: - iOS 26+ Memory Compaction
    
    private var memoryCompactionEnabled: Bool = true
    private var spanBasedBufferManagementEnabled: Bool = true
    private var predictiveMemoryManagementEnabled: Bool = true
    private var memoryCompactionTask: Task<Void, Never>?
    
    // MARK: - Event Stream
    
    let events: AsyncStream<MemoryEvent>
    private let eventContinuation: AsyncStream<MemoryEvent>.Continuation
    
    // MARK: - Monitoring
    
    private var monitoringTask: Task<Void, Never>?
    private let monitoringInterval: TimeInterval = 1.0
    
    // MARK: - Initialization
    
    init() {
        (self.events, self.eventContinuation) = AsyncStream<MemoryEvent>.makeStream()
        self.predictionModel = MemoryPredictionModel()
        
        // Enable iOS 26+ features if available
        if #available(iOS 26.0, *) {
            setupIOS26MemoryFeatures()
        }
        
        Task {
            await startMonitoring()
        }
    }
    
    // MARK: - Public Interface
    
    func startMonitoring() async {
        stopMonitoring()
        
        monitoringTask = Task {
            while !Task.isCancelled {
                await updateMemoryStatus()
                try? await Task.sleep(nanoseconds: UInt64(monitoringInterval * 1_000_000_000))
            }
        }
    }
    
    func stopMonitoring() async {
        monitoringTask?.cancel()
        monitoringTask = nil
    }
    
    func requestMemoryCleanup() async {
        await performMemoryCleanup()
        eventContinuation.yield(.cleanupCompleted)
    }
    
    func setMemoryWarningThreshold(_ threshold: Double) async {
        memoryWarningThreshold = max(0.5, min(0.95, threshold))
        eventContinuation.yield(.thresholdChanged(memoryWarningThreshold))
    }
    
    func getMemoryPrediction(for timeInterval: TimeInterval) async -> MemoryPrediction {
        return predictionModel.predict(for: timeInterval, history: memoryHistory)
    }
    
    func optimizeForHighMemoryUsage() async {
        // Aggressive cleanup for high memory usage scenarios
        await performAggressiveCleanup()
        
        // Enable iOS 26+ memory compaction
        if #available(iOS 26.0, *) {
            await enableIOS26MemoryCompaction()
        }
        
        eventContinuation.yield(.optimizationApplied(.aggressive))
    }
    
    func optimizeForLowMemoryUsage() async {
        // Conservative cleanup for normal operation
        await performConservativeCleanup()
        eventContinuation.yield(.optimizationApplied(.conservative))
    }
    
    // MARK: - iOS 26+ Memory Features
    
    @available(iOS 26.0, *)
    private func setupIOS26MemoryFeatures() {
        // Enable span-based buffer management
        spanBasedBufferManagementEnabled = true
        
        // Enable predictive memory management
        predictiveMemoryManagementEnabled = true
        
        // Enable advanced memory compaction
        memoryCompactionEnabled = true
    }
    
    @available(iOS 26.0, *)
    func enableIOS26MemoryCompaction() async {
        guard memoryCompactionEnabled else { return }
        
        // Start memory compaction task
        memoryCompactionTask = Task {
            await performIOS26MemoryCompaction()
        }
        
        eventContinuation.yield(.ios26MemoryCompactionEnabled)
    }
    
    @available(iOS 26.0, *)
    func disableIOS26MemoryCompaction() async {
        memoryCompactionTask?.cancel()
        memoryCompactionTask = nil
        eventContinuation.yield(.ios26MemoryCompactionDisabled)
    }
    
    @available(iOS 26.0, *)
    private func performIOS26MemoryCompaction() async {
        // Use iOS 26+ memory compaction APIs
        let compactionLevel = determineCompactionLevel()
        
        switch compactionLevel {
        case .light:
            await performLightMemoryCompaction()
        case .moderate:
            await performModerateMemoryCompaction()
        case .aggressive:
            await performAggressiveMemoryCompaction()
        }
    }
    
    @available(iOS 26.0, *)
    private func determineCompactionLevel() -> MemoryCompactionLevel {
        let memoryUsageRatio = Double(usedMemory) / Double(availableMemory + usedMemory)
        
        switch memoryUsageRatio {
        case 0..<0.7:
            return .light
        case 0.7..<0.85:
            return .moderate
        default:
            return .aggressive
        }
    }
    
    @available(iOS 26.0, *)
    private func performLightMemoryCompaction() async {
        // Light memory compaction using iOS 26+ APIs
        // Clear non-essential caches
        await clearNonEssentialCaches()
        
        // Compact memory spans
        if spanBasedBufferManagementEnabled {
            await compactMemorySpans(level: .light)
        }
    }
    
    @available(iOS 26.0, *)
    private func performModerateMemoryCompaction() async {
        await performLightMemoryCompaction()
        
        // Moderate memory compaction
        await clearImageCaches()
        await clearTemporaryFiles()
        
        // Compact memory spans with higher pressure
        if spanBasedBufferManagementEnabled {
            await compactMemorySpans(level: .moderate)
        }
    }
    
    @available(iOS 26.0, *)
    private func performAggressiveMemoryCompaction() async {
        await performModerateMemoryCompaction()
        
        // Aggressive memory compaction
        await clearAllCaches()
        await releaseNonEssentialResources()
        
        // Compact all memory spans
        if spanBasedBufferManagementEnabled {
            await compactMemorySpans(level: .aggressive)
        }
        
        // Trigger system memory compaction
        await triggerSystemMemoryCompaction()
    }
    
    @available(iOS 26.0, *)
    private func compactMemorySpans(level: MemoryCompactionLevel) async {
        // Use iOS 26+ span-based memory management
        // This would use the new span-based buffer management APIs
        switch level {
        case .light:
            // Compact only low-priority spans
            break
        case .moderate:
            // Compact medium and low-priority spans
            break
        case .aggressive:
            // Compact all spans
            break
        }
    }
    
    @available(iOS 26.0, *)
    private func triggerSystemMemoryCompaction() async {
        // Use iOS 26+ system memory compaction APIs
        // This would trigger the system's advanced memory compaction
    }
    
    // MARK: - Predictive Memory Management
    
    func enablePredictiveMemoryManagement() async {
        predictiveMemoryManagementEnabled = true
        eventContinuation.yield(.predictiveMemoryManagementEnabled)
    }
    
    func disablePredictiveMemoryManagement() async {
        predictiveMemoryManagementEnabled = false
        eventContinuation.yield(.predictiveMemoryManagementDisabled)
    }
    
    private func performPredictiveMemoryManagement() async {
        guard predictiveMemoryManagementEnabled else { return }
        
        // Get memory prediction for next 5 minutes
        let prediction = await getMemoryPrediction(for: 300)
        
        // If prediction indicates high memory usage, take preventive action
        if prediction.predictedUsage > 0.8 {
            await performPreventiveMemoryCleanup()
        }
    }
    
    private func performPreventiveMemoryCleanup() async {
        // Take preventive action based on prediction
        await clearExpiredCaches()
        await trimMemoryCachesLightly()
        
        eventContinuation.yield(.preventiveMemoryCleanupPerformed)
    }
    
    // MARK: - Private Methods
    
    private func updateMemoryStatus() async {
        let snapshot = await captureMemorySnapshot()
        
        // Update current state
        usedMemory = snapshot.usedMemory
        availableMemory = snapshot.availableMemory
        
        // Calculate memory pressure
        let memoryUsageRatio = Double(usedMemory) / Double(availableMemory + usedMemory)
        currentMemoryPressure = MemoryPressure(from: memoryUsageRatio)
        
        // Add to history
        memoryHistory.append(snapshot)
        if memoryHistory.count > maxHistorySize {
            memoryHistory.removeFirst()
        }
        
        // Check for warnings
        if memoryUsageRatio > memoryWarningThreshold {
            eventContinuation.yield(.warning(memoryUsageRatio))
            
            // Auto-cleanup if critical
            if currentMemoryPressure == .critical {
                await performAggressiveCleanup()
            }
        }
        
        // Update prediction model
        predictionModel.update(with: snapshot)
        
        // Perform predictive memory management
        await performPredictiveMemoryManagement()
        
        // Emit status update
        eventContinuation.yield(.statusUpdated(snapshot))
    }
    
    private func captureMemorySnapshot() async -> MemorySnapshot {
        let machTaskInfo = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &machTaskInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        var usedMemory: UInt64 = 0
        if kerr == KERN_SUCCESS {
            usedMemory = machTaskInfo.resident_size
        }
        
        // Get available memory
        var availableMemory: UInt64 = 0
        var info = vm_statistics64_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size)/4
        
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                host_statistics64(mach_host_self(),
                                 host_flavor_t(HOST_VM_INFO64),
                                 $0,
                                 &count)
            }
        }
        
        if result == KERN_SUCCESS {
            let pageSize = vm_kernel_page_size
            availableMemory = UInt64(info.free_count) * UInt64(pageSize)
        }
        
        return MemorySnapshot(
            timestamp: Date(),
            usedMemory: usedMemory,
            availableMemory: availableMemory,
            pressure: currentMemoryPressure
        )
    }
    
    private func performMemoryCleanup() async {
        // Clear image caches
        await clearImageCaches()
        
        // Clear temporary files
        await clearTemporaryFiles()
        
        // Trim memory caches
        await trimMemoryCaches()
        
        // Notify other components to release memory
        NotificationCenter.default.post(name: .memoryCleanupRequested, object: nil)
    }
    
    private func performAggressiveCleanup() async {
        await performMemoryCleanup()
        
        // Clear all caches aggressively
        await clearAllCaches()
        
        // Release non-essential resources
        await releaseNonEssentialResources()
        
        // Enable iOS 26+ memory compaction
        if #available(iOS 26.0, *) {
            await enableIOS26MemoryCompaction()
        }
    }
    
    private func performConservativeCleanup() async {
        // Only clear expired caches
        await clearExpiredCaches()
        
        // Trim memory caches lightly
        await trimMemoryCachesLightly()
    }
    
    private func clearImageCaches() async {
        // Clear SwiftUI image cache
        // Clear custom image caches
    }
    
    private func clearTemporaryFiles() async {
        // Clear temporary files from disk
        let tempDir = NSTemporaryDirectory()
        // Implementation would clean up temp files
    }
    
    private func trimMemoryCaches() async {
        // Trim system memory caches
        // Clear NSCache instances
    }
    
    private func clearAllCaches() async {
        // Clear all application caches
        URLCache.shared.removeAllCachedResponses()
    }
    
    private func clearExpiredCaches() async {
        // Clear only expired cache entries
    }
    
    private func trimMemoryCachesLightly() async {
        // Light cache trimming
    }
    
    private func clearNonEssentialCaches() async {
        // Clear caches that are not essential for current operation
    }
    
    private func releaseNonEssentialResources() async {
        // Release resources that can be recreated
        // Clear preview data, thumbnails, etc.
    }
    
    deinit {
        Task { [weak self] in
            await self?.stopMonitoring()
        }
        
        // Cancel iOS 26+ memory compaction task
        if #available(iOS 26.0, *) {
            memoryCompactionTask?.cancel()
        }
    }
}

// MARK: - Memory Pressure

enum MemoryManagerPressure: Sendable {
    case normal
    case warning
    case critical
    
    init(from usageRatio: Double) {
        switch usageRatio {
        case 0..<0.7:
            self = .normal
        case 0.7..<0.9:
            self = .warning
        default:
            self = .critical
        }
    }
    
    var severity: Double {
        switch self {
        case .normal:
            return 0.0
        case .warning:
            return 0.5
        case .critical:
            return 1.0
        }
    }
}

// MARK: - Memory Event

enum MemoryEvent: Sendable {
    case statusUpdated(MemorySnapshot)
    case warning(Double)
    case cleanupCompleted
    case thresholdChanged(Double)
    case optimizationApplied(MemoryOptimizationLevel)
    case predictionUpdated(MemoryPrediction)
    case ios26MemoryCompactionEnabled
    case ios26MemoryCompactionDisabled
    case predictiveMemoryManagementEnabled
    case predictiveMemoryManagementDisabled
    case preventiveMemoryCleanupPerformed
}

// MARK: - Memory Snapshot

struct LegacyMemorySnapshot: Sendable {
    let timestamp: Date
    let usedMemory: UInt64
    let availableMemory: UInt64
    let pressure: MemoryPressure
    
    var totalMemory: UInt64 {
        return usedMemory + availableMemory
    }
    
    var usageRatio: Double {
        return Double(usedMemory) / Double(totalMemory)
    }
    
    var formattedUsedMemory: String {
        return ByteCountFormatter.string(fromByteCount: Int64(usedMemory), countStyle: .memory)
    }
    
    var formattedAvailableMemory: String {
        return ByteCountFormatter.string(fromByteCount: Int64(availableMemory), countStyle: .memory)
    }
}

// MARK: - Memory Prediction Model

class MemoryPredictionModel: Sendable {
    private var trendData: [Double] = []
    private let maxTrendSize = 50
    
    func update(with snapshot: MemorySnapshot) {
        trendData.append(snapshot.usageRatio)
        if trendData.count > maxTrendSize {
            trendData.removeFirst()
        }
    }
    
    func predict(for timeInterval: TimeInterval, history: [MemorySnapshot]) -> MemoryPrediction {
        guard !trendData.isEmpty else {
            return MemoryPrediction(predictedUsage: 0, confidence: 0, timeToThreshold: nil)
        }
        
        // Simple linear regression for prediction
        let trend = calculateTrend()
        let currentUsage = trendData.last ?? 0
        let predictedUsage = min(1.0, max(0.0, currentUsage + trend * timeInterval))
        
        // Calculate confidence based on data stability
        let confidence = calculateConfidence()
        
        // Estimate time to threshold
        let timeToThreshold = calculateTimeToThreshold(currentUsage: currentUsage, trend: trend)
        
        return MemoryPrediction(
            predictedUsage: predictedUsage,
            confidence: confidence,
            timeToThreshold: timeToThreshold
        )
    }
    
    private func calculateTrend() -> Double {
        guard trendData.count >= 2 else { return 0 }
        
        let recentData = Array(trendData.suffix(10))
        var totalTrend: Double = 0
        
        for i in 1..<recentData.count {
            totalTrend += recentData[i] - recentData[i-1]
        }
        
        return totalTrend / Double(recentData.count - 1)
    }
    
    private func calculateConfidence() -> Double {
        guard trendData.count >= 3 else { return 0 }
        
        let recentData = Array(trendData.suffix(10))
        let mean = recentData.reduce(0, +) / Double(recentData.count)
        let variance = recentData.map { pow($0 - mean, 2) }.reduce(0, +) / Double(recentData.count)
        
        // Lower variance = higher confidence
        return max(0, 1 - variance)
    }
    
    private func calculateTimeToThreshold(currentUsage: Double, trend: Double) -> TimeInterval? {
        let threshold = 0.8
        guard trend > 0 && currentUsage < threshold else { return nil }
        
        return (threshold - currentUsage) / trend
    }
}

// MARK: - Memory Prediction

struct MemoryPrediction: Sendable {
    let predictedUsage: Double
    let confidence: Double
    let timeToThreshold: TimeInterval?
    
    var riskLevel: MemoryRiskLevel {
        switch predictedUsage {
        case 0..<0.6:
            return .low
        case 0.6..<0.8:
            return .medium
        default:
            return .high
        }
    }
}

// MARK: - Memory Risk Level

enum MemoryRiskLevel: Sendable {
    case low
    case medium
    case high
}

// MARK: - Memory Optimization Level

enum MemoryOptimizationLevel: Sendable {
    case conservative
    case normal
    case aggressive
}

// MARK: - iOS 26+ Memory Compaction Level

@available(iOS 26.0, *)
enum MemoryCompactionLevel: Sendable {
    case light
    case moderate
    case aggressive
}

// MARK: - Notification Extension

extension Notification.Name {
    static let memoryCleanupRequested = Notification.Name("memoryCleanupRequested")
}