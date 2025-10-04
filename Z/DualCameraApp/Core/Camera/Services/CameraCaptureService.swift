//
//  CameraCaptureService.swift
//  DualApp
//
//  Created by DualApp Team on 10/3/25.
//

import Foundation
import AVFoundation
import CoreVideo
import CoreImage
import Metal
import UIKit

// MARK: - Camera Capture Service

@MainActor
actor CameraCaptureService: Sendable {
    
    // MARK: - Properties
    
    private var configuration: CameraConfiguration
    private var isProcessing: Bool = false
    private var processingQueue: DispatchQueue?
    
    // MARK: - Frame Processing
    
    private var frameProcessors: [FrameProcessor] = []
    private var frameFilters: [FrameFilter] = []
    private var frameTransforms: [FrameTransform] = []
    
    // MARK: - Buffer Management
    
    private var frameBufferPool: FrameBufferPool?
    private var pixelBufferAdaptor: CVPixelBufferPool?
    
    // MARK: - Performance Monitoring
    
    private var captureMetrics: CaptureMetrics = CaptureMetrics()
    private var frameRateLimiter: FrameRateLimiter?
    
    // MARK: - Event Stream
    
    let events: AsyncStream<CaptureEvent>
    private let eventContinuation: AsyncStream<CaptureEvent>.Continuation
    
    // MARK: - Metal Processing
    
    private var metalDevice: MTLDevice?
    private var metalCommandQueue: MTLCommandQueue?
    private var computePipelineState: MTLComputePipelineState?
    
    // MARK: - Initialization
    
    init(configuration: CameraConfiguration) {
        self.configuration = configuration
        
        (self.events, self.eventContinuation) = AsyncStream<CaptureEvent>.makeStream()
        
        // Initialize processing components
        setupProcessingComponents()
        
        // Initialize Metal if available
        setupMetalProcessing()
    }
    
    // MARK: - Public Interface
    
    func startProcessing() async throws {
        guard !isProcessing else {
            throw CaptureError.alreadyProcessing
        }
        
        // Create processing queue
        processingQueue = DispatchQueue(label: "camera.capture.processing", qos: .userInteractive)
        
        // Create frame buffer pool
        try await createFrameBufferPool()
        
        // Initialize frame rate limiter
        frameRateLimiter = FrameRateLimiter(targetFrameRate: Double(configuration.frameRate))
        
        isProcessing = true
        eventContinuation.yield(.processingStarted)
    }
    
    func stopProcessing() async {
        guard isProcessing else { return }
        
        isProcessing = false
        processingQueue = nil
        frameBufferPool = nil
        frameRateLimiter = nil
        
        eventContinuation.yield(.processingStopped)
    }
    
    func processFrame(_ frame: DualCameraFrame) async -> ProcessedFrame? {
        guard isProcessing else {
            eventContinuation.yield(.error(CaptureError.notProcessing))
            return nil
        }
        
        let startTime = CACurrentMediaTime()
        
        // Update metrics
        captureMetrics.totalFrames += 1
        
        // Check frame rate limiter
        if let limiter = frameRateLimiter, !limiter.shouldProcessFrame() {
            captureMetrics.droppedFrames += 1
            return nil
        }
        
        do {
            // Process frame through pipeline
            let processedFrame = try await processFrameThroughPipeline(frame)
            
            // Update metrics
            let processingTime = CACurrentMediaTime() - startTime
            captureMetrics.averageProcessingTime = (captureMetrics.averageProcessingTime + processingTime) / 2
            captureMetrics.processedFrames += 1
            
            eventContinuation.yield(.frameProcessed(processedFrame))
            
            return processedFrame
            
        } catch {
            captureMetrics.failedFrames += 1
            eventContinuation.yield(.error(CaptureError.processingFailed(error)))
            return nil
        }
    }
    
    func addFrameProcessor(_ processor: FrameProcessor) async {
        frameProcessors.append(processor)
        eventContinuation.yield(.processorAdded(processor))
    }
    
    func removeFrameProcessor(_ processor: FrameProcessor) async {
        frameProcessors.removeAll { $0.id == processor.id }
        eventContinuation.yield(.processorRemoved(processor))
    }
    
    func addFrameFilter(_ filter: FrameFilter) async {
        frameFilters.append(filter)
        eventContinuation.yield(.filterAdded(filter))
    }
    
    func removeFrameFilter(_ filter: FrameFilter) async {
        frameFilters.removeAll { $0.id == filter.id }
        eventContinuation.yield(.filterRemoved(filter))
    }
    
    func addFrameTransform(_ transform: FrameTransform) async {
        frameTransforms.append(transform)
        eventContinuation.yield(.transformAdded(transform))
    }
    
    func removeFrameTransform(_ transform: FrameTransform) async {
        frameTransforms.removeAll { $0.id == transform.id }
        eventContinuation.yield(.transformRemoved(transform))
    }
    
    func updateConfiguration(_ configuration: CameraConfiguration) async {
        self.configuration = configuration
        
        // Update frame rate limiter
        frameRateLimiter = FrameRateLimiter(targetFrameRate: Double(configuration.frameRate))
        
        // Recreate frame buffer pool if needed
        if isProcessing {
            try? await createFrameBufferPool()
        }
        
        eventContinuation.yield(.configurationUpdated(configuration))
    }
    
    func getCaptureMetrics() async -> CaptureMetrics {
        return captureMetrics
    }
    
    func resetMetrics() async {
        captureMetrics = CaptureMetrics()
        eventContinuation.yield(.metricsReset)
    }
    
    // MARK: - Private Methods
    
    private func setupProcessingComponents() {
        // Add default frame processors
        frameProcessors = [
            ColorCorrectionProcessor(),
            ExposureAdjustmentProcessor(),
            NoiseReductionProcessor()
        ]
        
        // Add default frame filters
        frameFilters = [
            BasicColorFilter(),
            SharpenFilter()
        ]
        
        // Add default frame transforms
        frameTransforms = [
            OrientationTransform(),
            CropTransform()
        ]
    }
    
    private func setupMetalProcessing() {
        metalDevice = MTLCreateSystemDefaultDevice()
        guard let device = metalDevice else { return }
        
        metalCommandQueue = device.makeCommandQueue()
        
        // Load Metal shaders
        if let library = device.makeDefaultLibrary(),
           let kernelFunction = library.makeFunction(name: "frameProcessingKernel") {
            do {
                computePipelineState = try device.makeComputePipelineState(function: kernelFunction)
            } catch {
                print("Failed to create compute pipeline state: \(error)")
            }
        }
    }
    
    private func createFrameBufferPool() async throws {
        let width = Int(configuration.quality.resolution.width)
        let height = Int(configuration.quality.resolution.height)
        
        frameBufferPool = FrameBufferPool(
            width: width,
            height: height,
            pixelFormat: kCVPixelFormatType_32BGRA,
            bufferCount: 3
        )
    }
    
    private func processFrameThroughPipeline(_ frame: DualCameraFrame) async throws -> ProcessedFrame {
        var currentFrame = frame
        
        // Apply frame processors
        for processor in frameProcessors {
            currentFrame = try await processor.process(currentFrame, configuration: configuration)
        }
        
        // Apply frame transforms
        for transform in frameTransforms {
            currentFrame = try await transform.apply(to: currentFrame, configuration: configuration)
        }
        
        // Apply frame filters
        for filter in frameFilters {
            currentFrame = try await filter.apply(to: currentFrame, configuration: configuration)
        }
        
        // Create processed frame
        return ProcessedFrame(
            originalFrame: frame,
            processedFrame: currentFrame,
            processors: frameProcessors.map { $0.id },
            filters: frameFilters.map { $0.id },
            transforms: frameTransforms.map { $0.id },
            timestamp: Date(),
            processingTime: CACurrentMediaTime()
        )
    }
}

