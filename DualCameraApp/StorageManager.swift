//
//  StorageManager.swift
//  DualCameraApp
//
//  Manages file storage, cleanup, and optimization
//

import Foundation
import UIKit
import AVFoundation
import Photos
import os.log

class StorageManager {
    static let shared = StorageManager()
    
    private let log = OSLog(subsystem: "com.dualcamera.app", category: "Storage")
    
    // Storage monitoring
    private var storageCheckTimer: Timer?
    private let storageCheckInterval: TimeInterval = 60.0 // Check every minute
    
    // Storage thresholds (in MB)
    private struct StorageThresholds {
        static let warning: Double = 500      // 500MB
        static let critical: Double = 200     // 200MB
        static let emergency: Double = 100    // 100MB
        static let minimum: Double = 50       // 50MB
    }
    
    enum StorageState {
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
    
    private var currentStorageState: StorageState = .normal
    
    private var managedFiles: [URL] = []
    private var tempFiles: [URL] = []
    private var cacheFiles: [URL] = []
    
    private var storageHistory: [(Date, Double, Double)] = []
    private let maxStorageHistorySamples = 100
    
    var onStorageStateChanged: ((StorageState) -> Void)?
    var onStorageWarning: ((String) -> Void)?
    var onStorageCleanup: ((Int) -> Void)?
    
    private init() {
        setupStorageMonitoring()
        scanExistingFiles()
    }
    
    // MARK: - Storage Monitoring Setup
    
    private func setupStorageMonitoring() {
        // Initial storage check
        checkStorageStatus()
        
        // Start periodic storage checks
        storageCheckTimer = Timer.scheduledTimer(withTimeInterval: storageCheckInterval, repeats: true) { [weak self] _ in
            self?.checkStorageStatus()
        }
        
        logEvent("Storage Manager", "Initialized storage monitoring")
    }
    
    private func scanExistingFiles() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(at: documentsPath, includingPropertiesForKeys: [.creationDateKey, .fileSizeKey])
            
            for url in fileURLs {
                let filename = url.lastPathComponent.lowercased()
                
                if filename.contains("temp") {
                    tempFiles.append(url)
                } else if filename.contains("cache") {
                    cacheFiles.append(url)
                } else {
                    managedFiles.append(url)
                }
            }
            
