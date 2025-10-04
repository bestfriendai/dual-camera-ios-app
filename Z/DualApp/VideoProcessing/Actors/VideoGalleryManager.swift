//
//  VideoGalleryManager.swift
//  DualApp
//
//  Created by DualApp Team on 10/3/25.
//

import Foundation
import AVFoundation
import Photos
import SwiftUI
import Combine

// MARK: - Video Gallery Manager

actor VideoGalleryManager: Sendable {
    
    // MARK: - Properties
    
    private var videoItems: [VideoItem] = []
    private var filteredItems: [VideoItem] = []
    private var selectedItems: Set<UUID> = []
    
    // MARK: - Sorting and Filtering
    
    private var sortOption: VideoSortOption = .dateDescending
    private var filterOption: VideoFilterOption = .all
    private var searchText: String = ""
    
    // MARK: - Caching
    
    private var thumbnailCache: [URL: UIImage] = [:]
    private var metadataCache: [URL: VideoMetadata] = [:]
    
    // MARK: - Event Stream
    
    let events: AsyncStream<VideoGalleryEvent>
    private let eventContinuation: AsyncStream<VideoGalleryEvent>.Continuation
    
    // MARK: - Performance
    
    private var isLoadingThumbnails: Bool = false
    private var thumbnailLoadQueue: [URL] = []
    
    // MARK: - Initialization
    
    init() {
        (self.events, self.eventContinuation) = AsyncStream<VideoGalleryEvent>.makeStream()
        
        // Load existing videos
        Task {
            await loadVideoItems()
        }
    }
    
    // MARK: - Public Interface
    
    func loadVideoItems() async {
        await loadVideosFromDocuments()
        await loadVideosFromPhotoLibrary()
        await applySortingAndFiltering()
        
        eventContinuation.yield(.galleryLoaded(videoItems))
    }
    
    func refreshGallery() async {
        videoItems.removeAll()
        thumbnailCache.removeAll()
        metadataCache.removeAll()
        
        await loadVideoItems()
    }
    
    func getVideoItems() async -> [VideoItem] {
        return filteredItems
    }
    
    func getVideoItem(id: UUID) async -> VideoItem? {
        return videoItems.first { $0.id == id }
    }
    
    func getSelectedItems() async -> [VideoItem] {
        return videoItems.filter { selectedItems.contains($0.id) }
    }
    
    func selectItem(id: UUID) async {
        selectedItems.insert(id)
        eventContinuation.yield(.selectionChanged(selectedItems))
    }
    
    func deselectItem(id: UUID) async {
        selectedItems.remove(id)
        eventContinuation.yield(.selectionChanged(selectedItems))
    }
    
    func toggleSelection(id: UUID) async {
        if selectedItems.contains(id) {
            await deselectItem(id: id)
        } else {
            await selectItem(id: id)
        }
    }
    
    func selectAll() async {
        selectedItems.removeAll()
        for item in filteredItems {
            selectedItems.insert(item.id)
        }
        eventContinuation.yield(.selectionChanged(selectedItems))
    }
    
    func deselectAll() async {
        selectedItems.removeAll()
        eventContinuation.yield(.selectionChanged(selectedItems))
    }
    
    func deleteItem(id: UUID) async throws {
        guard let item = videoItems.first(where: { $0.id == id }) else {
            throw VideoGalleryManagerError.itemNotFound
        }
        
        // Delete file
        try FileManager.default.removeItem(at: item.url)
        
        // Remove from arrays
        videoItems.removeAll { $0.id == id }
        filteredItems.removeAll { $0.id == id }
        selectedItems.remove(id)
        
        // Clear cache
        thumbnailCache.removeValue(forKey: item.url)
        metadataCache.removeValue(forKey: item.url)
        
        eventContinuation.yield(.itemDeleted(item))
    }
    
    func deleteSelectedItems() async throws {
        let itemsToDelete = await getSelectedItems()
        
        for item in itemsToDelete {
            try await deleteItem(id: item.id)
        }
        
        await deselectAll()
        eventContinuation.yield(.batchDeleted(itemsToDelete))
    }
    
    func getThumbnail(for url: URL) async -> UIImage? {
        // Check cache first
        if let cachedThumbnail = thumbnailCache[url] {
            return cachedThumbnail
        }
        
        // Generate thumbnail
        let thumbnail = await generateThumbnail(for: url)
        
        // Cache thumbnail
        if let thumbnail = thumbnail {
            thumbnailCache[url] = thumbnail
        }
        
        return thumbnail
    }
    
    func getMetadata(for url: URL) async -> VideoMetadata? {
        // Check cache first
        if let cachedMetadata = metadataCache[url] {
            return cachedMetadata
        }
        
        // Extract metadata
        let metadata = await extractMetadata(for: url)
        
        // Cache metadata
        if let metadata = metadata {
            metadataCache[url] = metadata
        }
        
        return metadata
    }
    
    func setSortOption(_ option: VideoSortOption) async {
        sortOption = option
        await applySortingAndFiltering()
        eventContinuation.yield(.sortingChanged(option))
    }
    
    func setFilterOption(_ option: VideoFilterOption) async {
        filterOption = option
        await applySortingAndFiltering()
        eventContinuation.yield(.filterChanged(option))
    }
    
    func setSearchText(_ text: String) async {
        searchText = text.lowercased()
        await applySortingAndFiltering()
        eventContinuation.yield(.searchChanged(text))
    }
    
    func shareItem(id: UUID) async throws -> URL {
        guard let item = videoItems.first(where: { $0.id == id }) else {
            throw VideoGalleryManagerError.itemNotFound
        }
        
        return item.url
    }
    
    func shareSelectedItems() async throws -> [URL] {
        let itemsToShare = await getSelectedItems()
        return itemsToShare.map { $0.url }
    }
    
    func exportItem(id: UUID, to destination: VideoExportDestination) async throws -> URL {
        guard let item = videoItems.first(where: { $0.id == id }) else {
            throw VideoGalleryManagerError.itemNotFound
        }
        
        return try await exportVideo(item: item, to: destination)
    }
    
    func exportSelectedItems(to destination: VideoExportDestination) async throws -> [URL] {
        let itemsToExport = await getSelectedItems()
        var exportedURLs: [URL] = []
        
        for item in itemsToExport {
            let exportedURL = try await exportVideo(item: item, to: destination)
            exportedURLs.append(exportedURL)
        }
        
        return exportedURLs
    }
    
    func getStorageInfo() async -> VideoStorageInfo {
        let totalSize = await calculateTotalSize()
        let itemCount = videoItems.count
        let totalDuration = await calculateTotalDuration()

        return VideoStorageInfo(
            totalSpace: 0, // Not applicable for gallery manager
            availableSpace: 0, // Not applicable for gallery manager
            usedSpace: totalSize,
            videoCount: itemCount,
            totalVideoSize: totalSize,
            averageVideoSize: itemCount > 0 ? totalSize / Int64(itemCount) : 0,
            totalDuration: totalDuration,
            averageDuration: itemCount > 0 ? totalDuration / Double(itemCount) : 0
        )
    }
    
    // MARK: - Private Methods
    
    private func loadVideosFromDocuments() async {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        
        do {
            let contents = try FileManager.default.contentsOfDirectory(
                at: documentsPath,
                includingPropertiesForKeys: [.fileSizeKey, .creationDateKey],
                options: [.skipsHiddenFiles]
            )
            
            for url in contents {
                if url.pathExtension.lowercased() == "mp4" || 
                   url.pathExtension.lowercased() == "mov" ||
                   url.pathExtension.lowercased() == "heic" {
                    
                    let item = await createVideoItem(from: url, source: .documents)
                    videoItems.append(item)
                }
            }
        } catch {
            eventContinuation.yield(.error(VideoGalleryManagerError.loadFailed(error)))
        }
    }
    
    private func loadVideosFromPhotoLibrary() async {
        let status = await PHPhotoLibrary.authorizationStatus()
        guard status == .authorized else { return }
        
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        fetchOptions.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.video.rawValue)
        
        let fetchResult = PHAsset.fetchAssets(with: .video, options: fetchOptions)
        
        fetchResult.enumerateObjects { [self] asset, _, _ in
            Task {
                let item = await self.createVideoItem(from: asset, source: .photoLibrary)
                self.videoItems.append(item)
            }
        }
    }
    
    private func createVideoItem(from url: URL, source: VideoSource) async -> VideoItem {
        let metadata = await getMetadata(for: url) ?? VideoMetadata()
        let thumbnail = await getThumbnail(for: url)
        
        return VideoItem(
            id: UUID(),
            url: url,
            source: source,
            metadata: metadata,
            thumbnail: thumbnail,
            createdAt: metadata.creationDate ?? Date(),
            duration: metadata.duration ?? 0,
            fileSize: metadata.fileSize ?? 0
        )
    }
    
    private func createVideoItem(from asset: PHAsset, source: VideoSource) async -> VideoItem {
        let metadata = await extractMetadata(from: asset)
        let thumbnail = await generateThumbnail(from: asset)
        
        return VideoItem(
            id: UUID(),
            url: URL(string: "ph://\(asset.localIdentifier)")!,
            source: source,
            metadata: metadata,
            thumbnail: thumbnail,
            createdAt: asset.creationDate ?? Date(),
            duration: metadata.duration ?? 0,
            fileSize: 0 // Photo library assets don't have direct file size
        )
    }
    
    private func generateThumbnail(for url: URL) async -> UIImage? {
        let asset = AVURLAsset(url: url)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        imageGenerator.maximumSize = CGSize(width: 300, height: 300)
        
        do {
            let cgImage = try imageGenerator.copyCGImage(at: .zero, actualTime: nil)
            return UIImage(cgImage: cgImage)
        } catch {
            return nil
        }
    }
    
    private func generateThumbnail(from asset: PHAsset) async -> UIImage? {
        let imageManager = PHImageManager.default()
        let options = PHImageRequestOptions()
        options.isSynchronous = true
        options.deliveryMode = .highQualityFormat
        
        return await withCheckedContinuation { continuation in
            imageManager.requestImage(
                for: asset,
                targetSize: CGSize(width: 300, height: 300),
                contentMode: .aspectFill,
                options: options
            ) { image, _ in
                continuation.resume(returning: image)
            }
        }
    }
    
    private func extractMetadata(for url: URL) async -> VideoMetadata? {
        let asset = AVURLAsset(url: url)
        
        guard let duration = try? asset.duration.seconds,
              let track = asset.tracks(withMediaType: .video).first else {
            return nil
        }
        
        let naturalSize = track.naturalSize.applying(track.preferredTransform)
        let size = CGSize(width: abs(naturalSize.width), height: abs(naturalSize.height))
        
        let fileSize = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64) ?? 0
        
        // Extract creation date
        var creationDate: Date?
        if let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
           let date = attributes[.creationDate] as? Date {
            creationDate = date
        }
        
        return VideoMetadata(
            title: url.deletingPathExtension().lastPathComponent,
            duration: duration,
            fileSize: fileSize,
            resolution: size,
            frameRate: track.nominalFrameRate,
            bitrate: Double(track.estimatedDataRate),
            creationDate: creationDate,
            modificationDate: nil,
            codec: track.formatDescriptions.first.map { CMFormatDescriptionGetMediaSubType($0 as! CMFormatDescription) }.map { String(describing: $0) },
            format: url.pathExtension.uppercased(),
            location: nil,
            customMetadata: [:]
        )
    }
    
    private func extractMetadata(from asset: PHAsset) async -> VideoMetadata {
        let resources = PHAssetResource.assetResources(for: asset)
        let videoResource = resources.first { $0.type == .video }
        
        return VideoMetadata(
            title: asset.value(forKey: "filename") as? String ?? "Unknown",
            duration: asset.duration,
            fileSize: videoResource?.value(forKey: "fileSize") as? Int64 ?? 0,
            resolution: CGSize(width: asset.pixelWidth, height: asset.pixelHeight),
            frameRate: 30, // Default, not available from PHAsset
            bitrate: 0, // Not available from PHAsset
            creationDate: asset.creationDate,
            modificationDate: asset.modificationDate,
            codec: nil,
            format: (videoResource?.originalFilename as NSString?)?.pathExtension.uppercased() ?? "MP4",
            location: asset.location,
            customMetadata: [:]
        )
    }
    
    private func applySortingAndFiltering() async {
        // Apply filtering
        filteredItems = videoItems.filter { item in
            // Search filter
            if !searchText.isEmpty {
                let matchesSearch = item.metadata.title.lowercased().contains(searchText) ||
                                  item.metadata.customMetadata.values.contains { $0.lowercased().contains(searchText) }
                if !matchesSearch { return false }
            }
            
            // Type filter
            switch filterOption {
            case .all:
                return true
            case .documents:
                return item.source == .documents
            case .photoLibrary:
                return item.source == .photoLibrary
            case .shortVideos:
                return item.duration < 60
            case .longVideos:
                return item.duration >= 60
            case .largeFiles:
                return item.fileSize > 100_000_000 // 100MB
            case .smallFiles:
                return item.fileSize <= 100_000_000 // 100MB
            }
        }
        
        // Apply sorting
        switch sortOption {
        case .dateAscending:
            filteredItems.sort { $0.createdAt < $1.createdAt }
        case .dateDescending:
            filteredItems.sort { $0.createdAt > $1.createdAt }
        case .titleAscending:
            filteredItems.sort { $0.metadata.title < $1.metadata.title }
        case .titleDescending:
            filteredItems.sort { $0.metadata.title > $1.metadata.title }
        case .durationAscending:
            filteredItems.sort { $0.duration < $1.duration }
        case .durationDescending:
            filteredItems.sort { $0.duration > $1.duration }
        case .sizeAscending:
            filteredItems.sort { $0.fileSize < $1.fileSize }
        case .sizeDescending:
            filteredItems.sort { $0.fileSize > $1.fileSize }
        }
        
        eventContinuation.yield(.itemsUpdated(filteredItems))
    }
    
    private func exportVideo(item: VideoItem, to destination: VideoExportDestination) async throws -> URL {
        switch destination {
        case .documents:
            return try await exportToDocuments(item: item)
        case .photoLibrary:
            return try await exportToPhotoLibrary(item: item)
        case .sharedFolder:
            return try await exportToSharedFolder(item: item)
        case .cloud:
            return try await exportToCloud(item: item)
        }
    }
    
    private func exportToDocuments(item: VideoItem) async throws -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let exportURL = documentsPath.appendingPathComponent("exported_\(item.metadata.title).\(item.metadata.format.lowercased())")
        
        if item.source == .photoLibrary {
            // Export from photo library
            let asset = PHAsset.fetchAssets(withLocalIdentifiers: [item.url.absoluteString.replacingOccurrences(of: "ph://", with: "")], options: nil).firstObject
            guard let asset = asset else {
                throw VideoGalleryManagerError.exportFailed("Asset not found")
            }
            
            // This would require PHAssetResource to export the actual file
            throw VideoGalleryManagerError.exportFailed("Photo library export not implemented")
        } else {
            // Copy from documents
            try FileManager.default.copyItem(at: item.url, to: exportURL)
        }
        
        return exportURL
    }
    
    private func exportToPhotoLibrary(item: VideoItem) async throws -> URL {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized else {
            throw VideoGalleryManagerError.photoLibraryAccessDenied
        }
        
        try await PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: item.url)
        }
        
        return item.url
    }
    
    private func exportToSharedFolder(item: VideoItem) async throws -> URL {
        let sharedPath = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.dualapp.shared")
        guard let sharedPath = sharedPath else {
            throw VideoGalleryManagerError.exportFailed("Shared container not available")
        }
        
        let exportURL = sharedPath.appendingPathComponent("shared_\(item.metadata.title).\(item.metadata.format.lowercased())")
        try FileManager.default.copyItem(at: item.url, to: exportURL)
        
        return exportURL
    }
    
    private func exportToCloud(item: VideoItem) async throws -> URL {
        // This would integrate with iCloud or other cloud services
        throw VideoGalleryManagerError.exportFailed("Cloud export not implemented")
    }
    
    private func calculateTotalSize() async -> Int64 {
        return videoItems.reduce(0) { $0 + $1.fileSize }
    }
    
    private func calculateTotalDuration() async -> TimeInterval {
        return videoItems.reduce(0) { $0 + $1.duration }
    }
}

