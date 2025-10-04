//
//  VideoQuality.swift
//  DualCameraApp
//
//  Extended video quality definitions and metadata helpers.
//

import CoreGraphics
import CoreMedia

enum VideoQuality: String, CaseIterable, Sendable, Codable, CustomStringConvertible {
    case hd720 = "720p"
    case hd1080 = "1080p"
    case uhd4k = "4K"
    case high = "High"
    
    var dimensions: CGSize {
        switch self {
        case .hd720:
            return CGSize(width: 1280, height: 720)
        case .hd1080:
            return CGSize(width: 1920, height: 1080)
        case .uhd4k:
            return CGSize(width: 3840, height: 2160)
        case .high:
            return CGSize(width: 1920, height: 1080) // Same as 1080p
        }
    }

    var cmDimensions: CMVideoDimensions {
        switch self {
        case .hd720:
            return CMVideoDimensions(width: 1280, height: 720)
        case .hd1080:
            return CMVideoDimensions(width: 1920, height: 1080)
        case .uhd4k:
            return CMVideoDimensions(width: 3840, height: 2160)
        case .high:
            return CMVideoDimensions(width: 1920, height: 1080) // Same as 1080p
        }
    }

    var renderSize: CGSize {
        return dimensions
    }
}

extension VideoQuality {
    /// Frame rate best suited for the specified quality.
    var frameRate: Double {
        switch self {
        case .hd720:
            return 30.0
        case .hd1080:
            return 30.0
        case .uhd4k:
            return 24.0
        case .high:
            return 30.0 // Same as 1080p
        }
    }
}
