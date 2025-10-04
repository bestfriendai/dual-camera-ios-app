//
//  AudioProcessor.swift
//  DualApp
//
//  Created by DualApp Team on 10/3/25.
//

import Foundation
import AVFoundation
import Accelerate

// MARK: - Audio Processor Actor

actor AudioProcessor: Sendable {
    // MARK: - State Properties
    
    private(set) var currentConfiguration: AudioConfiguration
    private(set) var currentLatency: TimeInterval = 0.0
    private(set) var processingEnabled = false
    private(set) var processingLoad: Float = 0.0
    
    // MARK: - Processing Components
    
    private let noiseReducer: NoiseReducer
    private let audioEnhancer: AudioEnhancer
    private let spatialProcessor: SpatialAudioProcessor
    private let equalizer: AudioEqualizer
    private let compressor: AudioCompressor
    private let limiter: AudioLimiter
    
    // MARK: - Audio Units
    
    private var noiseReductionUnit: AUAudioUnit?
    private var enhancementUnit: AUAudioUnit?
    private var spatialUnit: AUAudioUnit?
    private var equalizerUnit: AUAudioUnit?
    private var compressorUnit: AUAudioUnit?
    private var limiterUnit: AUAudioUnit?
    
    // MARK: - Processing Chain
    
    private var processingChain: [AudioProcessingNode] = []
    private var processingBuffer: AVAudioPCMBuffer?
    private var processingQueue: DispatchQueue
    
    // MARK: - Performance Monitoring
    
    private var processingMetrics: AudioProcessingMetrics
    private var lastProcessingTime: TimeInterval = 0.0
    private var processingTimeHistory: [TimeInterval] = []
    
    // MARK: - Initialization
    
    init(configuration: AudioConfiguration = .default) {
        self.currentConfiguration = configuration
        self.noiseReducer = NoiseReducer()
        self.audioEnhancer = AudioEnhancer()
        self.spatialProcessor = SpatialAudioProcessor()
        self.equalizer = AudioEqualizer()
        self.compressor = AudioCompressor()
        self.limiter = AudioLimiter()
        self.processingQueue = DispatchQueue(label: "audio.processing", qos: .userInteractive)
        self.processingMetrics = AudioProcessingMetrics()
        
        Task {
            await setupProcessingChain()
        }
    }
    
    // MARK: - Public Interface
    
    func updateConfiguration(_ config: AudioConfiguration) async throws {
        currentConfiguration = config
        
        // Reconfigure processing chain
        await teardownProcessingChain()
        try await setupProcessingChain()
    }
    
    func processBuffer(_ buffer: AVAudioPCMBuffer) async -> AVAudioPCMBuffer {
        guard processingEnabled else { return buffer }
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        var processedBuffer = buffer
        
        // Apply processing chain
        for node in processingChain {
            processedBuffer = await node.process(processedBuffer)
        }
        
        // Update performance metrics
        let processingTime = CFAbsoluteTimeGetCurrent() - startTime
        await updateProcessingMetrics(processingTime)
        
        return processedBuffer
    }
    
    func enableProcessing(_ enabled: Bool) async {
        processingEnabled = enabled
        
        if enabled {
            await startProcessing()
        } else {
            await stopProcessing()
        }
    }
    
    func getProcessingMetrics() async -> AudioProcessingMetrics {
        return AudioProcessingMetrics(
            currentLatency: currentLatency,
            noiseReductionEnabled: currentConfiguration.enableNoiseReduction,
            spatialAudioEnabled: currentConfiguration.enableSpatialAudio,
            processingLoad: processingLoad,
            qualityMetrics: await calculateQualityMetrics()
        )
    }
    
    func setEqualizerPreset(_ preset: EqualizerPreset) async {
        await equalizer.setPreset(preset)
    }
    
    func setEqualizerBand(_ band: EqualizerBand, gain: Float) async {
        await equalizer.setBand(band, gain: gain)
    }
    
    func setCompressorSettings(_ settings: CompressorSettings) async {
        await compressor.setSettings(settings)
    }
    
    func setLimiterSettings(_ settings: LimiterSettings) async {
        await limiter.setSettings(settings)
    }
    
    func setNoiseReductionLevel(_ level: Float) async {
        await noiseReducer.setReductionLevel(level)
    }
    
    func setSpatialMode(_ mode: SpatialMode) async {
        await spatialProcessor.setMode(mode)
    }
    
    func enableRealTimeEffects(_ effects: [RealTimeEffect]) async {
        // Enable specific real-time effects
        for effect in effects {
            switch effect {
            case .noiseReduction:
                await noiseReducer.setEnabled(true)
            case .spatialAudio:
                await spatialProcessor.setEnabled(true)
            case .equalizer:
                await equalizer.setEnabled(true)
            case .compression:
                await compressor.setEnabled(true)
            case .limiting:
                await limiter.setEnabled(true)
            case .enhancement:
                await audioEnhancer.setEnabled(true)
            }
        }
    }
    
    func disableRealTimeEffects(_ effects: [RealTimeEffect]) async {
        // Disable specific real-time effects
        for effect in effects {
            switch effect {
            case .noiseReduction:
                await noiseReducer.setEnabled(false)
            case .spatialAudio:
                await spatialProcessor.setEnabled(false)
            case .equalizer:
                await equalizer.setEnabled(false)
            case .compression:
                await compressor.setEnabled(false)
            case .limiting:
                await limiter.setEnabled(false)
            case .enhancement:
                await audioEnhancer.setEnabled(false)
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func setupProcessingChain() async throws {
        processingChain.removeAll()
        
        // Build processing chain based on configuration
        if currentConfiguration.enableNoiseReduction {
            processingChain.append(noiseReducer)
            noiseReductionUnit = try await noiseReducer.createAudioUnit()
        }
        
        // Always add enhancer for basic audio improvement
        processingChain.append(audioEnhancer)
        enhancementUnit = try await audioEnhancer.createAudioUnit()
        
        // Add equalizer
        processingChain.append(equalizer)
        equalizerUnit = try await equalizer.createAudioUnit()
        
        // Add compressor
        processingChain.append(compressor)
        compressorUnit = try await compressor.createAudioUnit()
        
        // Add limiter
        processingChain.append(limiter)
        limiterUnit = try await limiter.createAudioUnit()
        
        // Add spatial processing if enabled
        if currentConfiguration.enableSpatialAudio {
            processingChain.append(spatialProcessor)
            spatialUnit = try await spatialProcessor.createAudioUnit()
        }
        
        await calculateLatency()
    }
    
    private func teardownProcessingChain() async {
        noiseReductionUnit = nil
        enhancementUnit = nil
        spatialUnit = nil
        equalizerUnit = nil
        compressorUnit = nil
        limiterUnit = nil
        processingChain.removeAll()
    }
    
    private func startProcessing() async {
        // Start all processing units
        noiseReductionUnit?.start()
        enhancementUnit?.start()
        spatialUnit?.start()
        equalizerUnit?.start()
        compressorUnit?.start()
        limiterUnit?.start()
    }
    
    private func stopProcessing() async {
        // Stop all processing units
        noiseReductionUnit?.stop()
        enhancementUnit?.stop()
        spatialUnit?.stop()
        equalizerUnit?.stop()
        compressorUnit?.stop()
        limiterUnit?.stop()
    }
    
    private func calculateLatency() async {
        var totalLatency: TimeInterval = 0.0
        
        if let unit = noiseReductionUnit {
            totalLatency += unit.latency
        }
        
        if let unit = enhancementUnit {
            totalLatency += unit.latency
        }
        
        if let unit = equalizerUnit {
            totalLatency += unit.latency
        }
        
        if let unit = compressorUnit {
            totalLatency += unit.latency
        }
        
        if let unit = limiterUnit {
            totalLatency += unit.latency
        }
        
        if let unit = spatialUnit {
            totalLatency += unit.latency
        }
        
        currentLatency = totalLatency
    }
    
    private func updateProcessingMetrics(_ processingTime: TimeInterval) async {
        lastProcessingTime = processingTime
        processingTimeHistory.append(processingTime)
        
        // Keep only last 100 measurements
        if processingTimeHistory.count > 100 {
            processingTimeHistory.removeFirst()
        }
        
        // Calculate processing load
        let averageProcessingTime = processingTimeHistory.reduce(0, +) / Double(processingTimeHistory.count)
        let bufferDuration = 1.0 / currentConfiguration.sampleRate * Double(currentConfiguration.bufferSize)
        processingLoad = Float(averageProcessingTime / bufferDuration)
    }
    
    private func calculateQualityMetrics() async -> AudioQualityMetrics {
        return AudioQualityMetrics(
            signalToNoiseRatio: await calculateSNR(),
            totalHarmonicDistortion: await calculateTHD(),
            dynamicRange: await calculateDynamicRange(),
            frequencyResponse: await calculateFrequencyResponse()
        )
    }
    
    private func calculateSNR() async -> Float {
        // Calculate signal-to-noise ratio
        return 60.0 // dB - placeholder
    }
    
    private func calculateTHD() async -> Float {
        // Calculate total harmonic distortion
        return 0.01 // 1% - placeholder
    }
    
    private func calculateDynamicRange() async -> Float {
        // Calculate dynamic range
        return 96.0 // dB - placeholder
    }
    
    private func calculateFrequencyResponse() async -> [Float] {
        // Calculate frequency response
        return Array(repeating: 1.0, count: 10) // Flat response - placeholder
    }
}

// MARK: - Audio Processing Node Protocol

protocol AudioProcessingNode: Actor {
    func process(_ buffer: AVAudioPCMBuffer) async -> AVAudioPCMBuffer
    func setEnabled(_ enabled: Bool) async
    func createAudioUnit() async throws -> AUAudioUnit
}

// MARK: - Noise Reducer

actor NoiseReducer: AudioProcessingNode {
    private var reductionLevel: Float = 0.7
    private var adaptiveMode: Bool = true
    private var enabled: Bool = true
    private var noiseProfile: NoiseProfile = NoiseProfile()
    
    func process(_ buffer: AVAudioPCMBuffer) async -> AVAudioPCMBuffer {
        guard enabled else { return buffer }
        
        return await applyNoiseReduction(buffer)
    }
    
    func setEnabled(_ enabled: Bool) async {
        self.enabled = enabled
    }
    
    func createAudioUnit() async throws -> AUAudioUnit {
        let componentDescription = AudioComponentDescription(
            componentType: kAudioUnitType_Effect,
            componentSubType: kAudioUnitSubType_NoiseReduction,
            componentManufacturer: kAudioUnitManufacturer_Apple,
            componentFlags: 0,
            componentFlagsMask: 0
        )
        
        return try AUAudioUnit(componentDescription: componentDescription)
    }
    
    func setReductionLevel(_ level: Float) async {
        reductionLevel = max(0.0, min(1.0, level))
    }
    
    private func applyNoiseReduction(_ buffer: AVAudioPCMBuffer) async -> AVAudioPCMBuffer {
        guard let channelData = buffer.floatChannelData else { return buffer }
        
        let frameLength = Int(buffer.frameLength)
        let processedBuffer = AVAudioPCMBuffer(
            pcmFormat: buffer.format,
            frameCapacity: buffer.frameCapacity
        )!
        
        guard let processedChannelData = processedBuffer.floatChannelData else { return buffer }
        
        processedBuffer.frameLength = buffer.frameLength
        
        // Apply spectral subtraction
        await applySpectralSubtraction(
            input: channelData[0],
            output: processedChannelData[0],
            frameLength: frameLength
        )
        
        return processedBuffer
    }
    
    private func applySpectralSubtraction(
        input: UnsafePointer<Float>,
        output: UnsafeMutablePointer<Float>,
        frameLength: Int
    ) async {
        // Implement spectral subtraction algorithm
        for i in 0..<frameLength {
            let sample = input[i]
            let magnitude = abs(sample)
            
            // Apply reduction based on noise floor
            let noiseFloor = noiseProfile.noiseFloor
            let reductionFactor = max(0.0, 1.0 - (noiseFloor / max(magnitude, noiseFloor)))
            let adjustedReduction = reductionFactor * reductionLevel
            
            output[i] = sample * adjustedReduction
        }
    }
}

// MARK: - Audio Enhancer

actor AudioEnhancer: AudioProcessingNode {
    private var enabled: Bool = true
    private var enhancementLevel: Float = 0.3
    
    func process(_ buffer: AVAudioPCMBuffer) async -> AVAudioPCMBuffer {
        guard enabled else { return buffer }
        
        return await applyEnhancement(buffer)
    }
    
    func setEnabled(_ enabled: Bool) async {
        self.enabled = enabled
    }
    
    func createAudioUnit() async throws -> AUAudioUnit {
        let componentDescription = AudioComponentDescription(
            componentType: kAudioUnitType_Effect,
            componentSubType: kAudioUnitSubType_Distortion,
            componentManufacturer: kAudioUnitManufacturer_Apple,
            componentFlags: 0,
            componentFlagsMask: 0
        )
        
        return try AUAudioUnit(componentDescription: componentDescription)
    }
    
    private func applyEnhancement(_ buffer: AVAudioPCMBuffer) async -> AVAudioPCMBuffer {
        guard let channelData = buffer.floatChannelData else { return buffer }
        
        let frameLength = Int(buffer.frameLength)
        let processedBuffer = AVAudioPCMBuffer(
            pcmFormat: buffer.format,
            frameCapacity: buffer.frameCapacity
        )!
        
        guard let processedChannelData = processedBuffer.floatChannelData else { return buffer }
        
        processedBuffer.frameLength = buffer.frameLength
        
        // Apply gentle enhancement
        for i in 0..<frameLength {
            let sample = channelData[0][i]
            processedChannelData[0][i] = sample * (1.0 + enhancementLevel * 0.1)
        }
        
        return processedBuffer
    }
}

// MARK: - Spatial Audio Processor

actor SpatialAudioProcessor: AudioProcessingNode {
    private var spatialMode: SpatialMode = .stereo
    private var enabled: Bool = true
    private var trackingEnabled: Bool = false
    
    func process(_ buffer: AVAudioPCMBuffer) async -> AVAudioPCMBuffer {
        guard enabled else { return buffer }
        
        return await applySpatialProcessing(buffer)
    }
    
    func setEnabled(_ enabled: Bool) async {
        self.enabled = enabled
    }
    
    func createAudioUnit() async throws -> AUAudioUnit {
        let componentDescription = AudioComponentDescription(
            componentType: kAudioUnitType_Effect,
            componentSubType: kAudioUnitSubType_SpatialAudio,
            componentManufacturer: kAudioUnitManufacturer_Apple,
            componentFlags: 0,
            componentFlagsMask: 0
        )
        
        return try AUAudioUnit(componentDescription: componentDescription)
    }
    
    func setMode(_ mode: SpatialMode) async {
        spatialMode = mode
    }
    
    private func applySpatialProcessing(_ buffer: AVAudioPCMBuffer) async -> AVAudioPCMBuffer {
        guard let channelData = buffer.floatChannelData else { return buffer }
        
        let frameLength = Int(buffer.frameLength)
        let processedBuffer = AVAudioPCMBuffer(
            pcmFormat: buffer.format,
            frameCapacity: buffer.frameCapacity
        )!
        
        guard let processedChannelData = processedBuffer.floatChannelData else { return buffer }
        
        processedBuffer.frameLength = buffer.frameLength
        
        // Apply spatial processing based on mode
        switch spatialMode {
        case .stereo:
            // Pass through for stereo
            processedChannelData[0] = channelData[0]
            if buffer.format.channelCount > 1 {
                processedChannelData[1] = channelData[1]
            }
        case .binaural:
            await applyBinauralProcessing(
                input: channelData[0],
                output: processedChannelData,
                frameLength: frameLength
            )
        case .surround:
            await applySurroundProcessing(
                input: channelData[0],
                output: processedChannelData,
                frameLength: frameLength
            )
        }
        
        return processedBuffer
    }
    
    private func applyBinauralProcessing(
        input: UnsafePointer<Float>,
        output: UnsafeMutablePointer<Float>,
        frameLength: Int
    ) async {
        // Apply binaural processing with HRTF
        for i in 0..<frameLength {
            let sample = input[i]
            
            // Simple binaural simulation
            let leftDelay = sin(Double(i) * 0.001) * 0.0001
            let rightDelay = cos(Double(i) * 0.001) * 0.0001
            
            output[0] = sample * Float(1.0 + leftDelay)
            if output.count > 1 {
                output[1] = sample * Float(1.0 + rightDelay)
            }
        }
    }
    
    private func applySurroundProcessing(
        input: UnsafePointer<Float>,
        output: UnsafeMutablePointer<Float>,
        frameLength: Int
    ) async {
        // Apply surround processing
        for i in 0..<frameLength {
            let sample = input[i]
            
            // Simple surround simulation
            let centerLevel = 0.7
            let surroundLevel = 0.3
            
            output[0] = sample * Float(centerLevel + surroundLevel * sin(Double(i) * 0.01))
            if output.count > 1 {
                output[1] = sample * Float(centerLevel + surroundLevel * cos(Double(i) * 0.01))
            }
        }
    }
}

// MARK: - Audio Equalizer

actor AudioEqualizer: AudioProcessingNode {
    private var enabled: Bool = true
    private var currentPreset: EqualizerPreset = .flat
    private var bandGains: [EqualizerBand: Float] = [:]
    
    func process(_ buffer: AVAudioPCMBuffer) async -> AVAudioPCMBuffer {
        guard enabled else { return buffer }
        
        return await applyEqualization(buffer)
    }
    
    func setEnabled(_ enabled: Bool) async {
        self.enabled = enabled
    }
    
    func createAudioUnit() async throws -> AUAudioUnit {
        let componentDescription = AudioComponentDescription(
            componentType: kAudioUnitType_Effect,
            componentSubType: kAudioUnitSubType_ParametricEQ,
            componentManufacturer: kAudioUnitManufacturer_Apple,
            componentFlags: 0,
            componentFlagsMask: 0
        )
        
        return try AUAudioUnit(componentDescription: componentDescription)
    }
    
    func setPreset(_ preset: EqualizerPreset) async {
        currentPreset = preset
        bandGains = preset.bandGains
    }
    
    func setBand(_ band: EqualizerBand, gain: Float) async {
        bandGains[band] = max(-12.0, min(12.0, gain))
    }
    
    private func applyEqualization(_ buffer: AVAudioPCMBuffer) async -> AVAudioPCMBuffer {
        guard let channelData = buffer.floatChannelData else { return buffer }
        
        let frameLength = Int(buffer.frameLength)
        let processedBuffer = AVAudioPCMBuffer(
            pcmFormat: buffer.format,
            frameCapacity: buffer.frameCapacity
        )!
        
        guard let processedChannelData = processedBuffer.floatChannelData else { return buffer }
        
        processedBuffer.frameLength = buffer.frameLength
        
        // Apply equalization using simple filters
        for i in 0..<frameLength {
            var sample = channelData[0][i]
            
            // Apply band gains
            for (band, gain) in bandGains {
                sample = applyBandFilter(sample, band: band, gain: gain, index: i)
            }
            
            processedChannelData[0][i] = sample
        }
        
        return processedBuffer
    }
    
    private func applyBandFilter(_ sample: Float, band: EqualizerBand, gain: Float, index: Int) -> Float {
        let frequency = band.frequency
        let q = band.q
        let gainLinear = pow(10.0, gain / 20.0)
        
        // Simple biquad filter implementation
        let omega = 2.0 * .pi * frequency / 44100.0
        let sin = sin(omega)
        let cos = cos(omega)
        let alpha = sin / (2.0 * q)
        
        let b0 = 1.0 + alpha * gainLinear
        let b1 = -2.0 * cos
        let b2 = 1.0 - alpha * gainLinear
        let a0 = 1.0 + alpha
        let a1 = -2.0 * cos
        let a2 = 1.0 - alpha
        
        // Apply filter (simplified)
        return sample * Float(b0 / a0)
    }
}

// MARK: - Audio Compressor

actor AudioCompressor: AudioProcessingNode {
    private var enabled: Bool = true
    private var settings: CompressorSettings = CompressorSettings()
    
    func process(_ buffer: AVAudioPCMBuffer) async -> AVAudioPCMBuffer {
        guard enabled else { return buffer }
        
        return await applyCompression(buffer)
    }
    
    func setEnabled(_ enabled: Bool) async {
        self.enabled = enabled
    }
    
    func createAudioUnit() async throws -> AUAudioUnit {
        let componentDescription = AudioComponentDescription(
            componentType: kAudioUnitType_Effect,
            componentSubType: kAudioUnitSubType_DynamicsProcessor,
            componentManufacturer: kAudioUnitManufacturer_Apple,
            componentFlags: 0,
            componentFlagsMask: 0
        )
        
        return try AUAudioUnit(componentDescription: componentDescription)
    }
    
    func setSettings(_ settings: CompressorSettings) async {
        self.settings = settings
    }
    
    private func applyCompression(_ buffer: AVAudioPCMBuffer) async -> AVAudioPCMBuffer {
        guard let channelData = buffer.floatChannelData else { return buffer }
        
        let frameLength = Int(buffer.frameLength)
        let processedBuffer = AVAudioPCMBuffer(
            pcmFormat: buffer.format,
            frameCapacity: buffer.frameCapacity
        )!
        
        guard let processedChannelData = processedBuffer.floatChannelData else { return buffer }
        
        processedBuffer.frameLength = buffer.frameLength
        
        // Apply compression
        for i in 0..<frameLength {
            let sample = channelData[0][i]
            let compressedSample = applyCompressionToSample(sample)
            processedChannelData[0][i] = compressedSample
        }
        
        return processedBuffer
    }
    
    private func applyCompressionToSample(_ sample: Float) -> Float {
        let absSample = abs(sample)
        let threshold = settings.threshold
        let ratio = settings.ratio
        let attackTime = settings.attackTime
        let releaseTime = settings.releaseTime
        
        // Simple compression algorithm
        if absSample > threshold {
            let gainReduction = (absSample - threshold) * (1.0 - 1.0 / ratio)
            return sample * (1.0 - gainReduction / absSample)
        }
        
        return sample
    }
}

// MARK: - Audio Limiter

actor AudioLimiter: AudioProcessingNode {
    private var enabled: Bool = true
    private var settings: LimiterSettings = LimiterSettings()
    
    func process(_ buffer: AVAudioPCMBuffer) async -> AVAudioPCMBuffer {
        guard enabled else { return buffer }
        
        return await applyLimiting(buffer)
    }
    
    func setEnabled(_ enabled: Bool) async {
        self.enabled = enabled
    }
    
    func createAudioUnit() async throws -> AUAudioUnit {
        let componentDescription = AudioComponentDescription(
            componentType: kAudioUnitType_Effect,
            componentSubType: kAudioUnitSubType_PeakLimiter,
            componentManufacturer: kAudioUnitManufacturer_Apple,
            componentFlags: 0,
            componentFlagsMask: 0
        )
        
        return try AUAudioUnit(componentDescription: componentDescription)
    }
    
    func setSettings(_ settings: LimiterSettings) async {
        self.settings = settings
    }
    
    private func applyLimiting(_ buffer: AVAudioPCMBuffer) async -> AVAudioPCMBuffer {
        guard let channelData = buffer.floatChannelData else { return buffer }
        
        let frameLength = Int(buffer.frameLength)
        let processedBuffer = AVAudioPCMBuffer(
            pcmFormat: buffer.format,
            frameCapacity: buffer.frameCapacity
        )!
        
        guard let processedChannelData = processedBuffer.floatChannelData else { return buffer }
        
        processedBuffer.frameLength = buffer.frameLength
        
        // Apply limiting
        for i in 0..<frameLength {
            let sample = channelData[0][i]
            let limitedSample = applyLimitingToSample(sample)
            processedChannelData[0][i] = limitedSample
        }
        
        return processedBuffer
    }
    
    private func applyLimitingToSample(_ sample: Float) -> Float {
        let threshold = settings.threshold
        let releaseTime = settings.releaseTime
        
        // Simple limiting algorithm
        if abs(sample) > threshold {
            return sample > 0 ? threshold : -threshold
        }
        
        return sample
    }
}

// MARK: - Supporting Types

struct AudioProcessingMetrics: Sendable {
    let currentLatency: TimeInterval
    let noiseReductionEnabled: Bool
    let spatialAudioEnabled: Bool
    let processingLoad: Float
    let qualityMetrics: AudioQualityMetrics
}

struct AudioQualityMetrics: Sendable {
    let signalToNoiseRatio: Float
    let totalHarmonicDistortion: Float
    let dynamicRange: Float
    let frequencyResponse: [Float]
}

struct NoiseProfile: Sendable {
    let noiseFloor: Float
    let frequencyProfile: [Float]
    let temporalProfile: [Float]
    
    init(noiseFloor: Float = -60.0) {
        self.noiseFloor = noiseFloor
        self.frequencyProfile = Array(repeating: noiseFloor, count: 10)
        self.temporalProfile = Array(repeating: noiseFloor, count: 100)
    }
}

enum RealTimeEffect: String, CaseIterable, Sendable {
    case noiseReduction = "noiseReduction"
    case spatialAudio = "spatialAudio"
    case equalizer = "equalizer"
    case compression = "compression"
    case limiting = "limiting"
    case enhancement = "enhancement"
    
    var displayName: String {
        switch self {
        case .noiseReduction:
            return "Noise Reduction"
        case .spatialAudio:
            return "Spatial Audio"
        case .equalizer:
            return "Equalizer"
        case .compression:
            return "Compression"
        case .limiting:
            return "Limiter"
        case .enhancement:
            return "Enhancement"
        }
    }
}

enum EqualizerPreset: String, CaseIterable, Sendable {
    case flat = "flat"
    case vocal = "vocal"
    case music = "music"
    case bass = "bass"
    case treble = "treble"
    case podcast = "podcast"
    
    var displayName: String {
        switch self {
        case .flat:
            return "Flat"
        case .vocal:
            return "Vocal"
        case .music:
            return "Music"
        case .bass:
            return "Bass Boost"
        case .treble:
            return "Treble Boost"
        case .podcast:
            return "Podcast"
        }
    }
    
    var bandGains: [EqualizerBand: Float] {
        switch self {
        case .flat:
            return Dictionary(uniqueKeysWithValues: EqualizerBand.allCases.map { ($0, 0.0) })
        case .vocal:
            return [
                .bass: -2.0,
                .lowMid: 1.0,
                .mid: 3.0,
                .highMid: 2.0,
                .treble: 1.0
            ]
        case .music:
            return [
                .bass: 2.0,
                .lowMid: 1.0,
                .mid: 0.0,
                .highMid: 1.0,
                .treble: 2.0
            ]
        case .bass:
            return [
                .bass: 6.0,
                .lowMid: 3.0,
                .mid: 0.0,
                .highMid: -1.0,
                .treble: -2.0
            ]
        case .treble:
            return [
                .bass: -2.0,
                .lowMid: -1.0,
                .mid: 0.0,
                .highMid: 3.0,
                .treble: 6.0
            ]
        case .podcast:
            return [
                .bass: 1.0,
                .lowMid: 2.0,
                .mid: 3.0,
                .highMid: 1.0,
                .treble: 0.0
            ]
        }
    }
}

enum EqualizerBand: String, CaseIterable, Sendable {
    case bass = "bass"
    case lowMid = "lowMid"
    case mid = "mid"
    case highMid = "highMid"
    case treble = "treble"
    
    var frequency: Double {
        switch self {
        case .bass:
            return 100.0
        case .lowMid:
            return 300.0
        case .mid:
            return 1000.0
        case .highMid:
            return 3000.0
        case .treble:
            return 10000.0
        }
    }
    
    var q: Double {
        switch self {
        case .bass, .treble:
            return 0.7
        case .lowMid, .mid, .highMid:
            return 1.0
        }
    }
    
    var displayName: String {
        switch self {
        case .bass:
            return "Bass"
        case .lowMid:
            return "Low Mid"
        case .mid:
            return "Mid"
        case .highMid:
            return "High Mid"
        case .treble:
            return "Treble"
        }
    }
}

struct CompressorSettings: Sendable {
    let threshold: Float
    let ratio: Float
    let attackTime: Float
    let releaseTime: Float
    let makeupGain: Float
    
    init(
        threshold: Float = -20.0,
        ratio: Float = 4.0,
        attackTime: Float = 0.003,
        releaseTime: Float = 0.1,
        makeupGain: Float = 0.0
    ) {
        self.threshold = threshold
        self.ratio = ratio
        self.attackTime = attackTime
        self.releaseTime = releaseTime
        self.makeupGain = makeupGain
    }
}

struct LimiterSettings: Sendable {
    let threshold: Float
    let releaseTime: Float
    let lookaheadTime: Float
    
    init(
        threshold: Float = -1.0,
        releaseTime: Float = 0.01,
        lookaheadTime: Float = 0.001
    ) {
        self.threshold = threshold
        self.releaseTime = releaseTime
        self.lookaheadTime = lookaheadTime
    }
}

enum SpatialMode: String, CaseIterable, Sendable {
    case stereo = "stereo"
    case binaural = "binaural"
    case surround = "surround"
    
    var displayName: String {
        switch self {
        case .stereo:
            return "Stereo"
        case .binaural:
            return "Binaural"
        case .surround:
            return "Surround"
        }
    }
}