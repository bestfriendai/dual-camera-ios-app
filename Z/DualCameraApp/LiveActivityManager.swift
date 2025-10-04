//
//  LiveActivityManager.swift
//  DualCameraApp
//
//  Live Activities system for recording status with modern iOS 16.1+ lock screen integration
//

import UIKit
import ActivityKit
import Intents

@available(iOS 16.2, *)
class LiveActivityManager {
    
    static let shared = LiveActivityManager()
    
    private init() {}
    
    // MARK: - Properties
    
    private var recordingActivity: Activity<RecordingActivityAttributes>?
    private var processingActivity: Activity<ProcessingActivityAttributes>?
    private var activityAuthorizationInfo: ActivityAuthorizationInfo?
    
    // MARK: - Activity Attributes
    
    struct RecordingActivityAttributes: ActivityAttributes {
        public struct ContentState: Codable, Hashable {
            var recordingState: RecordingState
            var duration: TimeInterval
            var frontCameraActive: Bool
            var backCameraActive: Bool
            var audioLevel: Float
            var fileSize: Int64
            var remainingStorage: Int64
            var batteryLevel: Float
            var thermalState: String
        }
        
        enum RecordingState: String, Codable {
            case idle
            case recording
            case paused
            case processing
            case completed
            case error
        }
    }
    
    struct ProcessingActivityAttributes: ActivityAttributes {
        public struct ContentState: Codable, Hashable {
            var processingStage: ProcessingStage
            var progress: Float
            var frontCameraPath: String?
            var backCameraPath: String?
            var combinedPath: String?
            var estimatedTimeRemaining: TimeInterval
        }
        
        enum ProcessingStage: String, Codable {
            case initializing
            case processingFront
            case processingBack
            case combining
            case finalizing
            case completed
            case error
        }
    }
    
    // MARK: - Activity Management
    
    /// Requests authorization for Live Activities
    func requestActivityAuthorization() async -> Bool {
        do {
            activityAuthorizationInfo = try await ActivityAuthorizationInfo()
            return activityAuthorizationInfo?.areActivitiesEnabled ?? false
        } catch {
            print("Error requesting activity authorization: \(error)")
            return false
        }
    }
    
    /// Starts a recording Live Activity
    func startRecordingLiveActivity(
        frontCameraActive: Bool = true,
        backCameraActive: Bool = true
    ) async -> Bool {
        // End any existing activity
        await endRecordingLiveActivity()
        
        // Check if activities are enabled
        guard await requestActivityAuthorization() else {
            return false
        }
        
        // Create initial content state
        let contentState = RecordingActivityAttributes.ContentState(
            recordingState: .recording,
            duration: 0,
            frontCameraActive: frontCameraActive,
            backCameraActive: backCameraActive,
            audioLevel: 0,
            fileSize: 0,
            remainingStorage: getAvailableStorage(),
            batteryLevel: UIDevice.current.batteryLevel,
            thermalState: getThermalState()
        )
        
        // Create attributes
        let attributes = RecordingActivityAttributes()
        
        do {
            // Create activity
            let activity = try Activity<RecordingActivityAttributes>.request(
                attributes: attributes,
                content: .init(state: contentState, staleDate: nil),
                pushType: nil
            )
            
            recordingActivity = activity
            
            // Start timers to update various states
            startUpdateTimers()
            
            return true
        } catch {
            print("Error starting recording live activity: \(error)")
            return false
        }
    }
    
    /// Starts a processing Live Activity
    func startProcessingLiveActivity(
        frontCameraPath: String? = nil,
        backCameraPath: String? = nil
    ) async -> Bool {
        // End any existing activity
        await endProcessingLiveActivity()
        
        // Check if activities are enabled
        guard await requestActivityAuthorization() else {
            return false
        }
        
        // Create initial content state
        let contentState = ProcessingActivityAttributes.ContentState(
            processingStage: .initializing,
            progress: 0,
            frontCameraPath: frontCameraPath,
            backCameraPath: backCameraPath,
            combinedPath: nil,
            estimatedTimeRemaining: 30
        )
        
        // Create attributes
        let attributes = ProcessingActivityAttributes()
        
        do {
            // Create activity
            let activity = try Activity<ProcessingActivityAttributes>.request(
                attributes: attributes,
                content: .init(state: contentState, staleDate: nil),
                pushType: nil
            )
            
            processingActivity = activity
            
            return true
        } catch {
            print("Error starting processing live activity: \(error)")
            return false
        }
    }
    
    /// Updates the recording state
    func updateRecordingState(_ state: RecordingActivityAttributes.RecordingState) async {
        await updateRecordingActivity { contentState in
            contentState.recordingState = state
        }
    }
    
