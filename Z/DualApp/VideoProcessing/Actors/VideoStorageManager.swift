//
//  VideoStorageManager.swift
//  DualApp
//
//  Created by DualApp Team on 10/3/25.
//

import Foundation
import AVFoundation
import Photos
import CloudKit
import Combine
import UIKit

// MARK: - Video Storage Manager

actor VideoStorageManager: Sendable {
    
    // MARK: - Properties
    
    private let documentsDirectory: URL
    private let cacheDirectory: URL
    private let tempDirectory: URL
    private let iCloudContainer: CKContainer?
    
    // MARK: - Storage State
    
    private var storageInfo: VideoStorageInfo = VideoStorageInfo()
    private var cacheInfo: VideoCacheInfo = VideoCacheInfo()
    
    // MARK: - Event Stream
    
    let events: AsyncStream<VideoStorageEvent>
    private let eventContinuation: AsyncStream<VideoStorageEvent>.Continuation
    
    // MARK: - Performance Monitoring
    
    private var storageMetrics: VideoStorageMetrics = VideoStorageMetrics()
    
    // MARK: - Initialization
    
    init() {
        // Initialize directories
        self.documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        self.cacheDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        self.tempDirectory = FileManager.default.temporaryDirectory
        
        // Initialize iCloud container
        self.iCloudContainer = CKContainer(identifier: "icloud.dualapp.videos")
        
        (self.events, self.eventContinuation) = AsyncStream<VideoStorageEvent>.makeStream()
        
        // Initialize storage
        Task {
            await initializeStorage()
            await updateStorageInfo()
        }
    }
    
    // MARK: - Public Interface
    
    func saveVideo(_ data: Data, filename: String) async throws -> URL {
        let url = documentsDirectory.appendingPathComponent(filename)
        
        // Check available space
        guard try await hasEnoughSpace(for: data.count) else {
            throw VideoStorageManagerError.insufficientSpace
        }
        
        try data.write(to: url)
        
        // Update storage info
        await updateStorageInfo()
        
        eventContinuation.yield(.videoSaved(url))
        
        return url
    }
    
    func saveVideo(from sourceURL: URL, filename: String) async throws -> URL {
        let destinationURL = documentsDirectory.appendingPathComponent(filename)
        
        // Check available space
        let fileSize = try FileManager.default.attributesOfItem(atPath: sourceURL.path)[.size] as? Int64 ?? 0
        guard try await hasEnoughSpace(for: fileSize) else {
            throw VideoStorageManagerError.insufficientSpace
        }
        
        try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
        
        // Update storage info
        await updateStorageInfo()
        
        eventContinuation.yield(.videoSaved(destinationURL))
        
        return destinationURL
    }
    
    func loadVideo(from url: URL) async throws -> Data {
        return try Data(contentsOf: url)
    }
    
    func deleteVideo(at url: URL) async throws {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw VideoStorageManagerError.fileNotFound
        }
        
        try FileManager.default.removeItem(at: url)
        
        // Update storage info
        await updateStorageInfo()
        
        eventContinuation.yield(.videoDeleted(url))
    }
    
    func moveVideo(from sourceURL: URL, to destinationURL: URL) async throws {
        guard FileManager.default.fileExists(atPath: sourceURL.path) else {
            throw VideoStorageManagerError.fileNotFound
        }
        
        try FileManager.default.moveItem(at: sourceURL, to: destinationURL)
        
        // Update storage info
        await updateStorageInfo()
        
        eventContinuation.yield(.videoMoved(sourceURL, destinationURL))
    }
    
    func copyVideo(from sourceURL: URL, to destinationURL: URL) async throws {
        guard FileManager.default.fileExists(atPath: sourceURL.path) else {
            throw VideoStorageManagerError.fileNotFound
        }
        
        // Check available space
        let fileSize = try FileManager.default.attributesOfItem(atPath: sourceURL.path)[.size] as? Int64 ?? 0
        guard try await hasEnoughSpace(for: fileSize) else {
            throw VideoStorageManagerError.insufficientSpace
        }
        
        try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
        
        // Update storage info
        await updateStorageInfo()
        
        eventContinuation.yield(.videoCopied(sourceURL, destinationURL))
    }
    
    func getVideoSize(at url: URL) async -> Int64 {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            return attributes[.size] as? Int64 ?? 0
        } catch {
            return 0
        }
    }
    
    func getAvailableSpace() async -> Int64 {
        do {
            let attributes = try FileManager.default.attributesOfFileSystem(forPath: documentsDirectory.path)
            return attributes[.systemFreeSize] as? Int64 ?? 0
        } catch {
            return 0
        }
    }
    
    func getTotalSpace() async -> Int64 {
        do {
            let attributes = try FileManager.default.attributesOfFileSystem(forPath: documentsDirectory.path)
            return attributes[.systemSize] as? Int64 ?? 0
        } catch {
            return 0
        }
    }
    
    func getStorageInfo() async -> VideoStorageInfo {
        return storageInfo
    }
    
    func getCacheInfo() async -> VideoCacheInfo {
        return cacheInfo
    }
    
    func getStorageMetrics() async -> VideoStorageMetrics {
        return storageMetrics
    }
    
    // MARK: - Cache Management
    
    func cacheThumbnail(_ image: UIImage, for url: URL) async throws -> URL {
        let cacheKey = url.absoluteString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? UUID().uuidString
        let cacheURL = cacheDirectory.appendingPathComponent("thumbnails/\(cacheKey).png")
        
        // Create thumbnails directory if it doesn't exist
        let thumbnailsDirectory = cacheDirectory.appendingPathComponent("thumbnails")
        try FileManager.default.createDirectory(at: thumbnailsDirectory, withIntermediateDirectories: true)
        
        // Convert image to data
        guard let data = image.pngData() else {
            throw VideoStorageManagerError.thumbnailConversionFailed
        }
        
        try data.write(to: cacheURL)
        
        // Update cache info
        await updateCacheInfo()
        
        eventContinuation.yield(.thumbnailCached(url, cacheURL))
        
        return cacheURL
    }
    
    func getCachedThumbnail(for url: URL) async -> UIImage? {
        let cacheKey = url.absoluteString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? UUID().uuidString
        let cacheURL = cacheDirectory.appendingPathComponent("thumbnails/\(cacheKey).png")
        
        guard FileManager.default.fileExists(atPath: cacheURL.path) else {
            return nil
        }
        
        return UIImage(contentsOfFile: cacheURL.path)
    }
    
    func cacheMetadata(_ metadata: VideoMetadata, for url: URL) async throws -> URL {
        let cacheKey = url.absoluteString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? UUID().uuidString
        let cacheURL = cacheDirectory.appendingPathComponent("metadata/\(cacheKey).json")
        
        // Create metadata directory if it doesn't exist
        let metadataDirectory = cacheDirectory.appendingPathComponent("metadata")
        try FileManager.default.createDirectory(at: metadataDirectory, withIntermediateDirectories: true)
        
        // Convert metadata to JSON
        let data = try JSONEncoder().encode(metadata)
        try data.write(to: cacheURL)
        
        // Update cache info
        await updateCacheInfo()
        
        eventContinuation.yield(.metadataCached(url, cacheURL))
        
        return cacheURL
    }
    
    func getCachedMetadata(for url: URL) async -> VideoMetadata? {
        let cacheKey = url.absoluteString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? UUID().uuidString
        let cacheURL = cacheDirectory.appendingPathComponent("metadata/\(cacheKey).json")
        
        guard FileManager.default.fileExists(atPath: cacheURL.path),
              let data = try? Data(contentsOf: cacheURL) else {
            return nil
        }
        
        return try? JSONDecoder().decode(VideoMetadata.self, from: data)
    }
    
    func clearCache() async throws {
        try FileManager.default.removeItem(at: cacheDirectory)
        try FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        
        // Update cache info
        cacheInfo = VideoCacheInfo()
        
        eventContinuation.yield(.cacheCleared)
    }
    
    func clearOldCache(olderThan date: Date) async throws {
        let enumerator = FileManager.default.enumerator(at: cacheDirectory, includingPropertiesForKeys: [.creationDateKey])
        
        for case let fileURL as URL in enumerator {
            let attributes = try fileURL.resourceValues(forKeys: [.creationDateKey])
            if let creationDate = attributes.creationDate,
               creationDate < date {
                try FileManager.default.removeItem(at: fileURL)
            }
        }
        
        // Update cache info
        await updateCacheInfo()
        
        eventContinuation.yield(.oldCacheCleared(date))
    }
    
    func optimizeCache() async throws {
        // Remove least recently used items if cache is too large
        let maxCacheSize: Int64 = 500 * 1024 * 1024 // 500MB
        
        if cacheInfo.totalSize > maxCacheSize {
            let itemsToRemove = try await getCacheItemsToRemove(targetSize: maxCacheSize)
            
            for item in itemsToRemove {
                try FileManager.default.removeItem(at: item.url)
            }
            
            // Update cache info
            await updateCacheInfo()
            
            eventContinuation.yield(.cacheOptimized)
        }
    }
    
    // MARK: - Cloud Backup
    
    func backupToiCloud(_ url: URL) async throws {
        guard let iCloudContainer = iCloudContainer else {
            throw VideoStorageManagerError.iCloudNotAvailable
        }
        
        let accountStatus = try await iCloudContainer.accountStatus()
        guard accountStatus == .available else {
            throw VideoStorageManagerError.iCloudNotAvailable
        }
        
        // Create cloud record
        let record = CKRecord(recordType: "Video")
        record["filename"] = url.lastPathComponent
        record["creationDate"] = Date()
        record["fileSize"] = await getVideoSize(at: url)
        
        // Upload file to iCloud
        let asset = CKAsset(fileURL: url)
        record["videoFile"] = asset
        
        let database = iCloudContainer.privateCloudDatabase
        try await database.save(record)
        
        eventContinuation.yield(.iCloudBackupCompleted(url))
    }
    
    func restoreFromiCloud(_ recordID: CKRecord.ID) async throws -> URL {
        guard let iCloudContainer = iCloudContainer else {
            throw VideoStorageManagerError.iCloudNotAvailable
        }
        
        let database = iCloudContainer.privateCloudDatabase
        let record = try await database.record(for: recordID)
        
        guard let asset = record["videoFile"] as? CKAsset else {
            throw VideoStorageManagerError.iCloudAssetNotFound
        }
        
        let filename = record["filename"] as? String ?? UUID().uuidString
        let destinationURL = documentsDirectory.appendingPathComponent(filename)
        
        try FileManager.default.copyItem(at: asset.fileURL, to: destinationURL)
        
        // Update storage info
        await updateStorageInfo()
        
        eventContinuation.yield(.iCloudRestoreCompleted(destinationURL))
        
        return destinationURL
    }
    
    func listiCloudBackups() async throws -> [CKRecord] {
        guard let iCloudContainer = iCloudContainer else {
            throw VideoStorageManagerError.iCloudNotAvailable
        }
        
        let database = iCloudContainer.privateCloudDatabase
        let query = CKQuery(recordType: "Video", predicate: NSPredicate(value: true))
        
        let result = try await database.records(matching: query)
        return result.matchResults.compactMap { try? $0.1.get() }
    }
    
    func deleteiCloudBackup(_ recordID: CKRecord.ID) async throws {
        guard let iCloudContainer = iCloudContainer else {
            throw VideoStorageManagerError.iCloudNotAvailable
        }
        
        let database = iCloudContainer.privateCloudDatabase
        try await database.deleteRecord(withID: recordID)
        
        eventContinuation.yield(.iCloudBackupDeleted(recordID))
    }
    
    // MARK: - Export to Photo Library
    
    func exportToPhotoLibrary(_ url: URL) async throws {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized else {
            throw VideoStorageManagerError.photoLibraryAccessDenied
        }
        
        try await PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
        }
        
        eventContinuation.yield(.photoLibraryExportCompleted(url))
    }
    
    // MARK: - Storage Cleanup
    
    func cleanupTempFiles() async throws {
        let enumerator = FileManager.default.enumerator(at: tempDirectory, includingPropertiesForKeys: [.creationDateKey])
        
        for case let fileURL as URL in enumerator {
            let attributes = try fileURL.resourceValues(forKeys: [.creationDateKey])
            if let creationDate = attributes.creationDate,
               Date().timeIntervalSince(creationDate) > 24 * 60 * 60 { // Older than 24 hours
                try FileManager.default.removeItem(at: fileURL)
            }
        }
        
        eventContinuation.yield(.tempFilesCleaned)
    }
    
    func cleanupCorruptedFiles() async throws {
        let enumerator = FileManager.default.enumerator(at: documentsDirectory, includingPropertiesForKeys: [.fileSizeKey])
        
        for case let fileURL as URL in enumerator {
            if fileURL.pathExtension.lowercased() == "mp4" ||
               fileURL.pathExtension.lowercased() == "mov" ||
               fileURL.pathExtension.lowercased() == "heic" {
                
                // Check if file is corrupted
                if await isVideoFileCorrupted(fileURL) {
                    try FileManager.default.removeItem(at: fileURL)
                    eventContinuation.yield(.corruptedFileCleaned(fileURL))
                }
            }
        }
        
        // Update storage info
        await updateStorageInfo()
    }
    
    func optimizeStorage() async throws {
        // Compress large files
        let enumerator = FileManager.default.enumerator(at: documentsDirectory, includingPropertiesForKeys: [.fileSizeKey])
        
        for case let fileURL as URL in enumerator {
            if fileURL.pathExtension.lowercased() == "mp4" ||
               fileURL.pathExtension.lowercased() == "mov" {
                
                let fileSize = try fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
                
                if fileSize > 100 * 1024 * 1024 { // Larger than 100MB
                    try await compressVideoFile(fileURL)
                }
            }
        }
        
        // Update storage info
        await updateStorageInfo()
        
        eventContinuation.yield(.storageOptimized)
    }
    
    // MARK: - Private Methods
    
    private func initializeStorage() async {
        // Create necessary directories
        do {
            try FileManager.default.createDirectory(at: documentsDirectory.appendingPathComponent("videos"), withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: cacheDirectory.appendingPathComponent("thumbnails"), withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: cacheDirectory.appendingPathComponent("metadata"), withIntermediateDirectories: true)
        } catch {
            eventContinuation.yield(.error(VideoStorageManagerError.initializationFailed(error)))
        }
    }
    
    private func updateStorageInfo() async {
        let totalSpace = await getTotalSpace()
        let availableSpace = await getAvailableSpace()
        let usedSpace = totalSpace - availableSpace
        
        var videoCount = 0
        var totalVideoSize: Int64 = 0
        var totalDuration: TimeInterval = 0
        
        let enumerator = FileManager.default.enumerator(at: documentsDirectory, includingPropertiesForKeys: [.fileSizeKey])
        
        for case let fileURL as URL in enumerator {
            if fileURL.pathExtension.lowercased() == "mp4" ||
               fileURL.pathExtension.lowercased() == "mov" ||
               fileURL.pathExtension.lowercased() == "heic" {
                
                videoCount += 1
                let fileSize = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
                totalVideoSize += fileSize
                
                // Get duration
                let asset = AVAsset(url: fileURL)
                let duration = asset.duration.seconds
                totalDuration += duration
            }
        }
        
        storageInfo = VideoStorageInfo(
            totalSpace: totalSpace,
            availableSpace: availableSpace,
            usedSpace: usedSpace,
            videoCount: videoCount,
            totalVideoSize: totalVideoSize,
            averageVideoSize: videoCount > 0 ? totalVideoSize / Int64(videoCount) : 0,
            totalDuration: totalDuration,
            averageDuration: videoCount > 0 ? totalDuration / Double(videoCount) : 0
        )
        
        eventContinuation.yield(.storageInfoUpdated(storageInfo))
    }
    
    private func updateCacheInfo() async {
        var thumbnailCount = 0
        var metadataCount = 0
        var totalCacheSize: Int64 = 0
        
        let enumerator = FileManager.default.enumerator(at: cacheDirectory, includingPropertiesForKeys: [.fileSizeKey])
        
        for case let fileURL as URL in enumerator {
            let fileSize = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
            totalCacheSize += fileSize
            
            if fileURL.pathExtension.lowercased() == "png" {
                thumbnailCount += 1
            } else if fileURL.pathExtension.lowercased() == "json" {
                metadataCount += 1
            }
        }
        
        cacheInfo = VideoCacheInfo(
            totalSize: totalCacheSize,
            thumbnailCount: thumbnailCount,
            metadataCount: metadataCount,
            averageThumbnailSize: thumbnailCount > 0 ? totalCacheSize / Int64(thumbnailCount) : 0
        )
        
        eventContinuation.yield(.cacheInfoUpdated(cacheInfo))
    }
    
    private func hasEnoughSpace(for requiredSize: Int64) async throws -> Bool {
        let availableSpace = await getAvailableSpace()
        return availableSpace > requiredSpace + (100 * 1024 * 1024) // Leave 100MB buffer
    }
    
    private func getCacheItemsToRemove(targetSize: Int64) async throws -> [CacheItem] {
        var items: [CacheItem] = []
        
        let enumerator = FileManager.default.enumerator(at: cacheDirectory, includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey])
        
        for case let fileURL as URL in enumerator {
            let attributes = try fileURL.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
            
            let item = CacheItem(
                url: fileURL,
                size: attributes.fileSize ?? 0,
                lastAccessed: attributes.contentModificationDate ?? Date()
            )
            
            items.append(item)
        }
        
        // Sort by last accessed date (oldest first)
        items.sort { $0.lastAccessed < $1.lastAccessed }
        
        // Remove items until we reach target size
        var currentSize = cacheInfo.totalSize
        var itemsToRemove: [CacheItem] = []
        
        for item in items {
            if currentSize <= targetSize {
                break
            }
            
            itemsToRemove.append(item)
            currentSize -= item.size
        }
        
        return itemsToRemove
    }
    
    private func isVideoFileCorrupted(_ url: URL) async -> Bool {
        let asset = AVAsset(url: url)
        
        // Check if asset is readable
        let status = asset.statusOfValue(forKey: "duration")
        if status == .failed {
            return true
        }
        
        // Check if duration is valid
        let duration = asset.duration.seconds
        if duration <= 0 || duration.isNaN || duration.isInfinite {
            return true
        }
        
        // Check if has video track
        if asset.tracks(withMediaType: .video).isEmpty {
            return true
        }
        
        return false
    }
    
    private func compressVideoFile(_ url: URL) async throws {
        let asset = AVAsset(url: url)
        
        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetMediumQuality) else {
            throw VideoStorageManagerError.compressionFailed
        }
        
        let compressedURL = url.appendingPathExtension("compressed.mp4")
        exportSession.outputURL = compressedURL
        exportSession.outputFileType = .mp4
        
        await withCheckedContinuation { continuation in
            exportSession.exportAsynchronously {
                continuation.resume()
            }
        }
        
        guard exportSession.status == .completed else {
            throw VideoStorageManagerError.compressionFailed
        }
        
        // Replace original file with compressed one
        try FileManager.default.removeItem(at: url)
        try FileManager.default.moveItem(at: compressedURL, to: url)
    }
}

