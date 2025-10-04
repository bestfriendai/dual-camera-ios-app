//
//  FrameSyncCoordinator.swift
//  DualApp
//
//  Created by DualApp Team on 10/3/25.
//

import Foundation
import AVFoundation
import CoreMedia

// MARK: - Frame Sync Coordinator

actor FrameSyncCoordinator {
    
    // MARK: - Properties
    
    private var isSynchronizing: Bool = false
    private var frameBuffer: FrameBuffer
    private var syncWindow: TimeInterval = 0.016 // 16ms (60fps)
    private var maxFrameAge: TimeInterval = 0.1 // 100ms
    
    // MARK: - Frame Queues
    
    private var frontFrameQueue: [DualCameraFrame] = []
    private var backFrameQueue: [DualCameraFrame] = []
    private let maxQueueSize: Int = 10
    
    // MARK: - Synchronization State
    
    private var lastSyncTime: Date = Date()
    private var syncStatistics: FrameSyncStatistics = FrameSyncStatistics()
    private var driftCompensation: DriftCompensation = DriftCompensation()
    
    // MARK: - Event Stream
    
    let events: AsyncStream<FrameSyncEvent>
    private let eventContinuation: AsyncStream<FrameSyncEvent>.Continuation
    
    // MARK: - Synchronization Task
    
    private var synchronizationTask: Task<Void, Never>?
    
    // MARK: - Initialization
    
    init() {
        (self.events, self.eventContinuation) = AsyncStream<FrameSyncEvent>.makeStream()
        self.frameBuffer = FrameBuffer()
    }
    
    // MARK: - Public Interface
    
    func startSynchronization() async {
        guard !isSynchronizing else { return }
        
        isSynchronizing = true
        lastSyncTime = Date()
        
        // Start synchronization task
        synchronizationTask = Task {
            await synchronizationLoop()
        }
        
        eventContinuation.yield(.synchronizationStarted)
    }
    
    func stopSynchronization() async {
        isSynchronizing = false
        synchronizationTask?.cancel()
        synchronizationTask = nil
        
        // Clear queues
        frontFrameQueue.removeAll()
        backFrameQueue.removeAll()
        frameBuffer.clear()
        
        eventContinuation.yield(.synchronizationStopped)
    }
    
    func addFrame(_ frame: DualCameraFrame) async {
        guard isSynchronizing else { return }
        
        // Add to appropriate queue
        switch frame.position {
        case .front:
            await addFrameToFrontQueue(frame)
        case .back:
            await addFrameToBackQueue(frame)
        default:
            break
        }
        
        // Update statistics
        await updateFrameStatistics(frame)
    }
    
    func setSyncWindow(_ window: TimeInterval) async {
        syncWindow = window
        eventContinuation.yield(.syncWindowChanged(window))
    }
    
    func setMaxFrameAge(_ age: TimeInterval) async {
        maxFrameAge = age
        eventContinuation.yield(.maxFrameAgeChanged(age))
    }
    
    func getSyncStatistics() async -> FrameSyncStatistics {
        return syncStatistics
    }
    
    func getSynchronizedFrames() async -> SynchronizedFramePair? {
        return frameBuffer.getNextSynchronizedPair()
    }
    
    // MARK: - Private Methods
    
    private func synchronizationLoop() async {
        while isSynchronizing && !Task.isCancelled {
            await processFrameSynchronization()
            try? await Task.sleep(nanoseconds: UInt64(syncWindow * 1_000_000_000))
        }
    }
    
    private func processFrameSynchronization() async {
        let currentTime = Date()
        
        // Remove old frames
        await removeOldFrames(currentTime: currentTime)
        
        // Find synchronized frame pairs
        await findSynchronizedFrames(currentTime: currentTime)
        
        // Update drift compensation
        await updateDriftCompensation(currentTime: currentTime)
        
        // Update sync statistics
        await updateSyncStatistics(currentTime: currentTime)
    }
    
    private func addFrameToFrontQueue(_ frame: DualCameraFrame) async {
        // Remove oldest frames if queue is full
        if frontFrameQueue.count >= maxQueueSize {
            frontFrameQueue.removeFirst()
        }

        frontFrameQueue.append(frame)

        // Sort by timestamp
        frontFrameQueue.sort { $0.timestamp < $1.timestamp }
    }

    private func addFrameToBackQueue(_ frame: DualCameraFrame) async {
        // Remove oldest frames if queue is full
        if backFrameQueue.count >= maxQueueSize {
            backFrameQueue.removeFirst()
        }

        backFrameQueue.append(frame)

        // Sort by timestamp
        backFrameQueue.sort { $0.timestamp < $1.timestamp }
    }
    
    private func removeOldFrames(currentTime: Date) async {
        let cutoffTime = currentTime.addingTimeInterval(-maxFrameAge)
        
        frontFrameQueue.removeAll { $0.timestamp < cutoffTime }
        backFrameQueue.removeAll { $0.timestamp < cutoffTime }
    }
    
    private func findSynchronizedFrames(currentTime: Date) async {
        guard !frontFrameQueue.isEmpty && !backFrameQueue.isEmpty else { return }
        
        // Find best synchronized pair
        var bestPair: SynchronizedFramePair?
        var bestScore: Double = Double.infinity
        
        for frontFrame in frontFrameQueue {
            for backFrame in backFrameQueue {
                let timeDifference = abs(frontFrame.timestamp.timeIntervalSince(backFrame.timestamp))
                let score = calculateSynchronizationScore(
                    frontFrame: frontFrame,
                    backFrame: backFrame,
                    timeDifference: timeDifference,
                    currentTime: currentTime
                )
                
                if score < bestScore && timeDifference <= syncWindow {
                    bestScore = score
                    bestPair = SynchronizedFramePair(
                        frontFrame: frontFrame,
                        backFrame: backFrame,
                        synchronizationScore: score,
                        timeDifference: timeDifference
                    )
                }
            }
        }
        
        // Add synchronized pair to buffer
        if let pair = bestPair {
            frameBuffer.addSynchronizedPair(pair)
            
            // Remove used frames from queues
            frontFrameQueue.removeAll { $0.timestamp <= pair.frontFrame.timestamp }
            backFrameQueue.removeAll { $0.timestamp <= pair.backFrame.timestamp }
            
            // Emit synchronized frame event
            eventContinuation.yield(.framesSynchronized(pair))
            
            // Update statistics
            syncStatistics.synchronizedPairs += 1
            syncStatistics.averageTimeDifference = (syncStatistics.averageTimeDifference + pair.timeDifference) / 2
        }
    }
    
    private func calculateSynchronizationScore(
        frontFrame: DualCameraFrame,
        backFrame: DualCameraFrame,
        timeDifference: TimeInterval,
        currentTime: Date
    ) -> Double {
        // Base score is time difference
        var score = timeDifference
        
        // Apply drift compensation
        let compensatedDifference = driftCompensation.compensate(timeDifference, for: frontFrame.position)
        score += abs(compensatedDifference - timeDifference)
        
        // Consider frame age
        let frontAge = currentTime.timeIntervalSince(frontFrame.timestamp)
        let backAge = currentTime.timeIntervalSince(backFrame.timestamp)
        let maxAge = max(frontAge, backAge)
        
        if maxAge > maxFrameAge * 0.5 {
            score += maxAge * 0.1
        }
        
        return score
    }
    
    private func updateDriftCompensation(currentTime: Date) async {
        // Calculate time drift between cameras
        if let lastFrontFrame = frontFrameQueue.last,
           let lastBackFrame = backFrameQueue.last {
            
            let timeDifference = lastFrontFrame.timestamp.timeIntervalSince(lastBackFrame.timestamp)
            driftCompensation.updateDrift(timeDifference, timestamp: currentTime)
        }
    }
    
    private func updateFrameStatistics(_ frame: DualCameraFrame) async {
        syncStatistics.totalFrames += 1
        
        switch frame.position {
        case .front:
            syncStatistics.frontFrames += 1
        case .back:
            syncStatistics.backFrames += 1
        default:
            break
        }
    }
    
    private func updateSyncStatistics(currentTime: Date) async {
        syncStatistics.lastSyncTime = currentTime
        syncStatistics.syncInterval = currentTime.timeIntervalSince(lastSyncTime)
        lastSyncTime = currentTime
        
        // Calculate synchronization rate
        if syncStatistics.totalFrames > 0 {
            syncStatistics.synchronizationRate = Double(syncStatistics.synchronizedPairs) / Double(syncStatistics.totalFrames)
        }
        
        // Emit statistics update
        eventContinuation.yield(.statisticsUpdated(syncStatistics))
    }
}

