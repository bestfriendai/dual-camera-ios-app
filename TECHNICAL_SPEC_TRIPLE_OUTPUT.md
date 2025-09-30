# Technical Specification: Triple Output Recording System

## Overview

This document provides detailed technical specifications for implementing the triple output recording system - the flagship feature that allows users to record once and receive three video outputs simultaneously:

1. **Front camera video** (front_[timestamp].mov)
2. **Back camera video** (back_[timestamp].mov)
3. **Combined/merged video** (combined_[timestamp].mp4)

## Current Architecture Analysis

### Existing Implementation
```swift
// Current: DualCameraManager.swift (lines 346-370)
func startRecording() {
    sessionQueue.async {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let timestamp = Int(Date().timeIntervalSince1970)
        
        self.frontVideoURL = documentsPath.appendingPathComponent("front_\(timestamp).mov")
        self.backVideoURL = documentsPath.appendingPathComponent("back_\(timestamp).mov")
        
        // Records to separate files
        frontMovieOutput.startRecording(to: frontURL, recordingDelegate: self)
        backMovieOutput.startRecording(to: backURL, recordingDelegate: self)
    }
}
```

**Limitations:**
- Only creates 2 separate files
- No real-time composition
- Merging happens post-recording via VideoMerger.swift
- User must manually trigger merge
- Merge process takes additional time and storage

## Proposed Architecture

### High-Level Design

```
┌─────────────────────────────────────────────────────────────┐
│                    Recording Session                         │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  ┌──────────────┐         ┌──────────────┐                  │
│  │ Front Camera │         │ Back Camera  │                  │
│  └──────┬───────┘         └──────┬───────┘                  │
│         │                        │                           │
│         ├────────────────────────┤                           │
│         │                        │                           │
│    ┌────▼────┐              ┌───▼─────┐                     │
│    │ Movie   │              │ Movie   │                      │
│    │ Output  │              │ Output  │                      │
│    └────┬────┘              └───┬─────┘                     │
│         │                        │                           │
│         ▼                        ▼                           │
│   front_xxx.mov            back_xxx.mov                      │
│                                                               │
│    ┌────────┐              ┌─────────┐                      │
│    │ Video  │              │ Video   │                       │
│    │ Data   │              │ Data    │                       │
│    │ Output │              │ Output  │                       │
│    └────┬───┘              └────┬────┘                      │
│         │                       │                            │
│         └───────┬───────────────┘                            │
│                 │                                             │
│         ┌───────▼────────┐                                   │
│         │ Frame Compositor│                                  │
│         │  (Real-time)   │                                   │
│         └───────┬────────┘                                   │
│                 │                                             │
│         ┌───────▼────────┐                                   │
│         │  Asset Writer  │                                   │
│         └───────┬────────┘                                   │
│                 │                                             │
│                 ▼                                             │
│         combined_xxx.mp4                                     │
│                                                               │
└─────────────────────────────────────────────────────────────┘
```

### Component Breakdown

#### 1. Enhanced DualCameraManager

**New Properties:**
```swift
class DualCameraManager {
    // EXISTING: Movie outputs for separate files
    private var frontMovieOutput: AVCaptureMovieFileOutput?
    private var backMovieOutput: AVCaptureMovieFileOutput?
    
    // NEW: Data outputs for real-time composition
    private var frontDataOutput: AVCaptureVideoDataOutput?
    private var backDataOutput: AVCaptureVideoDataOutput?
    private var audioDataOutput: AVCaptureAudioDataOutput?
    
    // NEW: Real-time composition
    private var frameCompositor: FrameCompositor?
    private var assetWriter: AVAssetWriter?
    private var videoWriterInput: AVAssetWriterInput?
    private var audioWriterInput: AVAssetWriterInput?
    private var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?
    
    // NEW: Frame synchronization
    private var frontFrameBuffer: CMSampleBuffer?
    private var backFrameBuffer: CMSampleBuffer?
    private let frameSyncQueue = DispatchQueue(label: "com.dualcamera.framesync")
    private let compositionQueue = DispatchQueue(label: "com.dualcamera.composition", qos: .userInitiated)
    
    // NEW: Recording configuration
    var recordingMode: RecordingMode = .tripleOutput
    var combinedLayout: RecordingLayout = .sideBySide
    
    // NEW: URLs for all outputs
    private var frontVideoURL: URL?
    private var backVideoURL: URL?
    private var combinedVideoURL: URL?
}
```

