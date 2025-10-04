//
//  VideoQuality.swift
//  DualCameraApp
//
//  Extended video quality definitions and metadata helpers.
//

import CoreGraphics

enum VideoQuality: String, CaseIterable, Sendable, Codable {
    case hd720 = "720p"
    case hd1080 = "1080p"
    case uhd4k = "4K"
    
    var dimensions: CGSize {
        switch self {
        case .hd720:
            return CGSize(width: 1280, height: 720)
        case .hd1080:
            return CGSize(width: 1920, height: 1080)
        case .uhd4k:
            return CGSize(width: 3840, height: 2160)
        }
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
        }
    }
}
