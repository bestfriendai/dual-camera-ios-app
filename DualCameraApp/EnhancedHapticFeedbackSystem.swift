//
//  EnhancedHapticFeedbackSystem.swift
//  DualCameraApp
//
//  Enhanced haptic feedback system with immersive feedback patterns and contextual responses
//

import UIKit
import CoreHaptics

/// Enhanced haptic feedback system with immersive feedback patterns
class EnhancedHapticFeedbackSystem {
    
    static let shared = EnhancedHapticFeedbackSystem()
    
    private init() {}
    
    // MARK: - Properties
    
    private var hapticEngine: CHHapticEngine?
    private var isHapticEnginePrepared = false
    private var continuousHapticPlayer: CHHapticPatternPlayer?
    
    // MARK: - Haptic Patterns
    
    /// Different haptic patterns for various interactions
    enum HapticPattern {
        case lightTap
        case mediumTap
        case heavyTap
        case success
        case warning
        case error
        case selection
        case recordingStart
        case recordingStop
        case recordingProgress
        case focusAdjustment
        case zoomAdjustment
        case cameraSwitch
        case flashToggle
        case photoCapture
        case videoCapture
        case burstCapture
        case timerCountdown
        case modeSwitch
        case settingsOpen
        case settingsClose
        case gestureDetected
        case longPressStart
        case longPressEnd
        case swipeUp
        case swipeDown
        case swipeLeft
        case swipeRight
        case pinchIn
        case pinchOut
        case custom([CHHapticEvent])
    }
    
    // MARK: - Haptic Intensity Levels
    
    /// Different intensity levels for haptic feedback
    enum HapticIntensity {
        case subtle
        case light
        case medium
        case strong
        case intense
        
        var value: Float {
            switch self {
            case .subtle:
                return 0.2
            case .light:
                return 0.4
            case .medium:
                return 0.6
            case .strong:
                return 0.8
            case .intense:
                return 1.0
            }
        }
    }
    
    // MARK: - Haptic Sharpness Levels
    
    /// Different sharpness levels for haptic feedback
    enum HapticSharpness {
        case dull
        case soft
        case medium
        case sharp
        case crisp
        
        var value: Float {
            switch self {
            case .dull:
                return 0.0
            case .soft:
                return 0.25
            case .medium:
                return 0.5
            case .sharp:
                return 0.75
            case .crisp:
                return 1.0
            }
        }
    }
    
    // MARK: - Initialization
    
