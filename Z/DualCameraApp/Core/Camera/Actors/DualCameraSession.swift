//
//  DualCameraSession.swift
//  DualApp
//
//  Created by DualApp Team on 10/3/25.
//

import Foundation
import AVFoundation
import SwiftUI
import Metal
import MetalKit

// MARK: - Dual Camera Session Actor

@MainActor
actor DualCameraSession: Sendable {
    
    // MARK: - State Properties
    
    private(set) var state: DualCameraSessionState = .notInitialized
    private(set) var configuration: CameraConfiguration?
    private(set) var frontCameraDevice: AVCaptureDevice?
    private(set) var backCameraDevice: AVCaptureDevice?
    private(set) var multiCamSession: AVCaptureMultiCamSession?
    
    // MARK: - Input/Output Management
    
    private var frontCameraInput: AVCaptureDeviceInput?
    private var backCameraInput: AVCaptureDeviceInput?
    private var frontVideoOutput: AVCaptureVideoDataOutput?
    private var backVideoOutput: AVCaptureVideoDataOutput?
    private var frontAudioOutput: AVCaptureAudioDataOutput?
    private var backAudioOutput: AVCaptureAudioDataOutput?
    private var photoOutput: AVCapturePhotoOutput?
    
    // MARK: - Hardware Synchronization
    
    private var hardwareSynchronizer: HardwareSynchronizer?
    private var frameSyncCoordinator: FrameSyncCoordinator?
    private var synchronizationLatency: TimeInterval = 0.001 // 1ms target
    
    // MARK: - Preview Management
    
    private var frontPreviewLayer: AVCaptureVideoPreviewLayer?
    private var backPreviewLayer: AVCaptureVideoPreviewLayer?
    private var metalRenderer: MetalRenderer?
    
    // MARK: - Performance Monitoring
    
    private var performanceMonitor: DualCameraPerformanceMonitor?
    private var adaptiveQualityManager: AdaptiveQualityManager?
    
    // MARK: - Event Streams
    
    let events: AsyncStream<DualCameraEvent>
    private let eventContinuation: AsyncStream<DualCameraEvent>.Continuation
    
    let frameStream: AsyncStream<DualCameraFrame>
    private let frameContinuation: AsyncStream<DualCameraFrame>.Continuation
    
    // MARK: - Recording State
    
    private var recordingSession: RecordingSession?
    private var recordingCoordinator: RecordingCoordinator?
    
    // MARK: - Error Recovery
    
    private var errorRecoveryManager: ErrorRecoveryManager?
    private var retryCount: Int = 0
    private let maxRetryCount: Int = 3
    
    // MARK: - Initialization
    
    init() {
        (self.events, self.eventContinuation) = AsyncStream<DualCameraEvent>.makeStream()
        (self.frameStream, self.frameContinuation) = AsyncStream<DualCameraFrame>.makeStream()
        
        Task {
            await initializeSession()
        }
    }
    
    // MARK: - Public Interface
    
    func initializeSession() async {
        guard state == .notInitialized else {
            eventContinuation.yield(.error(DualCameraError.invalidState))
            return
        }
        
        state = .initializing
        eventContinuation.yield(.stateChanged(.initializing))
        
        do {
            // Check multi-cam support
            guard await checkMultiCamSupport() else {
                throw DualCameraError.multiCamNotSupported
            }
            
            // Create multi-cam session
            multiCamSession = AVCaptureMultiCamSession()
            
            // Initialize hardware synchronizer
            hardwareSynchronizer = HardwareSynchronizer()
            frameSyncCoordinator = FrameSyncCoordinator()
            
            // Initialize performance monitoring
            performanceMonitor = DualCameraPerformanceMonitor()
            adaptiveQualityManager = AdaptiveQualityManager()
            
            // Initialize error recovery
            errorRecoveryManager = ErrorRecoveryManager()
            
            // Discover and configure cameras
            try await discoverAndConfigureCameras()
            
            // Set up hardware synchronization
            try await setupHardwareSynchronization()
            
            // Initialize Metal renderer
            try await initializeMetalRenderer()
            
            state = .ready
            eventContinuation.yield(.stateChanged(.ready))
            
        } catch {
            state = .error(error)
            eventContinuation.yield(.error(DualCameraError.initializationFailed(error.localizedDescription)))
        }
    }
    
    func configureSession(with configuration: CameraConfiguration) async throws {
        guard state == .ready else {
            throw DualCameraError.invalidState
        }
        
        self.configuration = configuration
        
        // Validate configuration
        let errors = configuration.validate()
        guard errors.isEmpty else {
            throw DualCameraError.configurationInvalid(errors)
        }
        
        // Apply configuration to devices
        try await applyConfiguration(configuration)
        
        eventContinuation.yield(.configurationUpdated(configuration))
    }
    
    func startSession() async throws {
        guard state == .ready else {
            throw DualCameraError.invalidState
        }
        
        guard let session = multiCamSession else {
            throw DualCameraError.sessionNotAvailable
        }
        
        // Start performance monitoring
        await performanceMonitor?.startMonitoring()
        
        // Start adaptive quality management
        await adaptiveQualityManager?.startManaging()
        
        // Start session
        session.startRunning()
        
        state = .running
        eventContinuation.yield(.stateChanged(.running))
        
        // Begin frame synchronization
        await frameSyncCoordinator?.startSynchronization()
    }
    
    func stopSession() async {
        guard state == .running else { return }
        
        // Stop frame synchronization
        await frameSyncCoordinator?.stopSynchronization()
        
        // Stop adaptive quality management
        await adaptiveQualityManager?.stopManaging()
        
        // Stop performance monitoring
        await performanceMonitor?.stopMonitoring()
        
        // Stop session
        multiCamSession?.stopRunning()
        
        state = .ready
        eventContinuation.yield(.stateChanged(.ready))
    }
    
    func startRecording() async throws -> RecordingSession {
        guard state == .running else {
            throw DualCameraError.invalidState
        }
        
        guard let configuration = configuration else {
            throw DualCameraError.configurationNotSet
        }
        
        // Check thermal and battery state
        try await checkSystemConstraints()
        
        // Create recording session
        recordingSession = RecordingSession(configuration: configuration)
        
        // Initialize recording coordinator
        recordingCoordinator = RecordingCoordinator(
            configuration: configuration,
            frontDevice: frontCameraDevice,
            backDevice: backCameraDevice
        )
        
        // Start recording
        try await recordingCoordinator?.startRecording()
        
        state = .recording
        eventContinuation.yield(.stateChanged(.recording))
        eventContinuation.yield(.recordingStarted(recordingSession!))
        
        return recordingSession!
    }
    
    func stopRecording() async throws {
        guard state == .recording else { return }
        
        // Stop recording coordinator
        try await recordingCoordinator?.stopRecording()
        
        // Finalize recording session
        recordingSession?.complete()
        
        state = .running
        eventContinuation.yield(.stateChanged(.running))
        eventContinuation.yield(.recordingStopped(recordingSession!))
        
        // Clear recording state
        recordingSession = nil
        recordingCoordinator = nil
    }
    
    func capturePhoto() async throws -> PhotoCaptureResult {
        guard state == .running || state == .ready else {
            throw DualCameraError.invalidState
        }
        
        guard let photoOutput = photoOutput else {
            throw DualCameraError.photoOutputNotAvailable
        }
        
        // Configure photo settings
        let photoSettings = AVCapturePhotoSettings()
        photoSettings.isHighResolutionPhotoEnabled = true
        
        if let config = configuration, config.hdrEnabled {
            photoSettings.isAutoHDREnabled = true
        }
        
        // Capture photo from both cameras
        return try await capturePhotoFromBothCameras(settings: photoSettings)
    }
    
    func switchCameras() async throws {
        guard state == .running else {
            throw DualCameraError.invalidState
        }
        
        // Swap front and back camera inputs
        try await swapCameraInputs()
        
        eventContinuation.yield(.camerasSwitched)
    }
    
    func updateZoomLevel(_ zoomLevel: Float) async throws {
        guard let backDevice = backCameraDevice else {
            throw DualCameraError.deviceNotAvailable(.back)
        }
        
        try await updateDeviceZoom(backDevice, zoomLevel: zoomLevel)
        
        eventContinuation.yield(.zoomChanged(zoomLevel))
    }
    
    func setFocusPoint(_ point: CGPoint, for position: CameraPosition) async throws {
        let device = position == .front ? frontCameraDevice : backCameraDevice
        
        guard let cameraDevice = device else {
            throw DualCameraError.deviceNotAvailable(position)
        }
        
        try await setFocusPoint(point, device: cameraDevice)
        
        eventContinuation.yield(.focusChanged(point, position))
    }
    
    func setExposureBias(_ bias: Float, for position: CameraPosition) async throws {
        let device = position == .front ? frontCameraDevice : backCameraDevice
        
        guard let cameraDevice = device else {
            throw DualCameraError.deviceNotAvailable(position)
        }
        
        try await setExposureBias(bias, device: cameraDevice)
        
        eventContinuation.yield(.exposureChanged(bias, position))
    }
    
    func getCurrentPerformanceMetrics() async -> DualCameraPerformanceMetrics? {
        return await performanceMonitor?.getCurrentMetrics()
    }
    
    func getRecommendedConfiguration() async -> CameraConfiguration? {
        return await adaptiveQualityManager?.getRecommendedConfiguration()
    }
    
    // MARK: - Private Methods
    
    private func checkMultiCamSupport() async -> Bool {
        // Check if device supports multi-cam
        guard AVCaptureMultiCamSession.isMultiCamSupported else {
            return false
        }
        
        // Check for iOS 26+ features
        if #available(iOS 26.0, *) {
            // Check for hardware synchronization support
            return AVCaptureMultiCamSession.isHardwareSynchronizationSupported
        }
        
        return true
    }
    
    private func discoverAndConfigureCameras() async throws {
        guard let session = multiCamSession else {
            throw DualCameraError.sessionNotAvailable
        }
        
        // Discover front camera
        let frontDiscoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera],
            mediaType: .video,
            position: .front
        )
        
        if let frontDevice = frontDiscoverySession.devices.first {
            frontCameraDevice = frontDevice
            try await configureCameraDevice(frontDevice, position: .front)
        }
        
        // Discover back camera
        let backDiscoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .builtInTelephotoCamera, .builtInUltraWideCamera],
            mediaType: .video,
            position: .back
        )
        
        if let backDevice = backDiscoverySession.devices.first {
            backCameraDevice = backDevice
            try await configureCameraDevice(backDevice, position: .back)
        }
        
        guard frontCameraDevice != nil || backCameraDevice != nil else {
            throw DualCameraError.noCamerasAvailable
        }
    }
    
    private func configureCameraDevice(_ device: AVCaptureDevice, position: CameraPosition) async throws {
        guard let session = multiCamSession else {
            throw DualCameraError.sessionNotAvailable
        }
        
        // Create input
        let input = try AVCaptureDeviceInput(device: device)
        
        // Add input to session
        if session.canAddInput(input) {
            session.addInput(input)
            
            if position == .front {
                frontCameraInput = input
            } else {
                backCameraInput = input
            }
        } else {
            throw DualCameraError.cannotAddInput(position)
        }
        
        // Configure outputs
        try await configureOutputs(for: device, position: position)
    }
    
    private func configureOutputs(for device: AVCaptureDevice, position: CameraPosition) async throws {
        guard let session = multiCamSession else {
            throw DualCameraError.sessionNotAvailable
        }
        
        // Create video output
        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "video.output.\(position)"))
        
        if session.canAddOutput(videoOutput) {
            session.addOutput(videoOutput)
            
            if position == .front {
                frontVideoOutput = videoOutput
            } else {
                backVideoOutput = videoOutput
            }
        }
        
        // Create audio output (only for back camera)
        if position == .back {
            let audioOutput = AVCaptureAudioDataOutput()
            audioOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "audio.output.back"))
            
            if session.canAddOutput(audioOutput) {
                session.addOutput(audioOutput)
                backAudioOutput = audioOutput
            }
        }
        
        // Create photo output
        if photoOutput == nil {
            let photoOut = AVCapturePhotoOutput()
            if session.canAddOutput(photoOut) {
                session.addOutput(photoOut)
                photoOutput = photoOut
            }
        }
    }
    
    private func setupHardwareSynchronization() async throws {
        guard let session = multiCamSession else {
            throw DualCameraError.sessionNotAvailable
        }
        
        if #available(iOS 26.0, *) {
            // Configure hardware synchronization for 1ms latency
            session.beginConfiguration()
            
            // Enable synchronized capture mode
            if session.isSynchronizedCaptureModeSupported(.synchronized) {
                session.synchronizedCaptureMode = .synchronized
            }
            
            // Configure master clock
            if let masterClock = CMClockGetHostTimeClock() {
                session.masterClock = masterClock
            }
            
            session.commitConfiguration()
            
            // Initialize hardware synchronizer
            await hardwareSynchronizer?.configure(
                session: session,
                targetLatency: synchronizationLatency
            )
        }
    }
    
    private func initializeMetalRenderer() async throws {
        // Create Metal device
        guard let metalDevice = MTLCreateSystemDefaultDevice() else {
            throw DualCameraError.metalNotAvailable
        }
        
        // Initialize Metal renderer
        metalRenderer = MetalRenderer(device: metalDevice)
        try await metalRenderer?.initialize()
    }
    
    private func applyConfiguration(_ configuration: CameraConfiguration) async throws {
        // Apply configuration to front camera
        if let frontDevice = frontCameraDevice {
            try await applyDeviceConfiguration(configuration, to: frontDevice)
        }
        
        // Apply configuration to back camera
        if let backDevice = backCameraDevice {
            try await applyDeviceConfiguration(configuration, to: backDevice)
        }
        
        // Update adaptive quality manager
        await adaptiveQualityManager?.updateConfiguration(configuration)
    }
    
    private func applyDeviceConfiguration(_ configuration: CameraConfiguration, to device: AVCaptureDevice) async throws {
        try await device.lockForConfiguration()
        defer { device.unlockForConfiguration() }
        
        // Set frame rate
        let duration = CMTime(value: 1, timescale: configuration.frameRate)
        device.activeVideoMinFrameDuration = duration
        device.activeVideoMaxFrameDuration = duration
        
        // Set focus mode
        if device.isFocusModeSupported(configuration.focusMode.avFocusMode) {
            device.focusMode = configuration.focusMode.avFocusMode
        }
        
        // Set exposure mode
        if device.isExposureModeSupported(configuration.exposureMode.avExposureMode) {
            device.exposureMode = configuration.exposureMode.avExposureMode
        }
        
        // Set white balance mode
        if device.isWhiteBalanceModeSupported(configuration.whiteBalanceMode.avWhiteBalanceMode) {
            device.whiteBalanceMode = configuration.whiteBalanceMode.avWhiteBalanceMode
        }
        
        // Apply zoom
        if configuration.zoomLevel > 1.0 && configuration.zoomLevel <= device.activeFormat.videoMaxZoomFactor {
            device.videoZoomFactor = CGFloat(configuration.zoomLevel)
        }
        
        // Enable HDR if supported
        if configuration.hdrEnabled && device.isSmoothAutoFocusSupported {
            device.isSmoothAutoFocusEnabled = true
        }
    }
    
    private func checkSystemConstraints() async throws {
        // Check thermal state
        let thermalState = await ThermalManager.shared.currentThermalState
        guard thermalState != .critical else {
            throw DualCameraError.thermalLimitReached
        }
        
        // Check battery level
        let batteryLevel = await BatteryManager.shared.currentBatteryLevel
        guard batteryLevel > 0.1 else {
            throw DualCameraError.batteryLevelLow
        }
        
        // Check available memory
        let memoryPressure = await MemoryManager.shared.currentMemoryPressure
        guard memoryPressure != .critical else {
            throw DualCameraError.memoryLimitReached
        }
    }
    
    private func capturePhotoFromBothCameras(settings: AVCapturePhotoSettings) async throws -> PhotoCaptureResult {
        guard let photoOutput = photoOutput else {
            throw DualCameraError.photoOutputNotAvailable
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            // Capture from front camera if available
            if let frontDevice = frontCameraDevice {
                let frontSettings = AVCapturePhotoSettings()
                frontSettings.isHighResolutionPhotoEnabled = true
                
                photoOutput.capturePhoto(with: frontSettings, delegate: PhotoCaptureDelegate(
                    position: .front,
                    completion: { result in
                        // Handle front camera result
                    }
                ))
            }
            
            // Capture from back camera
            if let backDevice = backCameraDevice {
                photoOutput.capturePhoto(with: settings, delegate: PhotoCaptureDelegate(
                    position: .back,
                    completion: { result in
                        continuation.resume(returning: result)
                    }
                ))
            }
        }
    }
    
    private func swapCameraInputs() async throws {
        guard let session = multiCamSession else {
            throw DualCameraError.sessionNotAvailable
        }
        
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        
        // Remove existing inputs
        if let frontInput = frontCameraInput {
            session.removeInput(frontInput)
        }
        
        if let backInput = backCameraInput {
            session.removeInput(backInput)
        }
        
        // Swap inputs
        let temp = frontCameraInput
        frontCameraInput = backCameraInput
        backCameraInput = temp
        
        // Add inputs back in swapped positions
        if let frontInput = frontCameraInput {
            session.addInput(frontInput)
        }
        
        if let backInput = backCameraInput {
            session.addInput(backInput)
        }
    }
    
    private func updateDeviceZoom(_ device: AVCaptureDevice, zoomLevel: Float) async throws {
        try await device.lockForConfiguration()
        defer { device.unlockForConfiguration() }
        
        let clampedZoom = max(1.0, min(zoomLevel, device.activeFormat.videoMaxZoomFactor))
        device.videoZoomFactor = CGFloat(clampedZoom)
    }
    
    private func setFocusPoint(_ point: CGPoint, device: AVCaptureDevice) async throws {
        try await device.lockForConfiguration()
        defer { device.unlockForConfiguration() }
        
        if device.isFocusPointOfInterestSupported {
            device.focusPointOfInterest = point
            device.focusMode = .autoFocus
        }
    }
    
    private func setExposureBias(_ bias: Float, device: AVCaptureDevice) async throws {
        try await device.lockForConfiguration()
        defer { device.unlockForConfiguration() }
        
        let clampedBias = max(device.minExposureTargetBias, min(bias, device.maxExposureTargetBias))
        device.setExposureTargetBias(clampedBias)
    }
    
    deinit {
        Task { [weak self] in
            await self?.stopSession()
        }
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension DualCameraSession: AVCaptureVideoDataOutputSampleBufferDelegate {
    nonisolated func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        Task { @MainActor in
            await processFrame(sampleBuffer, from: output)
        }
    }
    
    private func processFrame(_ sampleBuffer: CMSampleBuffer, from output: AVCaptureOutput) async {
        guard let session = multiCamSession else { return }
        
        // Determine camera position
        let position: CameraPosition = output == frontVideoOutput ? .front : .back
        
        // Create frame object
        let frame = DualCameraFrame(
            sampleBuffer: sampleBuffer,
            position: position,
            timestamp: Date(),
            session: session
        )
        
        // Send to frame stream
        frameContinuation.yield(frame)
        
        // Send to frame synchronizer
        await frameSyncCoordinator?.addFrame(frame)
        
        // Send to performance monitor
        await performanceMonitor?.recordFrame(frame)
    }
}

