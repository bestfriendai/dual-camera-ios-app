// Dual Camera App
import AVFoundation
import UIKit
import os.log

protocol RecordingCoordinatorDelegate: AnyObject {
    func recordingDidStart()
    func recordingDidStop(frontURL: URL?, backURL: URL?)
    func recordingDidFail(_ error: Error)
    func recordingProgressUpdated(_ duration: TimeInterval)
}

final class RecordingCoordinator: NSObject {
    
    enum RecordingPhase {
        case idle
        case countingDown(remaining: Int)
        case recording
        case paused
        case stopping
    }
    
    enum RecordingError: LocalizedError {
        case alreadyRecording
        case notRecording
        case outputSetupFailed(String)
        case fileCreationFailed
        case invalidSession
        
        var errorDescription: String? {
            switch self {
            case .alreadyRecording:
                return "Recording already in progress"
            case .notRecording:
                return "No active recording"
            case .outputSetupFailed(let reason):
                return "Failed to setup recording: \(reason)"
            case .fileCreationFailed:
                return "Failed to create recording file"
            case .invalidSession:
                return "Invalid capture session"
            }
        }
    }
    
    weak var delegate: RecordingCoordinatorDelegate?
    
    private let logger = Logger(subsystem: "com.dualcameraapp", category: "RecordingCoordinator")
    private let sessionQueue = DispatchQueue(label: "RecordingCoordinator.Queue")
    
    private(set) var phase: RecordingPhase = .idle
    
    private var frontMovieOutput: AVCaptureMovieFileOutput?
    private var backMovieOutput: AVCaptureMovieFileOutput?
    
    private var frontRecordingURL: URL?
    private var backRecordingURL: URL?
    
    private var recordingStartTime: Date?
    private var progressTimer: Timer?
    
    private var frontDevice: AVCaptureDevice?
    private var backDevice: AVCaptureDevice?
    
    func setupOutputs(session: AVCaptureMultiCamSession, frontDevice: AVCaptureDevice, backDevice: AVCaptureDevice) throws {
        var setupError: RecordingError?
        
        sessionQueue.sync {
            self.frontDevice = frontDevice
            self.backDevice = backDevice
            
            let frontOutput = AVCaptureMovieFileOutput()
            let backOutput = AVCaptureMovieFileOutput()
            
            frontOutput.movieFragmentInterval = .invalid
            backOutput.movieFragmentInterval = .invalid
            
            session.beginConfiguration()
            
            guard session.canAddOutput(frontOutput) else {
                session.commitConfiguration()
                setupError = RecordingError.outputSetupFailed("Cannot add front output")
                return
            }
            session.addOutput(frontOutput)
            
            guard session.canAddOutput(backOutput) else {
                session.commitConfiguration()
                setupError = RecordingError.outputSetupFailed("Cannot add back output")
                return
            }
            session.addOutput(backOutput)
            
            if let frontConnection = frontOutput.connection(with: .video) {
                if frontConnection.isVideoStabilizationSupported {
                    frontConnection.preferredVideoStabilizationMode = .auto
                }
                frontConnection.videoOrientation = .portrait
            }
            
            if let backConnection = backOutput.connection(with: .video) {
                if backConnection.isVideoStabilizationSupported {
                    backConnection.preferredVideoStabilizationMode = .auto
                }
                backConnection.videoOrientation = .portrait
            }
            
            session.commitConfiguration()
            
            self.frontMovieOutput = frontOutput
            self.backMovieOutput = backOutput
            
            logger.info("Recording outputs configured successfully")
        }
        
        if let error = setupError {
            throw error
        }
    }
    
    func startRecording() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            
            guard case .idle = self.phase else {
                DispatchQueue.main.async {
                    self.delegate?.recordingDidFail(RecordingError.alreadyRecording)
                }
                return
            }
            
            guard let frontOutput = self.frontMovieOutput,
                  let backOutput = self.backMovieOutput else {
                DispatchQueue.main.async {
                    self.delegate?.recordingDidFail(RecordingError.outputSetupFailed("Outputs not configured"))
                }
                return
            }
            
            let frontURL = self.createTemporaryURL(prefix: "front")
            let backURL = self.createTemporaryURL(prefix: "back")
            
            guard let frontURL = frontURL, let backURL = backURL else {
                DispatchQueue.main.async {
                    self.delegate?.recordingDidFail(RecordingError.fileCreationFailed)
                }
                return
            }
            
            self.frontRecordingURL = frontURL
            self.backRecordingURL = backURL
            
            frontOutput.startRecording(to: frontURL, recordingDelegate: self)
            backOutput.startRecording(to: backURL, recordingDelegate: self)
            
            self.phase = .recording
            self.recordingStartTime = Date()
            
            DispatchQueue.main.async {
                self.delegate?.recordingDidStart()
                self.startProgressTimer()
            }
            
            self.logger.info("Started recording to \(frontURL.path) and \(backURL.path)")
        }
    }
    
    func stopRecording() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            
            guard case .recording = self.phase else {
                DispatchQueue.main.async {
                    self.delegate?.recordingDidFail(RecordingError.notRecording)
                }
                return
            }
            
            self.phase = .stopping
            
            self.frontMovieOutput?.stopRecording()
            self.backMovieOutput?.stopRecording()
            
            DispatchQueue.main.async {
                self.stopProgressTimer()
            }
            
            self.logger.info("Stopped recording")
        }
    }
    
    private func createTemporaryURL(prefix: String) -> URL? {
        let tempDir = FileManager.default.temporaryDirectory
        let filename = "\(prefix)_\(UUID().uuidString).mov"
        return tempDir.appendingPathComponent(filename)
    }
    
    private func startProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, let startTime = self.recordingStartTime else { return }
            let duration = Date().timeIntervalSince(startTime)
            self.delegate?.recordingProgressUpdated(duration)
        }
    }
    
    private func stopProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = nil
    }
    
    private var finishedOutputCount = 0
    
    private func handleRecordingFinished() {
        finishedOutputCount += 1
        
        if finishedOutputCount >= 2 {
            finishedOutputCount = 0
            phase = .idle
            recordingStartTime = nil
            
            let frontURL = self.frontRecordingURL
            let backURL = self.backRecordingURL
            
            self.frontRecordingURL = nil
            self.backRecordingURL = nil
            
            DispatchQueue.main.async {
                self.delegate?.recordingDidStop(frontURL: frontURL, backURL: backURL)
            }
        }
    }
}

extension RecordingCoordinator: AVCaptureFileOutputRecordingDelegate {
    func fileOutput(_ output: AVCaptureFileOutput, didStartRecordingTo fileURL: URL, from connections: [AVCaptureConnection]) {
        logger.info("File output started recording: \(fileURL.lastPathComponent)")
    }
    
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        if let error = error {
            logger.error("Recording finished with error: \(error.localizedDescription)")
            DispatchQueue.main.async {
                self.delegate?.recordingDidFail(error)
            }
            phase = .idle
            finishedOutputCount = 0
            return
        }
        
        logger.info("File output finished recording: \(outputFileURL.lastPathComponent)")
        handleRecordingFinished()
    }
}