// MARK: - Supporting Types

enum VideoGalleryEvent: Sendable {
    case galleryLoaded([VideoItem])
    case itemDeleted(VideoItem)
    case batchDeleted([VideoItem])
    case selectionChanged(Set<UUID>)
    case sortingChanged(VideoSortOption)
    case filterChanged(VideoFilterOption)
    case searchChanged(String)
    case itemsUpdated([VideoItem])
    case error(VideoGalleryManagerError)
}

enum VideoGalleryManagerError: LocalizedError, Sendable {
    case itemNotFound
    case loadFailed(Error)
    case exportFailed(String)
    case photoLibraryAccessDenied
    
    var errorDescription: String? {
        switch self {
        case .itemNotFound:
            return "Video item not found"
        case .loadFailed(let error):
            return "Failed to load videos: \(error.localizedDescription)"
        case .exportFailed(let reason):
            return "Export failed: \(reason)"
        case .photoLibraryAccessDenied:
            return "Photo library access denied"
        }
    }
}

enum VideoSortOption: String, CaseIterable, Sendable {
    case dateAscending = "Date (Oldest First)"
    case dateDescending = "Date (Newest First)"
    case titleAscending = "Title (A-Z)"
    case titleDescending = "Title (Z-A)"
    case durationAscending = "Duration (Shortest First)"
    case durationDescending = "Duration (Longest First)"
    case sizeAscending = "Size (Smallest First)"
    case sizeDescending = "Size (Largest First)"
    
