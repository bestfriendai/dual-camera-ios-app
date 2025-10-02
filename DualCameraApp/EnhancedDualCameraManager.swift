//
//  EnhancedDualCameraManager.swift
//  DualCameraApp
//
//  Modern dual camera implementation with iOS 17+ features
//

import AVFoundation
import UIKit
import CoreVideo
import Metal

@available(iOS 17.0, *)
class EnhancedDualCameraManager: NSObject {
    
    // MARK: - Modern Properties
    
    private let session = AVCaptureMultiCamSession()
    private let sessionQueue = DispatchQueue(label: "EnhancedDualCamera.SessionQueue", qos: .userInitiated)
    
    // Enhanced device discovery
    private var ultraWideCamera: AVCaptureDevice?
    private var telephotoCamera: AVCaptureDevice?
    private var liDARScanner: AVCaptureDevice?
    
    // Modern outputs
    private var proResOutput: AVCaptureMovieFileOutput?
    private var spatialVideoOutput: AVCaptureMovieFileOutput?
    private var depthDataOutput: AVCaptureDepthDataOutput?
    private var portraitModeOutput: AVCaptureMovieFileOutput?
    private var cinematicModeOutput: AVCaptureMovieFileOutput?
    
    // AI-powered features
    private var sceneDetector: AVSceneDetector?
    private var realTimeEffectsProcessor: RealTimeEffectsProcessor?
    
    // Performance optimization
    private var adaptiveQualityController: AdaptiveQualityController?
    private var thermalManager: ThermalManager?
    
    // MARK: - Enhanced Setup
    
    func setupEnhancedCameras() {
        sessionQueue.async { [weak self] in
            self?.discoverModernDevices()
            self?.configureEnhancedSession()
            self?.setupAIFeatures()
            self?.startSession()
        }
    }
    
