//
//  VideoProcessor.swift
//  DualApp
//
//  Created by DualApp Team on 10/3/25.
//

import Foundation
import AVFoundation
import CoreImage
import CoreImage.CIFilterBuiltins
import Metal
import MetalKit
import UIKit
import VideoToolbox

// MARK: - Video Processor

@MainActor
actor VideoProcessor: Sendable {
    
    // MARK: - Properties
    
    private let ciContext: CIContext
    private let metalDevice: MTLDevice
    private let metalCommandQueue: MTLCommandQueue
    
    // MARK: - Processing State
    
    private var isProcessing: Bool = false
    private var currentJob: VideoProcessingJob?
    private var processingQueue: [VideoProcessingJob] = []
    
    // MARK: - Event Stream
    
    let events: AsyncStream<VideoProcessingEvent>
    private let eventContinuation: AsyncStream<VideoProcessingEvent>.Continuation
    
    // MARK: - Performance
    
    private var processingMetrics: VideoProcessingMetrics = VideoProcessingMetrics()
    
    // MARK: - Initialization
    
    init() {
        // Initialize Metal
        self.metalDevice = MTLCreateSystemDefaultDevice()!
        self.metalCommandQueue = metalDevice.makeCommandQueue()!
        
        // Initialize Core Image context with Metal
        self.ciContext = CIContext(mtlDevice: metalDevice, options: [
            .useSoftwareRenderer: false,
            .priorityRequestLow: false
        ])
        
        (self.events, self.eventContinuation) = AsyncStream<VideoProcessingEvent>.makeStream()
    }
    
    // MARK: - Public Interface
    
    func processVideo(_ inputURL: URL, outputURL: URL, configuration: VideoProcessingConfiguration) async throws -> URL {
        let job = VideoProcessingJob(
            id: UUID(),
            inputURL: inputURL,
            outputURL: outputURL,
            configuration: configuration,
            status: .queued,
            progress: 0.0
        )
        
        return try await processJob(job)
    }
    
    func composeVideos(_ videos: [URL], outputURL: URL, layout: VideoCompositionLayout) async throws -> URL {
        let config = VideoProcessingConfiguration(
            compositionLayout: layout,
            outputFormat: .mp4,
            quality: .high,
            frameRate: 30,
            includeAudio: true
        )
        
        let job = VideoProcessingJob(
            id: UUID(),
            inputURLs: videos,
            outputURL: outputURL,
            configuration: config,
            status: .queued,
            progress: 0.0
        )
        
        return try await processCompositionJob(job)
    }
    
    func trimVideo(_ inputURL: URL, outputURL: URL, startTime: TimeInterval, endTime: TimeInterval) async throws -> URL {
        let config = VideoProcessingConfiguration(
            trimStartTime: startTime,
            trimEndTime: endTime,
            outputFormat: .mp4,
            quality: .high
        )
        
        let job = VideoProcessingJob(
            id: UUID(),
            inputURL: inputURL,
            outputURL: outputURL,
            configuration: config,
            status: .queued,
            progress: 0.0,
            type: .trim
        )
        
        return try await processJob(job)
    }
    
    func compressVideo(_ inputURL: URL, outputURL: URL, quality: VideoCompressionQuality) async throws -> URL {
        let config = VideoProcessingConfiguration(
            compressionQuality: quality,
            outputFormat: .mp4
        )
        
        let job = VideoProcessingJob(
            id: UUID(),
            inputURL: inputURL,
            outputURL: outputURL,
            configuration: config,
            status: .queued,
            progress: 0.0,
            type: .compression
        )
        
        return try await processJob(job)
    }
    
    func addFilterToVideo(_ inputURL: URL, outputURL: URL, filter: VideoFilter) async throws -> URL {
        let config = VideoProcessingConfiguration(
            filter: filter,
            outputFormat: .mp4,
            quality: .high
        )
        
        let job = VideoProcessingJob(
            id: UUID(),
            inputURL: inputURL,
            outputURL: outputURL,
            configuration: config,
            status: .queued,
            progress: 0.0,
            type: .filter
        )
        
        return try await processJob(job)
    }
    
    func stabilizeVideo(_ inputURL: URL, outputURL: URL) async throws -> URL {
        let config = VideoProcessingConfiguration(
            stabilizationEnabled: true,
            outputFormat: .mp4,
            quality: .high
        )
        
        let job = VideoProcessingJob(
            id: UUID(),
            inputURL: inputURL,
            outputURL: outputURL,
            configuration: config,
            status: .queued,
            progress: 0.0,
            type: .stabilization
        )
        
        return try await processJob(job)
    }
    
    func extractFrames(_ inputURL: URL, outputDirectory: URL, frameRate: Int32) async throws -> [URL] {
        let asset = AVAsset(url: inputURL)
        let reader = try AVAssetReader(asset: asset)
        
        guard let videoTrack = asset.tracks(withMediaType: .video).first else {
            throw VideoProcessorError.noVideoTrack
        }
        
        let trackOutput = AVAssetReaderTrackOutput(
            track: videoTrack,
            outputSettings: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
            ]
        )
        
        reader.add(trackOutput)
        reader.startReading()
        
        var frameURLs: [URL] = []
        var frameCount = 0
        let targetFrameInterval = CMTime(value: 1, timescale: frameRate)
        var nextFrameTime = CMTime.zero
        
        while reader.status == .reading {
            autoreleasepool {
                guard let sampleBuffer = trackOutput.copyNextSampleBuffer(),
                      let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
                    return
                }
                
                let presentationTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
                
                if presentationTime >= nextFrameTime {
                    let frameURL = outputDirectory.appendingPathComponent("frame_\(frameCount).png")
                    
                    if let cgImage = CIImage(cvPixelBuffer: imageBuffer).cgImage(outputRect: CGRect(origin: .zero, size: videoTrack.naturalSize), context: ciContext) {
                        let uiImage = UIImage(cgImage: cgImage)
                        
                        if let data = uiImage.pngData() {
                            try? data.write(to: frameURL)
                            frameURLs.append(frameURL)
                            frameCount += 1
                        }
                    }
                    
                    nextFrameTime = CMTimeAdd(nextFrameTime, targetFrameInterval)
                }
            }
        }
        
        return frameURLs
    }
    
    func createPictureInPicture(_ mainVideoURL: URL, pipVideoURL: URL, outputURL: URL, pipPosition: PictureInPicturePosition) async throws -> URL {
        let config = VideoProcessingConfiguration(
            compositionLayout: .pictureInPicture(pipPosition),
            outputFormat: .mp4,
            quality: .high,
            includeAudio: true
        )
        
        let job = VideoProcessingJob(
            id: UUID(),
            inputURLs: [mainVideoURL, pipVideoURL],
            outputURL: outputURL,
            configuration: config,
            status: .queued,
            progress: 0.0,
            type: .composition
        )
        
        return try await processCompositionJob(job)
    }
    
    func createSideBySide(_ leftVideoURL: URL, rightVideoURL: URL, outputURL: URL) async throws -> URL {
        let config = VideoProcessingConfiguration(
            compositionLayout: .sideBySide,
            outputFormat: .mp4,
            quality: .high,
            includeAudio: true
        )
        
        let job = VideoProcessingJob(
            id: UUID(),
            inputURLs: [leftVideoURL, rightVideoURL],
            outputURL: outputURL,
            configuration: config,
            status: .queued,
            progress: 0.0,
            type: .composition
        )
        
        return try await processCompositionJob(job)
    }
    
    func createSplitScreen(_ topVideoURL: URL, bottomVideoURL: URL, outputURL: URL) async throws -> URL {
        let config = VideoProcessingConfiguration(
            compositionLayout: .splitScreen,
            outputFormat: .mp4,
            quality: .high,
            includeAudio: true
        )
        
        let job = VideoProcessingJob(
            id: UUID(),
            inputURLs: [topVideoURL, bottomVideoURL],
            outputURL: outputURL,
            configuration: config,
            status: .queued,
            progress: 0.0,
            type: .composition
        )
        
        return try await processCompositionJob(job)
    }
    
    func createOverlay(_ baseVideoURL: URL, overlayVideoURL: URL, outputURL: URL, blendMode: VideoBlendMode) async throws -> URL {
        let config = VideoProcessingConfiguration(
            compositionLayout: .overlay(blendMode),
            outputFormat: .mp4,
            quality: .high,
            includeAudio: true
        )
        
        let job = VideoProcessingJob(
            id: UUID(),
            inputURLs: [baseVideoURL, overlayVideoURL],
            outputURL: outputURL,
            configuration: config,
            status: .queued,
            progress: 0.0,
            type: .composition
        )
        
        return try await processCompositionJob(job)
    }
    
    func cancelProcessing(jobId: UUID) async {
        if currentJob?.id == jobId {
            currentJob?.status = .cancelled
            isProcessing = false
            eventContinuation.yield(.jobCancelled(jobId))
        } else {
            processingQueue.removeAll { $0.id == jobId }
            eventContinuation.yield(.jobCancelled(jobId))
        }
    }
    
    func getProcessingStatus() async -> VideoProcessingStatus {
        return VideoProcessingStatus(
            isProcessing: isProcessing,
            currentJob: currentJob,
            queuedJobs: processingQueue.count,
            metrics: processingMetrics
        )
    }
    
    // MARK: - Private Methods
    
    private func processJob(_ job: VideoProcessingJob) async throws -> URL {
        guard !isProcessing else {
            throw VideoProcessorError.alreadyProcessing
        }
        
        isProcessing = true
        currentJob = job
        job.status = .processing
        
        defer {
            isProcessing = false
            currentJob = nil
        }
        
        eventContinuation.yield(.jobStarted(job))
        
        let startTime = Date()
        
        do {
            let outputURL = try await executeJob(job)
            
            let duration = Date().timeIntervalSince(startTime)
            
            job.status = .completed
            job.progress = 1.0
            
            processingMetrics.totalJobsProcessed += 1
            processingMetrics.totalProcessingTime += duration
            processingMetrics.averageProcessingTime = processingMetrics.totalProcessingTime / Double(processingMetrics.totalJobsProcessed)
            
            eventContinuation.yield(.jobCompleted(job, outputURL))
            
            return outputURL
            
        } catch {
            job.status = .failed
            job.error = error
            
            eventContinuation.yield(.jobFailed(job, error))
            throw error
        }
    }
    
    private func processCompositionJob(_ job: VideoProcessingJob) async throws -> URL {
        guard !isProcessing else {
            throw VideoProcessorError.alreadyProcessing
        }
        
        isProcessing = true
        currentJob = job
        job.status = .processing
        
        defer {
            isProcessing = false
            currentJob = nil
        }
        
        eventContinuation.yield(.jobStarted(job))
        
        let startTime = Date()
        
        do {
            let outputURL = try await executeCompositionJob(job)
            
            let duration = Date().timeIntervalSince(startTime)
            
            job.status = .completed
            job.progress = 1.0
            
            processingMetrics.totalJobsProcessed += 1
            processingMetrics.totalProcessingTime += duration
            processingMetrics.averageProcessingTime = processingMetrics.totalProcessingTime / Double(processingMetrics.totalJobsProcessed)
            
            eventContinuation.yield(.jobCompleted(job, outputURL))
            
            return outputURL
            
        } catch {
            job.status = .failed
            job.error = error
            
            eventContinuation.yield(.jobFailed(job, error))
            throw error
        }
    }
    
    private func executeJob(_ job: VideoProcessingJob) async throws -> URL {
        let asset = AVAsset(url: job.inputURL)
        
        switch job.type {
        case .trim:
            return try await executeTrimJob(asset: asset, job: job)
        case .compression:
            return try await executeCompressionJob(asset: asset, job: job)
        case .filter:
            return try await executeFilterJob(asset: asset, job: job)
        case .stabilization:
            return try await executeStabilizationJob(asset: asset, job: job)
        default:
            return try await executeBasicProcessingJob(asset: asset, job: job)
        }
    }
    
    private func executeCompositionJob(_ job: VideoProcessingJob) async throws -> URL {
        let assets = job.inputURLs.map { AVAsset(url: $0) }
        
        return try await executeVideoCompositionJob(assets: assets, job: job)
    }
    
    private func executeTrimJob(asset: AVAsset, job: VideoProcessingJob) async throws -> URL {
        let startTime = CMTime(seconds: job.configuration.trimStartTime, preferredTimescale: asset.duration.timescale)
        let endTime = CMTime(seconds: job.configuration.trimEndTime, preferredTimescale: asset.duration.timescale)
        let timeRange = CMTimeRange(start: startTime, end: endTime)
        
        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHighestQuality) else {
            throw VideoProcessorError.exportSessionFailed
        }
        
        exportSession.outputURL = job.outputURL
        exportSession.outputFileType = job.configuration.outputFormat.avFileType
        exportSession.timeRange = timeRange
        
        await withCheckedContinuation { continuation in
            exportSession.exportAsynchronously {
                continuation.resume()
            }
        }
        
        guard exportSession.status == .completed else {
            throw VideoProcessorError.exportFailed(exportSession.error?.localizedDescription ?? "Unknown error")
        }
        
        return job.outputURL
    }
    
    private func executeCompressionJob(asset: AVAsset, job: VideoProcessingJob) async throws -> URL {
        guard let exportSession = AVAssetExportSession(asset: asset, presetName: job.configuration.compressionQuality.avPreset) else {
            throw VideoProcessorError.exportSessionFailed
        }
        
        exportSession.outputURL = job.outputURL
        exportSession.outputFileType = job.configuration.outputFormat.avFileType
        
        await withCheckedContinuation { continuation in
            exportSession.exportAsynchronously {
                continuation.resume()
            }
        }
        
        guard exportSession.status == .completed else {
            throw VideoProcessorError.exportFailed(exportSession.error?.localizedDescription ?? "Unknown error")
        }
        
        return job.outputURL
    }
    
    private func executeFilterJob(asset: AVAsset, job: VideoProcessingJob) async throws -> URL {
        let composition = AVMutableComposition()
        
        guard let videoTrack = asset.tracks(withMediaType: .video).first else {
            throw VideoProcessorError.noVideoTrack
        }
        
        let compositionVideoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)
        try compositionVideoTrack.insertTimeRange(CMTimeRange(start: .zero, duration: asset.duration), of: videoTrack, at: .zero)
        
        // Add audio track if exists
        if let audioTrack = asset.tracks(withMediaType: .audio).first {
            let compositionAudioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
            try compositionAudioTrack.insertTimeRange(CMTimeRange(start: .zero, duration: asset.duration), of: audioTrack, at: .zero)
        }
        
        // Apply filter
        let videoComposition = AVMutableVideoComposition()
        videoComposition.renderSize = videoTrack.naturalSize
        videoComposition.frameDuration = CMTime(value: 1, timescale: job.configuration.frameRate)
        
        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = CMTimeRange(start: .zero, duration: asset.duration)
        
        let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: compositionVideoTrack)
        layerInstruction.setTransform(videoTrack.preferredTransform, at: .zero)
        instruction.layerInstructions = [layerInstruction]
        
        videoComposition.instructions = [instruction]
        
        // Apply filter using Core Image
        videoComposition.customVideoCompositorClass = FilterVideoCompositor.self
        FilterVideoCompositor.filter = job.configuration.filter
        
        guard let exportSession = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else {
            throw VideoProcessorError.exportSessionFailed
        }
        
        exportSession.outputURL = job.outputURL
        exportSession.outputFileType = job.configuration.outputFormat.avFileType
        exportSession.videoComposition = videoComposition
        
        await withCheckedContinuation { continuation in
            exportSession.exportAsynchronously {
                continuation.resume()
            }
        }
        
        guard exportSession.status == .completed else {
            throw VideoProcessorError.exportFailed(exportSession.error?.localizedDescription ?? "Unknown error")
        }
        
        return job.outputURL
    }
    
    private func executeStabilizationJob(asset: AVAsset, job: VideoProcessingJob) async throws -> URL {
        let composition = AVMutableComposition()
        
        guard let videoTrack = asset.tracks(withMediaType: .video).first else {
            throw VideoProcessorError.noVideoTrack
        }
        
        let compositionVideoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)
        try compositionVideoTrack.insertTimeRange(CMTimeRange(start: .zero, duration: asset.duration), of: videoTrack, at: .zero)
        
        // Add audio track if exists
        if let audioTrack = asset.tracks(withMediaType: .audio).first {
            let compositionAudioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
            try compositionAudioTrack.insertTimeRange(CMTimeRange(start: .zero, duration: asset.duration), of: audioTrack, at: .zero)
        }
        
        // Apply stabilization
        let videoComposition = AVMutableVideoComposition()
        videoComposition.renderSize = videoTrack.naturalSize
        videoComposition.frameDuration = CMTime(value: 1, timescale: job.configuration.frameRate)
        
        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = CMTimeRange(start: .zero, duration: asset.duration)
        
        let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: compositionVideoTrack)
        layerInstruction.setTransform(videoTrack.preferredTransform, at: .zero)
        instruction.layerInstructions = [layerInstruction]
        
        videoComposition.instructions = [instruction]
        
        // Enable stabilization
        videoComposition.customVideoCompositorClass = StabilizationVideoCompositor.self
        
        guard let exportSession = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else {
            throw VideoProcessorError.exportSessionFailed
        }
        
        exportSession.outputURL = job.outputURL
        exportSession.outputFileType = job.configuration.outputFormat.avFileType
        exportSession.videoComposition = videoComposition
        
        await withCheckedContinuation { continuation in
            exportSession.exportAsynchronously {
                continuation.resume()
            }
        }
        
        guard exportSession.status == .completed else {
            throw VideoProcessorError.exportFailed(exportSession.error?.localizedDescription ?? "Unknown error")
        }
        
        return job.outputURL
    }
    
    private func executeBasicProcessingJob(asset: AVAsset, job: VideoProcessingJob) async throws -> URL {
        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHighestQuality) else {
            throw VideoProcessorError.exportSessionFailed
        }
        
        exportSession.outputURL = job.outputURL
        exportSession.outputFileType = job.configuration.outputFormat.avFileType
        
        await withCheckedContinuation { continuation in
            exportSession.exportAsynchronously {
                continuation.resume()
            }
        }
        
        guard exportSession.status == .completed else {
            throw VideoProcessorError.exportFailed(exportSession.error?.localizedDescription ?? "Unknown error")
        }
        
        return job.outputURL
    }
    
    private func executeVideoCompositionJob(assets: [AVAsset], job: VideoProcessingJob) async throws -> URL {
        let composition = AVMutableComposition()
        var videoTracks: [AVAssetTrack] = []
        var audioTracks: [AVAssetTrack] = []
        
        // Extract video and audio tracks
        for asset in assets {
            if let videoTrack = asset.tracks(withMediaType: .video).first {
                videoTracks.append(videoTrack)
            }
            if let audioTrack = asset.tracks(withMediaType: .audio).first {
                audioTracks.append(audioTrack)
            }
        }
        
        guard !videoTracks.isEmpty else {
            throw VideoProcessorError.noVideoTrack
        }
        
        // Create composition based on layout
        let (compositionVideoTrack, videoComposition) = try await createVideoComposition(
            videoTracks: videoTracks,
            layout: job.configuration.compositionLayout,
            frameRate: job.configuration.frameRate
        )
        
        // Add audio tracks
        for (index, audioTrack) in audioTracks.enumerated() {
            let compositionAudioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
            try compositionAudioTrack.insertTimeRange(CMTimeRange(start: .zero, duration: audioTrack.asset.duration), of: audioTrack, at: .zero)
        }
        
        guard let exportSession = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else {
            throw VideoProcessorError.exportSessionFailed
        }
        
        exportSession.outputURL = job.outputURL
        exportSession.outputFileType = job.configuration.outputFormat.avFileType
        exportSession.videoComposition = videoComposition
        
        await withCheckedContinuation { continuation in
            exportSession.exportAsynchronously {
                continuation.resume()
            }
        }
        
        guard exportSession.status == .completed else {
            throw VideoProcessorError.exportFailed(exportSession.error?.localizedDescription ?? "Unknown error")
        }
        
        return job.outputURL
    }
    
    private func createVideoComposition(videoTracks: [AVAssetTrack], layout: VideoCompositionLayout, frameRate: Int32) async throws -> (AVMutableCompositionTrack, AVMutableVideoComposition) {
        let composition = AVMutableComposition()
        let compositionVideoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)
        
        let videoComposition = AVMutableVideoComposition()
        videoComposition.frameDuration = CMTime(value: 1, timescale: frameRate)
        
        switch layout {
        case .sideBySide:
            videoComposition.renderSize = CGSize(
                width: videoTracks[0].naturalSize.width * 2,
                height: videoTracks[0].naturalSize.height
            )
            
            let instruction = AVMutableVideoCompositionInstruction()
            instruction.timeRange = CMTimeRange(start: .zero, duration: videoTracks[0].asset.duration)
            
            // Left video
            let leftLayerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: compositionVideoTrack)
            let leftTransform = CGAffineTransform(translationX: 0, y: 0)
            leftLayerInstruction.setTransform(leftTransform, at: .zero)
            
            // Right video
            let rightLayerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: compositionVideoTrack)
            let rightTransform = CGAffineTransform(translationX: videoTracks[0].naturalSize.width, y: 0)
            rightLayerInstruction.setTransform(rightTransform, at: .zero)
            
            instruction.layerInstructions = [leftLayerInstruction, rightLayerInstruction]
            videoComposition.instructions = [instruction]
            
        case .pictureInPicture(let position):
            videoComposition.renderSize = videoTracks[0].naturalSize
            
            let instruction = AVMutableVideoCompositionInstruction()
            instruction.timeRange = CMTimeRange(start: .zero, duration: videoTracks[0].asset.duration)
            
            // Main video
            let mainLayerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: compositionVideoTrack)
            mainLayerInstruction.setTransform(videoTracks[0].preferredTransform, at: .zero)
            
            // PiP video
            let pipLayerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: compositionVideoTrack)
            let pipSize = CGSize(width: videoTracks[0].naturalSize.width * 0.3, height: videoTracks[0].naturalSize.height * 0.3)
            let pipTransform = getPipTransform(pipSize: pipSize, position: position, containerSize: videoTracks[0].naturalSize)
            pipLayerInstruction.setTransform(pipTransform, at: .zero)
            
            instruction.layerInstructions = [mainLayerInstruction, pipLayerInstruction]
            videoComposition.instructions = [instruction]
            
        case .splitScreen:
            videoComposition.renderSize = videoTracks[0].naturalSize
            
            let instruction = AVMutableVideoCompositionInstruction()
            instruction.timeRange = CMTimeRange(start: .zero, duration: videoTracks[0].asset.duration)
            
            // Top video
            let topLayerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: compositionVideoTrack)
            let topTransform = CGAffineTransform(translationX: 0, y: 0)
            topLayerInstruction.setTransform(topTransform, at: .zero)
            
            // Bottom video
            let bottomLayerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: compositionVideoTrack)
            let bottomTransform = CGAffineTransform(translationX: 0, y: videoTracks[0].naturalSize.height / 2)
            bottomLayerInstruction.setTransform(bottomTransform, at: .zero)
            
            instruction.layerInstructions = [topLayerInstruction, bottomLayerInstruction]
            videoComposition.instructions = [instruction]
            
        case .overlay(let blendMode):
            videoComposition.renderSize = videoTracks[0].naturalSize
            
            let instruction = AVMutableVideoCompositionInstruction()
            instruction.timeRange = CMTimeRange(start: .zero, duration: videoTracks[0].asset.duration)
            
            // Base video
            let baseLayerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: compositionVideoTrack)
            baseLayerInstruction.setTransform(videoTracks[0].preferredTransform, at: .zero)
            
            // Overlay video
            let overlayLayerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: compositionVideoTrack)
            overlayLayerInstruction.setTransform(videoTracks[0].preferredTransform, at: .zero)
            overlayLayerInstruction.setOpacity(0.5, at: .zero) // Adjust opacity as needed
            
            instruction.layerInstructions = [baseLayerInstruction, overlayLayerInstruction]
            videoComposition.instructions = [instruction]
        }
        
        return (compositionVideoTrack, videoComposition)
    }
    
    private func getPipTransform(pipSize: CGSize, position: PictureInPicturePosition, containerSize: CGSize) -> CGAffineTransform {
        var x: CGFloat = 0
        var y: CGFloat = 0
        
        switch position {
        case .topLeft:
            x = 20
            y = 20
        case .topRight:
            x = containerSize.width - pipSize.width - 20
            y = 20
        case .bottomLeft:
            x = 20
            y = containerSize.height - pipSize.height - 20
        case .bottomRight:
            x = containerSize.width - pipSize.width - 20
            y = containerSize.height - pipSize.height - 20
        case .center:
            x = (containerSize.width - pipSize.width) / 2
            y = (containerSize.height - pipSize.height) / 2
        }
        
        return CGAffineTransform(translationX: x, y: y)
    }
}

