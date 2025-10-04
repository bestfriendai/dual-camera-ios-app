//
//  AdaptiveQualityManager.swift
//  DualApp
//
//  Created by DualApp Team on 10/3/25.
//

import Foundation
import AVFoundation

// MARK: - Adaptive Quality Manager

@MainActor
actor AdaptiveQualityManager: Sendable {
    
    // MARK: - Properties
    
    private var isManaging: Bool = false
    private var managementTask: Task<Void, Never>?
    private var managementInterval: TimeInterval = 2.0
    
    // MARK: - Configuration
    
    private var currentConfiguration: CameraConfiguration?
    private var baseConfiguration: CameraConfiguration?
    private var adaptiveStrategies: [AdaptiveStrategy] = []
    
    // MARK: - Quality Levels
    
    private var qualityLevels: [QualityLevel] = []
    private var currentQualityLevel: QualityLevel?
    
    // MARK: - Performance Monitoring
    
    private var performanceHistory: [PerformanceSnapshot] = []
    private let maxHistorySize: Int = 100
    
    // MARK: - Adaptation State
    
    private var lastAdaptationTime: Date = Date()
    private var adaptationCooldown: TimeInterval = 10.0
    private var adaptationThreshold: Double = 0.8
    
    // MARK: - Event Stream
    
    let events: AsyncStream<AdaptiveQualityEvent>
    private let eventContinuation: AsyncStream<AdaptiveQualityEvent>.Continuation
    
    // MARK: - Initialization
    
    init() {
        (self.events, self.eventContinuation) = AsyncStream<AdaptiveQualityEvent>.makeStream()
        
        // Initialize quality levels
        setupQualityLevels()
        
        // Initialize adaptive strategies
        setupAdaptiveStrategies()
    }
    
    // MARK: - Public Interface
    
    func startManaging() async {
        guard !isManaging else { return }
        
        isManaging = true
        lastAdaptationTime = Date()
        
        // Start management task
        managementTask = Task {
            await managementLoop()
        }
        
        eventContinuation.yield(.managementStarted)
    }
    
    func stopManaging() async {
        isManaging = false
        managementTask?.cancel()
        managementTask = nil
        
        eventContinuation.yield(.managementStopped)
    }
    
    func updateConfiguration(_ configuration: CameraConfiguration) async {
        currentConfiguration = configuration
        
        if baseConfiguration == nil {
            baseConfiguration = configuration
        }
        
        // Update quality levels based on new configuration
        await updateQualityLevels()
        
        eventContinuation.yield(.configurationUpdated(configuration))
    }
    
    func getRecommendedConfiguration() async -> CameraConfiguration? {
        guard let baseConfig = baseConfiguration else { return nil }
        
        let currentPerformance = await getCurrentPerformanceSnapshot()
        let recommendedLevel = determineOptimalQualityLevel(performance: currentPerformance)
        
        return applyQualityLevel(recommendedLevel, to: baseConfig)
    }
    
    func forceQualityAdjustment() async {
        await performQualityAdaptation(force: true)
    }
    
    func setAdaptationThreshold(_ threshold: Double) async {
        adaptationThreshold = max(0.1, min(1.0, threshold))
        eventContinuation.yield(.thresholdChanged(adaptationThreshold))
    }
    
    func setAdaptationCooldown(_ cooldown: TimeInterval) async {
        adaptationCooldown = max(1.0, cooldown)
        eventContinuation.yield(.cooldownChanged(cooldown))
    }
    
    func addAdaptiveStrategy(_ strategy: AdaptiveStrategy) async {
        adaptiveStrategies.append(strategy)
        eventContinuation.yield(.strategyAdded(strategy))
    }
    
    func removeAdaptiveStrategy(_ strategy: AdaptiveStrategy) async {
        adaptiveStrategies.removeAll { $0.id == strategy.id }
        eventContinuation.yield(.strategyRemoved(strategy))
    }
    
    func getCurrentQualityLevel() async -> QualityLevel? {
        return currentQualityLevel
    }
    
    func getAdaptationHistory() async -> [PerformanceSnapshot] {
        return performanceHistory
    }
    
    // MARK: - Private Methods
    
    private func managementLoop() async {
        while isManaging && !Task.isCancelled {
            await performQualityAdaptation()
            try? await Task.sleep(nanoseconds: UInt64(managementInterval * 1_000_000_000))
        }
    }
    
    private func performQualityAdaptation(force: Bool = false) async {
        let currentTime = Date()
        
        // Check cooldown
        if !force && currentTime.timeIntervalSince(lastAdaptationTime) < adaptationCooldown {
            return
        }
        
        // Get current performance snapshot
        let currentPerformance = await getCurrentPerformanceSnapshot()
        performanceHistory.append(currentPerformance)
        
        if performanceHistory.count > maxHistorySize {
            performanceHistory.removeFirst()
        }
        
        // Determine if adaptation is needed
        let shouldAdapt = shouldPerformAdaptation(performance: currentPerformance)
        
        if shouldAdapt || force {
            // Determine optimal quality level
            let recommendedLevel = determineOptimalQualityLevel(performance: currentPerformance)
            
            // Apply quality level if different
            if currentQualityLevel?.id != recommendedLevel.id || force {
                await applyQualityLevelChange(recommendedLevel)
                lastAdaptationTime = currentTime
            }
        }
        
        // Update current quality level
        currentQualityLevel = getCurrentQualityLevelFromConfiguration()
    }
    
    private func shouldPerformAdaptation(performance: PerformanceSnapshot) -> Bool {
        guard let currentLevel = currentQualityLevel else { return true }
        
        // Check if performance is below threshold
        if performance.overallScore < adaptationThreshold {
            return true
        }
        
        // Check if performance is significantly better than current level
        if currentLevel.targetPerformanceScore > 0 && 
           performance.overallScore > currentLevel.targetPerformanceScore + 0.1 {
            return true
        }
        
        // Check individual metrics
        if performance.frameRateEfficiency < 0.8 ||
           performance.memoryUsage > 0.8 ||
           performance.thermalState.rawValue >= ThermalState.serious.rawValue ||
           performance.batteryLevel < 0.2 {
            return true
        }
        
        return false
    }
    
    private func determineOptimalQualityLevel(performance: PerformanceSnapshot) -> QualityLevel {
        var bestLevel = qualityLevels.first!
        var bestScore: Double = -1
        
        for level in qualityLevels {
            let score = calculateQualityLevelScore(level: level, performance: performance)
            if score > bestScore {
                bestScore = score
                bestLevel = level
            }
        }
        
        return bestLevel
    }
    
    private func calculateQualityLevelScore(level: QualityLevel, performance: PerformanceSnapshot) -> Double {
        var score = 0.0
        
        // Performance match score (40%)
        let performanceDiff = abs(performance.overallScore - level.targetPerformanceScore)
        let performanceScore = max(0, 1 - performanceDiff)
        score += performanceScore * 0.4
        
        // Resource usage score (30%)
        let resourceScore = calculateResourceScore(level: level, performance: performance)
        score += resourceScore * 0.3
        
        // Stability score (20%)
        let stabilityScore = calculateStabilityScore(level: level, performance: performance)
        score += stabilityScore * 0.2
        
        // User experience score (10%)
        let experienceScore = calculateExperienceScore(level: level, performance: performance)
        score += experienceScore * 0.1
        
        return score
    }
    
    private func calculateResourceScore(level: QualityLevel, performance: PerformanceSnapshot) -> Double {
        var score = 1.0
        
        // Memory usage
        if performance.memoryUsage > level.maxMemoryUsage {
            score -= (performance.memoryUsage - level.maxMemoryUsage) * 2
        }
        
        // Thermal state
        if performance.thermalState.rawValue > level.maxThermalState.rawValue {
            score -= Double(performance.thermalState.rawValue - level.maxThermalState.rawValue) * 0.2
        }
        
        // Battery usage
        if performance.batteryLevel < level.minBatteryLevel {
            score -= (level.minBatteryLevel - performance.batteryLevel) * 2
        }
        
        return max(0, score)
    }
    
    private func calculateStabilityScore(level: QualityLevel, performance: PerformanceSnapshot) -> Double {
        var score = 1.0
        
        // Frame rate stability
        if performance.frameRateEfficiency < level.minFrameRateEfficiency {
            score -= (level.minFrameRateEfficiency - performance.frameRateEfficiency)
        }
        
        // Processing time
        if performance.frameProcessingTime > level.maxFrameProcessingTime {
            score -= (performance.frameProcessingTime - level.maxFrameProcessingTime) * 10
        }
        
        return max(0, score)
    }
    
    private func calculateExperienceScore(level: QualityLevel, performance: PerformanceSnapshot) -> Double {
        var score = 1.0
        
        // Quality preference
        score += level.qualityPreference * 0.3
        
        // Feature availability
        if performance.thermalState == .critical && level.requiresThermalHeadroom {
            score -= 0.5
        }
        
        if performance.batteryLevel < 0.3 && level.requiresBatteryHeadroom {
            score -= 0.3
        }
        
        return max(0, score)
    }
    
    private func applyQualityLevelChange(_ level: QualityLevel) async {
        guard let baseConfig = baseConfiguration else { return }
        
        let newConfiguration = applyQualityLevel(level, to: baseConfig)
        currentConfiguration = newConfiguration
        
        // Apply adaptive strategies
        for strategy in adaptiveStrategies {
            await strategy.apply(to: &newConfiguration, performance: performanceHistory.last)
        }
        
        eventContinuation.yield(.qualityLevelChanged(level, newConfiguration))
    }
    
    private func applyQualityLevel(_ level: QualityLevel, to configuration: CameraConfiguration) -> CameraConfiguration {
        var newConfig = configuration
        
        // Apply quality settings
        newConfig = CameraConfiguration(
            quality: level.videoQuality,
            frameRate: level.frameRate,
            hdrEnabled: level.hdrEnabled && configuration.hdrEnabled,
            multiCamEnabled: level.multiCamEnabled && configuration.multiCamEnabled,
            focusMode: configuration.focusMode,
            exposureMode: configuration.exposureMode,
            whiteBalanceMode: configuration.whiteBalanceMode,
            flashMode: configuration.flashMode,
            preferredCamera: configuration.preferredCamera,
            zoomLevel: configuration.zoomLevel,
            maxZoomLevel: configuration.maxZoomLevel,
            enableOpticalZoom: configuration.enableOpticalZoom,
            audioEnabled: level.audioEnabled && configuration.audioEnabled,
            audioQuality: level.audioQuality,
            noiseReductionEnabled: level.noiseReductionEnabled && configuration.noiseReductionEnabled,
            stereoRecordingEnabled: level.stereoRecordingEnabled && configuration.stereoRecordingEnabled,
            videoStabilizationEnabled: level.videoStabilizationEnabled && configuration.videoStabilizationEnabled,
            cinematicStabilizationEnabled: configuration.cinematicStabilizationEnabled && configuration.cinematicStabilizationEnabled,
            opticalImageStabilizationEnabled: configuration.opticalImageStabilizationEnabled && configuration.opticalImageStabilizationEnabled,
            portraitModeEnabled: configuration.portraitModeEnabled,
            nightModeEnabled: configuration.nightModeEnabled,
            slowMotionEnabled: configuration.slowMotionEnabled,
            timeLapseEnabled: configuration.timeLapseEnabled,
            cinematicModeEnabled: configuration.cinematicModeEnabled,
            colorSpace: configuration.colorSpace,
            colorFilter: configuration.colorFilter,
            toneMappingEnabled: configuration.toneMappingEnabled,
            dynamicRange: configuration.dynamicRange,
            lowLightBoostEnabled: configuration.lowLightBoostEnabled,
            thermalManagementEnabled: configuration.thermalManagementEnabled,
            batteryOptimizationEnabled: configuration.batteryOptimizationEnabled,
            adaptiveQualityEnabled: configuration.adaptiveQualityEnabled,
            outputFormat: configuration.outputFormat,
            compressionQuality: level.compressionQuality,
            keyFrameInterval: configuration.keyFrameInterval,
            enableTemporalCompression: configuration.enableTemporalCompression,
            previewFrameRate: level.previewFrameRate,
            previewQuality: level.previewQuality,
            enableGridOverlay: configuration.enableGridOverlay,
            enableLevelIndicator: configuration.enableLevelIndicator,
            includeLocationMetadata: configuration.includeLocationMetadata,
            includeDeviceMetadata: configuration.includeDeviceMetadata,
            includeTimestampMetadata: configuration.includeTimestampMetadata,
            customMetadata: configuration.customMetadata,
            sceneDetectionEnabled: configuration.sceneDetectionEnabled,
            subjectTrackingEnabled: configuration.subjectTrackingEnabled,
            autoEnhancementEnabled: configuration.autoEnhancementEnabled,
            smartHDR: configuration.smartHDR,
            voiceControlEnabled: configuration.voiceControlEnabled,
            hapticFeedbackEnabled: configuration.hapticFeedbackEnabled,
            audioDescriptionsEnabled: configuration.audioDescriptionsEnabled
        )
        
        return newConfig
    }
    
    private func getCurrentQualityLevelFromConfiguration() -> QualityLevel? {
        guard let config = currentConfiguration else { return nil }
        
        return qualityLevels.first { level in
            level.videoQuality == config.quality &&
            level.frameRate == config.frameRate &&
            level.hdrEnabled == config.hdrEnabled
        }
    }
    
    private func getCurrentPerformanceSnapshot() async -> PerformanceSnapshot {
        let thermalState = await ThermalManager.shared.currentThermalState
        let batteryLevel = await BatteryManager.shared.currentBatteryLevel
        let memoryPressure = await MemoryManager.shared.currentMemoryPressure
        
        return PerformanceSnapshot(
            timestamp: Date(),
            frameRateEfficiency: 0.9, // Would get actual value
            memoryUsage: 0.5, // Would get actual value
            thermalState: thermalState,
            batteryLevel: batteryLevel,
            frameProcessingTime: 0.02, // Would get actual value
            overallScore: calculateOverallScore(
                frameRateEfficiency: 0.9,
                memoryUsage: 0.5,
                thermalState: thermalState,
                batteryLevel: batteryLevel
            )
        )
    }
    
    private func calculateOverallScore(
        frameRateEfficiency: Double,
        memoryUsage: Double,
        thermalState: ThermalState,
        batteryLevel: Double
    ) -> Double {
        var score = 1.0
        
        // Frame rate contribution (40%)
        score *= (0.6 + 0.4 * frameRateEfficiency)
        
        // Memory usage contribution (20%)
        let memoryScore = max(0, 1 - memoryUsage)
        score *= (0.8 + 0.2 * memoryScore)
        
        // Thermal state contribution (20%)
        let thermalScore = max(0, 1 - Double(thermalState.rawValue) / 4.0)
        score *= (0.8 + 0.2 * thermalScore)
        
        // Battery level contribution (20%)
        score *= (0.8 + 0.2 * batteryLevel)
        
        return max(0, min(1, score))
    }
    
    private func setupQualityLevels() {
        qualityLevels = [
            // Ultra High Quality
            QualityLevel(
                id: "ultra_high",
                name: "Ultra High",
                videoQuality: .uhd4k,
                frameRate: 60,
                hdrEnabled: true,
                multiCamEnabled: true,
                audioEnabled: true,
                audioQuality: .lossless,
                noiseReductionEnabled: true,
                stereoRecordingEnabled: true,
                videoStabilizationEnabled: true,
                cinematicStabilizationEnabled: true,
                opticalImageStabilizationEnabled: true,
                compressionQuality: 0.95,
                previewFrameRate: 60,
                previewQuality: .ultra,
                targetPerformanceScore: 0.9,
                maxMemoryUsage: 0.7,
                maxThermalState: .fair,
                minBatteryLevel: 0.5,
                minFrameRateEfficiency: 0.9,
                maxFrameProcessingTime: 0.016,
                qualityPreference: 1.0,
                requiresThermalHeadroom: true,
                requiresBatteryHeadroom: true
            ),
            
            // High Quality
            QualityLevel(
                id: "high",
                name: "High",
                videoQuality: .uhd4k,
                frameRate: 30,
                hdrEnabled: true,
                multiCamEnabled: true,
                audioEnabled: true,
                audioQuality: .high,
                noiseReductionEnabled: true,
                stereoRecordingEnabled: true,
                videoStabilizationEnabled: true,
                cinematicStabilizationEnabled: false,
                opticalImageStabilizationEnabled: true,
                compressionQuality: 0.9,
                previewFrameRate: 30,
                previewQuality: .high,
                targetPerformanceScore: 0.8,
                maxMemoryUsage: 0.8,
                maxThermalState: .serious,
                minBatteryLevel: 0.3,
                minFrameRateEfficiency: 0.8,
                maxFrameProcessingTime: 0.033,
                qualityPreference: 0.8,
                requiresThermalHeadroom: false,
                requiresBatteryHeadroom: false
            ),
            
            // Medium Quality
            QualityLevel(
                id: "medium",
                name: "Medium",
                videoQuality: .hd1080,
                frameRate: 30,
                hdrEnabled: false,
                multiCamEnabled: true,
                audioEnabled: true,
                audioQuality: .high,
                noiseReductionEnabled: true,
                stereoRecordingEnabled: true,
                videoStabilizationEnabled: true,
                cinematicStabilizationEnabled: false,
                opticalImageStabilizationEnabled: false,
                compressionQuality: 0.8,
                previewFrameRate: 30,
                previewQuality: .medium,
                targetPerformanceScore: 0.6,
                maxMemoryUsage: 0.8,
                maxThermalState: .serious,
                minBatteryLevel: 0.2,
                minFrameRateEfficiency: 0.7,
                maxFrameProcessingTime: 0.033,
                qualityPreference: 0.6,
                requiresThermalHeadroom: false,
                requiresBatteryHeadroom: false
            ),
            
            // Low Quality
            QualityLevel(
                id: "low",
                name: "Low",
                videoQuality: .hd720,
                frameRate: 24,
                hdrEnabled: false,
                multiCamEnabled: false,
                audioEnabled: true,
                audioQuality: .medium,
                noiseReductionEnabled: false,
                stereoRecordingEnabled: false,
                videoStabilizationEnabled: false,
                cinematicStabilizationEnabled: false,
                opticalImageStabilizationEnabled: false,
                compressionQuality: 0.7,
                previewFrameRate: 24,
                previewQuality: .low,
                targetPerformanceScore: 0.4,
                maxMemoryUsage: 0.9,
                maxThermalState: .critical,
                minBatteryLevel: 0.1,
                minFrameRateEfficiency: 0.6,
                maxFrameProcessingTime: 0.041,
                qualityPreference: 0.4,
                requiresThermalHeadroom: false,
                requiresBatteryHeadroom: false
            ),
            
            // Power Saver
            QualityLevel(
                id: "power_saver",
                name: "Power Saver",
                videoQuality: .hd720,
                frameRate: 15,
                hdrEnabled: false,
                multiCamEnabled: false,
                audioEnabled: true,
                audioQuality: .low,
                noiseReductionEnabled: false,
                stereoRecordingEnabled: false,
                videoStabilizationEnabled: false,
                cinematicStabilizationEnabled: false,
                opticalImageStabilizationEnabled: false,
                compressionQuality: 0.6,
                previewFrameRate: 15,
                previewQuality: .low,
                targetPerformanceScore: 0.2,
                maxMemoryUsage: 0.9,
                maxThermalState: .critical,
                minBatteryLevel: 0.05,
                minFrameRateEfficiency: 0.5,
                maxFrameProcessingTime: 0.066,
                qualityPreference: 0.2,
                requiresThermalHeadroom: false,
                requiresBatteryHeadroom: false
            )
        ]
    }
    
    private func setupAdaptiveStrategies() {
        adaptiveStrategies = [
            ThermalAdaptationStrategy(),
            BatteryAdaptationStrategy(),
            MemoryAdaptationStrategy(),
            FrameRateAdaptationStrategy()
        ]
    }
    
    private func updateQualityLevels() async {
        // Update quality levels based on current configuration
        // This would adjust the available quality levels based on device capabilities
    }
}

