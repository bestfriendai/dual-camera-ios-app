//
//  GestureShortcutManager.swift
//  DualCameraApp
//
//  Gesture-based shortcuts system for common actions with modern iOS 18+ interactions
//

import UIKit

/// Gesture-based shortcuts manager for common camera actions
class GestureShortcutManager {
    
    static let shared = GestureShortcutManager()
    
    private init() {}
    
    // MARK: - Gesture Types
    
    enum GestureShortcut: String, CaseIterable {
        case doubleTap
        case tripleTap
        case longPress
        case swipeUp
        case swipeDown
        case swipeLeft
        case swipeRight
        case pinchIn
        case pinchOut
        case twoFingerTap
        case twoFingerDoubleTap
        case twoFingerLongPress
        case twoFingerSwipeUp
        case twoFingerSwipeDown
        case twoFingerSwipeLeft
        case twoFingerSwipeRight
        case twoFingerPinchIn
        case twoFingerPinchOut
        case threeFingerTap
        case threeFingerSwipeLeft
        case threeFingerSwipeRight
        case edgePanLeft
        case edgePanRight
        case edgePanTop
        case edgePanBottom
    }
    
    // MARK: - Action Types
    
    enum ShortcutAction {
        // Recording actions
        case startRecording
        case stopRecording
        case pauseRecording
        case resumeRecording
        case capturePhoto
        
        // Camera controls
        case toggleFlash
        case switchCamera
        case toggleFocusMode
        case resetFocus
        case toggleZoom
        case resetZoom
        
        // Mode changes
        case switchToPhotoMode
        case switchToVideoMode
        case switchToSlowMotionMode
        case switchToTimeLapseMode
        
        // UI actions
        case showSettings
        case hideControls
        case showControls
        case toggleGrid
        case toggleTimer
        
        // Advanced actions
        case takeBurstPhoto
        case startTimedRecording
        case takeHDRPhoto
        case toggleNightMode
        case togglePortraitMode
    }
    
    // MARK: - Properties
    
    private var gestureMappings: [GestureShortcut: ShortcutAction] = [:]
    private var gestureRecognizers: [UIGestureRecognizer] = []
    private weak var targetView: UIView?
    
    // Callbacks
    var onShortcutAction: ((ShortcutAction) -> Void)?
    
    // Visual feedback
    private let feedbackOverlay = UIView()
    private let feedbackLabel = UILabel()
    
    // MARK: - Setup
    
    /// Sets up gesture shortcuts on the target view
    func setupGestureShortcuts(on view: UIView) {
        targetView = view
        
        // Clear existing gesture recognizers
        clearGestureRecognizers()
        
        // Set up default gesture mappings
        setupDefaultGestureMappings()
        
        // Create and add gesture recognizers based on mappings
        createGestureRecognizers()
        
        // Setup visual feedback overlay
        setupFeedbackOverlay()
    }
    
    private func setupDefaultGestureMappings() {
        // Single finger gestures
        gestureMappings[.doubleTap] = .capturePhoto
        gestureMappings[.tripleTap] = .switchCamera
        gestureMappings[.longPress] = .startRecording
        gestureMappings[.swipeUp] = .showControls
        gestureMappings[.swipeDown] = .hideControls
        gestureMappings[.swipeLeft] = .switchToPhotoMode
        gestureMappings[.swipeRight] = .switchToVideoMode
        gestureMappings[.pinchIn] = .toggleZoom
        gestureMappings[.pinchOut] = .toggleZoom
        
        // Two finger gestures
        gestureMappings[.twoFingerTap] = .toggleFlash
        gestureMappings[.twoFingerDoubleTap] = .toggleFocusMode
        gestureMappings[.twoFingerLongPress] = .takeBurstPhoto
        gestureMappings[.twoFingerSwipeUp] = .showSettings
        gestureMappings[.twoFingerSwipeDown] = .toggleGrid
        gestureMappings[.twoFingerSwipeLeft] = .switchToSlowMotionMode
        gestureMappings[.twoFingerSwipeRight] = .switchToTimeLapseMode
        gestureMappings[.twoFingerPinchIn] = .resetZoom
        gestureMappings[.twoFingerPinchOut] = .resetFocus
        
        // Three finger gestures
        gestureMappings[.threeFingerTap] = .toggleNightMode
        gestureMappings[.threeFingerSwipeLeft] = .toggleTimer
        gestureMappings[.threeFingerSwipeRight] = .togglePortraitMode
        
        // Edge pan gestures
        gestureMappings[.edgePanLeft] = .switchCamera
        gestureMappings[.edgePanRight] = .switchCamera
        gestureMappings[.edgePanTop] = .showSettings
        gestureMappings[.edgePanBottom] = .showControls
    }
    
