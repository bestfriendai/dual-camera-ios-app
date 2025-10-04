//
//  MetalRenderer.swift
//  DualApp
//
//  Created by DualApp Team on 10/3/25.
//

import Foundation
import Metal
import MetalKit
import AVFoundation
import CoreVideo
import UIKit

// MARK: - Metal Renderer

@MainActor
class MetalRenderer: NSObject, Sendable {
    
    // MARK: - Properties
    
    private let device: MTLDevice
    private var commandQueue: MTLCommandQueue?
    private var renderPipelineState: MTLRenderPipelineState?
    private var computePipelineState: MTLComputePipelineState?
    private var textureCache: CVMetalTextureCache?
    private var library: MTLLibrary?
    
    // MARK: - Render Targets
    
    private var frontTexture: MTLTexture?
    private var backTexture: MTLTexture?
    private var compositeTexture: MTLTexture?
    private var depthTexture: MTLTexture?
    
    // MARK: - Rendering State
    
    private var isInitialized: Bool = false
    private var renderMode: RenderMode = .sideBySide
    private var viewportSize: CGSize = CGSize(width: 1920, height: 1080)
    
    // MARK: - Performance Monitoring
    
    private var frameCount: Int = 0
    private var lastFrameTime: CFTimeInterval = 0
    private var averageFrameTime: CFTimeInterval = 0
    
    // MARK: - Effects and Filters
    
    private var currentFilter: RenderFilter = .none
    private var colorConversionMatrix: simd_float4x4 = matrix_identity_float4x4
    private var brightness: Float = 1.0
    private var contrast: Float = 1.0
    private var saturation: Float = 1.0
    
    // MARK: - Synchronization
    
    private let renderLock = NSLock()
    private var frontFrameBuffer: CVPixelBuffer?
    private var backFrameBuffer: CVPixelBuffer?
    
    // MARK: - Initialization
    
    init(device: MTLDevice) {
        self.device = device
        super.init()
    }
    
    // MARK: - Public Interface
    
    func initialize() async throws {
        guard !isInitialized else { return }
        
        // Create command queue
        commandQueue = device.makeCommandQueue()
        guard commandQueue != nil else {
            throw MetalError.commandQueueCreationFailed
        }
        
        // Create texture cache
        let result = CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, device, nil, &textureCache)
        guard result == kCVReturnSuccess else {
            throw MetalError.textureCacheCreationFailed
        }
        
        // Load shader library
        library = device.makeDefaultLibrary()
        guard library != nil else {
            throw MetalError.libraryCreationFailed
        }
        
        // Create render pipeline
        try await createRenderPipeline()
        
        // Create compute pipeline
        try await createComputePipeline()
        
        // Create render targets
        try await createRenderTargets()
        
        // Initialize color conversion matrix
        setupColorConversionMatrix()
        