    private func discoverModernDevices() {
        // Discover all available cameras with modern capabilities
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .builtInUltraWideCamera, .builtInTelephotoCamera, .builtInLiDARDepthCamera],
            mediaType: .video,
            position: .unspecified
        )
        
        for device in discoverySession.devices {
            switch device.deviceType {
            case .builtInUltraWideCamera:
                if device.position == .back {
                    ultraWideCamera = device
                }
            case .builtInTelephotoCamera:
                telephotoCamera = device
            case .builtInLiDARDepthCamera:
                liDARScanner = device
            default:
                break
            }
        }
        
        print("Discovered modern cameras: UltraWide: \(ultraWideCamera?.localizedName ?? "None"), Telephoto: \(telephotoCamera?.localizedName ?? "None"), LiDAR: \(liDARScanner?.localizedName ?? "None")")
    }
    
    private func configureEnhancedSession() {
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        
        // Configure multi-camera setup with enhanced features
        setupMultiCameraInputs()
        setupModernOutputs()
        setupAdvancedConnections()
        configureProfessionalFeatures()
    }
    
    private func setupMultiCameraInputs() {
        // Setup front and back cameras with enhanced capabilities
        guard let frontCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
              let backCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            print("Failed to discover basic cameras")
            return
        }
        
        do {
            let frontInput = try AVCaptureDeviceInput(device: frontCamera)
            let backInput = try AVCaptureDeviceInput(device: backCamera)
            
            if session.canAddInput(frontInput) {
                session.addInputWithNoConnections(frontInput)
            }
            
            if session.canAddInput(backInput) {
                session.addInputWithNoConnections(backInput)
            }
            
            // Add ultra-wide and telephoto if available
            if let ultraWide = ultraWideCamera {
                let ultraWideInput = try AVCaptureDeviceInput(device: ultraWide)
                if session.canAddInput(ultraWideInput) {
                    session.addInputWithNoConnections(ultraWideInput)
                }
            }
            
            if let telephoto = telephotoCamera {
                let telephotoInput = try AVCaptureDeviceInput(device: telephoto)
                if session.canAddInput(telephotoInput) {
                    session.addInputWithNoConnections(telephotoInput)
                }
            }
            
        } catch {
            print("Failed to setup camera inputs: \(error)")
        }
    }
    
    private func setupModernOutputs() {
        // Setup ProRes output for professional recording
        if let backCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
           let proRes = ModernCameraFeatures.configureProResOutput(for: session, device: backCamera) {
            proResOutput = proRes
            if session.canAddOutput(proRes) {
                session.addOutputWithNoConnections(proRes)
            }
        }
        
        // Setup spatial video for Vision Pro
        if let spatial = ModernCameraFeatures.configureSpatialVideoOutput(for: session) {
            spatialVideoOutput = spatial
            if session.canAddOutput(spatial) {
                session.addOutputWithNoConnections(spatial)
            }
        }
        
        // Setup depth data output
        if let backCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
           let depth = ModernCameraFeatures.configureDepthDataOutput(for: session, device: backCamera) {
            depthDataOutput = depth
            depth.setDelegate(self, queue: DispatchQueue(label: "DepthDataQueue"))
            if session.canAddOutput(depth) {
                session.addOutputWithNoConnections(depth)
            }
        }
        
        // Setup portrait mode
        if let backCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
           let portrait = ModernCameraFeatures.configurePortraitModeOutput(for: session, device: backCamera) {
            portraitModeOutput = portrait
            if session.canAddOutput(portrait) {
                session.addOutputWithNoConnections(portrait)
            }
        }
        
        // Setup cinematic mode
        if let backCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
           let cinematic = ModernCameraFeatures.configureCinematicModeOutput(for: session, device: backCamera) {
            cinematicModeOutput = cinematic
            if session.canAddOutput(cinematic) {
                session.addOutputWithNoConnections(cinematic)
            }
        }
    }
    
    private func setupAdvancedConnections() {
        // Create optimized connections for all inputs and outputs
        guard let frontInput = session.inputs.first(where: { ($0 as? AVCaptureDeviceInput)?.device.position == .front }) as? AVCaptureDeviceInput,
              let backInput = session.inputs.first(where: { ($0 as? AVCaptureDeviceInput)?.device.position == .back }) as? AVCaptureDeviceInput else {
            return
        }
        
        // Get video ports
        let frontVideoPort = frontInput.ports(for: .video, sourceDeviceType: .builtInWideAngleCamera, sourceDevicePosition: .front).first!
        let backVideoPort = backInput.ports(for: .video, sourceDeviceType: .builtInWideAngleCamera, sourceDevicePosition: .back).first!
        
        // Connect outputs with enhanced settings
        connectOutputsWithEnhancedSettings(frontPort: frontVideoPort, backPort: backVideoPort)
    }
    
    private func connectOutputsWithEnhancedSettings(frontPort: AVCaptureInput.Port, backPort: AVCaptureInput.Port) {
        // Connect ProRes output
        if let proRes = proResOutput {
            let proResConnection = AVCaptureConnection(inputPorts: [backVideoPort], output: proRes)
            configureAdvancedConnection(proResConnection)
            if session.canAddConnection(proResConnection) {
                session.addConnection(proResConnection)
            }
        }
        
        // Connect spatial video output
        if let spatial = spatialVideoOutput {
            let spatialConnection = AVCaptureConnection(inputPorts: [backVideoPort], output: spatial)
            configureAdvancedConnection(spatialConnection)
            if session.canAddConnection(spatialConnection) {
                session.addConnection(spatialConnection)
            }
        }
        
        // Connect depth data output
        if let depth = depthDataOutput {
            let depthConnection = AVCaptureConnection(inputPorts: [backVideoPort], output: depth)
            if session.canAddConnection(depthConnection) {
                session.addConnection(depthConnection)
            }
        }
        
        // Connect portrait mode output
        if let portrait = portraitModeOutput {
            let portraitConnection = AVCaptureConnection(inputPorts: [backVideoPort], output: portrait)
            configureAdvancedConnection(portraitConnection)
            if session.canAddConnection(portraitConnection) {
                session.addConnection(portraitConnection)
            }
        }
        
        // Connect cinematic mode output
        if let cinematic = cinematicModeOutput {
            let cinematicConnection = AVCaptureConnection(inputPorts: [backVideoPort], output: cinematic)
            configureAdvancedConnection(cinematicConnection)
            if session.canAddConnection(cinematicConnection) {
                session.addConnection(cinematicConnection)
            }
        }
    }
    
    private func configureAdvancedConnection(_ connection: AVCaptureConnection) {
        // Configure connection with advanced settings
        if connection.isVideoOrientationSupported {
            connection.videoOrientation = .portrait
        }
        
        if connection.isVideoStabilizationSupported {
            if #available(iOS 17.0, *) {
                connection.preferredVideoStabilizationMode = .cinematicExtended
            } else {
                connection.preferredVideoStabilizationMode = .cinematic
            }
        }
        
        // Enable high resolution if supported
        if connection.isVideoHDREnabledSupported {
            connection.isVideoHDREnabled = true
        }
    }
    
    private func configureProfessionalFeatures() {
        // Configure professional camera features
        guard let backCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else { return }
        
        do {
            try backCamera.lockForConfiguration()
            
            // Enable professional features
            if #available(iOS 17.0, *) {
                // Enable AI-powered features
                ModernCameraFeatures.configureAICameraFeatures(for: backCamera)
                
                // Configure for best quality
                backCamera.automaticallyAdjustsVideoHDREnabled = true
                backCamera.automaticallyAdjustsFaceDrivenAutoFocusEnabled = true
                
                // Enable low light boost if available
                if backCamera.isLowLightBoostSupported {
                    backCamera.automaticallyEnablesLowLightBoostWhenAvailable = true
                }
            }
            
            backCamera.unlockForConfiguration()
        } catch {
            print("Failed to configure professional features: \(error)")
        }
    }
    
    private func setupAIFeatures() {
        // Setup AI-powered scene detection
        if #available(iOS 18.0, *) {
            sceneDetector = AVSceneDetector()
            sceneDetector?.delegate = self
        }
        
        // Setup real-time effects processor
        realTimeEffectsProcessor = RealTimeEffectsProcessor()
        
        // Setup adaptive quality controller
        adaptiveQualityController = AdaptiveQualityController()
        
        // Setup thermal manager
        thermalManager = ThermalManager()
    }
    
    private func startSession() {
        if !session.isRunning {
            session.startRunning()
            print("Enhanced dual camera session started")
        }
    }
    
    // MARK: - Modern Recording Methods
    
    func startProResRecording(to url: URL) {
        guard let proRes = proResOutput else {
            print("ProRes output not available")
            return
        }
        
        sessionQueue.async {
            proRes.startRecording(to: url, recordingDelegate: self)
        }
    }
    
    func startSpatialVideoRecording(to url: URL) {
        guard let spatial = spatialVideoOutput else {
            print("Spatial video output not available")
            return
        }
        
        sessionQueue.async {
            spatial.startRecording(to: url, recordingDelegate: self)
        }
    }
    
    func startPortraitModeRecording(to url: URL) {
        guard let portrait = portraitModeOutput else {
            print("Portrait mode output not available")
            return
        }
        
        sessionQueue.async {
            portrait.startRecording(to: url, recordingDelegate: self)
        }
    }
    
    func startCinematicModeRecording(to url: URL) {
        guard let cinematic = cinematicModeOutput else {
            print("Cinematic mode output not available")
            return
        }
        
        sessionQueue.async {
            cinematic.startRecording(to: url, recordingDelegate: self)
        }
    }
    
    // MARK: - Advanced Camera Controls
    
    func switchToUltraWideCamera() {
        guard let ultraWide = ultraWideCamera else { return }
        
        sessionQueue.async {
            // Implement camera switching logic
            self.switchToDevice(ultraWide)
        }
    }
    
    func switchToTelephotoCamera() {
        guard let telephoto = telephotoCamera else { return }
        
        sessionQueue.async {
            // Implement camera switching logic
            self.switchToDevice(telephoto)
        }
    }
    
    private func switchToDevice(_ device: AVCaptureDevice) {
        // Implement smooth camera switching
        do {
            try device.lockForConfiguration()
            
            // Configure device for optimal performance
            if #available(iOS 17.0, *) {
                ModernCameraFeatures.configureAICameraFeatures(for: device)
            }
            
            device.unlockForConfiguration()
        } catch {
            print("Failed to switch camera: \(error)")
        }
    }
    
    // MARK: - Performance Optimization
    
    func optimizeForPerformance() {
        adaptiveQualityController?.enableAdaptiveQuality()
        thermalManager?.startMonitoring()
    }
    
    func optimizeForQuality() {
        adaptiveQualityController?.disableAdaptiveQuality()
        thermalManager?.stopMonitoring()
    }
}