    var icon: String {
        switch self {
        case .dateAscending, .dateDescending:
            return "calendar"
        case .titleAscending, .titleDescending:
            return "textformat.abc"
        case .durationAscending, .durationDescending:
            return "clock"
        case .sizeAscending, .sizeDescending:
            return "doc"
        }
    }
}

enum VideoFilterOption: String, CaseIterable, Sendable {
    case all = "All Videos"
    case documents = "Documents"
    case photoLibrary = "Photo Library"
    case shortVideos = "Short Videos (< 1 min)"
    case longVideos = "Long Videos (≥ 1 min)"
    case largeFiles = "Large Files (> 100 MB)"
    case smallFiles = "Small Files (≤ 100 MB)"
    
    var icon: String {
        switch self {
        case .all:
            return "video"
        case .documents:
            return "folder"
        case .photoLibrary:
            return "photo"
        case .shortVideos:
            return "clock.badge.minus"
        case .longVideos:
            return "clock.badge.plus"
        case .largeFiles:
            return "doc.badge.plus"
        case .smallFiles:
            return "doc.badge.minus"
        }
    }
}

enum VideoSource: String, Sendable {
    case documents = "Documents"
    case photoLibrary = "Photo Library"
    case dualCamera = "Dual Camera"

    var icon: String {
        switch self {
        case .documents:
            return "folder"
        case .photoLibrary:
            return "photo"
        case .dualCamera:
            return "camera"
        }
    }
}

