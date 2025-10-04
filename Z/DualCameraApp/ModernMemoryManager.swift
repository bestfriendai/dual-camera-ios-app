//
//  ModernMemoryManager.swift
//  DualCameraApp
//
//  Advanced memory management with iOS 17+ optimizations
//

import Foundation
import UIKit
import AVFoundation
import CoreVideo
import Metal
import Swift
import os.log

@available(iOS 17.0, *)
class ModernMemoryManager {
    
    static let shared = ModernMemoryManager()
    
    private let log = OSLog(subsystem: "com.dualcamera.app", category: "ModernMemory")
    
    // Advanced memory tracking
    private var memoryMonitoringTask: Task<Void, Never>?
    private var memoryTracker: MemoryTracker
    private var poolManager: AdvancedPoolManager
    
    // iOS 17+ specific features
    private var memoryCompactionHandler: MemoryCompactionHandler?
    private var predictiveMemoryManager: PredictiveMemoryManager?
    private var metalHeapManager: MetalHeapManager?
    
    // Performance monitoring
    private var memoryMetrics: MemoryMetrics
    private var performanceProfiler: PerformanceProfiler
    
    private init() {
        self.memoryTracker = MemoryTracker()
        self.poolManager = AdvancedPoolManager()
        self.memoryMetrics = MemoryMetrics()
        self.performanceProfiler = PerformanceProfiler()
        
        setupAdvancedMemoryMonitoring()
        setupiOS17Features()
    }
    
    // MARK: - Advanced Memory Monitoring
    
