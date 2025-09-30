import AVFoundation
import UIKit

protocol DualCameraManagerDelegate: AnyObject {
    func didStartRecording()
    func didStopRecording()
    func didFailWithError(_ error: Error)
    func didUpdateVideoQuality(to quality: VideoQuality)
    func didCapturePhoto(frontImage: UIImage?, backImage: UIImage?)
}

enum VideoQuality: String, CaseIterable {
    case hd720 = "720p HD"
    case hd1080 = "1080p Full HD"
    case uhd4k = "4K Ultra HD"

    var dimensions: CMVideoDimensions {
        switch self {
        case .hd720:
            return CMVideoDimensions(width: 1280, height: 720)
        case .hd1080:
            return CMVideoDimensions(width: 1920, height: 1080)
        case .uhd4k:
            return CMVideoDimensions(width: 3840, height: 2160)
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

final class DualCameraManager: NSObject {
    weak var delegate: DualCameraManagerDelegate?

    var videoQuality: VideoQuality = .hd1080 {
        didSet {
            activeVideoQuality = videoQuality
            DispatchQueue.main.async {
                self.delegate?.didUpdateVideoQuality(to: self.videoQuality)
            }
        }
    }

    private let sessionQueue = DispatchQueue(label: "DualCameraManager.SessionQueue")

    private var captureSession: AVCaptureSession?

    var frontCamera: AVCaptureDevice?
    var backCamera: AVCaptureDevice?
    private var frontCameraInput: AVCaptureDeviceInput?
    private var backCameraInput: AVCaptureDeviceInput?

    private var audioDevice: AVCaptureDevice?
    private var audioInput: AVCaptureDeviceInput?

    private var frontMovieOutput: AVCaptureMovieFileOutput?
    private var backMovieOutput: AVCaptureMovieFileOutput?

    private var frontPhotoOutput: AVCapturePhotoOutput?
    private var backPhotoOutput: AVCapturePhotoOutput?

    var frontPreviewLayer: AVCaptureVideoPreviewLayer?
    var backPreviewLayer: AVCaptureVideoPreviewLayer?

    private var frontVideoURL: URL?
    private var backVideoURL: URL?
    private var combinedVideoURL: URL?

    private var capturedFrontImage: UIImage?
    private var capturedBackImage: UIImage?
    private var photoCaptureCount = 0

    private var isRecording = false
    private var isSetupComplete = false
    private(set) var activeVideoQuality: VideoQuality = .hd1080

    // MARK: - Triple Output Properties
    private var frontDataOutput: AVCaptureVideoDataOutput?
    private var backDataOutput: AVCaptureVideoDataOutput?
    private let dataOutputQueue = DispatchQueue(label: "com.dualcamera.dataoutput", qos: .userInitiated)
    private let compositionQueue = DispatchQueue(label: "com.dualcamera.composition", qos: .userInitiated)

    private var frameCompositor: FrameCompositor?
    private var assetWriter: AVAssetWriter?
    private var videoWriterInput: AVAssetWriterInput?
    private var audioWriterInput: AVAssetWriterInput?
    private var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?

    private var frontFrameBuffer: CMSampleBuffer?
    private var backFrameBuffer: CMSampleBuffer?
    private let frameSyncQueue = DispatchQueue(label: "com.dualcamera.framesync")

    private var recordingStartTime: CMTime?
    private var isWriting = false

    var recordingLayout: RecordingLayout = .sideBySide
    var enableTripleOutput: Bool = true

    private enum DualCameraError: LocalizedError {
        case multiCamNotSupported
        case missingDevices
        case configurationFailed(String)

        var errorDescription: String? {
            switch self {
            case .multiCamNotSupported:
                return "This device does not support simultaneous front and back camera capture."
            case .missingDevices:
                return "Required camera devices could not be initialized."
            case .configurationFailed(let reason):
                return reason
            }
        }
    }

    func setupCameras() {
        guard !isSetupComplete else { return }

        // Get devices immediately (fast operation)
        frontCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
        backCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
        audioDevice = AVCaptureDevice.default(for: .audio)

        guard frontCamera != nil, backCamera != nil else {
            DispatchQueue.main.async {
                self.delegate?.didFailWithError(DualCameraError.missingDevices)
            }
            return
        }

        // Use ASYNC instead of sync - don't block!
        sessionQueue.async {
            do {
                try self.configureSession()
                self.isSetupComplete = true

                // Notify on main thread
                DispatchQueue.main.async {
                    self.delegate?.didUpdateVideoQuality(to: self.videoQuality)
                }
            } catch {
                DispatchQueue.main.async {
                    self.delegate?.didFailWithError(error)
                }
                self.captureSession = nil
            }
        }
    }

    private func configureSession() throws {
        guard let frontCamera, let backCamera else {
            throw DualCameraError.missingDevices
        }

        if #available(iOS 13.0, *) {
            guard AVCaptureMultiCamSession.isMultiCamSupported else {
                throw DualCameraError.multiCamNotSupported
            }

            let session = AVCaptureMultiCamSession()
            captureSession = session
            try configureMultiCamSession(session: session, frontCamera: frontCamera, backCamera: backCamera)
        } else {
            throw DualCameraError.multiCamNotSupported
        }
    }

    @available(iOS 13.0, *)
    private func configureMultiCamSession(session: AVCaptureMultiCamSession, frontCamera: AVCaptureDevice, backCamera: AVCaptureDevice) throws {
        session.beginConfiguration()
        defer { session.commitConfiguration() }

        let selectedQuality = videoQuality
        activeVideoQuality = selectedQuality

        // STEP 1: Add inputs (fast)
        let frontInput = try AVCaptureDeviceInput(device: frontCamera)
        guard session.canAddInput(frontInput) else {
            throw DualCameraError.configurationFailed("Unable to add front camera input to capture session.")
        }
        session.addInputWithNoConnections(frontInput)
        frontCameraInput = frontInput

        let backInput = try AVCaptureDeviceInput(device: backCamera)
        guard session.canAddInput(backInput) else {
            throw DualCameraError.configurationFailed("Unable to add back camera input to capture session.")
        }
        session.addInputWithNoConnections(backInput)
        backCameraInput = backInput

        if let audioDevice {
            let audioInput = try AVCaptureDeviceInput(device: audioDevice)
            if session.canAddInput(audioInput) {
                session.addInputWithNoConnections(audioInput)
                self.audioInput = audioInput
            }
        }

        // STEP 2: Get video ports (needed for connections)
        guard
            let frontVideoPort = frontInput.ports(
                for: .video,
                sourceDeviceType: frontCamera.deviceType,
                sourceDevicePosition: .front
            ).first,
            let backVideoPort = backInput.ports(
                for: .video,
                sourceDeviceType: backCamera.deviceType,
                sourceDevicePosition: .back
            ).first
        else {
            throw DualCameraError.configurationFailed("Failed to obtain camera ports for preview and recording.")
        }

        // STEP 3: Setup PREVIEW LAYERS FIRST (most important for perceived speed)
        let frontPreviewLayer = AVCaptureVideoPreviewLayer(sessionWithNoConnection: session)
        frontPreviewLayer.videoGravity = .resizeAspectFill
        let frontPreviewConnection = AVCaptureConnection(
            inputPort: frontVideoPort,
            videoPreviewLayer: frontPreviewLayer
        )
        guard session.canAddConnection(frontPreviewConnection) else {
            throw DualCameraError.configurationFailed("Unable to configure front preview layer.")
        }
        session.addConnection(frontPreviewConnection)
        if frontPreviewConnection.isVideoOrientationSupported {
            frontPreviewConnection.videoOrientation = AVCaptureVideoOrientation.portrait
        }
        self.frontPreviewLayer = frontPreviewLayer

        let backPreviewLayer = AVCaptureVideoPreviewLayer(sessionWithNoConnection: session)
        backPreviewLayer.videoGravity = .resizeAspectFill
        let backPreviewConnection = AVCaptureConnection(
            inputPort: backVideoPort,
            videoPreviewLayer: backPreviewLayer
        )
        guard session.canAddConnection(backPreviewConnection) else {
            throw DualCameraError.configurationFailed("Unable to configure back preview layer.")
        }
        session.addConnection(backPreviewConnection)
        if backPreviewConnection.isVideoOrientationSupported {
            backPreviewConnection.videoOrientation = AVCaptureVideoOrientation.portrait
        }
        self.backPreviewLayer = backPreviewLayer

        // STEP 4: Setup movie outputs (needed for recording)
        let frontOutput = AVCaptureMovieFileOutput()
        guard session.canAddOutput(frontOutput) else {
            throw DualCameraError.configurationFailed("Unable to add front movie output to capture session.")
        }
        session.addOutputWithNoConnections(frontOutput)
        frontMovieOutput = frontOutput

        let backOutput = AVCaptureMovieFileOutput()
        guard session.canAddOutput(backOutput) else {
            throw DualCameraError.configurationFailed("Unable to add back movie output to capture session.")
        }
        session.addOutputWithNoConnections(backOutput)
        backMovieOutput = backOutput

        // STEP 5: Connect movie outputs to cameras
        var frontConnectionPorts: [AVCaptureInput.Port] = [frontVideoPort]
        if let audioPort = audioInput?.ports(
            for: .audio,
            sourceDeviceType: audioDevice?.deviceType,
            sourceDevicePosition: audioDevice?.position ?? .unspecified
        ).first {
            frontConnectionPorts.append(audioPort)
        }

        let frontConnection = AVCaptureConnection(inputPorts: frontConnectionPorts, output: frontOutput)
        guard session.canAddConnection(frontConnection) else {
            throw DualCameraError.configurationFailed("Unable to link front camera input with movie output.")
        }
        session.addConnection(frontConnection)
        if frontConnection.isVideoOrientationSupported {
            frontConnection.videoOrientation = AVCaptureVideoOrientation.portrait
        }

        let backConnection = AVCaptureConnection(inputPorts: [backVideoPort], output: backOutput)
        guard session.canAddConnection(backConnection) else {
            throw DualCameraError.configurationFailed("Unable to link back camera input with movie output.")
        }
        session.addConnection(backConnection)
        if backConnection.isVideoOrientationSupported {
            backConnection.videoOrientation = AVCaptureVideoOrientation.portrait
        }

        // DEFER: Photo outputs and triple output setup will be added when first needed
        // This significantly speeds up initial camera load time

        // Start session immediately - preview will be visible ASAP
        session.startRunning()

        // Schedule deferred setup on background queue
        DispatchQueue.global(qos: .utility).async { [weak self] in
            self?.setupDeferredOutputs(session: session, frontVideoPort: frontVideoPort, backVideoPort: backVideoPort)
        }
    }

    // MARK: - Deferred Setup (runs in background after camera is visible)
    @available(iOS 13.0, *)
    private func setupDeferredOutputs(session: AVCaptureMultiCamSession, frontVideoPort: AVCaptureInput.Port, backVideoPort: AVCaptureInput.Port) {
        // Wait a bit to let preview stabilize
        Thread.sleep(forTimeInterval: 0.3)

        sessionQueue.async {
            session.beginConfiguration()
            defer { session.commitConfiguration() }

            // Setup photo outputs
            let frontPhotoOutput = AVCapturePhotoOutput()
            if session.canAddOutput(frontPhotoOutput) {
                session.addOutputWithNoConnections(frontPhotoOutput)
                self.frontPhotoOutput = frontPhotoOutput

                let frontPhotoConnection = AVCaptureConnection(inputPorts: [frontVideoPort], output: frontPhotoOutput)
                if session.canAddConnection(frontPhotoConnection) {
                    session.addConnection(frontPhotoConnection)
                    if frontPhotoConnection.isVideoOrientationSupported {
                        frontPhotoConnection.videoOrientation = .portrait
                    }
                }
            }

            let backPhotoOutput = AVCapturePhotoOutput()
            if session.canAddOutput(backPhotoOutput) {
                session.addOutputWithNoConnections(backPhotoOutput)
                self.backPhotoOutput = backPhotoOutput

                let backPhotoConnection = AVCaptureConnection(inputPorts: [backVideoPort], output: backPhotoOutput)
                if session.canAddConnection(backPhotoConnection) {
                    session.addConnection(backPhotoConnection)
                    if backPhotoConnection.isVideoOrientationSupported {
                        backPhotoConnection.videoOrientation = .portrait
                    }
                }
            }

            // Setup triple output data outputs
            if self.enableTripleOutput {
                let frontDataOutput = AVCaptureVideoDataOutput()
                frontDataOutput.videoSettings = [
                    kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
                ]
                frontDataOutput.setSampleBufferDelegate(self, queue: self.dataOutputQueue)
                frontDataOutput.alwaysDiscardsLateVideoFrames = true

                if session.canAddOutput(frontDataOutput) {
                    session.addOutputWithNoConnections(frontDataOutput)
                    self.frontDataOutput = frontDataOutput

                    let frontDataConnection = AVCaptureConnection(inputPorts: [frontVideoPort], output: frontDataOutput)
                    if session.canAddConnection(frontDataConnection) {
                        session.addConnection(frontDataConnection)
                        if frontDataConnection.isVideoOrientationSupported {
                            frontDataConnection.videoOrientation = .portrait
                        }
                    }
                }

                let backDataOutput = AVCaptureVideoDataOutput()
                backDataOutput.videoSettings = [
                    kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
                ]
                backDataOutput.setSampleBufferDelegate(self, queue: self.dataOutputQueue)
                backDataOutput.alwaysDiscardsLateVideoFrames = true

                if session.canAddOutput(backDataOutput) {
                    session.addOutputWithNoConnections(backDataOutput)
                    self.backDataOutput = backDataOutput

                    let backDataConnection = AVCaptureConnection(inputPorts: [backVideoPort], output: backDataOutput)
                    if session.canAddConnection(backDataConnection) {
                        session.addConnection(backDataConnection)
                        if backDataConnection.isVideoOrientationSupported {
                            backDataConnection.videoOrientation = .portrait
                        }
                    }
                }
            }
        }
    }

    // MARK: - Session Control
    func startSessions() {
        guard let session = captureSession else { return }

        sessionQueue.async {
            if !session.isRunning {
                session.startRunning()
            }
        }
    }

    func stopSessions() {
        guard isSetupComplete, let session = captureSession else { return }

        sessionQueue.async {
            if session.isRunning {
                session.stopRunning()
            }
        }
    }

    // MARK: - Photo Capture
    func capturePhoto() {
        sessionQueue.async {
            guard self.isSetupComplete else { return }
            
            self.capturedFrontImage = nil
            self.capturedBackImage = nil
            self.photoCaptureCount = 0
            
            let settings = AVCapturePhotoSettings()
            settings.flashMode = self.isFlashOn ? .on : .off
            
            if let frontPhotoOutput = self.frontPhotoOutput {
                frontPhotoOutput.capturePhoto(with: settings, delegate: self)
            }
            
            if let backPhotoOutput = self.backPhotoOutput {
                backPhotoOutput.capturePhoto(with: settings, delegate: self)
            }
        }
    }
    
    // MARK: - Recording
    func startRecording() {
        sessionQueue.async {
            guard self.isSetupComplete, !self.isRecording else { return }

            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let timestamp = Int(Date().timeIntervalSince1970)

            self.frontVideoURL = documentsPath.appendingPathComponent("front_\(timestamp).mov")
            self.backVideoURL = documentsPath.appendingPathComponent("back_\(timestamp).mov")

            if let frontOutput = self.frontMovieOutput, let frontURL = self.frontVideoURL {
                frontOutput.startRecording(to: frontURL, recordingDelegate: self)
            }

            if let backOutput = self.backMovieOutput, let backURL = self.backVideoURL {
                backOutput.startRecording(to: backURL, recordingDelegate: self)
            }

            // Setup triple output (combined video)
            if self.enableTripleOutput {
                self.combinedVideoURL = documentsPath.appendingPathComponent("combined_\(timestamp).mp4")
                self.setupAssetWriter()
            }

            self.isRecording = true

            DispatchQueue.main.async {
                self.delegate?.didStartRecording()
            }
        }
    }

    func stopRecording() {
        sessionQueue.async {
            guard self.isRecording else { return }

            if self.frontMovieOutput?.isRecording == true {
                self.frontMovieOutput?.stopRecording()
            }

            if self.backMovieOutput?.isRecording == true {
                self.backMovieOutput?.stopRecording()
            }

            // Stop triple output
            if self.enableTripleOutput {
                self.finishAssetWriter()
            }

            self.isRecording = false
        }
    }

    // MARK: - Flash Control
    private(set) var isFlashOn: Bool = false

    func toggleFlash() {
        sessionQueue.sync {
            guard let backCamera = self.backCamera, backCamera.hasTorch else { return }
            do {
                try backCamera.lockForConfiguration()
                if backCamera.torchMode == .on {
                    backCamera.torchMode = .off
                    self.isFlashOn = false
                } else {
                    try backCamera.setTorchModeOn(level: AVCaptureDevice.maxAvailableTorchLevel)
                    self.isFlashOn = true
                }
                backCamera.unlockForConfiguration()
            } catch {
                print("Flash toggle error: \(error)")
            }
        }
    }

    // MARK: - URL Helper
    func getRecordingURLs() -> (front: URL?, back: URL?, combined: URL?) {
        return (frontVideoURL, backVideoURL, combinedVideoURL)
    }

    // MARK: - Zoom Control
    func setZoom(for position: AVCaptureDevice.Position, scale: CGFloat) {
        sessionQueue.async {
            let camera = position == .front ? self.frontCamera : self.backCamera
            guard let device = camera else { return }

            do {
                try device.lockForConfiguration()
                let maxZoom = min(device.activeFormat.videoMaxZoomFactor, 5.0)
                let zoom = max(1.0, min(scale, maxZoom))
                device.videoZoomFactor = zoom
                device.unlockForConfiguration()
            } catch {
                print("Zoom error: \(error)")
            }
        }
    }

    // MARK: - Focus and Exposure Control
    func setFocusAndExposure(for position: AVCaptureDevice.Position, at point: CGPoint) {
        sessionQueue.async {
            let camera = position == .front ? self.frontCamera : self.backCamera
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
    }

}

extension DualCameraManager: AVCaptureFileOutputRecordingDelegate {
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        if let error {
            print("Recording error: \(error)")
            DispatchQueue.main.async {
                self.delegate?.didFailWithError(error)
            }
            return
        }

        print("Recording finished successfully to: \(outputFileURL)")

        let frontFinished = frontMovieOutput?.isRecording == false
        let backFinished = backMovieOutput?.isRecording == false

        if frontFinished && backFinished {
            DispatchQueue.main.async {
                self.delegate?.didStopRecording()
            }
        }
    }
}

extension DualCameraManager: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error {
            print("Photo capture error: \(error)")
            return
        }

        guard let imageData = photo.fileDataRepresentation(),
              let image = UIImage(data: imageData) else {
            print("Failed to convert photo to image")
            return
        }

        if output == frontPhotoOutput {
            capturedFrontImage = image
        } else if output == backPhotoOutput {
            capturedBackImage = image
        }

        photoCaptureCount += 1

        if photoCaptureCount == 2 {
            DispatchQueue.main.async {
                self.delegate?.didCapturePhoto(frontImage: self.capturedFrontImage, backImage: self.capturedBackImage)
            }
        }
    }
}

