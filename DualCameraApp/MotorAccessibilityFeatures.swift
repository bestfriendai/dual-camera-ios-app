//
//  MotorAccessibilityFeatures.swift
//  DualCameraApp
//
//  Motor accessibility features system with support for switch control, reduced motion, and other motor accommodations
//

import UIKit

/// Motor accessibility features system with support for switch control and other motor accommodations
class MotorAccessibilityFeatures {
    
    static let shared = MotorAccessibilityFeatures()
    
    private init() {}
    
    // MARK: - Properties
    
    private var isSwitchControlRunning = false
    private var isAssistiveTouchRunning = false
    private var prefersReducedMotion = false
    private var accessibilitySettingsObservers: [(String, Any) -> Void] = []
    
    // MARK: - Motor Accessibility Configuration
    
    struct MotorAccessibilityConfiguration {
        var enableSwitchControlSupport: Bool = true
        var enableAssistiveTouchSupport: Bool = true
        var enableVoiceControlSupport: Bool = true
        var enableReducedMotionSupport: Bool = true
        var enableTouchAccommodations: Bool = true
        var enableAlternateControlMethods: Bool = true
        var increaseTouchTargetSize: Bool = true
        var enableCustomGestures: Bool = true
        var enableHapticFeedback: Bool = true
        var enableVisualFeedback: Bool = true
        var customTouchTargetSize: CGFloat = 44
        var customAnimationDuration: TimeInterval = 0.3
        var customGestureDelay: TimeInterval = 0.5
        var customRepeatDelay: TimeInterval = 0.5
        var customRepeatInterval: TimeInterval = 0.1
    }
    
    private var motorAccessibilityConfiguration = MotorAccessibilityConfiguration()
    
    // MARK: - Initialization
    
    /// Initializes the motor accessibility features system
    func initialize() {
        updateAccessibilitySettings()
        setupAccessibilitySettingsObserver()
        applyMotorAccessibilityConfiguration()
    }
    
    // MARK: - Accessibility Settings Monitoring
    
    private func updateAccessibilitySettings() {
        isSwitchControlRunning = UIAccessibility.isSwitchControlRunning
        isAssistiveTouchRunning = UIAccessibility.isAssistiveTouchRunning
        prefersReducedMotion = UIAccessibility.isReduceMotionEnabled
        
        notifyAccessibilitySettingsObservers()
    }
    