// MARK: - Supporting Types

enum VideoStorageEvent: Sendable {
    case videoSaved(URL)
    case videoDeleted(URL)
    case videoMoved(URL, URL)
    case videoCopied(URL, URL)
    case thumbnailCached(URL, URL)
    case metadataCached(URL, URL)
    case cacheCleared
    case oldCacheCleared(Date)
    case cacheOptimized
    case iCloudBackupCompleted(URL)
    case iCloudRestoreCompleted(URL)
    case iCloudBackupDeleted(CKRecord.ID)
    case photoLibraryExportCompleted(URL)
    case tempFilesCleaned
    case corruptedFileCleaned(URL)
    case storageOptimized
    case storageInfoUpdated(VideoStorageInfo)
    case cacheInfoUpdated(VideoCacheInfo)
    case error(VideoStorageManagerError)
}

enum VideoStorageManagerError: LocalizedError, Sendable {
    case insufficientSpace
    case fileNotFound
    case thumbnailConversionFailed
    case iCloudNotAvailable
    case iCloudAssetNotFound
    case photoLibraryAccessDenied
    case compressionFailed
    case initializationFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .insufficientSpace:
            return "Insufficient storage space"
        case .fileNotFound:
            return "File not found"
        case .thumbnailConversionFailed:
            return "Failed to convert thumbnail"
        case .iCloudNotAvailable:
            return "iCloud is not available"
        case .iCloudAssetNotFound:
            return "iCloud asset not found"
        case .photoLibraryAccessDenied:
            return "Photo library access denied"
        case .compressionFailed:
            return "Video compression failed"
        case .initializationFailed(let error):
            return "Storage initialization failed: \(error.localizedDescription)"
        }
    }
}