**New Enums:**
```swift
enum RecordingMode {
    case tripleOutput      // All 3 files (default)
    case separateOnly      // Only front + back
    case combinedOnly      // Only merged file
    case frontOnly         // Single camera
    case backOnly          // Single camera
}

enum RecordingLayout {
    case sideBySide
    case pictureInPicture(position: PIPPosition, size: PIPSize)
    case frontPrimary      // Front large, back small
    case backPrimary       // Back large, front small
    
    enum PIPPosition {
        case topLeft, topRight, bottomLeft, bottomRight
    }
    
    enum PIPSize {
        case small      // 25% of frame
        case medium     // 33% of frame
        case large      // 40% of frame
    }
}
```

#### 2. Frame Compositor

**New Class:**
```swift
import CoreImage
import Metal
import MetalKit

class FrameCompositor {
    private let ciContext: CIContext
    private let metalDevice: MTLDevice
    private var renderSize: CGSize
    private var layout: RecordingLayout
    
    init(layout: RecordingLayout, quality: VideoQuality) {
        // Initialize Metal for GPU-accelerated composition
        guard let device = MTLCreateSystemDefaultDevice() else {
            fatalError("Metal not supported")
        }
        self.metalDevice = device
        self.ciContext = CIContext(mtlDevice: device)
        self.renderSize = quality.dimensions
        self.layout = layout
    }
    
    func composite(frontBuffer: CVPixelBuffer, 
                   backBuffer: CVPixelBuffer,
                   timestamp: CMTime) -> CVPixelBuffer? {
        
        // Convert to CIImage for processing
        let frontImage = CIImage(cvPixelBuffer: frontBuffer)
        let backImage = CIImage(cvPixelBuffer: backBuffer)
        
        // Apply layout transformation
        let composedImage: CIImage
        switch layout {
        case .sideBySide:
            composedImage = composeSideBySide(front: frontImage, back: backImage)
        case .pictureInPicture(let position, let size):
            composedImage = composePIP(front: frontImage, back: backImage, 
                                      position: position, size: size)
        case .frontPrimary:
            composedImage = composePrimary(primary: frontImage, secondary: backImage)
        case .backPrimary:
            composedImage = composePrimary(primary: backImage, secondary: frontImage)
        }
        
        // Render to pixel buffer
        return renderToPixelBuffer(composedImage)
    }
    
    private func composeSideBySide(front: CIImage, back: CIImage) -> CIImage {
        let halfWidth = renderSize.width / 2
        
        // Scale and position front camera (left side)
        let frontScaled = front
            .transformed(by: CGAffineTransform(scaleX: halfWidth / front.extent.width,
                                               y: renderSize.height / front.extent.height))
        
        // Scale and position back camera (right side)
        let backScaled = back
            .transformed(by: CGAffineTransform(scaleX: halfWidth / back.extent.width,
                                              y: renderSize.height / back.extent.height))
            .transformed(by: CGAffineTransform(translationX: halfWidth, y: 0))
        
        // Composite both images
        return frontScaled.composited(over: backScaled)
    }
    
    private func composePIP(front: CIImage, back: CIImage, 
                           position: RecordingLayout.PIPPosition,
                           size: RecordingLayout.PIPSize) -> CIImage {
        
        // Back camera as main background
        let mainScaled = back
            .transformed(by: CGAffineTransform(scaleX: renderSize.width / back.extent.width,
                                               y: renderSize.height / back.extent.height))
        
        // Calculate PIP dimensions
        let pipScale: CGFloat
        switch size {
        case .small: pipScale = 0.25
        case .medium: pipScale = 0.33
        case .large: pipScale = 0.40
        }
        
        let pipWidth = renderSize.width * pipScale
        let pipHeight = renderSize.height * pipScale
        
        // Scale front camera for PIP
        let pipScaled = front
            .transformed(by: CGAffineTransform(scaleX: pipWidth / front.extent.width,
                                               y: pipHeight / front.extent.height))
        
        // Position PIP based on corner
        let pipPosition: CGPoint
        let margin: CGFloat = 20
        switch position {
        case .topLeft:
            pipPosition = CGPoint(x: margin, y: renderSize.height - pipHeight - margin)
        case .topRight:
            pipPosition = CGPoint(x: renderSize.width - pipWidth - margin, 
                                 y: renderSize.height - pipHeight - margin)
        case .bottomLeft:
            pipPosition = CGPoint(x: margin, y: margin)
        case .bottomRight:
            pipPosition = CGPoint(x: renderSize.width - pipWidth - margin, y: margin)
        }
        
        let pipPositioned = pipScaled
            .transformed(by: CGAffineTransform(translationX: pipPosition.x, y: pipPosition.y))
        
        // Add border to PIP
        let pipWithBorder = addBorder(to: pipPositioned, width: 3, color: .white)
        
        // Composite PIP over main
        return pipWithBorder.composited(over: mainScaled)
    }
    
    private func addBorder(to image: CIImage, width: CGFloat, color: CIColor) -> CIImage {
        // Create border effect using Core Image filters
        let borderFilter = CIFilter(name: "CIConstantColorGenerator")!
        borderFilter.setValue(color, forKey: kCIInputColorKey)
        
        // Apply border (simplified - full implementation would use masking)
        return image
    }
    
    private func renderToPixelBuffer(_ image: CIImage) -> CVPixelBuffer? {
        var pixelBuffer: CVPixelBuffer?
        let attrs = [
            kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue,
            kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue,
            kCVPixelBufferMetalCompatibilityKey: kCFBooleanTrue
        ] as CFDictionary
        
        let status = CVPixelBufferCreate(kCFAllocatorDefault,
                                        Int(renderSize.width),
                                        Int(renderSize.height),
                                        kCVPixelFormatType_32BGRA,
                                        attrs,
                                        &pixelBuffer)
        
        guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
            return nil
        }
        
        ciContext.render(image, to: buffer)
        return buffer
    }
}
```

