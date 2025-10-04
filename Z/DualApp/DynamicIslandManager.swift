//
//  DynamicIslandManager.swift
//  DualApp
//
//  Created by DualApp Team on 10/3/25.
//

import Foundation
import SwiftUI
import ActivityKit

// MARK: - Dynamic Island Manager

@MainActor
actor DynamicIslandManager: Sendable {
    
    // MARK: - Properties
    
    private var currentActivity: Activity<RecordingAttributes>?
    private var isMonitoring: Bool = false
    private var monitoringTask: Task<Void, Never>?
    
    // MARK: - iOS 26+ Dynamic Island Features
    
    private var enhancedDynamicIslandEnabled: Bool = false
    private var interactiveControlsEnabled: Bool = true
    private var liveActivityIntegrationEnabled: Bool = true
    private var adaptiveLayoutEnabled: Bool = true
    
    // MARK: - Event Stream
    
    let events: AsyncStream<DynamicIslandEvent>
    private let eventContinuation: AsyncStream<DynamicIslandEvent>.Continuation
    
    // MARK: - Initialization
    
    init() {
        (self.events, self.eventContinuation) = AsyncStream<DynamicIslandEvent>.makeStream()
        
        // Enable iOS 26+ features if available
        if #available(iOS 26.0, *) {
            setupIOS26DynamicIslandFeatures()
        }
    }
    
    // MARK: - Public Interface
    
    func startMonitoring() async {
        guard !isMonitoring else { return }
        
        isMonitoring = true
        
        // Start monitoring task
        monitoringTask = Task {
            await monitoringLoop()
        }
        
        eventContinuation.yield(.monitoringStarted)
    }
    
    func stopMonitoring() async {
        isMonitoring = false
        monitoringTask?.cancel()
        monitoringTask = nil
        
        // End current activity
        await endCurrentActivity()
        
        eventContinuation.yield(.monitoringStopped)
    }
    
    func startRecordingActivity(configuration: RecordingConfiguration) async throws {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            throw DynamicIslandError.activitiesNotEnabled
        }
        
        // End current activity if exists
        await endCurrentActivity()
        
        // Create attributes for recording
        let attributes = RecordingAttributes(
            configuration: configuration,
            startTime: Date()
        )
        
        // Create content state
        let contentState = RecordingAttributes.ContentState(
            isRecording: true,
            duration: 0,
            quality: configuration.quality,
            frameRate: configuration.frameRate,
            cameraMode: configuration.cameraMode,
            batteryLevel: await getCurrentBatteryLevel(),
            storageSpace: await getCurrentStorageSpace()
        )
        
        // Start activity
        do {
            let activity = try Activity<RecordingAttributes>.request(
                attributes: attributes,
                contentState: contentState,
                pushType: nil
            )
            
            currentActivity = activity
            
            // Start content state updates
            await startContentStateUpdates()
            
            eventContinuation.yield(.recordingActivityStarted(activity))
            
        } catch {
            throw DynamicIslandError.activityCreationFailed(error.localizedDescription)
        }
    }
    
    func stopRecordingActivity(finalDuration: TimeInterval, outputURL: URL) async {
        guard let activity = currentActivity else { return }
        
        // Update final state
        let finalState = RecordingAttributes.ContentState(
            isRecording: false,
            duration: finalDuration,
            quality: activity.attributes.configuration.quality,
            frameRate: activity.attributes.configuration.frameRate,
            cameraMode: activity.attributes.configuration.cameraMode,
            batteryLevel: await getCurrentBatteryLevel(),
            storageSpace: await getCurrentStorageSpace(),
            outputURL: outputURL
        )
        
        // Update activity
        do {
            try await activity.update(using: finalState)
            
            // End activity after a delay to show final state
            try await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
            
            await activity.end(dismissalPolicy: .immediate)
            currentActivity = nil
            
            eventContinuation.yield(.recordingActivityStopped(activity))
            
        } catch {
            eventContinuation.yield(.error(DynamicIslandError.activityUpdateFailed(error.localizedDescription)))
        }
    }
    
    func updateRecordingState(duration: TimeInterval, batteryLevel: Double, storageSpace: Double) async {
        guard let activity = currentActivity else { return }
        
        let updatedState = RecordingAttributes.ContentState(
            isRecording: true,
            duration: duration,
            quality: activity.attributes.configuration.quality,
            frameRate: activity.attributes.configuration.frameRate,
            cameraMode: activity.attributes.configuration.cameraMode,
            batteryLevel: batteryLevel,
            storageSpace: storageSpace
        )
        
        do {
            try await activity.update(using: updatedState)
            eventContinuation.yield(.recordingStateUpdated(updatedState))
        } catch {
            eventContinuation.yield(.error(DynamicIslandError.activityUpdateFailed(error.localizedDescription)))
        }
    }
    
    func pauseRecordingActivity() async {
        guard let activity = currentActivity else { return }
        
        let pausedState = RecordingAttributes.ContentState(
            isRecording: false,
            isPaused: true,
            duration: activity.contentState.duration,
            quality: activity.attributes.configuration.quality,
            frameRate: activity.attributes.configuration.frameRate,
            cameraMode: activity.attributes.configuration.cameraMode,
            batteryLevel: await getCurrentBatteryLevel(),
            storageSpace: await getCurrentStorageSpace()
        )
        
        do {
            try await activity.update(using: pausedState)
            eventContinuation.yield(.recordingActivityPaused(activity))
        } catch {
            eventContinuation.yield(.error(DynamicIslandError.activityUpdateFailed(error.localizedDescription)))
        }
    }
    
    func resumeRecordingActivity() async {
        guard let activity = currentActivity else { return }
        
        let resumedState = RecordingAttributes.ContentState(
            isRecording: true,
            isPaused: false,
            duration: activity.contentState.duration,
            quality: activity.attributes.configuration.quality,
            frameRate: activity.attributes.configuration.frameRate,
            cameraMode: activity.attributes.configuration.cameraMode,
            batteryLevel: await getCurrentBatteryLevel(),
            storageSpace: await getCurrentStorageSpace()
        )
        
        do {
            try await activity.update(using: resumedState)
            eventContinuation.yield(.recordingActivityResumed(activity))
        } catch {
            eventContinuation.yield(.error(DynamicIslandError.activityUpdateFailed(error.localizedDescription)))
        }
    }
    
    // MARK: - iOS 26+ Dynamic Island Features
    
    @available(iOS 26.0, *)
    private func setupIOS26DynamicIslandFeatures() {
        // Enable enhanced Dynamic Island features
        enhancedDynamicIslandEnabled = true
        
        // Enable interactive controls
        interactiveControlsEnabled = true
        
        // Enable Live Activity integration
        liveActivityIntegrationEnabled = true
        
        // Enable adaptive layout
        adaptiveLayoutEnabled = true
    }
    
    @available(iOS 26.0, *)
    func enableEnhancedDynamicIsland() async {
        enhancedDynamicIslandEnabled = true
        eventContinuation.yield(.enhancedDynamicIslandEnabled)
    }
    
    @available(iOS 26.0, *)
    func disableEnhancedDynamicIsland() async {
        enhancedDynamicIslandEnabled = false
        eventContinuation.yield(.enhancedDynamicIslandDisabled)
    }
    
    @available(iOS 26.0, *)
    func enableInteractiveControls() async {
        interactiveControlsEnabled = true
        eventContinuation.yield(.interactiveControlsEnabled)
    }
    
    @available(iOS 26.0, *)
    func disableInteractiveControls() async {
        interactiveControlsEnabled = false
        eventContinuation.yield(.interactiveControlsDisabled)
    }
    
    @available(iOS 26.0, *)
    func updateDynamicIslandLayout(_ layout: DynamicIslandLayout) async {
        guard enhancedDynamicIslandEnabled else { return }
        
        // Update Dynamic Island layout based on iOS 26+ capabilities
        eventContinuation.yield(.layoutUpdated(layout))
    }
    
    @available(iOS 26.0, *)
    func addInteractiveControl(_ control: DynamicIslandControl) async {
        guard interactiveControlsEnabled else { return }
        
        // Add interactive control to Dynamic Island
        eventContinuation.yield(.interactiveControlAdded(control))
    }
    
    @available(iOS 26.0, *)
    func removeInteractiveControl(_ control: DynamicIslandControl) async {
        guard interactiveControlsEnabled else { return }
        
        // Remove interactive control from Dynamic Island
        eventContinuation.yield(.interactiveControlRemoved(control))
    }
    
    // MARK: - Private Methods
    
    private func monitoringLoop() async {
        while isMonitoring && !Task.isCancelled {
            await updateActivityState()
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        }
    }
    
    private func updateActivityState() async {
        guard let activity = currentActivity else { return }
        
        // Update battery level and storage space
        let currentBatteryLevel = await getCurrentBatteryLevel()
        let currentStorageSpace = await getCurrentStorageSpace()
        
        let updatedState = RecordingAttributes.ContentState(
            isRecording: activity.contentState.isRecording,
            isPaused: activity.contentState.isPaused,
            duration: activity.contentState.duration,
            quality: activity.attributes.configuration.quality,
            frameRate: activity.attributes.configuration.frameRate,
            cameraMode: activity.attributes.configuration.cameraMode,
            batteryLevel: currentBatteryLevel,
            storageSpace: currentStorageSpace
        )
        
        do {
            try await activity.update(using: updatedState)
        } catch {
            eventContinuation.yield(.error(DynamicIslandError.activityUpdateFailed(error.localizedDescription)))
        }
    }
    
    private func startContentStateUpdates() async {
        // Start periodic updates for the activity
        Task {
            while currentActivity != nil && !Task.isCancelled {
                await updateActivityState()
                try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            }
        }
    }
    
    private func endCurrentActivity() async {
        guard let activity = currentActivity else { return }
        
        do {
            await activity.end(dismissalPolicy: .immediate)
            currentActivity = nil
            eventContinuation.yield(.activityEnded(activity))
        } catch {
            eventContinuation.yield(.error(DynamicIslandError.activityEndFailed(error.localizedDescription)))
        }
    }
    
    private func getCurrentBatteryLevel() async -> Double {
        // Get current battery level from BatteryManager
        return 0.8 // Placeholder
    }
    
    private func getCurrentStorageSpace() async -> Double {
        // Get current storage space
        return 0.6 // Placeholder
    }
    
    deinit {
        stopMonitoring()
    }
}