// MARK: - Triple Output Implementation
extension DualCameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput,
                      didOutput sampleBuffer: CMSampleBuffer,
                      from connection: AVCaptureConnection) {

        guard isRecording, enableTripleOutput else { return }

        frameSyncQueue.sync {
            if output == frontDataOutput {
                frontFrameBuffer = sampleBuffer
            } else if output == backDataOutput {
                backFrameBuffer = sampleBuffer
            }

            // When we have both frames, compose them
            if let frontBuffer = frontFrameBuffer,
               let backBuffer = backFrameBuffer {

                compositionQueue.async {
                    self.processFramePair(front: frontBuffer, back: backBuffer)
                }

                // Clear buffers
                frontFrameBuffer = nil
                backFrameBuffer = nil
            }
        }
    }

    private func processFramePair(front: CMSampleBuffer, back: CMSampleBuffer) {
        guard let frontPixelBuffer = CMSampleBufferGetImageBuffer(front),
              let backPixelBuffer = CMSampleBufferGetImageBuffer(back),
              assetWriter != nil,
              let videoWriterInput = videoWriterInput,
              let pixelBufferAdaptor = pixelBufferAdaptor else {
            return
        }

        // Initialize compositor if needed
        if frameCompositor == nil {
            frameCompositor = FrameCompositor(layout: recordingLayout, quality: activeVideoQuality)
        }

        let presentationTime = CMSampleBufferGetPresentationTimeStamp(front)

        // Set recording start time on first frame
        if recordingStartTime == nil {
            recordingStartTime = presentationTime
        }

        // Calculate relative time
        guard let startTime = recordingStartTime else { return }
        let relativeTime = CMTimeSubtract(presentationTime, startTime)

        // Compose frames
        guard let composedBuffer = frameCompositor?.composite(
            frontBuffer: frontPixelBuffer,
            backBuffer: backPixelBuffer,
            timestamp: relativeTime
        ) else {
            return
        }

        // Write to asset writer
        if videoWriterInput.isReadyForMoreMediaData {
            pixelBufferAdaptor.append(composedBuffer, withPresentationTime: relativeTime)
        }
    }

    private func setupAssetWriter() {
        guard let combinedURL = combinedVideoURL else { return }

        // Remove existing file if any
        try? FileManager.default.removeItem(at: combinedURL)

        do {
            let writer = try AVAssetWriter(outputURL: combinedURL, fileType: .mp4)

            // Video settings
            let videoSettings: [String: Any] = [
                AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoWidthKey: activeVideoQuality.renderSize.width,
                AVVideoHeightKey: activeVideoQuality.renderSize.height,
                AVVideoCompressionPropertiesKey: [
                    AVVideoAverageBitRateKey: 10_000_000,
                    AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel
                ]
            ]

            let videoWriterInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
            videoWriterInput.expectsMediaDataInRealTime = true

            let sourcePixelBufferAttributes: [String: Any] = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey as String: activeVideoQuality.renderSize.width,
                kCVPixelBufferHeightKey as String: activeVideoQuality.renderSize.height,
                kCVPixelBufferMetalCompatibilityKey as String: true
            ]

            let pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(
                assetWriterInput: videoWriterInput,
                sourcePixelBufferAttributes: sourcePixelBufferAttributes
            )

            if writer.canAdd(videoWriterInput) {
                writer.add(videoWriterInput)
            }

            // Audio settings
            let audioSettings: [String: Any] = [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: 44100,
                AVNumberOfChannelsKey: 2,
                AVEncoderBitRateKey: 128000
            ]

            let audioWriterInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
            audioWriterInput.expectsMediaDataInRealTime = true

            if writer.canAdd(audioWriterInput) {
                writer.add(audioWriterInput)
            }

            self.assetWriter = writer
            self.videoWriterInput = videoWriterInput
            self.audioWriterInput = audioWriterInput
            self.pixelBufferAdaptor = pixelBufferAdaptor

            writer.startWriting()
            writer.startSession(atSourceTime: .zero)

            isWriting = true
            recordingStartTime = nil

        } catch {
            print("Failed to setup asset writer: \(error)")
        }
    }

    private func finishAssetWriter() {
        guard let assetWriter = assetWriter, isWriting else { return }

        isWriting = false

        videoWriterInput?.markAsFinished()
        audioWriterInput?.markAsFinished()

        assetWriter.finishWriting { [weak self] in
            if assetWriter.status == .completed {
                print("Combined video saved successfully")
            } else if let error = assetWriter.error {
                print("Asset writer error: \(error)")
            }

            self?.assetWriter = nil
            self?.videoWriterInput = nil
            self?.audioWriterInput = nil
            self?.pixelBufferAdaptor = nil
            self?.frameCompositor = nil
            self?.recordingStartTime = nil
        }
    }
}
