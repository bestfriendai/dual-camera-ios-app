import AppIntents
import AVFoundation
import UIKit

@available(iOS 26.0, *)
struct VideoQualityEnum: AppEnum {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Video Quality"
    static var caseDisplayRepresentations: [VideoQualityEnum : DisplayRepresentation] = [
        .hd720: "720p HD",
        .hd1080: "1080p Full HD",
        .uhd4k: "4K Ultra HD"
    ]
    
    case hd720
    case hd1080
    case uhd4k
    
    func toVideoQuality() -> VideoQuality {
        switch self {
        case .hd720:
            return .hd720
        case .hd1080:
            return .hd1080
        case .uhd4k:
            return .uhd4k
        }
    }
}

@available(iOS 26.0, *)
struct StartRecordingIntent: AppIntent {
    static var title: LocalizedStringResource = "Start Recording"
    static var description = IntentDescription("Start dual camera recording with specified quality")
    
    @Parameter(title: "Camera Quality", default: .hd1080)
    var quality: VideoQualityEnum
    
    @Parameter(title: "Enable Flash", default: false)
    var enableFlash: Bool
    
    @MainActor
    func perform() async throws -> some IntentResult {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            throw IntentError.message("Unable to access camera controller")
        }
        
        if let viewController = rootViewController as? ViewController {
            viewController.cameraManager.videoQuality = quality.toVideoQuality()
            
            if enableFlash {
                viewController.cameraManager.toggleFlash()
            }
            
            try await viewController.cameraManager.startRecording()
            
            return .result(dialog: "Recording started in \(quality.toVideoQuality().displayName)")
        }
        
        throw IntentError.message("Camera not available")
    }
}

@available(iOS 26.0, *)
struct StopRecordingIntent: AppIntent {
    static var title: LocalizedStringResource = "Stop Recording"
    static var description = IntentDescription("Stop dual camera recording and save video")
    
    @MainActor
    func perform() async throws -> some IntentResult {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            throw IntentError.message("Unable to access camera controller")
        }
        
        if let viewController = rootViewController as? ViewController {
            await viewController.cameraManager.stopRecording()
            
            return .result(dialog: "Recording stopped and saved")
        }
        
        throw IntentError.message("Camera not available")
    }
}

@available(iOS 26.0, *)
struct CapturePhotoIntent: AppIntent {
    static var title: LocalizedStringResource = "Capture Photo"
    static var description = IntentDescription("Capture dual camera photo")
    
    @Parameter(title: "Enable Flash", default: false)
    var enableFlash: Bool
    
    @MainActor
    func perform() async throws -> some IntentResult {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            throw IntentError.message("Unable to access camera controller")
        }
        
        if let viewController = rootViewController as? ViewController {
            if enableFlash {
                viewController.cameraManager.toggleFlash()
            }
            
            await viewController.cameraManager.capturePhoto()
            
            return .result(dialog: "Photo captured")
        }
        
        throw IntentError.message("Camera not available")
    }
}

@available(iOS 26.0, *)
struct SwitchCameraIntent: AppIntent {
    static var title: LocalizedStringResource = "Switch Camera"
    static var description = IntentDescription("Switch between front and back cameras")
    
    @MainActor
    func perform() async throws -> some IntentResult {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            throw IntentError.message("Unable to access camera controller")
        }
        
        if let viewController = rootViewController as? ViewController {
            await viewController.cameraManager.swapCameras()
            
            return .result(dialog: "Camera switched")
        }
        
        throw IntentError.message("Camera not available")
    }
}

@available(iOS 26.0, *)
struct SetVideoQualityIntent: AppIntent {
    static var title: LocalizedStringResource = "Set Video Quality"
    static var description = IntentDescription("Change video recording quality")
    
    @Parameter(title: "Quality", default: .hd1080)
    var quality: VideoQualityEnum
    
    @MainActor
    func perform() async throws -> some IntentResult {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            throw IntentError.message("Unable to access camera controller")
        }
        
        if let viewController = rootViewController as? ViewController {
            viewController.cameraManager.videoQuality = quality.toVideoQuality()
            
            return .result(dialog: "Video quality set to \(quality.toVideoQuality().displayName)")
        }
        
        throw IntentError.message("Camera not available")
    }
}

@available(iOS 26.0, *)
struct ToggleFlashIntent: AppIntent {
    static var title: LocalizedStringResource = "Toggle Flash"
    static var description = IntentDescription("Turn flash on or off")
    
    @MainActor
    func perform() async throws -> some IntentResult {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            throw IntentError.message("Unable to access camera controller")
        }
        
        if let viewController = rootViewController as? ViewController {
            viewController.cameraManager.toggleFlash()
            let isOn = viewController.cameraManager.isFlashEnabled()
            
            return .result(dialog: "Flash turned \(isOn ? "on" : "off")")
        }
        
        throw IntentError.message("Camera not available")
    }
}

@available(iOS 26.0, *)
struct DualCameraAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartRecordingIntent(),
            phrases: [
                "Start recording with \(.applicationName)",
                "Begin dual camera recording",
                "Record video with \(.applicationName)"
            ],
            shortTitle: "Start Recording",
            systemImageName: "video.fill"
        )
        
        AppShortcut(
            intent: StopRecordingIntent(),
            phrases: [
                "Stop recording with \(.applicationName)",
                "End recording",
                "Save video with \(.applicationName)"
            ],
            shortTitle: "Stop Recording",
            systemImageName: "stop.fill"
        )
        
        AppShortcut(
            intent: CapturePhotoIntent(),
            phrases: [
                "Take a photo with \(.applicationName)",
                "Capture photo",
                "Take dual camera photo"
            ],
            shortTitle: "Capture Photo",
            systemImageName: "camera.fill"
        )
        
        AppShortcut(
            intent: SwitchCameraIntent(),
            phrases: [
                "Switch camera",
                "Flip camera with \(.applicationName)"
            ],
            shortTitle: "Switch Camera",
            systemImageName: "camera.rotate"
        )
        
        AppShortcut(
            intent: SetVideoQualityIntent(),
            phrases: [
                "Set video quality",
                "Change quality in \(.applicationName)"
            ],
            shortTitle: "Set Quality",
            systemImageName: "video.badge.waveform"
        )
        
        AppShortcut(
            intent: ToggleFlashIntent(),
            phrases: [
                "Toggle flash",
                "Turn flash on",
                "Turn flash off"
            ],
            shortTitle: "Toggle Flash",
            systemImageName: "bolt.fill"
        )
    }
}

extension VideoQuality {
    var displayName: String {
        switch self {
        case .hd720:
            return "720p HD"
        case .hd1080:
            return "1080p Full HD"
        case .uhd4k:
            return "4K Ultra HD"
        }
    }
}
