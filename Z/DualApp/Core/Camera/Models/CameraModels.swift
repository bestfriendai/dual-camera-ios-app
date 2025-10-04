//
//  CameraModels.swift
//  DualApp
//
//  Created by DualApp Team on 10/3/25.
//

import Foundation
import AVFoundation
import SwiftUI

// MARK: - Video Quality Extension

extension VideoQuality {
    var pixelCount: Int {
        return Int(resolution.width * resolution.height)
    }
    
    var aspectRatio: String {
        switch self {
        case .hd720, .hd1080:
            return "16:9"
        case .uhd4k:
            return "16:9"
        }
    }
    
    var avSessionPreset: AVCaptureSession.Preset {
        switch self {
        case .hd720:
            return .hd1280x720
        case .hd1080:
            return .hd1920x1080
        case .uhd4k:
            return .hd4K3840x2160
        }
    }
    
    var description: String {
        return rawValue
    }
    
    var shortDescription: String {
        switch self {
        case .hd720:
            return "720p"
        case .hd1080:
            return "1080p"
        case .uhd4k:
            return "4K"
        }
    }
    
    var bitRate: Int {
        switch self {
        case .hd720:
            return 5_000_000 // 5 Mbps
        case .hd1080:
            return 10_000_000 // 10 Mbps
        case .uhd4k:
            return 40_000_000 // 40 Mbps
        }
    }
    
    var recommendedFrameRates: [Int32] {
        switch self {
        case .hd720:
            return [24, 30, 60]
        case .hd1080:
            return [24, 30, 60, 120]
        case .uhd4k:
            return [24, 30, 60]
        }
    }
}

// MARK: - Camera Position

enum CameraDevicePosition: String, CaseIterable, Sendable, Codable {
    case front = "Front"
    case back = "Back"
    case wide = "Wide"
    case ultraWide = "Ultra Wide"
    case telephoto = "Telephoto"
    
    var avPosition: AVCaptureDevice.Position {
        switch self {
        case .front:
            return .front
        case .back, .wide, .ultraWide, .telephoto:
            return .back
        }
    }
    
    var deviceType: AVCaptureDevice.DeviceType {
        switch self {
        case .front:
            return .builtInWideAngleCamera
        case .back:
            return .builtInWideAngleCamera
        case .wide:
            return .builtInWideAngleCamera
        case .ultraWide:
            return .builtInUltraWideCamera
        case .telephoto:
            return .builtInTelephotoCamera
        }
    }
    
    var description: String {
        return rawValue
    }
    
    var icon: String {
        switch self {
        case .front:
            return "camera.fill"
        case .back:
            return "camera.rotate"
        case .wide:
            return "camera.viewfinder"
        case .ultraWide:
            return "camera.macro"
        case .telephoto:
            return "camera.aperture"
        }
    }
}

// MARK: - Focus Mode

enum CameraFocusMode: String, CaseIterable, Sendable, Codable {
    case locked = "Locked"
    case autoFocus = "Auto Focus"
    case continuousAutoFocus = "Continuous Auto Focus"
    case manual = "Manual"
    
    var avFocusMode: AVCaptureDevice.FocusMode {
        switch self {
        case .locked:
            return .locked
        case .autoFocus:
            return .autoFocus
        case .continuousAutoFocus:
            return .continuousAutoFocus
        case .manual:
            return .locked // Manual focus is handled differently
        }
    }
    
    var description: String {
        return rawValue
    }
    
    var icon: String {
        switch self {
        case .locked:
            return "lock.fill"
        case .autoFocus:
            return "target"
        case .continuousAutoFocus:
            return "target"
        case .manual:
            return "slider.horizontal.3"
        }
    }
}

// MARK: - Exposure Mode

enum CameraExposureMode: String, CaseIterable, Sendable, Codable {
    case locked = "Locked"
    case autoExpose = "Auto"
    case continuousAutoExposure = "Continuous Auto"
    case custom = "Custom"
    
