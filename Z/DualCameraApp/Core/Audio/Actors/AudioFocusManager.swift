//
//  AudioFocusManager.swift
//  DualApp
//
//  Created by DualApp Team on 10/3/25.
//

import Foundation
import AVFoundation
import UIKit

// MARK: - Audio Focus Manager

@MainActor
actor AudioFocusManager: NSObject, Sendable {
    // MARK: - State Properties
    
    private(set) var currentFocusState: AudioFocusState = .noFocus
    private(set) var focusConfiguration: AudioFocusConfiguration = .default
    private(set) var hasFocus: Bool = false
    private(set) var isInterrupted: Bool = false
    private(set) var interruptionType: AudioInterruptionType = .unknown
    
    // MARK: - Audio Session
    
    private let audioSession: AVAudioSession
    private var notificationObservers: [NSObjectProtocol] = []
    
    // MARK: - Event Streams
    
    let focusEvents: AsyncStream<AudioFocusEvent>
    private let focusContinuation: AsyncStream<AudioFocusEvent>.Continuation
    
    // MARK: - Focus History
    
    private var focusHistory: [AudioFocusEvent] = []
    private let maxHistoryEntries: Int = 100
    
    // MARK: - Initialization
    
    override init() {
        self.audioSession = AVAudioSession.sharedInstance()
        
        (focusEvents, focusContinuation) = AsyncStream.makeStream()
        
        super.init()
        
        Task {
            await initializeAudioFocusManager()
        }
    }
    
    // MARK: - Public Interface
    
    func requestFocus(with configuration: AudioFocusConfiguration = .default) async throws {
        guard currentFocusState == .noFocus else {
            throw AudioError.permissionDenied("Audio focus already requested")
        }
        
        focusConfiguration = configuration
        
        do {
            // Configure audio session
            try await configureAudioSession()
            
            // Request focus
            try await performFocusRequest()
            
            // Update state
            currentFocusState = .focused
            hasFocus = true
            isInterrupted = false
            
            // Send event
            let event = AudioFocusEvent(
                type: .focusGained,
                state: currentFocusState,
                configuration: focusConfiguration,
                timestamp: Date()
            )
            focusContinuation.yield(event)
            addToHistory(event)
            
        } catch {
            // Update state
            currentFocusState = .failed
            hasFocus = false
            
            // Send event
            let event = AudioFocusEvent(
                type: .focusRequestFailed,
                state: currentFocusState,
                configuration: focusConfiguration,
                timestamp: Date(),
                error: error
            )
            focusContinuation.yield(event)
            addToHistory(event)
            
            throw AudioError.permissionDenied("Failed to request audio focus: \(error.localizedDescription)")
        }
    }
    
    func abandonFocus() async {
        guard currentFocusState != .noFocus else { return }
        
        do {
            // Abandon focus
            try await performFocusAbandon()
            
            // Update state
            currentFocusState = .noFocus
            hasFocus = false
            isInterrupted = false
            
            // Send event
            let event = AudioFocusEvent(
                type: .focusLost,
                state: currentFocusState,
                configuration: focusConfiguration,
                timestamp: Date()
            )
            focusContinuation.yield(event)
            addToHistory(event)
            
        } catch {
            // Update state
            currentFocusState = .failed
            
            // Send event
            let event = AudioFocusEvent(
                type: .focusAbandonFailed,
                state: currentFocusState,
                configuration: focusConfiguration,
                timestamp: Date(),
                error: error
            )
            focusContinuation.yield(event)
            addToHistory(event)
        }
    }
    
    func updateConfiguration(_ configuration: AudioFocusConfiguration) async throws {
        focusConfiguration = configuration
        
        // Reconfigure if we have focus
        if hasFocus {
            try await configureAudioSession()
        }
    }
    
    func handleInterruption(_ type: AudioInterruptionType, options: AVAudioSession.InterruptionOptions = []) async {
        interruptionType = type
        
        switch type {
        case .began:
            await handleInterruptionBegan()
        case .ended:
            await handleInterruptionEnded(options: options)
        }
    }
    
    func handleRouteChange(_ reason: AVAudioSession.RouteChangeReason, previousRoute: AVAudioSessionRouteDescription?) async {
        // Update state based on route change
        switch reason {
        case .oldDeviceUnavailable:
            // Output device was disconnected
            if hasFocus {
                await handleOutputDeviceDisconnected()
            }
        case .newDeviceAvailable:
            // New output device is available
            if hasFocus {
                await handleOutputDeviceConnected()
            }
        case .categoryChange:
            // Audio category changed
            if hasFocus {
                await handleCategoryChange()
            }
        default:
            break
        }
        
        // Send event
        let event = AudioFocusEvent(
            type: .routeChanged,
            state: currentFocusState,
            configuration: focusConfiguration,
            timestamp: Date(),
            routeChangeReason: reason,
            previousRoute: previousRoute
        )
        focusContinuation.yield(event)
        addToHistory(event)
    }
    
    func handleMediaServicesReset() async {
        // Media services were reset, need to reconfigure
        if hasFocus {
            do {
                try await configureAudioSession()
                
                // Send event
                let event = AudioFocusEvent(
                    type: .mediaServicesReset,
                    state: currentFocusState,
                    configuration: focusConfiguration,
                    timestamp: Date()
                )
                focusContinuation.yield(event)
                addToHistory(event)
                
            } catch {
                // Update state
                currentFocusState = .failed
                hasFocus = false
                
                // Send event
                let event = AudioFocusEvent(
                    type: .focusLost,
                    state: currentFocusState,
                    configuration: focusConfiguration,
                    timestamp: Date(),
                    error: error
                )
                focusContinuation.yield(event)
                addToHistory(event)
            }
        }
    }
    
    func getFocusHistory() async -> [AudioFocusEvent] {
        return focusHistory
    }
    
    func getCurrentFocusState() async -> AudioFocusState {
        return currentFocusState
    }
    
    func hasAudioFocus() async -> Bool {
        return hasFocus
    }
    
    func isCurrentlyInterrupted() async -> Bool {
        return isInterrupted
    }
    
    // MARK: - Private Methods
    
    private func initializeAudioFocusManager() async {
        // Set up notification observers
        await setupNotificationObservers()
    }
    
    private func setupNotificationObservers() async {
        // Audio session interruption notification
        let interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: audioSession,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor in
                await self?.handleInterruptionNotification(notification)
            }
        }
        notificationObservers.append(interruptionObserver)
        
        // Audio session route change notification
        let routeChangeObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: audioSession,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor in
                await self?.handleRouteChangeNotification(notification)
            }
        }
        notificationObservers.append(routeChangeObserver)
        
        // Media services reset notification
        let mediaServicesResetObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.mediaServicesWereResetNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.handleMediaServicesReset()
            }
        }
        notificationObservers.append(mediaServicesResetObserver)
        
        // Media services lost notification
        let mediaServicesLostObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.mediaServicesWereLostNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.handleMediaServicesLost()
            }
        }
        notificationObservers.append(mediaServicesLostObserver)
    }
    
    private func configureAudioSession() async throws {
        // Configure audio session based on focus configuration
        try audioSession.setCategory(
            focusConfiguration.category,
            mode: focusConfiguration.mode,
            options: focusConfiguration.options
        )
        
        try audioSession.setPreferredSampleRate(focusConfiguration.preferredSampleRate)
        try audioSession.setPreferredIOBufferDuration(focusConfiguration.preferredIOBufferDuration)
        try audioSession.setPreferredOutputNumberOfChannels(focusConfiguration.preferredOutputNumberOfChannels)
        
        // Activate session
        try audioSession.setActive(true)
    }
    
    private func performFocusRequest() async throws {
        // Request audio focus
        try audioSession.setActive(true)
    }
    
    private func performFocusAbandon() async throws {
        // Abandon audio focus
        try audioSession.setActive(false)
    }
    
    private func handleInterruptionNotification(_ notification: Notification) async {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }
        
        let options = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
        let interruptionOptions = AVAudioSession.InterruptionOptions(rawValue: options)
        
        switch type {
        case .began:
            await handleInterruption(.began)
        case .ended:
            await handleInterruption(.ended, options: interruptionOptions)
        @unknown default:
            break
        }
    }
    
    private func handleRouteChangeNotification(_ notification: Notification) async {
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
            return
        }
        
        let previousRoute = userInfo[AVAudioSessionRouteChangePreviousRouteKey] as? AVAudioSessionRouteDescription
        
        await handleRouteChange(reason, previousRoute: previousRoute)
    }
    
    private func handleInterruption(_ type: AudioInterruptionType, options: AVAudioSession.InterruptionOptions = []) async {
        interruptionType = type
        
        switch type {
        case .began:
            await handleInterruptionBegan()
        case .ended:
            await handleInterruptionEnded(options: options)
        }
    }
    
    private func handleInterruptionBegan() async {
        // Update state
        isInterrupted = true
        
        // Send event
        let event = AudioFocusEvent(
            type: .interruptionBegan,
            state: currentFocusState,
            configuration: focusConfiguration,
            timestamp: Date(),
            interruptionType: .began
        )
        focusContinuation.yield(event)
        addToHistory(event)
    }
    
    private func handleInterruptionEnded(options: AVAudioSession.InterruptionOptions) async {
        // Update state
        isInterrupted = false
        
        // Check if we should resume
        let shouldResume = options.contains(.shouldResume)
        
        if shouldResume && hasFocus {
            do {
                // Reactivate session
                try audioSession.setActive(true)
                
                // Send event
                let event = AudioFocusEvent(
                    type: .interruptionEnded,
                    state: currentFocusState,
                    configuration: focusConfiguration,
                    timestamp: Date(),
                    interruptionType: .ended,
                    shouldResume: true
                )
                focusContinuation.yield(event)
                addToHistory(event)
                
            } catch {
                // Update state
                currentFocusState = .failed
                hasFocus = false
                
                // Send event
                let event = AudioFocusEvent(
                    type: .interruptionEnded,
                    state: currentFocusState,
                    configuration: focusConfiguration,
                    timestamp: Date(),
                    interruptionType: .ended,
                    shouldResume: false,
                    error: error
                )
                focusContinuation.yield(event)
                addToHistory(event)
            }
        } else {
            // Send event
            let event = AudioFocusEvent(
                type: .interruptionEnded,
                state: currentFocusState,
                configuration: focusConfiguration,
                timestamp: Date(),
                interruptionType: .ended,
                shouldResume: false
            )
            focusContinuation.yield(event)
            addToHistory(event)
        }
    }
    
    private func handleOutputDeviceDisconnected() async {
        // Update state
        currentFocusState = .temporarilyLost
        
        // Send event
        let event = AudioFocusEvent(
            type: .outputDeviceDisconnected,
            state: currentFocusState,
            configuration: focusConfiguration,
            timestamp: Date()
        )
        focusContinuation.yield(event)
        addToHistory(event)
    }
    
    private func handleOutputDeviceConnected() async {
        // Update state
        if hasFocus {
            currentFocusState = .focused
            
            // Send event
            let event = AudioFocusEvent(
                type: .outputDeviceConnected,
                state: currentFocusState,
                configuration: focusConfiguration,
                timestamp: Date()
            )
            focusContinuation.yield(event)
            addToHistory(event)
        }
    }
    
    private func handleCategoryChange() async {
        // Reconfigure session with new category
        do {
            try await configureAudioSession()
            
            // Send event
            let event = AudioFocusEvent(
                type: .categoryChanged,
                state: currentFocusState,
                configuration: focusConfiguration,
                timestamp: Date()
            )
            focusContinuation.yield(event)
            addToHistory(event)
            
        } catch {
            // Update state
            currentFocusState = .failed
            hasFocus = false
            
            // Send event
            let event = AudioFocusEvent(
                type: .categoryChanged,
                state: currentFocusState,
                configuration: focusConfiguration,
                timestamp: Date(),
                error: error
            )
            focusContinuation.yield(event)
            addToHistory(event)
        }
    }
    
    private func handleMediaServicesLost() async {
        // Update state
        currentFocusState = .failed
        hasFocus = false
        
        // Send event
        let event = AudioFocusEvent(
            type: .mediaServicesLost,
            state: currentFocusState,
            configuration: focusConfiguration,
            timestamp: Date()
        )
        focusContinuation.yield(event)
        addToHistory(event)
    }
    
    private func addToHistory(_ event: AudioFocusEvent) async {
        focusHistory.append(event)
        
        // Keep only the last maxHistoryEntries
        if focusHistory.count > maxHistoryEntries {
            focusHistory.removeFirst()
        }
    }
    
    deinit {
        // Remove notification observers
        for observer in notificationObservers {
            NotificationCenter.default.removeObserver(observer)
        }
    }
}