#### 3. Asset Writer Setup

**Implementation:**
```swift
extension DualCameraManager {
    
    private func setupAssetWriter(for url: URL, quality: VideoQuality) throws {
        // Create asset writer
        assetWriter = try AVAssetWriter(outputURL: url, fileType: .mp4)
        
        // Video settings
        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.hevc,  // H.265 for better compression
            AVVideoWidthKey: quality.dimensions.width,
            AVVideoHeightKey: quality.dimensions.height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: quality.bitrate,
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
                AVVideoMaxKeyFrameIntervalKey: 30
            ]
        ]
        
        // Create video input
        videoWriterInput = AVAssetWriterInput(mediaType: .video, 
                                              outputSettings: videoSettings)
        videoWriterInput?.expectsMediaDataInRealTime = true
        
        // Create pixel buffer adaptor
        let sourcePixelBufferAttributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: quality.dimensions.width,
            kCVPixelBufferHeightKey as String: quality.dimensions.height,
            kCVPixelBufferMetalCompatibilityKey as String: true
        ]
        
        pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: videoWriterInput!,
            sourcePixelBufferAttributes: sourcePixelBufferAttributes
        )
        
        // Audio settings
        let audioSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 2,
            AVEncoderBitRateKey: 128000
        ]
        
        audioWriterInput = AVAssetWriterInput(mediaType: .audio, 
                                              outputSettings: audioSettings)
        audioWriterInput?.expectsMediaDataInRealTime = true
        
        // Add inputs to writer
        if assetWriter!.canAdd(videoWriterInput!) {
            assetWriter!.add(videoWriterInput!)
        }
        if assetWriter!.canAdd(audioWriterInput!) {
            assetWriter!.add(audioWriterInput!)
        }
        
        // Start writing
        assetWriter!.startWriting()
        assetWriter!.startSession(atSourceTime: .zero)
    }
}
```

#### 4. Frame Synchronization & Processing

