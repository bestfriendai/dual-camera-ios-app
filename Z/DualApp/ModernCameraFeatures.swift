//
//  ModernCameraFeatures.swift
//  DualCameraApp
//
//  iOS 17+ and iOS 18+ camera capabilities integration
//

import AVFoundation
import CoreVideo
import Metal

@available(iOS 17.0, *)
class ModernCameraFeatures {
    
    // MARK: - ProRes Recording Support
    
    static func configureProResOutput(for session: AVCaptureSession, device: AVCaptureDevice) -> AVCaptureMovieFileOutput? {
        guard device.activeFormat.supportedCodecs.contains(.proRes422) else {
            print("ProRes not supported on this device")
            return nil
        }
        
        let output = AVCaptureMovieFileOutput()
        
        // Configure ProRes settings
        if #available(iOS 17.0, *) {
            output.setOutputSettings([
                AVVideoCodecKey: AVVideoCodecType.proRes422,
                AVVideoWidthKey: device.activeFormat.formatDescription.dimensions.width,
                AVVideoHeightKey: device.activeFormat.formatDescription.dimensions.height,
                AVVideoCompressionPropertiesKey: [
                    AVVideoAverageBitRateKey: 50_000_000, // 50 Mbps for ProRes
                    AVVideoProfileLevelKey: kAVVideoProfileLevelH264HighAutoLevel
                ]
            ])
        }
        