// MARK: - Supporting Types

enum VideoProcessingEvent: Sendable {
    case jobStarted(VideoProcessingJob)
    case jobProgress(UUID, Double)
    case jobCompleted(VideoProcessingJob, URL)
    case jobFailed(VideoProcessingJob, Error)
    case jobCancelled(UUID)
    case error(VideoProcessorError)
}

enum VideoProcessorError: LocalizedError, Sendable {
    case alreadyProcessing
    case noVideoTrack
    case exportSessionFailed
    case exportFailed(String)
    case invalidConfiguration
    case processingCancelled
    
    var errorDescription: String? {
        switch self {
        case .alreadyProcessing:
            return "Another processing job is already in progress"
        case .noVideoTrack:
            return "No video track found in the input file"
        case .exportSessionFailed:
            return "Failed to create export session"
        case .exportFailed(let reason):
            return "Export failed: \(reason)"
        case .invalidConfiguration:
            return "Invalid processing configuration"
        case .processingCancelled:
            return "Processing was cancelled"
        }
    }
}

enum VideoProcessingJobType: String, Sendable {
    case basic = "Basic"
    case trim = "Trim"
    case compression = "Compression"
    case filter = "Filter"
    case stabilization = "Stabilization"
    case composition = "Composition"
}

enum VideoCompositionLayout: Sendable {
    case sideBySide
    case pictureInPicture(PictureInPicturePosition)
    case splitScreen
    case overlay(VideoBlendMode)
}