// MARK: - Supporting Types

enum AdaptiveQualityEvent: Sendable {
    case managementStarted
    case managementStopped
    case configurationUpdated(CameraConfiguration)
    case qualityLevelChanged(QualityLevel, CameraConfiguration)
    case thresholdChanged(Double)
    case cooldownChanged(TimeInterval)
    case strategyAdded(AdaptiveStrategy)
    case strategyRemoved(AdaptiveStrategy)
    case adaptationCompleted(QualityLevel)
    case adaptationFailed(String)
}

struct QualityLevel: Sendable, Identifiable {
    let id: String
    let name: String
    let videoQuality: VideoQuality
    let frameRate: Int32
    let hdrEnabled: Bool
    let multiCamEnabled: Bool
    let audioEnabled: Bool
    let audioQuality: AudioQuality
    let noiseReductionEnabled: Bool
    let stereoRecordingEnabled: Bool
    let videoStabilizationEnabled: Bool
    let cinematicStabilizationEnabled: Bool
    let opticalImageStabilizationEnabled: Bool
    let compressionQuality: Float
    let previewFrameRate: Int32
    let previewQuality: PreviewQuality
    let targetPerformanceScore: Double
    let maxMemoryUsage: Double
    let maxThermalState: ThermalState
    let minBatteryLevel: Double
    let minFrameRateEfficiency: Double
    let maxFrameProcessingTime: TimeInterval
    let qualityPreference: Double
    let requiresThermalHeadroom: Bool
    let requiresBatteryHeadroom: Bool
    
