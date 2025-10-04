//
//  AccessibilitySystem.swift
//  DualApp
//
//  Created by DualApp Team on 10/3/25.
//

import SwiftUI
import Foundation

// MARK: - Accessibility System

struct AccessibilitySystem {
    
    // MARK: - Accessibility Categories
    
    struct Categories {
        static let button = "button"
        static let header = "header"
        static let navigation = "navigation"
        static let search = "search"
        static let main = "main"
        static let contentinfo = "contentinfo"
        static let region = "region"
        static let form = "form"
        static let landmark = "landmark"
        static let list = "list"
        static let listitem = "listitem"
        static let none = "none"
    }
    
    // MARK: - Accessibility Traits
    
    struct Traits {
        static let button = AccessibilityTraits.button
        static let link = AccessibilityTraits.link
        static let header = AccessibilityTraits.header
        static let searchField = AccessibilityTraits.searchField
        static let image = AccessibilityTraits.image
        static let selected = AccessibilityTraits.isSelected
        static let playsSound = AccessibilityTraits.playsSound
        static let keyboardKey = AccessibilityTraits.keyboardKey
        static let staticText = AccessibilityTraits.staticText
        static let summaryElement = AccessibilityTraits.summaryElement
        static let notEnabled = AccessibilityTraits.isDisabled
        static let updatesFrequently = AccessibilityTraits.updatesFrequently
        static let startsMediaSession = AccessibilityTraits.startsMediaSession
        static let adjustable = AccessibilityTraits.isAdjustable
        static let allowsDirectInteraction = AccessibilityTraits.allowsDirectInteraction
        static let causesPageTurn = AccessibilityTraits.causesPageTurn
        static let tabButton = AccessibilityTraits.isTabButton
    }
    
    // MARK: - Accessibility Hints
    
    struct Hints {
        static let doubleTap = "Double tap to activate"
        static let swipeUp = "Swipe up to expand"
        static let swipeDown = "Swipe down to collapse"
        static let swipeLeft = "Swipe left to dismiss"
        static let swipeRight = "Swipe right for more options"
        static let longPress = "Long press for more options"
        static let pinch = "Pinch to zoom"
        static let rotate = "Rotate to adjust"
        static let drag = "Drag to reorder"
        static let adjustable = "Swipe up or down to adjust"
        static let recording = "Recording in progress"
        static let camera = "Camera view"
        static let settings = "Opens settings"
        static let gallery = "Opens photo gallery"
        static let capture = "Capture photo"
        static let record = "Start recording"
        static let stop = "Stop recording"
        static let switchCamera = "Switch camera"
        static let flash = "Toggle flash"
        static let focus = "Adjust focus"
        static let exposure = "Adjust exposure"
        static let zoom = "Adjust zoom"
    }
    
    // MARK: - Accessibility Labels
    
    struct Labels {
        // Camera Controls
        static let recordButton = "Record video"
        static let stopButton = "Stop recording"
        static let captureButton = "Take photo"
        static let switchCameraButton = "Switch camera"
        static let flashButton = "Toggle flash"
        static let settingsButton = "Settings"
        static let galleryButton = "Photo gallery"
        static let closeButton = "Close"
        static let doneButton = "Done"
        static let cancelButton = "Cancel"
        static let saveButton = "Save"
        static let deleteButton = "Delete"
        static let editButton = "Edit"
        static let shareButton = "Share"
        
        // Status Indicators
        static let recordingIndicator = "Recording"
        static let batteryLevel = "Battery level"
        static let memoryUsage = "Memory usage"
        static let thermalState = "Device temperature"
        static let recordingTime = "Recording time"
        static let photoCount = "Photo count"
        static let videoCount = "Video count"
        
        // Settings
        static let videoQuality = "Video quality"
        static let frameRate = "Frame rate"
        static let audioRecording = "Audio recording"
        static let autoFocus = "Auto focus"
        static let gridLines = "Grid lines"
        static let levelIndicator = "Level indicator"
        
        // Navigation
        static let backButton = "Back"
        static let nextButton = "Next"
        static let previousButton = "Previous"
        static let menuButton = "Menu"
        static let tabButton = "Tab"
        
