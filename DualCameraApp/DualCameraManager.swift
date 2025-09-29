import AVFoundation
import UIKit

protocol DualCameraManagerDelegate: AnyObject {
    func didStartRecording()
    func didStopRecording()
    func didFailWithError(_ error: Error)
}

enum VideoQuality: String, CaseIterable {
    case hd720 = "720p HD"
    case hd1080 = "1080p Full HD"
    case uhd4k = "4K Ultra HD"

    var preset: AVCaptureSession.Preset {
        switch self {
        case .hd720:
            return .hd1280x720
        case .hd1080:
            return .hd1920x1080
        case .uhd4k:
            return .hd4K3840x2160
        }
    }

    var renderSize: CGSize {
        switch self {
        case .hd720:
            return CGSize(width: 1280, height: 720)
        case .hd1080:
            return CGSize(width: 1920, height: 1080)
        case .uhd4k:
            return CGSize(width: 3840, height: 2160)
        }
    }
}

class DualCameraManager: NSObject {
    weak var delegate: DualCameraManagerDelegate?

    // Video Quality
    var videoQuality: VideoQuality = .hd1080 {
        didSet {
            updateSessionPresets()
        }
    }

    // Camera Sessions
    private let frontCameraSession = AVCaptureSession()
    private let backCameraSession = AVCaptureSession()
    
    // Camera Devices
    private var frontCamera: AVCaptureDevice?
    private var backCamera: AVCaptureDevice?
    
    // Inputs
    private var frontCameraInput: AVCaptureDeviceInput?
    private var backCameraInput: AVCaptureDeviceInput?
    
    // Audio
    private var audioDevice: AVCaptureDevice?
    private var audioInput: AVCaptureDeviceInput?
    
    // Video Outputs
    private var frontVideoOutput: AVCaptureVideoDataOutput?
    private var backVideoOutput: AVCaptureVideoDataOutput?
    
    // Movie File Outputs
    private var frontMovieOutput: AVCaptureMovieFileOutput?
    private var backMovieOutput: AVCaptureMovieFileOutput?
    
    // Preview Layers
    var frontPreviewLayer: AVCaptureVideoPreviewLayer?
    var backPreviewLayer: AVCaptureVideoPreviewLayer?
    
    // Recording State
    private var isRecording = false
    private var frontVideoURL: URL?
    private var backVideoURL: URL?
    
    override init() {
        super.init()
        setupCameras()
    }
    
    private func setupCameras() {
        // Configure camera devices
        frontCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
        backCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
        audioDevice = AVCaptureDevice.default(for: .audio)
        
        setupSessions()
    }
    
    private func setupSessions() {
        // Setup Front Camera Session
        setupFrontCameraSession()
        
        // Setup Back Camera Session
        setupBackCameraSession()
    }
    
    private func setupFrontCameraSession() {
        frontCameraSession.beginConfiguration()

        // Set session preset
        if frontCameraSession.canSetSessionPreset(videoQuality.preset) {
            frontCameraSession.sessionPreset = videoQuality.preset
        }

        // Add video input
        guard let frontCamera = frontCamera else {
            print("Front camera not available")
            return
        }
        
        do {
            let frontInput = try AVCaptureDeviceInput(device: frontCamera)
            if frontCameraSession.canAddInput(frontInput) {
                frontCameraSession.addInput(frontInput)
                frontCameraInput = frontInput
            }
        } catch {
            print("Error setting up front camera input: \(error)")
        }
        
        // Add audio input (only to front camera session)
        if let audioDevice = audioDevice {
            do {
                let audioInputDevice = try AVCaptureDeviceInput(device: audioDevice)
                if frontCameraSession.canAddInput(audioInputDevice) {
                    frontCameraSession.addInput(audioInputDevice)
                    audioInput = audioInputDevice
                }
            } catch {
                print("Error setting up audio input: \(error)")
            }
        }
        
        // Setup movie file output for front camera
        frontMovieOutput = AVCaptureMovieFileOutput()
        if let frontMovieOutput = frontMovieOutput,
           frontCameraSession.canAddOutput(frontMovieOutput) {
            frontCameraSession.addOutput(frontMovieOutput)
        }
        
        // Setup preview layer
        frontPreviewLayer = AVCaptureVideoPreviewLayer(session: frontCameraSession)
        frontPreviewLayer?.videoGravity = .resizeAspectFill
        
        frontCameraSession.commitConfiguration()
    }
    
private func setupBackCameraSession() {
        backCameraSession.beginConfiguration()

        // Set session preset
        if backCameraSession.canSetSessionPreset(videoQuality.preset) {
            backCameraSession.sessionPreset = videoQuality.preset
        }

        // Add video input
        guard let backCamera = backCamera else {
            print("Back camera not available")
            backCameraSession.commitConfiguration()
            return
        }

        do {
            let backInput = try AVCaptureDeviceInput(device: backCamera)
            if backCameraSession.canAddInput(backInput) {
                backCameraSession.addInput(backInput)
                backCameraInput = backInput
            }
        } catch {
            print("Error setting up back camera input: \(error)")
        }

        // Setup movie file output for back camera
        backMovieOutput = AVCaptureMovieFileOutput()
        if let backMovieOutput = backMovieOutput,
           backCameraSession.canAddOutput(backMovieOutput) {
            backCameraSession.addOutput(backMovieOutput)
        }

        // Setup preview layer
        backPreviewLayer = AVCaptureVideoPreviewLayer(session: backCameraSession)
        backPreviewLayer?.videoGravity = .resizeAspectFill

        backCameraSession.commitConfiguration()
    }

