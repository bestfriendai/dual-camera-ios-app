//
//  BatteryAwareProcessingManager.swift
//  DualCameraApp
//
//  Battery-aware AI processing with adaptive quality
//

import Foundation
import UIKit
import os.log

@available(iOS 15.0, *)
final class BatteryAwareProcessingManager {
    
    static let shared = BatteryAwareProcessingManager()
    
    private let logger = Logger(subsystem: "com.dualcamera.app", category: "BatteryAware")
    private var batteryMonitorTimer: Timer?
    
    private(set) var isLowPowerModeEnabled = false
    private(set) var batteryLevel: Float = 1.0
    private(set) var batteryState: UIDevice.BatteryState = .unknown
    
    var shouldEnableAIProcessing: Bool {
        if isLowPowerModeEnabled {
            return false
        }
        
        if batteryState == .unplugged && batteryLevel < 0.2 {
            return false
        }
        
        return true
    }
    
    var recommendedVideoQuality: VideoQuality {
        if isLowPowerModeEnabled {
            return .hd720
        }
        
        switch batteryLevel {
        case 0..<0.2:
            return .hd720
        case 0.2..<0.5:
            return .hd1080
        default:
            return .uhd4k
        }
    }
    
    private init() {
        setupBatteryMonitoring()
    }
    
    private func setupBatteryMonitoring() {
        UIDevice.current.isBatteryMonitoringEnabled = true
        
        updateBatteryStatus()
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(batteryStateDidChange),
            name: UIDevice.batteryStateDidChangeNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(batteryLevelDidChange),
            name: UIDevice.batteryLevelDidChangeNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(powerStateDidChange),
            name: .NSProcessInfoPowerStateDidChange,
            object: nil
        )
        
        batteryMonitorTimer = Timer.scheduledTimer(
            withTimeInterval: 30.0,
            repeats: true
        ) { [weak self] _ in
            self?.updateBatteryStatus()
        }
    }
    
    @objc private func batteryStateDidChange() {
        updateBatteryStatus()
        logger.info("Battery state changed: \(self.batteryState.description)")
        postBatteryStatusUpdate()
    }
    
    @objc private func batteryLevelDidChange() {
        updateBatteryStatus()
        logger.info("Battery level changed: \(Int(self.batteryLevel * 100))%")
        postBatteryStatusUpdate()
    }
    
    @objc private func powerStateDidChange() {
        isLowPowerModeEnabled = ProcessInfo.processInfo.isLowPowerModeEnabled
        logger.info("Low Power Mode: \(self.isLowPowerModeEnabled ? "enabled" : "disabled")")
        postBatteryStatusUpdate()
    }
    
    private func updateBatteryStatus() {
        batteryLevel = UIDevice.current.batteryLevel
        batteryState = UIDevice.current.batteryState
        isLowPowerModeEnabled = ProcessInfo.processInfo.isLowPowerModeEnabled
    }
    
    private func postBatteryStatusUpdate() {
        NotificationCenter.default.post(
            name: .batteryStatusChanged,
            object: nil,
            userInfo: [
                "shouldEnableAI": shouldEnableAIProcessing,
                "recommendedQuality": recommendedVideoQuality,
                "batteryLevel": batteryLevel,
                "isLowPowerMode": isLowPowerModeEnabled
            ]
        )
    }
    
    func shouldThrottleFrameRate() -> Bool {
        return isLowPowerModeEnabled || (batteryState == .unplugged && batteryLevel < 0.3)
    }
    
    func shouldDisableTripleOutput() -> Bool {
        return isLowPowerModeEnabled || (batteryState == .unplugged && batteryLevel < 0.25)
    }
    
    func recommendedFrameRate() -> Int32 {
        if isLowPowerModeEnabled {
            return 24
        }
        
        switch batteryLevel {
        case 0..<0.2:
            return 24
        case 0.2..<0.5:
            return 30
        default:
            return 60
        }
    }
    
    deinit {
        batteryMonitorTimer?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }
}

extension UIDevice.BatteryState {
    var description: String {
        switch self {
        case .unknown: return "unknown"
        case .unplugged: return "unplugged"
        case .charging: return "charging"
        case .full: return "full"
        @unknown default: return "unknown"
        }
    }
}

extension Notification.Name {
    static let batteryStatusChanged = Notification.Name("BatteryStatusChanged")
}