enum PictureInPicturePosition: String, CaseIterable, Sendable {
    case topLeft = "Top Left"
    case topRight = "Top Right"
    case bottomLeft = "Bottom Left"
    case bottomRight = "Bottom Right"
    case center = "Center"
}

enum VideoBlendMode: String, CaseIterable, Sendable {
    case normal = "Normal"
    case multiply = "Multiply"
    case screen = "Screen"
    case overlay = "Overlay"
    case softLight = "Soft Light"
    case hardLight = "Hard Light"
}

enum VideoFilter: String, CaseIterable, Sendable {
    case none = "None"
    case sepia = "Sepia"
    case blackAndWhite = "Black & White"
    case vintage = "Vintage"
    case cold = "Cold"
    case warm = "Warm"
    case vivid = "Vivid"
    case dramatic = "Dramatic"
}

enum VideoCompressionQuality: String, CaseIterable, Sendable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"
    case custom = "Custom"
    
    var avPreset: String {
        switch self {
        case .low:
            return AVAssetExportPresetLowQuality
        case .medium:
            return AVAssetExportPresetMediumQuality
        case .high:
            return AVAssetExportPresetHighQuality
        case .custom:
            return AVAssetExportPresetHighestQuality
        }
    }
}

struct VideoProcessingConfiguration: Sendable {
    var compositionLayout: VideoCompositionLayout = .sideBySide
    var outputFormat: VideoOutputFormat = .mp4
    var quality: VideoQuality = .hd1080
    var frameRate: Int32 = 30
    var includeAudio: Bool = true
    var trimStartTime: TimeInterval = 0
    var trimEndTime: TimeInterval = 0
    var compressionQuality: VideoCompressionQuality = .high
    var filter: VideoFilter = .none
    var stabilizationEnabled: Bool = false
    var customBitrate: Int? = nil
    var customKeyFrameInterval: Int32? = nil
}

