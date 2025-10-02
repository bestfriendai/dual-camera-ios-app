import CoreImage
import Metal
import AVFoundation
import UIKit

enum RecordingLayout: String {
    case sideBySide
    case pictureInPicture
    case frontPrimary
    case backPrimary
    
    enum PIPPosition {
        case topLeft, topRight, bottomLeft, bottomRight
    }
    
    enum PIPSize: CGFloat {
        case small = 0.25
        case medium = 0.33
        case large = 0.40
    }
}

class FrameCompositor {
    private let ciContext: CIContext
    private let metalDevice: MTLDevice
    private var renderSize: CGSize
    private var layout: RecordingLayout
    
    // Performance optimization properties
    private var lastPerformanceCheck: CFTimeInterval = 0
    private var frameProcessingTimes: [CFTimeInterval] = []
    private let maxProcessingTimeSamples = 60 // Increased for better accuracy
    private var adaptiveQualityEnabled = true
    private var currentQualityLevel: Float = 1.0 // 1.0 = full quality, 0.5 = half quality
    
    // Enhanced pixel buffer pool management
    private var pixelBufferPool: CVPixelBufferPool?
    private var poolIdentifier: String = ""
    private var metalCommandQueue: MTLCommandQueue?
    
    // GPU optimization
    private var renderPipelineState: MTLRenderPipelineState?
    private var textureCache: CVMetalTextureCache?
    
    // Frame rate stabilization
    private var targetFrameRate: Double = 30.0
    private var frameDropThreshold: CFTimeInterval = 0.05 // 50ms
    
    init(layout: RecordingLayout, quality: VideoQuality) {
        guard let device = MTLCreateSystemDefaultDevice() else {
            fatalError("Metal not supported on this device")
        }
        
        self.metalDevice = device
        self.renderSize = quality.renderSize
        self.layout = layout
        
        // Create optimized CIContext
        self.ciContext = CIContext(mtlDevice: device, options: [
            .workingColorSpace: CGColorSpaceCreateDeviceRGB(),
            .outputColorSpace: CGColorSpaceCreateDeviceRGB(),
            .cacheIntermediates: false, // Optimize for memory
            .allowLowPower: true, // Optimize for battery
            .priorityRequestLow: true // Optimize for performance
        ])
        
        // Create Metal command queue
        self.metalCommandQueue = device.makeCommandQueue()
        
        // Setup Metal texture cache
        setupMetalTextureCache()
        
        // Setup pixel buffer pool with memory manager
        setupPixelBufferPool()
        
        // Setup frame rate stabilization
        setupFrameRateStabilization()
    }
    
    private func setupMetalTextureCache() {
        var cache: CVMetalTextureCache?
        let result = CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, metalDevice, nil, &cache)
        