    private func setupAccessibilitySettingsObserver() {
        // Register for accessibility settings change notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(accessibilitySettingsChanged),
            name: UIAccessibility.voiceOverStatusDidChangeNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(accessibilitySettingsChanged),
            name: UIAccessibility.switchControlStatusDidChangeNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(accessibilitySettingsChanged),
            name: UIAccessibility.assistiveTouchStatusDidChangeNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(accessibilitySettingsChanged),
            name: UIAccessibility.reduceMotionStatusDidChangeNotification,
            object: nil
        )
    }
    
    @objc private func accessibilitySettingsChanged() {
        updateAccessibilitySettings()
        applyMotorAccessibilityConfiguration()
    }
    
    private func notifyAccessibilitySettingsObservers() {
        let settings: [String: Any] = [
            "isSwitchControlRunning": isSwitchControlRunning,
            "isAssistiveTouchRunning": isAssistiveTouchRunning,
            "prefersReducedMotion": prefersReducedMotion
        ]
        
        accessibilitySettingsObservers.forEach { observer in
            for (key, value) in settings {
                observer(key, value)
            }
        }
    }
    
    // MARK: - Public Methods
    
    /// Adds an observer for accessibility settings changes
    func addAccessibilitySettingsObserver(_ observer: @escaping (String, Any) -> Void) {
        accessibilitySettingsObservers.append(observer)
    }
    
    /// Removes an observer for accessibility settings changes
    func removeAccessibilitySettingsObserver(_ observer: @escaping (String, Any) -> Void) {
        accessibilitySettingsObservers.removeAll { storedObserver in
            // This is a simple comparison that works for this use case
            return String(describing: storedObserver) == String(describing: observer)
        }
    }
    
    /// Updates the motor accessibility configuration
    func updateMotorAccessibilityConfiguration(_ configuration: MotorAccessibilityConfiguration) {
        motorAccessibilityConfiguration = configuration
        applyMotorAccessibilityConfiguration()
    }
    
    /// Gets the current motor accessibility configuration
    func getMotorAccessibilityConfiguration() -> MotorAccessibilityConfiguration {
        return motorAccessibilityConfiguration
    }
    
    /// Checks if Switch Control is currently running
    func isSwitchControlEnabled() -> Bool {
        return isSwitchControlRunning
    }
    
    /// Checks if AssistiveTouch is currently running
    func isAssistiveTouchEnabled() -> Bool {
        return isAssistiveTouchRunning
    }
    
    /// Checks if the user prefers reduced motion
    func checkPrefersReducedMotion() -> Bool {
        return prefersReducedMotion
    }
    
    // MARK: - Motor Accessibility Configuration Application
    
    private func applyMotorAccessibilityConfiguration() {
        // Apply configuration based on current accessibility settings
        
        if isSwitchControlRunning && motorAccessibilityConfiguration.enableSwitchControlSupport {
            applySwitchControlConfiguration()
        }
        
        if isAssistiveTouchRunning && motorAccessibilityConfiguration.enableAssistiveTouchSupport {
            applyAssistiveTouchConfiguration()
        }
        
        if prefersReducedMotion && motorAccessibilityConfiguration.enableReducedMotionSupport {
            applyReducedMotionConfiguration()
        }
        
        if motorAccessibilityConfiguration.enableTouchAccommodations {
            applyTouchAccommodations()
        }
        
        if motorAccessibilityConfiguration.enableAlternateControlMethods {
            applyAlternateControlMethods()
        }
    }
    
    private func applySwitchControlConfiguration() {
        // Apply configuration for Switch Control
        NotificationCenter.default.post(name: .motorAccessibilityShouldApplySwitchControlConfiguration, object: nil)
    }
    
    private func applyAssistiveTouchConfiguration() {
        // Apply configuration for AssistiveTouch
        NotificationCenter.default.post(name: .motorAccessibilityShouldApplyAssistiveTouchConfiguration, object: nil)
    }
    
    private func applyReducedMotionConfiguration() {
        // Apply configuration for reduced motion
        NotificationCenter.default.post(name: .motorAccessibilityShouldApplyReducedMotionConfiguration, object: nil)
    }
    
    private func applyTouchAccommodations() {
        // Apply configuration for touch accommodations
        NotificationCenter.default.post(name: .motorAccessibilityShouldApplyTouchAccommodations, object: nil)
    }
    
    private func applyAlternateControlMethods() {
        // Apply configuration for alternate control methods
        NotificationCenter.default.post(name: .motorAccessibilityShouldApplyAlternateControlMethods, object: nil)
    }
    
    // MARK: - Touch Target Size Adjustment
    
    /// Adjusts the touch target size for a view based on motor accessibility configuration
    func adjustTouchTargetSize(for view: UIView) {
        guard motorAccessibilityConfiguration.increaseTouchTargetSize else { return }
        
        let targetSize = motorAccessibilityConfiguration.customTouchTargetSize
        
        // Ensure the view's frame is at least the target size
        if view.frame.width < targetSize || view.frame.height < targetSize {
            let newSize = max(view.frame.width, view.frame.height, targetSize)
            
            // Adjust the view's frame while maintaining its center
            let center = view.center
            view.frame.size = CGSize(width: newSize, height: newSize)
            view.center = center
            
            // Update the view's layer if needed
            if let layer = view.layer as? CAShapeLayer {
                layer.path = UIBezierPath(ovalIn: view.bounds).cgPath
            }
        }
        
        // Adjust the view's accessibility frame
        view.accessibilityFrame = view.frame.insetBy(dx: -5, dy: -5)
    }
    
    // MARK: - Animation Duration Adjustment
    
    /// Adjusts the animation duration based on motor accessibility configuration
    func adjustedAnimationDuration(_ originalDuration: TimeInterval) -> TimeInterval {
        guard motorAccessibilityConfiguration.enableReducedMotionSupport && prefersReducedMotion else {
            return originalDuration
        }
        
        return motorAccessibilityConfiguration.customAnimationDuration
    }
    
    // MARK: - Custom Gesture Support
    
    /// Creates a custom gesture recognizer with motor accessibility accommodations
    func createCustomGestureRecognizer(
        type: GestureType,
        target: Any?,
        action: Selector
    ) -> UIGestureRecognizer {
        let gesture: UIGestureRecognizer
        
        switch type {
        case .tap:
            gesture = UITapGestureRecognizer(target: target, action: action)
        case .doubleTap:
            gesture = UITapGestureRecognizer(target: target, action: action)
            (gesture as! UITapGestureRecognizer).numberOfTapsRequired = 2
        case .longPress:
            gesture = UILongPressGestureRecognizer(target: target, action: action)
            (gesture as! UILongPressGestureRecognizer).minimumPressDuration = motorAccessibilityConfiguration.customGestureDelay
        case .swipe:
            gesture = UISwipeGestureRecognizer(target: target, action: action)
        case .pinch:
            gesture = UIPinchGestureRecognizer(target: target, action: action)
        }
        
        // Add accessibility accommodations
        if motorAccessibilityConfiguration.enableTouchAccommodations {
            gesture.accessibilityLabel = type.accessibilityLabel
            gesture.accessibilityHint = type.accessibilityHint
        }
        
        return gesture
    }
    
    enum GestureType {
        case tap
        case doubleTap
        case longPress
        case swipe
        case pinch
        
        var accessibilityLabel: String {
            switch self {
            case .tap:
                return "Tap"
            case .doubleTap:
                return "Double Tap"
            case .longPress:
                return "Long Press"
            case .swipe:
                return "Swipe"
            case .pinch:
                return "Pinch"
            }
        }
        
        var accessibilityHint: String {
            switch self {
            case .tap:
                return "Tap to activate"
            case .doubleTap:
                return "Double tap to activate"
            case .longPress:
                return "Long press to activate"
            case .swipe:
                return "Swipe to activate"
            case .pinch:
                return "Pinch to activate"
            }
        }
    }
    
    // MARK: - Visual Feedback
    
    /// Provides visual feedback for an action based on motor accessibility configuration
    func provideVisualFeedback(for view: UIView, type: VisualFeedbackType) {
        guard motorAccessibilityConfiguration.enableVisualFeedback else { return }
        
        switch type {
        case .highlight:
            highlightView(view)
        case .flash:
            flashView(view)
        case .pulse:
            pulseView(view)
        case .shake:
            shakeView(view)
        }
    }
    
    enum VisualFeedbackType {
        case highlight
        case flash
        case pulse
        case shake
    }
    
    private func highlightView(_ view: UIView) {
        UIView.animate(withDuration: 0.2) {
            view.backgroundColor = UIColor.systemYellow.withAlphaComponent(0.3)
        } completion: { _ in
            UIView.animate(withDuration: 0.2) {
                view.backgroundColor = UIColor.clear
            }
        }
    }
    
    private func flashView(_ view: UIView) {
        UIView.animate(withDuration: 0.1, animations: {
            view.alpha = 0.5
        }) { _ in
            UIView.animate(withDuration: 0.1) {
                view.alpha = 1.0
            }
        }
    }
    
    private func pulseView(_ view: UIView) {
        UIView.animate(withDuration: 0.2, animations: {
            view.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
        }) { _ in
            UIView.animate(withDuration: 0.2) {
                view.transform = .identity
            }
        }
    }
    
    private func shakeView(_ view: UIView) {
        let animation = CAKeyframeAnimation(keyPath: "transform.translation.x")
        animation.timingFunction = CAMediaTimingFunction(name: .linear)
        animation.duration = 0.6
        animation.values = [-20.0, 20.0, -20.0, 20.0, -10.0, 10.0, -5.0, 5.0, 0.0]
        view.layer.add(animation, forKey: "shake")
    }
    
    // MARK: - Haptic Feedback
    
    /// Provides haptic feedback for an action based on motor accessibility configuration
    func provideHapticFeedback(type: HapticFeedbackType) {
        guard motorAccessibilityConfiguration.enableHapticFeedback else { return }
        
        switch type {
        case .light:
            EnhancedHapticFeedbackSystem.shared.playHaptic(
                pattern: .lightTap,
                intensity: .light,
                sharpness: .medium
            )
        case .medium:
            EnhancedHapticFeedbackSystem.shared.playHaptic(
                pattern: .mediumTap,
                intensity: .medium,
                sharpness: .medium
            )
        case .heavy:
            EnhancedHapticFeedbackSystem.shared.playHaptic(
                pattern: .heavyTap,
                intensity: .strong,
                sharpness: .medium
            )
        case .success:
            EnhancedHapticFeedbackSystem.shared.success()
        case .error:
            EnhancedHapticFeedbackSystem.shared.error()
        case .warning:
            EnhancedHapticFeedbackSystem.shared.warning()
        }
    }
    
    enum HapticFeedbackType {
        case light
        case medium
        case heavy
        case success
        case error
        case warning
    }
    
    // MARK: - Voice Control Support
    
    /// Sets up voice control commands for the app
    func setupVoiceControlCommands() {
        guard motorAccessibilityConfiguration.enableVoiceControlSupport else { return }
        
        // Register voice control commands
        // This would typically involve using the UIAccessibilityCustomAction API
        NotificationCenter.default.post(name: .motorAccessibilityShouldSetupVoiceControlCommands, object: nil)
    }
    
    // MARK: - Switch Control Support
    
    /// Sets up switch control scanning for the app
    func setupSwitchControlScanning() {
        guard motorAccessibilityConfiguration.enableSwitchControlSupport else { return }
        
        // Set up switch control scanning
        // This would typically involve setting the accessibility elements and scan order
        NotificationCenter.default.post(name: .motorAccessibilityShouldSetupSwitchControlScanning, object: nil)
    }
    
    // MARK: - AssistiveTouch Support
    
    /// Sets up AssistiveTouch custom actions for the app
    func setupAssistiveTouchCustomActions() {
        guard motorAccessibilityConfiguration.enableAssistiveTouchSupport else { return }
        
        // Set up AssistiveTouch custom actions
        // This would typically involve registering custom actions with the system
        NotificationCenter.default.post(name: .motorAccessibilityShouldSetupAssistiveTouchCustomActions, object: nil)
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let motorAccessibilityShouldApplySwitchControlConfiguration = Notification.Name("motorAccessibilityShouldApplySwitchControlConfiguration")
    static let motorAccessibilityShouldApplyAssistiveTouchConfiguration = Notification.Name("motorAccessibilityShouldApplyAssistiveTouchConfiguration")
    static let motorAccessibilityShouldApplyReducedMotionConfiguration = Notification.Name("motorAccessibilityShouldApplyReducedMotionConfiguration")
    static let motorAccessibilityShouldApplyTouchAccommodations = Notification.Name("motorAccessibilityShouldApplyTouchAccommodations")
    static let motorAccessibilityShouldApplyAlternateControlMethods = Notification.Name("motorAccessibilityShouldApplyAlternateControlMethods")
    static let motorAccessibilityShouldSetupVoiceControlCommands = Notification.Name("motorAccessibilityShouldSetupVoiceControlCommands")
    static let motorAccessibilityShouldSetupSwitchControlScanning = Notification.Name("motorAccessibilityShouldSetupSwitchControlScanning")
    static let motorAccessibilityShouldSetupAssistiveTouchCustomActions = Notification.Name("motorAccessibilityShouldSetupAssistiveTouchCustomActions")
}

