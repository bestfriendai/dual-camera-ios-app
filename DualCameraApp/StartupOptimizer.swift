//
//  StartupOptimizer.swift
//  DualCameraApp
//
//  Optimizes app startup performance to achieve sub-1.5 second launch times
//

import Foundation
import UIKit
import AVFoundation
import os.signpost

class StartupOptimizer {
    static let shared = StartupOptimizer()
    
    private let log = OSLog(subsystem: "com.dualcamera.app", category: "Startup")
    private var startupSignpostID: OSSignpostID?
    private var startupStartTime: CFTimeInterval = 0
    
    // Startup phases
    enum StartupPhase: String, CaseIterable {
        case appLaunch = "App Launch"
        case permissionCheck = "Permission Check"
        case cameraDiscovery = "Camera Discovery"
        case sessionConfiguration = "Session Configuration"
        case previewSetup = "Preview Setup"
        case uiInitialization = "UI Initialization"
        case readyState = "Ready State"
    }
    
    enum StartupError: LocalizedError {
        case configurationFailed(String)
        
        var errorDescription: String? {
            switch self {
            case .configurationFailed(let reason):
                return reason
            }
        }
    }
    
    // Performance targets (in milliseconds)
    private struct PerformanceTargets {
        static let appLaunch: CFTimeInterval = 500      // 0.5s
        static let permissionCheck: CFTimeInterval = 100 // 0.1s
        static let cameraDiscovery: CFTimeInterval = 200 // 0.2s
        static let sessionConfiguration: CFTimeInterval = 400 // 0.4s
        static let previewSetup: CFTimeInterval = 200   // 0.2s
        static let uiInitialization: CFTimeInterval = 100 // 0.1s
        static let totalStartup: CFTimeInterval = 1500  // 1.5s total
    }
    
    // Current phase tracking
    private var currentPhase: StartupPhase?
    private var phaseStartTimes: [StartupPhase: CFTimeInterval] = [:]
    private var phaseDurations: [StartupPhase: CFTimeInterval] = [:]
    
    // Optimization flags
    private var isOptimizedStartup = true
    private var hasPreloadedResources = false
    
    private init() {
        // Preload critical resources during app launch
        preloadCriticalResources()
    }
    
    // MARK: - Startup Optimization
    
    func beginStartupOptimization() {
        startupStartTime = CACurrentMediaTime()
        let signpostID = OSSignpostID(log: log)
        startupSignpostID = signpostID
        
        os_signpost(.begin, log: log, name: "App Startup", signpostID: signpostID)
        logEvent("Startup", "Began startup optimization")
        
        // Start first phase
        beginPhase(.appLaunch)
    }
    
    func beginPhase(_ phase: StartupPhase) {
        // End previous phase if exists
        if let currentPhase = currentPhase {
            endPhase(currentPhase)
        }
        
        currentPhase = phase
        phaseStartTimes[phase] = CACurrentMediaTime()
        
        logEvent("Startup Phase", "Began \(phase.rawValue)")
    }
    
    func endPhase(_ phase: StartupPhase) {
        guard let startTime = phaseStartTimes[phase] else { return }
        
        let duration = CACurrentMediaTime() - startTime
        phaseDurations[phase] = duration
        
        // Check if phase exceeded target
        let target = getTargetForPhase(phase)
        if duration > target {
            logEvent("Performance Warning", "\(phase.rawValue) took \(String(format: "%.0f", duration * 1000))ms (target: \(String(format: "%.0f", target * 1000))ms)")
        }
        
        logEvent("Startup Phase", "Completed \(phase.rawValue) in \(String(format: "%.0f", duration * 1000))ms")
    }
    
    func completeStartup() {
        // End final phase
        if let currentPhase = currentPhase {
            endPhase(currentPhase)
        }
        
        let totalDuration = CACurrentMediaTime() - startupStartTime
        
        guard let signpostID = startupSignpostID else { return }
        os_signpost(.end, log: log, name: "App Startup", signpostID: signpostID)
        
        // Log startup summary
        logStartupSummary(totalDuration: totalDuration)
        
        // Reset for next startup
        resetStartupState()
    }
    
    // MARK: - Resource Preloading
    
    private func preloadCriticalResources() {
        guard !hasPreloadedResources else { return }
        
        DispatchQueue.global(qos: .userInitiated).async {
            // Preload Metal device and context
            _ = MTLCreateSystemDefaultDevice()
            
            // Preload camera formats
            self.preloadCameraFormats()
            
            // Preload common image assets
            self.preloadImageAssets()
            
            // Preload audio session
            self.preloadAudioSession()
            
            DispatchQueue.main.async {
                self.hasPreloadedResources = true
                self.logEvent("Resource Preloading", "Completed critical resource preloading")
            }
        }
    }
    
