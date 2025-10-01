//
//  VideoQuality.swift
//  DualCameraApp
//
//  Extended video quality definitions and metadata helpers.
//

import CoreGraphics

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

    /// Approximate bit rate (bits per second) used when exporting video at this quality.
    var bitRate: Int {
        switch self {
        case .hd720:
            return 4_000_000
        case .hd1080:
            return 8_000_000
        case .uhd4k:
            return 20_000_000
        }
    }
}