class VideoProcessingJob: ObservableObject, Identifiable, @unchecked Sendable {
    let id: UUID
    let inputURL: URL
    var inputURLs: [URL] = []
    let outputURL: URL
    let configuration: VideoProcessingConfiguration
    var status: VideoProcessingJobStatus
    var progress: Double
    var type: VideoProcessingJobType = .basic
    var error: Error?
    var startTime: Date?
    var endTime: Date?
    
    init(id: UUID = UUID(), inputURL: URL, outputURL: URL, configuration: VideoProcessingConfiguration, status: VideoProcessingJobStatus = .queued, progress: Double = 0.0, type: VideoProcessingJobType = .basic) {
        self.id = id
        self.inputURL = inputURL
        self.outputURL = outputURL
        self.configuration = configuration
        self.status = status
        self.progress = progress
        self.type = type
    }
    
    var duration: TimeInterval? {
        guard let startTime = startTime else { return nil }
        let endTime = self.endTime ?? Date()
        return endTime.timeIntervalSince(startTime)
    }
    
    var formattedDuration: String {
        guard let duration = duration else { return "0:00" }
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    var formattedProgress: String {
        return String(format: "%.1f%%", progress * 100)
    }
}

enum VideoProcessingJobStatus: String, CaseIterable, Sendable {
    case queued = "Queued"
    case processing = "Processing"
    case completed = "Completed"
    case failed = "Failed"
    case cancelled = "Cancelled"
    