// MARK: - Supporting Types

enum CaptureEvent: Sendable {
    case processingStarted
    case processingStopped
    case frameProcessed(ProcessedFrame)
    case processorAdded(FrameProcessor)
    case processorRemoved(FrameProcessor)
    case filterAdded(FrameFilter)
    case filterRemoved(FrameFilter)
    case transformAdded(FrameTransform)
    case transformRemoved(FrameTransform)
    case configurationUpdated(CameraConfiguration)
    case metricsReset
    case error(CaptureError)
}

enum CaptureError: LocalizedError, Sendable {
    case alreadyProcessing
    case notProcessing
    case processingFailed(Error)
    case bufferCreationFailed
    case metalProcessingFailed
    
    var errorDescription: String? {
        switch self {
        case .alreadyProcessing:
            return "Capture service is already processing"
        case .notProcessing:
            return "Capture service is not processing"
        case .processingFailed(let error):
            return "Frame processing failed: \(error.localizedDescription)"
        case .bufferCreationFailed:
            return "Failed to create frame buffer"
        case .metalProcessingFailed:
            return "Metal processing failed"
        }
    }
}

struct CaptureMetrics: Sendable {
    var totalFrames: Int = 0
    var processedFrames: Int = 0
    var droppedFrames: Int = 0
    var failedFrames: Int = 0
    var averageProcessingTime: CFTimeInterval = 0
    
    var processingRate: Double {
        return totalFrames > 0 ? Double(processedFrames) / Double(totalFrames) : 0
    }
    
    var dropRate: Double {
        return totalFrames > 0 ? Double(droppedFrames) / Double(totalFrames) : 0
    }
    
    var failureRate: Double {
        return totalFrames > 0 ? Double(failedFrames) / Double(totalFrames) : 0
    }
    
    var formattedProcessingRate: String {
        return String(format: "%.1f%%", processingRate * 100)
    }
    
    var formattedDropRate: String {
        return String(format: "%.1f%%", dropRate * 100)
    }
    
    var formattedAverageProcessingTime: String {
        return String(format: "%.2f ms", averageProcessingTime * 1000)
    }
}