// MARK: - Supporting Types

enum AudioFocusState: String, CaseIterable, Sendable {
    case noFocus = "noFocus"
    case requesting = "requesting"
    case focused = "focused"
    case temporarilyLost = "temporarilyLost"
    case failed = "failed"
    
    var displayName: String {
        switch self {
        case .noFocus:
            return "No Focus"
        case .requesting:
            return "Requesting"
        case .focused:
            return "Focused"
        case .temporarilyLost:
            return "Temporarily Lost"
        case .failed:
            return "Failed"
        }
    }
    
    var description: String {
        switch self {
        case .noFocus:
            return "No audio focus is currently held"
        case .requesting:
            return "Audio focus is being requested"
        case .focused:
            return "Audio focus is currently held"
        case .temporarilyLost:
            return "Audio focus is temporarily lost"
        case .failed:
            return "Audio focus request failed"
        }
    }
}

struct AudioFocusConfiguration: Sendable {
    let category: AVAudioSession.Category
    let mode: AVAudioSession.Mode
    let options: AVAudioSession.CategoryOptions
    let preferredSampleRate: Double
    let preferredIOBufferDuration: TimeInterval
    let preferredOutputNumberOfChannels: Int
    let allowMixing: Bool
    let duckOthers: Bool
    let interruptSpokenAudioAndMix: Bool
    
