import Foundation

enum PermissionType {
    case camera
    case microphone
    case photoLibrary
    
    var title: String {
        switch self {
        case .camera: return "Camera Access"
        case .microphone: return "Microphone Access"
        case .photoLibrary: return "Photo Library Access"
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

enum PermissionStatus {
    case authorized
    case denied
    case notDetermined
    case restricted
}
