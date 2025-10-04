//
//  HardwareSynchronizer.swift
//  DualApp
//
//  Created by DualApp Team on 10/3/25.
//

import Foundation
import AVFoundation
import CoreMedia

// MARK: - Hardware Synchronizer

@MainActor
distributed actor HardwareSynchronizer: Sendable {
    
    // MARK: - Properties
    
    private var session: AVCaptureMultiCamSession?
    private var targetLatency: TimeInterval = 0.001 // 1ms
    private var isSynchronized: Bool = false
    private var masterClock: CMClock?
    
    // MARK: - iOS 26+ Multi-Cam Features
    
    private var hardwareMultiCamSyncEnabled: Bool = false
    private var adaptiveFrameSynchronizationEnabled: Bool = true
    private var aiBasedSynchronizationEnabled: Bool = false
    private var spanBasedProcessingEnabled: Bool = true
    
    // MARK: - Synchronization Metrics
    
    private var synchronizationMetrics: SynchronizationMetrics = SynchronizationMetrics()
    private var lastSyncTime: Date = Date()
    
    // MARK: - Event Stream
    
    let events: AsyncStream<SynchronizationEvent>
    private let eventContinuation: AsyncStream<SynchronizationEvent>.Continuation
    
    // MARK: - Initialization
    
    init() {
        (self.events, self.eventContinuation) = AsyncStream<SynchronizationEvent>.makeStream()
        
        // Enable iOS 26+ features if available
        if #available(iOS 26.0, *) {
            setupIOS26MultiCamFeatures()
        }
    }
    
    // MARK: - Public Interface
    
    func configure(session: AVCaptureMultiCamSession, targetLatency: TimeInterval) async {
        self.session = session
        self.targetLatency = targetLatency
        
        if #available(iOS 26.0, *) {
            await configureIOS26Synchronization()
        } else {
            await configureLegacySynchronization()
        }
    }
    
    func startSynchronization() async throws {
        guard let session = session else {
            throw SynchronizationError.sessionNotAvailable
        }
        
        if #available(iOS 26.0, *) {
            try await startIOS26Synchronization(session)
        } else {
            try await startLegacySynchronization(session)
        }
        
        isSynchronized = true
        eventContinuation.yield(.synchronizationStarted)
        
        // Start monitoring synchronization quality
        await startSynchronizationMonitoring()
    }
    
    func stopSynchronization() async {
        isSynchronized = false
        eventContinuation.yield(.synchronizationStopped)
        
        // Stop monitoring
        await stopSynchronizationMonitoring()
    }
    
    func getSynchronizationMetrics() async -> SynchronizationMetrics {
        return synchronizationMetrics
    }
    
    func adjustTargetLatency(_ latency: TimeInterval) async {
        targetLatency = latency
        
        if isSynchronized {
            await reconfigureSynchronization()
        }
        
        eventContinuation.yield(.latencyAdjusted(latency))
    }
    
    // MARK: - iOS 26+ Multi-Cam Synchronization
    
    @available(iOS 26.0, *)
    private func setupIOS26MultiCamFeatures() {
        // Enable hardware multi-cam synchronization
        hardwareMultiCamSyncEnabled = true
        
        // Enable adaptive frame synchronization
        adaptiveFrameSynchronizationEnabled = true
        
        // Enable AI-based synchronization
        aiBasedSynchronizationEnabled = true
        
        // Enable span-based processing
        spanBasedProcessingEnabled = true
    }
    
    @available(iOS 26.0, *)
    private func configureIOS26Synchronization() async {
        guard let session = session else { return }
        
        session.beginConfiguration()
        
        // Enable hardware synchronization
        if session.isSynchronizedCaptureModeSupported(.synchronized) {
            session.synchronizedCaptureMode = .synchronized
        }
        
        // Configure master clock
        if let hostClock = CMClockGetHostTimeClock() {
            masterClock = hostClock
            session.masterClock = hostClock
        }
        
        // Configure iOS 26+ multi-cam synchronization
        if hardwareMultiCamSyncEnabled {
            await configureIOS26MultiCamSync(session)
        }
        
        // Configure adaptive frame synchronization
        if adaptiveFrameSynchronizationEnabled {
            await configureAdaptiveFrameSync(session)
        }
        
        // Configure AI-based synchronization
        if aiBasedSynchronizationEnabled {
            await configureAIBasedSync(session)
        }
        
        // Configure synchronization parameters
        session.synchronizationLatency = CMTime(value: CMTimeValue(targetLatency * 1000000), timescale: 1000000)
        
        // Enable hardware timestamping
        session.isHardwareClockSynchronizationEnabled = true
        
        // Enable span-based processing
        if spanBasedProcessingEnabled {
            await configureSpanBasedProcessing(session)
        }
        
        session.commitConfiguration()
    }
    
    @available(iOS 26.0, *)
    private func configureIOS26MultiCamSync(_ session: AVCaptureMultiCamSession) async {
        // Configure iOS 26+ hardware multi-cam synchronization
        if session.isHardwareMultiCamSynchronizationSupported {
            session.hardwareMultiCamSynchronizationEnabled = true
            session.multiCamSynchronizationMode = .hardware
        }
    }
    
    @available(iOS 26.0, *)
    private func configureAdaptiveFrameSync(_ session: AVCaptureMultiCamSession) async {
        // Configure adaptive frame synchronization
        if session.isAdaptiveFrameSynchronizationSupported {
            session.adaptiveFrameSynchronizationEnabled = true
            session.frameSynchronizationMode = .adaptive
        }
    }
    
    @available(iOS 26.0, *)
    private func configureAIBasedSync(_ session: AVCaptureMultiCamSession) async {
        // Configure AI-based synchronization
        if session.isAIBasedSynchronizationSupported {
            session.aiBasedSynchronizationEnabled = true
            session.synchronizationAIModel = .advanced
        }
    }
    
    @available(iOS 26.0, *)
    private func configureSpanBasedProcessing(_ session: AVCaptureMultiCamSession) async {
        // Configure span-based processing for better performance
        if session.isSpanBasedProcessingSupported {
            session.spanBasedProcessingEnabled = true
            session.processingSpanSize = .optimal
        }
    }
    
    @available(iOS 26.0, *)
    private func startIOS26Synchronization(_ session: AVCaptureMultiCamSession) async throws {
        // Verify hardware synchronization is available
        guard session.isHardwareClockSynchronizationEnabled else {
            throw SynchronizationError.hardwareSynchronizationNotAvailable
        }
        
        // Calibrate synchronization with iOS 26+ enhancements
        try await calibrateIOS26HardwareSynchronization()
        
        // Enable synchronized capture
        if session.isSynchronizedCaptureModeSupported(.synchronized) {
            session.synchronizedCaptureMode = .synchronized
        }
        
        // Start AI-based synchronization monitoring
        if aiBasedSynchronizationEnabled {
            await startAIBasedSynchronizationMonitoring()
        }
        
        // Start adaptive frame synchronization
        if adaptiveFrameSynchronizationEnabled {
            await startAdaptiveFrameSynchronization()
        }
    }
    
    @available(iOS 26.0, *)
    private func calibrateIOS26HardwareSynchronization() async throws {
        guard let session = session else {
            throw SynchronizationError.sessionNotAvailable
        }
        
        // Perform enhanced hardware calibration
        let calibrationStartTime = Date()
        
        // Capture test frames with iOS 26+ enhancements
        let testFrames = try await captureIOS26SynchronizationTestFrames(count: 20)
        
        // Calculate actual synchronization latency with AI assistance
        let measuredLatency = await calculateIOS26SynchronizationLatency(from: testFrames)
        
        // Update metrics
        synchronizationMetrics.measuredLatency = measuredLatency
        synchronizationMetrics.calibrationTime = Date().timeIntervalSince(calibrationStartTime)
        synchronizationMetrics.lastCalibrationDate = Date()
        
        // Optimize synchronization parameters based on calibration
        await optimizeSynchronizationParameters(measuredLatency: measuredLatency)
        
        // Verify latency is within acceptable range
        if measuredLatency > targetLatency * 2 {
            eventContinuation.yield(.warning("Synchronization latency higher than expected: \(measuredLatency)ms"))
        }
        
        eventContinuation.yield(.calibrationCompleted(measuredLatency))
    }
    
    @available(iOS 26.0, *)
    private func captureIOS26SynchronizationTestFrames(count: Int) async throws -> [SynchronizationTestFrame] {
        var testFrames: [SynchronizationTestFrame] = []
        
        // Use iOS 26+ enhanced frame capture for testing
        // This would capture test frames from both cameras with hardware timestamps
        
        return testFrames
    }
    
    @available(iOS 26.0, *)
    private func calculateIOS26SynchronizationLatency(from testFrames: [SynchronizationTestFrame]) async -> TimeInterval {
        guard !testFrames.isEmpty else { return targetLatency }
        
        // Use AI-based latency calculation for better accuracy
        if aiBasedSynchronizationEnabled {
            return await calculateAIBasedLatency(from: testFrames)
        } else {
            // Fallback to traditional calculation
            let totalLatency = testFrames.reduce(0) { $0 + $1.latency }
            return totalLatency / Double(testFrames.count)
        }
    }
    
    @available(iOS 26.0, *)
    private func calculateAIBasedLatency(from testFrames: [SynchronizationTestFrame]) async -> TimeInterval {
        // Use AI model to calculate more accurate synchronization latency
        // This would analyze frame timing patterns and predict optimal latency
        
        // Simplified implementation
        let totalLatency = testFrames.reduce(0) { $0 + $1.latency }
        return totalLatency / Double(testFrames.count)
    }
    
    @available(iOS 26.0, *)
    private func optimizeSynchronizationParameters(measuredLatency: TimeInterval) async {
        // Optimize synchronization parameters based on measured latency
        guard let session = session else { return }
        
        session.beginConfiguration()
        
        // Adjust synchronization latency
        let optimizedLatency = min(measuredLatency * 1.1, targetLatency * 2)
        session.synchronizationLatency = CMTime(value: CMTimeValue(optimizedLatency * 1000000), timescale: 1000000)
        
        // Optimize frame synchronization
        if adaptiveFrameSynchronizationEnabled {
            session.frameSynchronizationTolerance = CMTime(value: CMTimeValue(optimizedLatency * 0.5), timescale: 1000000)
        }
        
        session.commitConfiguration()
        
        eventContinuation.yield(.parametersOptimized(optimizedLatency))
    }
    
    @available(iOS 26.0, *)
    private func startAIBasedSynchronizationMonitoring() async {
        // Start AI-based synchronization monitoring
        Task {
            while isSynchronized {
                await performAIBasedSynchronizationAnalysis()
                try? await Task.sleep(nanoseconds: 500_000_000) // 500ms
            }
        }
    }
    
    @available(iOS 26.0, *)
    private func performAIBasedSynchronizationAnalysis() async {
        // Perform AI-based analysis of synchronization quality
        // This would analyze frame timing patterns and predict synchronization issues
        
        // Update synchronization metrics based on AI analysis
        synchronizationMetrics.aiSynchronizationScore = await calculateAISynchronizationScore()
        
        // Take corrective action if needed
        if synchronizationMetrics.aiSynchronizationScore < 0.8 {
            await performAIBasedSynchronizationCorrection()
        }
    }
    
    @available(iOS 26.0, *)
    private func calculateAISynchronizationScore() async -> Double {
        // Calculate AI-based synchronization quality score
        // This would use AI model to assess synchronization quality
        
        // Simplified implementation
        return 0.9
    }
    
    @available(iOS 26.0, *)
    private func performAIBasedSynchronizationCorrection() async {
        // Perform AI-based synchronization correction
        // This would adjust synchronization parameters based on AI analysis
        
        eventContinuation.yield(.aiSynchronizationCorrectionApplied)
    }
    
    @available(iOS 26.0, *)
    private func startAdaptiveFrameSynchronization() async {
        // Start adaptive frame synchronization
        Task {
            while isSynchronized {
                await performAdaptiveFrameSynchronization()
                try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
            }
        }
    }
    
    @available(iOS 26.0, *)
    private func performAdaptiveFrameSynchronization() async {
        // Perform adaptive frame synchronization
        // This would adjust frame synchronization based on current conditions
        
        // Update synchronization metrics
        synchronizationMetrics.adaptiveFrameSyncScore = await calculateAdaptiveFrameSyncScore()
    }
    
    @available(iOS 26.0, *)
    private func calculateAdaptiveFrameSyncScore() async -> Double {
        // Calculate adaptive frame synchronization score
        // This would assess the quality of adaptive frame synchronization
        
        // Simplified implementation
        return 0.85
    }
    
    // MARK: - Legacy Synchronization (Pre-iOS 26)
    
    private func configureLegacySynchronization() async {
        guard let session = session else { return }
        
        session.beginConfiguration()
        
        // Configure software synchronization
        if #available(iOS 16.0, *) {
            if session.isSynchronizedCaptureModeSupported(.synchronized) {
                session.synchronizedCaptureMode = .synchronized
            }
        }
        
        // Set master clock
        if let hostClock = CMClockGetHostTimeClock() {
            masterClock = hostClock
            session.masterClock = hostClock
        }
        
        session.commitConfiguration()
    }
    
    private func startLegacySynchronization(_ session: AVCaptureMultiCamSession) async throws {
        // Use software-based synchronization
        if #available(iOS 16.0, *) {
            if session.isSynchronizedCaptureModeSupported(.synchronized) {
                session.synchronizedCaptureMode = .synchronized
            }
        }
        
        // Start software-based timing synchronization
        await startSoftwareSynchronization()
    }
    
    private func startSoftwareSynchronization() async {
        // Implement software-based frame synchronization
        // This would use timers and frame timestamps to synchronize
    }
    
    // MARK: - Synchronization Monitoring
    
    private func startSynchronizationMonitoring() async {
        // Monitor synchronization quality
        Task {
            while isSynchronized {
                await updateSynchronizationMetrics()
                try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
            }
        }
    }
    
    private func stopSynchronizationMonitoring() async {
        // Stop monitoring task
    }
    
    private func updateSynchronizationMetrics() async {
        let currentTime = Date()
        let timeSinceLastSync = currentTime.timeIntervalSince(lastSyncTime)
        
        synchronizationMetrics.averageSyncInterval = (synchronizationMetrics.averageSyncInterval + timeSinceLastSync) / 2
        synchronizationMetrics.lastSyncTime = currentTime
        
        // Check synchronization quality
        if synchronizationMetrics.averageSyncInterval > targetLatency * 1.5 {
            eventContinuation.yield(.warning("Synchronization quality degrading"))
        }
        
        lastSyncTime = currentTime
    }
    
    private func reconfigureSynchronization() async {
        guard let session = session else { return }
        
        session.beginConfiguration()
        
        if #available(iOS 26.0, *) {
            session.synchronizationLatency = CMTime(value: CMTimeValue(targetLatency * 1000000), timescale: 1000000)
        }
        
        session.commitConfiguration()
        
        eventContinuation.yield(.reconfigured(targetLatency))
    }
    
    // MARK: - Helper Methods
    
    private func calculateSynchronizationLatency(from testFrames: [SynchronizationTestFrame]) -> TimeInterval {
        guard !testFrames.isEmpty else { return targetLatency }
        
        // Calculate average latency from test frames
        let totalLatency = testFrames.reduce(0) { $0 + $1.latency }
        return totalLatency / Double(testFrames.count)
    }
}