    var avExposureMode: AVCaptureDevice.ExposureMode {
        switch self {
        case .locked:
            return .locked
        case .autoExpose:
            return .autoExpose
        case .continuousAutoExposure:
            return .continuousAutoExposure
        case .custom:
            return .custom
        }
    }
    
    var description: String {
        return rawValue
    }
    
    var icon: String {
        switch self {
        case .locked:
            return "lock.fill"
        case .autoExpose:
            return "sun.max.fill"
        case .continuousAutoExposure:
            return "sun.max.fill"
        case .custom:
            return "slider.horizontal.3"
        }
    }
}

// MARK: - White Balance Mode

enum CameraWhiteBalanceMode: String, CaseIterable, Sendable, Codable {
    case locked = "Locked"
    case continuousAutoWhiteBalance = "Continuous Auto"
    case autoWhiteBalance = "Auto"
    case daylight = "Daylight"
    case cloudy = "Cloudy"
    case tungsten = "Tungsten"
    case fluorescent = "Fluorescent"
    case incandescent = "Incandescent"
    case flash = "Flash"
    
    var avWhiteBalanceMode: AVCaptureDevice.WhiteBalanceMode {
        switch self {
        case .locked:
            return .locked
        case .continuousAutoWhiteBalance:
            return .continuousAutoWhiteBalance
        case .autoWhiteBalance:
            return .autoWhiteBalance
        case .daylight:
            return .locked // Custom white balance
        case .cloudy:
            return .locked // Custom white balance
        case .tungsten:
            return .locked // Custom white balance
        case .fluorescent:
            return .locked // Custom white balance
        case .incandescent:
            return .locked // Custom white balance
        case .flash:
            return .locked // Custom white balance
        }
    }
    
    var temperatureAndTint: AVCaptureDevice.WhiteBalanceTemperatureAndTintValues? {
        switch self {
        case .daylight:
            return AVCaptureDevice.WhiteBalanceTemperatureAndTintValues(
                temperature: 5200,
                tint: 0
            )
        case .cloudy:
            return AVCaptureDevice.WhiteBalanceTemperatureAndTintValues(
                temperature: 6000,
                tint: 0
            )
        case .tungsten:
            return AVCaptureDevice.WhiteBalanceTemperatureAndTintValues(
                temperature: 3200,
                tint: 0
            )
        case .fluorescent:
            return AVCaptureDevice.WhiteBalanceTemperatureAndTintValues(
                temperature: 4000,
                tint: 0
            )
        case .incandescent:
            return AVCaptureDevice.WhiteBalanceTemperatureAndTintValues(
                temperature: 2700,
                tint: 0
            )
        case .flash:
            return AVCaptureDevice.WhiteBalanceTemperatureAndTintValues(
                temperature: 5500,
                tint: 0
            )
        default:
            return nil
        }
    }
    
    var description: String {
        return rawValue
    }
    
    var icon: String {
        switch self {
        case .locked:
            return "lock.fill"
        case .continuousAutoWhiteBalance, .autoWhiteBalance:
            return "circle.lefthalf.filled"
        case .daylight:
            return "sun.max.fill"
        case .cloudy:
            return "cloud.fill"
        case .tungsten:
            return "lightbulb.fill"
        case .fluorescent:
            return "lightbulb"
        case .incandescent:
            return "lightbulb.2.fill"
        case .flash:
            return "bolt.fill"
        }
    }
}

// MARK: - Flash Mode

enum CameraFlashMode: String, CaseIterable, Sendable, Codable {
    case off = "Off"
    case on = "On"
    case auto = "Auto"
    case redEyeReduction = "Red Eye Reduction"
    
    var description: String {
        return rawValue
    }
    
    var icon: String {
        switch self {
        case .off:
            return "bolt.slash.fill"
        case .on:
            return "bolt.fill"
        case .auto:
            return "bolt.badge.automatic.fill"
        case .redEyeReduction:
            return "eye.fill"
        }
    }
    