            logEvent("Storage Manager", "Scanned existing files: \(managedFiles.count) managed, \(tempFiles.count) temp, \(cacheFiles.count) cache")
        } catch {
            logEvent("Storage Manager", "Error scanning files: \(error)")
        }
    }
    
    private func checkStorageStatus() {
        let (usedSpace, availableSpace) = getStorageInfo()
        _ = usedSpace + availableSpace
        
        // Record in history
        storageHistory.append((Date(), usedSpace, availableSpace))
        if storageHistory.count > maxStorageHistorySamples {
            storageHistory.removeFirst()
        }
        
        // Determine storage state
        let availableMB = availableSpace / 1024 / 1024
        let newState: StorageState
        
        switch availableMB {
        case StorageThresholds.minimum..<StorageThresholds.emergency:
            newState = .emergency
        case StorageThresholds.emergency..<StorageThresholds.critical:
            newState = .critical
        case StorageThresholds.critical..<StorageThresholds.warning:
            newState = .warning
        default:
            newState = .normal
        }
        
        if newState != currentStorageState {
            let previousState = currentStorageState
            currentStorageState = newState
            
            logEvent("Storage State", "Changed from \(previousState.description) to \(newState.description) (\(String(format: "%.0f", availableMB))MB available)")
            
            // Handle storage state change
            handleStorageStateChange(newState)
            
            // Notify callbacks
            DispatchQueue.main.async {
                self.onStorageStateChanged?(newState)
            }
        }
    }
    
    private func handleStorageStateChange(_ state: StorageState) {
        switch state {
        case .normal:
            // No action needed
            break
            
        case .warning:
            // Perform light cleanup
            performLightCleanup()
            
        case .critical:
            // Perform aggressive cleanup
            performAggressiveCleanup()
            
        case .emergency:
            // Perform emergency cleanup
            performEmergencyCleanup()
        }
    }
    
    // MARK: - Storage Cleanup Strategies
    
    private func performLightCleanup() {
        logEvent("Storage Cleanup", "Performing light cleanup")
        
        var cleanedFiles = 0
        
        // Clean temp files older than 1 hour
        cleanedFiles += cleanTempFiles(olderThan: 3600)
        
        // Clean cache files older than 24 hours
        cleanedFiles += cleanCacheFiles(olderThan: 86400)
        
        if cleanedFiles > 0 {
            logEvent("Storage Cleanup", "Light cleanup completed: \(cleanedFiles) files removed")
            
            DispatchQueue.main.async {
                self.onStorageCleanup?(cleanedFiles)
            }
        }
    }
    
    private func performAggressiveCleanup() {
        logEvent("Storage Cleanup", "Performing aggressive cleanup")
        
        var cleanedFiles = 0
        
        // Clean all temp files
        cleanedFiles += cleanTempFiles(olderThan: 0)
        
        // Clean cache files older than 6 hours
        cleanedFiles += cleanCacheFiles(olderThan: 21600)
        
        // Clean old managed files (older than 7 days)
        cleanedFiles += cleanManagedFiles(olderThan: 604800)
        
        if cleanedFiles > 0 {
            logEvent("Storage Cleanup", "Aggressive cleanup completed: \(cleanedFiles) files removed")
            
            DispatchQueue.main.async {
                self.onStorageCleanup?(cleanedFiles)
            }
        }
    }
    
    private func performEmergencyCleanup() {
        logEvent("Storage Cleanup", "Performing emergency cleanup")
        
        var cleanedFiles = 0
        
        // Clean all temp files
        cleanedFiles += cleanTempFiles(olderThan: 0)
        
        // Clean all cache files
        cleanedFiles += cleanCacheFiles(olderThan: 0)
        
        // Clean old managed files (older than 3 days)
        cleanedFiles += cleanManagedFiles(olderThan: 259200)
        
        // Clean largest managed files if still needed
        if getAvailableStorageSpace() < StorageThresholds.minimum {
            cleanedFiles += cleanLargestManagedFiles(count: 5)
        }
        
        if cleanedFiles > 0 {
            logEvent("Storage Cleanup", "Emergency cleanup completed: \(cleanedFiles) files removed")
            
            DispatchQueue.main.async {
                self.onStorageCleanup?(cleanedFiles)
                
                // Show warning if still low on space
                if self.getAvailableStorageSpace() < StorageThresholds.minimum {
                    self.onStorageWarning?("Critically low on storage space. Please free up space immediately.")
                }
            }
        }
    }
    
    // MARK: - File Cleanup Methods
    
    private func cleanTempFiles(olderThan seconds: TimeInterval) -> Int {
        return cleanFiles(tempFiles, olderThan: seconds) { [weak self] url in
            self?.tempFiles.removeAll { $0 == url }
        }
    }
    
    private func cleanCacheFiles(olderThan seconds: TimeInterval) -> Int {
        return cleanFiles(cacheFiles, olderThan: seconds) { [weak self] url in
            self?.cacheFiles.removeAll { $0 == url }
        }
    }
    
    private func cleanManagedFiles(olderThan seconds: TimeInterval) -> Int {
        return cleanFiles(managedFiles, olderThan: seconds) { [weak self] url in
            self?.managedFiles.removeAll { $0 == url }
        }
    }
    
    private func cleanLargestManagedFiles(count: Int) -> Int {
        let sortedFiles = managedFiles.sorted { url1, url2 in
            let size1 = getFileSize(url1)
            let size2 = getFileSize(url2)
            return size1 > size2
        }
        
        let filesToClean = Array(sortedFiles.prefix(count))
        var cleanedFiles = 0
        
        for url in filesToClean {
            do {
                try FileManager.default.removeItem(at: url)
                managedFiles.removeAll { $0 == url }
                cleanedFiles += 1
            } catch {
                logEvent("Storage Cleanup", "Error removing file \(url.lastPathComponent): \(error)")
            }
        }
        
        return cleanedFiles
    }
    
    private func cleanFiles(_ files: [URL], olderThan seconds: TimeInterval, removalHandler: (URL) -> Void) -> Int {
        var cleanedFiles = 0
        let now = Date()
        
        for url in files {
            do {
                let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
                if let creationDate = attributes[.creationDate] as? Date {
                    let age = now.timeIntervalSince(creationDate)
                    
                    if age >= seconds {
                        try FileManager.default.removeItem(at: url)
                        removalHandler(url)
                        cleanedFiles += 1
                    }
                }
            } catch {
                logEvent("Storage Cleanup", "Error cleaning file \(url.lastPathComponent): \(error)")
            }
        }
        
        return cleanedFiles
    }
    
    private func getFileSize(_ url: URL) -> Int64 {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            return attributes[.size] as? Int64 ?? 0
        } catch {
            return 0
        }
    }
    
    // MARK: - Storage Utilities
    
    func getStorageInfo() -> (usedSpace: Double, availableSpace: Double) {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        
        do {
            let attributes = try FileManager.default.attributesOfFileSystem(forPath: documentsPath.path)
            
            if let totalSpace = attributes[.systemSize] as? Int64,
               let freeSpace = attributes[.systemFreeSize] as? Int64 {
                let usedSpace = Double(totalSpace - freeSpace)
                let availableSpace = Double(freeSpace)
                
                return (usedSpace: usedSpace, availableSpace: availableSpace)
            }
        } catch {
            logEvent("Storage Manager", "Error getting storage info: \(error)")
        }
        
        return (usedSpace: 0, availableSpace: 0)
    }
    
    func getAvailableStorageSpace() -> Double {
        let (_, availableSpace) = getStorageInfo()
        return availableSpace / 1024.0 / 1024.0
    }
    
    func getStorageStatistics() -> [String: Any] {
        let (usedSpace, availableSpace) = getStorageInfo()
        let totalSpace = usedSpace + availableSpace
        
        return [
            "usedSpace": usedSpace,
            "availableSpace": availableSpace,
            "totalSpace": totalSpace,
            "usagePercentage": (usedSpace / totalSpace) * 100,
            "storageState": currentStorageState.description,
            "managedFilesCount": managedFiles.count,
            "tempFilesCount": tempFiles.count,
            "cacheFilesCount": cacheFiles.count
        ]
    }
    
    // MARK: - File Management
    
    func addManagedFile(_ url: URL) {
        managedFiles.append(url)
        logEvent("File Management", "Added managed file: \(url.lastPathComponent)")
    }
    
    func addTempFile(_ url: URL) {
        tempFiles.append(url)
        logEvent("File Management", "Added temp file: \(url.lastPathComponent)")
    }
    
    func addCacheFile(_ url: URL) {
        cacheFiles.append(url)
        logEvent("File Management", "Added cache file: \(url.lastPathComponent)")
    }
    
    func removeManagedFile(_ url: URL) {
        do {
            try FileManager.default.removeItem(at: url)
            managedFiles.removeAll { $0 == url }
            logEvent("File Management", "Removed managed file: \(url.lastPathComponent)")
        } catch {
            logEvent("File Management", "Error removing file: \(error)")
        }
    }
    
    func getEstimatedRecordingSpace(quality: VideoQuality, duration: TimeInterval) -> Double {
        // Estimate space required for recording (in MB)
        let bitRates: [VideoQuality: Double] = [
            .uhd4k: 20.0,   // 20 Mbps
            .hd1080: 10.0,  // 10 Mbps
            .hd720: 5.0     // 5 Mbps
        ]
        
        let bitRate = bitRates[quality] ?? 10.0
        let estimatedSize = (bitRate / 8) * duration / 1024 // Convert to MB
        
        // Add 20% buffer
        return estimatedSize * 1.2
    }
    
    func canRecordVideo(quality: VideoQuality, duration: TimeInterval) -> Bool {
        let requiredSpace = getEstimatedRecordingSpace(quality: quality, duration: duration)
        let availableSpace = getAvailableStorageSpace()
        
        return availableSpace > requiredSpace
    }
    
    func getMaxRecordingDuration(for quality: VideoQuality) -> TimeInterval {
        let availableSpace = getAvailableStorageSpace()
        let bitRates: [VideoQuality: Double] = [
            .uhd4k: 20.0,   // 20 Mbps
            .hd1080: 10.0,  // 10 Mbps
            .hd720: 5.0     // 5 Mbps
        ]
        
        let bitRate = bitRates[quality] ?? 10.0
        let maxDuration = (availableSpace * 1024 * 8) / bitRate // Convert back to seconds
        
        // Leave 10% buffer
        return maxDuration * 0.9
    }
    
    // MARK: - Public Interface
    
    func getCurrentStorageState() -> StorageState {
        return currentStorageState
    }
    
    func forceStorageCheck() {
        checkStorageStatus()
    }
    
    func performCleanup() {
        switch currentStorageState {
        case .normal:
            performLightCleanup()
        case .warning:
            performLightCleanup()
        case .critical:
            performAggressiveCleanup()
        case .emergency:
            performEmergencyCleanup()
        }
    }
    
    func resetStorageManagement() {
        storageCheckTimer?.invalidate()
        storageHistory.removeAll()
        
        // Restart monitoring
        setupStorageMonitoring()
        
        logEvent("Storage Manager", "Reset storage management")
    }
    
    private func logEvent(_ name: StaticString, _ message: String = "") {
        os_signpost(.event, log: log, name: name, "%{public}s", message)
    }
    
    deinit {
        storageCheckTimer?.invalidate()
    }
}

