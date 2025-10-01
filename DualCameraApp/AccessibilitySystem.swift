//
//  AccessibilitySystem.swift
//  DualCameraApp
//
//  Comprehensive accessibility system with VoiceOver navigation and custom actions
//

import UIKit

/// Comprehensive accessibility system with VoiceOver navigation and custom actions
class AccessibilitySystem {
    
    static let shared = AccessibilitySystem()
    
    private init() {}
    
    // MARK: - Accessibility Manager
    
    /// Manages accessibility settings and configurations
    class AccessibilityManager {
        
        private init() {}
        
        static let shared = AccessibilityManager()
        
        /// Checks if VoiceOver is currently running
        var isVoiceOverRunning: Bool {
            return UIAccessibility.isVoiceOverRunning
        }
        
        /// Checks if Switch Control is currently running
        var isSwitchControlRunning: Bool {
            return UIAccessibility.isSwitchControlRunning
        }
        
        /// Checks if the user prefers high contrast
        var prefersHighContrast: Bool {
            return UIAccessibility.isDarkerSystemColorsEnabled
        }
        
        /// Checks if the user prefers reduced motion
        var prefersReducedMotion: Bool {
            return UIAccessibility.isReduceMotionEnabled
        }
        
        /// Checks if the user prefers bold text
        var prefersBoldText: Bool {
            return UIAccessibility.isBoldTextEnabled
        }
        
        /// Posts an accessibility notification
        func postNotification(_ notification: UIAccessibility.Notification, argument: Any? = nil) {
            UIAccessibility.post(notification: notification, argument: argument)
        }
        
        /// Posts an announcement for VoiceOver users
        func announce(_ message: String) {
            postNotification(.announcement, argument: message)
        }
        
        /// Posts a screen changed notification
        func screenChanged(to element: String? = nil) {
            postNotification(.screenChanged, argument: element)
        }
        
        /// Posts a layout changed notification
        func layoutChanged(to element: String? = nil) {
            postNotification(.layoutChanged, argument: element)
        }
        
        /// Posts a page scrolled notification
        func pageScrolled(to edge: UIAccessibility.Notification) {
            postNotification(edge)
        }
    }
    
    // MARK: - Custom Actions
    
    /// Custom accessibility actions for camera controls
    class CameraAccessibilityActions {
        
        /// Creates a custom action for capturing a photo
        static func capturePhotoAction(target: Any?, selector: Selector) -> UIAccessibilityCustomAction {
            return UIAccessibilityCustomAction(
                name: "Capture Photo",
                target: target,
                selector: selector
            )
        }
        
        /// Creates a custom action for starting recording
        static func startRecordingAction(target: Any?, selector: Selector) -> UIAccessibilityCustomAction {
            return UIAccessibilityCustomAction(
                name: "Start Recording",
                target: target,
                selector: selector
            )
        }
        
        /// Creates a custom action for stopping recording
        static func stopRecordingAction(target: Any?, selector: Selector) -> UIAccessibilityCustomAction {
            return UIAccessibilityCustomAction(
                name: "Stop Recording",
                target: target,
                selector: selector
            )
        }
        
        /// Creates a custom action for pausing recording
        static func pauseRecordingAction(target: Any?, selector: Selector) -> UIAccessibilityCustomAction {
            return UIAccessibilityCustomAction(
                name: "Pause Recording",
                target: target,
                selector: selector
            )
        }
        
        /// Creates a custom action for resuming recording
        static func resumeRecordingAction(target: Any?, selector: Selector) -> UIAccessibilityCustomAction {
            return UIAccessibilityCustomAction(
                name: "Resume Recording",
                target: target,
                selector: selector
            )
        }
        
        /// Creates a custom action for switching camera
        static func switchCameraAction(target: Any?, selector: Selector) -> UIAccessibilityCustomAction {
            return UIAccessibilityCustomAction(
                name: "Switch Camera",
                target: target,
                selector: selector
            )
        }
        
        /// Creates a custom action for toggling flash
        static func toggleFlashAction(target: Any?, selector: Selector) -> UIAccessibilityCustomAction {
            return UIAccessibilityCustomAction(
                name: "Toggle Flash",
                target: target,
                selector: selector
            )
        }
        
        /// Creates a custom action for adjusting focus
        static func adjustFocusAction(target: Any?, selector: Selector) -> UIAccessibilityCustomAction {
            return UIAccessibilityCustomAction(
                name: "Adjust Focus",
                target: target,
                selector: selector
            )
        }
        
        /// Creates a custom action for adjusting zoom
        static func adjustZoomAction(target: Any?, selector: Selector) -> UIAccessibilityCustomAction {
            return UIAccessibilityCustomAction(
                name: "Adjust Zoom",
                target: target,
                selector: selector
            )
        }
        