        // Content
        static let photoPreview = "Photo preview"
        static let videoPreview = "Video preview"
        static let thumbnail = "Thumbnail"
        static let title = "Title"
        static let description = "Description"
        static let date = "Date"
        static let duration = "Duration"
        static let size = "Size"
    }
    
    // MARK: - Accessibility Values
    
    struct Values {
        static func percentage(_ value: Double) -> String {
            return String(format: "%.0f percent", value * 100)
        }
        
        static func batteryLevel(_ level: Double) -> String {
            return String(format: "%.0f percent battery", level * 100)
        }
        
        static func memoryUsage(_ usage: Double) -> String {
            return String(format: "%.0f percent memory used", usage * 100)
        }
        
        static func recordingTime(_ time: TimeInterval) -> String {
            let minutes = Int(time) / 60
            let seconds = Int(time) % 60
            return String(format: "%d minutes %d seconds", minutes, seconds)
        }
        
        static func videoQuality(_ quality: VideoQuality) -> String {
            switch quality {
            case .hd720:
                return "HD 720p"
            case .hd1080:
                return "HD 1080p"
            case .uhd4k:
                return "4K Ultra HD"
            }
        }
        
        static func frameRate(_ rate: Int32) -> String {
            return String(format: "%d frames per second", rate)
        }
        
        static func thermalState(_ state: ThermalState) -> String {
            switch state {
            case .nominal:
                return "Normal temperature"
            case .fair:
                return "Warm"
            case .serious:
                return "Hot"
            case .critical:
                return "Critical temperature"
            case .unknown:
                return "Unknown temperature"
            }
        }
    }
}

// MARK: - Accessibility View Modifiers

extension View {
    
    // MARK: - Basic Accessibility
    
    func accessibilityIdentifier(_ identifier: String) -> some View {
        self.accessibilityIdentifier(identifier)
    }
    
    func accessibilityLabel(_ label: String) -> some View {
        self.accessibilityLabel(label)
    }
    
    func accessibilityHint(_ hint: String) -> some View {
        self.accessibilityHint(hint)
    }
    
    func accessibilityValue(_ value: String) -> some View {
        self.accessibilityValue(value)
    }
    
    func accessibilityHidden(_ hidden: Bool) -> some View {
        self.accessibilityHidden(hidden)
    }
    
    // MARK: - Accessibility Traits
    
    func accessibilityAddTraits(_ traits: AccessibilityTraits) -> some View {
        self.accessibilityAddTraits(traits)
    }
    
    func accessibilityRemoveTraits(_ traits: AccessibilityTraits) -> some View {
        self.accessibilityRemoveTraits(traits)
    }
    
    func accessibilityTrait(_ trait: AccessibilityTraits) -> some View {
        self.accessibilityAddTraits(trait)
    }
    
    // MARK: - Accessibility Categories
    
    func accessibilityCategory(_ category: String) -> some View {
        self.accessibilityAddTraits(.isButton)
    }
    
    func accessibilityElement(children: AccessibilityChildBehavior = .combine) -> some View {
        self.accessibilityElement(children: children)
    }
    
    // MARK: - Accessibility Actions
    
    func accessibilityAction(_ action: AccessibilityActionKind = .default, _ handler: @escaping () -> Void) -> some View {
        self.accessibilityAction(action, handler)
    }
    
    func accessibilityAdjustableAction(_ handler: @escaping (AccessibilityAdjustmentDirection) -> Void) -> some View {
        self.accessibilityAdjustableAction(handler)
    }
    
    // MARK: - Accessibility Grouping
    
    func accessibilityGroup() -> some View {
        self.accessibilityElement(children: .combine)
    }
    
    func accessibilityContainer() -> some View {
        self.accessibilityElement(children: .contain)
    }
    
    func accessibilityIgnore() -> some View {
        self.accessibilityHidden(true)
    }
    
    // MARK: - Accessibility for Specific Controls
    