// MARK: - Frame Buffer

class FrameBuffer: @unchecked Sendable {
    private var synchronizedPairs: [SynchronizedFramePair] = []
    private let maxBufferSize: Int = 30
    private let lock = NSLock()
    
    func addSynchronizedPair(_ pair: SynchronizedFramePair) {
        lock.lock()
        defer { lock.unlock() }
        
        synchronizedPairs.append(pair)
        
        // Remove oldest pairs if buffer is full
        if synchronizedPairs.count > maxBufferSize {
            synchronizedPairs.removeFirst()
        }
    }
    
    func getNextSynchronizedPair() -> SynchronizedFramePair? {
        lock.lock()
        defer { lock.unlock() }
        
        return synchronizedPairs.isEmpty ? nil : synchronizedPairs.removeFirst()
    }
    
    func clear() {
        lock.lock()
        defer { lock.unlock() }
        
        synchronizedPairs.removeAll()
    }
    
    func getBufferCount() -> Int {
        lock.lock()
        defer { lock.unlock() }
        
        return synchronizedPairs.count
    }
}

// MARK: - Drift Compensation

struct DriftCompensation: Sendable {
    private var driftValues: [TimeInterval] = []
    private let maxDriftValues: Int = 100
    private var averageDrift: TimeInterval = 0
    
