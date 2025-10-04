//
//  CinematicModeIntegration.swift
//  DualCameraApp
//
//  Advanced Cinematic Mode integration with iOS 17+ features
//

import AVFoundation
import CoreVideo
import Metal
import UIKit

@available(iOS 17.0, *)
class CinematicModeIntegration: NSObject {
    
    // MARK: - Properties
    
    private let cinematicSession = AVCaptureMultiCamSession()
    private let sessionQueue = DispatchQueue(label: "CinematicMode.SessionQueue", qos: .userInitiated)
    
    // Cinematic mode specific outputs
    private var cinematicOutput: AVCaptureMovieFileOutput?
    private var depthDataOutput: AVCaptureDepthDataOutput?
    private var metadataOutput: AVCaptureMetadataOutput?
    
    // AI-powered focus tracking
    private var focusTracker: CinematicFocusTracker
    private var subjectAnalyzer: SubjectAnalyzer
    private var depthProcessor: DepthProcessor
    
    // Real-time effects
    private var rackFocusController: RackFocusController
    private var apertureController: ApertureController
    private var backgroundBlurController: BackgroundBlurController
    
    // Performance optimization
    private var cinematicRenderer: CinematicRenderer
    private var qualityController: CinematicQualityController
    
    // Delegate
    weak var delegate: CinematicModeDelegate?
    
    override init() {
        self.focusTracker = CinematicFocusTracker()
        self.subjectAnalyzer = SubjectAnalyzer()
        self.depthProcessor = DepthProcessor()
        self.rackFocusController = RackFocusController()
        self.apertureController = ApertureController()
        self.backgroundBlurController = BackgroundBlurController()
        self.cinematicRenderer = CinematicRenderer()
        self.qualityController = CinematicQualityController()
        
        super.init()
        
        setupCinematicSession()
    }
    
    // MARK: - Session Setup
    
    private func setupCinematicSession() {
        sessionQueue.async { [weak self] in
            self?.configureCinematicSession()
        }
    }
    
    private func configureCinematicSession() {
        cinematicSession.beginConfiguration()
        defer { cinematicSession.commitConfiguration() }
        
        // Configure cinematic camera input
        setupCinematicCameraInput()
        
        // Configure cinematic outputs
        setupCinematicOutputs()
        
        // Configure advanced connections
        setupCinematicConnections()
        
        // Enable AI-powered features
        enableCinematicAI()
    }
    
    private func setupCinematicCameraInput() {
        guard let cinematicCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            print("Cinematic camera not available")
            return
        }
        
        // Check if cinematic mode is supported
        guard cinematicCamera.activeFormat.isCinematicVideoSupported else {
            print("Cinematic mode not supported on this device")
            return
        }
        