enum VideoExportDestination: String, CaseIterable, Sendable {
    case documents = "Documents"
    case photoLibrary = "Photo Library"
    case sharedFolder = "Shared Folder"
    case cloud = "Cloud"
    
    var icon: String {
        switch self {
        case .documents:
            return "folder"
        case .photoLibrary:
            return "photo"
        case .sharedFolder:
            return "person.2"
        case .cloud:
            return "icloud"
        }
    }
}

struct VideoItem: Sendable, Identifiable {
    let id: UUID
    let url: URL
    let source: VideoSource
    let metadata: VideoMetadata
    let thumbnail: UIImage?
    let createdAt: Date
    let duration: TimeInterval
    let fileSize: Int64
    
    var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    var formattedFileSize: String {
        return ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
    }
}

struct VideoMetadata: Sendable {
    var title: String = ""
    var duration: TimeInterval = 0
    var fileSize: Int64 = 0
    var resolution: CGSize = .zero
    var frameRate: Float = 0
    var bitrate: Double = 0
    var creationDate: Date?
    var modificationDate: Date?
    var codec: String?
    var format: String = ""
    var location: CLLocation?
    var customMetadata: [String: String] = [:]
    
    var formattedResolution: String {
        if resolution == .zero {
            return "Unknown"
        }
        return "\(Int(resolution.width))×\(Int(resolution.height))"
    }
    
    var formattedFrameRate: String {
        return String(format: "%.0f fps", frameRate)
    }
    
    var formattedBitrate: String {
        return String(format: "%.0f kbps", bitrate / 1000)
    }
}



