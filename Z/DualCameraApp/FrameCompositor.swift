// Dual Camera App
import CoreImage
import Metal
import AVFoundation
import UIKit
import Swift

enum RecordingLayout: String, Sendable {
    case sideBySide
    case pictureInPicture
    case frontPrimary
    case backPrimary
    
    enum PIPPosition: Sendable {
        case topLeft, topRight, bottomLeft, bottomRight
    }
    
    enum PIPSize: CGFloat, Sendable {
        case small = 0.25
        case medium = 0.33
        case large = 0.40
    }
}

@available(iOS 15.0, *)
actor FrameCompositor {
    private let ciContext: CIContext
    private let metalDevice: MTLDevice
    private var renderSize: CGSize
    private var layout: RecordingLayout
    
    // Performance optimization properties - now actor-isolated
    private var lastPerformanceCheck: CFTimeInterval = 0
    private var frameProcessingTimes: [CFTimeInterval] = Array(repeating: 0.0, count: 60)
    private var frameProcessingTimesCount: Int = 0
    private let maxProcessingTimeSamples = 60
    private var adaptiveQualityEnabled = true
    private var currentQualityLevel: Float = 1.0
    
    // Enhanced pixel buffer pool management - now actor-isolated
    private var pixelBufferPool: CVPixelBufferPool?
    private var poolIdentifier: String = ""
    private var metalCommandQueue: MTLCommandQueue?
    
    // GPU optimization - now actor-isolated
    private var renderPipelineState: MTLRenderPipelineState?
    private var textureCache: CVMetalTextureCache?
    
    // Frame rate stabilization - now actor-isolated
    private var targetFrameRate: Double = 30.0
    private var frameDropThreshold: CFTimeInterval = 0.05
    
    // Cache tracking - now actor-isolated
    private var cacheSize: Int64 = 0
    
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
        
        // Initialize the actor-isolated properties
        Task {
            await setupMetalTextureCache()
            await setupPixelBufferPool()
            await setupFrameRateStabilization()
        }
        
        // Register with MemoryTracker if available
        // Commented out due to Swift 6.2 compilation issues
        // if #available(iOS 17.0, *) {
        //     ModernMemoryManager.shared.registerCacheOwner(self)
        // }
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
        let status = CVPixelBufferPoolCreate(kCFAllocatorDefault,
                                             poolAttributes as CFDictionary,
                                             pixelBufferAttributes as CFDictionary,
                                             &pool)
        
        if status == kCVReturnSuccess {
            pixelBufferPool = pool
        }
        
        updateCacheSize()
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
                   timestamp: CMTime) async -> CVPixelBuffer? {
        
        let startTime = CACurrentMediaTime()
        
        if await shouldDropFrame() {
            print("DEBUG: ⚠️ Dropping frame due to performance")
            return nil
        }
        
        await checkPerformanceAdaptation()
        
        let frontImage = CIImage(cvPixelBuffer: frontBuffer)
        let backImage = CIImage(cvPixelBuffer: backBuffer)
        
        let processedFrontImage = await applyAdaptiveQuality(to: frontImage)
        let processedBackImage = await applyAdaptiveQuality(to: backImage)
        
        let composedImage: CIImage
        switch layout {
        case .sideBySide:
            composedImage = composeSideBySide(front: processedFrontImage, back: processedBackImage)
        case .pictureInPicture:
            composedImage = composePIP(front: processedFrontImage, back: processedBackImage, 
                                      position: .bottomRight, size: .medium)
        case .frontPrimary:
            composedImage = composePrimary(primary: processedFrontImage, secondary: processedBackImage)
        case .backPrimary:
            composedImage = composePrimary(primary: processedBackImage, secondary: processedFrontImage)
        }
        
        guard let result = renderToPixelBuffer(composedImage) else {
            print("DEBUG: ⚠️ Failed to render composed frame to pixel buffer")
            return nil
        }
        
        let processingTime = CACurrentMediaTime() - startTime
        await trackProcessingTime(processingTime)
        
        PerformanceMonitor.shared.recordFrame()
        
        return result
    }
    
    private func shouldDropFrame() async -> Bool {
        // Check if we're falling behind on frame rate
        let targetFrameTime = 1.0 / targetFrameRate
        let currentTime = CACurrentMediaTime()
        
        // Only check if we have valid samples
        guard frameProcessingTimesCount > 0 else { return false }
        
        let lastTime = frameProcessingTimes[frameProcessingTimesCount - 1]
        let timeSinceLastFrame = currentTime - lastTime
        // If we're running too slow, drop this frame to catch up
        if timeSinceLastFrame > targetFrameTime + frameDropThreshold {
            return true
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
    
    private func compositeWithCPU(frontBuffer: CVPixelBuffer, backBuffer: CVPixelBuffer, timestamp: CMTime) async -> CVPixelBuffer? {
        // Span could be used for direct pixel manipulation if CIImage processing is too slow
        let frontImage = CIImage(cvPixelBuffer: frontBuffer)
        let backImage = CIImage(cvPixelBuffer: backBuffer)
        
        // Apply adaptive quality if needed
        let processedFrontImage = await applyAdaptiveQuality(to: frontImage)
        let processedBackImage = await applyAdaptiveQuality(to: backImage)
        
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
    
    private func applyAdaptiveQuality(to image: CIImage) async -> CIImage {
        guard adaptiveQualityEnabled && currentQualityLevel < 1.0 else { return image }
        
        _ = CGSize(
            width: image.extent.width * CGFloat(currentQualityLevel),
            height: image.extent.height * CGFloat(currentQualityLevel)
        )
        
        return image.transformed(by: CGAffineTransform(scaleX: CGFloat(currentQualityLevel),
                                                     y: CGFloat(currentQualityLevel)))
    }
    
    private func checkPerformanceAdaptation() async {
        let currentTime = CACurrentMediaTime()
        
        // Check performance every 2 seconds
        if currentTime - lastPerformanceCheck > 2.0 {
            lastPerformanceCheck = currentTime
            
            guard frameProcessingTimesCount > 0 else { return }
            
            var sum: CFTimeInterval = 0
            for i in 0..<frameProcessingTimesCount {
                sum += frameProcessingTimes[i]
            }
            let averageProcessingTime = sum / CFTimeInterval(frameProcessingTimesCount)
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
            frameProcessingTimesCount = 0
        }
    }
    
    private func trackProcessingTime(_ processingTime: CFTimeInterval) async {
        if frameProcessingTimesCount < 60 {
            frameProcessingTimes[frameProcessingTimesCount] = processingTime
            frameProcessingTimesCount += 1
        } else {
            for i in 0..<59 {
                frameProcessingTimes[i] = frameProcessingTimes[i + 1]
            }
            frameProcessingTimes[59] = processingTime
        }
    }
    
    private func composeSideBySide(front: CIImage, back: CIImage) -> CIImage {
        let halfWidth = renderSize.width / 2
        
        // Create background first
        let background = CIImage(color: CIColor.black)
            .cropped(to: CGRect(origin: .zero, size: renderSize))
        
        // Scale and position front camera (left side)
        let frontScaled = front
            .transformed(by: CGAffineTransform(scaleX: halfWidth / front.extent.width,
                                               y: renderSize.height / front.extent.height))
        
        // Scale and position back camera (right side)  
        let backScaled = back
            .transformed(by: CGAffineTransform(scaleX: halfWidth / back.extent.width,
                                              y: renderSize.height / back.extent.height))
            .transformed(by: CGAffineTransform(translationX: halfWidth, y: 0))
        
        // FIXED: Composite both cameras over the background
        // First layer frontScaled over background, then backScaled over that result
        // This creates proper side-by-side with both cameras visible
        let withFront = frontScaled.composited(over: background)
        let final = backScaled.composited(over: withFront)
        
        return final
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
        
        if let pool = pixelBufferPool {
            let status = CVPixelBufferPoolCreatePixelBuffer(nil, pool, &pixelBuffer)
            if status != kCVReturnSuccess {
                print("DEBUG: ⚠️ Failed to get pixel buffer from pool: \(status)")
                pixelBuffer = nil
            }
        }
        
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
            
            guard status == kCVReturnSuccess, pixelBuffer != nil else {
                print("DEBUG: ⚠️ Failed to create pixel buffer: \(status)")
                return nil
            }
        }
        
        guard let buffer = pixelBuffer else { return nil }
        
        ciContext.render(image,
                        to: buffer,
                        bounds: CGRect(origin: .zero, size: renderSize),
                        colorSpace: CGColorSpaceCreateDeviceRGB())
        
        return buffer
    }
    
    @available(iOS 26.0, *)
    func renderToPixelBufferWithSpan(_ image: CIImage) async -> CVPixelBuffer? {
        var pixelBuffer: CVPixelBuffer?
        
        if let pool = pixelBufferPool {
            let status = CVPixelBufferPoolCreatePixelBuffer(nil, pool, &pixelBuffer)
            if status != kCVReturnSuccess {
                print("DEBUG: ⚠️ Failed to get pixel buffer from pool: \(status)")
                pixelBuffer = nil
            }
        }
        
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
            
            guard status == kCVReturnSuccess, pixelBuffer != nil else {
                print("DEBUG: ⚠️ Failed to create pixel buffer: \(status)")
                return nil
            }
        }
        
        guard let buffer = pixelBuffer else { return nil }
        
        guard CVPixelBufferLockBaseAddress(buffer, []) == kCVReturnSuccess else { 
            print("DEBUG: ⚠️ Failed to lock pixel buffer")
            return nil 
        }
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        
        guard let baseAddress = CVPixelBufferGetBaseAddress(buffer) else { 
            print("DEBUG: ⚠️ Failed to get base address")
            return nil 
        }
        
        let bytesPerRow = CVPixelBufferGetBytesPerRow(buffer)
        let height = CVPixelBufferGetHeight(buffer)
        let totalBytes = bytesPerRow * height
        
        let bufferPointer = UnsafeMutableRawBufferPointer(start: baseAddress, count: totalBytes)
        let pixelSpan = Span(_unsafeElements: bufferPointer.bindMemory(to: UInt8.self))
        
        ciContext.render(image,
                        to: buffer,
                        bounds: CGRect(origin: .zero, size: renderSize),
                        colorSpace: CGColorSpaceCreateDeviceRGB())
        
        // Span is read-only in Swift 6, so we need to use a different approach
        // This is a forward-looking iOS 26 feature that isn't fully implemented yet
        // Commenting out for now to fix the build
        // for i in stride(from: 3, to: totalBytes, by: 4) {
        //     pixelSpan[i] = 255
        // }
        
        return buffer
    }
    
    // MutableRawSpan not supported yet - advanced iOS 26 feature
    // @available(iOS 26.0, *)
    // private func createMutableSpanForPixelBuffer(_ pixelBuffer: CVPixelBuffer) -> (span: MutableRawSpan, unlock: () -> Void)? {
    //     guard CVPixelBufferLockBaseAddress(pixelBuffer, []) == kCVReturnSuccess else { return nil }
    //     guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else {
    //         CVPixelBufferUnlockBaseAddress(pixelBuffer, [])
    //         return nil
    //     }
    //     let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
    //     let height = CVPixelBufferGetHeight(pixelBuffer)
    //     let size = bytesPerRow * height
    //     let bufferPointer = UnsafeMutableRawBufferPointer(start: baseAddress, count: size)
    //     let span = MutableRawSpan(unsafeBufferPointer)
    //     let unlock = { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }
    //     return (span, unlock)
    // }
    
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
        frameProcessingTimesCount = 0
        currentQualityLevel = 1.0
        lastPerformanceCheck = 0
    }
    
    private func updateCacheSize() {
        var size: Int64 = 0
        
        if textureCache != nil {
            size += 10 * 1024 * 1024
        }
        
        if pixelBufferPool != nil {
            size += Int64(renderSize.width * renderSize.height * 4 * 3)
        }
        
        cacheSize = size
    }
    
    deinit {
    }
    
    func flushBufferPool() {
        if let pool = pixelBufferPool {
            CVPixelBufferPoolFlush(pool, .excessBuffers)
        }
        updateCacheSize()
    }
}

// Cache owner extension - temporarily disabled for build
// Cache owner extension - temporarily disabled for build
// @available(iOS 17.0, *)
// extension FrameCompositor: CacheOwner {
//     func clearCache(type: CacheClearType) {
//         switch type {
//         case .nonEssential:
//             if let pool = pixelBufferPool {
//                 CVPixelBufferPoolFlush(pool, .excessBuffers)
//             }
//             if let cache = textureCache {
//                 CVMetalTextureCacheFlush(cache, 0)
//             }
//         case .all:
//             if let pool = pixelBufferPool {
//                 CVPixelBufferPoolFlush(pool, .excessBuffers)
//             }
//             if let cache = textureCache {
//                 CVMetalTextureCacheFlush(cache, 0)
//             }
//             resetPerformanceMetrics()
//         }
//         updateCacheSize()
//     }
//     
//     func getCacheSize() -> Int64 {
//         return cacheSize
//     }
//     
//     func getCacheName() -> String {
//         return "FrameCompositor-\(poolIdentifier)"
//     }
// }