struct ProcessedFrame: Sendable {
    let originalFrame: DualCameraFrame
    let processedFrame: DualCameraFrame
    let processors: [String]
    let filters: [String]
    let transforms: [String]
    let timestamp: Date
    let processingTime: CFTimeInterval
    
    var pixelBuffer: CVPixelBuffer? {
        return processedFrame.pixelBuffer
    }
}

// MARK: - Frame Buffer Pool

class FrameBufferPool: @unchecked Sendable {
    private var bufferPool: CVPixelBufferPool?
    private let width: Int
    private let height: Int
    private let pixelFormat: OSType
    private let bufferCount: Int
    private let lock = NSLock()
    
    init(width: Int, height: Int, pixelFormat: OSType, bufferCount: Int) {
        self.width = width
        self.height = height
        self.pixelFormat = pixelFormat
        self.bufferCount = bufferCount
        
        createBufferPool()
    }
    
    func getBuffer() -> CVPixelBuffer? {
        lock.lock()
        defer { lock.unlock() }
        
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferPoolCreatePixelBuffer(
            kCFAllocatorDefault,
            bufferPool!,
            &pixelBuffer,
            nil,
            nil
        )
        
        return status == kCVReturnSuccess ? pixelBuffer : nil
    }
    
    private func createBufferPool() {
        let pixelBufferAttributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: pixelFormat,
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height,
            kCVPixelBufferIOSurfacePropertiesKey as String: [:],
            kCVPixelBufferPoolMinimumBufferCountKey as String: bufferCount
        ]
        
        CVPixelBufferPoolCreate(
            kCFAllocatorDefault,
            pixelBufferAttributes as CFDictionary,
            nil,
            &bufferPool
        )
    }
}

// MARK: - Frame Rate Limiter

class FrameRateLimiter: @unchecked Sendable {
    private let targetFrameRate: Double
    private let targetFrameTime: CFTimeInterval
    private var lastFrameTime: CFTimeInterval = 0
    private let lock = NSLock()
    
    init(targetFrameRate: Double) {
        self.targetFrameRate = targetFrameRate
        self.targetFrameTime = 1.0 / targetFrameRate
    }
    
    func shouldProcessFrame() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        
        let currentTime = CACurrentMediaTime()
        let timeSinceLastFrame = currentTime - lastFrameTime
        
        if timeSinceLastFrame >= targetFrameTime {
            lastFrameTime = currentTime
            return true
        }
        
        return false
    }
    
    func getTargetFrameTime() -> CFTimeInterval {
        return targetFrameTime
    }
}

// MARK: - Frame Processor Protocol

protocol FrameProcessor: Sendable, Identifiable {
    func process(_ frame: DualCameraFrame, configuration: CameraConfiguration) async throws -> DualCameraFrame
}

// MARK: - Frame Filter Protocol

protocol FrameFilter: Sendable, Identifiable {
    func apply(to frame: DualCameraFrame, configuration: CameraConfiguration) async throws -> DualCameraFrame
}

// MARK: - Frame Transform Protocol

protocol FrameTransform: Sendable, Identifiable {
    func apply(to frame: DualCameraFrame, configuration: CameraConfiguration) async throws -> DualCameraFrame
}

// MARK: - Concrete Frame Processors

struct ColorCorrectionProcessor: FrameProcessor {
    let id = "color_correction"
    
    func process(_ frame: DualCameraFrame, configuration: CameraConfiguration) async throws -> DualCameraFrame {
        // Apply color correction
        return frame
    }
}

struct ExposureAdjustmentProcessor: FrameProcessor {
    let id = "exposure_adjustment"
    
    func process(_ frame: DualCameraFrame, configuration: CameraConfiguration) async throws -> DualCameraFrame {
        // Apply exposure adjustment
        return frame
    }
}

struct NoiseReductionProcessor: FrameProcessor {
    let id = "noise_reduction"
    
    func process(_ frame: DualCameraFrame, configuration: CameraConfiguration) async throws -> DualCameraFrame {
        // Apply noise reduction
        return frame
    }
}

// MARK: - Concrete Frame Filters

struct BasicColorFilter: FrameFilter {
    let id = "basic_color"
    
    func apply(to frame: DualCameraFrame, configuration: CameraConfiguration) async throws -> DualCameraFrame {
        // Apply basic color filter
        return frame
    }
}

struct SharpenFilter: FrameFilter {
    let id = "sharpen"
    
    func apply(to frame: DualCameraFrame, configuration: CameraConfiguration) async throws -> DualCameraFrame {
        // Apply sharpening filter
        return frame
    }
}

// MARK: - Concrete Frame Transforms

struct OrientationTransform: FrameTransform {
    let id = "orientation"
    
    func apply(to frame: DualCameraFrame, configuration: CameraConfiguration) async throws -> DualCameraFrame {
        // Apply orientation transform
        return frame
    }
}

struct CropTransform: FrameTransform {
    let id = "crop"
    
    func apply(to frame: DualCameraFrame, configuration: CameraConfiguration) async throws -> DualCameraFrame {
        // Apply crop transform
        return frame
    }
}