    /// Prepares the haptic engine for use
    func prepareHapticEngine() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        
        do {
            hapticEngine = try CHHapticEngine()
            
            // Set up engine stopped handler
            hapticEngine?.stoppedHandler = { reason in
                print("Haptic engine stopped: \(reason)")
                self.isHapticEnginePrepared = false
            }
            
            // Set up reset handler
            hapticEngine?.resetHandler = {
                print("Haptic engine reset")
                do {
                    try self.hapticEngine?.start()
                    self.isHapticEnginePrepared = true
                } catch {
                    print("Failed to restart haptic engine: \(error)")
                }
            }
            
            try hapticEngine?.start()
            isHapticEnginePrepared = true
        } catch {
            print("Failed to create haptic engine: \(error)")
        }
    }
    
    /// Stops the haptic engine
    func stopHapticEngine() {
        hapticEngine?.stop { error in
            if let error = error {
                print("Failed to stop haptic engine: \(error)")
            }
        }
        isHapticEnginePrepared = false
    }
    
    // MARK: - Haptic Feedback Methods
    
    /// Plays a haptic pattern with specified intensity and sharpness
    func playHaptic(
        pattern: HapticPattern,
        intensity: HapticIntensity = .medium,
        sharpness: HapticSharpness = .medium
    ) {
        // If Core Haptics is not available, fall back to basic haptics
        if !CHHapticEngine.capabilitiesForHardware().supportsHaptics {
            playBasicHaptic(pattern: pattern)
            return
        }
        
        // Ensure haptic engine is prepared
        if !isHapticEnginePrepared {
            prepareHapticEngine()
        }
        
        guard let engine = hapticEngine else { return }
        
        do {
            // Create haptic pattern based on pattern type
            let hapticPattern = createHapticPattern(pattern: pattern, intensity: intensity, sharpness: sharpness)
            
            // Create player from pattern
            let player = try engine.makePlayer(with: hapticPattern)
            
            // Play pattern
            try player.start(atTime: 0)
        } catch {
            print("Failed to play haptic pattern: \(error)")
            // Fall back to basic haptics
            playBasicHaptic(pattern: pattern)
        }
    }
    
    /// Plays a continuous haptic pattern
    func playContinuousHaptic(
        pattern: HapticPattern,
        intensity: HapticIntensity = .medium,
        sharpness: HapticSharpness = .medium,
        duration: TimeInterval
    ) {
        // If Core Haptics is not available, fall back to basic haptics
        if !CHHapticEngine.capabilitiesForHardware().supportsHaptics {
            playBasicHaptic(pattern: pattern)
            return
        }
        
        // Ensure haptic engine is prepared
        if !isHapticEnginePrepared {
            prepareHapticEngine()
        }
        
        guard let engine = hapticEngine else { return }
        
        do {
            // Create haptic pattern based on pattern type
            let hapticPattern = createContinuousHapticPattern(
                pattern: pattern,
                intensity: intensity,
                sharpness: sharpness,
                duration: duration
            )
            
            // Create player from pattern
            let player = try engine.makePlayer(with: hapticPattern)
            
            // Store player for later stopping
            continuousHapticPlayer = player
            
            // Play pattern
            try player.start(atTime: 0)
        } catch {
            print("Failed to play continuous haptic pattern: \(error)")
            // Fall back to basic haptics
            playBasicHaptic(pattern: pattern)
        }
    }
    
    /// Stops any continuous haptic feedback
    func stopContinuousHaptic() {
        try? continuousHapticPlayer?.stop(atTime: 0)
        continuousHapticPlayer = nil
    }
    
    // MARK: - Haptic Pattern Creation
    
    private func createHapticPattern(
        pattern: HapticPattern,
        intensity: HapticIntensity,
        sharpness: HapticSharpness
    ) -> CHHapticPattern {
        let events: [CHHapticEvent]
        
        switch pattern {
        case .lightTap:
            events = [
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity.value),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness.value)
                    ],
                    relativeTime: 0
                )
            ]
            
        case .mediumTap:
            events = [
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity.value),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness.value)
                    ],
                    relativeTime: 0
                )
            ]
            
        case .heavyTap:
            events = [
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity.value),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness.value)
                    ],
                    relativeTime: 0
                )
            ]
            
        case .success:
            events = [
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity.value),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness.value)
                    ],
                    relativeTime: 0
                ),
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity.value * 0.7),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness.value)
                    ],
                    relativeTime: 0.1
                )
            ]
            
        case .warning:
            events = [
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity.value),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness.value)
                    ],
                    relativeTime: 0
                ),
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity.value * 0.7),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness.value)
                    ],
                    relativeTime: 0.3
                )
            ]
            
        case .error:
            events = [
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity.value),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness.value)
                    ],
                    relativeTime: 0
                ),
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity.value * 0.7),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness.value)
                    ],
                    relativeTime: 0.1
                ),
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity.value * 0.5),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness.value)
                    ],
                    relativeTime: 0.2
                )
            ]
            
        case .recordingStart:
            events = [
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity.value),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness.value)
                    ],
                    relativeTime: 0
                ),
                CHHapticEvent(
                    eventType: .hapticContinuous,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity.value * 0.3),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness.value)
                    ],
                    relativeTime: 0.1,
                    duration: 0.5
                )
            ]
            
        case .recordingStop:
            events = [
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity.value),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness.value)
                    ],
                    relativeTime: 0
                ),
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity.value * 0.7),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness.value)
                    ],
                    relativeTime: 0.2
                )
            ]
            
        case .focusAdjustment:
            events = [
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity.value * 0.5),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness.value)
                    ],
                    relativeTime: 0
                )
            ]
            
        case .zoomAdjustment:
            events = [
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity.value * 0.3),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness.value)
                    ],
                    relativeTime: 0
                )
            ]
            
        case .photoCapture:
            events = [
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity.value),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness.value)
                    ],
                    relativeTime: 0
                ),
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity.value * 0.5),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness.value)
                    ],
                    relativeTime: 0.05
                )
            ]
            
        case .custom(let customEvents):
            events = customEvents
            
        default:
            // Default to light tap for unhandled patterns
            events = [
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity.value),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness.value)
                    ],
                    relativeTime: 0
                )
            ]
        }
        
        do {
            return try CHHapticPattern(events: events, parameters: [])
        } catch {
            print("Failed to create haptic pattern: \(error)")
            // Return a simple pattern as fallback
            do {
                return try CHHapticPattern(events: [
                    CHHapticEvent(
                        eventType: .hapticTransient,
                        parameters: [
                            CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity.value),
                            CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness.value)
                        ],
                        relativeTime: 0
                    )
                ], parameters: [])
            } catch {
                fatalError("Failed to create fallback haptic pattern: \(error)")
            }
        }
    }
    
    private func createContinuousHapticPattern(
        pattern: HapticPattern,
        intensity: HapticIntensity,
        sharpness: HapticSharpness,
        duration: TimeInterval
    ) -> CHHapticPattern {
        let events: [CHHapticEvent]
        
        switch pattern {
        case .recordingProgress:
            events = [
                CHHapticEvent(
                    eventType: .hapticContinuous,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity.value * 0.3),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness.value)
                    ],
                    relativeTime: 0,
                    duration: duration
                )
            ]
            
        case .timerCountdown:
            events = [
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity.value),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness.value)
                    ],
                    relativeTime: 0
                ),
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity.value),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness.value)
                    ],
                    relativeTime: duration * 0.5
                ),
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity.value),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness.value)
                    ],
                    relativeTime: duration * 0.9
                )
            ]
            
        default:
            // Default to continuous vibration for unhandled patterns
            events = [
                CHHapticEvent(
                    eventType: .hapticContinuous,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity.value * 0.3),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness.value)
                    ],
                    relativeTime: 0,
                    duration: duration
                )
            ]
        }
        
        do {
            return try CHHapticPattern(events: events, parameters: [])
        } catch {
            print("Failed to create continuous haptic pattern: \(error)")
            // Return a simple pattern as fallback
            do {
                return try CHHapticPattern(events: [
                    CHHapticEvent(
                        eventType: .hapticContinuous,
                        parameters: [
                            CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity.value * 0.3),
                            CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness.value)
                        ],
                        relativeTime: 0,
                        duration: duration
                    )
                ], parameters: [])
            } catch {
                fatalError("Failed to create fallback continuous haptic pattern: \(error)")
            }
        }
    }
    
    // MARK: - Basic Haptic Feedback
    
    private func playBasicHaptic(pattern: HapticPattern) {
        let feedbackGenerator: UIFeedbackGenerator
        
        switch pattern {
        case .lightTap, .focusAdjustment, .zoomAdjustment, .selection:
            feedbackGenerator = UIImpactFeedbackGenerator(style: .light)
        case .mediumTap, .recordingStart, .recordingStop, .cameraSwitch, .flashToggle, .photoCapture, .videoCapture:
            feedbackGenerator = UIImpactFeedbackGenerator(style: .medium)
        case .heavyTap, .burstCapture, .modeSwitch, .settingsOpen, .settingsClose, .gestureDetected:
            feedbackGenerator = UIImpactFeedbackGenerator(style: .heavy)
        case .success:
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            return
        case .warning:
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.warning)
            return
        case .error:
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.error)
            return
        default:
            feedbackGenerator = UIImpactFeedbackGenerator(style: .light)
        }
        
        feedbackGenerator.prepare()
        if let impactGenerator = feedbackGenerator as? UIImpactFeedbackGenerator {
            impactGenerator.impactOccurred()
        }
    }
    
    // MARK: - Convenience Methods
    
    /// Plays a haptic for recording start
    func recordingStart() {
        playHaptic(pattern: .recordingStart, intensity: .medium, sharpness: .sharp)
    }
    
    /// Plays a haptic for recording stop
    func recordingStop() {
        playHaptic(pattern: .recordingStop, intensity: .strong, sharpness: .sharp)
    }
    
    /// Plays a haptic for photo capture
    func photoCapture() {
        playHaptic(pattern: .photoCapture, intensity: .medium, sharpness: .crisp)
    }
    
    /// Plays a haptic for video capture
    func videoCapture() {
        playHaptic(pattern: .videoCapture, intensity: .medium, sharpness: .sharp)
    }
    
    /// Plays a haptic for burst capture
    func burstCapture() {
        playHaptic(pattern: .burstCapture, intensity: .strong, sharpness: .sharp)
    }
    
    /// Plays a haptic for focus adjustment
    func focusAdjustment() {
        playHaptic(pattern: .focusAdjustment, intensity: .light, sharpness: .soft)
    }
    
    /// Plays a haptic for zoom adjustment
    func zoomAdjustment() {
        playHaptic(pattern: .zoomAdjustment, intensity: .subtle, sharpness: .soft)
    }
    
    /// Plays a haptic for camera switch
    func cameraSwitch() {
        playHaptic(pattern: .cameraSwitch, intensity: .medium, sharpness: .medium)
    }
    
    /// Plays a haptic for flash toggle
    func flashToggle() {
        playHaptic(pattern: .flashToggle, intensity: .light, sharpness: .medium)
    }
    
    /// Plays a haptic for mode switch
    func modeSwitch() {
        playHaptic(pattern: .modeSwitch, intensity: .medium, sharpness: .medium)
    }
    
    /// Plays a haptic for settings open
    func settingsOpen() {
        playHaptic(pattern: .settingsOpen, intensity: .light, sharpness: .soft)
    }
    
    /// Plays a haptic for settings close
    func settingsClose() {
        playHaptic(pattern: .settingsClose, intensity: .light, sharpness: .soft)
    }
    
    /// Plays a haptic for gesture detected
    func gestureDetected() {
        playHaptic(pattern: .gestureDetected, intensity: .light, sharpness: .medium)
    }
    
    /// Plays a haptic for selection
    func selection() {
        playHaptic(pattern: .selection, intensity: .light, sharpness: .medium)
    }
    
    /// Plays a haptic for success
    func success() {
        playHaptic(pattern: .success, intensity: .medium, sharpness: .sharp)
    }
    
    /// Plays a haptic for warning
    func warning() {
        playHaptic(pattern: .warning, intensity: .medium, sharpness: .sharp)
    }
    
    /// Plays a haptic for error
    func error() {
        playHaptic(pattern: .error, intensity: .strong, sharpness: .sharp)
    }
    
    /// Plays a haptic for timer countdown
    func timerCountdown(duration: TimeInterval) {
        playContinuousHaptic(pattern: .timerCountdown, intensity: .medium, sharpness: .medium, duration: duration)
    }
    
    /// Plays a haptic for recording progress
    func recordingProgress(duration: TimeInterval) {
        playContinuousHaptic(pattern: .recordingProgress, intensity: .subtle, sharpness: .soft, duration: duration)
    }
    
    /// Plays a custom haptic pattern
    func customPattern(_ events: [CHHapticEvent]) {
        playHaptic(pattern: .custom(events))
    }
}