// MARK: - Recording Attributes

struct RecordingAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var isRecording: Bool
        var isPaused: Bool = false
        var duration: TimeInterval
        var quality: VideoQuality
        var frameRate: Int32
        var cameraMode: CameraMode
        var batteryLevel: Double
        var storageSpace: Double
        var outputURL: URL?
    }
    
    var configuration: RecordingConfiguration
    var startTime: Date
}

// MARK: - Recording Configuration

struct RecordingConfiguration: Codable, Hashable {
    var quality: VideoQuality
    var frameRate: Int32
    var cameraMode: CameraMode
    var multiCamEnabled: Bool
    var hdrEnabled: Bool
}

// MARK: - Dynamic Island Event

enum DynamicIslandEvent: Sendable {
    case monitoringStarted
    case monitoringStopped
    case recordingActivityStarted(Activity<RecordingAttributes>)
    case recordingActivityStopped(Activity<RecordingAttributes>)
    case recordingActivityPaused(Activity<RecordingAttributes>)
    case recordingActivityResumed(Activity<RecordingAttributes>)
    case recordingStateUpdated(RecordingAttributes.ContentState)
    case activityEnded(Activity<RecordingAttributes>)
    case enhancedDynamicIslandEnabled
    case enhancedDynamicIslandDisabled
    case interactiveControlsEnabled
    case interactiveControlsDisabled
    case layoutUpdated(DynamicIslandLayout)
    case interactiveControlAdded(DynamicIslandControl)
    case interactiveControlRemoved(DynamicIslandControl)
    case error(DynamicIslandError)
}

