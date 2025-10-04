//
//  CameraConfiguration.swift
//  DualApp
//
//  Created by DualApp Team on 10/3/25.
//

import Foundation
import AVFoundation
import SwiftUI

// MARK: - Camera Configuration

struct CameraConfiguration: Sendable, Codable, Equatable {
    
    // MARK: - Basic Configuration
    
    let quality: VideoQuality
    let frameRate: Int32
    let hdrEnabled: Bool
    let multiCamEnabled: Bool
    
    // MARK: - Advanced Configuration
    
    let focusMode: FocusMode
    let exposureMode: ExposureMode
    let whiteBalanceMode: WhiteBalanceMode
    let flashMode: FlashMode
    
    // MARK: - Lens Configuration
    
    let preferredCamera: CameraPosition
    let zoomLevel: Float
    let maxZoomLevel: Float
    let enableOpticalZoom: Bool
    
    // MARK: - Audio Configuration
    
    let audioEnabled: Bool
    let audioQuality: AudioQuality
    let noiseReductionEnabled: Bool
    let stereoRecordingEnabled: Bool
    
    // MARK: - Stabilization Configuration
    
    let videoStabilizationEnabled: Bool
    let cinematicStabilizationEnabled: Bool
    let opticalImageStabilizationEnabled: Bool
    
    // MARK: - Special Features
    
    let portraitModeEnabled: Bool
    let nightModeEnabled: Bool
    let slowMotionEnabled: Bool
    let timeLapseEnabled: Bool
    let cinematicModeEnabled: Bool
    
    // MARK: - Color and Filter Configuration
    
    let colorSpace: ColorSpace
    let colorFilter: ColorFilter
    let toneMappingEnabled: Bool
    let dynamicRange: DynamicRange
    
    // MARK: - Performance Configuration
    
    let lowLightBoostEnabled: Bool
    let thermalManagementEnabled: Bool
    let batteryOptimizationEnabled: Bool
    let adaptiveQualityEnabled: Bool
    
    // MARK: - Output Configuration
    
    let outputFormat: VideoOutputFormat
    let compressionQuality: Float
    let keyFrameInterval: Int32
    let enableTemporalCompression: Bool
    
    // MARK: - Preview Configuration
    
    let previewFrameRate: Int32
    let previewQuality: PreviewQuality
    let enableGridOverlay: Bool
    let enableLevelIndicator: Bool
    
    // MARK: - Metadata Configuration
    
    let includeLocationMetadata: Bool
    let includeDeviceMetadata: Bool
    let includeTimestampMetadata: Bool
    let customMetadata: [String: String]
    
    // MARK: - AI and ML Features
    
    let sceneDetectionEnabled: Bool
    let subjectTrackingEnabled: Bool
    let autoEnhancementEnabled: Bool
    let smartHDR: Bool
    
    // MARK: - Accessibility Features
    
    let voiceControlEnabled: Bool
    let hapticFeedbackEnabled: Bool
    let audioDescriptionsEnabled: Bool
    
    // MARK: - Initialization
    