    func accessibilityButton(label: String, hint: String? = nil, action: @escaping () -> Void) -> some View {
        self
            .accessibilityLabel(label)
            .accessibilityHint(hint ?? "")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction(.default, action)
    }
    
    func accessibilityToggle(label: String, hint: String? = nil, isOn: Bool, action: @escaping () -> Void) -> some View {
        self
            .accessibilityLabel(label)
            .accessibilityHint(hint ?? "")
            .accessibilityValue(isOn ? "On" : "Off")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction(.default, action)
    }
    
    func accessibilitySlider(label: String, hint: String? = nil, value: Double, action: @escaping (AccessibilityAdjustmentDirection) -> Void) -> some View {
        self
            .accessibilityLabel(label)
            .accessibilityHint(hint ?? AccessibilitySystem.Hints.adjustable)
            .accessibilityValue(AccessibilitySystem.Values.percentage(value))
            .accessibilityAddTraits(.isAdjustable)
            .accessibilityAdjustableAction(action)
    }
    
    func accessibilityStepper(label: String, hint: String? = nil, value: String, increment: @escaping () -> Void, decrement: @escaping () -> Void) -> some View {
        self
            .accessibilityLabel(label)
            .accessibilityHint(hint ?? "")
            .accessibilityValue(value)
            .accessibilityAddTraits(.isAdjustable)
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment:
                    increment()
                case .decrement:
                    decrement()
                @unknown default:
                    break
                }
            }
    }
    
    // MARK: - Accessibility for Camera Controls
    
    func accessibilityCameraControl(label: String, hint: String? = nil, action: @escaping () -> Void) -> some View {
        self
            .accessibilityLabel(label)
            .accessibilityHint(hint ?? "")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction(.default, action)
    }
    
    func accessibilityRecordingButton(isRecording: Bool, action: @escaping () -> Void) -> some View {
        let label = isRecording ? AccessibilitySystem.Labels.stopButton : AccessibilitySystem.Labels.recordButton
        let hint = isRecording ? AccessibilitySystem.Hints.stop : AccessibilitySystem.Hints.record
        
        return self
            .accessibilityLabel(label)
            .accessibilityHint(hint)
            .accessibilityAddTraits(.isButton)
            .accessibilityAction(.default, action)
    }
    
    func accessibilityCaptureButton(action: @escaping () -> Void) -> some View {
        self
            .accessibilityLabel(AccessibilitySystem.Labels.captureButton)
            .accessibilityHint(AccessibilitySystem.Hints.capture)
            .accessibilityAddTraits(.isButton)
            .accessibilityAction(.default, action)
    }
    
    func accessibilitySwitchCameraButton(action: @escaping () -> Void) -> some View {
        self
            .accessibilityLabel(AccessibilitySystem.Labels.switchCameraButton)
            .accessibilityHint(AccessibilitySystem.Hints.switchCamera)
            .accessibilityAddTraits(.isButton)
            .accessibilityAction(.default, action)
    }
    
    func accessibilityFlashButton(isOn: Bool, action: @escaping () -> Void) -> some View {
        self
            .accessibilityLabel(AccessibilitySystem.Labels.flashButton)
            .accessibilityHint(isOn ? "Flash on" : "Flash off")
            .accessibilityValue(isOn ? "On" : "Off")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction(.default, action)
    }
    
    // MARK: - Accessibility for Status Indicators
    
    func accessibilityBatteryLevel(level: Double) -> some View {
        self
            .accessibilityLabel(AccessibilitySystem.Labels.batteryLevel)
            .accessibilityValue(AccessibilitySystem.Values.batteryLevel(level))
            .accessibilityAddTraits(.updatesFrequently)
    }
    
    func accessibilityMemoryUsage(usage: Double) -> some View {
        self
            .accessibilityLabel(AccessibilitySystem.Labels.memoryUsage)
            .accessibilityValue(AccessibilitySystem.Values.memoryUsage(usage))
            .accessibilityAddTraits(.updatesFrequently)
    }
    
    func accessibilityThermalState(state: ThermalState) -> some View {
        self
            .accessibilityLabel(AccessibilitySystem.Labels.thermalState)
            .accessibilityValue(AccessibilitySystem.Values.thermalState(state))
            .accessibilityAddTraits(.updatesFrequently)
    }
    
    func accessibilityRecordingTime(time: TimeInterval) -> some View {
        self
            .accessibilityLabel(AccessibilitySystem.Labels.recordingTime)
            .accessibilityValue(AccessibilitySystem.Values.recordingTime(time))
            .accessibilityAddTraits(.updatesFrequently)
    }
    
    // MARK: - Accessibility for Settings
    
    func accessibilityVideoQuality(quality: VideoQuality, action: @escaping () -> Void) -> some View {
        self
            .accessibilityLabel(AccessibilitySystem.Labels.videoQuality)
            .accessibilityValue(AccessibilitySystem.Values.videoQuality(quality))
            .accessibilityHint("Tap to change video quality")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction(.default, action)
    }
    
    func accessibilityFrameRate(rate: Int32, action: @escaping () -> Void) -> some View {
        self
            .accessibilityLabel(AccessibilitySystem.Labels.frameRate)
            .accessibilityValue(AccessibilitySystem.Values.frameRate(rate))
            .accessibilityHint("Tap to change frame rate")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction(.default, action)
    }
    
    func accessibilityToggleSetting(label: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        self
            .accessibilityLabel(label)
            .accessibilityValue(isOn ? "On" : "Off")
            .accessibilityHint("Double tap to toggle")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction(.default, action)
    }
    
    // MARK: - Accessibility for Lists and Grids
    
    func accessibilityList() -> some View {
        self.accessibilityAddTraits(.isList)
    }
    
    func accessibilityListItem(label: String, hint: String? = nil) -> some View {
        self
            .accessibilityLabel(label)
            .accessibilityHint(hint ?? "")
            .accessibilityAddTraits(.isButton)
    }
    
    func accessibilityGrid(columns: Int) -> some View {
        self
            .accessibilityLabel("Grid with \(columns) columns")
            .accessibilityAddTraits(.isList)
    }
    
    func accessibilityGridItem(label: String, row: Int, column: Int) -> some View {
        self
            .accessibilityLabel("\(label), row \(row + 1), column \(column + 1)")
            .accessibilityAddTraits(.isButton)
    }
    
    // MARK: - Accessibility for Navigation
    
    func accessibilityBackButton(action: @escaping () -> Void) -> some View {
        self
            .accessibilityLabel(AccessibilitySystem.Labels.backButton)
            .accessibilityHint("Go back")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction(.default, action)
    }
    
    func accessibilityTabButton(label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        self
            .accessibilityLabel(label)
            .accessibilityHint(isSelected ? "Selected tab" : "Tab")
            .accessibilityAddTraits([.isButton, .isTabButton])
            .accessibilityValue(isSelected ? "Selected" : "Not selected")
            .accessibilityAction(.default, action)
    }
    
    // MARK: - Accessibility for Media
    
    func accessibilityImage(label: String, decorative: Bool = false) -> some View {
        if decorative {
            return self.accessibilityHidden(true)
        } else {
            return self.accessibilityLabel(label).accessibilityAddTraits(.isImage)
        }
    }
    
    func accessibilityVideo(label: String, duration: TimeInterval? = nil) -> some View {
        var view = self.accessibilityLabel(label).accessibilityAddTraits(.playsSound)
        
        if let duration = duration {
            view = view.accessibilityValue(AccessibilitySystem.Values.recordingTime(duration))
        }
        
        return view
    }
    
    func accessibilityAudio(label: String, duration: TimeInterval? = nil) -> some View {
        var view = self.accessibilityLabel(label).accessibilityAddTraits(.playsSound)
        
        if let duration = duration {
            view = view.accessibilityValue(AccessibilitySystem.Values.recordingTime(duration))
        }
        
        return view
    }
    
    // MARK: - Accessibility for Progress and Loading
    
    func accessibilityProgress(value: Double, total: Double = 1.0, label: String = "Progress") -> some View {
        self
            .accessibilityLabel(label)
            .accessibilityValue(String(format: "%.0f percent complete", (value / total) * 100))
            .accessibilityAddTraits(.updatesFrequently)
    }
    
    func accessibilityLoading(label: String = "Loading") -> some View {
        self
            .accessibilityLabel(label)
            .accessibilityHint("Please wait")
            .accessibilityAddTraits(.updatesFrequently)
    }
    
    // MARK: - Accessibility for Alerts and Notifications
    
    func accessibilityAlert(label: String, message: String) -> some View {
        self
            .accessibilityLabel(label)
            .accessibilityValue(message)
            .accessibilityAddTraits(.isModal)
    }
    
    func accessibilityNotification(label: String, message: String) -> some View {
        self
            .accessibilityLabel(label)
            .accessibilityValue(message)
            .accessibilityAddTraits(.isSummaryElement)
    }
    
    // MARK: - Accessibility for Forms
    
    func accessibilityFormField(label: String, value: String, hint: String? = nil) -> some View {
        var view = self
            .accessibilityLabel(label)
            .accessibilityValue(value)
        
        if let hint = hint {
            view = view.accessibilityHint(hint)
        }
        
        return view
    }
    
    func accessibilityTextField(label: String, placeholder: String? = nil, value: String = "") -> some View {
        var view = self
            .accessibilityLabel(label)
            .accessibilityValue(value)
        
        if let placeholder = placeholder {
            view = view.accessibilityHint(placeholder)
        }
        
        return view
    }
    
    // MARK: - Accessibility for Custom Components
    
    func accessibilityCustomAction(label: String, action: @escaping () -> Void) -> some View {
        self.accessibilityAction(.custom(label), action)
    }
    
    func accessibilityCustomRotor(label: String, action: @escaping () -> Void) -> some View {
        self.accessibilityAction(.custom(label), action)
    }
    
    // MARK: - Accessibility for Dynamic Content
    
    func accessibilityLiveRegion(_ region: AccessibilityLiveRegion) -> some View {
        // Note: SwiftUI doesn't have direct live region support
        // This would need to be implemented with notifications
        return self
    }
    
    func accessibilityAnnouncement(_ message: String) -> some View {
        self.onAppear {
            UIAccessibility.post(notification: .announcement, argument: message)
        }
    }
    
    func accessibilityScreenChanged() -> some View {
        self.onAppear {
            UIAccessibility.post(notification: .screenChanged, argument: self)
        }
    }
    
    func accessibilityLayoutChanged(to element: Any?) -> some View {
        self.onAppear {
            UIAccessibility.post(notification: .layoutChanged, argument: element)
        }
    }
}