// MARK: - AVCaptureAudioDataOutputSampleBufferDelegate

extension DualCameraSession: AVCaptureAudioDataOutputSampleBufferDelegate {
    nonisolated func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        Task { @MainActor in
            await processAudioFrame(sampleBuffer)
        }
    }
    
    private func processAudioFrame(_ sampleBuffer: CMSampleBuffer) async {
        // Process audio frame
        await recordingCoordinator?.processAudioFrame(sampleBuffer)
    }
}

// MARK: - Supporting Types

enum DualCameraSessionState: Sendable {
    case notInitialized
    case initializing
    case ready
    case running
    case recording
    case error(Error)
    
    var description: String {
        switch self {
        case .notInitialized:
            return "Not Initialized"
        case .initializing:
            return "Initializing"
        case .ready:
            return "Ready"
        case .running:
            return "Running"
        case .recording:
            return "Recording"
        case .error(let error):
            return "Error: \(error.localizedDescription)"
        }
    }
}

enum DualCameraEvent: Sendable {
    case stateChanged(DualCameraSessionState)
    case configurationUpdated(CameraConfiguration)
    case recordingStarted(RecordingSession)
    case recordingStopped(RecordingSession)
    case camerasSwitched
    case zoomChanged(Float)
    case focusChanged(CGPoint, CameraPosition)
    case exposureChanged(Float, CameraPosition)
    case error(DualCameraError)
    case performanceWarning(String)
    case thermalLimitReached
    case batteryLevelLow
}

