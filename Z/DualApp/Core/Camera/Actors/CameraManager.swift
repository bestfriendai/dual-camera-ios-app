//
//  CameraManager.swift
//  DualApp
//
//  Created by DualApp Team on 10/3/25.
//

import Foundation
import AVFoundation
import SwiftUI

// MARK: - Camera Manager Actor

@MainActor
actor CameraManager: Sendable {
    // MARK: - State Properties (Actor-Isolated)
    
    private(set) var state: CameraState = .notConfigured
    private(set) var activeConfiguration: CameraConfiguration?
    private var frontDevice: AVCaptureDevice?
    private var backDevice: AVCaptureDevice?
    private var captureSession: AVCaptureMultiCamSession?
    
    // MARK: - Event Stream
    
    let events: AsyncStream<CameraEvent>
    private let eventContinuation: AsyncStream<CameraEvent>.Continuation
    
    // MARK: - Initialization
    
    init() {
        (self.events, self.eventContinuation) = AsyncStream<CameraEvent>.makeStream()
    }
    
    // MARK: - Public Interface
    
    func configureCameras() async throws {
        guard state == .notConfigured else {
            throw CameraError.invalidState
        }
        
        state = .configuring
        eventContinuation.yield(.stateChanged(.configuring))
        
        do {
            // Discover available cameras
            let discoveryResult = try await discoverCameras()
            
            // Create multi-cam session
            captureSession = AVCaptureMultiCamSession()
            
            // Configure front camera
            if let frontDevice = discoveryResult.frontDevice {
                try await configureCamera(frontDevice, position: .front)
                self.frontDevice = frontDevice
            }
            
            // Configure back camera
            if let backDevice = discoveryResult.backDevice {
                try await configureCamera(backDevice, position: .back)
                self.backDevice = backDevice
            }
            
            // Set up hardware synchronization
            try await setupHardwareSynchronization()
            
            // Apply default configuration
            activeConfiguration = .default
            try await applyConfiguration(.default)
            
            state = .configured
            eventContinuation.yield(.stateChanged(.configured))
            
        } catch {
            state = .error(CameraError.configurationFailed(error.localizedDescription))
            eventContinuation.yield(.error(CameraError.configurationFailed(error.localizedDescription)))
            throw error
        }
    }
    
    // MARK: - Private Methods
    
    private func discoverCameras() async throws -> (frontDevice: AVCaptureDevice?, backDevice: AVCaptureDevice?) {
            let discoverySession = AVCaptureDevice.DiscoverySession(
                deviceTypes: [.builtInWideAngleCamera, .builtInTelephotoCamera, .builtInUltraWideCamera],
                mediaType: .video,
                position: .unspecified
            )
            
            let devices = discoverySession.devices
            var frontDevice: AVCaptureDevice?
            var backDevice: AVCaptureDevice?
            
            for device in devices {
                switch device.position {
                case .front:
                    frontDevice = device
                case .back:
                    backDevice = device
                default:
                    break
                }
            }
            
            guard frontDevice != nil || backDevice != nil else {
                throw CameraError.hardwareNotSupported
            }
            
            return (frontDevice, backDevice)
        }
        
        private func configureCamera(_ device: AVCaptureDevice, position: AVCaptureDevice.Position) async throws {
            guard let session = captureSession else {
                throw CameraError.sessionNotAvailable
            }
            
            // Create input
            let input = try AVCaptureDeviceInput(device: device)
            
            // Add input to session
            if session.canAddInput(input) {
                session.addInput(input)
            } else {
                throw CameraError.configurationFailed("Cannot add camera input for position: \(position)")
            }
            
            // Configure device settings
            try await configureDeviceSettings(device)
        }
        
        private func configureDeviceSettings(_ device: AVCaptureDevice) async throws {
            try await device.lockForConfiguration()
            defer { device.unlockForConfiguration() }
            
            // Set frame rate
            if let config = activeConfiguration {
                let duration = CMTime(value: 1, timescale: config.frameRate)
                device.activeVideoMinFrameDuration = duration
                device.activeVideoMaxFrameDuration = duration
            }
            
            // Enable HDR if supported
            if let config = activeConfiguration, config.hdrEnabled {
                if device.isSmoothAutoFocusSupported {
                    device.isSmoothAutoFocusEnabled = true
                }
            }
        }
        
        private func setupHardwareSynchronization() async throws {
            guard let session = captureSession else {
                throw CameraError.sessionNotAvailable
            }
            
            // Configure hardware synchronization for multi-cam
            session.beginConfiguration()
            defer { session.commitConfiguration() }
            
            // Enable synchronization if available
            if #available(iOS 16.0, *) {
                session.synchronizedCaptureMode = .synchronized
            }
        }
        
        private func applyConfiguration(_ config: CameraConfiguration) async throws {
            guard let session = captureSession else {
                throw CameraError.sessionNotAvailable
            }
            
            session.beginConfiguration()
            defer { session.commitConfiguration() }
            
            // Update frame rates
            if let frontDevice = frontDevice {
                try await configureDeviceSettings(frontDevice)
            }
            
            if let backDevice = backDevice {
                try await configureDeviceSettings(backDevice)
            }
        }
        
        private func configureRecordingOutputs() async throws {
            guard let session = captureSession else {
                throw CameraError.sessionNotAvailable
            }
            
            // Configure video outputs for each camera
            // This would be implemented with specific output configurations
            // for the dual camera recording functionality
        }
        
        private func beginMultiCamRecording() async throws {
            // Start recording on all configured outputs
            // Implementation would include file URL management and
            // coordination between multiple recording sessions
        }
        
        private func stopMultiCamRecording() async throws {
            // Stop recording on all outputs
            // Implementation would ensure proper file finalization
        }
        
        private func processRecordings() async throws -> [CameraManager.RecordingMetadata] {
            // Process and merge recordings from multiple cameras
            // Return metadata for processed recordings
            return []
        }
    
    // MARK: - Photo Capture Delegate
    
    class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate {
        private let metadata: PhotoMetadata
        private let completion: (Result<Data, Error>) -> Void
        
        init(metadata: PhotoMetadata, completion: @escaping (Result<Data, Error>) -> Void) {
            self.metadata = metadata
            self.completion = completion
        }
        
        func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
            if let error = error {
                completion(.failure(error))
            } else if let imageData = photo.fileDataRepresentation() {
                completion(.success(imageData))
            } else {
                completion(.failure(CameraError.photoCaptureFailed("No image data available")))
            }
        }
    }
    
    // MARK: - Recording Metadata
    
    struct RecordingMetadata: Sendable {
        let id: UUID
        let cameraPosition: AVCaptureDevice.Position
        let duration: TimeInterval
        let fileURL: URL
        let timestamp: Date
        let quality: VideoQuality
    }
    
    // MARK: - Additional Camera Events
    
    enum CameraEventExtended: Sendable {
        case recordingsReady([RecordingMetadata])
        case configurationApplied(CameraConfiguration)
        case deviceChanged(AVCaptureDevice.Position)
        case focusChanged(CGPoint)
        case exposureChanged(Float)
        case whiteBalanceChanged(AVCaptureDevice.WhiteBalanceMode)
    }
    
    // MARK: - Additional Camera Errors
    
    enum CameraErrorExtended: Error, Sendable {
        case invalidState
        case sessionNotAvailable
        case recordingFailed(String)
        case photoCaptureFailed(String)
        case deviceNotAvailable(AVCaptureDevice.Position)
        case configurationConflict(String)
    }
    
    func startRecording() async throws {
        guard state == .configured else {
            throw CameraError.invalidState
        }
        
        guard let session = captureSession else {
            throw CameraError.sessionNotAvailable
        }
        
        do {
            // Check thermal and battery state
            let thermalState = await ThermalManager.shared.currentThermalState
            let batteryLevel = await BatteryManager.shared.currentBatteryLevel
            
            guard thermalState != .critical else {
                throw CameraError.thermalLimitReached
            }
            
            guard batteryLevel > 0.1 else {
                throw CameraError.batteryLevelLow
            }
            
            // Configure recording outputs
            try await configureRecordingOutputs()
            
            // Start session if not already running
            if !session.isRunning {
                session.startRunning()
            }
            
            // Begin recording on all outputs
            try await beginMultiCamRecording()
            
            state = .recording
            eventContinuation.yield(.recordingStarted)
            
        } catch {
            eventContinuation.yield(.error(CameraError.recordingFailed(error.localizedDescription)))
            throw error
        }
    }
    
    func stopRecording() async {
        guard state == .recording else { return }
        
        do {
            // Stop recording on all outputs
            try await stopMultiCamRecording()
            
            // Process and save recordings
            let recordings = try await processRecordings()
            
            state = .configured
            eventContinuation.yield(.recordingStopped)
            // TODO: Add recordingsReady case to CameraEvent enum
            // eventContinuation.yield(.recordingsReady(recordings))
            
        } catch {
            state = .error(CameraError.recordingFailed(error.localizedDescription))
            eventContinuation.yield(.error(CameraError.recordingFailed(error.localizedDescription)))
        }
    }
    
    func capturePhoto() async throws -> PhotoMetadata {
        guard state == .configured else {
            throw CameraError.invalidState
        }
        
        guard let session = captureSession else {
            throw CameraError.sessionNotAvailable
        }
        
        do {
            // Configure photo output
            let photoOutput = AVCapturePhotoOutput()
            session.addOutput(photoOutput)
            
            // Capture photo from both cameras
            let photoSettings = AVCapturePhotoSettings()
            photoSettings.isHighResolutionPhotoEnabled = true
            
            let metadata = PhotoMetadata()
            
            photoOutput.capturePhoto(with: photoSettings, delegate: PhotoCaptureDelegate(metadata: metadata) { [weak self] result in
                Task { @MainActor in
                    switch result {
                    case .success(let photoData):
                        self?.eventContinuation.yield(.photoCaptured(metadata))
                    case .failure(let error):
                        self?.eventContinuation.yield(.error(CameraError.photoCaptureFailed(error.localizedDescription)))
                    }
                }
            })
            
            return metadata
            
        } catch {
            eventContinuation.yield(.error(CameraError.photoCaptureFailed(error.localizedDescription)))
            throw CameraError.photoCaptureFailed(error.localizedDescription)
        }
    }
    
    func updateConfiguration(_ config: CameraConfiguration) async throws {
        guard state == .configured else {
            throw CameraError.invalidState
        }
        
        do {
            try await applyConfiguration(config)
            activeConfiguration = config
            eventContinuation.yield(.configurationUpdated(config))
            
        } catch {
            eventContinuation.yield(.error(CameraError.configurationFailed(error.localizedDescription)))
            throw CameraError.configurationFailed(error.localizedDescription)
        }
    }
}

// MARK: - Camera State

enum CameraState: Sendable {
    case notConfigured
    case configuring
    case configured
    case recording
    case error(CameraError)
}

// MARK: - Camera Event

enum CameraEvent: Sendable {
    case stateChanged(CameraState)
    case configurationUpdated(CameraConfiguration)
    case recordingStarted
    case recordingStopped
    case photoCaptured(PhotoMetadata)
    case error(CameraError)
}

// MARK: - Camera Configuration



// MARK: - Photo Metadata

struct PhotoMetadata: Sendable {
    let timestamp = Date()
    let identifier = UUID().uuidString
}

// MARK: - Camera Error

enum CameraError: LocalizedError, Sendable {
    case notConfigured
    case configurationFailed(String)
    case hardwareNotSupported
    case permissionDenied
    case thermalLimitReached
    case batteryLevelLow
    
    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Camera is not configured"
        case .configurationFailed(let reason):
            return "Camera configuration failed: \(reason)"
        case .hardwareNotSupported:
            return "Device hardware not supported"
        case .permissionDenied:
            return "Camera permission denied"
        case .thermalLimitReached:
            return "Thermal limit reached"
        case .batteryLevelLow:
            return "Battery level too low"
        }
    }
}