    private func preloadCameraFormats() {
        // Discover available camera devices and formats
        let discoveryQueue = DispatchQueue(label: "CameraDiscovery", qos: .userInitiated)
        
        discoveryQueue.async {
            let frontCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
            let backCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
            
            // Cache device capabilities
            if let frontCamera = frontCamera {
                _ = frontCamera.activeFormat.formatDescription
                _ = frontCamera.activeFormat.videoSupportedFrameRateRanges
            }
            
            if let backCamera = backCamera {
                _ = backCamera.activeFormat.formatDescription
                _ = backCamera.activeFormat.videoSupportedFrameRateRanges
            }
        }
    }
    
    private func preloadImageAssets() {
        // Preload common UI assets
        DispatchQueue.global(qos: .utility).async {
            // Preload system images
            _ = UIImage(systemName: "camera.fill")
            _ = UIImage(systemName: "record.circle.fill")
            _ = UIImage(systemName: "stop.circle.fill")
            _ = UIImage(systemName: "photo.fill")
            _ = UIImage(systemName: "gear")
        }
    }
    
    private func preloadAudioSession() {
        // Configure audio session in background
        DispatchQueue.global(qos: .utility).async {
            do {
                let audioSession = AVAudioSession.sharedInstance()
                try audioSession.setCategory(.playAndRecord, mode: .videoRecording)
                try audioSession.setActive(true)
            } catch {
                print("Failed to preload audio session: \(error)")
            }
        }
    }
    
    // MARK: - Permission Optimization
    
    func optimizePermissionCheck() -> Bool {
        beginPhase(.permissionCheck)
        
        let cameraStatus = AVCaptureDevice.authorizationStatus(for: .video)
        let audioStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        
        let hasAllPermissions = cameraStatus == .authorized && audioStatus == .authorized
        
        endPhase(.permissionCheck)
        
        return hasAllPermissions
    }
    
    // MARK: - Camera Setup Optimization
    
    func optimizeCameraSetup() -> (front: AVCaptureDevice?, back: AVCaptureDevice?) {
        beginPhase(.cameraDiscovery)
        
        // Discover cameras concurrently
        let discoveryQueue = DispatchQueue(label: "CameraDiscovery", qos: .userInitiated)
        var frontCamera: AVCaptureDevice?
        var backCamera: AVCaptureDevice?
        
        let group = DispatchGroup()
        
        // Front camera discovery
        group.enter()
        discoveryQueue.async {
            frontCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
            group.leave()
        }
        
        // Back camera discovery
        group.enter()
        discoveryQueue.async {
            backCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
            group.leave()
        }
        
        // Wait for discovery
        group.wait()
        
        endPhase(.cameraDiscovery)
        
        return (frontCamera, backCamera)
    }
    
    // MARK: - Session Configuration Optimization
    
    func optimizeSessionConfiguration(session: AVCaptureMultiCamSession,
                                    frontCamera: AVCaptureDevice,
                                    backCamera: AVCaptureDevice) throws {
        beginPhase(.sessionConfiguration)
        
        // Use optimized configuration pattern
        session.beginConfiguration()
        
        // Batch all configuration changes
        defer {
            session.commitConfiguration()
            endPhase(.sessionConfiguration)
        }
        
        // Add inputs with minimal validation
        let frontInput = try AVCaptureDeviceInput(device: frontCamera)
        let backInput = try AVCaptureDeviceInput(device: backCamera)
        
        guard session.canAddInput(frontInput) else {
            throw StartupError.configurationFailed("Unable to add front camera input")
        }
        session.addInputWithNoConnections(frontInput)
        
        guard session.canAddInput(backInput) else {
            throw StartupError.configurationFailed("Unable to add back camera input")
        }
        session.addInputWithNoConnections(backInput)
        
        // Configure outputs efficiently
        configureOptimizedOutputs(session: session, frontInput: frontInput, backInput: backInput)
    }
    
    private func configureOptimizedOutputs(session: AVCaptureMultiCamSession,
                                         frontInput: AVCaptureDeviceInput,
                                         backInput: AVCaptureDeviceInput) {
        // Configure only essential outputs for startup
        // Additional outputs can be added later in deferred setup
        
        // Preview layers are configured in the preview setup phase
        // Movie outputs are configured when recording starts
        // Photo outputs are configured when photo capture is needed
    }
    
    // MARK: - Preview Setup Optimization
    