    static let `default` = AudioFocusConfiguration(
        category: .playAndRecord,
        mode: .videoRecording,
        options: [.defaultToSpeaker, .allowBluetoothA2DP, .allowAirPlay],
        preferredSampleRate: 44100.0,
        preferredIOBufferDuration: 0.005,
        preferredOutputNumberOfChannels: 2,
        allowMixing: false,
        duckOthers: false,
        interruptSpokenAudioAndMix: false
    )
    
    static let recording = AudioFocusConfiguration(
        category: .playAndRecord,
        mode: .videoRecording,
        options: [.defaultToSpeaker, .allowBluetoothA2DP, .allowAirPlay, .mixWithOthers],
        preferredSampleRate: 48000.0,
        preferredIOBufferDuration: 0.005,
        preferredOutputNumberOfChannels: 2,
        allowMixing: false,
        duckOthers: false,
        interruptSpokenAudioAndMix: false
    )
    
    static let playback = AudioFocusConfiguration(
        category: .playback,
        mode: .moviePlayback,
        options: [.allowBluetoothA2DP, .allowAirPlay],
        preferredSampleRate: 44100.0,
        preferredIOBufferDuration: 0.005,
        preferredOutputNumberOfChannels: 2,
        allowMixing: false,
        duckOthers: false,
        interruptSpokenAudioAndMix: false
    )
    