**Implementation:**
```swift
extension DualCameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    
    func captureOutput(_ output: AVCaptureOutput,
                      didOutput sampleBuffer: CMSampleBuffer,
                      from connection: AVCaptureConnection) {
        
        guard recordingMode == .tripleOutput || recordingMode == .combinedOnly else {
            return
        }
        
        frameSyncQueue.async { [weak self] in
            guard let self = self else { return }
            
            // Store frame in appropriate buffer
            if output == self.frontDataOutput {
                self.frontFrameBuffer = sampleBuffer
            } else if output == self.backDataOutput {
                self.backFrameBuffer = sampleBuffer
            }
            
            // Check if we have both frames
            if let frontBuffer = self.frontFrameBuffer,
               let backBuffer = self.backFrameBuffer {
                
                // Process frames on composition queue
                self.processFramePair(front: frontBuffer, back: backBuffer)
                
                // Clear buffers
                self.frontFrameBuffer = nil
                self.backFrameBuffer = nil
            }
        }
    }
    
    private func processFramePair(front: CMSampleBuffer, back: CMSampleBuffer) {
        compositionQueue.async { [weak self] in
            guard let self = self,
                  let frontPixelBuffer = CMSampleBufferGetImageBuffer(front),
                  let backPixelBuffer = CMSampleBufferGetImageBuffer(back),
                  let compositor = self.frameCompositor else {
                return
            }
            
            // Get presentation timestamp
            let timestamp = CMSampleBufferGetPresentationTimeStamp(front)
            
            // Compose frames
            guard let composedBuffer = compositor.composite(
                frontBuffer: frontPixelBuffer,
                backBuffer: backPixelBuffer,
                timestamp: timestamp
            ) else {
                print("Failed to compose frame")
                return
            }
            
            // Write to asset writer
            self.writeComposedFrame(composedBuffer, at: timestamp)
        }
    }
    
    private func writeComposedFrame(_ pixelBuffer: CVPixelBuffer, at timestamp: CMTime) {
        guard let videoInput = videoWriterInput,
              let adaptor = pixelBufferAdaptor,
              videoInput.isReadyForMoreMediaData else {
            // Drop frame if not ready (prevents backlog)
            return
        }
        
        adaptor.append(pixelBuffer, withPresentationTime: timestamp)
    }
}

// Audio handling
extension DualCameraManager: AVCaptureAudioDataOutputSampleBufferDelegate {
    
    func captureOutput(_ output: AVCaptureOutput,
                      didOutput sampleBuffer: CMSampleBuffer,
                      from connection: AVCaptureConnection) {
        
        guard let audioInput = audioWriterInput,
              audioInput.isReadyForMoreMediaData else {
            return
        }
        
        audioInput.append(sampleBuffer)
    }
}
```

#### 5. Updated Recording Flow

**Start Recording:**
```swift
func startRecording() {
    sessionQueue.async { [weak self] in
        guard let self = self, !self.isRecording else { return }
        
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let timestamp = Int(Date().timeIntervalSince1970)
        
        // Setup URLs based on recording mode
        switch self.recordingMode {
        case .tripleOutput:
            self.frontVideoURL = documentsPath.appendingPathComponent("front_\(timestamp).mov")
            self.backVideoURL = documentsPath.appendingPathComponent("back_\(timestamp).mov")
            self.combinedVideoURL = documentsPath.appendingPathComponent("combined_\(timestamp).mp4")
            
            // Start movie outputs for separate files
            if let frontOutput = self.frontMovieOutput, let frontURL = self.frontVideoURL {
                frontOutput.startRecording(to: frontURL, recordingDelegate: self)
            }
            if let backOutput = self.backMovieOutput, let backURL = self.backVideoURL {
                backOutput.startRecording(to: backURL, recordingDelegate: self)
            }
            
            // Setup asset writer for combined output
            if let combinedURL = self.combinedVideoURL {
                do {
                    try self.setupAssetWriter(for: combinedURL, quality: self.activeVideoQuality)
                    self.frameCompositor = FrameCompositor(layout: self.combinedLayout, 
                                                          quality: self.activeVideoQuality)
                } catch {
                    print("Failed to setup asset writer: \(error)")
                }
            }
            
        case .separateOnly:
            // Only start movie outputs
            // ... (similar to current implementation)
            
        case .combinedOnly:
            // Only setup asset writer
            // ... (no movie outputs)
            
        case .frontOnly, .backOnly:
            // Single camera recording
            // ... (simplified flow)
        }
        
        self.isRecording = true
        DispatchQueue.main.async {
            self.delegate?.didStartRecording()
        }
    }
}
```

**Stop Recording:**
```swift
func stopRecording() {
    sessionQueue.async { [weak self] in
        guard let self = self, self.isRecording else { return }
        
        // Stop movie outputs
        if self.frontMovieOutput?.isRecording == true {
            self.frontMovieOutput?.stopRecording()
        }
        if self.backMovieOutput?.isRecording == true {
            self.backMovieOutput?.stopRecording()
        }
        
        // Finish asset writer
        if let writer = self.assetWriter, writer.status == .writing {
            self.videoWriterInput?.markAsFinished()
            self.audioWriterInput?.markAsFinished()
            
            writer.finishWriting { [weak self] in
                guard let self = self else { return }
                
                if writer.status == .completed {
                    print("Combined video saved: \(self.combinedVideoURL?.path ?? "")")
                } else if let error = writer.error {
                    print("Asset writer error: \(error)")
                }
                
                // Cleanup
                self.assetWriter = nil
                self.videoWriterInput = nil
                self.audioWriterInput = nil
                self.pixelBufferAdaptor = nil
                self.frameCompositor = nil
            }
        }
        
        self.isRecording = false
    }
}
```

