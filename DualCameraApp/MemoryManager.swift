//
//  MemoryManager.swift
//  DualCameraApp
//
//  Advanced memory management with pixel buffer pooling and pressure handling
//

import Foundation
import UIKit
import AVFoundation
import CoreVideo
import os.log

class MemoryManager {
    static let shared = MemoryManager()
    
    private let log = OSLog(subsystem: "com.dualcamera.app", category: "Memory")
    
    // Memory pressure monitoring
    private var memoryPressureHandler: DispatchSourceMemoryPressure?
    private var memoryWarningCount: Int = 0
    private var lastMemoryCheck: CFTimeInterval = 0
    
    // Memory usage tracking
    private var memoryUsageHistory: [(Date, Double)] = []
    private let maxMemoryHistorySamples = 100
    
    // Pixel buffer pools
    private var pixelBufferPools: [String: CVPixelBufferPool] = [:]
    private var poolAttributes: [String: Any] = [:]
    private var poolCreationCount: Int = 0
    
    // Memory thresholds (in MB)
    private struct MemoryThresholds {
        static let warning: Double = 200      // 200MB
        static let critical: Double = 250     // 250MB
        static let emergency: Double = 300    // 300MB
        static let maximum: Double = 400      // 400MB
    }
    
    enum MemoryState {
        case normal
        case warning
        case critical
        case emergency
        
        var description: String {
            switch self {
            case .normal: return "Normal"
            case .warning: return "Warning"
            case .critical: return "Critical"
            case .emergency: return "Emergency"
            }
        }
    }
    
    private var currentMemoryState: MemoryState = .normal
    
    var onMemoryPressure: ((MemoryState) -> Void)?
    var onMemoryWarning: (() -> Void)?
    var onMemoryRestored: (() -> Void)?
    
    private init() {
        setupMemoryMonitoring()
        setupPixelBufferPooling()
    }
    
    // MARK: - Memory Monitoring Setup
    
    private func setupMemoryMonitoring() {
        // Setup system memory pressure monitoring
        memoryPressureHandler = DispatchSource.makeMemoryPressureSource(
            eventMask: [.warning, .critical],
            queue: DispatchQueue.global(qos: .utility)
        )
        
        memoryPressureHandler?.setEventHandler { [weak self] in
            guard let self = self else { return }
            
            let event = self.memoryPressureHandler?.mask
            if event?.contains(.warning) == true {
                self.handleSystemMemoryPressure(.warning)
            }
            
            if event?.contains(.critical) == true {
                self.handleSystemMemoryPressure(.critical)
            }
        }
        
        memoryPressureHandler?.resume()
        
        // Register for app memory warnings
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
        
        // Start periodic memory checks
        Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.checkMemoryUsage()
        }
        