        do {
            let cinematicInput = try AVCaptureDeviceInput(device: cinematicCamera)
            
            if cinematicSession.canAddInput(cinematicInput) {
                cinematicSession.addInput(cinematicInput)
                
                // Configure cinematic camera settings
                configureCinematicCamera(cinematicCamera)
            }
        } catch {
            print("Failed to add cinematic camera input: \(error)")
        }
    }
    
    private func configureCinematicCamera(_ camera: AVCaptureDevice) {
        do {
            try camera.lockForConfiguration()
            
            // Enable cinematic mode features
            if #available(iOS 17.0, *) {
                // Enable AI-powered subject tracking
                camera.automaticallyAdjustsFaceDrivenAutoFocusEnabled = true
                
                // Enable advanced focus modes
                if camera.isFocusModeSupported(.continuousAutoFocus) {
                    camera.focusMode = .continuousAutoFocus
                }
                
                // Configure for cinematic depth of field
                configureCinematicDepthOfField(camera)
            }
            
            camera.unlockForConfiguration()
        } catch {
            print("Failed to configure cinematic camera: \(error)")
        }
    }
    
    private func configureCinematicDepthOfField(_ camera: AVCaptureDevice) {
        // Configure depth of field for cinematic effect
        if #available(iOS 17.0, *) {
            // Set optimal aperture for cinematic look
            // This would depend on the specific camera capabilities
        }
    }
    
    private func setupCinematicOutputs() {
        // Setup cinematic video output
        setupCinematicVideoOutput()
        
        // Setup depth data output
        setupDepthDataOutput()
        
        // Setup metadata output for subject tracking
        setupMetadataOutput()
    }
    
    private func setupCinematicVideoOutput() {
        let cinematicOutput = AVCaptureMovieFileOutput()
        
        // Configure for cinematic recording
        cinematicOutput.setOutputSettings([
            AVVideoCodecKey: AVVideoCodecType.hevc,
            AVVideoWidthKey: 3840,
            AVVideoHeightKey: 2160,
            AVVideoCompressionPropertiesKey: [
                AVVideoCinematicVideoEnabledKey: true,
                AVVideoAverageBitRateKey: 25_000_000,
                AVVideoMaxKeyFrameIntervalKey: 60,
                AVVideoProfileLevelKey: kVTProfileLevel_HEVC_Main_AutoLevel
            ]
        ])
        
        if cinematicSession.canAddOutput(cinematicOutput) {
            cinematicSession.addOutput(cinematicOutput)
            self.cinematicOutput = cinematicOutput
        }
    }
    
    private func setupDepthDataOutput() {
        let depthOutput = AVCaptureDepthDataOutput()
        depthOutput.isFilteringEnabled = true
        depthOutput.setDelegate(self, queue: DispatchQueue(label: "DepthDataQueue"))
        
        if cinematicSession.canAddOutput(depthOutput) {
            cinematicSession.addOutput(depthOutput)
            self.depthDataOutput = depthOutput
        }
    }
    
    private func setupMetadataOutput() {
        let metadataOutput = AVCaptureMetadataOutput()
        metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue(label: "MetadataQueue"))
        
        // Configure for face detection and subject tracking
        metadataOutput.metadataObjectTypes = [
            .face,
            .humanBody,
            .cat,
            .dog
        ]
        
        if cinematicSession.canAddOutput(metadataOutput) {
            cinematicSession.addOutput(metadataOutput)
            self.metadataOutput = metadataOutput
        }
    }
    
    private func setupCinematicConnections() {
        // Configure connections for optimal cinematic quality
        guard let cinematicInput = cinematicSession.inputs.first as? AVCaptureDeviceInput,
              let cinematicOutput = cinematicOutput else { return }
        
        let connection = AVCaptureConnection(inputPorts: cinematicInput.ports, output: cinematicOutput)
        
        if cinematicSession.canAddConnection(connection) {
            // Configure connection for cinematic recording
            if connection.isVideoOrientationSupported {
                connection.videoOrientation = .portrait
            }
            
            if connection.isVideoStabilizationSupported {
                connection.preferredVideoStabilizationMode = .cinematicExtended
            }
            
            // Enable HDR for cinematic look
            if connection.isVideoHDREnabledSupported {
                connection.isVideoHDREnabled = true
            }
            
            cinematicSession.addConnection(connection)
        }
    }
    
    private func enableCinematicAI() {
        // Enable AI-powered cinematic features
        if #available(iOS 17.0, *) {
            focusTracker.enableAITracking()
            subjectAnalyzer.enableSubjectRecognition()
            depthProcessor.enableAIProcessing()
        }
    }
    
    // MARK: - Cinematic Recording
    
    func startCinematicRecording(to url: URL) {
        sessionQueue.async { [weak self] in
            guard let self = self,
                  let cinematicOutput = self.cinematicOutput else {
                print("Cinematic output not available")
                return
            }
            
            // Start cinematic recording
            cinematicOutput.startRecording(to: url, recordingDelegate: self)
            
            // Start AI processing
            self.startCinematicAI()
            
            // Notify delegate
            DispatchQueue.main.async {
                self.delegate?.didStartCinematicRecording()
            }
        }
    }
    
    func stopCinematicRecording() {
        sessionQueue.async { [weak self] in
            guard let self = self,
                  let cinematicOutput = self.cinematicOutput else { return }
            
            // Stop cinematic recording
            cinematicOutput.stopRecording()
            
            // Stop AI processing
            self.stopCinematicAI()
            
            // Notify delegate
            DispatchQueue.main.async {
                self.delegate?.didStopCinematicRecording()
            }
        }
    }
    
    private func startCinematicAI() {
        // Start AI-powered cinematic processing
        focusTracker.startTracking()
        subjectAnalyzer.startAnalysis()
        depthProcessor.startProcessing()
    }
    
    private func stopCinematicAI() {
        // Stop AI-powered cinematic processing
        focusTracker.stopTracking()
        subjectAnalyzer.stopAnalysis()
        depthProcessor.stopProcessing()
    }
    
    // MARK: - Cinematic Controls
    
    func rackFocus(to subject: CinematicSubject, duration: TimeInterval = 1.0) {
        rackFocusController.rackFocus(to: subject, duration: duration)
    }
    
    func adjustAperture(_ fStop: Float) {
        apertureController.setAperture(fStop)
    }
    
    func adjustBackgroundBlur(_ intensity: Float) {
        backgroundBlurController.setBlurIntensity(intensity)
    }
    
    func setFocusPoint(_ point: CGPoint) {
        focusTracker.setFocusPoint(point)
    }
    
    func trackSubject(_ subject: CinematicSubject) {
        focusTracker.trackSubject(subject)
        subjectAnalyzer.focusOnSubject(subject)
    }
    
    // MARK: - Session Control
    
    func startCinematicSession() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            
            if !self.cinematicSession.isRunning {
                self.cinematicSession.startRunning()
                
                DispatchQueue.main.async {
                    self.delegate?.didStartCinematicSession()
                }
            }
        }
    }
    
    func stopCinematicSession() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            
            if self.cinematicSession.isRunning {
                self.cinematicSession.stopRunning()
                
                DispatchQueue.main.async {
                    self.delegate?.didStopCinematicSession()
                }
            }
        }
    }
    
    // MARK: - Quality Control
    
    func setQualityLevel(_ level: CinematicQualityLevel) {
        qualityController.setQualityLevel(level)
    }
    
    func enableAdaptiveQuality(_ enabled: Bool) {
        qualityController.enableAdaptiveQuality(enabled)
    }
}

