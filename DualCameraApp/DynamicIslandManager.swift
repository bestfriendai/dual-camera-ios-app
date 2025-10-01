//
//  DynamicIslandManager.swift
//  DualCameraApp
//
//  Dynamic Island support for recording status with modern iOS 16+ interactions
//

import UIKit
import ActivityKit

@available(iOS 16.2, *)
class DynamicIslandManager {
    
    static let shared = DynamicIslandManager()
    
    private init() {}
    
    private var recordingActivity: Activity<RecordingAttributes>?
    private var liveActivity: Activity<LiveRecordingAttributes>?
    private var activityAuthorizationInfo: ActivityAuthorizationInfo?
    
    // MARK: - Activity Attributes
    
    struct RecordingAttributes: ActivityAttributes {
        public struct ContentState: Codable, Hashable {
            var recordingState: RecordingState
            var duration: TimeInterval
            var frontCameraActive: Bool
            var backCameraActive: Bool
            var audioLevel: Float
        }
        
        enum RecordingState: String, Codable {
            case idle
            case recording
            case paused
            case processing
        }
    }
    
    struct LiveRecordingAttributes: ActivityAttributes {
        public struct ContentState: Codable, Hashable {
            var recordingState: RecordingAttributes.RecordingState
            var duration: TimeInterval
            var frontCameraActive: Bool
            var backCameraActive: Bool
            var audioLevel: Float
            var fileSize: Int64
            var remainingStorage: Int64
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
    
    /// Starts a recording activity in the Dynamic Island
    func startRecordingActivity(
        frontCameraActive: Bool = true,
        backCameraActive: Bool = true
    ) async -> Bool {
        // End any existing activity
        await endRecordingActivity()
        
        // Check if activities are enabled
        guard await requestActivityAuthorization() else {
            return false
        }
        
        // Create initial content state
        let contentState = RecordingAttributes.ContentState(
            recordingState: .recording,
            duration: 0,
            frontCameraActive: frontCameraActive,
            backCameraActive: backCameraActive,
            audioLevel: 0
        )
        
        // Create attributes
        let attributes = RecordingAttributes()
        
        do {
            // Create activity
            let activity = try Activity<RecordingAttributes>.request(
                attributes: attributes,
                contentState: contentState,
                pushType: nil
            )
            
            recordingActivity = activity
            
            // Start timer to update duration
            startDurationUpdateTimer()
            
            return true
        } catch {
            print("Error starting recording activity: \(error)")
            return false
        }
    }
    
    /// Starts a Live Activity for extended recording
    func startLiveActivity(
        frontCameraActive: Bool = true,
        backCameraActive: Bool = true
    ) async -> Bool {
        // End any existing activity
        await endLiveActivity()
        
        // Check if activities are enabled
        guard await requestActivityAuthorization() else {
            return false
        }
        
        // Create initial content state
        let contentState = LiveRecordingAttributes.ContentState(
            recordingState: .recording,
            duration: 0,
            frontCameraActive: frontCameraActive,
            backCameraActive: backCameraActive,
            audioLevel: 0,
            fileSize: 0,
            remainingStorage: getAvailableStorage()
        )
        
        // Create attributes
        let attributes = LiveRecordingAttributes()
        
        do {
            // Create activity
            let activity = try Activity<LiveRecordingAttributes>.request(
                attributes: attributes,
                content: .init(state: contentState, staleDate: nil),
                pushType: nil
            )
            
            liveActivity = activity
            
            // Start timer to update duration
            startDurationUpdateTimer()
            
            return true
        } catch {
            print("Error starting live activity: \(error)")
            return false
        }
    }
    
    /// Updates the recording state
    func updateRecordingState(_ state: RecordingAttributes.RecordingState) async {
        await updateRecordingActivity { contentState in
            contentState.recordingState = state
        }
        
        await updateLiveActivity { contentState in
            contentState.recordingState = state
        }
    }
    
    /// Updates the recording duration
    func updateRecordingDuration(_ duration: TimeInterval) async {
        await updateRecordingActivity { contentState in
            contentState.duration = duration
        }
        
        await updateLiveActivity { contentState in
            contentState.duration = duration
        }
    }
    
    /// Updates the camera states
    func updateCameraStates(frontCameraActive: Bool, backCameraActive: Bool) async {
        await updateRecordingActivity { contentState in
            contentState.frontCameraActive = frontCameraActive
            contentState.backCameraActive = backCameraActive
        }
        
        await updateLiveActivity { contentState in
            contentState.frontCameraActive = frontCameraActive
            contentState.backCameraActive = backCameraActive
        }
    }
    