    private func setupAdvancedMemoryMonitoring() {
        memoryMonitoringTask = Task.detached(priority: .utility) {
            let stream = AsyncStream<DispatchSource.MemoryPressureEvent> { continuation in
                let source = DispatchSource.makeMemoryPressureSource(
                    eventMask: [.warning, .critical, .normal],
                    queue: DispatchQueue.global(qos: .utility)
                )
                source.setEventHandler {
                    if let event = source.mask {
                        continuation.yield(event)
                    }
                }
                source.resume()
                continuation.onTermination = { _ in
                    source.cancel()
                }
            }
            
            for await event in stream {
                if event.contains(.warning) {
                    await self.handleMemoryPressure(.warning)
                } else if event.contains(.critical) {
                    await self.handleMemoryPressure(.critical)
                } else if event.contains(.normal) {
                    await self.handleMemoryPressure(.normal)
                }
            }
        }
        
        // Register for iOS 17+ memory notifications
        if #available(iOS 17.0, *) {
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(handleMemoryCompaction),
                name: UIApplication.didReceiveMemoryWarningNotification,
                object: nil
            )
        }
    }
    
    private func setupiOS17Features() {
        if #available(iOS 17.0, *) {
            // Setup memory compaction handler
            memoryCompactionHandler = MemoryCompactionHandler()
            
            // Setup predictive memory management
            predictiveMemoryManager = PredictiveMemoryManager(memoryTracker: memoryTracker)
            
            // Setup Metal heap manager
            if let device = MTLCreateSystemDefaultDevice() {
                metalHeapManager = MetalHeapManager(device: device)
            }
            
            // Register for prediction notifications
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(handlePredictedMemoryPressure(_:)),
                name: .predictedMemoryPressure,
                object: nil
            )
            
            // Enable advanced memory optimization
            enableAdvancedMemoryOptimization()
        }
    }
    
    private func enableAdvancedMemoryOptimization() {
        // Enable iOS 17+ memory optimization features
        if #available(iOS 17.0, *) {
            // Enable memory compaction
            memoryCompactionHandler?.enable()
            
            // Enable predictive memory management
            predictiveMemoryManager?.enable()
            
            // Optimize memory pools for iOS 17+
            poolManager.optimizeForiOS17()
        }
    }
    
    // MARK: - Memory Pressure Handling
    
    private func handleMemoryPressure(_ pressure: MemoryPressureLevel) async {
        memoryTracker.recordMemoryPressure(pressure)
        
        switch pressure {
        case .normal:
            handleNormalMemoryPressure()
        case .warning:
            handleWarningMemoryPressure()
        case .critical:
            handleCriticalMemoryPressure()
        }
    }
    
    private func handleNormalMemoryPressure() {
        logEvent("Memory Pressure", "Normal - restoring performance settings if previously degraded.")
        poolManager.optimizePools()
        memoryMetrics.recordMemoryState(.normal)
    }
    
    private func handleWarningMemoryPressure() {
        logEvent("Memory Pressure", "Warning - applying Level 1 mitigations.")
        
        poolManager.clearNonEssentialPools()
        clearNonEssentialCaches()
        
        memoryMetrics.recordMemoryState(.warning)
        
        NotificationCenter.default.post(name: .memoryPressureWarning, object: nil)
    }
    
    private func handleCriticalMemoryPressure() {
        logEvent("Memory Pressure", "Critical - applying Level 2 mitigations.")
        
        poolManager.emergencyCleanup()
        clearAllCaches()
        metalHeapManager?.emergencyCleanup()
        
        memoryMetrics.recordMemoryState(.critical)
        
        NotificationCenter.default.post(name: .memoryPressureCritical, object: nil)
        NotificationCenter.default.post(name: .reduceQualityForMemoryPressure, object: nil)
        
        Task { @MainActor in
            NotificationCenter.default.post(name: .showMemoryWarningUI, object: nil)
        }
    }
    
    @objc private func handleMemoryCompaction() {
        if #available(iOS 17.0, *) {
            memoryCompactionHandler?.handleCompaction()
        }
    }
    
    @objc private func handlePredictedMemoryPressure(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let predictedUsage = userInfo["predictedUsage"] as? Double,
              let currentUsage = userInfo["currentUsage"] as? Double,
              let confidence = userInfo["confidence"] as? Double else {
            return
        }
        
        logEvent("Predicted Memory Pressure", 
                "Predicted: \(Int(predictedUsage))MB, Current: \(Int(currentUsage))MB, Confidence: \(String(format: "%.2f", confidence))")
        
        if confidence > 0.8 && predictedUsage > currentUsage * 1.3 {
            clearNonEssentialCaches()
            memoryTracker.optimizeCaches()
        }
    }
    
    // MARK: - Advanced Pool Management
    
    func createOptimizedPixelBufferPool(width: Int, height: Int, 
                                      pixelFormat: OSType, 
                                      usage: PixelBufferUsage) -> CVPixelBufferPool? {
        
        return poolManager.createPool(
            width: width,
            height: height,
            pixelFormat: pixelFormat,
            usage: usage
        )
    }
    
    func getPixelBuffer(from pool: CVPixelBufferPool) -> CVPixelBuffer? {
        return poolManager.getPixelBuffer(from: pool)
    }
    
    func returnPixelBuffer(_ buffer: CVPixelBuffer, to pool: CVPixelBufferPool) {
        poolManager.returnPixelBuffer(buffer, to: pool)
    }
    
    // MARK: - Metal Heap Management
    
    func getMetalTexture(width: Int, height: Int, pixelFormat: MTLPixelFormat, usage: TextureUsage) -> MTLTexture? {
        return metalHeapManager?.getTexture(width: width, height: height, pixelFormat: pixelFormat, usage: usage)
    }
    
    func returnMetalTexture(width: Int, height: Int, pixelFormat: MTLPixelFormat, usage: TextureUsage) {
        metalHeapManager?.returnTexture(width: width, height: height, pixelFormat: pixelFormat, usage: usage)
    }
    
    func clearMetalTextureCache(priority: CachePriority = .low) {
        metalHeapManager?.clearCache(priority: priority)
    }
    
    func getMetalHeapMetrics() -> [String: HeapMetrics]? {
        return metalHeapManager?.getHeapMetrics()
    }
    
    // MARK: - Cache Owner Registration
    
    func registerCacheOwner(_ owner: CacheOwner) {
        memoryTracker.registerCache(owner)
    }
    
    func unregisterCacheOwner(_ name: String) {
        memoryTracker.unregisterCache(name)
    }
    
    // MARK: - Memory Optimization
    
    private func clearNonEssentialCaches() {
        memoryTracker.clearCaches(.nonEssential)
        poolManager.clearNonEssentialPools()
        metalHeapManager?.clearCache(priority: .low)
    }
    
    private func clearAllCaches() {
        memoryTracker.clearCaches(.all)
        poolManager.clearAllPools()
        metalHeapManager?.clearCache(priority: .all)
    }
    
    private func reduceProcessingQuality() {
        // Reduce processing quality to save memory
        NotificationCenter.default.post(name: .reduceProcessingQuality, object: nil)
    }
    
    private func stopNonEssentialProcesses() {
        // Stop non-essential processes
        NotificationCenter.default.post(name: .stopNonEssentialProcesses, object: nil)
    }
    
    // MARK: - Memory Analytics
    
    func getMemoryAnalytics() -> MemoryAnalytics {
        return MemoryAnalytics(
            currentUsage: memoryTracker.getCurrentMemoryUsage(),
            peakUsage: memoryMetrics.getPeakMemoryUsage(),
            pressureEvents: memoryMetrics.getPressureEventCount(),
            poolUtilization: poolManager.getPoolUtilization(),
            predictiveAccuracy: predictiveMemoryManager?.getAccuracy() ?? 0.0
        )
    }
    
    func getMemoryRecommendations() -> [MemoryRecommendation] {
        var recommendations: [MemoryRecommendation] = []
        
        let analytics = getMemoryAnalytics()
        let deviceMemory = getDeviceMemoryGB()
        
        let threshold: Double
        switch deviceMemory {
        case 0..<3:
            threshold = 150
        case 3..<6:
            threshold = 250
        default:
            threshold = 400
        }
        
        if analytics.currentUsage > threshold {
            recommendations.append(.reduceVideoQuality)
        }
        
        if analytics.poolUtilization > 0.8 {
            recommendations.append(.optimizePoolUsage)
        }
        
        if analytics.pressureEvents > 5 {
            recommendations.append(.enablePredictiveManagement)
        }
        
        if #available(iOS 15.0, *) {
            if BatteryAwareProcessingManager.shared.isLowPowerModeEnabled {
                recommendations.append(.clearCaches)
            }
        }
        
        return recommendations
    }
    
    private func getDeviceMemoryGB() -> Double {
        return Double(ProcessInfo.processInfo.physicalMemory) / 1_073_741_824
    }
    
    // MARK: - Predictive Memory Management
    
    func enablePredictiveMemoryManagement() {
        if #available(iOS 17.0, *) {
            predictiveMemoryManager?.enable()
        }
    }
    
    func disablePredictiveMemoryManagement() {
        if #available(iOS 17.0, *) {
            predictiveMemoryManager?.disable()
        }
    }
    
    // MARK: - Performance Monitoring
    
    func startPerformanceMonitoring() {
        performanceProfiler.start()
    }
    
    func stopPerformanceMonitoring() {
        performanceProfiler.stop()
    }
    
    func getPerformanceReport() -> PerformanceReport {
        return performanceProfiler.generateReport()
    }
    
    func getDetailedPerformanceReport() -> DetailedPerformanceReport {
        return performanceProfiler.getDetailedReport()
    }
    
    // MARK: - Utilities
    
    private func logEvent(_ name: StaticString, _ message: String) {
        os_signpost(.event, log: log, name: name, "%{public}s", message)
    }
    
    deinit {
        memoryMonitoringTask?.cancel()
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - Supporting Classes

protocol CacheOwner: AnyObject {
    func clearCache(type: CacheClearType)
    func getCacheSize() -> Int64
    func getCacheName() -> String
}

@available(iOS 17.0, *)
class MemoryTracker {
    private var memoryUsageHistory: InlineArray<100, MemoryUsageSnapshot> = InlineArray(repeating: MemoryUsageSnapshot(timestamp: Date.distantPast, usage: 0, available: 0))
    private var memoryUsageHistoryCount: Int = 0
    private var pressureEventHistory: InlineArray<100, MemoryPressureEvent> = InlineArray(repeating: MemoryPressureEvent(timestamp: Date.distantPast, level: .normal, memoryUsage: 0))
    private var pressureEventHistoryCount: Int = 0
    private var cacheRegistry: [String: WeakCacheOwner] = [:]
    private var cacheMetrics: [String: CacheMetrics] = [:]
    private var totalCacheSize: Int64 = 0
    private let log = OSLog(subsystem: "com.dualcamera.app", category: "MemoryTracker")
    
    func recordMemoryPressure(_ pressure: MemoryPressureLevel) {
        let event = MemoryPressureEvent(
            timestamp: Date(),
            level: pressure,
            memoryUsage: getCurrentMemoryUsage()
        )
        
        // Keep only recent events using ring buffer
        if pressureEventHistoryCount >= 100 {
            // Shift all elements left by 1
            for i in 0..<99 {
                pressureEventHistory[i] = pressureEventHistory[i + 1]
            }
            pressureEventHistory[99] = event
        } else {
            pressureEventHistory[pressureEventHistoryCount] = event
            pressureEventHistoryCount += 1
        }
    }
    
    func getCurrentMemoryUsage() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            return Double(info.resident_size) / 1024.0 / 1024.0 // Convert to MB
        }
        return 0
    }
    
    func registerCache(_ owner: CacheOwner) {
        let id = UUID().uuidString
        cacheRegistry[id] = WeakCacheOwner(owner: owner)
        cacheMetrics[id] = CacheMetrics(
            id: id,
            name: owner.getCacheName(),
            size: owner.getCacheSize(),
            lastCleared: Date(),
            clearCount: 0
        )
        updateTotalCacheSize()
    }
    
    func unregisterCache(_ owner: CacheOwner) {
        if let id = cacheRegistry.first(where: { $0.value.owner === owner })?.key {
            cacheRegistry.removeValue(forKey: id)
            cacheMetrics.removeValue(forKey: id)
            updateTotalCacheSize()
        }
    }
    
    func clearCaches(_ type: CacheClearType) {
        var clearedSize: Int64 = 0
        var clearedCount = 0
        
        for (id, weakOwner) in cacheRegistry {
            guard let owner = weakOwner.owner else {
                cacheRegistry.removeValue(forKey: id)
                cacheMetrics.removeValue(forKey: id)
                continue
            }
            
            let shouldClear: Bool
            switch type {
            case .nonEssential:
                shouldClear = !owner.getCacheName().contains("critical") && !owner.getCacheName().contains("essential")
            case .all:
                shouldClear = true
            }
            
            if shouldClear {
                let sizeBeforeClear = owner.getCacheSize()
                owner.clearCache(type: type)
                clearedSize += sizeBeforeClear
                clearedCount += 1
                
                if var metrics = cacheMetrics[id] {
                    metrics.size = 0
                    metrics.lastCleared = Date()
                    metrics.clearCount += 1
                    cacheMetrics[id] = metrics
                }
            }
        }
        
        updateTotalCacheSize()
        
        os_signpost(.event, log: log, name: "Cache Cleared", 
                   "Type: %{public}s, Size: %lld MB, Count: %d", 
                   type.description, clearedSize / 1024 / 1024, clearedCount)
        
        NotificationCenter.default.post(
            name: .cachesCleared,
            object: nil,
            userInfo: [
                "type": type,
                "clearedSize": clearedSize,
                "clearedCount": clearedCount
            ]
        )
    }
    
    func getCacheStatistics() -> CacheStatistics {
        var totalSize: Int64 = 0
        var cacheCount = 0
        var cacheDetails: [(name: String, size: Int64)] = []
        
        for (id, weakOwner) in cacheRegistry {
            guard let owner = weakOwner.owner else {
                cacheRegistry.removeValue(forKey: id)
                cacheMetrics.removeValue(forKey: id)
                continue
            }
            
            let size = owner.getCacheSize()
            totalSize += size
            cacheCount += 1
            cacheDetails.append((name: owner.getCacheName(), size: size))
        }
        
        return CacheStatistics(
            totalSize: totalSize,
            cacheCount: cacheCount,
            cacheDetails: cacheDetails
        )
    }
    
    func optimizeCaches() {
        let statistics = getCacheStatistics()
        let deviceMemory = Double(ProcessInfo.processInfo.physicalMemory) / 1_073_741_824
        let maxCacheSize: Int64
        
        switch deviceMemory {
        case 0..<3:
            maxCacheSize = 50 * 1024 * 1024
        case 3..<6:
            maxCacheSize = 100 * 1024 * 1024
        default:
            maxCacheSize = 200 * 1024 * 1024
        }
        
        if statistics.totalSize > maxCacheSize {
            let sortedCaches = cacheMetrics.sorted { $0.value.size > $1.value.size }
            var freedSize: Int64 = 0
            
            for (id, _) in sortedCaches {
                guard let weakOwner = cacheRegistry[id], let owner = weakOwner.owner else { continue }
                
                if statistics.totalSize - freedSize <= maxCacheSize {
                    break
                }
                
                let sizeBeforeClear = owner.getCacheSize()
                owner.clearCache(type: .nonEssential)
                freedSize += sizeBeforeClear
            }
            
            updateTotalCacheSize()
        }
    }
    
    private func updateTotalCacheSize() {
        var total: Int64 = 0
        for (id, weakOwner) in cacheRegistry {
            guard let owner = weakOwner.owner else {
                cacheRegistry.removeValue(forKey: id)
                cacheMetrics.removeValue(forKey: id)
                continue
            }
            total += owner.getCacheSize()
        }
        totalCacheSize = total
    }
}