// MARK: - AVCaptureDepthDataOutputDelegate

@available(iOS 17.0, *)
extension CinematicModeIntegration: AVCaptureDepthDataOutputDelegate {
    func depthDataOutput(_ output: AVCaptureDepthDataOutput, didOutput depthData: AVDepthData, timestamp: CMTime, connection: AVCaptureConnection) {
        // Process depth data for cinematic effects
        depthProcessor.processDepthData(depthData, timestamp: timestamp)
    }
    
    func depthDataOutput(_ output: AVCaptureDepthDataOutput, didDrop depthData: AVDepthData, timestamp: CMTime, connection: AVCaptureConnection, reason: AVCaptureDepthDataOutput.DroppedReason) {
        // Handle dropped depth data
        print("Depth data dropped: \(reason)")
    }
}

// MARK: - AVCaptureMetadataOutputObjectsDelegate

@available(iOS 17.0, *)
extension CinematicModeIntegration: AVCaptureMetadataOutputObjectsDelegate {
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        // Process metadata for subject tracking
        for metadataObject in metadataObjects {
            if let faceObject = metadataObject as? AVMetadataFaceObject {
                processFaceDetection(faceObject)
            } else if let bodyObject = metadataObject as? AVMetadataHumanBodyObject {
                processBodyDetection(bodyObject)
            }
        }
    }
    
    private func processFaceDetection(_ faceObject: AVMetadataFaceObject) {
        // Process face detection for cinematic focus
        let subject = CinematicSubject(
            type: .face,
            bounds: faceObject.bounds,
            confidence: faceObject.confidence,
            trackingID: faceObject.faceID
        )
        
        focusTracker.updateSubject(subject)
        subjectAnalyzer.analyzeSubject(subject)
    }
    
    private func processBodyDetection(_ bodyObject: AVMetadataHumanBodyObject) {
        // Process body detection for cinematic focus
        let subject = CinematicSubject(
            type: .body,
            bounds: bodyObject.bounds,
            confidence: 1.0,
            trackingID: nil
        )
        
        focusTracker.updateSubject(subject)
        subjectAnalyzer.analyzeSubject(subject)
    }
}

// MARK: - AVCaptureFileOutputRecordingDelegate