    // MARK: - Session Control
    func startSessions() {
        DispatchQueue.global(qos: .userInitiated).async {
            if !self.frontCameraSession.isRunning {
                self.frontCameraSession.startRunning()
            }
            if !self.backCameraSession.isRunning {
                self.backCameraSession.startRunning()
            }
        }
    }

    func stopSessions() {
        DispatchQueue.global(qos: .userInitiated).async {
            if self.frontCameraSession.isRunning {
                self.frontCameraSession.stopRunning()
            }
            if self.backCameraSession.isRunning {
                self.backCameraSession.stopRunning()
            }
        }
    }

    // MARK: - Recording
    func startRecording() {
        guard !isRecording else { return }

        // Generate file URLs
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let timestamp = Int(Date().timeIntervalSince1970)

        frontVideoURL = documentsPath.appendingPathComponent("front_\(timestamp).mov")
        backVideoURL = documentsPath.appendingPathComponent("back_\(timestamp).mov")

        if let frontMovieOutput = frontMovieOutput, let frontURL = frontVideoURL {
            frontMovieOutput.startRecording(to: frontURL, recordingDelegate: self)
        }
        if let backMovieOutput = backMovieOutput, let backURL = backVideoURL {
            backMovieOutput.startRecording(to: backURL, recordingDelegate: self)
        }

        isRecording = true
        delegate?.didStartRecording()
    }

    func stopRecording() {
        guard isRecording else { return }
        if frontMovieOutput?.isRecording == true {
            frontMovieOutput?.stopRecording()
        }
        if backMovieOutput?.isRecording == true {
            backMovieOutput?.stopRecording()
        }
        isRecording = false
    }

    // MARK: - Flash Control
    private(set) var isFlashOn: Bool = false

    func toggleFlash() {
        guard let backCamera = backCamera, backCamera.hasTorch else { return }
        do {
            try backCamera.lockForConfiguration()
            if backCamera.torchMode == .on {
                backCamera.torchMode = .off
                isFlashOn = false
            } else {
                try backCamera.setTorchModeOn(level: 1.0)
                isFlashOn = true
            }
            backCamera.unlockForConfiguration()
        } catch {
            print("Flash toggle error: \(error)")
        }
    }

    // MARK: - URL Helper
    func getRecordingURLs() -> (front: URL?, back: URL?) {
        return (frontVideoURL, backVideoURL)
    }

    // MARK: - Zoom Control
    func setZoom(for position: AVCaptureDevice.Position, scale: CGFloat) {
        let camera = position == .front ? frontCamera : backCamera
        guard let device = camera else { return }

        do {
            try device.lockForConfiguration()
            let maxZoom = min(device.activeFormat.videoMaxZoomFactor, 5.0) // Limit to 5x
            let zoom = max(1.0, min(scale, maxZoom))
            device.videoZoomFactor = zoom
            device.unlockForConfiguration()
        } catch {
            print("Zoom error: \(error)")
        }
    }

    // MARK: - Focus and Exposure Control
    func setFocusAndExposure(for position: AVCaptureDevice.Position, at point: CGPoint) {
        let camera = position == .front ? frontCamera : backCamera
        guard let device = camera else { return }

        do {
            try device.lockForConfiguration()

            if device.isFocusPointOfInterestSupported && device.isFocusModeSupported(.autoFocus) {
                device.focusPointOfInterest = point
                device.focusMode = .autoFocus
            }

            if device.isExposurePointOfInterestSupported && device.isExposureModeSupported(.autoExpose) {
                device.exposurePointOfInterest = point
                device.exposureMode = .autoExpose
            }

            device.unlockForConfiguration()
        } catch {
            print("Focus/Exposure error: \(error)")
        }
    }

    // MARK: - Quality Control
    private func updateSessionPresets() {
        frontCameraSession.beginConfiguration()
        if frontCameraSession.canSetSessionPreset(videoQuality.preset) {
            frontCameraSession.sessionPreset = videoQuality.preset
        }
        frontCameraSession.commitConfiguration()

        backCameraSession.beginConfiguration()
        if backCameraSession.canSetSessionPreset(videoQuality.preset) {
            backCameraSession.sessionPreset = videoQuality.preset
        }
        backCameraSession.commitConfiguration()
    }
}

// MARK: - AVCaptureFileOutputRecordingDelegate
extension DualCameraManager: AVCaptureFileOutputRecordingDelegate {
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        
        if let error = error {
            print("Recording error: \(error)")
            delegate?.didFailWithError(error)
            return
        }
        
        print("Recording finished successfully to: \(outputFileURL)")
        
        // Check if both recordings are done
        let frontFinished = frontMovieOutput?.isRecording == false
        let backFinished = backMovieOutput?.isRecording == false
        
        if frontFinished && backFinished {
            delegate?.didStopRecording()
        }
    }
}