// MARK: - Accessibility Helpers

struct AccessibilityHelper {
    
    // MARK: - VoiceOver Detection
    
    static var isVoiceOverRunning: Bool {
        return UIAccessibility.isVoiceOverRunning
    }
    
    static var isSwitchControlRunning: Bool {
        return UIAccessibility.isSwitchControlRunning
    }
    
    static var isReduceMotionEnabled: Bool {
        return UIAccessibility.isReduceMotionEnabled
    }
    
    static var isReduceTransparencyEnabled: Bool {
        return UIAccessibility.isReduceTransparencyEnabled
    }
    
    static var isInvertColorsEnabled: Bool {
        return UIAccessibility.isInvertColorsEnabled
    }
    
    static var isDarkerSystemColorsEnabled: Bool {
        return UIAccessibility.isDarkerSystemColorsEnabled
    }
    
    static var isHighContrastEnabled: Bool {
        return UIAccessibility.isHighContrastEnabled
    }
    
    // MARK: - Accessibility Notifications
    
    static func postAnnouncement(_ message: String) {
        UIAccessibility.post(notification: .announcement, argument: message)
    }
    
    static func postLayoutChanged(_ element: Any?) {
        UIAccessibility.post(notification: .layoutChanged, argument: element)
    }
    
    static func postScreenChanged(_ element: Any?) {
        UIAccessibility.post(notification: .screenChanged, argument: element)
    }
    
