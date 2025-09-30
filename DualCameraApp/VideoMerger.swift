import AVFoundation
import Photos
import UIKit

class VideoMerger {
    enum VideoLayout {
        case sideBySide
        case pip
    }

    func mergeVideos(frontURL: URL, backURL: URL, layout: VideoLayout = .sideBySide, quality: VideoQuality, completion: @escaping (Result<URL, Error>) -> Void) {
        let composition = AVMutableComposition()

        // Create separate video tracks for front and back cameras
        guard let frontVideoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid),
              let backVideoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid),
              let audioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            completion(.failure(NSError(domain: "VideoMerger", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to create composition tracks"])))
            return
        }

        // Load assets
        let frontAsset = AVAsset(url: frontURL)
        let backAsset = AVAsset(url: backURL)

        let group = DispatchGroup()
        var frontVideoTrackAsset: AVAssetTrack?
        var backVideoTrackAsset: AVAssetTrack?
        var audioTrackAsset: AVAssetTrack?

        // Load front video track
        group.enter()
        frontAsset.loadValuesAsynchronously(forKeys: ["tracks"]) {
            frontVideoTrackAsset = frontAsset.tracks(withMediaType: .video).first
            group.leave()
        }

        // Load back video track
        group.enter()
        backAsset.loadValuesAsynchronously(forKeys: ["tracks"]) {
            backVideoTrackAsset = backAsset.tracks(withMediaType: .video).first
            group.leave()
        }

        // Load audio track (from front camera which has audio)
        group.enter()
        frontAsset.loadValuesAsynchronously(forKeys: ["tracks"]) {
            audioTrackAsset = frontAsset.tracks(withMediaType: .audio).first
            group.leave()
        }

        group.notify(queue: .global(qos: .userInitiated)) {
            self.performVideoMerge(
                composition: composition,
                frontVideoTrack: frontVideoTrack,
                backVideoTrack: backVideoTrack,
                audioTrack: audioTrack,
                frontVideoTrackAsset: frontVideoTrackAsset,
                backVideoTrackAsset: backVideoTrackAsset,
                audioTrackAsset: audioTrackAsset,
                frontAsset: frontAsset,
                backAsset: backAsset,
                layout: layout,
                quality: quality,
                completion: completion
            )
        }
    }

    private func performVideoMerge(
        composition: AVMutableComposition,
        frontVideoTrack: AVMutableCompositionTrack,
        backVideoTrack: AVMutableCompositionTrack,
        audioTrack: AVMutableCompositionTrack,
        frontVideoTrackAsset: AVAssetTrack?,
        backVideoTrackAsset: AVAssetTrack?,
        audioTrackAsset: AVAssetTrack?,
        frontAsset: AVAsset,
        backAsset: AVAsset,
        layout: VideoLayout,
        quality: VideoQuality,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        guard let frontTrackAsset = frontVideoTrackAsset,
              let backTrackAsset = backVideoTrackAsset else {
            completion(.failure(NSError(domain: "VideoMerger", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to load video tracks"])))
            return
        }

        let duration = min(frontAsset.duration, backAsset.duration)

        do {
            // Insert front video track
            try frontVideoTrack.insertTimeRange(CMTimeRangeMake(start: .zero, duration: duration),
                                               of: frontTrackAsset,
                                               at: .zero)

            // Insert back video track
            try backVideoTrack.insertTimeRange(CMTimeRangeMake(start: .zero, duration: duration),
                                              of: backTrackAsset,
                                              at: .zero)

            // Insert audio track if available
            if let audioSourceTrack = audioTrackAsset {
                try audioTrack.insertTimeRange(CMTimeRangeMake(start: .zero, duration: duration),
                                             of: audioSourceTrack,
                                             at: .zero)
            }

        } catch {
            completion(.failure(error))
            return
        }

        // Create video composition for layout
        let videoComposition = createVideoComposition(
            frontTrack: frontVideoTrack,
            backTrack: backVideoTrack,
            composition: composition,
            layout: layout,
            quality: quality
        )

        // Export the merged video
        exportMergedVideo(composition: composition, videoComposition: videoComposition, completion: completion)
    }

    private func createVideoComposition(
        frontTrack: AVMutableCompositionTrack,
        backTrack: AVMutableCompositionTrack,
        composition: AVMutableComposition,
        layout: VideoLayout,
        quality: VideoQuality
    ) -> AVVideoComposition {

        let videoComposition = AVMutableVideoComposition()
        videoComposition.frameDuration = CMTimeMake(value: 1, timescale: 30) // 30 FPS

        let renderSize = quality.renderSize
        videoComposition.renderSize = renderSize

        // Create composition instruction
        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = CMTimeRangeMake(start: .zero, duration: composition.duration)

        switch layout {
        case .sideBySide:
            // Front camera layer instruction (left side)
            let frontLayerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: frontTrack)
            let frontTransform = CGAffineTransform(scaleX: 0.5, y: 1.0) // Scale to half width
            frontLayerInstruction.setTransform(frontTransform, at: .zero)

            // Back camera layer instruction (right side)
            let backLayerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: backTrack)
            let backTransform = CGAffineTransform(scaleX: 0.5, y: 1.0)
                .concatenating(CGAffineTransform(translationX: renderSize.width / 2, y: 0)) // Move to right side
            backLayerInstruction.setTransform(backTransform, at: .zero)

            instruction.layerInstructions = [frontLayerInstruction, backLayerInstruction]

        case .pip:
            // Back camera as main video (full screen)
            let backLayerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: backTrack)
            backLayerInstruction.setTransform(CGAffineTransform.identity, at: .zero)

            // Front camera as picture-in-picture (small overlay)
            let frontLayerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: frontTrack)
            let pipScale: CGFloat = 0.25 // 25% of original size
            let pipX = renderSize.width * 0.75
            let pipY = renderSize.height * 0.75
            let pipTransform = CGAffineTransform(scaleX: pipScale, y: pipScale)
                .concatenating(CGAffineTransform(translationX: pipX, y: pipY)) // Position in bottom-right
            frontLayerInstruction.setTransform(pipTransform, at: .zero)

            instruction.layerInstructions = [backLayerInstruction, frontLayerInstruction]
        }

        videoComposition.instructions = [instruction]
        return videoComposition
    }

    private func exportMergedVideo(composition: AVMutableComposition, videoComposition: AVVideoComposition, completion: @escaping (Result<URL, Error>) -> Void) {
        // Create output URL
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let timestamp = Int(Date().timeIntervalSince1970)
        let outputURL = documentsPath.appendingPathComponent("merged_\(timestamp).mp4")

        // Remove existing file if it exists
        try? FileManager.default.removeItem(at: outputURL)

        // Create export session
        guard let exportSession = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else {
            completion(.failure(NSError(domain: "VideoMerger", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to create export session"])))
            return
        }

        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4
        exportSession.videoComposition = videoComposition

        exportSession.exportAsynchronously {
            switch exportSession.status {
            case .completed:
                self.saveMergedVideoToPhotos(url: outputURL) { result in
                    switch result {
                    case .success:
                        completion(.success(outputURL))
                    case .failure(let error):
                        completion(.failure(error))
                    }
                }
            case .failed:
                completion(.failure(exportSession.error ?? NSError(domain: "VideoMerger", code: 4, userInfo: [NSLocalizedDescriptionKey: "Export failed"])))
            case .cancelled:
                completion(.failure(NSError(domain: "VideoMerger", code: 5, userInfo: [NSLocalizedDescriptionKey: "Export cancelled"])))
            default:
                completion(.failure(NSError(domain: "VideoMerger", code: 6, userInfo: [NSLocalizedDescriptionKey: "Export failed with unknown status"])))
            }
        }
    }

    private func saveMergedVideoToPhotos(url: URL, completion: @escaping (Result<Void, Error>) -> Void) {
        PHPhotoLibrary.requestAuthorization { status in
            switch status {
            case .authorized, .limited:
                PHPhotoLibrary.shared().performChanges({
                    PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
                }) { success, error in
                    if success {
                        // Clean up temporary file after a delay to ensure Photos has copied it
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            try? FileManager.default.removeItem(at: url)
                        }
                        // Also clean up old temporary files to save space
                        self.cleanupOldTemporaryFiles()
                        completion(.success(()))
                    } else {
                        completion(.failure(error ?? NSError(domain: "VideoMerger", code: 7, userInfo: [NSLocalizedDescriptionKey: "Failed to save to Photos"])))
                    }
                }
            case .denied, .restricted:
                completion(.failure(NSError(domain: "VideoMerger", code: 8, userInfo: [NSLocalizedDescriptionKey: "Photos access denied"])))
            case .notDetermined:
                completion(.failure(NSError(domain: "VideoMerger", code: 9, userInfo: [NSLocalizedDescriptionKey: "Photos permission not determined"])))
            @unknown default:
                completion(.failure(NSError(domain: "VideoMerger", code: 10, userInfo: [NSLocalizedDescriptionKey: "Unknown Photos permission status"])))
            }
        }
    }

    private func cleanupOldTemporaryFiles() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]

        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(at: documentsPath, includingPropertiesForKeys: [.creationDateKey])
            let now = Date()

            // Delete files older than 7 days
            for url in fileURLs {
                if let creationDate = try? url.resourceValues(forKeys: [.creationDateKey]).creationDate {
                    let daysSinceCreation = Calendar.current.dateComponents([.day], from: creationDate, to: now).day ?? 0
                    if daysSinceCreation > 7 {
                        try? FileManager.default.removeItem(at: url)
                        print("Cleaned up old file: \(url.lastPathComponent)")
                    }
                }
            }
        } catch {
            print("Error cleaning up temporary files: \(error)")
        }
    }
}