    private func createGestureRecognizers() {
        guard let view = targetView else { return }
        
        // Single finger gestures
        createTapGesture(.doubleTap, numberOfTaps: 2, numberOfTouches: 1, on: view)
        createTapGesture(.tripleTap, numberOfTaps: 3, numberOfTouches: 1, on: view)
        createLongPressGesture(.longPress, on: view)
        createSwipeGesture(.swipeUp, direction: .up, on: view)
        createSwipeGesture(.swipeDown, direction: .down, on: view)
        createSwipeGesture(.swipeLeft, direction: .left, on: view)
        createSwipeGesture(.swipeRight, direction: .right, on: view)
        createPinchGesture(.pinchIn, on: view)
        createPinchGesture(.pinchOut, on: view)
        
        // Two finger gestures
        createTapGesture(.twoFingerTap, numberOfTaps: 1, numberOfTouches: 2, on: view)
        createTapGesture(.twoFingerDoubleTap, numberOfTaps: 2, numberOfTouches: 2, on: view)
        createLongPressGesture(.twoFingerLongPress, numberOfTouches: 2, on: view)
        createSwipeGesture(.twoFingerSwipeUp, direction: .up, numberOfTouches: 2, on: view)
        createSwipeGesture(.twoFingerSwipeDown, direction: .down, numberOfTouches: 2, on: view)
        createSwipeGesture(.twoFingerSwipeLeft, direction: .left, numberOfTouches: 2, on: view)
        createSwipeGesture(.twoFingerSwipeRight, direction: .right, numberOfTouches: 2, on: view)
        createPinchGesture(.twoFingerPinchIn, numberOfTouches: 2, on: view)
        createPinchGesture(.twoFingerPinchOut, numberOfTouches: 2, on: view)
        
        // Three finger gestures
        createTapGesture(.threeFingerTap, numberOfTaps: 1, numberOfTouches: 3, on: view)
        createSwipeGesture(.threeFingerSwipeLeft, direction: .left, numberOfTouches: 3, on: view)
        createSwipeGesture(.threeFingerSwipeRight, direction: .right, numberOfTouches: 3, on: view)
        
        // Edge pan gestures
        createEdgePanGesture(.edgePanLeft, edge: .left, on: view)
        createEdgePanGesture(.edgePanRight, edge: .right, on: view)
        createEdgePanGesture(.edgePanTop, edge: .top, on: view)
        createEdgePanGesture(.edgePanBottom, edge: .bottom, on: view)
    }
    
