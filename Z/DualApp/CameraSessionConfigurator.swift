// Dual Camera App
import AVFoundation
import os.log

final class CameraSessionConfigurator {
    
    private let logger = Logger(subsystem: "com.dualcameraapp", category: "SessionConfigurator")
    private let sessionQueue = DispatchQueue(label: "CameraSessionConfigurator.Queue")
    
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
    
    func configure(videoQuality: VideoQuality, completion: @escaping (Result<CameraConfiguration, ConfigurationError>) -> Void) {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            
            let signpostID = OSSignpostID(log: .default)
            os_signpost(.begin, log: .default, name: "Camera Configuration", signpostID: signpostID)
            
            do {
                let config = try self.performConfiguration(videoQuality: videoQuality)
                os_signpost(.end, log: .default, name: "Camera Configuration", signpostID: signpostID)
                DispatchQueue.main.async {
                    completion(.success(config))
                }
            } catch let error as ConfigurationError {
                os_signpost(.end, log: .default, name: "Camera Configuration", signpostID: signpostID, "Error: %{public}@", error.localizedDescription)
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            } catch {
                os_signpost(.end, log: .default, name: "Camera Configuration", signpostID: signpostID, "Unexpected error")
                DispatchQueue.main.async {
                    completion(.failure(.sessionConfigurationFailed(error.localizedDescription)))
                }
            }
        }
    }
    
    private func performConfiguration(videoQuality: VideoQuality) throws -> CameraConfiguration {
        guard AVCaptureMultiCamSession.isMultiCamSupported else {
            logger.error("Multi-camera not supported on this device")
            throw ConfigurationError.multiCamNotSupported
        }
        
        let session = AVCaptureMultiCamSession()
        
        guard let frontDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) else {
            throw ConfigurationError.deviceNotFound(position: .front)
        }
        
        guard let backDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            throw ConfigurationError.deviceNotFound(position: .back)
        }
        
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
        
        var audioInput: AVCaptureDeviceInput?
        if let audioDevice = AVCaptureDevice.default(for: .audio) {
            do {
                let input = try AVCaptureDeviceInput(device: audioDevice)
                if session.canAddInput(input) {
                    session.addInput(input)
                    audioInput = input
                }
            } catch {
                logger.warning("Audio setup failed, continuing without audio: \(error.localizedDescription)")
            }
        }
        
        configureVideoFormat(for: frontDevice, quality: videoQuality)
        configureVideoFormat(for: backDevice, quality: videoQuality)
        
        session.commitConfiguration()
        
        let frontPreviewLayer = AVCaptureVideoPreviewLayer(session: session)
        frontPreviewLayer.videoGravity = .resizeAspectFill
        frontPreviewLayer.connection?.videoOrientation = .portrait
        
        let backPreviewLayer = AVCaptureVideoPreviewLayer(session: session)
        backPreviewLayer.videoGravity = .resizeAspectFill
        backPreviewLayer.connection?.videoOrientation = .portrait
        

        
        logger.info("Camera configuration completed successfully")
        
        return CameraConfiguration(
            session: session,
            frontDevice: frontDevice,
            backDevice: backDevice,
            frontInput: frontInput,
            backInput: backInput,
            audioInput: audioInput,
            frontPreviewLayer: frontPreviewLayer,
            backPreviewLayer: backPreviewLayer
        )
    }
    
    private func configureVideoFormat(for device: AVCaptureDevice, quality: VideoQuality) {
        let targetDimensions = quality.dimensions
        
        guard let format = device.formats.first(where: { format in
            let dimensions = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
            return CGFloat(dimensions.width) >= targetDimensions.width &&
                   CGFloat(dimensions.height) >= targetDimensions.height &&
                   format.videoSupportedFrameRateRanges.contains(where: { $0.maxFrameRate >= 30 })
        }) else {
            logger.warning("Preferred format not found for device, using default")
            return
        }
        
        do {
            try device.lockForConfiguration()
            device.activeFormat = format
            device.activeVideoMinFrameDuration = CMTime(value: 1, timescale: 30)
            device.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: 30)
            device.unlockForConfiguration()
            logger.info("Configured format for device")
        } catch {
            logger.error("Failed to configure format: \(error.localizedDescription)")
        }
    }
}