    var isAvailable: Bool {
        // Check if flash is available on current device
        return AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)?.hasFlash ?? false
    }
}

// MARK: - Camera Audio Quality

enum CameraAudioQuality: String, CaseIterable, Sendable, Codable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"
    case lossless = "Lossless"
    
    var sampleRate: Double {
        switch self {
        case .low:
            return 22050.0
        case .medium:
            return 44100.0
        case .high:
            return 48000.0
        case .lossless:
            return 96000.0
        }
    }
    
    var bitRate: Int {
        switch self {
        case .low:
            return 64000 // 64 kbps
        case .medium:
            return 128000 // 128 kbps
        case .high:
            return 256000 // 256 kbps
        case .lossless:
            return 320000 // 320 kbps
        }
    }
    
    var channels: Int {
        switch self {
        case .low, .medium:
            return 1 // Mono
        case .high, .lossless:
            return 2 // Stereo
        }
    }
    
    var description: String {
        return rawValue
    }
    
    var icon: String {
        switch self {
        case .low:
            return "waveform.path.ecg"
        case .medium:
            return "waveform.path"
        case .high:
            return "waveform"
        case .lossless:
            return "waveform.and.person.filled"
        }
    }
}

// MARK: - Color Space

enum ColorSpace: String, CaseIterable, Sendable, Codable {
    case sRGB = "sRGB"
    case p3 = "P3"
    case rec2020 = "Rec.2020"
    case proPhoto = "Pro Photo"
    
    var avColorSpace: AVCaptureColorSpace {
        switch self {
        case .sRGB:
            return AVCaptureColorSpace.sRGB
        case .p3:
            return AVCaptureColorSpace.p3_D65
        case .rec2020:
            return AVCaptureColorSpace.rec2020
        case .proPhoto:
            return AVCaptureColorSpace.P3_D65 // Fallback to P3
        }
    }
    
    var description: String {
        return rawValue
    }
    
    var icon: String {
        switch self {
        case .sRGB:
            return "circle.fill"
        case .p3:
            return "circle.lefthalf.filled"
        case .rec2020:
            return "circle.righthalf.filled"
        case .proPhoto:
            return "camera.aperture"
        }
    }
}

// MARK: - Color Filter

enum ColorFilter: String, CaseIterable, Sendable, Codable {
    case none = "None"
    case vivid = "Vivid"
    case dramatic = "Dramatic"
    case warm = "Warm"
    case cool = "Cool"
    case blackAndWhite = "Black & White"
    case sepia = "Sepia"
    case vintage = "Vintage"
    
    var description: String {
        return rawValue
    }
    
    var icon: String {
        switch self {
        case .none:
            return "circle"
        case .vivid:
            return "paintpalette.fill"
        case .dramatic:
            return "theatermasks.fill"
        case .warm:
            return "sun.max.fill"
        case .cool:
            return "snowflake"
        case .blackAndWhite:
            return "circle.fill"
        case .sepia:
            return "photo.artframe"
        case .vintage:
            return "camera.macro"
        }
    }
}

// MARK: - Dynamic Range

enum DynamicRange: String, CaseIterable, Sendable, Codable {
    case sdr = "SDR"
    case hdr10 = "HDR10"
    case dolbyVision = "Dolby Vision"
    case hdrHLG = "HDR HLG"
    
    var description: String {
        return rawValue
    }
    
    var icon: String {
        switch self {
        case .sdr:
            return "tv"
        case .hdr10:
            return "tv.and.mediabox"
        case .dolbyVision:
            return "tv.and.hifispeaker.fill"
        case .hdrHLG:
            return "tv.circle.fill"
        }
    }
}

// MARK: - Video Output Format

enum VideoOutputFormat: String, CaseIterable, Sendable, Codable {
    case mp4 = "MP4"
    case mov = "MOV"
    case hevc = "HEVC"
    case proRes = "ProRes"
    
    var avFileType: AVFileType {
        switch self {
        case .mp4:
            return .mp4
        case .mov:
            return .mov
        case .hevc:
            return .mp4 // HEVC is stored in MP4 container
        case .proRes:
            return .mov
        }
    }
    