    static func postScrollStatusChanged(_ element: Any?) {
        UIAccessibility.post(notification: .scrollStatusChanged, argument: element)
    }
    
    // MARK: - Accessibility Focus
    
    static func requestFocus(_ element: Any?) {
        UIAccessibility.post(notification: .layoutChanged, argument: element)
    }
    
    static func moveFocusToNextElement() {
        UIAccessibility.post(notification: .screenChanged, argument: nil)
    }
    
    // MARK: - Accessibility Utilities
    
    static func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) % 3600 / 60
        let seconds = Int(duration) % 60
        
        if hours > 0 {
            return String(format: "%d hours %d minutes %d seconds", hours, minutes, seconds)
        } else if minutes > 0 {
            return String(format: "%d minutes %d seconds", minutes, seconds)
        } else {
            return String(format: "%d seconds", seconds)
        }
    }
    
    static func formatFileSize(_ size: Int64) -> String {
        let byteCountFormatter = ByteCountFormatter()
        byteCountFormatter.allowedUnits = [.useKB, .useMB, .useGB, .useTB]
        byteCountFormatter.countStyle = .file
        return byteCountFormatter.string(fromByteCount: size)
    }
    
    static func formatPercentage(_ value: Double) -> String {
        return String(format: "%.0f percent", value * 100)
    }
    
    static func formatRatio(_ numerator: Double, denominator: Double) -> String {
        return String(format: "%.0f out of %.0f", numerator, denominator)
    }
}