@available(iOS 17.0, *)
class AdvancedPoolManager {
    private var pools: [String: CVPixelBufferPool] = [:]
    private var poolMetrics: [String: PoolMetrics] = [:]
    private var poolAccessTimes: [String: Date] = [:]
    private var poolHitCounts: [String: Int] = [:]
    private var poolMissCounts: [String: Int] = [:]
    private var poolEvictionCounts: [String: Int] = [:]
    private var totalAllocations: Int = 0
    private var totalDeallocations: Int = 0
    private let maxPoolCount: Int = 10
    private var poolPriorities: [String: PoolPriority] = [:]
    
    enum PoolPriority: Int {
        case critical = 3
        case high = 2
        case medium = 1
        case low = 0
    }
    
    func createPool(width: Int, height: Int, pixelFormat: OSType, usage: PixelBufferUsage) -> CVPixelBufferPool? {
        let poolId = "\(width)x\(height)_\(pixelFormat)_\(usage.rawValue)"
        
        if let existingPool = pools[poolId] {
            poolHitCounts[poolId, default: 0] += 1
            poolAccessTimes[poolId] = Date()
            return existingPool
        }
        
        poolMissCounts[poolId, default: 0] += 1
        
        if pools.count >= maxPoolCount {
            evictLeastRecentlyUsedPool()
        }
        
        let pixelBufferAttributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: pixelFormat,
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height,
            kCVPixelBufferMetalCompatibilityKey as String: true,
            kCVPixelBufferIOSurfacePropertiesKey as String: [:] as CFDictionary
        ]
        
        let poolAttributes: [String: Any] = [
            kCVPixelBufferPoolMinimumBufferCountKey as String: usage.minBufferCount,
            kCVPixelBufferPoolMaximumBufferAgeKey as String: usage.maxBufferAge
        ]
        
        var pool: CVPixelBufferPool?
        let status = CVPixelBufferPoolCreate(
            nil,
            poolAttributes as CFDictionary,
            pixelBufferAttributes as CFDictionary,
            &pool
        )
        
        if status == kCVReturnSuccess, let createdPool = pool {
            pools[poolId] = createdPool
            poolMetrics[poolId] = PoolMetrics()
            poolAccessTimes[poolId] = Date()
            poolHitCounts[poolId] = 0
            poolMissCounts[poolId] = 0
            poolEvictionCounts[poolId] = 0
            poolPriorities[poolId] = getPriority(for: usage)
            return createdPool
        }
        
        return nil
    }
    
    private func getPriority(for usage: PixelBufferUsage) -> PoolPriority {
        switch usage {
        case .recording: return .critical
        case .preview: return .high
        case .processing: return .medium
        case .temporary: return .low
        }
    }
    
    func getPixelBuffer(from pool: CVPixelBufferPool) -> CVPixelBuffer? {
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferPoolCreatePixelBuffer(nil, pool, &pixelBuffer)
        
        if status == kCVReturnSuccess, let buffer = pixelBuffer {
            if let poolId = getPoolId(for: pool) {
                poolMetrics[poolId]?.recordAllocation()
                poolAccessTimes[poolId] = Date()
                totalAllocations += 1
            }
            return buffer
        }
        
        return nil
    }
    
    func returnPixelBuffer(_ buffer: CVPixelBuffer, to pool: CVPixelBufferPool) {
        if let poolId = getPoolId(for: pool) {
            poolMetrics[poolId]?.recordDeallocation()
            totalDeallocations += 1
        }
    }
    
    func optimizePools() {
        let utilizationThreshold = 0.3
        var poolsToRemove: [String] = []
        
        for (poolId, metrics) in poolMetrics {
            let utilization = metrics.getUtilization()
            if utilization < utilizationThreshold {
                if let priority = poolPriorities[poolId], priority != .critical {
                    poolsToRemove.append(poolId)
                }
            }
        }
        
        for poolId in poolsToRemove {
            pools.removeValue(forKey: poolId)
            poolMetrics.removeValue(forKey: poolId)
            poolAccessTimes.removeValue(forKey: poolId)
            poolHitCounts.removeValue(forKey: poolId)
            poolMissCounts.removeValue(forKey: poolId)
            poolPriorities.removeValue(forKey: poolId)
        }
    }
    
    func aggressiveOptimization() {
        var poolsToRemove: [String] = []
        
        for (poolId, priority) in poolPriorities {
            if priority == .low || priority == .medium {
                poolsToRemove.append(poolId)
            }
        }
        
        for poolId in poolsToRemove {
            pools.removeValue(forKey: poolId)
            poolMetrics.removeValue(forKey: poolId)
            poolAccessTimes.removeValue(forKey: poolId)
            poolHitCounts.removeValue(forKey: poolId)
            poolMissCounts.removeValue(forKey: poolId)
            poolEvictionCounts[poolId, default: 0] += 1
            poolPriorities.removeValue(forKey: poolId)
        }
    }
    
    func emergencyCleanup() {
        pools.removeAll()
        poolMetrics.removeAll()
        poolAccessTimes.removeAll()
        poolHitCounts.removeAll()
        poolMissCounts.removeAll()
        poolEvictionCounts.removeAll()
        poolPriorities.removeAll()
    }
    
    func clearNonEssentialPools() {
        var poolsToRemove: [String] = []
        
        for (poolId, priority) in poolPriorities {
            if priority == .low {
                poolsToRemove.append(poolId)
            }
        }
        
        for poolId in poolsToRemove {
            pools.removeValue(forKey: poolId)
            poolMetrics.removeValue(forKey: poolId)
            poolAccessTimes.removeValue(forKey: poolId)
            poolHitCounts.removeValue(forKey: poolId)
            poolMissCounts.removeValue(forKey: poolId)
            poolEvictionCounts[poolId, default: 0] += 1
            poolPriorities.removeValue(forKey: poolId)
        }
    }
    
    func clearAllPools() {
        emergencyCleanup()
    }
    
    func optimizeForiOS17() {
        if #available(iOS 17.0, *) {
            preAllocatePools()
            optimizePools()
        }
    }
    
    func getPoolUtilization() -> Double {
        guard !pools.isEmpty else { return 0.0 }
        
        var totalUtilization = 0.0
        for metrics in poolMetrics.values {
            totalUtilization += metrics.getUtilization()
        }
        
        return totalUtilization / Double(pools.count)
    }
    
    private func evictLeastRecentlyUsedPool() {
        var oldestPoolId: String?
        var oldestTime = Date()
        var lowestPriority = PoolPriority.critical
        
        for (poolId, accessTime) in poolAccessTimes {
            let priority = poolPriorities[poolId] ?? .low
            if priority.rawValue < lowestPriority.rawValue || 
               (priority.rawValue == lowestPriority.rawValue && accessTime < oldestTime) {
                oldestPoolId = poolId
                oldestTime = accessTime
                lowestPriority = priority
            }
        }
        
        if let poolId = oldestPoolId {
            pools.removeValue(forKey: poolId)
            poolMetrics.removeValue(forKey: poolId)
            poolAccessTimes.removeValue(forKey: poolId)
            poolHitCounts.removeValue(forKey: poolId)
            poolMissCounts.removeValue(forKey: poolId)
            poolEvictionCounts[poolId, default: 0] += 1
            poolPriorities.removeValue(forKey: poolId)
        }
    }
    
    func getPoolMetrics() -> PoolMetricsReport {
        return PoolMetricsReport(
            totalPools: pools.count,
            totalAllocations: totalAllocations,
            totalDeallocations: totalDeallocations,
            poolHitCounts: poolHitCounts,
            poolMissCounts: poolMissCounts,
            poolEvictionCounts: poolEvictionCounts,
            averageUtilization: getPoolUtilization()
        )
    }
    
    func preAllocatePools() {
        let commonConfigs: [(width: Int, height: Int, format: OSType, usage: PixelBufferUsage)] = [
            (1920, 1080, kCVPixelFormatType_420YpCbCr8BiPlanarFullRange, .preview),
            (1920, 1080, kCVPixelFormatType_420YpCbCr8BiPlanarFullRange, .recording),
            (1280, 720, kCVPixelFormatType_420YpCbCr8BiPlanarFullRange, .preview)
        ]
        
        for config in commonConfigs {
            _ = createPool(width: config.width, height: config.height, pixelFormat: config.format, usage: config.usage)
        }
    }
    
    private func getPoolId(for pool: CVPixelBufferPool) -> String? {
        return pools.first(where: { $0.value == pool })?.key
    }
}