    static let voiceChat = AudioFocusConfiguration(
        category: .playAndRecord,
        mode: .voiceChat,
        options: [.defaultToSpeaker, .allowBluetooth],
        preferredSampleRate: 44100.0,
        preferredIOBufferDuration: 0.002,
        preferredOutputNumberOfChannels: 2,
        allowMixing: false,
        duckOthers: false,
        interruptSpokenAudioAndMix: false
    )
    
    static let ambient = AudioFocusConfiguration(
        category: .ambient,
        mode: .default,
        options: [],
        preferredSampleRate: 44100.0,
        preferredIOBufferDuration: 0.005,
        preferredOutputNumberOfChannels: 2,
        allowMixing: true,
        duckOthers: false,
        interruptSpokenAudioAndMix: false
    )
    
    static let soloAmbient = AudioFocusConfiguration(
        category: .soloAmbient,
        mode: .default,
        options: [],
        preferredSampleRate: 44100.0,
        preferredIOBufferDuration: 0.005,
        preferredOutputNumberOfChannels: 2,
        allowMixing: false,
        duckOthers: false,
        interruptSpokenAudioAndMix: false
    )
}

enum AudioInterruptionType: String, CaseIterable, Sendable {
    case began = "began"
    case ended = "ended"
    case unknown = "unknown"
    