// MARK: - AVCaptureDepthDataOutputDelegate

@available(iOS 17.0, *)
extension EnhancedDualCameraManager: AVCaptureDepthDataOutputDelegate {
    func depthDataOutput(_ output: AVCaptureDepthDataOutput, didOutput depthData: AVDepthData, timestamp: CMTime, connection: AVCaptureConnection) {
        // Process depth data for 3D effects, segmentation, etc.
        processDepthData(depthData, timestamp: timestamp)
    }
    
    private func processDepthData(_ depthData: AVDepthData, timestamp: CMTime) {
        // Convert depth data to usable format
        guard let pixelBuffer = depthData.depthDataPixelBuffer else { return }
        
        // Use depth data for advanced features
        realTimeEffectsProcessor?.processDepthData(pixelBuffer, timestamp: timestamp)
    }
}

// MARK: - AVSceneDetectorDelegate

@available(iOS 18.0, *)
extension EnhancedDualCameraManager: AVSceneDetectorDelegate {
    func sceneDetector(_ detector: AVSceneDetector, didDetect scene: AVScene) {
        // Handle scene detection results
        handleSceneDetection(scene)
    }
    
    private func handleSceneDetection(_ scene: AVScene) {
        // Adjust camera settings based on detected scene
        switch scene.type {
        case .portrait:
            // Optimize for portrait scenes
            break
        case .landscape:
            // Optimize for landscape scenes
            break
        case .food:
            // Optimize for food photography
            break
        case .document:
            // Optimize for document scanning
            break
        default:
            break
        }
    }
}

// MARK: - AVCaptureFileOutputRecordingDelegate

@available(iOS 17.0, *)
extension EnhancedDualCameraManager: AVCaptureFileOutputRecordingDelegate {
    func fileOutput(_ output: AVCaptureFileOutput, didStartRecordingTo fileURL: URL, from connections: [AVCaptureConnection]) {
        print("Started recording to: \(fileURL.lastPathComponent)")
    }
    
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        if let error = error {
            print("Recording error: \(error)")
        } else {
            print("Finished recording to: \(outputFileURL.lastPathComponent)")
        }
    }
}

// MARK: - Supporting Classes

class RealTimeEffectsProcessor {
    func processDepthData(_ pixelBuffer: CVPixelBuffer, timestamp: CMTime) {
        // Process depth data for real-time effects
    }
}

class AdaptiveQualityController {
    func enableAdaptiveQuality() {
        // Enable adaptive quality based on performance
    }
    
    func disableAdaptiveQuality() {
        // Disable adaptive quality
    }
}

class ThermalManager {
    func startMonitoring() {
        // Start thermal monitoring
    }
    
    func stopMonitoring() {
        // Stop thermal monitoring
    }
}