    init(
        quality: VideoQuality = .hd1080,
        frameRate: Int32 = 30,
        hdrEnabled: Bool = false,
        multiCamEnabled: Bool = true,
        focusMode: FocusMode = .continuousAutoFocus,
        exposureMode: ExposureMode = .continuousAutoExposure,
        whiteBalanceMode: WhiteBalanceMode = .continuousAutoWhiteBalance,
        flashMode: FlashMode = .auto,
        preferredCamera: CameraPosition = .back,
        zoomLevel: Float = 1.0,
        maxZoomLevel: Float = 10.0,
        enableOpticalZoom: Bool = true,
        audioEnabled: Bool = true,
        audioQuality: AudioQuality = .high,
        noiseReductionEnabled: Bool = true,
        stereoRecordingEnabled: Bool = true,
        videoStabilizationEnabled: Bool = true,
        cinematicStabilizationEnabled: Bool = false,
        opticalImageStabilizationEnabled: Bool = true,
        portraitModeEnabled: Bool = false,
        nightModeEnabled: Bool = false,
        slowMotionEnabled: Bool = false,
        timeLapseEnabled: Bool = false,
        cinematicModeEnabled: Bool = false,
        colorSpace: ColorSpace = .sRGB,
        colorFilter: ColorFilter = .none,
        toneMappingEnabled: Bool = true,
        dynamicRange: DynamicRange = .sdr,
        lowLightBoostEnabled: Bool = false,
        thermalManagementEnabled: Bool = true,
        batteryOptimizationEnabled: Bool = true,
        adaptiveQualityEnabled: Bool = true,
        outputFormat: VideoOutputFormat = .mp4,
        compressionQuality: Float = 0.8,
        keyFrameInterval: Int32 = 60,
        enableTemporalCompression: Bool = true,
        previewFrameRate: Int32 = 30,
        previewQuality: PreviewQuality = .high,
        enableGridOverlay: Bool = false,
        enableLevelIndicator: Bool = false,
        includeLocationMetadata: Bool = false,
        includeDeviceMetadata: Bool = true,
        includeTimestampMetadata: Bool = true,
        customMetadata: [String: String] = [:],
        sceneDetectionEnabled: Bool = true,
        subjectTrackingEnabled: Bool = false,
        autoEnhancementEnabled: Bool = true,
        smartHDR: Bool = false,
        voiceControlEnabled: Bool = false,
        hapticFeedbackEnabled: Bool = true,
        audioDescriptionsEnabled: Bool = false
    ) {
        self.quality = quality
        self.frameRate = frameRate
        self.hdrEnabled = hdrEnabled
        self.multiCamEnabled = multiCamEnabled
        self.focusMode = focusMode
        self.exposureMode = exposureMode
        self.whiteBalanceMode = whiteBalanceMode
        self.flashMode = flashMode
        self.preferredCamera = preferredCamera
        self.zoomLevel = zoomLevel
        self.maxZoomLevel = maxZoomLevel
        self.enableOpticalZoom = enableOpticalZoom
        self.audioEnabled = audioEnabled
        self.audioQuality = audioQuality
        self.noiseReductionEnabled = noiseReductionEnabled
        self.stereoRecordingEnabled = stereoRecordingEnabled
        self.videoStabilizationEnabled = videoStabilizationEnabled
        self.cinematicStabilizationEnabled = cinematicStabilizationEnabled
        self.opticalImageStabilizationEnabled = opticalImageStabilizationEnabled
        self.portraitModeEnabled = portraitModeEnabled
        self.nightModeEnabled = nightModeEnabled
        self.slowMotionEnabled = slowMotionEnabled
        self.timeLapseEnabled = timeLapseEnabled
        self.cinematicModeEnabled = cinematicModeEnabled
        self.colorSpace = colorSpace
        self.colorFilter = colorFilter
        self.toneMappingEnabled = toneMappingEnabled
        self.dynamicRange = dynamicRange
        self.lowLightBoostEnabled = lowLightBoostEnabled
        self.thermalManagementEnabled = thermalManagementEnabled
        self.batteryOptimizationEnabled = batteryOptimizationEnabled
        self.adaptiveQualityEnabled = adaptiveQualityEnabled
        self.outputFormat = outputFormat
        self.compressionQuality = compressionQuality
        self.keyFrameInterval = keyFrameInterval
        self.enableTemporalCompression = enableTemporalCompression
        self.previewFrameRate = previewFrameRate
        self.previewQuality = previewQuality
        self.enableGridOverlay = enableGridOverlay
        self.enableLevelIndicator = enableLevelIndicator
        self.includeLocationMetadata = includeLocationMetadata
        self.includeDeviceMetadata = includeDeviceMetadata
        self.includeTimestampMetadata = includeTimestampMetadata
        self.customMetadata = customMetadata
        self.sceneDetectionEnabled = sceneDetectionEnabled
        self.subjectTrackingEnabled = subjectTrackingEnabled
        self.autoEnhancementEnabled = autoEnhancementEnabled
        self.smartHDR = smartHDR
        self.voiceControlEnabled = voiceControlEnabled
        self.hapticFeedbackEnabled = hapticFeedbackEnabled
        self.audioDescriptionsEnabled = audioDescriptionsEnabled
    }
    
    // MARK: - Default Configurations
    
    static let `default` = CameraConfiguration()
    
    static let highQuality = CameraConfiguration(
        quality: .uhd4k,
        frameRate: 60,
        hdrEnabled: true,
        multiCamEnabled: true,
        videoStabilizationEnabled: true,
        cinematicStabilizationEnabled: true,
        audioQuality: .lossless,
        compressionQuality: 0.9,
        smartHDR: true,
        sceneDetectionEnabled: true,
        autoEnhancementEnabled: true
    )
    