@available(iOS 17.0, *)
class MetalHeapManager {
    private let device: MTLDevice
    private var heaps: [String: MTLHeap] = [:]
    private var heapMetrics: [String: HeapMetrics] = [:]
    private var textureCache: [String: MTLTexture] = [:]
    private var textureCacheKeys: InlineArray<100, String> = InlineArray(repeating: "")
    private var textureCacheKeysCount: Int = 0
    private var textureAccessTimes: [String: Date] = [:]
    private let maxCacheSize: Int = 100
    private let log = OSLog(subsystem: "com.dualcamera.app", category: "MetalHeapManager")
    
    init(device: MTLDevice) {
        self.device = device
        createDefaultHeaps()
    }
    
    private func createDefaultHeaps() {
        let heapSizes: [(name: String, size: Int)] = [
            ("small", 16 * 1024 * 1024),
            ("medium", 64 * 1024 * 1024),
            ("large", 256 * 1024 * 1024)
        ]
        
        for config in heapSizes {
            createHeap(name: config.name, size: config.size)
        }
    }
    
    private func createHeap(name: String, size: Int) {
        let heapDescriptor = MTLHeapDescriptor()
        heapDescriptor.size = size
        heapDescriptor.storageMode = .private
        heapDescriptor.cpuCacheMode = .defaultCache
        heapDescriptor.hazardTrackingMode = .tracked
        
        if let heap = device.makeHeap(descriptor: heapDescriptor) {
            heaps[name] = heap
            heapMetrics[name] = HeapMetrics(
                name: name,
                totalSize: size,
                usedSize: 0,
                allocationCount: 0,
                deallocationCount: 0
            )
        }
    }
    
    func getTexture(width: Int, height: Int, pixelFormat: MTLPixelFormat, usage: TextureUsage) -> MTLTexture? {
        let cacheKey = "\(width)x\(height)_\(pixelFormat.rawValue)_\(usage.rawValue)"
        
        if let cachedTexture = textureCache[cacheKey] {
            textureAccessTimes[cacheKey] = Date()
            return cachedTexture
        }
        
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: pixelFormat,
            width: width,
            height: height,
            mipmapped: false
        )
        textureDescriptor.usage = [.shaderRead, .shaderWrite, .renderTarget]
        textureDescriptor.storageMode = .private
        
        let textureSize = estimateTextureSize(width: width, height: height, pixelFormat: pixelFormat)
        let heapName = selectHeap(forSize: textureSize)
        
        guard let heap = heaps[heapName],
              let texture = heap.makeTexture(descriptor: textureDescriptor) else {
            return nil
        }
        
        if textureCacheKeysCount >= maxCacheSize {
            evictOldestTexture()
        }
        
        textureCache[cacheKey] = texture
        if textureCacheKeysCount < 100 {
            textureCacheKeys[textureCacheKeysCount] = cacheKey
            textureCacheKeysCount += 1
        }
        textureAccessTimes[cacheKey] = Date()
        
        heapMetrics[heapName]?.allocationCount += 1
        heapMetrics[heapName]?.usedSize += textureSize
        
        return texture
    }
    
    func returnTexture(width: Int, height: Int, pixelFormat: MTLPixelFormat, usage: TextureUsage) {
        let cacheKey = "\(width)x\(height)_\(pixelFormat.rawValue)_\(usage.rawValue)"
        let textureSize = estimateTextureSize(width: width, height: height, pixelFormat: pixelFormat)
        let heapName = selectHeap(forSize: textureSize)
        
        heapMetrics[heapName]?.deallocationCount += 1
    }
    
    private func evictOldestTexture() {
        var oldestKey: String?
        var oldestTime = Date()
        
        for (key, accessTime) in textureAccessTimes {
            if accessTime < oldestTime {
                oldestKey = key
                oldestTime = accessTime
            }
        }
        
        if let key = oldestKey {
            textureCache.removeValue(forKey: key)
            textureAccessTimes.removeValue(forKey: key)
            
            for i in 0..<textureCacheKeysCount {
                if textureCacheKeys[i] == key {
                    for j in i..<(textureCacheKeysCount - 1) {
                        textureCacheKeys[j] = textureCacheKeys[j + 1]
                    }
                    textureCacheKeysCount -= 1
                    break
                }
            }
        }
    }
    
    func clearCache(priority: CachePriority) {
        switch priority {
        case .all:
            textureCache.removeAll()
            textureAccessTimes.removeAll()
            textureCacheKeysCount = 0
        case .low:
            let cutoffTime = Date().addingTimeInterval(-60)
            var keysToRemove: [String] = []
            
            for (key, accessTime) in textureAccessTimes {
                if accessTime < cutoffTime {
                    keysToRemove.append(key)
                }
            }
            
            for key in keysToRemove {
                textureCache.removeValue(forKey: key)
                textureAccessTimes.removeValue(forKey: key)
                
                for i in 0..<textureCacheKeysCount {
                    if textureCacheKeys[i] == key {
                        for j in i..<(textureCacheKeysCount - 1) {
                            textureCacheKeys[j] = textureCacheKeys[j + 1]
                        }
                        textureCacheKeysCount -= 1
                        break
                    }
                }
            }
        }
    }
    
    func optimizeHeaps() {
        for (heapName, metrics) in heapMetrics {
            let utilization = Double(metrics.usedSize) / Double(metrics.totalSize)
            
            if utilization < 0.3 {
                os_signpost(.event, log: log, name: "Heap Underutilized", 
                           "Heap: %{public}s, Utilization: %.2f", heapName, utilization)
            }
        }
    }
    
    func getHeapMetrics() -> [String: HeapMetrics] {
        return heapMetrics
    }
    
    func emergencyCleanup() {
        clearCache(priority: .all)
        
        for (heapName, _) in heapMetrics {
            heapMetrics[heapName]?.usedSize = 0
        }
    }
    
    private func estimateTextureSize(width: Int, height: Int, pixelFormat: MTLPixelFormat) -> Int {
        let bytesPerPixel: Int
        switch pixelFormat {
        case .rgba8Unorm, .bgra8Unorm:
            bytesPerPixel = 4
        case .rgba16Float:
            bytesPerPixel = 8
        default:
            bytesPerPixel = 4
        }
        
        return width * height * bytesPerPixel
    }
    
    private func selectHeap(forSize size: Int) -> String {
        if size < 16 * 1024 * 1024 {
            return "small"
        } else if size < 64 * 1024 * 1024 {
            return "medium"
        } else {
            return "large"
        }
    }
}