// MARK: - UIView Extensions for Motor Accessibility

extension UIView {
    
    /// Applies motor accessibility accommodations to the view
    func applyMotorAccessibilityAccommodations() {
        // Adjust touch target size
        MotorAccessibilityFeatures.shared.adjustTouchTargetSize(for: self)
        
        // Add visual feedback for touch events
        addTouchFeedback()
        
        // Add haptic feedback for touch events
        addHapticFeedback()
    }
    
    private func addTouchFeedback() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTouchFeedback))
        addGestureRecognizer(tapGesture)
    }
    
    @objc private func handleTouchFeedback() {
        MotorAccessibilityFeatures.shared.provideVisualFeedback(for: self, type: .flash)
    }
    
    private func addMotorHapticFeedback() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleHapticFeedback))
        addGestureRecognizer(tapGesture)
    }
    
    @objc private func handleHapticFeedback() {
        MotorAccessibilityFeatures.shared.provideHapticFeedback(type: .light)
    }
    
    /// Creates an accessible button with motor accessibility accommodations
    static func createAccessibleMotorAccessibilityButton(
        title: String,
        target: Any?,
        selector: Selector
    ) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.accessibilityLabel = title
        button.addTarget(target, action: selector, for: .touchUpInside)
        
        // Apply motor accessibility accommodations
        button.applyMotorAccessibilityAccommodations()
        
        return button
    }
    
    /// Creates an accessible slider with motor accessibility accommodations
    static func createAccessibleMotorAccessibilitySlider(
        minimumValue: Float,
        maximumValue: Float,
        value: Float,
        target: Any?,
        selector: Selector
    ) -> UISlider {
        let slider = UISlider()
        slider.minimumValue = minimumValue
        slider.maximumValue = maximumValue
        slider.value = value
        slider.addTarget(target, action: selector, for: .valueChanged)
        
        // Apply motor accessibility accommodations
        slider.applyMotorAccessibilityAccommodations()
        
        return slider
    }
    
    /// Creates an accessible switch with motor accessibility accommodations
    static func createAccessibleMotorAccessibilitySwitch(
        isOn: Bool,
        target: Any?,
        selector: Selector
    ) -> UISwitch {
        let switchControl = UISwitch()
        switchControl.isOn = isOn
        switchControl.addTarget(target, action: selector, for: .valueChanged)
        
        // Apply motor accessibility accommodations
        switchControl.applyMotorAccessibilityAccommodations()
        
        return switchControl
    }
}