        /// Creates a custom action for switching to photo mode
        static func switchToPhotoModeAction(target: Any?, selector: Selector) -> UIAccessibilityCustomAction {
            return UIAccessibilityCustomAction(
                name: "Switch to Photo Mode",
                target: target,
                selector: selector
            )
        }
        
        /// Creates a custom action for switching to video mode
        static func switchToVideoModeAction(target: Any?, selector: Selector) -> UIAccessibilityCustomAction {
            return UIAccessibilityCustomAction(
                name: "Switch to Video Mode",
                target: target,
                selector: selector
            )
        }
        
        /// Creates a custom action for showing settings
        static func showSettingsAction(target: Any?, selector: Selector) -> UIAccessibilityCustomAction {
            return UIAccessibilityCustomAction(
                name: "Show Settings",
                target: target,
                selector: selector
            )
        }
        
        /// Creates a custom action for hiding controls
        static func hideControlsAction(target: Any?, selector: Selector) -> UIAccessibilityCustomAction {
            return UIAccessibilityCustomAction(
                name: "Hide Controls",
                target: target,
                selector: selector
            )
        }
        
        /// Creates a custom action for showing controls
        static func showControlsAction(target: Any?, selector: Selector) -> UIAccessibilityCustomAction {
            return UIAccessibilityCustomAction(
                name: "Show Controls",
                target: target,
                selector: selector
            )
        }
    }
    
    // MARK: - Navigation Helpers
    
    /// Helpers for navigating the app with VoiceOver
    class NavigationHelpers {
        
        /// Sets up the accessibility order for a view and its subviews
        static func setAccessibilityOrder(for view: UIView, elements: [UIView]) {
            // Set the accessibility elements in the specified order
            view.accessibilityElements = elements
        }
        
        /// Sets up the accessibility frame for a view
        static func setAccessibilityFrame(for view: UIView, in container: UIView) {
            view.accessibilityFrame = container.convert(view.bounds, to: nil)
        }
        
        /// Sets up the accessibility activation point for a view
        static func setAccessibilityActivationPoint(for view: UIView, point: CGPoint) {
            view.accessibilityActivationPoint = point
        }
        
        /// Sets up the accessibility language for a view
        static func setAccessibilityLanguage(for view: UIView, language: String) {
            view.accessibilityLanguage = language
        }
        
        /// Sets up the accessibility hint for a view
        static func setAccessibilityHint(for view: UIView, hint: String) {
            view.accessibilityHint = hint
        }
        
        /// Sets up the accessibility label for a view
        static func setAccessibilityLabel(for view: UIView, label: String) {
            view.accessibilityLabel = label
        }
        
        /// Sets up the accessibility value for a view
        static func setAccessibilityValue(for view: UIView, value: String) {
            view.accessibilityValue = value
        }
        
        /// Sets up the accessibility traits for a view
        static func setAccessibilityTraits(for view: UIView, traits: UIAccessibilityTraits) {
            view.accessibilityTraits = traits
        }
        
        /// Sets up the accessibility identifier for a view
        static func setAccessibilityIdentifier(for view: UIView, identifier: String) {
            view.accessibilityIdentifier = identifier
        }
        
        /// Sets up the accessibility navigation style for a view
        static func setAccessibilityNavigationStyle(for view: UIView, style: UIAccessibilityNavigationStyle) {
            view.accessibilityNavigationStyle = style
        }
        
        /// Sets up the accessibility container type for a view
        static func setAccessibilityContainerType(for view: UIView, type: UIAccessibilityContainerType) {
            view.accessibilityContainerType = type
        }
    }
    
    // MARK: - VoiceOver Guides
    
    /// Provides guidance for VoiceOver users
    class VoiceOverGuides {
        
        /// Provides an introduction to the camera interface
        static func provideCameraInterfaceIntroduction() {
            let introduction = """
            Welcome to Dual Camera. This interface allows you to record with both front and back cameras simultaneously.
            
            The main recording button is located at the bottom center of the screen.
            Swipe left or right to access additional controls like flash, camera switch, and settings.
            Double-tap anywhere on the screen to focus the camera.
            Use two-finger double-tap to capture a photo.
            Use two-finger long-press to start recording video.
            """
            
            AccessibilityManager.shared.announce(introduction)
        }
        
        /// Provides guidance for recording video
        static func provideRecordingGuidance() {
            let guidance = """
            To start recording video, use two-finger long-press on the screen.
            While recording, you can double-tap with two fingers to pause or resume.
            To stop recording, use two-finger double-tap.
            """
            
            AccessibilityManager.shared.announce(guidance)
        }
        
        /// Provides guidance for capturing photos
        static func providePhotoCaptureGuidance() {
            let guidance = """
            To capture a photo, use two-finger double-tap on the screen.
            You can also use the capture button at the bottom of the screen.
            """
            
            AccessibilityManager.shared.announce(guidance)
        }
        
