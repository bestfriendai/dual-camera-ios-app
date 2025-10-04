//
//  FocusModeIntegration.swift
//  DualCameraApp
//
//  Focus Mode integration system that adapts app behavior based on user's Focus settings
//

import UIKit
import UserNotifications

/// Focus Mode integration system that adapts app behavior based on user's Focus settings
class FocusModeIntegration {
    
    static let shared = FocusModeIntegration()
    
    private init() {}
    
    // MARK: - Properties
    
    private var currentFocusStatus: FocusStatus = .unavailable
    private var focusStatusObservers: [(FocusStatus) -> Void] = []
    private var notificationAuthorizationGranted = false
    
    // MARK: - Focus Status
    
    enum FocusStatus {
        case unavailable
        case available(isActive: Bool, name: String?)
        case restricted
    }
    
    // MARK: - Focus Configuration
    
    struct FocusConfiguration {
        var respectFocusMode: Bool = true
        var allowNotificationsInFocus: Bool = false
        var allowSoundsInFocus: Bool = false
        var allowHapticsInFocus: Bool = false
        var autoHideControlsInFocus: Bool = true
        var reduceVisualEffectsInFocus: Bool = true
        var enableMinimalModeInFocus: Bool = true
        var customFocusBehaviors: [String: Any] = [:]
    }
    
    private var focusConfiguration = FocusConfiguration()
    
    // MARK: - Initialization
    
    /// Initializes the Focus Mode integration system
    func initialize() {
        requestNotificationAuthorization()
        setupFocusStatusObserver()
        updateCurrentFocusStatus()
    }
    
    // MARK: - Notification Authorization
    