        isInitialized = true
    }
    
    func renderFrame(_ frame: DualCameraFrame, to view: MTKView) async throws {
        guard isInitialized else {
            throw MetalError.notInitialized
        }
        
        renderLock.lock()
        defer { renderLock.unlock() }
        
        // Update frame buffer
        switch frame.position {
        case .front:
            frontFrameBuffer = frame.pixelBuffer
        case .back:
            backFrameBuffer = frame.pixelBuffer
        default:
            break
        }
        
        // Render if both frames are available
        if frontFrameBuffer != nil && backFrameBuffer != nil {
            try await renderCompositeFrame(to: view)
        }
    }
    
    func setRenderMode(_ mode: RenderMode) async {
        renderLock.lock()
        defer { renderLock.unlock() }
        
        renderMode = mode
        await updateRenderPipeline()
    }
    
    func setViewportSize(_ size: CGSize) async {
        renderLock.lock()
        defer { renderLock.unlock() }
        
        viewportSize = size
        await createRenderTargets()
    }
    
    func setFilter(_ filter: RenderFilter) async {
        renderLock.lock()
        defer { renderLock.unlock() }
        
        currentFilter = filter
        await updateRenderPipeline()
    }
    
    func setBrightness(_ brightness: Float) async {
        self.brightness = brightness
    }
    
    func setContrast(_ contrast: Float) async {
        self.contrast = contrast
    }
    
    func setSaturation(_ saturation: Float) async {
        self.saturation = saturation
    }
    
    func getPerformanceMetrics() -> RenderPerformanceMetrics {
        return RenderPerformanceMetrics(
            frameCount: frameCount,
            averageFrameTime: averageFrameTime,
            currentFPS: averageFrameTime > 0 ? 1.0 / averageFrameTime : 0,
            renderMode: renderMode,
            filter: currentFilter
        )
    }
    
    func resetPerformanceMetrics() async {
        frameCount = 0
        lastFrameTime = 0
        averageFrameTime = 0
    }
    
    // MARK: - Private Methods
    
    private func createRenderPipeline() async throws {
        guard let library = library else {
            throw MetalError.libraryNotAvailable
        }
        
        // Create vertex function
        let vertexFunction = library.makeFunction(name: "vertexShader")
        guard vertexFunction != nil else {
            throw MetalError.vertexFunctionNotFound
        }
        
        // Create fragment function
        let fragmentFunction = library.makeFunction(name: "fragmentShader")
        guard fragmentFunction != nil else {
            throw MetalError.fragmentFunctionNotFound
        }
        
        // Create pipeline descriptor
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        pipelineDescriptor.colorAttachments[0].isBlendingEnabled = true
        pipelineDescriptor.colorAttachments[0].rgbBlendOperation = .add
        pipelineDescriptor.colorAttachments[0].alphaBlendOperation = .add
        pipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        pipelineDescriptor.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
        pipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        pipelineDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
        
        // Create pipeline state
        renderPipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
    }
    
    private func createComputePipeline() async throws {
        guard let library = library else {
            throw MetalError.libraryNotAvailable
        }
        
        // Create compute function
        let computeFunction = library.makeFunction(name: "compositeShader")
        guard computeFunction != nil else {
            throw MetalError.computeFunctionNotFound
        }
        
        // Create compute pipeline state
        computePipelineState = try device.makeComputePipelineState(function: computeFunction!)
    }
    
    private func createRenderTargets() async throws {
        let width = Int(viewportSize.width)
        let height = Int(viewportSize.height)
        
        // Create composite texture
        let compositeDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm,
            width: width,
            height: height,
            mipmapped: false
        )
        compositeDescriptor.usage = [.renderTarget, .shaderRead, .shaderWrite]
        compositeTexture = device.makeTexture(descriptor: compositeDescriptor)
        
        // Create depth texture
        let depthDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .depth32Float,
            width: width,
            height: height,
            mipmapped: false
        )
        depthDescriptor.usage = .renderTarget
        depthTexture = device.makeTexture(descriptor: depthDescriptor)
    }
    
    private func renderCompositeFrame(to view: MTKView) async throws {
        guard let commandQueue = commandQueue,
              let commandBuffer = commandQueue.makeCommandBuffer(),
              let compositeTexture = compositeTexture else {
            throw MetalError.renderResourcesNotAvailable
        }
        
        let startTime = CACurrentMediaTime()
        
        // Convert frame buffers to Metal textures
        try await updateMetalTextures()
        
        // Perform composite rendering
        try await performCompositeRendering(commandBuffer: commandBuffer)
        
        // Present to view
        if let drawable = view.currentDrawable {
            commandBuffer.present(drawable)
        }
        
        commandBuffer.commit()
        
        // Update performance metrics
        updatePerformanceMetrics(startTime: startTime)
    }
    
    private func updateMetalTextures() async throws {
        guard let textureCache = textureCache else {
            throw MetalError.textureCacheNotAvailable
        }
        
        // Update front texture
        if let frontBuffer = frontFrameBuffer {
            frontTexture = try createMetalTexture(from: frontBuffer, textureCache: textureCache)
        }
        
        // Update back texture
        if let backBuffer = backFrameBuffer {
            backTexture = try createMetalTexture(from: backBuffer, textureCache: textureCache)
        }
    }
    
    private func createMetalTexture(from pixelBuffer: CVPixelBuffer, textureCache: CVMetalTextureCache) throws -> MTLTexture? {
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        
        var metalTexture: CVMetalTexture?
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
        
        guard result == kCVReturnSuccess, let texture = metalTexture else {
            throw MetalError.textureCreationFailed
        }
        
        return CVMetalTextureGetTexture(texture)
    }
    
    private func performCompositeRendering(commandBuffer: MTLCommandQueue) async throws {
        guard let computePipelineState = computePipelineState,
              let commandBuffer = commandBuffer.makeCommandBuffer(),
              let computeEncoder = commandBuffer.makeComputeCommandEncoder(),
              let frontTexture = frontTexture,
              let backTexture = backTexture,
              let compositeTexture = compositeTexture else {
            throw MetalError.computeResourcesNotAvailable
        }
        
        // Set compute pipeline
        computeEncoder.setComputePipelineState(computePipelineState)
        
        // Set textures
        computeEncoder.setTexture(frontTexture, index: 0)
        computeEncoder.setTexture(backTexture, index: 1)
        computeEncoder.setTexture(compositeTexture, index: 2)
        
        // Set uniforms
        var uniforms = RenderUniforms(
            renderMode: UInt32(renderMode.rawValue),
            brightness: brightness,
            contrast: contrast,
            saturation: saturation,
            colorMatrix: colorConversionMatrix
        )
        
        computeEncoder.setBytes(&uniforms, length: MemoryLayout<RenderUniforms>.size, index: 0)
        
        // Calculate thread group size
        let threadGroupSize = MTLSize(width: 16, height: 16, depth: 1)
        let threadGroups = MTLSize(
            width: (compositeTexture.width + threadGroupSize.width - 1) / threadGroupSize.width,
            height: (compositeTexture.height + threadGroupSize.height - 1) / threadGroupSize.height,
            depth: 1
        )
        
        // Dispatch compute
        computeEncoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupSize)
        computeEncoder.endEncoding()
        
        // Apply post-processing effects if needed
        if currentFilter != .none {
            try await applyPostProcessingEffects(commandBuffer: commandBuffer)
        }
    }
    
    private func applyPostProcessingEffects(commandBuffer: MTLCommandQueue) async throws {
        // Apply filters like blur, sharpen, etc.
        // This would be implemented based on the current filter
    }
    
    private func updateRenderPipeline() async {
        // Update render pipeline based on current render mode and filter
        // This would switch between different shader configurations
    }
    
    private func setupColorConversionMatrix() {
        // Setup YUV to RGB conversion matrix
        colorConversionMatrix = simd_float4x4([
            simd_float4(1.0,  0.0,  1.402, 0.0),
            simd_float4(1.0, -0.344, -0.714, 0.0),
            simd_float4(1.0,  1.772, 0.0,   0.0),
            simd_float4(0.0,  0.0,  0.0,   1.0)
        ])
    }
    
    private func updatePerformanceMetrics(startTime: CFTimeInterval) {
        let frameTime = CACurrentMediaTime() - startTime
        
        if frameCount == 0 {
            averageFrameTime = frameTime
        } else {
            averageFrameTime = (averageFrameTime * 0.9) + (frameTime * 0.1)
        }
        
        frameCount += 1
        lastFrameTime = startTime
    }
}