    static let lowPower = CameraConfiguration(
        quality: .hd720,
        frameRate: 24,
        hdrEnabled: false,
        multiCamEnabled: false,
        videoStabilizationEnabled: false,
        cinematicStabilizationEnabled: false,
        audioQuality: .medium,
        compressionQuality: 0.6,
        smartHDR: false,
        sceneDetectionEnabled: false,
        autoEnhancementEnabled: false,
        batteryOptimizationEnabled: true,
        adaptiveQualityEnabled: true
    )
    
    static let portrait = CameraConfiguration(
        quality: .hd1080,
        frameRate: 30,
        hdrEnabled: true,
        multiCamEnabled: false,
        portraitModeEnabled: true,
        cinematicStabilizationEnabled: true,
        audioQuality: .high,
        compressionQuality: 0.8,
        smartHDR: true,
        sceneDetectionEnabled: true,
        autoEnhancementEnabled: true,
        subjectTrackingEnabled: true
    )
    
    static let cinematic = CameraConfiguration(
        quality: .uhd4k,
        frameRate: 24,
        hdrEnabled: true,
        multiCamEnabled: false,
        cinematicModeEnabled: true,
        cinematicStabilizationEnabled: true,
        audioQuality: .lossless,
        compressionQuality: 0.9,
        colorSpace: .p3,
        dynamicRange: .hdr10,
        smartHDR: true,
        sceneDetectionEnabled: true,
        autoEnhancementEnabled: true,
        subjectTrackingEnabled: true
    )
    
    static let slowMotion = CameraConfiguration(
        quality: .hd1080,
        frameRate: 240,
        hdrEnabled: false,
        multiCamEnabled: false,
        slowMotionEnabled: true,
        videoStabilizationEnabled: true,
        audioQuality: .high,
        compressionQuality: 0.8,
        smartHDR: false,
        sceneDetectionEnabled: false,
        autoEnhancementEnabled: false
    )
    
    static let timeLapse = CameraConfiguration(
        quality: .uhd4k,
        frameRate: 1,
        hdrEnabled: true,
        multiCamEnabled: false,
        timeLapseEnabled: true,
        videoStabilizationEnabled: true,
        audioEnabled: false,
        compressionQuality: 0.8,
        smartHDR: true,
        sceneDetectionEnabled: true,
        autoEnhancementEnabled: true
    )
    
    static let nightMode = CameraConfiguration(
        quality: .hd1080,
        frameRate: 30,
        hdrEnabled: true,
        multiCamEnabled: false,
        nightModeEnabled: true,
        lowLightBoostEnabled: true,
        videoStabilizationEnabled: true,
        audioQuality: .high,
        compressionQuality: 0.8,
        smartHDR: true,
        sceneDetectionEnabled: true,
        autoEnhancementEnabled: true
    )
    
    // MARK: - Validation
    
    func validate() -> [ConfigurationError] {
        var errors: [ConfigurationError] = []
        
        // Validate frame rate
        if frameRate <= 0 || frameRate > 240 {
            errors.append(.invalidFrameRate(frameRate))
        }
        
        // Validate zoom level
        if zoomLevel < 1.0 || zoomLevel > maxZoomLevel {
            errors.append(.invalidZoomLevel(zoomLevel))
        }
        
        // Validate compression quality
        if compressionQuality < 0.1 || compressionQuality > 1.0 {
            errors.append(.invalidCompressionQuality(compressionQuality))
        }
        
        // Validate key frame interval
        if keyFrameInterval <= 0 {
            errors.append(.invalidKeyFrameInterval(keyFrameInterval))
        }
        
        // Validate compatibility
        if slowMotionEnabled && frameRate < 60 {
            errors.append(.incompatibleSlowMotionFrameRate(frameRate))
        }
        
        if nightModeEnabled && frameRate > 30 {
            errors.append(.incompatibleNightModeFrameRate(frameRate))
        }
        
        if cinematicModeEnabled && quality != .uhd4k {
            errors.append(.incompatibleCinematicModeQuality(quality))
        }
        
        if portraitModeEnabled && multiCamEnabled {
            errors.append(.incompatiblePortraitModeMultiCam)
        }
        
        return errors
    }
    
    // MARK: - Compatibility
    