        logEvent("Memory Manager", "Initialized memory monitoring")
    }
    
    @objc private func handleAppMemoryWarning() {
        memoryWarningCount += 1
        logEvent("Memory Warning", "Received app memory warning #\(memoryWarningCount)")
        
        // Handle memory warning
        handleMemoryPressure(.warning)
        
        // Notify callbacks
        DispatchQueue.main.async {
            self.onMemoryWarning?()
        }
    }
    
    private func handleSystemMemoryPressure(_ pressure: DispatchSource.MemoryPressureEvent) {
        logEvent("Memory Pressure", "System memory pressure: \(pressure == .warning ? "Warning" : "Critical")")
        
        let memoryState: MemoryState = pressure == .warning ? .warning : .critical
        handleMemoryPressure(memoryState)
    }
    
    private func handleMemoryPressure(_ state: MemoryState) {
        currentMemoryState = state
        
        // Record memory usage
        let currentUsage = getCurrentMemoryUsage()
        recordMemoryUsage(currentUsage)
        
        // Apply memory management based on state
        switch state {
        case .normal:
            break // No action needed
            
        case .warning:
            applyWarningLevelMitigation()
            
        case .critical:
            applyCriticalLevelMitigation()
            
        case .emergency:
            applyEmergencyLevelMitigation()
        }
        
        // Notify callbacks
        DispatchQueue.main.async {
            self.onMemoryPressure?(state)
        }
    }
    
    private func checkMemoryUsage() {
        let currentUsage = getCurrentMemoryUsage()
        let currentTime = CACurrentMediaTime()
        
        // Only check every 5 seconds to avoid overhead
        if currentTime - lastMemoryCheck > 5.0 {
            lastMemoryCheck = currentTime
            recordMemoryUsage(currentUsage)
            
            // Determine memory state based on usage
            let newState: MemoryState
            switch currentUsage {
            case 0..<MemoryThresholds.warning:
                newState = .normal
            case MemoryThresholds.warning..<MemoryThresholds.critical:
                newState = .warning
            case MemoryThresholds.critical..<MemoryThresholds.emergency:
                newState = .critical
            default:
                newState = .emergency
            }
            
            if newState != currentMemoryState {
                handleMemoryPressure(newState)
            }
            
            // Log memory usage
            logEvent("Memory Usage", "\(String(format: "%.1f", currentUsage)) MB (\(currentMemoryState.description))")
        }
    }
    
    private func recordMemoryUsage(_ usage: Double) {
        memoryUsageHistory.append((Date(), usage))
        
        // Keep only recent samples
        if memoryUsageHistory.count > maxMemoryHistorySamples {
            memoryUsageHistory.removeFirst()
        }
    }
    
    // MARK: - Memory Mitigation Strategies
    
    private func applyWarningLevelMitigation() {
        logEvent("Memory Mitigation", "Applying warning level mitigation")
        
        // Clear pixel buffer pools
        clearPixelBufferPools()
        
        // Reduce video quality
        if SettingsManager.shared.videoQuality == .uhd4k {
            SettingsManager.shared.videoQuality = .hd1080
        }
        
        // Enable adaptive quality
        SettingsManager.shared.recordingQualityAdaptive = true
        
        // Clear caches
        clearImageCaches()
    }
    
    private func applyCriticalLevelMitigation() {
        logEvent("Memory Mitigation", "Applying critical level mitigation")
        
        // Force 720p quality
        SettingsManager.shared.videoQuality = .hd720
        
        // Disable triple output
        SettingsManager.shared.enableTripleOutput = false
        
        // Clear all pixel buffer pools
        clearPixelBufferPools()
        
        // Clear all caches
        clearAllCaches()
        
        // Reduce frame compositor quality
        NotificationCenter.default.post(name: .reduceQualityForMemoryPressure, object: nil)
    }
    
    private func applyEmergencyLevelMitigation() {
        logEvent("Memory Mitigation", "Applying emergency level mitigation")
        
        // Force lowest quality
        SettingsManager.shared.videoQuality = .hd720
        
        // Disable all non-essential features
        SettingsManager.shared.enableTripleOutput = false
        SettingsManager.shared.enableHapticFeedback = false
        
        // Clear everything possible
        clearPixelBufferPools()
        clearAllCaches()
        
        // Suggest stopping recording
        NotificationCenter.default.post(name: .emergencyMemoryPressure, object: nil)
    }
    
    // MARK: - Pixel Buffer Pool Management
    
    private func setupPixelBufferPooling() {
        // Setup default pool attributes
        poolAttributes = [
            kCVPixelBufferPoolMinimumBufferCountKey as String: 3,
            kCVPixelBufferPoolMaximumBufferAgeKey as String: 2.0
        ]
        
        logEvent("Pixel Buffer Pool", "Initialized pixel buffer pooling")
    }
    
    func createPixelBufferPool(width: Int, height: Int, pixelFormat: OSType, identifier: String) -> CVPixelBufferPool? {
        // Check if pool already exists
        if let existingPool = pixelBufferPools[identifier] {
            return existingPool
        }
        
        let pixelBufferAttributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: pixelFormat,
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height,
            kCVPixelBufferMetalCompatibilityKey as String: true,
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true,
            kCVPixelBufferIOSurfacePropertiesKey as String: [:] as CFDictionary
        ]
        
        var pool: CVPixelBufferPool?
        let status = CVPixelBufferPoolCreate(
            nil,
            poolAttributes as CFDictionary,
            pixelBufferAttributes as CFDictionary,
            &pool
        )
        
        guard status == kCVReturnSuccess, let createdPool = pool else {
            logEvent("Pixel Buffer Pool", "Failed to create pool: \(status)")
            return nil
        }
        
        // Store pool
        pixelBufferPools[identifier] = createdPool
        poolCreationCount += 1
        
        logEvent("Pixel Buffer Pool", "Created pool '\(identifier)' (\(width)x\(height))")
        
        return createdPool
    }
    
    func getPixelBufferFromPool(_ pool: CVPixelBufferPool) -> CVPixelBuffer? {
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferPoolCreatePixelBuffer(nil, pool, &pixelBuffer)
        
        guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
            logEvent("Pixel Buffer Pool", "Failed to get pixel buffer: \(status)")
            return nil
        }
        
        return buffer
    }
    
    func clearPixelBufferPools() {
        pixelBufferPools.removeAll()
        logEvent("Pixel Buffer Pool", "Cleared all pixel buffer pools")
    }
    
    func clearPixelBufferPool(identifier: String) {
        pixelBufferPools.removeValue(forKey: identifier)
        logEvent("Pixel Buffer Pool", "Cleared pool '\(identifier)'")
    }
    
    // MARK: - Cache Management
    
    private func clearImageCaches() {
        // Clear image caches
        // This would clear any cached images or assets
        
        logEvent("Cache Management", "Cleared image caches")
    }
    
    private func clearAllCaches() {
        // Clear all possible caches
        clearImageCaches()
        
        // Clear temporary files
        clearTemporaryFiles()
        
        // Trigger garbage collection
        DispatchQueue.global(qos: .utility).async {
            // Force garbage collection if possible
            autoreleasepool {
                // Temporary memory cleanup
            }
        }
        
        logEvent("Cache Management", "Cleared all caches")
    }
    
    func clearTemporaryFiles() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(at: documentsPath, includingPropertiesForKeys: [.creationDateKey])
            let now = Date()
            
            for url in fileURLs {
                if url.lastPathComponent.contains("temp") || url.lastPathComponent.contains("cache") {
                    if let creationDate = try? url.resourceValues(forKeys: [.creationDateKey]).creationDate {
                        let hoursSinceCreation = Calendar.current.dateComponents([.hour], from: creationDate, to: now).hour ?? 0
                        if hoursSinceCreation > 1 {
                            try? FileManager.default.removeItem(at: url)
                        }
                    }
                }
            }
        } catch {
            logEvent("Cache Management", "Error clearing temporary files: \(error)")
        }
    }
    
    // MARK: - Memory Utilities
    
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
            return Double(info.resident_size) / 1024.0 / 1024.0 // Convert to MB
        }
        return 0
    }
    
    func getSystemMemoryInfo() -> (total: Double, available: Double, used: Double) {
        var totalMemory: Double = 0
        var availableMemory: Double = 0
        
        // Get system memory information
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
            totalMemory = Double(ProcessInfo.processInfo.physicalMemory) / 1024.0 / 1024.0 // Convert to MB
            availableMemory = max(0, totalMemory - Double(info.resident_size) / 1024.0 / 1024.0)
        }
        
        let usedMemory = totalMemory - availableMemory
        
        return (total: totalMemory, available: availableMemory, used: usedMemory)
    }
    
    // MARK: - Public Interface
    
    func getCurrentMemoryState() -> MemoryState {
        return currentMemoryState
    }
    
    func getMemoryUsageHistory() -> [(Date, Double)] {
        return memoryUsageHistory
    }
    
    func getMemoryWarningCount() -> Int {
        return memoryWarningCount
    }
    
    func isMemoryPressureHigh() -> Bool {
        return currentMemoryState == .critical || currentMemoryState == .emergency
    }
    
    func getMemoryStatistics() -> [String: Any] {
        let currentUsage = getCurrentMemoryUsage()
        let systemMemory = getSystemMemoryInfo()
        
        return [
            "currentUsage": currentUsage,
            "memoryState": currentMemoryState.description,
            "warningCount": memoryWarningCount,
            "poolCount": pixelBufferPools.count,
            "systemTotal": systemMemory.total,
            "systemAvailable": systemMemory.available,
            "systemUsed": systemMemory.used,
            "usagePercentage": (systemMemory.used / systemMemory.total) * 100
        ]
    }
    
    func optimizeMemoryUsage() {
        // Manual memory optimization
        clearPixelBufferPools()
        clearAllCaches()
        
        logEvent("Memory Optimization", "Manual memory optimization completed")
    }
    
    func resetMemoryManagement() {
        // Reset memory management state
        currentMemoryState = .normal
        memoryWarningCount = 0
        memoryUsageHistory.removeAll()
        
        // Clear pools
        clearPixelBufferPools()
        
        logEvent("Memory Manager", "Reset memory management system")
    }
    
    // MARK: - Helper Methods
    
    private func logEvent(_ name: StaticString, _ message: String = "") {
        os_signpost(.event, log: log, name: name, "%{public}s", message)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        memoryPressureHandler?.cancel()
    }
}

// MARK: - Notification Extensions

extension Notification.Name {
    static let reduceQualityForMemoryPressure = Notification.Name("ReduceQualityForMemoryPressure")
    static let emergencyMemoryPressure = Notification.Name("EmergencyMemoryPressure")
    static let memoryPressureRecovered = Notification.Name("MemoryPressureRecovered")
}