        return output
    }
    
    // MARK: - Spatial Video for Vision Pro
    
    static func configureSpatialVideoOutput(for session: AVCaptureSession) -> AVCaptureMovieFileOutput? {
        guard #available(iOS 17.0, *) else { return nil }
        
        let output = AVCaptureMovieFileOutput()
        
        // Configure for spatial video (stereoscopic 3D)
        output.setOutputSettings([
            AVVideoCodecKey: AVVideoCodecType.hevc,
            AVVideoWidthKey: 4096,
            AVVideoHeightKey: 2048,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: 100_000_000, // High bitrate for spatial
                AVVideoExpectedSourceFrameRateKey: 30,
                AVVideoProfileLevelKey: kVTProfileLevel_HEVC_Main_AutoLevel
            ]
        ])
        
        return output
    }
    
    // MARK: - Depth Data Integration
    
    static func configureDepthDataOutput(for session: AVCaptureSession, device: AVCaptureDevice) -> AVCaptureDepthDataOutput? {
        guard #available(iOS 17.0, *),
              let depthFormats = device.activeFormat.supportedDepthDataFormats,
              !depthFormats.isEmpty else {
            print("Depth data not supported")
            return nil
        }
        
        let depthOutput = AVCaptureDepthDataOutput()
        depthOutput.isFilteringEnabled = true
        
        // Configure for best depth format
        if let bestFormat = depthFormats.first {
            depthOutput.setDepthDataFormat(bestFormat)
        }
        
        return depthOutput
    }
    
    // MARK: - Portrait Mode Video
    
    static func configurePortraitModeOutput(for session: AVCaptureSession, device: AVCaptureDevice) -> AVCaptureMovieFileOutput? {
        guard #available(iOS 17.0, *),
              device.activeFormat.isPortraitEffectSupported else {
            print("Portrait mode not supported")
            return nil
        }
        
        let output = AVCaptureMovieFileOutput()
        
        // Enable portrait effect (background blur)
        output.setOutputSettings([
            AVVideoCodecKey: AVVideoCodecType.hevc,
            AVVideoWidthKey: device.activeFormat.formatDescription.dimensions.width,
            AVVideoHeightKey: device.activeFormat.formatDescription.dimensions.height,
            AVVideoCompressionPropertiesKey: [
                AVVideoPortraitEffectEnabledKey: true,
                AVVideoAverageBitRateKey: 15_000_000
            ]
        ])
        
        return output
    }
    
    // MARK: - Cinematic Mode 2.0
    
    static func configureCinematicModeOutput(for session: AVCaptureSession, device: AVCaptureDevice) -> AVCaptureMovieFileOutput? {
        guard #available(iOS 17.0, *),
              device.activeFormat.isCinematicVideoSupported else {
            print("Cinematic mode not supported")
            return nil
        }
        
        let output = AVCaptureMovieFileOutput()
        
        // Enhanced cinematic settings
        output.setOutputSettings([
            AVVideoCodecKey: AVVideoCodecType.hevc,
            AVVideoWidthKey: 3840,
            AVVideoHeightKey: 2160,
            AVVideoCompressionPropertiesKey: [
                AVVideoCinematicVideoEnabledKey: true,
                AVVideoAverageBitRateKey: 25_000_000,
                AVVideoMaxKeyFrameIntervalKey: 60
            ]
        ])
        
        return output
    }
    
    // MARK: - Action Mode Video
    
    static func configureActionModeOutput(for session: AVCaptureSession, device: AVCaptureDevice) -> AVCaptureMovieFileOutput? {
        guard #available(iOS 17.0, *),
              device.activeFormat.isActionModeVideoSupported else {
            print("Action mode not supported")
            return nil
        }
        
        let output = AVCaptureMovieFileOutput()
        
        // Action mode for smooth motion
        output.setOutputSettings([
            AVVideoCodecKey: AVVideoCodecType.hevc,
            AVVideoWidthKey: 1920,
            AVVideoHeightKey: 1080,
            AVVideoCompressionPropertiesKey: [
                AVVideoActionModeVideoEnabledKey: true,
                AVVideoExpectedSourceFrameRateKey: 60,
                AVVideoAverageBitRateKey: 12_000_000
            ]
        ])
        
        return output
    }
    
    // MARK: - Enhanced HDR Video
    
    static func configureHDRVideoOutput(for session: AVCaptureSession, device: AVCaptureDevice) -> AVCaptureMovieFileOutput? {
        guard #available(iOS 17.0, *),
              device.activeFormat.isVideoHDRSupported else {
            print("HDR video not supported")
            return nil
        }
        
        let output = AVCaptureMovieFileOutput()
        
        // Dolby Vision HDR
        output.setOutputSettings([
            AVVideoCodecKey: AVVideoCodecType.hevc,
            AVVideoWidthKey: device.activeFormat.formatDescription.dimensions.width,
            AVVideoHeightKey: device.activeFormat.formatDescription.dimensions.height,
            AVVideoCompressionPropertiesKey: [
                AVVideoHDREnabledKey: true,
                AVVideoAverageBitRateKey: 30_000_000,
                AVVideoColorPrimariesKey: kAVVideoColorPrimaries_ITU_R_2020,
                AVVideoTransferFunctionKey: kAVVideoTransferFunction_ITU_R_2020,
                AVVideoYCbCrMatrixKey: kAVVideoYCbCrMatrix_ITU_R_2020
            ]
        ])
        
        return output
    }
    
    // MARK: - Multi-Stream Recording
    
    static func configureMultiStreamRecording(for session: AVCaptureSession, device: AVCaptureDevice) -> [AVCaptureMovieFileOutput] {
        var outputs: [AVCaptureMovieFileOutput] = []
        
        // High quality stream
        if let highQualityOutput = createHighQualityOutput(for: device) {
            outputs.append(highQualityOutput)
        }
        
        // Low quality stream for preview/analysis
        if let lowQualityOutput = createLowQualityOutput(for: device) {
            outputs.append(lowQualityOutput)
        }
        
        return outputs
    }
    
    private static func createHighQualityOutput(for device: AVCaptureDevice) -> AVCaptureMovieFileOutput? {
        let output = AVCaptureMovieFileOutput()
        output.setOutputSettings([
            AVVideoCodecKey: AVVideoCodecType.hevc,
            AVVideoWidthKey: device.activeFormat.formatDescription.dimensions.width,
            AVVideoHeightKey: device.activeFormat.formatDescription.dimensions.height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: 20_000_000,
                AVVideoExpectedSourceFrameRateKey: 30
            ]
        ])
        return output
    }
    
    private static func createLowQualityOutput(for device: AVCaptureDevice) -> AVCaptureMovieFileOutput? {
        let output = AVCaptureMovieFileOutput()
        output.setOutputSettings([
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: 960,
            AVVideoHeightKey: 540,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: 2_000_000,
                AVVideoExpectedSourceFrameRateKey: 30
            ]
        ])
        return output
    }
}