    private func requestNotificationAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { [weak self] granted, error in
            DispatchQueue.main.async {
                self?.notificationAuthorizationGranted = granted
                if let error = error {
                    print("Error requesting notification authorization: \(error)")
                }
            }
        }
    }
    
    // MARK: - Focus Status Observation
    
    private func setupFocusStatusObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleExternalFocusStatusChange(_:)),
            name: .focusModeStatusDidChange,
            object: nil
        )
    }
    
    @objc private func handleExternalFocusStatusChange(_ notification: Notification) {
        let isActive = notification.userInfo?["isActive"] as? Bool ?? false
        let name = notification.userInfo?["name"] as? String
        updateFocusStatus(isActive: isActive, name: name)
    }
    
    private func updateCurrentFocusStatus() {
        currentFocusStatus = .unavailable
        notifyFocusStatusObservers()
        applyFocusConfiguration()
    }

    func updateFocusStatus(isActive: Bool, name: String? = nil) {
        currentFocusStatus = .available(isActive: isActive, name: name)
        notifyFocusStatusObservers()
        applyFocusConfiguration()
    }

    func setFocusStatusRestricted() {
        currentFocusStatus = .restricted
        notifyFocusStatusObservers()
        applyFocusConfiguration()
    }

    func setFocusStatusUnavailable() {
        currentFocusStatus = .unavailable
        notifyFocusStatusObservers()
        applyFocusConfiguration()
    }
    
    private func notifyFocusStatusObservers() {
        focusStatusObservers.forEach { observer in
            observer(currentFocusStatus)
        }
    }
    
    // MARK: - Public Methods
    
    /// Adds an observer for focus status changes
    func addFocusStatusObserver(_ observer: @escaping (FocusStatus) -> Void) {
        focusStatusObservers.append(observer)
        observer(currentFocusStatus)
    }
    
    /// Removes an observer for focus status changes
    func removeFocusStatusObserver(_ observer: @escaping (FocusStatus) -> Void) {
        focusStatusObservers.removeAll { storedObserver in
            // This is a simple comparison that works for this use case
            return String(describing: storedObserver) == String(describing: observer)
        }
    }
    
    /// Gets the current focus status
    func getCurrentFocusStatus() -> FocusStatus {
        return currentFocusStatus
    }
    
    /// Checks if Focus Mode is currently active
    func isFocusModeActive() -> Bool {
        switch currentFocusStatus {
        case .available(let isActive, _):
            return isActive
        default:
            return false
        }
    }
    
    /// Gets the name of the currently active Focus Mode
    func getActiveFocusModeName() -> String? {
        switch currentFocusStatus {
        case .available(_, let name):
            return name
        default:
            return nil
        }
    }
    
    /// Updates the focus configuration
    func updateFocusConfiguration(_ configuration: FocusConfiguration) {
        focusConfiguration = configuration
        applyFocusConfiguration()
    }
    
    /// Gets the current focus configuration
    func getFocusConfiguration() -> FocusConfiguration {
        return focusConfiguration
    }
    
    // MARK: - Focus Configuration Application
    
    private func applyFocusConfiguration() {
        guard focusConfiguration.respectFocusMode else { return }
        
        switch currentFocusStatus {
        case .available(let isActive, _):
            if isActive {
                applyActiveFocusConfiguration()
            } else {
                applyInactiveFocusConfiguration()
            }
        default:
            break
        }
    }
    
    private func applyActiveFocusConfiguration() {
        // Apply configuration for when Focus Mode is active
        
        // Disable notifications if configured
        if !focusConfiguration.allowNotificationsInFocus {
            disableNotifications()
        }
        
        // Disable sounds if configured
        if !focusConfiguration.allowSoundsInFocus {
            disableSounds()
        }
        
        // Disable haptics if configured
        if !focusConfiguration.allowHapticsInFocus {
            disableHaptics()
        }
        
        // Auto-hide controls if configured
        if focusConfiguration.autoHideControlsInFocus {
            hideControls()
        }
        
        // Reduce visual effects if configured
        if focusConfiguration.reduceVisualEffectsInFocus {
            reduceVisualEffects()
        }
        
        // Enable minimal mode if configured
        if focusConfiguration.enableMinimalModeInFocus {
            enableMinimalMode()
        }
        
        // Apply custom focus behaviors
        applyCustomFocusBehaviors()
    }
    
    private func applyInactiveFocusConfiguration() {
        // Apply configuration for when Focus Mode is not active
        
        // Re-enable notifications
        enableNotifications()
        
        // Re-enable sounds
        enableSounds()
        
        // Re-enable haptics
        enableHaptics()
        
        // Show controls
        showControls()
        
        // Restore visual effects
        restoreVisualEffects()
        
        // Disable minimal mode
        disableMinimalMode()
    }
    
    // MARK: - Configuration Application Methods
    
    private func disableNotifications() {
        // Disable notifications
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
    
    private func enableNotifications() {
        // Re-enable notifications
        // This would typically involve re-registering any pending notifications
    }
    
    private func disableSounds() {
        // Disable sounds
        // This would typically involve setting a global flag that sound-producing methods check
    }
    
    private func enableSounds() {
        // Re-enable sounds
        // This would typically involve unsetting the global flag
    }
    
    private func disableHaptics() {
        // Disable haptics
        EnhancedHapticFeedbackSystem.shared.stopHapticEngine()
    }
    
    private func enableHaptics() {
        // Re-enable haptics
        EnhancedHapticFeedbackSystem.shared.prepareHapticEngine()
    }
    
    private func hideControls() {
        // Hide controls
        // This would typically involve posting a notification that UI components observe
        NotificationCenter.default.post(name: .focusModeShouldHideControls, object: nil)
    }
    
    private func showControls() {
        // Show controls
        // This would typically involve posting a notification that UI components observe
        NotificationCenter.default.post(name: .focusModeShouldShowControls, object: nil)
    }
    
    private func reduceVisualEffects() {
        // Reduce visual effects
        // This would typically involve posting a notification that UI components observe
        NotificationCenter.default.post(name: .focusModeShouldReduceVisualEffects, object: nil)
    }
    
    private func restoreVisualEffects() {
        // Restore visual effects
        // This would typically involve posting a notification that UI components observe
        NotificationCenter.default.post(name: .focusModeShouldRestoreVisualEffects, object: nil)
    }
    
    private func enableMinimalMode() {
        // Enable minimal mode
        // This would typically involve posting a notification that UI components observe
        NotificationCenter.default.post(name: .focusModeShouldEnableMinimalMode, object: nil)
    }
    
    private func disableMinimalMode() {
        // Disable minimal mode
        // This would typically involve posting a notification that UI components observe
        NotificationCenter.default.post(name: .focusModeShouldDisableMinimalMode, object: nil)
    }
    
    private func applyCustomFocusBehaviors() {
        // Apply custom focus behaviors
        // This would typically involve iterating through the custom behaviors and applying them
        for (key, value) in focusConfiguration.customFocusBehaviors {
            // Apply custom behavior based on key and value
            NotificationCenter.default.post(
                name: .focusModeCustomBehavior,
                object: nil,
                userInfo: [key: value]
            )
        }
    }
    
    // MARK: - Focus-Aware Notifications
    
    /// Posts a notification if allowed by the current Focus Mode configuration
    func postFocusAwareNotification(
        id: String,
        title: String,
        body: String,
        userInfo: [AnyHashable: Any]? = nil
    ) {
        guard focusConfiguration.respectFocusMode else {
            postNotification(id: id, title: title, body: body, userInfo: userInfo)
            return
        }
        
        switch currentFocusStatus {
        case .available(let isActive, _):
            if isActive && !focusConfiguration.allowNotificationsInFocus {
                // Don't post notification while in Focus Mode
                return
            }
        default:
            break
        }
        
        postNotification(id: id, title: title, body: body, userInfo: userInfo)
    }
    
    private func postNotification(
        id: String,
        title: String,
        body: String,
        userInfo: [AnyHashable: Any]?
    ) {
        guard notificationAuthorizationGranted else { return }
        
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = nil // We'll handle sounds separately
        
        if let userInfo = userInfo {
            content.userInfo = userInfo
        }
        
        let request = UNNotificationRequest(
            identifier: id,
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error posting notification: \(error)")
            }
        }
    }
    
    // MARK: - Focus-Aware Sounds
    
    /// Plays a sound if allowed by the current Focus Mode configuration
    func playFocusAwareSound(_ soundName: String) {
        guard focusConfiguration.respectFocusMode else {
            playSound(soundName)
            return
        }
        
        switch currentFocusStatus {
        case .available(let isActive, _):
            if isActive && !focusConfiguration.allowSoundsInFocus {
                // Don't play sound while in Focus Mode
                return
            }
        default:
            break
        }
        
        playSound(soundName)
    }
    
    private func playSound(_ soundName: String) {
        // Play the sound
        // This would typically involve using AudioServicesPlaySystemSound or AVAudioPlayer
    }
    
    // MARK: - Focus-Aware Haptics
    
    /// Plays haptic feedback if allowed by the current Focus Mode configuration
    func playFocusAwareHaptic(
        pattern: EnhancedHapticFeedbackSystem.HapticPattern,
        intensity: EnhancedHapticFeedbackSystem.HapticIntensity = .medium,
        sharpness: EnhancedHapticFeedbackSystem.HapticSharpness = .medium
    ) {
        guard focusConfiguration.respectFocusMode else {
            EnhancedHapticFeedbackSystem.shared.playHaptic(
                pattern: pattern,
                intensity: intensity,
                sharpness: sharpness
            )
            return
        }
        
        switch currentFocusStatus {
        case .available(let isActive, _):
            if isActive && !focusConfiguration.allowHapticsInFocus {
                // Don't play haptic while in Focus Mode
                return
            }
        default:
            break
        }
        
        EnhancedHapticFeedbackSystem.shared.playHaptic(
            pattern: pattern,
            intensity: intensity,
            sharpness: sharpness
        )
    }
    
    // MARK: - Focus-Aware UI Updates
    
    /// Determines if UI should be updated based on the current Focus Mode configuration
    func shouldUpdateUI() -> Bool {
        guard focusConfiguration.respectFocusMode else { return true }
        
        switch currentFocusStatus {
        case .available(let isActive, _):
            if isActive && focusConfiguration.enableMinimalModeInFocus {
                // Limit UI updates while in Focus Mode with minimal mode enabled
                return false
            }
        default:
            break
        }
        
        return true
    }
    
    /// Determines if visual effects should be applied based on the current Focus Mode configuration
    func shouldApplyVisualEffects() -> Bool {
        guard focusConfiguration.respectFocusMode else { return true }
        
        switch currentFocusStatus {
        case .available(let isActive, _):
            if isActive && focusConfiguration.reduceVisualEffectsInFocus {
                // Don't apply visual effects while in Focus Mode with visual effects reduction enabled
                return false
            }
        default:
            break
        }
        
        return true
    }
    
    /// Determines if controls should be shown based on the current Focus Mode configuration
    func shouldShowControls() -> Bool {
        guard focusConfiguration.respectFocusMode else { return true }
        
        switch currentFocusStatus {
        case .available(let isActive, _):
            if isActive && focusConfiguration.autoHideControlsInFocus {
                // Don't show controls while in Focus Mode with auto-hide enabled
                return false
            }
        default:
            break
        }
        
        return true
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let focusModeStatusDidChange = Notification.Name("focusModeStatusDidChange")

    static let focusModeShouldHideControls = Notification.Name("focusModeShouldHideControls")
    static let focusModeShouldShowControls = Notification.Name("focusModeShouldShowControls")
    static let focusModeShouldReduceVisualEffects = Notification.Name("focusModeShouldReduceVisualEffects")
    static let focusModeShouldRestoreVisualEffects = Notification.Name("focusModeShouldRestoreVisualEffects")
    static let focusModeShouldEnableMinimalMode = Notification.Name("focusModeShouldEnableMinimalMode")
    static let focusModeShouldDisableMinimalMode = Notification.Name("focusModeShouldDisableMinimalMode")
    static let focusModeCustomBehavior = Notification.Name("focusModeCustomBehavior")
}

