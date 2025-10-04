import Foundation
import UIKit

protocol MainActorMessage: Sendable {
    associatedtype Payload: Sendable = Void
    var payload: Payload { get }
}

extension MainActorMessage where Payload == Void {
    var payload: Void { () }
}

struct MemoryPressureWarning: MainActorMessage {
    enum Level: Sendable {
        case warning
        case critical
    }
    
    let level: Level
    let currentUsage: Double
    let timestamp: Date
    
    var payload: (Level, Double, Date) {
        (level, currentUsage, timestamp)
    }
}

struct MemoryPressureCritical: MainActorMessage {
    let currentUsage: Double
    let availableMemory: Double
    let timestamp: Date
    
    var payload: (Double, Double, Date) {
        (currentUsage, availableMemory, timestamp)
    }
}

struct ReduceProcessingQuality: MainActorMessage {
    let suggestedQuality: Float
    let reason: String
    
    var payload: (Float, String) {
        (suggestedQuality, reason)
    }
}

struct StopNonEssentialProcesses: MainActorMessage {
    let severity: Int
    
    var payload: Int { severity }
}

struct ReduceQualityForMemoryPressure: MainActorMessage {
    let targetQuality: Float
    
    var payload: Float { targetQuality }
}

struct ShowMemoryWarningUI: MainActorMessage {
    let message: String
    let actionRequired: Bool
    
    var payload: (String, Bool) {
        (message, actionRequired)
    }
}

struct CachesCleared: MainActorMessage {
    let bytesFreed: Int64
    
    var payload: Int64 { bytesFreed }
}

struct PredictedMemoryPressure: MainActorMessage {
    let predictedUsage: Double
    let confidence: Double
    let timeToThreshold: TimeInterval
    
    var payload: (Double, Double, TimeInterval) {
        (predictedUsage, confidence, timeToThreshold)
    }
}

struct RetryCameraSetup: MainActorMessage {}

struct RestartCameraSetup: MainActorMessage {
    let reason: String
    
    var payload: String { reason }
}

struct RetryRecordingStart: MainActorMessage {}

struct RetryRecordingStop: MainActorMessage {}

struct RestartRecording: MainActorMessage {
    let preserveSettings: Bool
    
    var payload: Bool { preserveSettings }
}

struct ForceStopRecording: MainActorMessage {
    let reason: String
    
    var payload: String { reason }
}

struct ErrorRecovered: MainActorMessage {
    let errorType: String
    
    var payload: String { errorType }
}

struct ShowMemoryWarning: MainActorMessage {
    let severity: Int
    
    var payload: Int { severity }
}

struct EmergencyMemoryPressure: MainActorMessage {
    let criticalThreshold: Double
    
    var payload: Double { criticalThreshold }
}

struct MemoryPressureRecovered: MainActorMessage {
    let newUsage: Double
    
    var payload: Double { newUsage }
}

struct FocusModeStatusDidChange: MainActorMessage {
    let isEnabled: Bool
    let mode: String
    
    var payload: (Bool, String) {
        (isEnabled, mode)
    }
}

struct FocusModeShouldHideControls: MainActorMessage {}

struct FocusModeShouldShowControls: MainActorMessage {}

struct FocusModeShouldReduceVisualEffects: MainActorMessage {}

struct FocusModeShouldRestoreVisualEffects: MainActorMessage {}

struct FocusModeShouldEnableMinimalMode: MainActorMessage {}

struct FocusModeShouldDisableMinimalMode: MainActorMessage {}

struct FocusModeCustomBehavior: MainActorMessage {
    let behavior: String
    
    var payload: String { behavior }
}

struct AccessibilityGlassSettingsChanged: MainActorMessage {
    let blurRadius: CGFloat
    let transparency: CGFloat
    
    var payload: (CGFloat, CGFloat) {
        (blurRadius, transparency)
    }
}

struct MetalRenderingSettingsChanged: MainActorMessage {
    let enabled: Bool
    
    var payload: Bool { enabled }
}

struct MotorAccessibilityShouldApplySwitchControlConfiguration: MainActorMessage {}

struct MotorAccessibilityShouldApplyAssistiveTouchConfiguration: MainActorMessage {}

struct MotorAccessibilityShouldApplyReducedMotionConfiguration: MainActorMessage {}

struct MotorAccessibilityShouldApplyTouchAccommodations: MainActorMessage {}

struct MotorAccessibilityShouldApplyAlternateControlMethods: MainActorMessage {}

struct MotorAccessibilityShouldSetupVoiceControlCommands: MainActorMessage {}

struct MotorAccessibilityShouldSetupSwitchControlScanning: MainActorMessage {}

struct MotorAccessibilityShouldSetupAssistiveTouchCustomActions: MainActorMessage {}

struct BatteryStateChanged: MainActorMessage {
    let level: Float
    let state: UIDevice.BatteryState
    let isLowPowerMode: Bool
    
    var payload: (Float, UIDevice.BatteryState, Bool) {
        (level, state, isLowPowerMode)
    }
}

struct ThermalStateChanged: MainActorMessage {
    enum ThermalState: Sendable {
        case nominal
        case fair
        case serious
        case critical
    }
    
    let state: ThermalState
    let temperature: Double?
    
    var payload: (ThermalState, Double?) {
        (state, temperature)
    }
}

struct RecordingStateChanged: MainActorMessage {
    let isRecording: Bool
    let duration: TimeInterval
    
    var payload: (Bool, TimeInterval) {
        (isRecording, duration)
    }
}

@available(iOS 26.0, *)
extension NotificationCenter {
    func post<Message: MainActorMessage>(_ message: Message) {
        let notificationName = Notification.Name(String(describing: Message.self))
        let notification = Notification(name: notificationName, object: message, userInfo: nil)
        self.post(notification)
    }
    
    func notifications<Message: MainActorMessage>(
        of type: Message.Type
    ) -> AsyncStream<Message> {
        let notificationName = Notification.Name(String(describing: type))
        
        return AsyncStream { continuation in
            let observer = self.addObserver(
                forName: notificationName,
                object: nil,
                queue: .main
            ) { notification in
                if let message = notification.object as? Message {
                    continuation.yield(message)
                }
            }
            
            continuation.onTermination = { @Sendable _ in
                NotificationCenter.default.removeObserver(observer)
            }
        }
    }
}

extension NotificationCenter {
    func postLegacy<Message: MainActorMessage>(_ message: Message) {
        let notificationName = Notification.Name(String(describing: Message.self))
        let notification = Notification(name: notificationName, object: message, userInfo: nil)
        self.post(notification)
    }
}