// MARK: - Dynamic Island Error

enum DynamicIslandError: LocalizedError, Sendable {
    case activitiesNotEnabled
    case activityCreationFailed(String)
    case activityUpdateFailed(String)
    case activityEndFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .activitiesNotEnabled:
            return "Live Activities are not enabled"
        case .activityCreationFailed(let reason):
            return "Failed to create activity: \(reason)"
        case .activityUpdateFailed(let reason):
            return "Failed to update activity: \(reason)"
        case .activityEndFailed(let reason):
            return "Failed to end activity: \(reason)"
        }
    }
}

// MARK: - iOS 26+ Dynamic Island Layout

@available(iOS 26.0, *)
enum DynamicIslandLayout: String, CaseIterable, Sendable {
    case compact = "Compact"
    case expanded = "Expanded"
    case minimal = "Minimal"
    case interactive = "Interactive"
    
    var description: String {
        switch self {
        case .compact:
            return "Compact layout with essential information"
        case .expanded:
            return "Expanded layout with detailed information"
        case .minimal:
            return "Minimal layout with basic indicators"
        case .interactive:
            return "Interactive layout with controls"
        }
    }
}

// MARK: - iOS 26+ Dynamic Island Control

@available(iOS 26.0, *)
struct DynamicIslandControl: Identifiable, Sendable {
    let id = UUID()
    let type: DynamicIslandControlType
    let title: String
    let icon: String
    let action: () async -> Void
}

// MARK: - Dynamic Island Control Type

@available(iOS 26.0, *)
enum DynamicIslandControlType: String, CaseIterable, Sendable {
    case pauseResume = "PauseResume"
    case stop = "Stop"
    case switchCamera = "SwitchCamera"
    case toggleHDR = "ToggleHDR"
    case toggleMultiCam = "ToggleMultiCam"
    
    var systemImage: String {
        switch self {
        case .pauseResume:
            return "pause.circle.fill"
        case .stop:
            return "stop.circle.fill"
        case .switchCamera:
            return "camera.rotate"
        case .toggleHDR:
            return "sun.max.fill"
        case .toggleMultiCam:
            return "camera.on.rectangle"
        }
    }
}

// MARK: - Supporting Types

enum CameraMode: String, CaseIterable, Codable, Sendable {
    case video = "Video"
    case photo = "Photo"
    case cinematic = "Cinematic"
    case portrait = "Portrait"
    
    var systemImage: String {
        switch self {
        case .video:
            return "video.circle.fill"
        case .photo:
            return "camera.circle.fill"
        case .cinematic:
            return "camera.aperture"
        case .portrait:
            return "person.crop.circle.fill"
        }
    }
}