    func isCompatibleWith(device: AVCaptureDevice) -> Bool {
        // Check device capabilities
        guard device.supportsSessionPreset(quality.avSessionPreset) else {
            return false
        }
        
        // Check frame rate support
        guard device.activeFormat.supportedFrameRateRanges.contains(where: { range in
            range.minFrameRate...range.maxFrameRate ~= Double(frameRate)
        }) else {
            return false
        }
        
        // Check zoom support
        guard zoomLevel <= device.activeFormat.videoMaxZoomFactor else {
            return false
        }
        
        // Check feature support
        if portraitModeEnabled && !device.supportsPortraitMode {
            return false
        }
        
        if cinematicModeEnabled && !device.supportsCinematicMode {
            return false
        }
        
        if nightModeEnabled && !device.supportsNightMode {
            return false
        }
        
        return true
    }
    
    // MARK: - Optimization
    
    func optimizedFor(batteryLevel: Double, thermalState: ThermalState) -> CameraConfiguration {
        var config = self
        
        // Battery optimization
        if batteryLevel < 0.2 {
            config.quality = .hd720
            config.frameRate = 24
            config.hdrEnabled = false
            config.videoStabilizationEnabled = false
            config.compressionQuality = 0.6
        } else if batteryLevel < 0.5 {
            config.quality = .hd1080
            config.frameRate = 30
            config.compressionQuality = 0.7
        }
        
        // Thermal optimization
        if thermalState == .serious || thermalState == .critical {
            config.frameRate = min(config.frameRate, 30)
            config.hdrEnabled = false
            config.videoStabilizationEnabled = false
            config.smartHDR = false
        }
        
        return config
    }
    
    // MARK: - Description
    
    var description: String {
        var components: [String] = []
        
        components.append("\(quality.description)")
        components.append("\(frameRate) fps")
        
        if hdrEnabled {
            components.append("HDR")
        }
        
        if multiCamEnabled {
            components.append("Multi-Cam")
        }
        
        if portraitModeEnabled {
            components.append("Portrait")
        }
        
        if cinematicModeEnabled {
            components.append("Cinematic")
        }
        
        if nightModeEnabled {
            components.append("Night Mode")
        }
        
        if slowMotionEnabled {
            components.append("Slow Motion")
        }
        
        if timeLapseEnabled {
            components.append("Time Lapse")
        }
        
        return components.joined(separator: " • ")
    }
    
    var detailedDescription: String {
        var description = self.description
        description += "\n\nFocus: \(focusMode.description)"
        description += "\nExposure: \(exposureMode.description)"
        description += "\nWhite Balance: \(whiteBalanceMode.description)"
        description += "\nFlash: \(flashMode.description)"
        description += "\nStabilization: \(videoStabilizationEnabled ? "On" : "Off")"
        description += "\nAudio: \(audioEnabled ? audioQuality.description : "Disabled")"
        description += "\nFormat: \(outputFormat.description)"
        description += "\nColor Space: \(colorSpace.description)"
        
        return description
    }
}

// MARK: - Configuration Error

enum ConfigurationError: LocalizedError, Sendable, Codable {
    case invalidFrameRate(Int32)
    case invalidZoomLevel(Float)
    case invalidCompressionQuality(Float)
    case invalidKeyFrameInterval(Int32)
    case incompatibleSlowMotionFrameRate(Int32)
    case incompatibleNightModeFrameRate(Int32)
    case incompatibleCinematicModeQuality(VideoQuality)
    case incompatiblePortraitModeMultiCam
    case unsupportedFeature(String)
    case deviceNotAvailable
    
    var errorDescription: String? {
        switch self {
        case .invalidFrameRate(let frameRate):
            return "Invalid frame rate: \(frameRate) fps"
        case .invalidZoomLevel(let zoomLevel):
            return "Invalid zoom level: \(zoomLevel)x"
        case .invalidCompressionQuality(let quality):
            return "Invalid compression quality: \(quality)"
        case .invalidKeyFrameInterval(let interval):
            return "Invalid key frame interval: \(interval)"
        case .incompatibleSlowMotionFrameRate(let frameRate):
            return "Slow motion requires frame rate of 60 fps or higher, got \(frameRate) fps"
        case .incompatibleNightModeFrameRate(let frameRate):
            return "Night mode supports frame rates up to 30 fps, got \(frameRate) fps"
        case .incompatibleCinematicModeQuality(let quality):
            return "Cinematic mode requires 4K quality, got \(quality.description)"
        case .incompatiblePortraitModeMultiCam:
            return "Portrait mode is not compatible with multi-camera recording"
        case .unsupportedFeature(let feature):
            return "Unsupported feature: \(feature)"
        case .deviceNotAvailable:
            return "Camera device is not available"
        }
    }
}