struct VideoStorageInfo: Sendable {
    let totalSpace: Int64
    let availableSpace: Int64
    let usedSpace: Int64
    let videoCount: Int
    let totalVideoSize: Int64
    let averageVideoSize: Int64
    let totalDuration: TimeInterval
    let averageDuration: TimeInterval
    
    init(
        totalSpace: Int64 = 0,
        availableSpace: Int64 = 0,
        usedSpace: Int64 = 0,
        videoCount: Int = 0,
        totalVideoSize: Int64 = 0,
        averageVideoSize: Int64 = 0,
        totalDuration: TimeInterval = 0,
        averageDuration: TimeInterval = 0
    ) {
        self.totalSpace = totalSpace
        self.availableSpace = availableSpace
        self.usedSpace = usedSpace
        self.videoCount = videoCount
        self.totalVideoSize = totalVideoSize
        self.averageVideoSize = averageVideoSize
        self.totalDuration = totalDuration
        self.averageDuration = averageDuration
    }
    
    var formattedTotalSpace: String {
        return ByteCountFormatter.string(fromByteCount: totalSpace, countStyle: .file)
    }
    
    var formattedAvailableSpace: String {
        return ByteCountFormatter.string(fromByteCount: availableSpace, countStyle: .file)
    }
    
    var formattedUsedSpace: String {
        return ByteCountFormatter.string(fromByteCount: usedSpace, countStyle: .file)
    }
    