// MARK: - Haptic Feedback Extensions

extension EnhancedHapticFeedbackSystem {
    
    /// Creates a haptic event with specified parameters
    static func createHapticEvent(
        type: CHHapticEvent.EventType,
        intensity: Float,
        sharpness: Float,
        time: TimeInterval,
        duration: TimeInterval = 0
    ) -> CHHapticEvent {
        let parameters = [
            CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
            CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness)
        ]
        
        return CHHapticEvent(
            eventType: type,
            parameters: parameters,
            relativeTime: time,
            duration: duration
        )
    }
    
    /// Creates a haptic curve for dynamic intensity changes
    static func createHapticCurve(
        initialIntensity: Float,
        finalIntensity: Float,
        duration: TimeInterval,
        time: TimeInterval
    ) -> [CHHapticEvent] {
        let events: [CHHapticEvent] = []
        
        // This would create a series of events to simulate a curve
        // For simplicity, we're just returning an empty array
        
        return events
    }
    
    /// Creates a haptic texture for rich feedback
    static func createHapticTexture(
        events: [CHHapticEvent]
    ) -> CHHapticPattern? {
        do {
            return try CHHapticPattern(events: events, parameters: [])
        } catch {
            print("Failed to create haptic texture: \(error)")
            return nil
        }
    }
}