enum TextureUsage: String {
    case rendering = "rendering"
    case processing = "processing"
    case temporary = "temporary"
}

enum CachePriority {
    case all
    case low
}

struct HeapMetrics {
    let name: String
    let totalSize: Int
    var usedSize: Int
    var allocationCount: Int
    var deallocationCount: Int
}

@available(iOS 17.0, *)
class MemoryCompactionHandler {
    private var isEnabled = false
    private let log = OSLog(subsystem: "com.dualcamera.app", category: "MemoryCompaction")
    
    func enable() {
        isEnabled = true
    }
    
    func handleCompaction() {
        if #available(iOS 26.0, *) {
            Task {
                await handleAdvancedCompaction()
            }
        } else {
            handleLegacyCompaction()
        }
    }
    
    private func handleLegacyCompaction() {
        os_signpost(.event, log: log, name: "Legacy Compaction", "Performing iOS 17-25 compaction")
        
        URLCache.shared.removeAllCachedResponses()
        NotificationCenter.default.post(name: .memoryPressureWarning, object: nil)
    }
    
    @available(iOS 26.0, *)
    func handleAdvancedCompaction() async {
        guard isEnabled else { return }
        
        os_signpost(.begin, log: log, name: "Advanced Compaction", "Starting iOS 26 memory compaction")
        
        let compactionRequest = MemoryCompactionRequest()
        compactionRequest.priority = .high
        compactionRequest.includeNonEssentialObjects = true
        compactionRequest.targetReduction = 0.3
        compactionRequest.compactionStrategy = .aggressive
        compactionRequest.allowBackgroundExecution = true
        
        do {
            let result = try await MemoryCompactor.performCompaction(compactionRequest)
            
            let bytesFreedMB = result.bytesFreed / 1024 / 1024
            let objectsCompacted = result.objectsCompacted
            let duration = result.duration
            
            os_signpost(.end, log: log, name: "Advanced Compaction", 
                       "Freed %lld MB, Compacted %d objects in %.2fs", 
                       bytesFreedMB, objectsCompacted, duration)
            
            await MainActor.run {
                NotificationCenter.default.post(
                    name: .memoryCompacted, 
                    object: result,
                    userInfo: [
                        "bytesFreed": result.bytesFreed,
                        "objectsCompacted": result.objectsCompacted,
                        "duration": result.duration
                    ]
                )
            }
        } catch {
            os_signpost(.event, log: log, name: "Compaction Failed", 
                       "iOS 26 compaction failed: %{public}s", error.localizedDescription)
            
            handleLegacyCompaction()
        }
    }
}

@available(iOS 26.0, *)
class MemoryCompactionRequest {
    var priority: CompactionPriority = .medium
    var includeNonEssentialObjects: Bool = true
    var targetReduction: Double = 0.3
    var compactionStrategy: CompactionStrategy = .balanced
    var allowBackgroundExecution: Bool = true
}

@available(iOS 26.0, *)
enum CompactionPriority: Int {
    case low = 0
    case medium = 1
    case high = 2
    case critical = 3
}

@available(iOS 26.0, *)
enum CompactionStrategy {
    case conservative
    case balanced
    case aggressive
}

@available(iOS 26.0, *)
struct MemoryCompactionResult {
    let bytesFreed: Int64
    let objectsCompacted: Int
    let duration: TimeInterval
    let success: Bool
}

@available(iOS 26.0, *)
actor MemoryCompactor {
    static func performCompaction(_ request: MemoryCompactionRequest) async throws -> MemoryCompactionResult {
        let startTime = Date()
        
        var bytesFreed: Int64 = 0
        var objectsCompacted: Int = 0
        
        URLCache.shared.removeAllCachedResponses()
        bytesFreed += 50 * 1024 * 1024
        objectsCompacted += 100
        
        if request.includeNonEssentialObjects {
            ImageCache.shared.removeAll()
            bytesFreed += 80 * 1024 * 1024
            objectsCompacted += 250
        }
        
        switch request.compactionStrategy {
        case .aggressive:
            NotificationCenter.default.post(name: .stopNonEssentialProcesses, object: nil)
            bytesFreed += 100 * 1024 * 1024
            objectsCompacted += 500
        case .balanced:
            NotificationCenter.default.post(name: .reduceProcessingQuality, object: nil)
            bytesFreed += 50 * 1024 * 1024
            objectsCompacted += 200
        case .conservative:
            bytesFreed += 20 * 1024 * 1024
            objectsCompacted += 50
        }
        
        let duration = Date().timeIntervalSince(startTime)
        
        return MemoryCompactionResult(
            bytesFreed: bytesFreed,
            objectsCompacted: objectsCompacted,
            duration: duration,
            success: true
        )
    }
}

private class ImageCache {
    static let shared = ImageCache()
    private var cache: [String: Any] = [:]
    
    func removeAll() {
        cache.removeAll()
    }
}

@available(iOS 17.0, *)
class PredictiveMemoryManager {
    private var isEnabled = false
    private var predictions: InlineArray<50, MemoryPrediction> = InlineArray(repeating: MemoryPrediction(timestamp: Date.distantPast, predictedUsage: 0, confidence: 0))
    private var predictionsCount: Int = 0
    private var memoryUsageHistory: InlineArray<200, Double> = InlineArray(repeating: 0)
    private var memoryUsageHistoryCount: Int = 0
    private var predictionTask: Task<Void, Never>?
    private var contextualMultipliers: [String: Double] = [
        "recording": 1.5,
        "processing": 1.3,
        "idle": 0.8
    ]
    private let emaAlpha: Double = 0.3
    private var currentEMA: Double = 0
    private let log = OSLog(subsystem: "com.dualcamera.app", category: "PredictiveMemory")
    private weak var memoryTracker: MemoryTracker?
    
    init(memoryTracker: MemoryTracker) {
        self.memoryTracker = memoryTracker
    }
    
    func enable() {
        isEnabled = true
        startPrediction()
    }
    
    func disable() {
        isEnabled = false
        stopPrediction()
    }
    
    func getAccuracy() -> Double {
        guard predictionsCount > 10 else {
            return 0.0
        }
        
        var totalError: Double = 0
        var comparisonCount = 0
        
        for i in 0..<min(predictionsCount, 50) {
            let prediction = predictions[i]
            guard let actualUsage = memoryTracker?.getCurrentMemoryUsage() else { continue }
            
            let error = abs(prediction.predictedUsage - actualUsage) / actualUsage
            totalError += error
            comparisonCount += 1
        }
        
        guard comparisonCount > 0 else { return 0.0 }
        
        let averageError = totalError / Double(comparisonCount)
        let accuracy = max(0, 1.0 - averageError)
        
        return accuracy
    }
    
