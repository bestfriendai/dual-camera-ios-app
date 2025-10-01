//
//  HapticFeedbackManager.swift
//  DualCameraApp
//
//  Centralized haptic feedback management for enhanced user experience
//

import UIKit

class HapticFeedbackManager {
    static let shared = HapticFeedbackManager()
    
    private init() {}
    
    // MARK: - Basic Haptic Types
    
    func lightImpact() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
    
    func mediumImpact() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
    }
    
    func heavyImpact() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
        impactFeedback.impactOccurred()
    }
    
    func success() {
        let notificationFeedback = UINotificationFeedbackGenerator()
        notificationFeedback.notificationOccurred(.success)
    }
    
    func warning() {
        let notificationFeedback = UINotificationFeedbackGenerator()
        notificationFeedback.notificationOccurred(.warning)
    }
    
    func error() {
        let notificationFeedback = UINotificationFeedbackGenerator()
        notificationFeedback.notificationOccurred(.error)
    }
    
    // MARK: - Selection Feedback
    
    func selectionChanged() {
        let selectionFeedback = UISelectionFeedbackGenerator()
        selectionFeedback.selectionChanged()
    }
    
    // MARK: - Custom Recording Haptics
    
    func recordingStart() {
        // Prepare the generator for better timing
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.prepare()
        
        // Delay slightly for better user experience
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            impactFeedback.impactOccurred()
        }
    }
    
    func recordingStop() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
        impactFeedback.impactOccurred()
        
        // Follow with success notification
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            let notificationFeedback = UINotificationFeedbackGenerator()
            notificationFeedback.notificationOccurred(.success)
        }
    }
    
    func photoCapture() {
        // Two-stage haptic for photo capture
        let firstImpact = UIImpactFeedbackGenerator(style: .medium)
        firstImpact.impactOccurred()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let secondImpact = UIImpactFeedbackGenerator(style: .light)
            secondImpact.impactOccurred()
        }
    }
    
    func countdownTick(seconds: Int) {
        // Different haptic intensity based on countdown value
        if seconds <= 3 {
            let impactFeedback = UIImpactFeedbackGenerator(style: seconds <= 1 ? .heavy : .medium)
            impactFeedback.impactOccurred()
        } else {
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
        }
    }
    
    func focusAdjustment() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
    
    func zoomAdjustment() {
        let selectionFeedback = UISelectionFeedbackGenerator()
        selectionFeedback.selectionChanged()
    }
    
    func qualityChange() {
        let selectionFeedback = UISelectionFeedbackGenerator()
        selectionFeedback.selectionChanged()
    }
    
    func cameraSwitch() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
    }
    
    func flashToggle() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
    
    func memoryWarning() {
        // Warning haptic pattern
        let warningFeedback = UINotificationFeedbackGenerator()
        warningFeedback.prepare()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            warningFeedback.notificationOccurred(.warning)
        }
    }
    
    func errorOccurred() {
        let errorFeedback = UINotificationFeedbackGenerator()
        errorFeedback.notificationOccurred(.error)
    }
    
    // MARK: - Custom Patterns
    
    func recordingProgress(elapsedSeconds: Int, totalSeconds: Int? = nil) {
        // Provide subtle haptic feedback at certain intervals
        if elapsedSeconds > 0 && elapsedSeconds % 10 == 0 {
            lightImpact()
        }
        
        // Warn when approaching limit
        if let total = totalSeconds {
            let remaining = total - elapsedSeconds
            if remaining <= 10 && remaining > 0 && remaining % 5 == 0 {
                warning()
            }
        }
    }
    
    func gestureFeedback(type: GestureType) {
        switch type {
        case .tap:
            lightImpact()
        case .pinch:
            selectionChanged()
        case .swipe:
            mediumImpact()
        case .longPress:
            // Prepare for potential long press action
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.prepare()
        }
    }
    
    enum GestureType {
        case tap
        case pinch
        case swipe
        case longPress
    }
    
    // MARK: - Settings Integration
    
    func updateHapticSettings(enabled: Bool) {
        // Could integrate with user settings here
        // For now, always enabled
    }
    
    // MARK: - Accessibility Support
    
    func accessibilityAnnouncement(_ message: String) {
        UIAccessibility.post(notification: .announcement, argument: message)
    }
    
    func screenChanged(to element: String) {
        UIAccessibility.post(notification: .screenChanged, argument: element)
    }
    
    func layoutChanged(to element: String) {
        UIAccessibility.post(notification: .layoutChanged, argument: element)
    }
}