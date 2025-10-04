//
//  VideoPlayerManager.swift
//  DualApp
//
//  Created by DualApp Team on 10/3/25.
//

import Foundation
import AVFoundation
import Combine

// MARK: - Video Player Manager

@MainActor
class VideoPlayerManager: ObservableObject {
    
    // MARK: - Properties
    
    @Published var player: AVPlayer?
    @Published var isPlaying: Bool = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var playbackSpeed: Float = 1.0
    @Published var currentQuality: VideoQuality = .hd1080
    @Published var isLoading: Bool = false
    @Published var isBuffering: Bool = false
    
    // MARK: - Private Properties
    
    private var playerItem: AVPlayerItem?
    private var timeObserver: Any?
    private var rateObserver: NSKeyValueObservation?
    private var statusObserver: NSKeyValueObservation?
    private var loadedTimeRangesObserver: NSKeyValueObservation?
    
    // MARK: - Initialization
    
    init() {
        setupNotifications()
    }
    
    deinit {
        cleanup()
    }
    
    // MARK: - Public Methods
    
    func loadVideo(_ url: URL) async {
        isLoading = true
        
        // Create player item
        let asset = AVAsset(url: url)
        playerItem = AVPlayerItem(asset: asset)
        
        // Create player
        player = AVPlayer(playerItem: playerItem)
        
        // Setup observers
        setupObservers()
        
        // Wait for asset to load
        await asset.loadValues(forKeys: ["duration", "tracks"])
        
        if asset.statusOfValue(forKey: "duration") == .loaded {
            duration = asset.duration.seconds
        }
        
        isLoading = false
    }
    
    func togglePlayPause() {
        guard let player = player else { return }
        
        if isPlaying {
            player.pause()
        } else {
            player.play()
        }
    }
    
    func play() {
        player?.play()
    }
    
    func pause() {
        player?.pause()
    }
    
    func stop() {
        player?.pause()
        player?.seek(to: .zero)
    }
    
    func seek(to time: TimeInterval) {
        let cmTime = CMTime(seconds: time, preferredTimescale: 600)
        player?.seek(to: cmTime)
    }
    
    func seek(to percentage: Double) {
        let time = duration * percentage
        seek(to: time)
    }
    
    func skipForward(_ seconds: TimeInterval = 10) {
        let newTime = min(currentTime + seconds, duration)
        seek(to: newTime)
    }
    
    func skipBackward(_ seconds: TimeInterval = 10) {
        let newTime = max(currentTime - seconds, 0)
        seek(to: newTime)
    }
    
    func stepForward() {
        player?.currentItem?.step(byCount: 1)
    }
    
    func stepBackward() {
        player?.currentItem?.step(byCount: -1)
    }
    
    func setPlaybackSpeed(_ speed: Float) {
        playbackSpeed = speed
        player?.rate = isPlaying ? speed : 0
    }
    
    func setQuality(_ quality: VideoQuality) {
        currentQuality = quality
        // In a real implementation, this would switch to a different quality stream
    }
    
    func setVolume(_ volume: Float) {
        player?.volume = volume
    }
    
    func exportTo(_ destination: VideoExportDestination) async throws -> URL {
        guard let playerItem = playerItem else {
            throw VideoPlayerManagerError.noVideoLoaded
        }
        
        let asset = playerItem.asset
        let outputURL = generateOutputURL(for: destination)
        
        let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHighestQuality)
        exportSession?.outputURL = outputURL
        exportSession?.outputFileType = .mp4
        
        await withCheckedContinuation { continuation in
            exportSession?.exportAsynchronously {
                continuation.resume()
            }
        }
        
        guard exportSession?.status == .completed else {
            throw VideoPlayerManagerError.exportFailed(exportSession?.error?.localizedDescription ?? "Unknown error")
        }
        