    /// Updates the audio level
    func updateAudioLevel(_ level: Float) async {
        await updateRecordingActivity { contentState in
            contentState.audioLevel = level
        }
        
        await updateLiveActivity { contentState in
            contentState.audioLevel = level
        }
    }
    
    /// Updates the file size (for Live Activity)
    func updateFileSize(_ size: Int64) async {
        await updateLiveActivity { contentState in
            contentState.fileSize = size
        }
    }
    
    /// Updates the remaining storage (for Live Activity)
    func updateRemainingStorage(_ storage: Int64) async {
        await updateLiveActivity { contentState in
            contentState.remainingStorage = storage
        }
    }
    
    /// Ends the recording activity
    func endRecordingActivity() async {
        guard let activity = recordingActivity else { return }
        
        // Update state to processing
        await updateRecordingState(.processing)
        
        // Wait a moment for the state to update
        try? await Task.sleep(nanoseconds: 500_000_000)
        
        // End the activity
        await activity.end(dismissalPolicy: .immediate)
        recordingActivity = nil
        
        // Stop duration update timer
        stopDurationUpdateTimer()
    }
    
    /// Ends the Live Activity
    func endLiveActivity() async {
        guard let activity = liveActivity else { return }
        
        // Update state to processing
        await updateLiveActivity { contentState in
            contentState.recordingState = .processing
        }
        
        // Wait a moment for the state to update
        try? await Task.sleep(nanoseconds: 500_000_000)
        
        // End the activity
        await activity.end(dismissalPolicy: .immediate)
        liveActivity = nil
        
        // Stop duration update timer
        stopDurationUpdateTimer()
    }
    
    // MARK: - Private Methods
    
    private var durationUpdateTimer: Timer?
    
    private func startDurationUpdateTimer() {
        stopDurationUpdateTimer()
        
        durationUpdateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task {
                await self?.incrementDuration()
            }
        }
    }
    
    private func stopDurationUpdateTimer() {
        durationUpdateTimer?.invalidate()
        durationUpdateTimer = nil
    }
    
    private func incrementDuration() async {
        guard let activity = recordingActivity else { return }
        
        let currentDuration = activity.contentState.duration
        await updateRecordingDuration(currentDuration + 1)
    }
    
    private func updateRecordingActivity(_ update: (inout RecordingAttributes.ContentState) -> Void) async {
        guard let activity = recordingActivity else { return }
        
        var contentState = activity.contentState
        update(&contentState)
        
        do {
            try await activity.update(using: contentState)
        } catch {
            print("Error updating recording activity: \(error)")
        }
    }
    