        if result == kCVReturnSuccess, let textureCache = cache {
            self.textureCache = textureCache
        }
    }
    
    private func setupPixelBufferPool() {
        poolIdentifier = "FrameCompositor_\(renderSize.width)x\(renderSize.height)_\(UUID().uuidString)"
        
        let pixelBufferAttributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: Int(renderSize.width),
            kCVPixelBufferHeightKey as String: Int(renderSize.height),
            kCVPixelBufferMetalCompatibilityKey as String: true,
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true,
            kCVPixelBufferIOSurfacePropertiesKey as String: [:] as CFDictionary
        ]
        
        let poolAttributes: [String: Any] = [
            kCVPixelBufferPoolMinimumBufferCountKey as String: 3,
            kCVPixelBufferPoolMaximumBufferAgeKey as String: 2.0
        ]
        
        var pool: CVPixelBufferPool?
        let status = CVPixelBufferPoolCreate(
            nil,
            poolAttributes as CFDictionary,
            pixelBufferAttributes as CFDictionary,
            &pool
        )
        
        if status == kCVReturnSuccess {
            pixelBufferPool = pool
        }
    }
    
    private func setupFrameRateStabilization() {
        // Get target frame rate from adaptive quality manager
        targetFrameRate = 30.0 // AdaptiveQualityManager.shared.stabilizeFrameRate()
    }
    
    func updateLayout(_ newLayout: RecordingLayout) {
        self.layout = newLayout
    }
    
    func composite(frontBuffer: CVPixelBuffer,
                   backBuffer: CVPixelBuffer,
                   timestamp: CMTime) -> CVPixelBuffer? {
        
        let startTime = CACurrentMediaTime()
        
        if shouldDropFrame() {
            return nil
        }
        
        checkPerformanceAdaptation()
        
        let frontImage = CIImage(cvPixelBuffer: frontBuffer)
        let backImage = CIImage(cvPixelBuffer: backBuffer)
        
        let processedFrontImage = applyAdaptiveQuality(to: frontImage)
        let processedBackImage = applyAdaptiveQuality(to: backImage)
        
        let composedImage: CIImage
        switch layout {
        case .sideBySide:
            composedImage = composeSideBySide(front: processedFrontImage, back: processedBackImage)
        case .pictureInPicture:
            composedImage = composeSideBySide(front: processedFrontImage, back: processedBackImage)
        case .frontPrimary:
            composedImage = composePrimary(primary: processedFrontImage, secondary: processedBackImage)
        case .backPrimary:
            composedImage = composePrimary(primary: processedBackImage, secondary: processedFrontImage)
        }
        
        guard let result = renderToPixelBuffer(composedImage) else {
            return nil
        }
        
        let processingTime = CACurrentMediaTime() - startTime
        trackProcessingTime(processingTime)
        
        PerformanceMonitor.shared.recordFrame()
        
        return result
    }
    
    private func shouldDropFrame() -> Bool {
        // Check if we're falling behind on frame rate
        let targetFrameTime = 1.0 / targetFrameRate
        let currentTime = CACurrentMediaTime()
        
        if let lastTime = frameProcessingTimes.last {
            let timeSinceLastFrame = currentTime - lastTime
            // If we're running too slow, drop this frame to catch up
            if timeSinceLastFrame > targetFrameTime + frameDropThreshold {
                return true
            }
        }
        
        return false
    }
    
    private func createMetalTexture(from pixelBuffer: CVPixelBuffer) -> MTLTexture? {
        guard let textureCache = textureCache else { return nil }
        
        var metalTexture: CVMetalTexture?
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        
        let result = CVMetalTextureCacheCreateTextureFromImage(
            kCFAllocatorDefault,
            textureCache,
            pixelBuffer,
            nil,
            .bgra8Unorm,
            width,
            height,
            0,
            &metalTexture
        )
        
        guard result == kCVReturnSuccess,
              let texture = metalTexture,
              let metalTextureRef = CVMetalTextureGetTexture(texture) else {
            return nil
        }
        
        return metalTextureRef
    }
    
    private func compositeWithMetal(front: MTLTexture, back: MTLTexture) -> MTLTexture? {
        guard let commandQueue = metalCommandQueue,
              let commandBuffer = commandQueue.makeCommandBuffer() else {
            return nil
        }
        let device = metalDevice
        
        if renderPipelineState == nil {
            createRenderPipelineState(device: device)
        }
        
        guard let pipelineState = renderPipelineState else {
            return nil
        }
        
        let outputTextureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm,
            width: Int(renderSize.width),
            height: Int(renderSize.height),
            mipmapped: false
        )
        outputTextureDescriptor.usage = [.renderTarget, .shaderRead]
        outputTextureDescriptor.storageMode = .private
        
        guard let outputTexture = device.makeTexture(descriptor: outputTextureDescriptor) else {
            return nil
        }
        
        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = outputTexture
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        renderPassDescriptor.colorAttachments[0].storeAction = .store
        
        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            return nil
        }
        
        renderEncoder.setRenderPipelineState(pipelineState)
        renderEncoder.setFragmentTexture(front, index: 0)
        renderEncoder.setFragmentTexture(back, index: 1)
        renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
        renderEncoder.endEncoding()
        
        commandBuffer.commit()
        
        return outputTexture
    }
    
    private func createRenderPipelineState(device: MTLDevice) {
        // Create a simple vertex shader
        let vertexShaderSource = """
        using namespace metal;
        
        struct VertexOut {
            float4 position [[position]];
            float2 texCoord;
        };
        
        vertex VertexOut vertex_shader(uint vertexID [[vertex_id]]) {
            VertexOut out;
            
            float2 positions[6] = {
                float2(-1.0, -1.0),
                float2(1.0, -1.0),
                float2(-1.0, 1.0),
                float2(1.0, -1.0),
                float2(1.0, 1.0),
                float2(-1.0, 1.0)
            };
            
            float2 texCoords[6] = {
                float2(0.0, 1.0),
                float2(1.0, 1.0),
                float2(0.0, 0.0),
                float2(1.0, 1.0),
                float2(1.0, 0.0),
                float2(0.0, 0.0)
            };
            
            out.position = float4(positions[vertexID], 0.0, 1.0);
            out.texCoord = texCoords[vertexID];
            
            return out;
        }
        """
        
        // Create a fragment shader for composition
        let fragmentShaderSource = """
        using namespace metal;
        
        struct VertexOut {
            float4 position [[position]];
            float2 texCoord;
        };
        
        fragment float4 fragment_shader(VertexOut in [[stage_in]],
                                       texture2d<float> frontTexture [[texture(0)]],
                                       texture2d<float> backTexture [[texture(1)]],
                                       sampler textureSampler [[sampler(0)]]) {
            constexpr sampler s(coord::normalized, address::clamp_to_edge, filter::linear);
            
            float2 frontCoord = in.texCoord;
            float2 backCoord = in.texCoord;
            
            // Adjust coordinates based on layout
            // This is a simplified implementation
            // In a real implementation, you'd pass layout parameters as uniforms
            
            float4 frontColor = frontTexture.sample(s, frontCoord);
            float4 backColor = backTexture.sample(s, backCoord);
            
            // Simple side-by-side composition
            if (in.texCoord.x < 0.5) {
                return frontColor;
            } else {
                return backColor;
            }
        }
        """
        
        do {
            // Create library
            let library = try device.makeLibrary(source: vertexShaderSource + "\n" + fragmentShaderSource, options: nil)
            
            // Create functions
            let vertexFunction = library.makeFunction(name: "vertex_shader")
            let fragmentFunction = library.makeFunction(name: "fragment_shader")
            
            // Create pipeline descriptor
            let pipelineDescriptor = MTLRenderPipelineDescriptor()
            pipelineDescriptor.vertexFunction = vertexFunction
            pipelineDescriptor.fragmentFunction = fragmentFunction
            pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
            
            // Create pipeline state
            renderPipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch {
            print("Failed to create render pipeline state: \(error)")
        }
    }
    
    private func convertTextureToPixelBuffer(_ texture: MTLTexture) -> CVPixelBuffer? {
        guard let pool = pixelBufferPool else {
            return nil
        }
        
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool, &pixelBuffer)
        guard status == kCVReturnSuccess, let pixelBuffer = pixelBuffer else {
            return nil
        }
        
        // Create Metal texture from pixel buffer
        guard let destinationTexture = createMetalTexture(from: pixelBuffer) else {
            return nil
        }
        
        // Copy texture
        guard let commandQueue = metalCommandQueue,
              let commandBuffer = commandQueue.makeCommandBuffer(),
              let blitEncoder = commandBuffer.makeBlitCommandEncoder() else {
            return nil
        }
        
        blitEncoder.copy(from: texture, sourceSlice: 0, sourceLevel: 0, sourceOrigin: MTLOrigin(x: 0, y: 0, z: 0),
                        sourceSize: MTLSize(width: texture.width, height: texture.height, depth: 1),
                        to: destinationTexture, destinationSlice: 0, destinationLevel: 0,
                        destinationOrigin: MTLOrigin(x: 0, y: 0, z: 0))
        
        blitEncoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        
        return pixelBuffer
    }
    
    private func compositeWithCPU(frontBuffer: CVPixelBuffer, backBuffer: CVPixelBuffer, timestamp: CMTime) -> CVPixelBuffer? {
        // Fallback to CPU processing
        let frontImage = CIImage(cvPixelBuffer: frontBuffer)
        let backImage = CIImage(cvPixelBuffer: backBuffer)
        
        // Apply adaptive quality if needed
        let processedFrontImage = applyAdaptiveQuality(to: frontImage)
        let processedBackImage = applyAdaptiveQuality(to: backImage)
        
        let composedImage: CIImage
        switch layout {
        case .sideBySide:
            composedImage = composeSideBySide(front: processedFrontImage, back: processedBackImage)
        case .pictureInPicture:
            // Default PIP without parameters
            composedImage = composeSideBySide(front: processedFrontImage, back: processedBackImage)
        case .frontPrimary:
            composedImage = composePrimary(primary: processedFrontImage, secondary: processedBackImage)
        case .backPrimary:
            composedImage = composePrimary(primary: processedBackImage, secondary: processedFrontImage)
        }
        
        return renderToPixelBuffer(composedImage)
    }
    
    private func applyAdaptiveQuality(to image: CIImage) -> CIImage {
        guard adaptiveQualityEnabled && currentQualityLevel < 1.0 else { return image }
        
        _ = CGSize(
            width: image.extent.width * CGFloat(currentQualityLevel),
            height: image.extent.height * CGFloat(currentQualityLevel)
        )
        
        return image.transformed(by: CGAffineTransform(scaleX: CGFloat(currentQualityLevel),
                                                     y: CGFloat(currentQualityLevel)))
    }
    
    private func checkPerformanceAdaptation() {
        let currentTime = CACurrentMediaTime()
        
        // Check performance every 2 seconds
        if currentTime - lastPerformanceCheck > 2.0 {
            lastPerformanceCheck = currentTime
            
            guard !frameProcessingTimes.isEmpty else { return }
            
            let averageProcessingTime = frameProcessingTimes.reduce(0, +) / CFTimeInterval(frameProcessingTimes.count)
            let targetProcessingTime = 1.0 / 30.0 // Target 30 FPS
            
            // Adapt quality based on performance
            if averageProcessingTime > targetProcessingTime * 1.5 {
                // Performance is poor, reduce quality
                currentQualityLevel = max(0.5, currentQualityLevel - 0.1)
                PerformanceMonitor.shared.logEvent("Quality Adaptation", "Reduced quality to \(currentQualityLevel)")
            } else if averageProcessingTime < targetProcessingTime * 0.5 && currentQualityLevel < 1.0 {
                // Performance is good, increase quality
                currentQualityLevel = min(1.0, currentQualityLevel + 0.1)
                PerformanceMonitor.shared.logEvent("Quality Adaptation", "Increased quality to \(currentQualityLevel)")
            }
            
            // Clear old samples
            frameProcessingTimes.removeAll()
        }
    }
    
    private func trackProcessingTime(_ processingTime: CFTimeInterval) {
        frameProcessingTimes.append(processingTime)
        
        // Keep only recent samples
        if frameProcessingTimes.count > maxProcessingTimeSamples {
            frameProcessingTimes.removeFirst()
        }
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
        
        // Create background
        let background = CIImage(color: CIColor.black)
            .cropped(to: CGRect(origin: .zero, size: renderSize))
        
        // Composite both images
        return backScaled.composited(over: frontScaled).composited(over: background)
    }
    
    private func composePIP(front: CIImage, back: CIImage, 
                           position: RecordingLayout.PIPPosition,
                           size: RecordingLayout.PIPSize) -> CIImage {
        
        // Back camera as main background
        let mainScaled = back
            .transformed(by: CGAffineTransform(scaleX: renderSize.width / back.extent.width,
                                               y: renderSize.height / back.extent.height))
        
        // Calculate PIP dimensions
        let pipScale = size.rawValue
        let pipWidth = renderSize.width * pipScale
        let pipHeight = renderSize.height * pipScale
        
        // Scale front camera for PIP
        let pipScaled = front
            .transformed(by: CGAffineTransform(scaleX: pipWidth / front.extent.width,
                                               y: pipHeight / front.extent.height))
        
        // Position PIP based on corner
        let margin: CGFloat = 20
        let pipPosition: CGPoint
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
        let pipWithBorder = addBorder(to: pipPositioned, 
                                     rect: CGRect(origin: pipPosition, 
                                                 size: CGSize(width: pipWidth, height: pipHeight)),
                                     width: 3, 
                                     color: .white)
        
        // Create background
        let background = CIImage(color: CIColor.black)
            .cropped(to: CGRect(origin: .zero, size: renderSize))
        
        // Composite PIP over main
        return pipWithBorder.composited(over: mainScaled).composited(over: background)
    }
    
    private func composePrimary(primary: CIImage, secondary: CIImage) -> CIImage {
        // Primary takes 75% of width, secondary takes 25%
        let primaryWidth = renderSize.width * 0.75
        let secondaryWidth = renderSize.width * 0.25
        
        // Scale primary (left side)
        let primaryScaled = primary
            .transformed(by: CGAffineTransform(scaleX: primaryWidth / primary.extent.width,
                                               y: renderSize.height / primary.extent.height))
        
        // Scale secondary (right side)
        let secondaryScaled = secondary
            .transformed(by: CGAffineTransform(scaleX: secondaryWidth / secondary.extent.width,
                                              y: renderSize.height / secondary.extent.height))
            .transformed(by: CGAffineTransform(translationX: primaryWidth, y: 0))
        
        // Create background
        let background = CIImage(color: CIColor.black)
            .cropped(to: CGRect(origin: .zero, size: renderSize))
        
        return secondaryScaled.composited(over: primaryScaled).composited(over: background)
    }
    
    private func addBorder(to image: CIImage, rect: CGRect, width: CGFloat, color: UIColor) -> CIImage {
        // Create a simple border by overlaying the image on a slightly larger colored rectangle
        let borderRect = rect.insetBy(dx: -width, dy: -width)
        let borderColor = CIColor(color: color)
        
        let borderImage = CIImage(color: borderColor)
            .cropped(to: borderRect)
        
        return image.composited(over: borderImage)
    }
    
    private func renderToPixelBuffer(_ image: CIImage) -> CVPixelBuffer? {
        var pixelBuffer: CVPixelBuffer?
        
        // Try to use pool first for better performance
        if let pool = pixelBufferPool {
            CVPixelBufferPoolCreatePixelBuffer(nil, pool, &pixelBuffer)
        }
        
        // Fallback to creating new buffer if pool fails
        if pixelBuffer == nil {
            let attrs = [
                kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue as Any,
                kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue as Any,
                kCVPixelBufferMetalCompatibilityKey: kCFBooleanTrue as Any,
                kCVPixelBufferIOSurfacePropertiesKey: [:] as CFDictionary
            ] as CFDictionary
            
            let status = CVPixelBufferCreate(kCFAllocatorDefault,
                                            Int(renderSize.width),
                                            Int(renderSize.height),
                                            kCVPixelFormatType_32BGRA,
                                            attrs,
                                            &pixelBuffer)
            
            guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
                print("Failed to create pixel buffer: \(status)")
                return nil
            }
        }
        
        guard let buffer = pixelBuffer else { return nil }
        
        // Render with performance optimization
        ciContext.render(image,
                        to: buffer,
                        bounds: CGRect(origin: .zero, size: renderSize),
                        colorSpace: CGColorSpaceCreateDeviceRGB())
        
        return buffer
    }
    
    // MARK: - Performance Control
    
    func setAdaptiveQuality(_ enabled: Bool) {
        adaptiveQualityEnabled = enabled
    }
    
    func setCurrentQualityLevel(_ level: Float) {
        currentQualityLevel = max(0.5, min(1.0, level))
    }
    
    func getCurrentQualityLevel() -> Float {
        return currentQualityLevel
    }
    
    func resetPerformanceMetrics() {
        frameProcessingTimes.removeAll()
        currentQualityLevel = 1.0
        lastPerformanceCheck = 0
    }
}

