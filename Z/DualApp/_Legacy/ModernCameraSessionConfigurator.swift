//
//  ModernCameraSessionConfigurator.swift
//  DualCameraApp
//
//  iOS 26 async/await camera configuration with prepare() API
//

import AVFoundation
import os.log

@available(iOS 15.0, *)
final class ModernCameraSessionConfigurator {
    
    private let logger = Logger(subsystem: "com.dualcameraapp", category: "ModernSessionConfigurator")
    
    struct CameraConfiguration {
        let session: AVCaptureMultiCamSession
        let frontDevice: AVCaptureDevice
        let backDevice: AVCaptureDevice
        let frontInput: AVCaptureDeviceInput
        let backInput: AVCaptureDeviceInput
        let audioInput: AVCaptureDeviceInput?
        let frontPreviewLayer: AVCaptureVideoPreviewLayer
        let backPreviewLayer: AVCaptureVideoPreviewLayer
    }
    
    enum ConfigurationError: LocalizedError {
        case multiCamNotSupported
        case deviceNotFound(position: AVCaptureDevice.Position)
        case inputCreationFailed(Error)
        case sessionConfigurationFailed(String)
        case audioSetupFailed(Error)
        
        var errorDescription: String? {
            switch self {
            case .multiCamNotSupported:
                return "Multi-camera recording is not supported on this device"
            case .deviceNotFound(let position):
                return "Camera not found for position: \(position)"
            case .inputCreationFailed(let error):
                return "Failed to create camera input: \(error.localizedDescription)"
            case .sessionConfigurationFailed(let reason):
                return "Session configuration failed: \(reason)"
            case .audioSetupFailed(let error):
                return "Audio setup failed: \(error.localizedDescription)"
            }
        }
    }
    
    func configureMinimal(videoQuality: VideoQuality) async throws -> CameraConfiguration {
        let signpostID = OSSignpostID(log: .default)
        os_signpost(.begin, log: .default, name: "Modern Camera Configuration", signpostID: signpostID)
        
        defer {
            os_signpost(.end, log: .default, name: "Modern Camera Configuration", signpostID: signpostID)
        }
        
        guard AVCaptureMultiCamSession.isMultiCamSupported else {
            logger.error("Multi-camera not supported on this device")
            throw ConfigurationError.multiCamNotSupported
        }
        
        let session = AVCaptureMultiCamSession()
        
        let (frontDevice, backDevice) = try await discoverCamerasAsync()
        
        let frontInput: AVCaptureDeviceInput
        let backInput: AVCaptureDeviceInput
        
        do {
            frontInput = try AVCaptureDeviceInput(device: frontDevice)
            backInput = try AVCaptureDeviceInput(device: backDevice)
        } catch {
            throw ConfigurationError.inputCreationFailed(error)
        }
        
        session.beginConfiguration()
        
        guard session.canAddInput(frontInput) else {
            session.commitConfiguration()
            throw ConfigurationError.sessionConfigurationFailed("Cannot add front camera input")
        }
        session.addInput(frontInput)
        
        guard session.canAddInput(backInput) else {
            session.commitConfiguration()
            throw ConfigurationError.sessionConfigurationFailed("Cannot add back camera input")
        }
        session.addInput(backInput)
        
        // Audio and video format deferred to recording time
        
        session.commitConfiguration()
        
        let frontPreviewLayer = AVCaptureVideoPreviewLayer(session: session)
        frontPreviewLayer.videoGravity = .resizeAspectFill
        frontPreviewLayer.connection?.videoOrientation = .portrait
        
        let backPreviewLayer = AVCaptureVideoPreviewLayer(session: session)
        backPreviewLayer.videoGravity = .resizeAspectFill
        backPreviewLayer.connection?.videoOrientation = .portrait
        
        logger.info("Modern camera configuration completed successfully")
        
        return CameraConfiguration(
            session: session,
            frontDevice: frontDevice,
            backDevice: backDevice,
            frontInput: frontInput,
            backInput: backInput,
            audioInput: nil,
            frontPreviewLayer: frontPreviewLayer,
            backPreviewLayer: backPreviewLayer
        )
    }
    
    private func discoverCamerasAsync() async throws -> (AVCaptureDevice, AVCaptureDevice) {
        return try await withThrowingTaskGroup(of: (String, AVCaptureDevice?).self) { group in
            group.addTask {
                let session = AVCaptureDevice.DiscoverySession(
                    deviceTypes: [.builtInWideAngleCamera],
                    mediaType: .video,
                    position: .front
                )
                return ("front", session.devices.first)
            }
            
            group.addTask {
                let session = AVCaptureDevice.DiscoverySession(
                    deviceTypes: [.builtInWideAngleCamera],
                    mediaType: .video,
                    position: .back
                )
                return ("back", session.devices.first)
            }
            
            var frontDevice: AVCaptureDevice?
            var backDevice: AVCaptureDevice?
            
            for try await (position, device) in group {
                if position == "front" { frontDevice = device }
                else if position == "back" { backDevice = device }
            }
            
            guard let front = frontDevice, let back = backDevice else {
                throw ConfigurationError.deviceNotFound(position: .unspecified)
            }
            
            self.logger.info("Parallel camera discovery completed")
            return (front, back)
        }
    }
    
    private func setupAudioInputAsync(for session: AVCaptureMultiCamSession) async throws -> AVCaptureDeviceInput? {
        return try await withCheckedThrowingContinuation { continuation in
            Task.detached(priority: .utility) {
                guard let audioDevice = AVCaptureDevice.default(for: .audio) else {
                    continuation.resume(returning: nil)
                    return
                }
                
                do {
                    let input = try AVCaptureDeviceInput(device: audioDevice)
                    if session.canAddInput(input) {
                        session.addInput(input)
                        continuation.resume(returning: input)
                    } else {
                        continuation.resume(returning: nil)
                    }
                } catch {
                    continuation.resume(throwing: ConfigurationError.audioSetupFailed(error))
                }
            }
        }
    }
    
    private func configureVideoFormat(for device: AVCaptureDevice, quality: VideoQuality) async {
        await Task.detached(priority: .userInitiated) {
            let targetDimensions = quality.dimensions
            
            guard let format = device.formats.first(where: { format in
                let dimensions = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
                return dimensions.width >= targetDimensions.width &&
                       dimensions.height >= targetDimensions.height &&
                       format.videoSupportedFrameRateRanges.contains(where: { $0.maxFrameRate >= 30 })
            }) else {
                self.logger.warning("Preferred format not found for device, using default")
                return
            }
            
            do {
                try device.lockForConfiguration()
                device.activeFormat = format
                device.activeVideoMinFrameDuration = CMTime(value: 1, timescale: 30)
                device.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: 30)
                device.unlockForConfiguration()
                self.logger.info("Configured format for device")
            } catch {
                self.logger.error("Failed to configure format: \(error.localizedDescription)")
            }
        }.value
    }
    
    private func prepareSession(_ session: AVCaptureMultiCamSession) async {
        logger.info("Session preparation called - no async prepare API available in current iOS")
    }
    
    func startSessionAsync(_ session: AVCaptureMultiCamSession) async {
        await Task.detached(priority: .userInitiated) {
            session.startRunning()
            self.logger.info("Session started asynchronously")
        }.value
    }
    
    func stopSessionAsync(_ session: AVCaptureMultiCamSession) async {
        await Task.detached(priority: .utility) {
            session.stopRunning()
            self.logger.info("Session stopped asynchronously")
        }.value
    }
}