    var description: String {
        return "\(name) - \(videoQuality.shortDescription) @ \(frameRate)fps"
    }
}

struct PerformanceSnapshot: Sendable {
    let timestamp: Date
    let frameRateEfficiency: Double
    let memoryUsage: Double
    let thermalState: ThermalState
    let batteryLevel: Double
    let frameProcessingTime: TimeInterval
    let overallScore: Double
}

protocol AdaptiveStrategy: Sendable, Identifiable {
    func apply(to configuration: inout CameraConfiguration, performance: PerformanceSnapshot?) async
}

struct ThermalAdaptationStrategy: AdaptiveStrategy {
    let id = "thermal_adaptation"
    
    func apply(to configuration: inout CameraConfiguration, performance: PerformanceSnapshot?) async {
        guard let performance = performance else { return }
        
        if performance.thermalState == .critical {
            configuration.hdrEnabled = false
            configuration.frameRate = min(configuration.frameRate, 24)
            configuration.videoStabilizationEnabled = false
        } else if performance.thermalState == .serious {
            configuration.hdrEnabled = false
            configuration.frameRate = min(configuration.frameRate, 30)
        }
    }
}

struct BatteryAdaptationStrategy: AdaptiveStrategy {
    let id = "battery_adaptation"
    
    func apply(to configuration: inout CameraConfiguration, performance: PerformanceSnapshot?) async {
        guard let performance = performance else { return }
        
        if performance.batteryLevel < 0.1 {
            configuration.quality = .hd720
            configuration.frameRate = 15
            configuration.multiCamEnabled = false
            configuration.videoStabilizationEnabled = false
        } else if performance.batteryLevel < 0.2 {
            configuration.quality = .hd1080
            configuration.frameRate = 24
            configuration.hdrEnabled = false
        }
    }
}

struct MemoryAdaptationStrategy: AdaptiveStrategy {
    let id = "memory_adaptation"
    
    func apply(to configuration: inout CameraConfiguration, performance: PerformanceSnapshot?) async {
        guard let performance = performance else { return }
        
        if performance.memoryUsage > 0.9 {
            configuration.quality = .hd720
            configuration.multiCamEnabled = false
            configuration.noiseReductionEnabled = false
        } else if performance.memoryUsage > 0.8 {
            configuration.quality = .hd1080
            configuration.previewQuality = .medium
        }
    }
}

struct FrameRateAdaptationStrategy: AdaptiveStrategy {
    let id = "framerate_adaptation"
    
    func apply(to configuration: inout CameraConfiguration, performance: PerformanceSnapshot?) async {
        guard let performance = performance else { return }
        
        if performance.frameRateEfficiency < 0.6 {
            configuration.frameRate = max(15, configuration.frameRate / 2)
        } else if performance.frameRateEfficiency < 0.8 {
            configuration.frameRate = max(24, configuration.frameRate - 6)
        }
    }
}