    /// Updates the recording duration
    func updateRecordingDuration(_ duration: TimeInterval) async {
        await updateRecordingActivity { contentState in
            contentState.duration = duration
        }
    }
    
    /// Updates the camera states
    func updateCameraStates(frontCameraActive: Bool, backCameraActive: Bool) async {
        await updateRecordingActivity { contentState in
            contentState.frontCameraActive = frontCameraActive
            contentState.backCameraActive = backCameraActive
        }
    }
    
    /// Updates the audio level
    func updateAudioLevel(_ level: Float) async {
        await updateRecordingActivity { contentState in
            contentState.audioLevel = level
        }
    }
    
    /// Updates the file size
    func updateFileSize(_ size: Int64) async {
        await updateRecordingActivity { contentState in
            contentState.fileSize = size
        }
    }
    
    /// Updates the remaining storage
    func updateRemainingStorage(_ storage: Int64) async {
        await updateRecordingActivity { contentState in
            contentState.remainingStorage = storage
        }
    }
    
    /// Updates the battery level
    func updateBatteryLevel(_ level: Float) async {
        await updateRecordingActivity { contentState in
            contentState.batteryLevel = level
        }
    }
    
    /// Updates the thermal state
    func updateThermalState() async {
        await updateRecordingActivity { contentState in
            contentState.thermalState = getThermalState()
        }
    }
    
    /// Updates the processing stage
    func updateProcessingStage(_ stage: ProcessingActivityAttributes.ProcessingStage) async {
        await updateProcessingActivity { contentState in
            contentState.processingStage = stage
        }
    }
    
    /// Updates the processing progress
    func updateProcessingProgress(_ progress: Float) async {
        await updateProcessingActivity { contentState in
            contentState.progress = progress
        }
    }
    
    /// Updates the estimated time remaining
    func updateEstimatedTimeRemaining(_ time: TimeInterval) async {
        await updateProcessingActivity { contentState in
            contentState.estimatedTimeRemaining = time
        }
    }
    
    /// Updates the combined video path
    func updateCombinedPath(_ path: String) async {
        await updateProcessingActivity { contentState in
            contentState.combinedPath = path
        }
    }
    
    /// Ends the recording Live Activity
    func endRecordingLiveActivity() async {
        guard let activity = recordingActivity else { return }
        
        // Update state to processing
        await updateRecordingState(.processing)
        
        // Wait a moment for the state to update
        try? await Task.sleep(nanoseconds: 500_000_000)
        
        // End the activity
        await activity.end(dismissalPolicy: .immediate)
        recordingActivity = nil
        
        // Stop update timers
        stopUpdateTimers()
    }
    
    /// Ends the processing Live Activity
    func endProcessingLiveActivity() async {
        guard let activity = processingActivity else { return }
        
        // Update state to completed
        await updateProcessingStage(.completed)
        
        // Wait a moment for the state to update
        try? await Task.sleep(nanoseconds: 500_000_000)
        
        // End the activity
        await activity.end(dismissalPolicy: .immediate)
        processingActivity = nil
    }
    
    // MARK: - Private Methods
    
    private var updateTimers: [Timer] = []
    
    private func startUpdateTimers() {
        stopUpdateTimers()
        
        // Start duration update timer
        let durationTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task {
                await self?.incrementDuration()
            }
        }
        updateTimers.append(durationTimer)
        
        // Start battery level update timer
        let batteryTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            Task {
                await self?.updateBatteryLevel(UIDevice.current.batteryLevel)
            }
        }
        updateTimers.append(batteryTimer)
        
        // Start thermal state update timer
        let thermalTimer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { [weak self] _ in
            Task {
                await self?.updateThermalState()
            }
        }
        updateTimers.append(thermalTimer)
        
        // Start remaining storage update timer
        let storageTimer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { [weak self] _ in
            Task {
                await self?.updateRemainingStorage(self?.getAvailableStorage() ?? 0)
            }
        }
        updateTimers.append(storageTimer)
    }
    
    private func stopUpdateTimers() {
        updateTimers.forEach { $0.invalidate() }
        updateTimers.removeAll()
    }
    
    private func incrementDuration() async {
        guard let activity = recordingActivity else { return }
        
        let currentDuration = activity.contentState.duration
        await updateRecordingDuration(currentDuration + 1)
    }
    
    private func updateRecordingActivity(_ update: (inout RecordingActivityAttributes.ContentState) -> Void) async {
        guard let activity = recordingActivity else { return }
        
        var contentState = activity.contentState
        update(&contentState)
        
        do {
            let updatedContent = ActivityContent<RecordingActivityAttributes.ContentState>(
                state: contentState,
                staleDate: nil
            )
            try await activity.update(updatedContent)
        } catch {
            print("Error updating recording live activity: \(error)")
        }
    }
    
    private func updateProcessingActivity(_ update: (inout ProcessingActivityAttributes.ContentState) -> Void) async {
        guard let activity = processingActivity else { return }
        
        var contentState = activity.contentState
        update(&contentState)
        
        do {
            let updatedContent = ActivityContent<ProcessingActivityAttributes.ContentState>(
                state: contentState,
                staleDate: nil
            )
            try await activity.update(updatedContent)
        } catch {
            print("Error updating processing live activity: \(error)")
        }
    }
    
    private func getAvailableStorage() -> Int64 {
        let fileURL = URL(fileURLWithPath: NSHomeDirectory())
        do {
            let values = try fileURL.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
            return values.volumeAvailableCapacityForImportantUsage ?? 0
        } catch {
            print("Error getting available storage: \(error)")
            return 0
        }
    }
    
    private func getThermalState() -> String {
        switch ProcessInfo.processInfo.thermalState {
        case .nominal:
            return "Normal"
        case .fair:
            return "Fair"
        case .serious:
            return "Serious"
        case .critical:
            return "Critical"
        @unknown default:
            return "Unknown"
        }
    }
}