@available(iOS 17.0, *)
extension CinematicModeIntegration: AVCaptureFileOutputRecordingDelegate {
    func fileOutput(_ output: AVCaptureFileOutput, didStartRecordingTo fileURL: URL, from connections: [AVCaptureConnection]) {
        print("Cinematic recording started to: \(fileURL.lastPathComponent)")
    }
    
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        if let error = error {
            print("Cinematic recording error: \(error)")
            DispatchQueue.main.async {
                self.delegate?.didFailCinematicRecording(error)
            }
        } else {
            print("Cinematic recording finished to: \(outputFileURL.lastPathComponent)")
            DispatchQueue.main.async {
                self.delegate?.didFinishCinematicRecording(to: outputFileURL)
            }
        }
    }
}

// MARK: - Delegate Protocol

@available(iOS 17.0, *)
protocol CinematicModeDelegate: AnyObject {
    func didStartCinematicSession()
    func didStopCinematicSession()
    func didStartCinematicRecording()
    func didStopCinematicRecording()
    func didFinishCinematicRecording(to url: URL)
    func didFailCinematicRecording(_ error: Error)
    func didUpdateCinematicSubject(_ subject: CinematicSubject)
    func didUpdateFocusPoint(_ point: CGPoint)
}

// MARK: - Supporting Classes

@available(iOS 17.0, *)
class CinematicFocusTracker {
    func enableAITracking() {
        // Enable AI-powered focus tracking
    }
    
    func startTracking() {
        // Start focus tracking
    }
    
    func stopTracking() {
        // Stop focus tracking
    }
    
    func setFocusPoint(_ point: CGPoint) {
        // Set focus point
    }
    
    func trackSubject(_ subject: CinematicSubject) {
        // Track specific subject
    }
    
    func updateSubject(_ subject: CinematicSubject) {
        // Update subject tracking
    }
}

@available(iOS 17.0, *)
class SubjectAnalyzer {
    func enableSubjectRecognition() {
        // Enable AI subject recognition
    }
    
    func startAnalysis() {
        // Start subject analysis
    }
    
    func stopAnalysis() {
        // Stop subject analysis
    }
    
    func analyzeSubject(_ subject: CinematicSubject) {
        // Analyze subject for cinematic decisions
    }
    
    func focusOnSubject(_ subject: CinematicSubject) {
        // Focus on specific subject
    }
}

@available(iOS 17.0, *)
class DepthProcessor {
    func enableAIProcessing() {
        // Enable AI depth processing
    }
    
    func startProcessing() {
        // Start depth processing
    }
    
    func stopProcessing() {
        // Stop depth processing
    }
    
    func processDepthData(_ depthData: AVDepthData, timestamp: CMTime) {
        // Process depth data for cinematic effects
    }
}

@available(iOS 17.0, *)
class RackFocusController {
    func rackFocus(to subject: CinematicSubject, duration: TimeInterval) {
        // Perform rack focus to subject
    }
}

@available(iOS 17.0, *)
class ApertureController {
    func setAperture(_ fStop: Float) {
        // Set aperture for depth of field
    }
}

@available(iOS 17.0, *)
class BackgroundBlurController {
    func setBlurIntensity(_ intensity: Float) {
        // Set background blur intensity
    }
}

@available(iOS 17.0, *)
class CinematicRenderer {
    // Advanced cinematic rendering
}

@available(iOS 17.0, *)
class CinematicQualityController {
    func setQualityLevel(_ level: CinematicQualityLevel) {
        // Set cinematic quality level
    }
    
    func enableAdaptiveQuality(_ enabled: Bool) {
        // Enable adaptive quality
    }
}

// MARK: - Data Structures

struct CinematicSubject {
    let type: SubjectType
    let bounds: CGRect
    let confidence: Float
    let trackingID: Int32?
    
    init(type: SubjectType, bounds: CGRect, confidence: Float, trackingID: Int32? = nil) {
        self.type = type
        self.bounds = bounds
        self.confidence = confidence
        self.trackingID = trackingID
    }
}

enum SubjectType {
    case face
    case body
    case animal
    case object
}

enum CinematicQualityLevel {
    case low
    case medium
    case high
    case cinematic
}

// MARK: - Extensions

extension AVCaptureDevice.Format {
    var isCinematicVideoSupported: Bool {
        if #available(iOS 17.0, *) {
            return supportedCodecs.contains(.hevc) && 
                   dimensions.width >= 3840 && 
                   dimensions.height >= 2160 &&
                   videoSupportedFrameRateRanges.contains(where: { $0.maxFrameRate >= 24 })
        }
        return false
    }
}