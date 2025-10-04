import Foundation
import Metal
import MetalKit
import UIKit
import QuartzCore
import os.signpost

@available(iOS 15.0, *)
class MetalGlassRenderer {
    
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let library: MTLLibrary
    
    private var kawaseDownPipeline: MTLComputePipelineState?
    private var kawaseUpPipeline: MTLComputePipelineState?
    private var glassRenderPipeline: MTLRenderPipelineState?
    
    private var samplerState: MTLSamplerState?
    
    private var texturePyramid: [MTLTexture] = []
    private var pyramidLevels: Int = 5
    
    private var backdropTexture: MTLTexture?
    private var currentSize: CGSize = .zero
    
    private var displayLink: CADisplayLink?
    private weak var targetLayer: CAMetalLayer?
    private weak var backdropView: UIView?
    
    private var cachedBackdropTexture: MTLTexture?
    private var backdropViewHash: Int = 0
    private var framesSinceBackdropUpdate: Int = 0
    private var backdropCacheInterval: Int = 10
    private var isBackdropStatic: Bool = false
    private let signpostLog = OSLog(subsystem: "com.dualcamera.app", category: "MetalGlassRenderer")
    private var lastFrameTime: CFTimeInterval = 0
    
    // Cache tracking
    private var cacheSize: Int64 = 0
    
    var blurRadius: Float = 8.0
    var fresnelStrength: Float = 0.3
    var tintColor: SIMD4<Float> = SIMD4<Float>(0.2, 0.5, 1.0, 1.0)
    var ior: Float = 1.45
    
    func setTintColor(_ color: UIColor) {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        
        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        tintColor = SIMD4<Float>(Float(red), Float(green), Float(blue), Float(alpha))
    }
    
    struct KawaseParams {
        var texelSize: SIMD2<Float>
        var offset: Float
        var padding: Float
    }
    
    struct FresnelParams {
        var fresnelStrength: Float
        var ior: Float
        var tintColor: SIMD4<Float>
        var blurIntensity: Float
    }
    