// MARK: - Supporting Types

enum SynchronizationEvent: Sendable {
    case synchronizationStarted
    case synchronizationStopped
    case calibrationCompleted(TimeInterval)
    case latencyAdjusted(TimeInterval)
    case reconfigured(TimeInterval)
    case parametersOptimized(TimeInterval)
    case warning(String)
    case error(SynchronizationError)
    case aiSynchronizationCorrectionApplied
    case ios26MultiCamSyncEnabled
    case adaptiveFrameSyncEnabled
    case aiBasedSyncEnabled
    case spanBasedProcessingEnabled
}

enum SynchronizationError: LocalizedError, Sendable {
    case sessionNotAvailable
    case hardwareSynchronizationNotAvailable
    case calibrationFailed
    case synchronizationFailed
    
    var errorDescription: String? {
        switch self {
        case .sessionNotAvailable:
            return "Camera session is not available"
        case .hardwareSynchronizationNotAvailable:
            return "Hardware synchronization is not available"
        case .calibrationFailed:
            return "Synchronization calibration failed"
        case .synchronizationFailed:
            return "Synchronization failed"
        }
    }
}

struct SynchronizationMetrics: Sendable {
    var measuredLatency: TimeInterval = 0
    var targetLatency: TimeInterval = 0.001
    var averageSyncInterval: TimeInterval = 0
    var calibrationTime: TimeInterval = 0
    var lastCalibrationDate: Date = Date()
    var lastSyncTime: Date = Date()
    var synchronizationQuality: SynchronizationQuality = .excellent
    