    mutating func updateDrift(_ drift: TimeInterval, timestamp: Date) {
        driftValues.append(drift)
        
        if driftValues.count > maxDriftValues {
            driftValues.removeFirst()
        }
        
        // Calculate average drift
        averageDrift = driftValues.reduce(0, +) / Double(driftValues.count)
    }
    
    func compensate(_ timeDifference: TimeInterval, for position: CameraPosition) -> TimeInterval {
        // Apply drift compensation based on camera position
        let compensationFactor = position == .front ? 1.0 : -1.0
        return timeDifference + (averageDrift * compensationFactor * 0.5)
    }
    
    func getCurrentDrift() -> TimeInterval {
        return averageDrift
    }
}

// MARK: - Supporting Types

enum FrameSyncEvent: Sendable {
    case synchronizationStarted
    case synchronizationStopped
    case framesSynchronized(SynchronizedFramePair)
    case syncWindowChanged(TimeInterval)
    case maxFrameAgeChanged(TimeInterval)
    case statisticsUpdated(FrameSyncStatistics)
    case warning(String)
    case error(FrameSyncError)
}

enum FrameSyncError: LocalizedError, Sendable {
    case frameBufferOverflow
    case synchronizationTimeout
    case driftCompensationFailed
    
    var errorDescription: String? {
        switch self {
        case .frameBufferOverflow:
            return "Frame buffer overflow"
        case .synchronizationTimeout:
            return "Synchronization timeout"
        case .driftCompensationFailed:
            return "Drift compensation failed"
        }
    }
}

struct SynchronizedFramePair: Sendable {
    let frontFrame: DualCameraFrame
    let backFrame: DualCameraFrame
    let synchronizationScore: Double
    let timeDifference: TimeInterval
    let timestamp: Date
    
    init(frontFrame: DualCameraFrame, backFrame: DualCameraFrame, synchronizationScore: Double, timeDifference: TimeInterval) {
        self.frontFrame = frontFrame
        self.backFrame = backFrame
        self.synchronizationScore = synchronizationScore
        self.timeDifference = timeDifference
        self.timestamp = Date()
    }
    
    var isWellSynchronized: Bool {
        return timeDifference <= 0.016 // 16ms for 60fps
    }
    
    var synchronizationQuality: SynchronizationQuality {
        switch timeDifference {
        case 0..<0.005:
            return .excellent
        case 0.005..<0.010:
            return .good
        case 0.010..<0.016:
            return .fair
        default:
            return .poor
        }
    }
}

struct FrameSyncStatistics: Sendable {
    var totalFrames: Int = 0
    var frontFrames: Int = 0
    var backFrames: Int = 0
    var synchronizedPairs: Int = 0
    var averageTimeDifference: TimeInterval = 0
    var synchronizationRate: Double = 0
    var syncInterval: TimeInterval = 0
    var lastSyncTime: Date = Date()
    
    var formattedSynchronizationRate: String {
        return String(format: "%.1f%%", synchronizationRate * 100)
    }
    
    var formattedAverageTimeDifference: String {
        return String(format: "%.2fms", averageTimeDifference * 1000)
    }
    
    var isPerformingWell: Bool {
        return synchronizationRate > 0.9 && averageTimeDifference < 0.010
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