// MARK: - Supporting Types

enum RenderMode: Int, CaseIterable, Sendable {
    case sideBySide = 0
    case pictureInPicture = 1
    case splitScreen = 2
    case overlay = 3
    case single = 4
    
    var description: String {
        switch self {
        case .sideBySide:
            return "Side by Side"
        case .pictureInPicture:
            return "Picture in Picture"
        case .splitScreen:
            return "Split Screen"
        case .overlay:
            return "Overlay"
        case .single:
            return "Single Camera"
        }
    }
}

enum RenderFilter: Int, CaseIterable, Sendable {
    case none = 0
    case grayscale = 1
    case sepia = 2
    case blur = 3
    case sharpen = 4
    case vintage = 5
    case cool = 6
    case warm = 7
    
    var description: String {
        switch self {
        case .none:
            return "None"
        case .grayscale:
            return "Grayscale"
        case .sepia:
            return "Sepia"
        case .blur:
            return "Blur"
        case .sharpen:
            return "Sharpen"
        case .vintage:
            return "Vintage"
        case .cool:
            return "Cool"
        case .warm:
            return "Warm"
        }
    }
}

struct RenderUniforms: Sendable {
    let renderMode: UInt32
    let brightness: Float
    let contrast: Float
    let saturation: Float
    let colorMatrix: simd_float4x4
}

struct RenderPerformanceMetrics: Sendable {
    let frameCount: Int
    let averageFrameTime: CFTimeInterval
    let currentFPS: Double
    let renderMode: RenderMode
    let filter: RenderFilter
    
    var formattedAverageFrameTime: String {
        return String(format: "%.2f ms", averageFrameTime * 1000)
    }
    
    var formattedFPS: String {
        return String(format: "%.1f fps", currentFPS)
    }
}