    var icon: String {
        switch self {
        case .queued:
            return "clock"
        case .processing:
            return "gear.circle.fill"
        case .completed:
            return "checkmark.circle.fill"
        case .failed:
            return "xmark.circle.fill"
        case .cancelled:
            return "stop.circle.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .queued:
            return .orange
        case .processing:
            return .blue
        case .completed:
            return .green
        case .failed:
            return .red
        case .cancelled:
            return .gray
        }
    }
}

struct VideoProcessingStatus: Sendable {
    let isProcessing: Bool
    let currentJob: VideoProcessingJob?
    let queuedJobs: Int
    let metrics: VideoProcessingMetrics
}

struct VideoProcessingMetrics: Sendable {
    var totalJobsProcessed: Int = 0
    var totalProcessingTime: TimeInterval = 0
    var averageProcessingTime: TimeInterval = 0
    var successRate: Double = 0
    var totalJobs: Int = 0
    var successfulJobs: Int = 0
    var failedJobs: Int = 0
    
    var formattedAverageProcessingTime: String {
        let minutes = Int(averageProcessingTime) / 60
        let seconds = Int(averageProcessingTime) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    var formattedSuccessRate: String {
        return String(format: "%.1f%%", successRate * 100)
    }
}

// MARK: - Custom Video Compositors

class FilterVideoCompositor: NSObject, AVVideoCompositing {
    static var filter: VideoFilter = .none
    