    var formattedTotalVideoSize: String {
        return ByteCountFormatter.string(fromByteCount: totalVideoSize, countStyle: .file)
    }
    
    var formattedAverageVideoSize: String {
        return ByteCountFormatter.string(fromByteCount: averageVideoSize, countStyle: .file)
    }
    
    var formattedTotalDuration: String {
        let hours = Int(totalDuration) / 3600
        let minutes = (Int(totalDuration) % 3600) / 60
        let seconds = Int(totalDuration) % 60
        
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
    
    var formattedAverageDuration: String {
        let minutes = Int(averageDuration) / 60
        let seconds = Int(averageDuration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    var usagePercentage: Double {
        guard totalSpace > 0 else { return 0 }
        return Double(usedSpace) / Double(totalSpace)
    }
}

struct VideoCacheInfo: Sendable {
    let totalSize: Int64
    let thumbnailCount: Int
    let metadataCount: Int
    let averageThumbnailSize: Int64
    
    init(
        totalSize: Int64 = 0,
        thumbnailCount: Int = 0,
        metadataCount: Int = 0,
        averageThumbnailSize: Int64 = 0
    ) {
        self.totalSize = totalSize
        self.thumbnailCount = thumbnailCount
        self.metadataCount = metadataCount
        self.averageThumbnailSize = averageThumbnailSize
    }
    
    var formattedTotalSize: String {
        return ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
    }
    
    var formattedAverageThumbnailSize: String {
        return ByteCountFormatter.string(fromByteCount: averageThumbnailSize, countStyle: .file)
    }
}

struct VideoStorageMetrics: Sendable {
    var totalSaves: Int = 0
    var totalDeletes: Int = 0
    var totalCacheHits: Int = 0
    var totalCacheMisses: Int = 0
    var totaliCloudBackups: Int = 0
    var totalPhotoLibraryExports: Int = 0
    var totalCompressions: Int = 0
    var totalCleanupOperations: Int = 0
    
    var cacheHitRate: Double {
        let totalRequests = totalCacheHits + totalCacheMisses
        return totalRequests > 0 ? Double(totalCacheHits) / Double(totalRequests) : 0
    }
    
    var formattedCacheHitRate: String {
        return String(format: "%.1f%%", cacheHitRate * 100)
    }
}

struct CacheItem: Sendable {
    let url: URL
    let size: Int64
    let lastAccessed: Date
}