    private func updateLiveActivity(_ update: (inout LiveRecordingAttributes.ContentState) -> Void) async {
        guard let activity = liveActivity else { return }
        
        var contentState = activity.contentState
        update(&contentState)
        
        do {
            let updatedContent = ActivityContent<LiveRecordingAttributes.ContentState>(
                state: contentState,
                staleDate: nil
            )
            try await activity.update(updatedContent)
        } catch {
            print("Error updating live activity: \(error)")
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
}

@available(iOS 16.2, *)
extension DynamicIslandManager {
    
    /// Creates a compact leading view for the Dynamic Island
    static func createCompactLeadingView(for state: RecordingAttributes.ContentState) -> String {
        switch state.recordingState {
        case .idle:
            return "Ready"
        case .recording:
            return "● REC"
        case .paused:
            return "⏸ PAUSED"
        case .processing:
            return "⏳ PROCESSING"
        }
    }
    
    /// Creates a compact trailing view for the Dynamic Island
    static func createCompactTrailingView(for state: RecordingAttributes.ContentState) -> String {
        let duration = Int(state.duration)
        let minutes = duration / 60
        let seconds = duration % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    /// Creates a compact bottom view for the Dynamic Island
    static func createCompactBottomView(for state: RecordingAttributes.ContentState) -> String {
        var cameras: [String] = []
        
        if state.frontCameraActive {
            cameras.append("Front")
        }
        
        if state.backCameraActive {
            cameras.append("Back")
        }
        
        return cameras.joined(separator: " + ")
    }
    
    /// Creates an expanded leading view for the Dynamic Island
    static func createExpandedLeadingView(for state: RecordingAttributes.ContentState) -> String {
        switch state.recordingState {
        case .idle:
            return "Dual Camera Ready"
        case .recording:
            return "Recording"
        case .paused:
            return "Recording Paused"
        case .processing:
            return "Processing"
        }
    }
    
    /// Creates an expanded trailing view for the Dynamic Island
    static func createExpandedTrailingView(for state: RecordingAttributes.ContentState) -> String {
        let duration = Int(state.duration)
        let minutes = duration / 60
        let seconds = duration % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    /// Creates an expanded center view for the Dynamic Island
    static func createExpandedCenterView(for state: RecordingAttributes.ContentState) -> String {
        var cameras: [String] = []
        
        if state.frontCameraActive {
            cameras.append("Front Camera")
        }
        
        if state.backCameraActive {
            cameras.append("Back Camera")
        }
        
        if cameras.isEmpty {
            return "No Cameras Active"
        } else if cameras.count == 1 {
            return cameras.first!
        } else {
            return cameras.joined(separator: " & ")
        }
    }
    
    /// Creates an expanded bottom view for the Dynamic Island
    static func createExpandedBottomView(for state: RecordingAttributes.ContentState) -> String {
        let audioLevel = Int(state.audioLevel * 100)
        return "Audio: \(audioLevel)%"
    }
}

// MARK: - Dynamic Island Status Manager

@available(iOS 16.0, *)
class DynamicIslandStatusManager {
    
    static let shared = DynamicIslandStatusManager()
    
    private init() {}
    
    /// Checks if Dynamic Island is available
    var isDynamicIslandAvailable: Bool {
        if #available(iOS 16.1, *) {
            return UIDevice.current.userInterfaceIdiom == .phone
        } else {
            return false
        }
    }
    
    /// Checks if Live Activities are supported
    var isLiveActivitiesSupported: Bool {
        if #available(iOS 16.1, *) {
            return ActivityAuthorizationInfo().areActivitiesEnabled
        } else {
            return false
        }
    }
    
    /// Determines the appropriate activity type based on recording duration
    func determineActivityType(for estimatedDuration: TimeInterval) -> DynamicIslandActivityType {
        if estimatedDuration > 300 { // 5 minutes
            return .liveActivity
        } else {
            return .recordingActivity
        }
    }
    
    /// Gets the recommended activity type for the current device
    func getRecommendedActivityType() -> DynamicIslandActivityType {
        if isLiveActivitiesSupported {
            return .liveActivity
        } else {
            return .recordingActivity
        }
    }
    
    enum DynamicIslandActivityType {
        case recordingActivity
        case liveActivity
    }
}

// MARK: - Dynamic Island UI Components

@available(iOS 16.0, *)
class DynamicIslandUIComponents {
    
    /// Creates a view for the Dynamic Island expanded state
    static func createExpandedRecordingView(
        state: DynamicIslandManager.RecordingAttributes.ContentState
    ) -> UIView {
        let containerView = UIView()
        containerView.backgroundColor = UIColor.black.withAlphaComponent(0.8)
        containerView.layer.cornerRadius = 20
        containerView.layer.cornerCurve = .continuous
        
        // Create content views
        let leadingLabel = UILabel()
        leadingLabel.text = DynamicIslandManager.createExpandedLeadingView(for: state)
        leadingLabel.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        leadingLabel.textColor = .white
        
        let trailingLabel = UILabel()
        trailingLabel.text = DynamicIslandManager.createExpandedTrailingView(for: state)
        trailingLabel.font = UIFont.systemFont(ofSize: 16, weight: .regular)
        trailingLabel.textColor = .white
        
        let centerLabel = UILabel()
        centerLabel.text = DynamicIslandManager.createExpandedCenterView(for: state)
        centerLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        centerLabel.textColor = .white
        
        let bottomLabel = UILabel()
        bottomLabel.text = DynamicIslandManager.createExpandedBottomView(for: state)
        bottomLabel.font = UIFont.systemFont(ofSize: 12, weight: .regular)
        bottomLabel.textColor = .white
        
        // Add subviews
        containerView.addSubview(leadingLabel)
        containerView.addSubview(trailingLabel)
        containerView.addSubview(centerLabel)
        containerView.addSubview(bottomLabel)
        
        // Setup constraints
        leadingLabel.translatesAutoresizingMaskIntoConstraints = false
        trailingLabel.translatesAutoresizingMaskIntoConstraints = false
        centerLabel.translatesAutoresizingMaskIntoConstraints = false
        bottomLabel.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            leadingLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 12),
            leadingLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            
            trailingLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 12),
            trailingLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            
            centerLabel.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            centerLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            centerLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            
            bottomLabel.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -12),
            bottomLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            bottomLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16)
        ])
        
        return containerView
    }
}