    var sourcePixelBufferAttributes: [String : Any]? {
        return [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferOpenGLCompatibilityKey as String: true,
            kCVPixelBufferMetalCompatibilityKey as String: true
        ]
    }
    
    var requiredPixelBufferAttributesForRenderContext: [String : Any] {
        return [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferOpenGLCompatibilityKey as String: true,
            kCVPixelBufferMetalCompatibilityKey as String: true
        ]
    }
    
    func renderContextChanged(_ newRenderContext: AVVideoCompositionRenderContext) {
        // Handle render context changes
    }
    
    func startRequest(_ request: AVAsynchronousVideoCompositionRequest) {
        guard let sourceFrame = request.sourceFrame(byTrackID: request.sourceTrackIDs[0].int32Value) else {
            request.finish(with: NSError(domain: "FilterVideoCompositor", code: 0, userInfo: nil))
            return
        }
        
        let ciImage = CIImage(cvPixelBuffer: sourceFrame)
        let filteredImage = applyFilter(to: ciImage, filter: Self.filter)
        
        let context = CIContext()
        guard let outputPixelBuffer = request.renderContext.newPixelBuffer() else {
            request.finish(with: NSError(domain: "FilterVideoCompositor", code: 1, userInfo: nil))
            return
        }
        
        context.render(filteredImage, to: outputPixelBuffer)
        
        request.finish(withComposedVideoFrame: outputPixelBuffer)
    }
    