// MARK: - Focus Mode Integration Extensions

extension FocusModeIntegration {
    
    /// Creates a focus-aware notification content
    func createFocusAwareNotificationContent(
        title: String,
        body: String,
        categoryIdentifier: String? = nil
    ) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        
        if let categoryIdentifier = categoryIdentifier {
            content.categoryIdentifier = categoryIdentifier
        }
        
        // Add focus-aware information to the notification
        switch currentFocusStatus {
        case .available(let isActive, let name):
            content.userInfo["focusModeActive"] = isActive
            if let name = name {
                content.userInfo["focusModeName"] = name
            }
        default:
            content.userInfo["focusModeActive"] = false
        }
        
        return content
    }
    
    /// Creates a focus-aware notification category
    func createFocusAwareNotificationCategory(
        identifier: String,
        actions: [UNNotificationAction] = [],
        intentIdentifiers: [String] = []
    ) -> UNNotificationCategory {
        let category = UNNotificationCategory(
            identifier: identifier,
            actions: actions,
            intentIdentifiers: intentIdentifiers,
            options: []
        )
        
        return category
    }
    
    /// Registers focus-aware notification categories
    func registerFocusAwareNotificationCategories() {
        let categories = [
            createFocusAwareNotificationCategory(
                identifier: "RECORDING_COMPLETE",
                actions: [
                    UNNotificationAction(
                        identifier: "VIEW_RECORDING",
                        title: "View Recording",
                        options: []
                    )
                ]
            ),
            createFocusAwareNotificationCategory(
                identifier: "PROCESSING_COMPLETE",
                actions: [
                    UNNotificationAction(
                        identifier: "VIEW_VIDEO",
                        title: "View Video",
                        options: []
                    )
                ]
            )
        ]
        
        UNUserNotificationCenter.current().setNotificationCategories(
            Set(categories)
        )
    }
}