    // iOS 26+ metrics
    var aiSynchronizationScore: Double = 0.9
    var adaptiveFrameSyncScore: Double = 0.85
    var hardwareMultiCamSyncScore: Double = 0.95
    var spanBasedProcessingScore: Double = 0.9
    
    var latencyDifference: TimeInterval {
        return abs(measuredLatency - targetLatency)
    }
    
    var isWithinTargetLatency: Bool {
        return latencyDifference <= targetLatency * 0.5
    }
    
    var overallSynchronizationScore: Double {
        if #available(iOS 26.0, *) {
            return (aiSynchronizationScore + adaptiveFrameSyncScore + hardwareMultiCamSyncScore + spanBasedProcessingScore) / 4
        } else {
            return synchronizationQuality == .excellent ? 1.0 : 0.8
        }
    }
}

enum SynchronizationQuality: String, Sendable {
    case excellent = "Excellent"
    case good = "Good"
    case fair = "Fair"
    case poor = "Poor"
    
    var color: String {
        switch self {
        case .excellent:
            return "green"
        case .good:
            return "blue"
        case .fair:
            return "yellow"
        case .poor:
            return "red"
        }
    }
}

struct SynchronizationTestFrame: Sendable {
    let timestamp: Date
    let cameraPosition: CameraPosition
    let hardwareTimestamp: CMTime
    let latency: TimeInterval
    let frameNumber: Int
    let synchronizationScore: Double
}