    func optimizePreviewSetup(session: AVCaptureMultiCamSession,
                             frontInput: AVCaptureDeviceInput,
                             backInput: AVCaptureDeviceInput) -> (front: AVCaptureVideoPreviewLayer?, back: AVCaptureVideoPreviewLayer?) {
        beginPhase(.previewSetup)
        
        // Create preview layers with optimized settings
        let frontPreviewLayer = AVCaptureVideoPreviewLayer(sessionWithNoConnection: session)
        frontPreviewLayer.videoGravity = .resizeAspectFill
        
        let backPreviewLayer = AVCaptureVideoPreviewLayer(sessionWithNoConnection: session)
        backPreviewLayer.videoGravity = .resizeAspectFill
        
        // Get video ports efficiently
        guard let frontVideoPort = frontInput.ports(for: .video, sourceDeviceType: frontInput.device.deviceType, sourceDevicePosition: .front).first,
              let backVideoPort = backInput.ports(for: .video, sourceDeviceType: backInput.device.deviceType, sourceDevicePosition: .back).first else {
            endPhase(.previewSetup)
            return (nil, nil)
        }
        
        // Create connections
        let frontConnection = AVCaptureConnection(inputPort: frontVideoPort, videoPreviewLayer: frontPreviewLayer)
        let backConnection = AVCaptureConnection(inputPort: backVideoPort, videoPreviewLayer: backPreviewLayer)
        
        // Add connections
        session.addConnection(frontConnection)
        session.addConnection(backConnection)
        
        // Set orientation
        if frontConnection.isVideoOrientationSupported {
            frontConnection.videoOrientation = .portrait
        }
        if backConnection.isVideoOrientationSupported {
            backConnection.videoOrientation = .portrait
        }
        
        endPhase(.previewSetup)
        
        return (frontPreviewLayer, backPreviewLayer)
    }
    
    // MARK: - Performance Monitoring
    
    private func getTargetForPhase(_ phase: StartupPhase) -> CFTimeInterval {
        switch phase {
        case .appLaunch:
            return PerformanceTargets.appLaunch
        case .permissionCheck:
            return PerformanceTargets.permissionCheck
        case .cameraDiscovery:
            return PerformanceTargets.cameraDiscovery
        case .sessionConfiguration:
            return PerformanceTargets.sessionConfiguration
        case .previewSetup:
            return PerformanceTargets.previewSetup
        case .uiInitialization:
            return PerformanceTargets.uiInitialization
        case .readyState:
            return 0 // No target for ready state
        }
    }
    
    private func logStartupSummary(totalDuration: CFTimeInterval) {
        logEvent("Startup Summary", "Total startup time: \(String(format: "%.0f", totalDuration * 1000))ms")
        
        // Log phase breakdown
        for phase in StartupPhase.allCases {
            if let duration = phaseDurations[phase] {
                let target = getTargetForPhase(phase)
                let status = duration > target ? "❌" : "✅"
                logEvent("Phase Summary", "\(status) \(phase.rawValue): \(String(format: "%.0f", duration * 1000))ms (target: \(String(format: "%.0f", target * 1000))ms)")
            }
        }
        
        // Check overall performance
        if totalDuration > PerformanceTargets.totalStartup {
            logEvent("Performance Issue", "Startup time exceeded target of \(String(format: "%.0f", PerformanceTargets.totalStartup * 1000))ms")
        } else {
            logEvent("Performance Success", "Startup completed within target time")
        }
    }
    
    private func logEvent(_ name: StaticString, _ message: String = "") {
        os_signpost(.event, log: log, name: name, "%{public}s", message)
    }
    
    private func resetStartupState() {
        currentPhase = nil
        phaseStartTimes.removeAll()
        phaseDurations.removeAll()
        startupSignpostID = nil
    }
    
    // MARK: - Public Interface
    
    func getStartupMetrics() -> [String: Any] {
        var metrics: [String: Any] = [:]
        
        for phase in StartupPhase.allCases {
            if let duration = phaseDurations[phase] {
                metrics["\(phase.rawValue)_duration"] = duration
                metrics["\(phase.rawValue)_target"] = getTargetForPhase(phase)
            }
        }
        
        if !phaseDurations.isEmpty {
            let totalDuration = phaseDurations.values.reduce(0, +)
            metrics["total_startup_duration"] = totalDuration
            metrics["startup_target"] = PerformanceTargets.totalStartup
        }
        
        return metrics
    }
    
    func isStartupOptimized() -> Bool {
        return isOptimizedStartup && hasPreloadedResources
    }
}