## Performance Optimization

### 1. Memory Management
```swift
// Reuse pixel buffer pool
private var pixelBufferPool: CVPixelBufferPool?

func createPixelBufferPool(width: Int, height: Int) -> CVPixelBufferPool? {
    let attrs = [
        kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_32BGRA,
        kCVPixelBufferWidthKey: width,
        kCVPixelBufferHeightKey: height,
        kCVPixelBufferIOSurfacePropertiesKey: [:] as CFDictionary
    ] as CFDictionary
    
    var pool: CVPixelBufferPool?
    CVPixelBufferPoolCreate(kCFAllocatorDefault, nil, attrs, &pool)
    return pool
}
```

### 2. Thermal Management
```swift
import os.signpost

class ThermalMonitor {
    private let thermalState = ProcessInfo.processInfo.thermalState
    
    func shouldReduceQuality() -> Bool {
        return thermalState == .serious || thermalState == .critical
    }
    
    func monitorThermalState(callback: @escaping (ProcessInfo.ThermalState) -> Void) {
        NotificationCenter.default.addObserver(
            forName: ProcessInfo.thermalStateDidChangeNotification,
            object: nil,
            queue: .main
        ) { _ in
            callback(ProcessInfo.processInfo.thermalState)
        }
    }
}
```

### 3. Adaptive Quality
```swift
func adjustQualityForPerformance() {
    let thermalMonitor = ThermalMonitor()
    
    if thermalMonitor.shouldReduceQuality() {
        // Reduce combined output quality
        // Keep separate outputs at full quality
        print("Reducing combined output quality due to thermal state")
        
        // Could reduce resolution, bitrate, or frame rate
        // Or temporarily disable combined output
    }
}
```

## Testing Strategy

### Unit Tests
```swift
class FrameCompositorTests: XCTestCase {
    func testSideBySideComposition() {
        // Test frame composition logic
    }
    
    func testPIPComposition() {
        // Test PIP layout
    }
    
    func testFrameSynchronization() {
        // Test frame timing
    }
}
```

### Integration Tests
```swift
class TripleOutputRecordingTests: XCTestCase {
    func testTripleOutputCreation() {
        // Verify all 3 files are created
    }
    
    func testCombinedVideoQuality() {
        // Verify combined video matches expected quality
    }
    
    func testPerformanceUnderLoad() {
        // Test with extended recording duration
    }
}
```

### Performance Tests
```swift
class RecordingPerformanceTests: XCTestCase {
    func testFrameRate() {
        // Measure: Should maintain 30fps consistently
    }
    
    func testMemoryUsage() {
        // Measure: Should stay under 300MB
    }
    
    func testBatteryImpact() {
        // Measure: Should be < 15% per hour
    }
}
```

## Migration Path

### Phase 1: Add Data Outputs (Week 1-2)
- Add AVCaptureVideoDataOutput to existing session
- Implement basic frame capture
- No composition yet, just logging

### Phase 2: Implement Compositor (Week 3-4)
- Build FrameCompositor class
- Implement side-by-side layout
- Test composition performance

### Phase 3: Add Asset Writer (Week 5-6)
- Integrate AVAssetWriter
- Connect compositor to writer
- Test end-to-end flow

### Phase 4: Optimize & Polish (Week 7-8)
- Performance tuning
- Memory optimization
- Error handling
- User feedback

## Success Criteria

✅ All 3 files created simultaneously during recording
✅ Combined video quality matches separate videos
✅ Frame rate maintained at 30fps (no drops)
✅ Memory usage < 300MB during recording
✅ No thermal throttling on iPhone 13 Pro or newer
✅ Combined file size reasonable (not 2x separate files)
✅ User can select layout before recording
✅ Graceful degradation on older devices

## Conclusion

This triple output system represents a significant technical achievement and competitive differentiator. The implementation leverages modern iOS APIs (AVFoundation, Core Image, Metal) for efficient, real-time video composition while maintaining high quality and performance.