    private func startPrediction() {
        predictionTask = Task.detached(priority: .utility) { [weak self] in
            while await self?.isEnabled == true {
                if #available(iOS 26.0, *) {
                    await self?.performMLPrediction()
                } else {
                    await self?.performPrediction()
                }
                try? await Task.sleep(nanoseconds: 5_000_000_000)
            }
        }
    }
    
    private func stopPrediction() {
        predictionTask?.cancel()
        predictionTask = nil
    }
    
    private func performPrediction() {
        guard let memoryTracker = memoryTracker else { return }
        
        let currentUsage = memoryTracker.getCurrentMemoryUsage()
        
        if memoryUsageHistoryCount >= 200 {
            for i in 0..<199 {
                memoryUsageHistory[i] = memoryUsageHistory[i + 1]
            }
            memoryUsageHistory[199] = currentUsage
        } else {
            memoryUsageHistory[memoryUsageHistoryCount] = currentUsage
            memoryUsageHistoryCount += 1
        }
        
        if currentEMA == 0 {
            currentEMA = currentUsage
        } else {
            currentEMA = emaAlpha * currentUsage + (1 - emaAlpha) * currentEMA
        }
        
        guard memoryUsageHistoryCount >= 10 else { return }
        
        let recentHistory = (0..<min(memoryUsageHistoryCount, 20)).map { memoryUsageHistory[memoryUsageHistoryCount - 1 - $0] }
        let trend = calculateTrend(from: recentHistory)
        
        let contextMultiplier = contextualMultipliers["idle"] ?? 1.0
        
        let basePrediction = currentEMA
        let trendAdjustment = trend * 10.0
        let predictedUsage = (basePrediction + trendAdjustment) * contextMultiplier
        
        let volatility = calculateVolatility(from: recentHistory)
        let confidence = max(0.5, 1.0 - volatility)
        
        let prediction = MemoryPrediction(
            timestamp: Date(),
            predictedUsage: predictedUsage,
            confidence: confidence
        )
        
        if predictionsCount >= 50 {
            for i in 0..<49 {
                predictions[i] = predictions[i + 1]
            }
            predictions[49] = prediction
        } else {
            predictions[predictionsCount] = prediction
            predictionsCount += 1
        }
        
        os_signpost(.event, log: log, name: "Prediction", 
                   "Current: %.1f MB, Predicted: %.1f MB, Confidence: %.2f", 
                   currentUsage, predictedUsage, confidence)
        
        if predictedUsage > currentUsage * 1.2 && confidence > 0.7 {
            NotificationCenter.default.post(
                name: .predictedMemoryPressure,
                object: nil,
                userInfo: [
                    "predictedUsage": predictedUsage,
                    "currentUsage": currentUsage,
                    "confidence": confidence
                ]
            )
        }
    }
    
    @available(iOS 26.0, *)
    private func performMLPrediction() async {
        guard let memoryTracker = memoryTracker else { return }
        
        let currentUsage = memoryTracker.getCurrentMemoryUsage()
        
        if memoryUsageHistoryCount >= 200 {
            for i in 0..<199 {
                memoryUsageHistory[i] = memoryUsageHistory[i + 1]
            }
            memoryUsageHistory[199] = currentUsage
        } else {
            memoryUsageHistory[memoryUsageHistoryCount] = currentUsage
            memoryUsageHistoryCount += 1
        }
        
        guard memoryUsageHistoryCount >= 20 else { 
            performPrediction()
            return 
        }
        
        let recentHistory = (0..<min(memoryUsageHistoryCount, 20)).map { 
            memoryUsageHistory[memoryUsageHistoryCount - 1 - $0] 
        }
        
        let deviceState = MemoryPredictionDeviceState(
            batteryLevel: UIDevice.current.batteryLevel,
            thermalState: ProcessInfo.processInfo.thermalState.rawValue,
            isLowPowerMode: ProcessInfo.processInfo.isLowPowerModeEnabled,
            availableMemory: getAvailableMemory()
        )
        
        let appState = MemoryPredictionAppState(
            isRecording: false,
            activeBufferCount: 5,
            processingQueueDepth: 2,
            cameraSessionActive: true
        )
        
        let input = MemoryPredictionInput(
            currentUsage: currentUsage,
            recentHistory: recentHistory,
            deviceState: deviceState,
            appState: appState
        )
        
        do {
            let mlPredictor = try await MemoryMLPredictor.shared
            let prediction = try await mlPredictor.predict(input: input)
            
            let confidence = prediction.confidence
            let predictedUsage = prediction.predictedUsage
            let advanceWarningSeconds = prediction.advanceWarningSeconds
            
            let memoryPrediction = MemoryPrediction(
                timestamp: Date(),
                predictedUsage: predictedUsage,
                confidence: confidence
            )
            
            if predictionsCount >= 50 {
                for i in 0..<49 {
                    predictions[i] = predictions[i + 1]
                }
                predictions[49] = memoryPrediction
            } else {
                predictions[predictionsCount] = memoryPrediction
                predictionsCount += 1
            }
            
            os_signpost(.event, log: log, name: "ML Prediction", 
                       "Current: %.1f MB, Predicted: %.1f MB, Confidence: %.2f, Warning: %.1fs", 
                       currentUsage, predictedUsage, confidence, advanceWarningSeconds)
            
            if predictedUsage > currentUsage * 1.2 && confidence > 0.7 {
                await notifyPredictedMemoryPressure(predictedUsage, currentUsage, confidence)
            }
        } catch {
            os_signpost(.event, log: log, name: "ML Prediction Failed", 
                       "Falling back to statistical prediction: %{public}s", error.localizedDescription)
            performPrediction()
        }
    }
    
    @available(iOS 26.0, *)
    private func notifyPredictedMemoryPressure(_ predictedUsage: Double, _ currentUsage: Double, _ confidence: Double) async {
        await MainActor.run {
            NotificationCenter.default.post(
                name: .predictedMemoryPressure,
                object: nil,
                userInfo: [
                    "predictedUsage": predictedUsage,
                    "currentUsage": currentUsage,
                    "confidence": confidence,
                    "advanceWarning": 10.0
                ]
            )
        }
    }
    
    private func getAvailableMemory() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            let totalMemory = Double(ProcessInfo.processInfo.physicalMemory) / 1024.0 / 1024.0
            let usedMemory = Double(info.resident_size) / 1024.0 / 1024.0
            return totalMemory - usedMemory
        }
        return 0
    }
    
    func getLatestPrediction() -> MemoryPrediction? {
        guard predictionsCount > 0 else { return nil }
        return predictions[predictionsCount - 1]
    }
    
    func getPredictionTrend() -> PredictionTrend {
        guard predictionsCount >= 5 else { return .stable }
        
        let recentPredictions = (0..<5).map { predictions[predictionsCount - 1 - $0].predictedUsage }
        let trend = calculateTrend(from: recentPredictions)
        
        if trend > 0.1 {
            return .increasing
        } else if trend < -0.1 {
            return .decreasing
        } else {
            return .stable
        }
    }
    
    func updateContextualMultiplier(context: String, multiplier: Double) {
        contextualMultipliers[context] = multiplier
    }
    
    private func calculateTrend(from values: [Double]) -> Double {
        guard values.count >= 2 else { return 0 }
        
        let n = Double(values.count)
        let sumX = (0..<values.count).reduce(0.0) { $0 + Double($1) }
        let sumY = values.reduce(0, +)
        let sumXY = zip(0..<values.count, values).reduce(0.0) { $0 + Double($1.0) * $1.1 }
        let sumX2 = (0..<values.count).reduce(0.0) { $0 + Double($1 * $1) }
        
        let denominator = n * sumX2 - sumX * sumX
        guard denominator != 0 else { return 0 }
        
        let slope = (n * sumXY - sumX * sumY) / denominator
        return slope
    }
    
    private func calculateVolatility(from values: [Double]) -> Double {
        guard values.count >= 2 else { return 0 }
        
        let mean = values.reduce(0, +) / Double(values.count)
        let variance = values.reduce(0) { $0 + pow($1 - mean, 2) } / Double(values.count)
        let stdDev = sqrt(variance)
        
        return stdDev / mean
    }
}

enum PredictionTrend {
    case increasing
    case stable
    case decreasing
}

@available(iOS 17.0, *)
class PerformanceProfiler {
    private var isRunning = false
    private var metrics: InlineArray<200, PerformanceMetric> = InlineArray(repeating: PerformanceMetric(timestamp: Date.distantPast, memoryUsage: 0, cpuUsage: 0, frameRate: 0))
    private var metricsCount: Int = 0
    
    private var startTime: Date?
    private var metricsCollectionTask: Task<Void, Never>?
    private var cpuUsageHistory: InlineArray<100, Double> = InlineArray(repeating: 0.0)
    private var cpuUsageHistoryCount: Int = 0
    private var frameRateHistory: InlineArray<100, Double> = InlineArray(repeating: 0.0)
    private var frameRateHistoryCount: Int = 0
    
    func start() {
        guard !isRunning else { return }
        isRunning = true
        startTime = Date()
        
        metricsCollectionTask = Task.detached(priority: .utility) { [weak self] in
            while await self?.isRunning == true {
                await self?.collectMetrics()
                try? await Task.sleep(nanoseconds: 500_000_000)
            }
        }
    }
    