        return outputURL
    }
    
    func trim(from startTime: TimeInterval, to endTime: TimeInterval) async throws -> URL {
        guard let playerItem = playerItem else {
            throw VideoPlayerManagerError.noVideoLoaded
        }
        
        let asset = playerItem.asset
        let outputURL = generateOutputURL(for: .documents)
        
        let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHighestQuality)
        exportSession?.outputURL = outputURL
        exportSession?.outputFileType = .mp4
        
        let startCMTime = CMTime(seconds: startTime, preferredTimescale: 600)
        let endCMTime = CMTime(seconds: endTime, preferredTimescale: 600)
        let timeRange = CMTimeRange(start: startCMTime, end: endCMTime)
        
        exportSession?.timeRange = timeRange
        
        await withCheckedContinuation { continuation in
            exportSession?.exportAsynchronously {
                continuation.resume()
            }
        }
        
        guard exportSession?.status == .completed else {
            throw VideoPlayerManagerError.exportFailed(exportSession?.error?.localizedDescription ?? "Unknown error")
        }
        
        return outputURL
    }
    
    func cleanup() {
        removeObservers()
        player?.pause()
        player = nil
        playerItem = nil
    }
    
    // MARK: - Private Methods
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerDidFinishPlaying),
            name: .AVPlayerItemDidPlayToEndTime,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
    }
    
    private func setupObservers() {
        guard let playerItem = playerItem else { return }
        
        // Time observer
        timeObserver = player?.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.1, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            self?.currentTime = time.seconds
        }
        
        // Rate observer
        rateObserver = player?.observe(\.rate) { [weak self] player, _ in
            DispatchQueue.main.async {
                self?.isPlaying = player.rate > 0
            }
        }
        
        // Status observer
        statusObserver = playerItem.observe(\.status) { [weak self] item, _ in
            DispatchQueue.main.async {
                switch item.status {
                case .readyToPlay:
                    self?.isLoading = false
                case .failed:
                    self?.isLoading = false
                    // Handle error
                case .unknown:
                    break
                @unknown default:
                    break
                }
            }
        }
        
        // Loaded time ranges observer
        loadedTimeRangesObserver = playerItem.observe(\.loadedTimeRanges) { [weak self] item, _ in
            DispatchQueue.main.async {
                self?.updateBufferingStatus(item: item)
            }
        }
    }
    
    private func removeObservers() {
        if let timeObserver = timeObserver {
            player?.removeTimeObserver(timeObserver)
        }
        
        rateObserver?.invalidate()
        statusObserver?.invalidate()
        loadedTimeRangesObserver?.invalidate()
        
        timeObserver = nil
        rateObserver = nil
        statusObserver = nil
        loadedTimeRangesObserver = nil
    }
    
    private func updateBufferingStatus(item: AVPlayerItem) {
        guard !item.loadedTimeRanges.isEmpty else {
            isBuffering = true
            return
        }
        
        let timeRange = item.loadedTimeRanges.first!.timeRangeValue
        let bufferedTime = CMTimeGetSeconds(timeRange.start) + CMTimeGetSeconds(timeRange.duration)
        
        isBuffering = bufferedTime < currentTime + 1.0 // Buffer if less than 1 second ahead
    }
    
    private func generateOutputURL(for destination: VideoExportDestination) -> URL {
        let timestamp = Int(Date().timeIntervalSince1970)
        
        switch destination {
        case .documents:
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            return documentsPath.appendingPathComponent("exported_\(timestamp).mp4")
        case .photoLibrary:
            let tempPath = FileManager.default.temporaryDirectory
            return tempPath.appendingPathComponent("exported_\(timestamp).mp4")
        case .sharedFolder:
            let sharedPath = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.dualapp.shared")
            return sharedPath?.appendingPathComponent("shared_\(timestamp).mp4") ?? FileManager.default.temporaryDirectory.appendingPathComponent("shared_\(timestamp).mp4")
        case .cloud:
            let tempPath = FileManager.default.temporaryDirectory
            return tempPath.appendingPathComponent("cloud_export_\(timestamp).mp4")
        }
    }
    
    // MARK: - Notification Handlers
    
    @objc private func playerDidFinishPlaying() {
        // Handle playback completion
        isPlaying = false
    }
    
    @objc private func applicationDidEnterBackground() {
        // Handle background state
        pause()
    }
    
    @objc private func applicationWillEnterForeground() {
        // Handle foreground state
        // Resume playback if needed
    }
}

// MARK: - Dual Camera Player Manager

@MainActor
class DualCameraPlayerManager: ObservableObject {
    
    // MARK: - Properties
    
    @Published var frontPlayer: AVPlayer?
    @Published var backPlayer: AVPlayer?
    @Published var isPlaying: Bool = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var playbackSpeed: Float = 1.0
    @Published var isLoading: Bool = false
    @Published var isBuffering: Bool = false
    
    // MARK: - Private Properties
    
    private var frontPlayerItem: AVPlayerItem?
    private var backPlayerItem: AVPlayerItem?
    private var timeObserver: Any?
    private var rateObserver: NSKeyValueObservation?
    private var statusObserver: NSKeyValueObservation?
    
    // MARK: - Initialization
    
    init() {
        setupNotifications()
    }
    
    deinit {
        cleanup()
    }
    
    // MARK: - Public Methods
    
    func loadVideos(_ frontURL: URL, _ backURL: URL) async {
        isLoading = true
        
        // Create player items
        let frontAsset = AVAsset(url: frontURL)
        let backAsset = AVAsset(url: backURL)
        
        frontPlayerItem = AVPlayerItem(asset: frontAsset)
        backPlayerItem = AVPlayerItem(asset: backAsset)
        
        // Create players
        frontPlayer = AVPlayer(playerItem: frontPlayerItem)
        backPlayer = AVPlayer(playerItem: backPlayerItem)
        
        // Setup observers
        setupObservers()
        
        // Wait for assets to load
        await frontAsset.loadValues(forKeys: ["duration", "tracks"])
        await backAsset.loadValues(forKeys: ["duration", "tracks"])
        
        if frontAsset.statusOfValue(forKey: "duration") == .loaded {
            duration = frontAsset.duration.seconds
        }
        
        isLoading = false
    }
    