        /// Provides guidance for switching between modes
        static func provideModeSwitchingGuidance() {
            let guidance = """
            To switch between photo and video modes, swipe left or right until you find the mode selector.
            Double-tap to select a mode.
            """
            
            AccessibilityManager.shared.announce(guidance)
        }
        
        /// Provides guidance for accessing settings
        static func provideSettingsAccessGuidance() {
            let guidance = """
            To access settings, swipe left or right until you find the settings button.
            Double-tap to open settings.
            """
            
            AccessibilityManager.shared.announce(guidance)
        }
    }
    
    // MARK: - Haptic Accessibility
    
    /// Provides haptic feedback for accessibility
    class HapticAccessibility {
        
        /// Provides haptic feedback for important events
        static func provideFeedback(for event: AccessibilityEvent) {
            switch event {
            case .recordingStarted:
                HapticFeedbackManager.shared.recordingStart()
            case .recordingStopped:
                HapticFeedbackManager.shared.recordingStop()
            case .photoCaptured:
                HapticFeedbackManager.shared.photoCapture()
            case .cameraSwitched:
                HapticFeedbackManager.shared.cameraSwitch()
            case .flashToggled:
                HapticFeedbackManager.shared.flashToggle()
            case .focusAdjusted:
                HapticFeedbackManager.shared.focusAdjustment()
            case .zoomAdjusted:
                HapticFeedbackManager.shared.zoomAdjustment()
            case .modeChanged:
                HapticFeedbackManager.shared.selectionChanged()
            case .settingsOpened:
                HapticFeedbackManager.shared.lightImpact()
            case .errorOccurred:
                HapticFeedbackManager.shared.errorOccurred()
            case .warning:
                HapticFeedbackManager.shared.warning()
            case .success:
                HapticFeedbackManager.shared.success()
            }
        }
        
        enum AccessibilityEvent {
            case recordingStarted
            case recordingStopped
            case photoCaptured
            case cameraSwitched
            case flashToggled
            case focusAdjusted
            case zoomAdjusted
            case modeChanged
            case settingsOpened
            case errorOccurred
            case warning
            case success
        }
    }
    
    // MARK: - Accessibility Settings
    
    /// Manages accessibility-specific settings
    class AccessibilitySettings {
        
        private init() {}
        
        static let shared = AccessibilitySettings()
        
        private let userDefaults = UserDefaults.standard
        private let voiceOverGuidanceShownKey = "VoiceOverGuidanceShown"
        
        /// Checks if VoiceOver guidance has been shown
        var hasShownVoiceOverGuidance: Bool {
            get {
                return userDefaults.bool(forKey: voiceOverGuidanceShownKey)
            }
            set {
                userDefaults.set(newValue, forKey: voiceOverGuidanceShownKey)
            }
        }
        
        /// Shows VoiceOver guidance if it hasn't been shown before
        func showVoiceOverGuidanceIfNeeded() {
            if AccessibilityManager.shared.isVoiceOverRunning && !hasShownVoiceOverGuidance {
                VoiceOverGuides.provideCameraInterfaceIntroduction()
                hasShownVoiceOverGuidance = true
            }
        }
        
        /// Enables or disables accessibility-specific features
        func setAccessibilityFeaturesEnabled(_ enabled: Bool) {
            // This would enable/disable accessibility-specific features
            // For example, larger touch targets, higher contrast, etc.
        }
        
        /// Adjusts the UI based on accessibility settings
        func adjustUIForAccessibilitySettings() {
            // Adjust UI based on accessibility settings
            if AccessibilityManager.shared.prefersHighContrast {
                // Increase contrast
            }
            
            if AccessibilityManager.shared.prefersBoldText {
                // Use bold text
            }
            
            if AccessibilityManager.shared.prefersReducedMotion {
                // Reduce animations
            }
        }
    }
    
    // MARK: - Accessibility Utilities
    
    /// Utility functions for accessibility
    class AccessibilityUtilities {
        
        /// Creates an accessible button with proper labeling
        static func createAccessibleButton(
            title: String,
            accessibilityLabel: String? = nil,
            accessibilityHint: String? = nil,
            target: Any?,
            selector: Selector
        ) -> UIButton {
            let button = UIButton(type: .system)
            button.setTitle(title, for: .normal)
            button.accessibilityLabel = accessibilityLabel ?? title
            button.accessibilityHint = accessibilityHint
            button.addTarget(target, action: selector, for: .touchUpInside)
            
            return button
        }
        
        /// Creates an accessible image view with proper labeling
        static func createAccessibleImageView(
            image: UIImage?,
            accessibilityLabel: String,
            isAccessibilityElement: Bool = true
        ) -> UIImageView {
            let imageView = UIImageView(image: image)
            imageView.accessibilityLabel = accessibilityLabel
            imageView.isAccessibilityElement = isAccessibilityElement
            
            return imageView
        }
        