// MARK: - Camera Configuration Builder

class CameraConfigurationBuilder {
    private var configuration = CameraConfiguration()
    
    func quality(_ quality: VideoQuality) -> CameraConfigurationBuilder {
        configuration = CameraConfiguration(
            quality: quality,
            frameRate: configuration.frameRate,
            hdrEnabled: configuration.hdrEnabled,
            multiCamEnabled: configuration.multiCamEnabled,
            focusMode: configuration.focusMode,
            exposureMode: configuration.exposureMode,
            whiteBalanceMode: configuration.whiteBalanceMode,
            flashMode: configuration.flashMode,
            preferredCamera: configuration.preferredCamera,
            zoomLevel: configuration.zoomLevel,
            maxZoomLevel: configuration.maxZoomLevel,
            enableOpticalZoom: configuration.enableOpticalZoom,
            audioEnabled: configuration.audioEnabled,
            audioQuality: configuration.audioQuality,
            noiseReductionEnabled: configuration.noiseReductionEnabled,
            stereoRecordingEnabled: configuration.stereoRecordingEnabled,
            videoStabilizationEnabled: configuration.videoStabilizationEnabled,
            cinematicStabilizationEnabled: configuration.cinematicStabilizationEnabled,
            opticalImageStabilizationEnabled: configuration.opticalImageStabilizationEnabled,
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
            compressionQuality: configuration.compressionQuality,
            keyFrameInterval: configuration.keyFrameInterval,
            enableTemporalCompression: configuration.enableTemporalCompression,
            previewFrameRate: configuration.previewFrameRate,
            previewQuality: configuration.previewQuality,
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
        return self
    }
    
    func frameRate(_ frameRate: Int32) -> CameraConfigurationBuilder {
        configuration = CameraConfiguration(
            quality: configuration.quality,
            frameRate: frameRate,
            hdrEnabled: configuration.hdrEnabled,
            multiCamEnabled: configuration.multiCamEnabled,
            focusMode: configuration.focusMode,
            exposureMode: configuration.exposureMode,
            whiteBalanceMode: configuration.whiteBalanceMode,
            flashMode: configuration.flashMode,
            preferredCamera: configuration.preferredCamera,
            zoomLevel: configuration.zoomLevel,
            maxZoomLevel: configuration.maxZoomLevel,
            enableOpticalZoom: configuration.enableOpticalZoom,
            audioEnabled: configuration.audioEnabled,
            audioQuality: configuration.audioQuality,
            noiseReductionEnabled: configuration.noiseReductionEnabled,
            stereoRecordingEnabled: configuration.stereoRecordingEnabled,
            videoStabilizationEnabled: configuration.videoStabilizationEnabled,
            cinematicStabilizationEnabled: configuration.cinematicStabilizationEnabled,
            opticalImageStabilizationEnabled: configuration.opticalImageStabilizationEnabled,
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
            compressionQuality: configuration.compressionQuality,
            keyFrameInterval: configuration.keyFrameInterval,
            enableTemporalCompression: configuration.enableTemporalCompression,
            previewFrameRate: configuration.previewFrameRate,
            previewQuality: configuration.previewQuality,
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
        return self
    }
    
    func enableHDR() -> CameraConfigurationBuilder {
        configuration = CameraConfiguration(
            quality: configuration.quality,
            frameRate: configuration.frameRate,
            hdrEnabled: true,
            multiCamEnabled: configuration.multiCamEnabled,
            focusMode: configuration.focusMode,
            exposureMode: configuration.exposureMode,
            whiteBalanceMode: configuration.whiteBalanceMode,
            flashMode: configuration.flashMode,
            preferredCamera: configuration.preferredCamera,
            zoomLevel: configuration.zoomLevel,
            maxZoomLevel: configuration.maxZoomLevel,
            enableOpticalZoom: configuration.enableOpticalZoom,
            audioEnabled: configuration.audioEnabled,
            audioQuality: configuration.audioQuality,
            noiseReductionEnabled: configuration.noiseReductionEnabled,
            stereoRecordingEnabled: configuration.stereoRecordingEnabled,
            videoStabilizationEnabled: configuration.videoStabilizationEnabled,
            cinematicStabilizationEnabled: configuration.cinematicStabilizationEnabled,
            opticalImageStabilizationEnabled: configuration.opticalImageStabilizationEnabled,
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
            compressionQuality: configuration.compressionQuality,
            keyFrameInterval: configuration.keyFrameInterval,
            enableTemporalCompression: configuration.enableTemporalCompression,
            previewFrameRate: configuration.previewFrameRate,
            previewQuality: configuration.previewQuality,
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
        return self
    }
    
    func enableMultiCam() -> CameraConfigurationBuilder {
        configuration = CameraConfiguration(
            quality: configuration.quality,
            frameRate: configuration.frameRate,
            hdrEnabled: configuration.hdrEnabled,
            multiCamEnabled: true,
            focusMode: configuration.focusMode,
            exposureMode: configuration.exposureMode,
            whiteBalanceMode: configuration.whiteBalanceMode,
            flashMode: configuration.flashMode,
            preferredCamera: configuration.preferredCamera,
            zoomLevel: configuration.zoomLevel,
            maxZoomLevel: configuration.maxZoomLevel,
            enableOpticalZoom: configuration.enableOpticalZoom,
            audioEnabled: configuration.audioEnabled,
            audioQuality: configuration.audioQuality,
            noiseReductionEnabled: configuration.noiseReductionEnabled,
            stereoRecordingEnabled: configuration.stereoRecordingEnabled,
            videoStabilizationEnabled: configuration.videoStabilizationEnabled,
            cinematicStabilizationEnabled: configuration.cinematicStabilizationEnabled,
            opticalImageStabilizationEnabled: configuration.opticalImageStabilizationEnabled,
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
            compressionQuality: configuration.compressionQuality,
            keyFrameInterval: configuration.keyFrameInterval,
            enableTemporalCompression: configuration.enableTemporalCompression,
            previewFrameRate: configuration.previewFrameRate,
            previewQuality: configuration.previewQuality,
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
        return self
    }
    
    func enablePortraitMode() -> CameraConfigurationBuilder {
        configuration = CameraConfiguration(
            quality: configuration.quality,
            frameRate: configuration.frameRate,
            hdrEnabled: configuration.hdrEnabled,
            multiCamEnabled: false, // Portrait mode doesn't support multi-cam
            focusMode: configuration.focusMode,
            exposureMode: configuration.exposureMode,
            whiteBalanceMode: configuration.whiteBalanceMode,
            flashMode: configuration.flashMode,
            preferredCamera: configuration.preferredCamera,
            zoomLevel: configuration.zoomLevel,
            maxZoomLevel: configuration.maxZoomLevel,
            enableOpticalZoom: configuration.enableOpticalZoom,
            audioEnabled: configuration.audioEnabled,
            audioQuality: configuration.audioQuality,
            noiseReductionEnabled: configuration.noiseReductionEnabled,
            stereoRecordingEnabled: configuration.stereoRecordingEnabled,
            videoStabilizationEnabled: configuration.videoStabilizationEnabled,
            cinematicStabilizationEnabled: configuration.cinematicStabilizationEnabled,
            opticalImageStabilizationEnabled: configuration.opticalImageStabilizationEnabled,
            portraitModeEnabled: true,
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
            compressionQuality: configuration.compressionQuality,
            keyFrameInterval: configuration.keyFrameInterval,
            enableTemporalCompression: configuration.enableTemporalCompression,
            previewFrameRate: configuration.previewFrameRate,
            previewQuality: configuration.previewQuality,
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
        return self
    }
    
    func enableCinematicMode() -> CameraConfigurationBuilder {
        configuration = CameraConfiguration(
            quality: .uhd4k, // Cinematic mode requires 4K
            frameRate: 24, // Cinematic mode uses 24 fps
            hdrEnabled: true,
            multiCamEnabled: false, // Cinematic mode doesn't support multi-cam
            focusMode: configuration.focusMode,
            exposureMode: configuration.exposureMode,
            whiteBalanceMode: configuration.whiteBalanceMode,
            flashMode: configuration.flashMode,
            preferredCamera: configuration.preferredCamera,
            zoomLevel: configuration.zoomLevel,
            maxZoomLevel: configuration.maxZoomLevel,
            enableOpticalZoom: configuration.enableOpticalZoom,
            audioEnabled: configuration.audioEnabled,
            audioQuality: .lossless, // Cinematic mode uses lossless audio
            noiseReductionEnabled: configuration.noiseReductionEnabled,
            stereoRecordingEnabled: configuration.stereoRecordingEnabled,
            videoStabilizationEnabled: configuration.videoStabilizationEnabled,
            cinematicStabilizationEnabled: true,
            opticalImageStabilizationEnabled: configuration.opticalImageStabilizationEnabled,
            portraitModeEnabled: configuration.portraitModeEnabled,
            nightModeEnabled: configuration.nightModeEnabled,
            slowMotionEnabled: false, // Not compatible with cinematic mode
            timeLapseEnabled: false, // Not compatible with cinematic mode
            cinematicModeEnabled: true,
            colorSpace: .p3, // Cinematic mode uses P3 color space
            colorFilter: configuration.colorFilter,
            toneMappingEnabled: configuration.toneMappingEnabled,
            dynamicRange: .hdr10, // Cinematic mode uses HDR10
            lowLightBoostEnabled: configuration.lowLightBoostEnabled,
            thermalManagementEnabled: configuration.thermalManagementEnabled,
            batteryOptimizationEnabled: configuration.batteryOptimizationEnabled,
            adaptiveQualityEnabled: configuration.adaptiveQualityEnabled,
            outputFormat: configuration.outputFormat,
            compressionQuality: 0.9, // High quality for cinematic mode
            keyFrameInterval: configuration.keyFrameInterval,
            enableTemporalCompression: configuration.enableTemporalCompression,
            previewFrameRate: configuration.previewFrameRate,
            previewQuality: configuration.previewQuality,
            enableGridOverlay: configuration.enableGridOverlay,
            enableLevelIndicator: configuration.enableLevelIndicator,
            includeLocationMetadata: configuration.includeLocationMetadata,
            includeDeviceMetadata: configuration.includeDeviceMetadata,
            includeTimestampMetadata: configuration.includeTimestampMetadata,
            customMetadata: configuration.customMetadata,
            sceneDetectionEnabled: true,
            subjectTrackingEnabled: true,
            autoEnhancementEnabled: true,
            smartHDR: true,
            voiceControlEnabled: configuration.voiceControlEnabled,
            hapticFeedbackEnabled: configuration.hapticFeedbackEnabled,
            audioDescriptionsEnabled: configuration.audioDescriptionsEnabled
        )
        return self
    }
    
    func build() -> CameraConfiguration {
        return configuration
    }
}

// MARK: - Camera Configuration Presets Manager

class CameraConfigurationPresets {
    
    static let shared = CameraConfigurationPresets()
    
    private var userPresets: [String: CameraConfiguration] = [:]
    
    private init() {
        loadUserPresets()
    }
    
    // MARK: - Built-in Presets
    
    static let builtInPresets: [String: CameraConfiguration] = [
        "Default": .default,
        "High Quality": .highQuality,
        "Low Power": .lowPower,
        "Portrait": .portrait,
        "Cinematic": .cinematic,
        "Slow Motion": .slowMotion,
        "Time Lapse": .timeLapse,
        "Night Mode": .nightMode
    ]
    
    // MARK: - Preset Management
    
    func preset(named name: String) -> CameraConfiguration? {
        return builtInPresets[name] ?? userPresets[name]
    }
    
    func allPresets() -> [String: CameraConfiguration] {
        var allPresets = builtInPresets
        allPresets.merge(userPresets) { _, new in new }
        return allPresets
    }
    
    func savePreset(_ configuration: CameraConfiguration, named name: String) {
        userPresets[name] = configuration
        saveUserPresets()
    }
    
    func deletePreset(named name: String) {
        userPresets.removeValue(forKey: name)
        saveUserPresets()
    }
    
    // MARK: - Persistence
    
    private func loadUserPresets() {
        // Load user presets from UserDefaults or file storage
        if let data = UserDefaults.standard.data(forKey: "UserCameraPresets"),
           let presets = try? JSONDecoder().decode([String: CameraConfiguration].self, from: data) {
            userPresets = presets
        }
    }
    
    private func saveUserPresets() {
        // Save user presets to UserDefaults or file storage
        if let data = try? JSONEncoder().encode(userPresets) {
            UserDefaults.standard.set(data, forKey: "UserCameraPresets")
        }
    }
}