enum DualCameraError: LocalizedError, Sendable {
    case invalidState
    case multiCamNotSupported
    case sessionNotAvailable
    case configurationNotSet
    case configurationInvalid([ConfigurationError])
    case initializationFailed(String)
    case deviceNotAvailable(CameraPosition)
    case cannotAddInput(CameraPosition)
    case photoOutputNotAvailable
    case thermalLimitReached
    case batteryLevelLow
    case memoryLimitReached
    case metalNotAvailable
    case hardwareSynchronizationFailed
    case frameSynchronizationFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidState:
            return "Invalid session state"
        case .multiCamNotSupported:
            return "Multi-camera is not supported on this device"
        case .sessionNotAvailable:
            return "Camera session is not available"
        case .configurationNotSet:
            return "Camera configuration is not set"
        case .configurationInvalid(let errors):
            return "Invalid configuration: \(errors.map(\.errorDescription).joined(separator: ", "))"
        case .initializationFailed(let reason):
            return "Initialization failed: \(reason)"
        case .deviceNotAvailable(let position):
            return "Camera device not available: \(position.description)"
        case .cannotAddInput(let position):
            return "Cannot add camera input: \(position.description)"
        case .photoOutputNotAvailable:
            return "Photo output is not available"
        case .thermalLimitReached:
            return "Thermal limit reached"
        case .batteryLevelLow:
            return "Battery level too low"
        case .memoryLimitReached:
            return "Memory limit reached"
        case .metalNotAvailable:
            return "Metal is not available"
        case .hardwareSynchronizationFailed:
            return "Hardware synchronization failed"
        case .frameSynchronizationFailed:
            return "Frame synchronization failed"
        }
    }
}

struct DualCameraFrame: Sendable {
    let sampleBuffer: CMSampleBuffer
    let position: CameraPosition
    let timestamp: Date
    let session: AVCaptureSession
    
    var pixelBuffer: CVPixelBuffer? {
        return CMSampleBufferGetImageBuffer(sampleBuffer)
    }
    
    var presentationTime: CMTime {
        return CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
    }
    
    var duration: CMTime {
        return CMSampleBufferGetDuration(sampleBuffer)
    }
}

struct PhotoCaptureResult: Sendable {
    let frontImageData: Data?
    let backImageData: Data?
    let timestamp: Date
    let metadata: [String: Any]
}

class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate {
    let position: CameraPosition
    let completion: (PhotoCaptureResult) -> Void
    
    init(position: CameraPosition, completion: @escaping (PhotoCaptureResult) -> Void) {
        self.position = position
        self.completion = completion
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            // Handle error
            return
        }
        
        let imageData = photo.fileDataRepresentation()
        let result = PhotoCaptureResult(
            frontImageData: position == .front ? imageData : nil,
            backImageData: position == .back ? imageData : nil,
            timestamp: Date(),
            metadata: photo.metadata as? [String: Any] ?? [:]
        )
        
        completion(result)
    }
}