    private func applyFilter(to image: CIImage, filter: VideoFilter) -> CIImage {
        switch filter {
        case .none:
            return image
        case .sepia:
            return image.applyingFilter("CISepiaTone", parameters: [kCIInputIntensityKey: 0.8])
        case .blackAndWhite:
            return image.applyingFilter("CIPhotoEffectNoir")
        case .vintage:
            return image.applyingFilter("CIPhotoEffectInstant")
        case .cold:
            return image.applyingFilter("CITemperatureAndTint", parameters: ["inputNeutral": CIVector(x: 6500, y: 0)])
        case .warm:
            return image.applyingFilter("CITemperatureAndTint", parameters: ["inputNeutral": CIVector(x: 4500, y: 0)])
        case .vivid:
            return image.applyingFilter("CIVibrance", parameters: [kCIInputAmountKey: 0.5])
        case .dramatic:
            return image.applyingFilter("CIColorContrast", parameters: [kCIInputContrastKey: 1.5])
        }
    }
}

class StabilizationVideoCompositor: NSObject, AVVideoCompositing {
    var sourcePixelBufferAttributes: [String : Any]? {
        return [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferOpenGLCompatibilityKey as String: true,
            kCVPixelBufferMetalCompatibilityKey as String: true
        ]
    }
    
    var requiredPixelBufferAttributesForRenderContext: [String : Any] {
        return [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferOpenGLCompatibilityKey as String: true,
            kCVPixelBufferMetalCompatibilityKey as String: true
        ]
    }
    
    func renderContextChanged(_ newRenderContext: AVVideoCompositionRenderContext) {
        // Handle render context changes
    }
    
    func startRequest(_ request: AVAsynchronousVideoCompositionRequest) {
        guard let sourceFrame = request.sourceFrame(byTrackID: request.sourceTrackIDs[0].int32Value) else {
            request.finish(with: NSError(domain: "StabilizationVideoCompositor", code: 0, userInfo: nil))
            return
        }
        
        // Apply stabilization (simplified version)
        // In a real implementation, this would use AVVideoStabilization or custom algorithms
        let ciImage = CIImage(cvPixelBuffer: sourceFrame)
        
        let context = CIContext()
        guard let outputPixelBuffer = request.renderContext.newPixelBuffer() else {
            request.finish(with: NSError(domain: "StabilizationVideoCompositor", code: 1, userInfo: nil))
            return
        }
        
        context.render(ciImage, to: outputPixelBuffer)
        
        request.finish(withComposedVideoFrame: outputPixelBuffer)
    }
}