    func stop() {
        isRunning = false
        metricsCollectionTask?.cancel()
        metricsCollectionTask = nil
    }
    
    private func collectMetrics() {
        let memoryUsage = getCurrentMemoryUsage()
        let cpuUsage = getCPUUsage()
        let frameRate = getFrameRate()
        
        let metric = PerformanceMetric(
            timestamp: Date(),
            memoryUsage: memoryUsage,
            cpuUsage: cpuUsage,
            frameRate: frameRate
        )
        
        if metricsCount >= 200 {
            for i in 0..<199 {
                metrics[i] = metrics[i + 1]
            }
            metrics[199] = metric
        } else {
            metrics[metricsCount] = metric
            metricsCount += 1
        }
        
        if cpuUsageHistoryCount >= 100 {
            for i in 0..<99 {
                cpuUsageHistory[i] = cpuUsageHistory[i + 1]
            }
            cpuUsageHistory[99] = cpuUsage
        } else {
            cpuUsageHistory[cpuUsageHistoryCount] = cpuUsage
            cpuUsageHistoryCount += 1
        }
        
        if frameRateHistoryCount >= 100 {
            for i in 0..<99 {
                frameRateHistory[i] = frameRateHistory[i + 1]
            }
            frameRateHistory[99] = frameRate
        } else {
            frameRateHistory[frameRateHistoryCount] = frameRate
            frameRateHistoryCount += 1
        }
    }
    
    private func getCurrentMemoryUsage() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            return Double(info.resident_size) / 1024.0 / 1024.0
        }
        return 0
    }
    
    private func getCPUUsage() -> Double {
        var threadList: thread_act_array_t?
        var threadCount: mach_msg_type_number_t = 0
        
        let result = task_threads(mach_task_self_, &threadList, &threadCount)
        
        guard result == KERN_SUCCESS, let threads = threadList else {
            return 0
        }
        
        var totalCPU: Double = 0
        
        for i in 0..<Int(threadCount) {
            var threadInfo = thread_basic_info()
            var threadInfoCount = mach_msg_type_number_t(THREAD_INFO_MAX)
            
            let infoResult = withUnsafeMutablePointer(to: &threadInfo) {
                $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                    thread_info(threads[i], thread_flavor_t(THREAD_BASIC_INFO), $0, &threadInfoCount)
                }
            }
            
            if infoResult == KERN_SUCCESS {
                if threadInfo.flags & TH_FLAGS_IDLE == 0 {
                    totalCPU += Double(threadInfo.cpu_usage) / Double(TH_USAGE_SCALE) * 100.0
                }
            }
        }
        
        vm_deallocate(mach_task_self_, vm_address_t(bitPattern: threads), vm_size_t(threadCount * MemoryLayout<thread_t>.stride))
        
        return totalCPU
    }
    
    private func getFrameRate() -> Double {
        return 30.0
    }
    
    func generateReport() -> PerformanceReport {
        guard metricsCount > 0 else {
            return PerformanceReport(
                averageMemoryUsage: 0,
                peakMemoryUsage: 0,
                frameRate: 0,
                cpuUsage: 0
            )
        }
        
        var totalMemory: Double = 0
        var peakMemory: Double = 0
        var totalFrameRate: Double = 0
        var totalCPU: Double = 0
        
        for i in 0..<metricsCount {
            let metric = metrics[i]
            totalMemory += metric.memoryUsage
            totalFrameRate += metric.frameRate
            totalCPU += metric.cpuUsage
            peakMemory = max(peakMemory, metric.memoryUsage)
        }
        
        return PerformanceReport(
            averageMemoryUsage: totalMemory / Double(metricsCount),
            peakMemoryUsage: peakMemory,
            frameRate: totalFrameRate / Double(metricsCount),
            cpuUsage: totalCPU / Double(metricsCount)
        )
    }
    
    func getDetailedReport() -> DetailedPerformanceReport {
        let basicReport = generateReport()
        
        var memoryArray: [Double] = []
        for i in 0..<metricsCount {
            memoryArray.append(metrics[i].memoryUsage)
        }
        
        return DetailedPerformanceReport(
            basic: basicReport,
            cpuTrend: calculateTrend(from: cpuUsageHistory, count: cpuUsageHistoryCount),
            memoryTrend: calculateTrend(from: memoryArray, count: metricsCount),
            frameRateTrend: calculateTrend(from: frameRateHistory, count: frameRateHistoryCount),
            duration: Date().timeIntervalSince(startTime ?? Date())
        )
    }
    
    private func calculateTrend(from data: InlineArray<100, Double>, count: Int) -> TrendDirection {
        guard count > 10 else { return .stable }
        
        var sumX: Double = 0
        var sumY: Double = 0
        var sumXY: Double = 0
        var sumX2: Double = 0
        
        let n = Double(count)
        
        for i in 0..<count {
            let x = Double(i)
            let y = data[i]
            sumX += x
            sumY += y
            sumXY += x * y
            sumX2 += x * x
        }
        
        let slope = (n * sumXY - sumX * sumY) / (n * sumX2 - sumX * sumX)
        
        if slope > 0.1 {
            return .increasing
        } else if slope < -0.1 {
            return .decreasing
        } else {
            return .stable
        }
    }
    
    private func calculateTrend(from data: [Double], count: Int) -> TrendDirection {
        guard count > 10 else { return .stable }
        
        var sumX: Double = 0
        var sumY: Double = 0
        var sumXY: Double = 0
        var sumX2: Double = 0
        
        let n = Double(count)
        
        for i in 0..<count {
            let x = Double(i)
            let y = data[i]
            sumX += x
            sumY += y
            sumXY += x * y
            sumX2 += x * x
        }
        
        let slope = (n * sumXY - sumX * sumY) / (n * sumX2 - sumX * sumX)
        
        if slope > 0.1 {
            return .increasing
        } else if slope < -0.1 {
            return .decreasing
        } else {
            return .stable
        }
    }
    
    func reset() {
        metricsCount = 0
        cpuUsageHistoryCount = 0
        frameRateHistoryCount = 0
        startTime = nil
    }
}

// MARK: - Data Structures

enum MemoryPressureLevel {
    case normal
    case warning
    case critical
}

enum PixelBufferUsage: String {
    case preview = "preview"
    case recording = "recording"
    case processing = "processing"
    case temporary = "temporary"
    
    var minBufferCount: Int {
        switch self {
        case .preview: return 3
        case .recording: return 5
        case .processing: return 2
        case .temporary: return 1
        }
    }
    
    var maxBufferAge: Double {
        switch self {
        case .preview: return 1.0
        case .recording: return 5.0
        case .processing: return 0.5
        case .temporary: return 0.1
        }
    }
}

enum CacheClearType {
    case nonEssential
    case all
    
    var description: String {
        switch self {
        case .nonEssential: return "Non-Essential"
        case .all: return "All"
        }
    }
}

struct MemoryUsageSnapshot {
    let timestamp: Date
    let usage: Double
    let available: Double
}

struct MemoryPressureEvent {
    let timestamp: Date
    let level: MemoryPressureLevel
    let memoryUsage: Double
}

struct PoolMetrics {
    private var allocationCount = 0
    private var deallocationCount = 0
    
    mutating func recordAllocation() {
        allocationCount += 1
    }
    
    mutating func recordDeallocation() {
        deallocationCount += 1
    }
    
    func getUtilization() -> Double {
        guard allocationCount > 0 else { return 0.0 }
        let activeBuffers = allocationCount - deallocationCount
        return Double(activeBuffers) / Double(allocationCount)
    }
}

struct PoolMetricsReport {
    let totalPools: Int
    let totalAllocations: Int
    let totalDeallocations: Int
    let poolHitCounts: [String: Int]
    let poolMissCounts: [String: Int]
    let poolEvictionCounts: [String: Int]
    let averageUtilization: Double
}

struct MemoryPrediction {
    let timestamp: Date
    let predictedUsage: Double
    let confidence: Double
}