// MARK: - Accessibility Preferences

struct AccessibilityPreferences {
    
    // MARK: - User Preferences
    
    @AppStorage("accessibility.reduceMotion") static var reduceMotion: Bool = false
    @AppStorage("accessibility.highContrast") static var highContrast: Bool = false
    @AppStorage("accessibility.largeText") static var largeText: Bool = false
    @AppStorage("accessibility.voiceOver") static var voiceOver: Bool = false
    @AppStorage("accessibility.hapticFeedback") static var hapticFeedback: Bool = true
    @AppStorage("accessibility.audioDescriptions") static var audioDescriptions: Bool = false
    @AppStorage("accessibility.closedCaptions") static var closedCaptions: Bool = false
    
    // MARK: - Preference Detection
    
    static func detectSystemPreferences() {
        reduceMotion = UIAccessibility.isReduceMotionEnabled
        highContrast = UIAccessibility.isHighContrastEnabled
        largeText = UIApplication.shared.preferredContentSizeCategory.isAccessibilityCategory
        voiceOver = UIAccessibility.isVoiceOverRunning
    }
    
    // MARK: - Preference Application
    
    static func applyPreferences() {
        detectSystemPreferences()
        
        // Apply preferences to UI elements
        NotificationCenter.default.post(name: .accessibilityPreferencesChanged, object: nil)
    }
}

// MARK: - Accessibility Notification Extension

extension Notification.Name {
    static let accessibilityPreferencesChanged = Notification.Name("accessibilityPreferencesChanged")
    static let voiceOverStatusChanged = Notification.Name("voiceOverStatusChanged")
    static let reduceMotionStatusChanged = Notification.Name("reduceMotionStatusChanged")
    static let highContrastStatusChanged = Notification.Name("highContrastStatusChanged")
}

// MARK: - Accessibility Testing Helpers

#if DEBUG
struct AccessibilityTestingHelpers {
    
    static func dumpAccessibilityHierarchy() {
        // Debug helper to print accessibility hierarchy
        print("=== Accessibility Hierarchy ===")
        // Implementation would traverse and print the hierarchy
    }
    
    static func highlightAccessibilityElements() {
        // Debug helper to visually highlight accessibility elements
        // Implementation would add visual overlays to accessibility elements
    }
    
    static func validateAccessibilityLabels() -> [String] {
        // Debug helper to validate accessibility labels
        var issues: [String] = []
        
        // Implementation would check for missing or invalid labels
        
        return issues
    }
    
    static func testVoiceOverNavigation() {
        // Debug helper to test VoiceOver navigation
        print("=== VoiceOver Navigation Test ===")
        // Implementation would simulate VoiceOver navigation
    }
}
#endif