    func togglePlayPause() {
        guard let frontPlayer = frontPlayer, let backPlayer = backPlayer else { return }
        
        if isPlaying {
            frontPlayer.pause()
            backPlayer.pause()
        } else {
            frontPlayer.play()
            backPlayer.play()
        }
    }
    
    func play() {
        frontPlayer?.play()
        backPlayer?.play()
    }
    
    func pause() {
        frontPlayer?.pause()
        backPlayer?.pause()
    }
    
    func stop() {
        frontPlayer?.pause()
        backPlayer?.pause()
        frontPlayer?.seek(to: .zero)
        backPlayer?.seek(to: .zero)
    }
    
    func seek(to time: TimeInterval) {
        let cmTime = CMTime(seconds: time, preferredTimescale: 600)
        frontPlayer?.seek(to: cmTime)
        backPlayer?.seek(to: cmTime)
    }
    
    func seek(to percentage: Double) {
        let time = duration * percentage
        seek(to: time)
    }
    
    func skipForward(_ seconds: TimeInterval = 10) {
        let newTime = min(currentTime + seconds, duration)
        seek(to: newTime)
    }
    
    func skipBackward(_ seconds: TimeInterval = 10) {
        let newTime = max(currentTime - seconds, 0)
        seek(to: newTime)
    }
    
    func stepForward() {
        frontPlayer?.currentItem?.step(byCount: 1)
        backPlayer?.currentItem?.step(byCount: 1)
    }
    
    func stepBackward() {
        frontPlayer?.currentItem?.step(byCount: -1)
        backPlayer?.currentItem?.step(byCount: -1)
    }
    
    func setPlaybackSpeed(_ speed: Float) {
        playbackSpeed = speed
        frontPlayer?.rate = isPlaying ? speed : 0
        backPlayer?.rate = isPlaying ? speed : 0
    }
    
    func setVolume(_ volume: Float) {
        frontPlayer?.volume = volume
        backPlayer?.volume = volume
    }
    
    func setSynchronization(offset: TimeInterval) {
        // Synchronize the two players with an offset
        if let backPlayer = backPlayer {
            let cmTime = CMTime(seconds: offset, preferredTimescale: 600)
            backPlayer.seek(to: cmTime)
        }
    }
    
    func cleanup() {
        removeObservers()
        frontPlayer?.pause()
        backPlayer?.pause()
        frontPlayer = nil
        backPlayer = nil
        frontPlayerItem = nil
        backPlayerItem = nil
    }
    
    // MARK: - Private Methods
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerDidFinishPlaying),
            name: .AVPlayerItemDidPlayToEndTime,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
    }
    
    private func setupObservers() {
        guard let frontPlayerItem = frontPlayerItem else { return }
        
        // Time observer
        timeObserver = frontPlayer?.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.1, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            self?.currentTime = time.seconds
        }
        
        // Rate observer
        rateObserver = frontPlayer?.observe(\.rate) { [weak self] player, _ in
            DispatchQueue.main.async {
                self?.isPlaying = player.rate > 0
            }
        }
        
        // Status observer
        statusObserver = frontPlayerItem.observe(\.status) { [weak self] item, _ in
            DispatchQueue.main.async {
                switch item.status {
                case .readyToPlay:
                    self?.isLoading = false
                case .failed:
                    self?.isLoading = false
                    // Handle error
                case .unknown:
                    break
                @unknown default:
                    break
                }
            }
        }
    }
    
    private func removeObservers() {
        if let timeObserver = timeObserver {
            frontPlayer?.removeTimeObserver(timeObserver)
        }
        
        rateObserver?.invalidate()
        statusObserver?.invalidate()
        
        timeObserver = nil
        rateObserver = nil
        statusObserver = nil
    }
    
    // MARK: - Notification Handlers
    
    @objc private func playerDidFinishPlaying() {
        // Handle playback completion
        isPlaying = false
    }
    
    @objc private func applicationDidEnterBackground() {
        // Handle background state
        pause()
    }
    
    @objc private func applicationWillEnterForeground() {
        // Handle foreground state
        // Resume playback if needed
    }
}

// MARK: - Supporting Types

enum VideoPlayerManagerError: LocalizedError, Sendable {
    case noVideoLoaded
    case exportFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .noVideoLoaded:
            return "No video is currently loaded"
        case .exportFailed(let reason):
            return "Export failed: \(reason)"
        }
    }
}