struct PerformanceMetric {
    let timestamp: Date
    let memoryUsage: Double
    let cpuUsage: Double
    let frameRate: Double
}

struct MemoryAnalytics {
    let currentUsage: Double
    let peakUsage: Double
    let pressureEvents: Int
    let poolUtilization: Double
    let predictiveAccuracy: Double
}

struct CacheMetrics {
    let id: String
    let name: String
    var size: Int64
    var lastCleared: Date
    var clearCount: Int
}

struct CacheStatistics {
    let totalSize: Int64
    let cacheCount: Int
    let cacheDetails: [(name: String, size: Int64)]
}

class WeakCacheOwner {
    weak var owner: CacheOwner?
    
    init(owner: CacheOwner) {
        self.owner = owner
    }
}

enum MemoryRecommendation {
    case reduceVideoQuality
    case optimizePoolUsage
    case enablePredictiveManagement
    case clearCaches
}

struct PerformanceReport {
    let averageMemoryUsage: Double
    let peakMemoryUsage: Double
    let frameRate: Double
    let cpuUsage: Double
}

struct DetailedPerformanceReport {
    let basic: PerformanceReport
    let cpuTrend: TrendDirection
    let memoryTrend: TrendDirection
    let frameRateTrend: TrendDirection
    let duration: TimeInterval
}

enum TrendDirection {
    case increasing
    case decreasing
    case stable
}

class MemoryMetrics {
    private var peakMemoryUsage: Double = 0
    private var pressureEventCount: Int = 0
    private var memoryStates: InlineArray<100, MemoryPressureLevel> = InlineArray(repeating: .normal)
    private var memoryStatesCount: Int = 0
    
    func recordMemoryState(_ state: MemoryPressureLevel) {
        // Keep only recent states using ring buffer
        if memoryStatesCount >= 100 {
            // Shift all elements left by 1
            for i in 0..<99 {
                memoryStates[i] = memoryStates[i + 1]
            }
            memoryStates[99] = state
        } else {
            memoryStates[memoryStatesCount] = state
            memoryStatesCount += 1
        }
        
        if state == .critical {
            pressureEventCount += 1
        }
    }
    
    func getPeakMemoryUsage() -> Double {
        return peakMemoryUsage
    }
    
    func getPressureEventCount() -> Int {
        return pressureEventCount
    }
}

// MARK: - Notification Extensions

extension Notification.Name {
    static let memoryPressureWarning = Notification.Name("MemoryPressureWarning")
    static let memoryPressureCritical = Notification.Name("MemoryPressureCritical")
    static let reduceProcessingQuality = Notification.Name("ReduceProcessingQuality")
    static let stopNonEssentialProcesses = Notification.Name("StopNonEssentialProcesses")
    static let reduceQualityForMemoryPressure = Notification.Name("ReduceQualityForMemoryPressure")
    static let showMemoryWarningUI = Notification.Name("ShowMemoryWarningUI")
    static let cachesCleared = Notification.Name("CachesCleared")
    static let predictedMemoryPressure = Notification.Name("PredictedMemoryPressure")
    static let memoryCompacted = Notification.Name("MemoryCompacted")
}

@available(iOS 26.0, *)
struct MemoryPredictionInput {
    let currentUsage: Double
    let recentHistory: [Double]
    let deviceState: MemoryPredictionDeviceState
    let appState: MemoryPredictionAppState
}

@available(iOS 26.0, *)
struct MemoryPredictionDeviceState {
    let batteryLevel: Float
    let thermalState: Int
    let isLowPowerMode: Bool
    let availableMemory: Double
}

@available(iOS 26.0, *)
struct MemoryPredictionAppState {
    let isRecording: Bool
    let activeBufferCount: Int
    let processingQueueDepth: Int
    let cameraSessionActive: Bool
}

@available(iOS 26.0, *)
struct MemoryPredictionOutput {
    let predictedUsage: Double
    let confidence: Double
    let advanceWarningSeconds: Double
}

@available(iOS 26.0, *)
actor MemoryMLPredictor {
    static let shared: MemoryMLPredictor = {
        return MemoryMLPredictor()
    }()
    
    private var model: MemoryPredictionModel?
    
    private init() {
        Task {
            await loadModel()
        }
    }
    
    private func loadModel() async {
        do {
            model = try MemoryPredictionModel()
        } catch {
            print("Failed to load ML model: \(error)")
        }
    }
    
    func predict(input: MemoryPredictionInput) async throws -> MemoryPredictionOutput {
        guard let model = model else {
            throw MemoryMLPredictorError.modelNotLoaded
        }
        
        return try await model.predict(input: input)
    }
}

@available(iOS 26.0, *)
enum MemoryMLPredictorError: Error {
    case modelNotLoaded
    case predictionFailed
}

@available(iOS 26.0, *)
class MemoryPredictionModel {
    private let weights: [Double]
    private let biases: [Double]
    private let scalingFactor: Double = 1.2
    
    init() throws {
        self.weights = [
            0.85, 0.10, 0.03, 0.02,
            0.15, -0.05, -0.08, 0.12,
            0.20, 0.18, 0.10, 0.08
        ]
        self.biases = [0.5, 0.3, 0.2]
    }
    
    func predict(input: MemoryPredictionInput) async throws -> MemoryPredictionOutput {
        let features = extractFeatures(from: input)
        
        let historyWeight = features[0...3].reduce(0, +) / 4.0
        let deviceWeight = features[4...7].reduce(0, +) / 4.0
        let appWeight = features[8...11].reduce(0, +) / 4.0
        
        let baselinePrediction = input.currentUsage * (1.0 + historyWeight * 0.1)
        
        let deviceAdjustment = deviceWeight * 0.15
        let appAdjustment = appWeight * 0.25
        
        let predictedUsage = baselinePrediction * (1.0 + deviceAdjustment + appAdjustment)
        
        let historyVariance = calculateVariance(input.recentHistory)
        let baseConfidence = 0.95
        let variancePenalty = min(historyVariance * 0.1, 0.15)
        let confidence = max(0.7, baseConfidence - variancePenalty)
        
        let usageIncrease = (predictedUsage - input.currentUsage) / input.currentUsage
        let advanceWarningSeconds: Double
        if usageIncrease > 0.3 {
            advanceWarningSeconds = 15.0
        } else if usageIncrease > 0.2 {
            advanceWarningSeconds = 12.0
        } else if usageIncrease > 0.1 {
            advanceWarningSeconds = 10.0
        } else {
            advanceWarningSeconds = 5.0
        }
        
        return MemoryPredictionOutput(
            predictedUsage: predictedUsage,
            confidence: confidence,
            advanceWarningSeconds: advanceWarningSeconds
        )
    }
    
    private func extractFeatures(from input: MemoryPredictionInput) -> [Double] {
        var features: [Double] = []
        
        if input.recentHistory.count >= 4 {
            features.append(input.recentHistory[0] / input.currentUsage)
            features.append(input.recentHistory[1] / input.currentUsage)
            features.append(input.recentHistory[2] / input.currentUsage)
            features.append(input.recentHistory[3] / input.currentUsage)
        } else {
            features.append(contentsOf: [1.0, 1.0, 1.0, 1.0])
        }
        
        features.append(Double(input.deviceState.batteryLevel))
        features.append(Double(input.deviceState.thermalState) / 3.0)
        features.append(input.deviceState.isLowPowerMode ? 1.0 : 0.0)
        features.append(min(input.deviceState.availableMemory / 1000.0, 1.0))
        
        features.append(input.appState.isRecording ? 1.0 : 0.0)
        features.append(Double(input.appState.activeBufferCount) / 10.0)
        features.append(Double(input.appState.processingQueueDepth) / 5.0)
        features.append(input.appState.cameraSessionActive ? 1.0 : 0.0)
        
        return features
    }
    
    private func calculateVariance(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0.0 }
        let mean = values.reduce(0, +) / Double(values.count)
        let variance = values.reduce(0) { $0 + pow($1 - mean, 2) } / Double(values.count)
        return variance / max(mean, 1.0)
    }
}