    var codec: AVVideoCodecType {
        switch self {
        case .mp4:
            return .h264
        case .mov:
            return .h264
        case .hevc:
            return .hevc
        case .proRes:
            return .proRes422HQ
        }
    }
    
    var description: String {
        return rawValue
    }
    
    var icon: String {
        switch self {
        case .mp4:
            return "video.fill"
        case .mov:
            return "video.circle.fill"
        case .hevc:
            return "video.badge.plus"
        case .proRes:
            return "video.bubble.left.fill"
        }
    }
    
    var supportsHDR: Bool {
        switch self {
        case .mp4, .mov:
            return false
        case .hevc, .proRes:
            return true
        }
    }
}

// MARK: - Preview Quality

enum PreviewQuality: String, CaseIterable, Sendable, Codable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"
    case ultra = "Ultra"
    
    var resolution: CGSize {
        switch self {
        case .low:
            return CGSize(width: 320, height: 240)
        case .medium:
            return CGSize(width: 640, height: 480)
        case .high:
            return CGSize(width: 1280, height: 720)
        case .ultra:
            return CGSize(width: 1920, height: 1080)
        }
    }
    
    var description: String {
        return rawValue
    }
    
    var icon: String {
        switch self {
        case .low:
            return "rectangle"
        case .medium:
            return "rectangle.fill"
        case .high:
            return "rectangle.stack.fill"
        case .ultra:
            return "rectangle.stack.badge.plus"
        }
    }
}

// MARK: - Camera Device Extensions

extension AVCaptureDevice {
    
    var supportsPortraitMode: Bool {
        return deviceType == .builtInWideAngleCamera && position == .back
    }
    
    var supportsCinematicMode: Bool {
        return deviceType == .builtInWideAngleCamera && position == .back
    }
    
    var supportsNightMode: Bool {
        return deviceType == .builtInWideAngleCamera && position == .back
    }
    
    var supportsMultiCam: Bool {
        return supportsMulticam
    }
    
    var supportsHDR: Bool {
        return activeFormat.supportedColorSpaces.contains(.p3_D65)
    }
    
    var supportsProRes: Bool {
        return activeFormat.supportedVideoCodecs.contains(.proRes422HQ)
    }
    
    var supportsHEVC: Bool {
        return activeFormat.supportedVideoCodecs.contains(.hevc)
    }
    
    var maxFrameRate: Double {
        return activeFormat.videoSupportedFrameRateRanges.max()?.maxFrameRate ?? 30.0
    }
    
    var minFrameRate: Double {
        return activeFormat.videoSupportedFrameRateRanges.min()?.minFrameRate ?? 1.0
    }
    
    var maxZoomFactor: Float {
        return activeFormat.videoMaxZoomFactor
    }
    
    var hasOpticalImageStabilization: Bool {
        return activeVideoStabilizationModes.contains(.optical)
    }
    
    var hasCinematicStabilization: Bool {
        return activeVideoStabilizationModes.contains(.cinematic)
    }
    
    func supportsQuality(_ quality: VideoQuality) -> Bool {
        return supportsSessionPreset(quality.avSessionPreset)
    }
    
    func supportsFrameRate(_ frameRate: Int32) -> Bool {
        return activeFormat.videoSupportedFrameRateRanges.contains { range in
            range.minFrameRate...range.maxFrameRate ~= Double(frameRate)
        }
    }
    
    func supportsColorSpace(_ colorSpace: ColorSpace) -> Bool {
        return activeFormat.supportedColorSpaces.contains(colorSpace.avColorSpace)
    }
    
    func supportsCodec(_ codec: AVVideoCodecType) -> Bool {
        return activeFormat.supportedVideoCodecs.contains(codec)
    }
}

// MARK: - Camera Feature Support

struct CameraFeatureSupport: Sendable {
    let deviceType: AVCaptureDevice.DeviceType
    let position: AVCaptureDevice.Position
    
