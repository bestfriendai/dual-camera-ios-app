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
}

enum PermissionStatus: Sendable {
    case notDetermined
    case authorized
    case denied
    case restricted
    case limited
}
