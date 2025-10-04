// Dual Camera App
import AVFoundation
import UIKit
import os.log

@MainActor
protocol RecordingCoordinatorDelegate: AnyObject {
    func recordingDidStart()
    func recordingDidStop(frontURL: URL?, backURL: URL?)
    func recordingDidFail(_ error: Error)
    func recordingProgressUpdated(_ duration: TimeInterval)
}

@MainActor
class RecordingCoordinator: NSObject {
    
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
    
    private(set) var phase: RecordingPhase = .idle
    
    private var frontMovieOutput: AVCaptureMovieFileOutput?
    private var backMovieOutput: AVCaptureMovieFileOutput?
    
    private var frontRecordingURL: URL?
    private var backRecordingURL: URL?
    
    private var recordingStartTime: Date?
    private var progressTask: Task<Void, Never>?
    
    private var frontDevice: AVCaptureDevice?
    private var backDevice: AVCaptureDevice?
    
    func setupOutputs(session: AVCaptureMultiCamSession, frontDevice: AVCaptureDevice, backDevice: AVCaptureDevice) throws {
        self.frontDevice = frontDevice
        self.backDevice = backDevice
        
        let frontOutput = AVCaptureMovieFileOutput()
        let backOutput = AVCaptureMovieFileOutput()
        
        frontOutput.movieFragmentInterval = .invalid
        backOutput.movieFragmentInterval = .invalid
        
        session.beginConfiguration()
        
        guard session.canAddOutput(frontOutput) else {
            session.commitConfiguration()
            throw RecordingError.outputSetupFailed("Cannot add front output")
        }
        session.addOutput(frontOutput)
        
        guard session.canAddOutput(backOutput) else {
            session.commitConfiguration()
            throw RecordingError.outputSetupFailed("Cannot add back output")
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
    
    func startRecording() {
        guard case .idle = self.phase else {
            delegate?.recordingDidFail(RecordingError.alreadyRecording)
            return
        }
        
        guard let frontOutput = frontMovieOutput, let backOutput = backMovieOutput else {
            delegate?.recordingDidFail(RecordingError.outputSetupFailed("Outputs not configured"))
            return
        }
        
        guard let frontURL = createTemporaryURL(prefix: "front"),
              let backURL = createTemporaryURL(prefix: "back") else {
            delegate?.recordingDidFail(RecordingError.fileCreationFailed)
            return
        }
        
        self.frontRecordingURL = frontURL
        self.backRecordingURL = backURL
        
        frontOutput.startRecording(to: frontURL, recordingDelegate: self)
        backOutput.startRecording(to: backURL, recordingDelegate: self)
        
        delegate?.recordingDidStart()
        startProgressTimer()
        
        self.logger.info("Started recording to \(frontURL.path) and \(backURL.path)")
    }
    
    func stopRecording() {
        guard case .recording = self.phase else {
            delegate?.recordingDidFail(RecordingError.notRecording)
            return
        }
        
        self.phase = .stopping
        
        self.frontMovieOutput?.stopRecording()
        self.backMovieOutput?.stopRecording()
        
        stopProgressTimer()
        
        self.logger.info("Stopped recording")
    }
    
    private func createTemporaryURL(prefix: String) -> URL? {
        let tempDir = FileManager.default.temporaryDirectory
        let filename = "\(prefix)_\(UUID().uuidString).mov"
        return tempDir.appendingPathComponent(filename)
    }
    
    private func startProgressTimer() {
        progressTask?.cancel()
        progressTask = Task { @MainActor in
            while !Task.isCancelled {
                if #available(iOS 16.0, *) {
                    try? await Task.sleep(for: .milliseconds(100))
                } else {
                    try? await Task.sleep(nanoseconds: 100_000_000)
                }
                if let startTime = self.recordingStartTime {
                    let duration = Date().timeIntervalSince(startTime)
                    self.delegate?.recordingProgressUpdated(duration)
                }
            }
        }
    }
    
    private func stopProgressTimer() {
        progressTask?.cancel()
        progressTask = nil
    }
    
    private var finishedOutputCount = 0
    
    private func handleRecordingFinished() {
        self.finishedOutputCount += 1
        
        if self.finishedOutputCount >= 2 {
            let frontURL = self.frontRecordingURL
            let backURL = self.backRecordingURL
            
            self.finishedOutputCount = 0
            self.phase = .idle
            self.recordingStartTime = nil
            self.frontRecordingURL = nil
            self.backRecordingURL = nil
            
            delegate?.recordingDidStop(frontURL: frontURL, backURL: backURL)
        }
    }
}

extension RecordingCoordinator: AVCaptureFileOutputRecordingDelegate {
    nonisolated func fileOutput(_ output: AVCaptureFileOutput, didStartRecordingTo fileURL: URL, from connections: [AVCaptureConnection]) {
        logger.info("File output started recording: \(fileURL.lastPathComponent)")
    }
    
    nonisolated func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        if let error = error {
            logger.error("Recording finished with error: \(error.localizedDescription)")
            Task { @MainActor in
                self.delegate?.recordingDidFail(error)
            }
            Task { @MainActor in
                self.setIdlePhase()
            }
            return
        }
        
        logger.info("File output finished recording: \(outputFileURL.lastPathComponent)")
        Task { @MainActor in
            handleRecordingFinished()
        }
    }
    
    private func setIdlePhase() {
        phase = .idle
        finishedOutputCount = 0
    }
}