enum MetalError: LocalizedError, Sendable {
    case notInitialized
    case commandQueueCreationFailed
    case textureCacheCreationFailed
    case libraryCreationFailed
    case libraryNotAvailable
    case vertexFunctionNotFound
    case fragmentFunctionNotFound
    case computeFunctionNotFound
    case textureCreationFailed
    case textureCacheNotAvailable
    case renderResourcesNotAvailable
    case computeResourcesNotAvailable
    
    var errorDescription: String? {
        switch self {
        case .notInitialized:
            return "Metal renderer is not initialized"
        case .commandQueueCreationFailed:
            return "Failed to create Metal command queue"
        case .textureCacheCreationFailed:
            return "Failed to create Metal texture cache"
        case .libraryCreationFailed:
            return "Failed to create Metal library"
        case .libraryNotAvailable:
            return "Metal library is not available"
        case .vertexFunctionNotFound:
            return "Vertex function not found"
        case .fragmentFunctionNotFound:
            return "Fragment function not found"
        case .computeFunctionNotFound:
            return "Compute function not found"
        case .textureCreationFailed:
            return "Failed to create Metal texture"
        case .textureCacheNotAvailable:
            return "Metal texture cache is not available"
        case .renderResourcesNotAvailable:
            return "Render resources are not available"
        case .computeResourcesNotAvailable:
            return "Compute resources are not available"
        }
    }
}

// MARK: - Metal Shaders (would be in .metal file)

/*
 Metal shader code would be in a separate .metal file:
 
#include <metal_stdlib>
using namespace metal;
 
struct VertexOut {
    float4 position [[position]];
    float2 texCoord;
};
 
vertex VertexOut vertexShader(uint vertexID [[vertex_id]]) {
    VertexOut out;
    
    // Simple triangle strip for fullscreen quad
    float2 positions[6] = {
        float2(-1.0, -1.0),
        float2( 1.0, -1.0),
        float2(-1.0,  1.0),
        float2( 1.0, -1.0),
        float2( 1.0,  1.0),
        float2(-1.0,  1.0)
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
 
fragment float4 fragmentShader(VertexOut in [[stage_in]],
                              texture2d<float> frontTexture [[texture(0)]],
                              texture2d<float> backTexture [[texture(1)]],
                              constant RenderUniforms& uniforms [[buffer(0)]]) {
    constexpr sampler textureSampler(mag_filter::linear, min_filter::linear);
    
    float4 frontColor = frontTexture.sample(textureSampler, in.texCoord);
    float4 backColor = backTexture.sample(textureSampler, in.texCoord);
    
    // Composite based on render mode
    float4 compositeColor;
    
    switch (uniforms.renderMode) {
        case 0: // Side by side
            if (in.texCoord.x < 0.5) {
                compositeColor = frontColor;
            } else {
                compositeColor = backColor;
            }
            break;
            
        case 1: // Picture in picture
            compositeColor = frontColor;
            if (in.texCoord.x > 0.7 && in.texCoord.y > 0.7) {
                float2 pipCoord = (in.texCoord - float2(0.7, 0.7)) * 3.33;
                if (pipCoord.x >= 0.0 && pipCoord.x <= 1.0 && pipCoord.y >= 0.0 && pipCoord.y <= 1.0) {
                    compositeColor = backTexture.sample(textureSampler, pipCoord);
                }
            }
            break;
            
        default:
            compositeColor = mix(frontColor, backColor, 0.5);
            break;
    }
    
    // Apply color adjustments
    compositeColor.rgb *= uniforms.brightness;
    compositeColor.rgb = (compositeColor.rgb - 0.5) * uniforms.contrast + 0.5;
    
    return compositeColor;
}
 
kernel void compositeShader(texture2d<float, access::write> output [[texture(2)]],
                            texture2d<float, access::read> frontTexture [[texture(0)]],
                            texture2d<float, access::read> backTexture [[texture(1)]],
                            constant RenderUniforms& uniforms [[buffer(0)]],
                            uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= output.get_width() || gid.y >= output.get_height()) {
        return;
    }
    
    constexpr sampler textureSampler(mag_filter::linear, min_filter::linear);
    
    float2 texCoord = float2(gid) / float2(output.get_width(), output.get_height());
    float4 frontColor = frontTexture.sample(textureSampler, texCoord);
    float4 backColor = backTexture.sample(textureSampler, texCoord);
    
    // Composite logic here
    float4 compositeColor = mix(frontColor, backColor, 0.5);
    
    output.write(compositeColor, gid);
}
*/