        /// Creates an accessible label with proper styling
        static func createAccessibleLabel(
            text: String,
            accessibilityLabel: String? = nil,
            accessibilityHint: String? = nil,
            font: UIFont? = nil,
            textColor: UIColor? = nil
        ) -> UILabel {
            let label = UILabel()
            label.text = text
            label.accessibilityLabel = accessibilityLabel ?? text
            label.accessibilityHint = accessibilityHint
            
            if let font = font {
                label.font = font
            }
            
            if let textColor = textColor {
                label.textColor = textColor
            }
            
            return label
        }
        
        /// Creates an accessible slider with proper labeling
        static func createAccessibleSlider(
            accessibilityLabel: String,
            accessibilityHint: String? = nil,
            minimumValue: Float,
            maximumValue: Float,
            value: Float
        ) -> UISlider {
            let slider = UISlider()
            slider.minimumValue = minimumValue
            slider.maximumValue = maximumValue
            slider.value = value
            slider.accessibilityLabel = accessibilityLabel
            slider.accessibilityHint = accessibilityHint
            
            return slider
        }
        
        /// Creates an accessible switch with proper labeling
        static func createAccessibleSwitch(
            accessibilityLabel: String,
            accessibilityHint: String? = nil,
            isOn: Bool
        ) -> UISwitch {
            let switchControl = UISwitch()
            switchControl.isOn = isOn
            switchControl.accessibilityLabel = accessibilityLabel
            switchControl.accessibilityHint = accessibilityHint
            
            return switchControl
        }
        
        /// Creates an accessible segmented control with proper labeling
        static func createAccessibleSegmentedControl(
            items: [String],
            accessibilityLabel: String,
            accessibilityHint: String? = nil,
            selectedSegmentIndex: Int
        ) -> UISegmentedControl {
            let segmentedControl = UISegmentedControl(items: items)
            segmentedControl.selectedSegmentIndex = selectedSegmentIndex
            segmentedControl.accessibilityLabel = accessibilityLabel
            segmentedControl.accessibilityHint = accessibilityHint
            
            return segmentedControl
        }
    }
}

// MARK: - UIView Extensions for Accessibility

extension UIView {
    
    /// Makes a view accessible with common properties
    func makeAccessible(
        label: String? = nil,
        hint: String? = nil,
        value: String? = nil,
        traits: UIAccessibilityTraits = .none,
        identifier: String? = nil
    ) {
        if let label = label {
            accessibilityLabel = label
        }
        
        if let hint = hint {
            accessibilityHint = hint
        }
        
        if let value = value {
            accessibilityValue = value
        }
        
        if traits != .none {
            accessibilityTraits.insert(traits)
        }
        
        if let identifier = identifier {
            accessibilityIdentifier = identifier
        }
    }
    
    /// Adds custom accessibility actions to a view
    func addAccessibilityActions(_ actions: [UIAccessibilityCustomAction]) {
        var existingActions = accessibilityCustomActions ?? []
        existingActions.append(contentsOf: actions)
        accessibilityCustomActions = existingActions
    }
    
    /// Sets up accessibility for a button
    func setupButtonAccessibility(
        label: String,
        hint: String? = nil,
        traits: UIAccessibilityTraits = .button
    ) {
        makeAccessible(label: label, hint: hint, traits: traits)
    }
    
    /// Sets up accessibility for an image view
    func setupImageViewAccessibility(
        label: String,
        hint: String? = nil,
        traits: UIAccessibilityTraits = .image
    ) {
        makeAccessible(label: label, hint: hint, traits: traits)
    }
    
    /// Sets up accessibility for a label
    func setupLabelAccessibility(
        label: String,
        hint: String? = nil,
        traits: UIAccessibilityTraits = .staticText
    ) {
        makeAccessible(label: label, hint: hint, traits: traits)
    }
    
    /// Sets up accessibility for a slider
    func setupSliderAccessibility(
        label: String,
        hint: String? = nil,
        value: String? = nil,
        traits: UIAccessibilityTraits = .adjustable
    ) {
        makeAccessible(label: label, hint: hint, value: value, traits: traits)
    }
    
    /// Sets up accessibility for a switch
    func setupSwitchAccessibility(
        label: String,
        hint: String? = nil,
        value: String? = nil,
        traits: UIAccessibilityTraits = .button
    ) {
        makeAccessible(label: label, hint: hint, value: value, traits: traits)
    }
    
    /// Sets up accessibility for a segmented control
    func setupSegmentedControlAccessibility(
        label: String,
        hint: String? = nil,
        value: String? = nil,
        traits: UIAccessibilityTraits = .adjustable
    ) {
        makeAccessible(label: label, hint: hint, value: value, traits: traits)
    }
}