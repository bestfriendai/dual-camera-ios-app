import AVFoundation
import Photos
import UIKit

// MARK: - Video Merging Extension
extension ViewController {
    
    enum VideoLayout {
        case sideBySide
        case pip
    }
    
    func mergeVideos(frontURL: URL, backURL: URL, layout: VideoLayout = .sideBySide) {
        statusLabel.text = "Preparing videos..."
        mergeVideosButton.isEnabled = false
        mergeVideosButton.alpha = 0.5
        activityIndicator.startAnimating()
        progressView.isHidden = false
        progressView.progress = 0.0

        let composition = AVMutableComposition()

        // Create separate video tracks for front and back cameras
        guard let frontVideoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid),
              let backVideoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid),
              let audioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            showMergeError("Failed to create composition tracks")
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

        group.notify(queue: .main) {
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
                layout: layout
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
        layout: VideoLayout
    ) {
        guard let frontTrackAsset = frontVideoTrackAsset,
              let backTrackAsset = backVideoTrackAsset else {
            showMergeError("Failed to load video tracks")
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
            showMergeError("Failed to insert tracks: \(error.localizedDescription)")
            return
        }

        // Create video composition for layout
        let videoComposition = createVideoComposition(
            frontTrack: frontVideoTrack,
            backTrack: backVideoTrack,
            composition: composition,
            layout: layout
        )

        // Export the merged video
        exportMergedVideo(composition: composition, videoComposition: videoComposition)
    }
    
    private func createVideoComposition(
        frontTrack: AVMutableCompositionTrack,
        backTrack: AVMutableCompositionTrack,
        composition: AVMutableComposition,
        layout: VideoLayout
    ) -> AVVideoComposition {

        let videoComposition = AVMutableVideoComposition()
        videoComposition.frameDuration = CMTimeMake(value: 1, timescale: 30) // 30 FPS

        // Use the current video quality setting - access through self
        let renderSize = self.dualCameraManager.videoQuality.renderSize
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
    
    private func exportMergedVideo(composition: AVMutableComposition, videoComposition: AVVideoComposition) {
        // Create output URL
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let timestamp = Int(Date().timeIntervalSince1970)
        let outputURL = documentsPath.appendingPathComponent("merged_\(timestamp).mp4")

        // Remove existing file if it exists
        try? FileManager.default.removeItem(at: outputURL)

        // Create export session
        guard let exportSession = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else {
            showMergeError("Failed to create export session")
            return
        }

        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4
        exportSession.videoComposition = videoComposition

        // Update status
        DispatchQueue.main.async {
            self.statusLabel.text = "Exporting video..."
            self.progressView.progress = 0.1
        }

        // Monitor export progress
        let progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }

            let progress = exportSession.progress
            DispatchQueue.main.async {
                self.progressView.progress = progress
                self.statusLabel.text = "Exporting video... \(Int(progress * 100))%"
            }

            if exportSession.status != .exporting {
                timer.invalidate()
            }
        }

        exportSession.exportAsynchronously {
            progressTimer.invalidate()

            DispatchQueue.main.async {
                self.activityIndicator.stopAnimating()

                switch exportSession.status {
                case .completed:
                    self.progressView.progress = 1.0
                    self.statusLabel.text = "Saving to Photos..."
                    self.saveMergedVideoToPhotos(url: outputURL)
                case .failed:
                    self.showMergeError("Export failed: \(exportSession.error?.localizedDescription ?? "Unknown error")")
                case .cancelled:
                    self.showMergeError("Export cancelled")
                default:
                    self.showMergeError("Export failed with unknown status")
                }
            }
        }
    }
    
    private func saveMergedVideoToPhotos(url: URL) {
        PHPhotoLibrary.requestAuthorization { status in
            DispatchQueue.main.async {
                switch status {
                case .authorized, .limited:
                    PHPhotoLibrary.shared().performChanges({
                        PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
                    }) { success, error in
                        DispatchQueue.main.async {
                            if success {
                                self.statusLabel.text = "Merged video saved to Photos!"
                                // Clean up temporary file after a delay to ensure Photos has copied it
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                                    try? FileManager.default.removeItem(at: url)
                                }
                                // Also clean up old temporary files to save space
                                self.cleanupOldTemporaryFiles()
                            } else {
                                self.showMergeError("Failed to save to Photos: \(error?.localizedDescription ?? "Unknown error")")
                            }
                            self.resetMergeButton()
                        }
                    }
                case .denied, .restricted:
                    self.showMergeError("Photos access denied. Please enable in Settings.")
                    self.resetMergeButton()
                case .notDetermined:
                    self.showMergeError("Photos permission not determined")
                    self.resetMergeButton()
                @unknown default:
                    self.showMergeError("Unknown Photos permission status")
                    self.resetMergeButton()
                }
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
    
    private func showMergeError(_ message: String) {
        DispatchQueue.main.async {
            self.statusLabel.text = "Error: \(message)"
            self.activityIndicator.stopAnimating()
            self.progressView.isHidden = true
            self.resetMergeButton()

            // Show alert for critical errors
            let alert = UIAlertController(title: "Merge Failed", message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            self.present(alert, animated: true)
        }
    }

    private func resetMergeButton() {
        mergeVideosButton.isEnabled = true
        mergeVideosButton.alpha = 1.0
        progressView.isHidden = true
        progressView.progress = 0.0
    }
}