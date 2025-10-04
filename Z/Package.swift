// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "DualApp",
    platforms: [
        .iOS(.v26) // iOS 18+ minimum deployment target
    ],
    products: [
        .library(
            name: "DualApp",
            targets: ["DualApp"]),
    ],
    dependencies: [
        // Add iOS 18+ specific dependencies
        .package(url: "https://github.com/apple/swift-async-algorithms", from: "1.0.0")
    ],
    targets: [
        .target(
            name: "DualApp",
            dependencies: [
                .product(name: "AsyncAlgorithms", package: "swift-async-algorithms")
            ],
            path: "DualApp",
            exclude: ["Tests"],
            linkerSettings: [
                .linkedFramework("AVFoundation"),
                .linkedFramework("CoreImage"),
                .linkedFramework("CoreVideo"),
                .linkedFramework("Metal"),
                .linkedFramework("MetalKit"),
                .linkedFramework("VideoToolbox"),
                .linkedFramework("ActivityKit"),
                .linkedFramework("AppIntents"),
                .linkedFramework("CoreMotion"),
                .linkedFramework("CoreML"),
                .linkedFramework("Vision"),
                .linkedFramework("CoreLocation"),
                .linkedFramework("CoreBluetooth"),
                .linkedFramework("CoreNFC"),
                .linkedFramework("EventKit"),
                .linkedFramework("MediaPlayer"),
                .linkedFramework("Photos"),
                .linkedFramework("PhotosUI"),
                .linkedFramework("UserNotifications"),
                .linkedFramework("WidgetKit"),
                .linkedFramework("BackgroundTasks"),
                .linkedFramework("Compression"),
                .linkedFramework("CryptoKit"),
                .linkedFramework("LocalAuthentication"),
                .linkedFramework("DeviceCheck"),
                .linkedFramework("Network"),
                .linkedFramework("Security"),
                .linkedFramework("Speech"),
                .linkedFramework("SoundAnalysis"),
                .linkedFramework("PencilKit"),
                .linkedFramework("ARKit"),
                .linkedFramework("RealityKit"),
                .linkedFramework("SceneKit"),
                .linkedFramework("SpriteKit"),
                .linkedFramework("GameplayKit"),
                .linkedFramework("GameController"),
                .linkedFramework("CoreHaptics"),
                .linkedFramework("CoreGraphics"),
                .linkedFramework("CoreText"),
                .linkedFramework("CoreAnimation"),
                .linkedFramework("QuartzCore"),
                .linkedFramework("CoreFoundation"),
                .linkedFramework("Foundation"),
                .linkedFramework("UIKit"),
                .linkedFramework("SwiftUI"),
                .linkedFramework("Combine"),
                .linkedFramework("SwiftData")
            ]
        ),
        .testTarget(
            name: "DualAppTests",
            dependencies: ["DualApp"],
            path: "DualApp/Tests"),
    ]
)