    private func createTapGesture(_ shortcut: GestureShortcut, numberOfTaps: Int, numberOfTouches: Int, on view: UIView) {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleGesture(_:)))
        tapGesture.numberOfTapsRequired = numberOfTaps
        tapGesture.numberOfTouchesRequired = numberOfTouches
        tapGesture.name = shortcut.rawValue
        
        view.addGestureRecognizer(tapGesture)
        gestureRecognizers.append(tapGesture)
    }
    
    private func createLongPressGesture(_ shortcut: GestureShortcut, numberOfTouches: Int = 1, on view: UIView) {
        let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(handleGesture(_:)))
        longPressGesture.numberOfTouchesRequired = numberOfTouches
        longPressGesture.minimumPressDuration = 0.5
        longPressGesture.name = shortcut.rawValue
        
        view.addGestureRecognizer(longPressGesture)
        gestureRecognizers.append(longPressGesture)
    }
    
    private func createSwipeGesture(_ shortcut: GestureShortcut, direction: UISwipeGestureRecognizer.Direction, numberOfTouches: Int = 1, on view: UIView) {
        let swipeGesture = UISwipeGestureRecognizer(target: self, action: #selector(handleGesture(_:)))
        swipeGesture.direction = direction
        swipeGesture.numberOfTouchesRequired = numberOfTouches
        swipeGesture.name = shortcut.rawValue
        
        view.addGestureRecognizer(swipeGesture)
        gestureRecognizers.append(swipeGesture)
    }
    
    private func createPinchGesture(_ shortcut: GestureShortcut, numberOfTouches: Int = 1, on view: UIView) {
        let pinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(handleGesture(_:)))
        pinchGesture.name = shortcut.rawValue
        
        view.addGestureRecognizer(pinchGesture)
        gestureRecognizers.append(pinchGesture)
    }
    
    private func createEdgePanGesture(_ shortcut: GestureShortcut, edge: UIRectEdge, on view: UIView) {
        let edgePanGesture = UIScreenEdgePanGestureRecognizer(target: self, action: #selector(handleGesture(_:)))
        edgePanGesture.edges = edge
        edgePanGesture.name = shortcut.rawValue
        
        view.addGestureRecognizer(edgePanGesture)
        gestureRecognizers.append(edgePanGesture)
    }
    
    private func setupFeedbackOverlay() {
        guard let view = targetView else { return }
        
        // Setup feedback overlay
        feedbackOverlay.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        feedbackOverlay.layer.cornerRadius = 12
        feedbackOverlay.layer.cornerCurve = .continuous
        feedbackOverlay.isHidden = true
        feedbackOverlay.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(feedbackOverlay)
        
        // Setup feedback label
        feedbackLabel.font = DesignSystem.Typography.callout.font
        feedbackLabel.textColor = .white
        feedbackLabel.textAlignment = .center
        feedbackLabel.translatesAutoresizingMaskIntoConstraints = false
        feedbackOverlay.addSubview(feedbackLabel)
        
        // Setup constraints
        NSLayoutConstraint.activate([
            feedbackOverlay.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            feedbackOverlay.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -100),
            feedbackOverlay.widthAnchor.constraint(lessThanOrEqualToConstant: 200),
            feedbackOverlay.heightAnchor.constraint(equalToConstant: 40),
            
            feedbackLabel.centerXAnchor.constraint(equalTo: feedbackOverlay.centerXAnchor),
            feedbackLabel.centerYAnchor.constraint(equalTo: feedbackOverlay.centerYAnchor),
            feedbackLabel.leadingAnchor.constraint(greaterThanOrEqualTo: feedbackOverlay.leadingAnchor, constant: 8),
            feedbackLabel.trailingAnchor.constraint(lessThanOrEqualTo: feedbackOverlay.trailingAnchor, constant: -8)
        ])
    }
    
    // MARK: - Gesture Handling
    
    @objc private func handleGesture(_ gesture: UIGestureRecognizer) {
        guard let gestureName = gesture.name,
              let shortcut = GestureShortcut(rawValue: gestureName),
              let action = gestureMappings[shortcut] else {
            return
        }
        
        // Handle different gesture states
        switch gesture.state {
        case .began:
            handleGestureBegan(gesture, shortcut: shortcut, action: action)
        case .changed:
            handleGestureChanged(gesture, shortcut: shortcut, action: action)
        case .ended:
            handleGestureEnded(gesture, shortcut: shortcut, action: action)
        case .cancelled:
            handleGestureCancelled(gesture, shortcut: shortcut, action: action)
        default:
            break
        }
    }
    
    private func handleGestureBegan(_ gesture: UIGestureRecognizer, shortcut: GestureShortcut, action: ShortcutAction) {
        // Show visual feedback for certain gestures
        switch shortcut {
        case .longPress, .twoFingerLongPress:
            showFeedback(for: action)
        default:
            break
        }
        
        // Provide haptic feedback
        HapticFeedbackManager.shared.gestureFeedback(type: .longPress)
    }
    
    private func handleGestureChanged(_ gesture: UIGestureRecognizer, shortcut: GestureShortcut, action: ShortcutAction) {
        // Handle continuous gestures like pinch
        if let pinchGesture = gesture as? UIPinchGestureRecognizer {
            handlePinchGesture(pinchGesture, shortcut: shortcut, action: action)
        }
    }
    
    private func handleGestureEnded(_ gesture: UIGestureRecognizer, shortcut: GestureShortcut, action: ShortcutAction) {
        // Execute the action
        executeAction(action)
        
        // Show visual feedback
        showFeedback(for: action)
        
        // Provide haptic feedback
        let gestureType: HapticFeedbackManager.GestureType
        switch shortcut {
        case .doubleTap, .twoFingerTap, .threeFingerTap:
            gestureType = .tap
        case .pinchIn, .pinchOut, .twoFingerPinchIn, .twoFingerPinchOut:
            gestureType = .pinch
        case .swipeUp, .swipeDown, .swipeLeft, .swipeRight,
             .twoFingerSwipeUp, .twoFingerSwipeDown, .twoFingerSwipeLeft, .twoFingerSwipeRight,
             .threeFingerSwipeLeft, .threeFingerSwipeRight:
            gestureType = .swipe
        default:
            gestureType = .tap
        }
        
        HapticFeedbackManager.shared.gestureFeedback(type: gestureType)
    }
    
    private func handleGestureCancelled(_ gesture: UIGestureRecognizer, shortcut: GestureShortcut, action: ShortcutAction) {
        // Hide visual feedback if shown
        hideFeedback()
    }
    
    private func handlePinchGesture(_ gesture: UIPinchGestureRecognizer, shortcut: GestureShortcut, action: ShortcutAction) {
        // Handle zoom gestures
        switch shortcut {
        case .pinchIn, .pinchOut:
            if gesture.state == .changed {
                // Update zoom level based on pinch scale
                let scale = gesture.scale
                // This would update the camera zoom
            }
        case .twoFingerPinchIn, .twoFingerPinchOut:
            if gesture.state == .changed {
                // Handle two-finger pinch for different actions
            }
        default:
            break
        }
    }
    
    private func executeAction(_ action: ShortcutAction) {
        // Notify delegate of action
        onShortcutAction?(action)
    }
    
    // MARK: - Visual Feedback
    
    private func showFeedback(for action: ShortcutAction) {
        guard let view = targetView else { return }
        
        // Update feedback label
        feedbackLabel.text = actionDescription(for: action)
        
        // Show feedback overlay with animation
        feedbackOverlay.isHidden = false
        feedbackOverlay.alpha = 0
        feedbackOverlay.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        
        UIView.animate(withDuration: 0.2, delay: 0, options: [.curveEaseOut]) {
            self.feedbackOverlay.alpha = 1
            self.feedbackOverlay.transform = .identity
        } completion: { _ in
            // Hide after delay
            UIView.animate(withDuration: 0.2, delay: 1.0, options: [.curveEaseIn]) {
                self.feedbackOverlay.alpha = 0
                self.feedbackOverlay.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
            } completion: { _ in
                self.feedbackOverlay.isHidden = true
            }
        }
    }
    
    private func hideFeedback() {
        UIView.animate(withDuration: 0.2, delay: 0, options: [.curveEaseIn]) {
            self.feedbackOverlay.alpha = 0
            self.feedbackOverlay.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
        } completion: { _ in
            self.feedbackOverlay.isHidden = true
        }
    }
    
    private func actionDescription(for action: ShortcutAction) -> String {
        switch action {
        // Recording actions
        case .startRecording:
            return "Start Recording"
        case .stopRecording:
            return "Stop Recording"
        case .pauseRecording:
            return "Pause Recording"
        case .resumeRecording:
            return "Resume Recording"
        case .capturePhoto:
            return "Photo Captured"
            
        // Camera controls
        case .toggleFlash:
            return "Flash Toggled"
        case .switchCamera:
            return "Camera Switched"
        case .toggleFocusMode:
            return "Focus Mode Toggled"
        case .resetFocus:
            return "Focus Reset"
        case .toggleZoom:
            return "Zoom Toggled"
        case .resetZoom:
            return "Zoom Reset"
            
        // Mode changes
        case .switchToPhotoMode:
            return "Photo Mode"
        case .switchToVideoMode:
            return "Video Mode"
        case .switchToSlowMotionMode:
            return "Slow Motion"
        case .switchToTimeLapseMode:
            return "Time Lapse"
            
        // UI actions
        case .showSettings:
            return "Settings"
        case .hideControls:
            return "Controls Hidden"
        case .showControls:
            return "Controls Shown"
        case .toggleGrid:
            return "Grid Toggled"
        case .toggleTimer:
            return "Timer Toggled"
            
        // Advanced actions
        case .takeBurstPhoto:
            return "Burst Photo"
        case .startTimedRecording:
            return "Timed Recording"
        case .takeHDRPhoto:
            return "HDR Photo"
        case .toggleNightMode:
            return "Night Mode"
        case .togglePortraitMode:
            return "Portrait Mode"
        }
    }
    
    // MARK: - Configuration
    
    /// Updates the mapping for a specific gesture shortcut
    func updateGestureMapping(_ shortcut: GestureShortcut, action: ShortcutAction) {
        gestureMappings[shortcut] = action
    }
    
    /// Removes a gesture mapping
    func removeGestureMapping(_ shortcut: GestureShortcut) {
        gestureMappings.removeValue(forKey: shortcut)
    }
    
    /// Enables or disables all gesture shortcuts
    func setGestureShortcutsEnabled(_ enabled: Bool) {
        gestureRecognizers.forEach { $0.isEnabled = enabled }
    }
    
    /// Enables or disables a specific gesture shortcut
    func setGestureShortcutEnabled(_ shortcut: GestureShortcut, enabled: Bool) {
        if let gesture = gestureRecognizers.first(where: { $0.name == shortcut.rawValue }) {
            gesture.isEnabled = enabled
        }
    }
    
    /// Clears all gesture recognizers
    private func clearGestureRecognizers() {
        guard let view = targetView else { return }
        
        gestureRecognizers.forEach { view.removeGestureRecognizer($0) }
        gestureRecognizers.removeAll()
    }
    
    // MARK: - Accessibility
    
    /// Provides accessibility labels for gesture shortcuts
    func accessibilityLabel(for shortcut: GestureShortcut) -> String {
        guard let action = gestureMappings[shortcut] else {
            return "Unassigned gesture"
        }
        
        return actionDescription(for: action)
    }
    
    /// Provides accessibility hints for gesture shortcuts
    func accessibilityHint(for shortcut: GestureShortcut) -> String {
        switch shortcut {
        case .doubleTap:
            return "Double tap to capture photo"
        case .tripleTap:
            return "Triple tap to switch camera"
        case .longPress:
            return "Long press to start recording"
        case .swipeUp:
            return "Swipe up to show controls"
        case .swipeDown:
            return "Swipe down to hide controls"
        case .swipeLeft:
            return "Swipe left to switch to photo mode"
        case .swipeRight:
            return "Swipe right to switch to video mode"
        case .pinchIn, .pinchOut:
            return "Pinch to toggle zoom"
        case .twoFingerTap:
            return "Two finger tap to toggle flash"
        case .twoFingerDoubleTap:
            return "Two finger double tap to toggle focus mode"
        case .twoFingerLongPress:
            return "Two finger long press to take burst photo"
        case .twoFingerSwipeUp:
            return "Two finger swipe up to show settings"
        case .twoFingerSwipeDown:
            return "Two finger swipe down to toggle grid"
        case .twoFingerSwipeLeft:
            return "Two finger swipe left to switch to slow motion mode"
        case .twoFingerSwipeRight:
            return "Two finger swipe right to switch to time lapse mode"
        case .twoFingerPinchIn:
            return "Two finger pinch in to reset zoom"
        case .twoFingerPinchOut:
            return "Two finger pinch out to reset focus"
        case .threeFingerTap:
            return "Three finger tap to toggle night mode"
        case .threeFingerSwipeLeft:
            return "Three finger swipe left to toggle timer"
        case .threeFingerSwipeRight:
            return "Three finger swipe right to toggle portrait mode"
        case .edgePanLeft, .edgePanRight:
            return "Edge pan to switch camera"
        case .edgePanTop:
            return "Edge pan from top to show settings"
        case .edgePanBottom:
            return "Edge pan from bottom to show controls"
        }
    }
}