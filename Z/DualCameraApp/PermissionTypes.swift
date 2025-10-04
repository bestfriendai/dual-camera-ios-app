import Foundation

enum PermissionType: String, CaseIterable, Sendable {
    case camera = "Camera"
    case microphone = "Microphone"
    case photoLibrary = "Photo Library"
    
    var title: String {
        self.rawValue
    }
    
    var description: String {
        switch self {
        case .camera:
            return "Access to camera for recording videos"
        case .microphone:
            return "Access to microphone for recording audio"
        case .photoLibrary:
            return "Access to photo library for saving videos"
        }
    }

    var message: String {
        switch self {
        case .camera:
            return "This app needs camera access to record videos from both front and back cameras simultaneously."
        case .microphone:
            return "This app needs microphone access to record audio with your videos."
        case .photoLibrary:
            return "This app needs photo library access to save your merged videos."
        }
    }
}

enum PermissionStatus: Sendable {
    case notDetermined
    case authorized
    case denied
    case restricted
    case limited
}

extension PermissionType {
    var alertTitle: String {
        switch self {
        case .camera: return "Camera Access"
        case .microphone: return "Microphone Access"
        case .photoLibrary: return "Photo Library Access"
        }
    }
}