    var displayName: String {
        switch self {
        case .began:
            return "Began"
        case .ended:
            return "Ended"
        case .unknown:
            return "Unknown"
        }
    }
}

struct AudioFocusEvent: Sendable {
    let type: AudioFocusEventType
    let state: AudioFocusState
    let configuration: AudioFocusConfiguration
    let timestamp: Date
    let error: Error?
    let interruptionType: AudioInterruptionType?
    let shouldResume: Bool?
    let routeChangeReason: AVAudioSession.RouteChangeReason?
    let previousRoute: AVAudioSessionRouteDescription?
    
    init(
        type: AudioFocusEventType,
        state: AudioFocusState,
        configuration: AudioFocusConfiguration,
        timestamp: Date = Date(),
        error: Error? = nil,
        interruptionType: AudioInterruptionType? = nil,
        shouldResume: Bool? = nil,
        routeChangeReason: AVAudioSession.RouteChangeReason? = nil,
        previousRoute: AVAudioSessionRouteDescription? = nil
    ) {
        self.type = type
        self.state = state
        self.configuration = configuration
        self.timestamp = timestamp
        self.error = error
        self.interruptionType = interruptionType
        self.shouldResume = shouldResume
        self.routeChangeReason = routeChangeReason
        self.previousRoute = previousRoute
    }
}

enum AudioFocusEventType: String, CaseIterable, Sendable {
    case focusGained = "focusGained"
    case focusLost = "focusLost"
    case focusRequestFailed = "focusRequestFailed"
    case focusAbandonFailed = "focusAbandonFailed"
    case interruptionBegan = "interruptionBegan"
    case interruptionEnded = "interruptionEnded"
    case routeChanged = "routeChanged"
    case outputDeviceDisconnected = "outputDeviceDisconnected"
    case outputDeviceConnected = "outputDeviceConnected"
    case categoryChanged = "categoryChanged"
    case mediaServicesReset = "mediaServicesReset"
    case mediaServicesLost = "mediaServicesLost"
    
    var displayName: String {
        switch self {
        case .focusGained:
            return "Focus Gained"
        case .focusLost:
            return "Focus Lost"
        case .focusRequestFailed:
            return "Focus Request Failed"
        case .focusAbandonFailed:
            return "Focus Abandon Failed"
        case .interruptionBegan:
            return "Interruption Began"
        case .interruptionEnded:
            return "Interruption Ended"
        case .routeChanged:
            return "Route Changed"
        case .outputDeviceDisconnected:
            return "Output Device Disconnected"
        case .outputDeviceConnected:
            return "Output Device Connected"
        case .categoryChanged:
            return "Category Changed"
        case .mediaServicesReset:
            return "Media Services Reset"
        case .mediaServicesLost:
            return "Media Services Lost"
        }
    }
}