    init?(device: MTLDevice) {
        self.device = device
        
        guard let queue = device.makeCommandQueue() else {
            return nil
        }
        self.commandQueue = queue
        
        guard let defaultLibrary = device.makeDefaultLibrary() else {
            return nil
        }
        self.library = defaultLibrary
        
        setupPipelines()
        setupSamplerState()
        
        // Register with MemoryTracker if available
        if #available(iOS 17.0, *) {
            ModernMemoryManager.shared.registerCacheOwner(self)
        }
    }
    
    private func setupPipelines() {
        do {
            if let kawaseDownFunction = library.makeFunction(name: "kawaseDown") {
                kawaseDownPipeline = try device.makeComputePipelineState(function: kawaseDownFunction)
            }
            
            if let kawaseUpFunction = library.makeFunction(name: "kawaseUp") {
                kawaseUpPipeline = try device.makeComputePipelineState(function: kawaseUpFunction)
            }
            
            let renderPipelineDescriptor = MTLRenderPipelineDescriptor()
            renderPipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
            
            if let vertexFunction = library.makeFunction(name: "vertexGlass"),
               let fragmentFunction = library.makeFunction(name: "fragmentGlass") {
                renderPipelineDescriptor.vertexFunction = vertexFunction
                renderPipelineDescriptor.fragmentFunction = fragmentFunction
                glassRenderPipeline = try device.makeRenderPipelineState(descriptor: renderPipelineDescriptor)
            }
        } catch {
            print("Failed to create pipelines: \(error)")
        }
    }
    
    private func setupSamplerState() {
        let samplerDescriptor = MTLSamplerDescriptor()
        samplerDescriptor.minFilter = .linear
        samplerDescriptor.magFilter = .linear
        samplerDescriptor.sAddressMode = .clampToEdge
        samplerDescriptor.tAddressMode = .clampToEdge
        samplerState = device.makeSamplerState(descriptor: samplerDescriptor)
    }
    
    private func calculateBackdropHash(view: UIView) -> Int {
        var hasher = Hasher()
        hasher.combine(view.bounds)
        hasher.combine(view.transform.a)
        hasher.combine(view.transform.b)
        hasher.combine(view.transform.c)
        hasher.combine(view.transform.d)
        hasher.combine(view.transform.tx)
        hasher.combine(view.transform.ty)
        hasher.combine(view.subviews.count)
        return hasher.finalize()
    }
    
    private func shouldUpdateBackdrop(view: UIView) -> Bool {
        let currentHash = calculateBackdropHash(view: view)
        if currentHash != backdropViewHash {
            backdropViewHash = currentHash
            framesSinceBackdropUpdate = 0
            return true
        }
        framesSinceBackdropUpdate += 1
        if framesSinceBackdropUpdate >= backdropCacheInterval {
            framesSinceBackdropUpdate = 0
            return true
        }
        return false
    }
    
    func createTexturePyramid(size: CGSize, numLevels: Int) {
        texturePyramid.removeAll()
        
        var currentWidth = Int(size.width)
        var currentHeight = Int(size.height)
        
        for _ in 0..<numLevels {
            let descriptor = MTLTextureDescriptor.texture2DDescriptor(
                pixelFormat: .rgba16Float,
                width: max(1, currentWidth),
                height: max(1, currentHeight),
                mipmapped: false
            )
            descriptor.usage = [.shaderRead, .shaderWrite]
            descriptor.storageMode = .private
            
            if #available(iOS 17.0, *) {
                if let texture = device.makeTexture(descriptor: descriptor) {
                    texturePyramid.append(texture)
                }
            } else {
                if let texture = device.makeTexture(descriptor: descriptor) {
                    texturePyramid.append(texture)
                }
            }
            
            currentWidth /= 2
            currentHeight /= 2
        }
        
        updateCacheSize()
    }
    
    func captureBackdrop(from view: UIView) -> MTLTexture? {
        let signpostID = OSSignpostID(log: signpostLog)
        os_signpost(.begin, log: signpostLog, name: "Backdrop Capture", signpostID: signpostID)
        
        let scale = UIScreen.main.scale
        let size = CGSize(width: view.bounds.width * scale, height: view.bounds.height * scale)
        
        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        guard let context = UIGraphicsGetCurrentContext() else {
            UIGraphicsEndImageContext()
            os_signpost(.end, log: signpostLog, name: "Backdrop Capture", signpostID: signpostID)
            return nil
        }
        
        view.drawHierarchy(in: view.bounds, afterScreenUpdates: false)
        
        guard let image = UIGraphicsGetImageFromCurrentImageContext(),
              let cgImage = image.cgImage else {
            UIGraphicsEndImageContext()
            os_signpost(.end, log: signpostLog, name: "Backdrop Capture", signpostID: signpostID)
            return nil
        }
        
        UIGraphicsEndImageContext()
        
        let textureLoader = MTKTextureLoader(device: device)
        let texture = try? textureLoader.newTexture(cgImage: cgImage, options: [
            .textureUsage: NSNumber(value: MTLTextureUsage.shaderRead.rawValue),
            .textureStorageMode: NSNumber(value: MTLStorageMode.private.rawValue)
        ])
        
        os_signpost(.end, log: signpostLog, name: "Backdrop Capture", signpostID: signpostID)
        return texture
    }
    
    func encodeBlurPasses(commandBuffer: MTLCommandBuffer, sourceTexture: MTLTexture) {
        let signpostID = OSSignpostID(log: signpostLog)
        os_signpost(.begin, log: signpostLog, name: "Blur Passes", signpostID: signpostID)
        
        guard let kawaseDown = kawaseDownPipeline,
              let kawaseUp = kawaseUpPipeline,
              !texturePyramid.isEmpty else {
            os_signpost(.end, log: signpostLog, name: "Blur Passes", signpostID: signpostID)
            return
        }
        
        let threadgroupSize = MTLSize(width: 16, height: 16, depth: 1)
        
        for level in 0..<texturePyramid.count {
            guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
                continue
            }
            
            encoder.setComputePipelineState(kawaseDown)
            
            let inputTexture = level == 0 ? sourceTexture : texturePyramid[level - 1]
            let outputTexture = texturePyramid[level]
            
            encoder.setTexture(inputTexture, index: 0)
            encoder.setTexture(outputTexture, index: 1)
            
            var params = KawaseParams(
                texelSize: SIMD2<Float>(1.0 / Float(inputTexture.width), 1.0 / Float(inputTexture.height)),
                offset: Float(level) * 0.5,
                padding: 0.0
            )
            encoder.setBytes(&params, length: MemoryLayout<KawaseParams>.stride, index: 0)
            
            if let sampler = samplerState {
                encoder.setSamplerState(sampler, index: 0)
            }
            
            let threadgroupsPerGrid = MTLSize(
                width: (outputTexture.width + threadgroupSize.width - 1) / threadgroupSize.width,
                height: (outputTexture.height + threadgroupSize.height - 1) / threadgroupSize.height,
                depth: 1
            )
            
            encoder.dispatchThreadgroups(threadgroupsPerGrid, threadsPerThreadgroup: threadgroupSize)
            encoder.endEncoding()
        }
        
        for level in stride(from: texturePyramid.count - 2, through: 0, by: -1) {
            guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
                continue
            }
            
            encoder.setComputePipelineState(kawaseUp)
            
            let inputTexture = texturePyramid[level + 1]
            let outputTexture = texturePyramid[level]
            
            encoder.setTexture(inputTexture, index: 0)
            encoder.setTexture(outputTexture, index: 1)
            
            var params = KawaseParams(
                texelSize: SIMD2<Float>(1.0 / Float(inputTexture.width), 1.0 / Float(inputTexture.height)),
                offset: Float(level) * 0.5,
                padding: 0.0
            )
            encoder.setBytes(&params, length: MemoryLayout<KawaseParams>.stride, index: 0)
            
            if let sampler = samplerState {
                encoder.setSamplerState(sampler, index: 0)
            }
            
            let threadgroupsPerGrid = MTLSize(
                width: (outputTexture.width + threadgroupSize.width - 1) / threadgroupSize.width,
                height: (outputTexture.height + threadgroupSize.height - 1) / threadgroupSize.height,
                depth: 1
            )
            
            encoder.dispatchThreadgroups(threadgroupsPerGrid, threadsPerThreadgroup: threadgroupSize)
            encoder.endEncoding()
        }
        
        os_signpost(.end, log: signpostLog, name: "Blur Passes", signpostID: signpostID)
    }
    
    func encodeGlassComposition(commandBuffer: MTLCommandBuffer, drawable: CAMetalDrawable) {
        let signpostID = OSSignpostID(log: signpostLog)
        os_signpost(.begin, log: signpostLog, name: "Glass Composition", signpostID: signpostID)
        guard let renderPipeline = glassRenderPipeline,
              let backdropTexture = backdropTexture,
              !texturePyramid.isEmpty else {
            os_signpost(.end, log: signpostLog, name: "Glass Composition", signpostID: signpostID)
            return
        }
        
        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = drawable.texture
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        renderPassDescriptor.colorAttachments[0].storeAction = .store
        
        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            return
        }
        
        encoder.setRenderPipelineState(renderPipeline)
        
        encoder.setFragmentTexture(backdropTexture, index: 0)
        encoder.setFragmentTexture(texturePyramid[0], index: 1)
        
        var fresnelParams = FresnelParams(
            fresnelStrength: fresnelStrength,
            ior: ior,
            tintColor: tintColor,
            blurIntensity: blurRadius / 16.0
        )
        encoder.setFragmentBytes(&fresnelParams, length: MemoryLayout<FresnelParams>.stride, index: 0)
        
        if let sampler = samplerState {
            encoder.setFragmentSamplerState(sampler, index: 0)
        }
        
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
        encoder.endEncoding()
        
        os_signpost(.end, log: signpostLog, name: "Glass Composition", signpostID: signpostID)
    }
    
    func render(to layer: CAMetalLayer, backdropView: UIView) {
        let signpostID = OSSignpostID(log: signpostLog)
        os_signpost(.begin, log: signpostLog, name: "Full Render", signpostID: signpostID)
        let layerSize = layer.drawableSize
        let size = CGSize(width: layerSize.width, height: layerSize.height)
        
        if size != currentSize || texturePyramid.isEmpty {
            currentSize = size
            createTexturePyramid(size: size, numLevels: pyramidLevels)
        }
        
        if shouldUpdateBackdrop(view: backdropView) {
            backdropTexture = captureBackdrop(from: backdropView)
            cachedBackdropTexture = backdropTexture
        } else {
            backdropTexture = cachedBackdropTexture
        }
        
        guard let drawable = layer.nextDrawable(),
              let commandBuffer = commandQueue.makeCommandBuffer(),
              let sourceTexture = backdropTexture else {
            os_signpost(.end, log: signpostLog, name: "Full Render", signpostID: signpostID)
            return
        }
        
        encodeBlurPasses(commandBuffer: commandBuffer, sourceTexture: sourceTexture)
        encodeGlassComposition(commandBuffer: commandBuffer, drawable: drawable)
        
        commandBuffer.present(drawable)
        commandBuffer.commit()
        
        os_signpost(.end, log: signpostLog, name: "Full Render", signpostID: signpostID)
    }
    
    func setBackdropStatic(_ isStatic: Bool) {
        self.isBackdropStatic = isStatic
        backdropCacheInterval = isStatic ? Int.max : 10
    }
    
    func invalidateBackdropCache() {
        cachedBackdropTexture = nil
        backdropViewHash = 0
        framesSinceBackdropUpdate = 0
    }
    
    func startRendering(layer: CAMetalLayer, backdropView: UIView) {
        targetLayer = layer
        self.backdropView = backdropView
        
        displayLink?.invalidate()
        displayLink = CADisplayLink(target: self, selector: #selector(displayLinkUpdate))
        displayLink?.preferredFrameRateRange = CAFrameRateRange(minimum: 60, maximum: 120, preferred: 60)
        displayLink?.add(to: .main, forMode: .common)
    }
    
    @objc private func displayLinkUpdate() {
        guard let layer = targetLayer, let backdropView = backdropView else {
            stopRendering()
            return
        }
        
        let currentTime = CACurrentMediaTime()
        let delta = currentTime - lastFrameTime
        lastFrameTime = currentTime
        if delta > 1.0/60.0 {
            os_signpost(.event, log: signpostLog, name: "Slow Frame", "Delta: %.2fms", delta * 1000)
        }
        
        render(to: layer, backdropView: backdropView)
    }
    
    func stopRendering() {
        displayLink?.invalidate()
        displayLink = nil
        targetLayer = nil
        backdropView = nil
    }
    
    static func isMetalRenderingAvailable() -> Bool {
        guard MTLCreateSystemDefaultDevice() != nil else {
            return false
        }
        
        if UIAccessibility.isReduceTransparencyEnabled {
            return false
        }
        
        return true
    }
    
    private func updateCacheSize() {
        var size: Int64 = 0
        
        for texture in texturePyramid {
            let bytesPerPixel = 8
            size += Int64(texture.width * texture.height * bytesPerPixel)
        }
        
        if let backdrop = backdropTexture {
            size += Int64(backdrop.width * backdrop.height * 4)
        }
        
        cacheSize = size
    }
    
    deinit {
        if #available(iOS 17.0, *) {
            ModernMemoryManager.shared.unregisterCacheOwner(self)
        }
        
        stopRendering()
        texturePyramid.removeAll()
        backdropTexture = nil
    }
}

@available(iOS 17.0, *)
extension MetalGlassRenderer: CacheOwner {
    func clearCache(type: CacheClearType) {
        switch type {
        case .nonEssential:
            invalidateBackdropCache()
        case .all:
            invalidateBackdropCache()
            texturePyramid.removeAll()
            backdropTexture = nil
        }
        updateCacheSize()
    }
    
    func getCacheSize() -> Int64 {
        return cacheSize
    }
    
    func getCacheName() -> String {
        return "MetalGlassRenderer"
    }
}