// MARK: - iOS 18+ Features

@available(iOS 18.0, *)
extension ModernCameraFeatures {
    
    // MARK: - AI-Powered Camera Features
    
    static func configureAICameraFeatures(for device: AVCaptureDevice) {
        // AI-powered scene detection and optimization
        if #available(iOS 18.0, *) {
            do {
                try device.lockForConfiguration()
                
                // Enable AI scene detection
                if device.isSceneDetectionSupported {
                    device.enablesSceneDetection = true
                }
                
                // Enable AI-powered auto-focus
                if device.isAutoFocusRangeRestrictionSupported {
                    device.autoFocusRangeRestriction = .near
                }
                
                // Enable AI low-light enhancement
                if device.isLowLightBoostSupported {
                    device.automaticallyEnablesLowLightBoostWhenAvailable = true
                }
                
                device.unlockForConfiguration()
            } catch {
                print("Failed to configure AI camera features: \(error)")
            }
        }
    }
    
    // MARK: - Advanced Computational Photography
    
    static func configureComputationalPhotography(for device: AVCaptureDevice) -> AVCapturePhotoOutput? {
        guard #available(iOS 18.0, *) else { return nil }
        
        let output = AVCapturePhotoOutput()
        
        // Configure for computational photography
        if #available(iOS 18.0, *) {
            output.maxPhotoQualityPrioritization = .quality
            
            // Enable advanced computational features
            output.isHighResolutionCaptureEnabled = true
            output.isAutoStabilizationEnabled = true
            
            // Configure for best quality
            let settings = AVCapturePhotoSettings()
            settings.photoQualityPrioritization = .quality
            settings.isHighResolutionPhotoEnabled = true
            settings.isAutoStabilizationEnabled = true
            
            // Enable semantic rendering if available
            if output.isSemanticRenderingSupported {
                settings.isSemanticRenderingEnabled = true
            }
        }
        
        return output
    }
    
    // MARK: - Real-Time Video Effects
    
    static func configureRealTimeEffects(for session: AVCaptureSession) -> AVCaptureVideoDataOutput? {
        guard #available(iOS 18.0, *) else { return nil }
        
        let output = AVCaptureVideoDataOutput()
        
        // Configure for real-time effects processing
        output.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferMetalCompatibilityKey as String: true
        ]
        
        output.alwaysDiscardsLateVideoFrames = false
        
        return output
    }
}

// MARK: - Device Capability Extensions

extension AVCaptureDevice.Format {
    var isPortraitEffectSupported: Bool {
        if #available(iOS 17.0, *) {
            return supportedCodecs.contains(.hevc) && 
                   dimensions.width >= 1920 && 
                   dimensions.height >= 1080
        }
        return false
    }
    
    var isCinematicVideoSupported: Bool {
        if #available(iOS 17.0, *) {
            return supportedCodecs.contains(.hevc) && 
                   dimensions.width >= 3840 && 
                   dimensions.height >= 2160
        }
        return false
    }
    
    var isActionModeVideoSupported: Bool {
        if #available(iOS 17.0, *) {
            return supportedCodecs.contains(.hevc) && 
                   videoSupportedFrameRateRanges.contains(where: { $0.maxFrameRate >= 60 })
        }
        return false
    }
}

extension AVCaptureDevice {
    var isSceneDetectionSupported: Bool {
        if #available(iOS 18.0, *) {
            return activeFormat.isSceneDetectionSupported
        }
        return false
    }
    
    var isSemanticRenderingSupported: Bool {
        if #available(iOS 18.0, *) {
            return activeFormat.isSemanticRenderingSupported
        }
        return false
    }
}