    var supportsPortraitMode: Bool {
        return deviceType == .builtInWideAngleCamera && position == .back
    }
    
    var supportsCinematicMode: Bool {
        return deviceType == .builtInWideAngleCamera && position == .back
    }
    
    var supportsNightMode: Bool {
        return deviceType == .builtInWideAngleCamera && position == .back
    }
    
    var supportsMultiCam: Bool {
        return true // Most modern devices support multi-cam
    }
    
    var supportsHDR: Bool {
        return true // Most modern devices support HDR
    }
    
    var supportsProRes: Bool {
        return deviceType == .builtInWideAngleCamera && position == .back
    }
    
    var supportsHEVC: Bool {
        return true // Most modern devices support HEVC
    }
    
    var supportsOpticalZoom: Bool {
        return deviceType == .builtInTelephotoCamera
    }
    
    var supportsUltraWide: Bool {
        return deviceType == .builtInUltraWideCamera
    }
    
    var supportsFlash: Bool {
        return deviceType == .builtInWideAngleCamera && position == .back
    }
    
    var supportsOpticalImageStabilization: Bool {
        return deviceType == .builtInWideAngleCamera && position == .back
    }
    
    var supportsCinematicStabilization: Bool {
        return deviceType == .builtInWideAngleCamera && position == .back
    }
    
    static func forDevice(_ device: AVCaptureDevice) -> CameraFeatureSupport {
        return CameraFeatureSupport(
            deviceType: device.deviceType,
            position: device.position
        )
    }
}

// MARK: - Camera Capabilities

struct CameraCapabilities: Sendable {
    let supportedQualities: [VideoQuality]
    let supportedFrameRates: [Int32]
    let supportedColorSpaces: [ColorSpace]
    let supportedCodecs: [AVVideoCodecType]
    let maxZoomFactor: Float
    let hasFlash: Bool
    let hasOpticalImageStabilization: Bool
    let hasCinematicStabilization: Bool
    let supportsPortraitMode: Bool
    let supportsCinematicMode: Bool
    let supportsNightMode: Bool
    let supportsMultiCam: Bool
    let supportsHDR: Bool
    let supportsProRes: Bool
    let supportsHEVC: Bool
    
    static func forDevice(_ device: AVCaptureDevice) -> CameraCapabilities {
        let supportedQualities = VideoQuality.allCases.filter { quality in
            device.supportsSessionPreset(quality.avSessionPreset)
        }
        
        let supportedFrameRates = [24, 30, 60, 120, 240].filter { frameRate in
            device.supportsFrameRate(frameRate)
        }
        
        let supportedColorSpaces: [ColorSpace] = [.sRGB, .p3, .rec2020, .proPhoto].filter { colorSpace in
            device.supportsColorSpace(colorSpace)
        }
        
        let supportedCodecs: [AVVideoCodecType] = [.h264, .hevc, .proRes422HQ].filter { codec in
            device.supportsCodec(codec)
        }
        
        let featureSupport = CameraFeatureSupport.forDevice(device)
        
        return CameraCapabilities(
            supportedQualities: supportedQualities,
            supportedFrameRates: supportedFrameRates,
            supportedColorSpaces: supportedColorSpaces,
            supportedCodecs: supportedCodecs,
            maxZoomFactor: device.maxZoomFactor,
            hasFlash: device.hasFlash,
            hasOpticalImageStabilization: device.hasOpticalImageStabilization,
            hasCinematicStabilization: device.hasCinematicStabilization,
            supportsPortraitMode: featureSupport.supportsPortraitMode,
            supportsCinematicMode: featureSupport.supportsCinematicMode,
            supportsNightMode: featureSupport.supportsNightMode,
            supportsMultiCam: featureSupport.supportsMultiCam,
            supportsHDR: featureSupport.supportsHDR,
            supportsProRes: featureSupport.supportsProRes,
            supportsHEVC: featureSupport.supportsHEVC
        )
    }
}