@available(iOS 16.2, *)
extension LiveActivityManager {
    
    /// Gets the appropriate title for the recording state
    static func getRecordingTitle(for state: RecordingActivityAttributes.RecordingState) -> String {
        switch state {
        case .idle:
            return "Dual Camera Ready"
        case .recording:
            return "Recording"
        case .paused:
            return "Recording Paused"
        case .processing:
            return "Processing"
        case .completed:
            return "Recording Complete"
        case .error:
            return "Recording Error"
        }
    }
    
    /// Gets the appropriate subtitle for the recording state
    static func getRecordingSubtitle(for state: RecordingActivityAttributes.ContentState) -> String {
        let duration = Int(state.duration)
        let minutes = duration / 60
        let seconds = duration % 60
        let timeString = String(format: "%02d:%02d", minutes, seconds)
        
        var cameras: [String] = []
        
        if state.frontCameraActive {
            cameras.append("Front")
        }
        
        if state.backCameraActive {
            cameras.append("Back")
        }
        
        let cameraString = cameras.isEmpty ? "No Cameras" : cameras.joined(separator: " + ")
        
        return "\(cameraString) • \(timeString)"
    }
    
    /// Gets the appropriate title for the processing stage
    static func getProcessingTitle(for stage: ProcessingActivityAttributes.ProcessingStage) -> String {
        switch stage {
        case .initializing:
            return "Initializing"
        case .processingFront:
            return "Processing Front Camera"
        case .processingBack:
            return "Processing Back Camera"
        case .combining:
            return "Combining Videos"
        case .finalizing:
            return "Finalizing"
        case .completed:
            return "Processing Complete"
        case .error:
            return "Processing Error"
        }
    }
    
    /// Gets the appropriate subtitle for the processing stage
    static func getProcessingSubtitle(for state: ProcessingActivityAttributes.ContentState) -> String {
        let progress = Int(state.progress * 100)
        let timeRemaining = Int(state.estimatedTimeRemaining)
        let minutes = timeRemaining / 60
        let seconds = timeRemaining % 60
        let timeString = String(format: "%02d:%02d", minutes, seconds)
        
        return "\(progress)% • \(timeString) remaining"
    }
    
    /// Gets the appropriate deep link URL for the recording state
    static func getRecordingDeepLink(for state: RecordingActivityAttributes.ContentState) -> URL? {
        switch state.recordingState {
        case .recording:
            return URL(string: "dualcamera://recording")
        case .paused:
            return URL(string: "dualcamera://paused")
        case .processing:
            return URL(string: "dualcamera://processing")
        case .completed:
            return URL(string: "dualcamera://completed")
        case .error:
            return URL(string: "dualcamera://error")
        default:
            return URL(string: "dualcamera://main")
        }
    }
    
    /// Gets the appropriate deep link URL for the processing stage
    static func getProcessingDeepLink(for state: ProcessingActivityAttributes.ContentState) -> URL? {
        switch state.processingStage {
        case .initializing:
            return URL(string: "dualcamera://processing/initializing")
        case .processingFront:
            return URL(string: "dualcamera://processing/front")
        case .processingBack:
            return URL(string: "dualcamera://processing/back")
        case .combining:
            return URL(string: "dualcamera://processing/combining")
        case .finalizing:
            return URL(string: "dualcamera://processing/finalizing")
        case .completed:
            return URL(string: "dualcamera://processing/completed")
        case .error:
            return URL(string: "dualcamera://processing/error")
        }
    }
}