//
//  AudioManager.swift
//  DualApp
//
//  Created by DualApp Team on 10/3/25.
//

import Foundation
import AVFoundation
import SwiftUI
import Combine

// MARK: - Audio Manager Actor

// MARK: - Audio Source Enum

enum AudioSource: String, CaseIterable, Sendable {
    case builtInMic = "Built-in Microphone"
    case externalMic = "External Microphone"
    case bluetoothMic = "Bluetooth Microphone"

    var displayName: String {
        return self.rawValue
    }
}

actor AudioManager: Sendable {
    // MARK: - Singleton

    static let shared = AudioManager()

    // MARK: - State Properties
    
    private(set) var currentState: AudioState = .inactive
    private(set) var currentConfiguration: AudioConfiguration
    private(set) var currentSessionConfiguration: AudioSessionConfiguration
    private(set) var currentMicrophoneConfiguration: MicrophoneConfiguration
    private(set) var audioLevels: AudioLevels = AudioLevels()
    private(set) var availableMicrophones: [MicrophoneConfiguration] = []
    private(set) var currentPreset: AudioPreset?
    
    // MARK: - Audio Components
    
    private let audioSession: AVAudioSession
    private let audioEngine: AVAudioEngine
    private var audioProcessor: AudioProcessor?
    private var audioRecorder: AudioRecorder?
    private var audioPlayer: AudioPlayer?
    
    // MARK: - Input/Output Management
    
    private var inputNode: AVAudioInputNode?
    private var outputNode: AVAudioOutputNode?
    private var mixerNode: AVAudioMixerNode?
    private var effectNode: AVAudioUnitEffect?
    private var converterNode: AVAudioConverter?
    
    // MARK: - Level Monitoring
    
    private var levelMonitoringTimer: Timer?
    private var levelMonitoringEnabled = false
    private var levelUpdateInterval: TimeInterval = 0.05 // 20fps
    
    // MARK: - Audio Focus Management
    
    private var audioFocusManager: AudioFocusManagerCompat
    private var hasAudioFocus = false
    
    // MARK: - Event Streams
    
    let audioStateEvents: AsyncStream<AudioStateEvent>
    let audioLevelEvents: AsyncStream<AudioLevelEvent>
    let audioErrorEvents: AsyncStream<AudioErrorEvent>
    let audioFocusEvents: AsyncStream<AudioFocusEvent>
    private let audioStateContinuation: AsyncStream<AudioStateEvent>.Continuation
    private let audioLevelContinuation: AsyncStream<AudioLevelEvent>.Continuation
    private let audioErrorContinuation: AsyncStream<AudioErrorEvent>.Continuation
    private let audioFocusContinuation: AsyncStream<AudioFocusEvent>.Continuation
    
    // MARK: - Performance Monitoring
    
    private var performanceMonitor: AudioPerformanceMonitor
    private var metricsUpdateTimer: Timer?
    
    // MARK: - Initialization
    
    init() {
        self.audioSession = AVAudioSession.sharedInstance()
        self.audioEngine = AVAudioEngine()
        self.currentConfiguration = AudioConfiguration.default
        self.currentSessionConfiguration = AudioSessionConfiguration.default
        self.currentMicrophoneConfiguration = MicrophoneConfiguration.default
        self.audioFocusManager = AudioFocusManagerCompat()
        self.performanceMonitor = AudioPerformanceMonitor()
        
        // Create event streams
        (audioStateEvents, audioStateContinuation) = AsyncStream.makeStream()
        (audioLevelEvents, audioLevelContinuation) = AsyncStream.makeStream()
        (audioErrorEvents, audioErrorContinuation) = AsyncStream.makeStream()
        (audioFocusEvents, audioFocusContinuation) = AsyncStream.makeStream()
        
        Task {
            await initializeAudioManager()
        }
    }
    
    // MARK: - Public Interface
    
    func configureForRecording() async throws {
        guard currentState == .inactive else {
            throw AudioError.invalidState("Audio manager must be inactive to configure")
        }
        
        await updateState(.configuring)
        
        do {
            // Configure audio session
            try await configureAudioSession(currentSessionConfiguration)
            
            // Discover available microphones
            await discoverMicrophones()
            
            // Configure audio engine
            try await configureAudioEngine()
            
            // Initialize audio processor
            await initializeAudioProcessor()
            
            // Initialize audio recorder
            await initializeAudioRecorder()
            
            // Set up level monitoring
            await setupLevelMonitoring()
            
            // Set up performance monitoring
            await setupPerformanceMonitoring()
            
            // Request audio focus
            try await requestAudioFocus()
            
            await updateState(.configured)
            
        } catch {
            await handleAudioError(error)
            throw error
        }
    }
    
    func startRecording() async throws -> URL {
        guard currentState == .configured else {
            throw AudioError.invalidState("Audio not configured for recording")
        }
        
        guard hasAudioFocus else {
            throw AudioError.sessionNotActive
        }
        
        do {
            // Start audio engine
            try audioEngine.start()
            
            // Start recording
            let recordingURL = try await audioRecorder?.startRecording(
                configuration: currentConfiguration
            ) ?? generateRecordingURL()
            
            // Start level monitoring
            await startLevelMonitoring()
            
            // Start performance monitoring
            await startPerformanceMonitoring()
            
            await updateState(.recording)
            
            return recordingURL
            
        } catch {
            await handleAudioError(error)
            throw error
        }
    }
    
    func stopRecording() async throws -> URL {
        guard currentState == .recording else {
            throw AudioError.invalidState("Not currently recording")
        }
        
        do {
            // Stop recording
            let recordingURL = try await audioRecorder?.stopRecording() ?? generateRecordingURL()
            
            // Stop audio engine
            audioEngine.stop()
            
            // Stop level monitoring
            await stopLevelMonitoring()
            
            // Stop performance monitoring
            await stopPerformanceMonitoring()
            
            await updateState(.configured)
            
            return recordingURL
            
        } catch {
            await handleAudioError(error)
            throw error
        }
    }
    
    func pauseRecording() async throws {
        guard currentState == .recording else {
            throw AudioError.invalidState("Not currently recording")
        }
        
        do {
            try await audioRecorder?.pauseRecording()
            await updateState(.paused)
        } catch {
            await handleAudioError(error)
            throw error
        }
    }
    
    func resumeRecording() async throws {
        guard currentState == .paused else {
            throw AudioError.invalidState("Not currently paused")
        }
        
        do {
            try await audioRecorder?.resumeRecording()
            await updateState(.recording)
        } catch {
            await handleAudioError(error)
            throw error
        }
    }
    
    func updateConfiguration(_ configuration: AudioConfiguration) async throws {
        guard currentState != .recording else {
            throw AudioError.invalidState("Cannot change configuration during recording")
        }
        
        currentConfiguration = configuration
        
        // Apply configuration to audio components
        try await audioProcessor?.updateConfiguration(configuration)
        try await audioRecorder?.updateConfiguration(configuration)
        
        // Reconfigure audio session if needed
        if configuration.sampleRate != currentSessionConfiguration.preferredSampleRate {
            let newSessionConfig = AudioSessionConfiguration(
                category: currentSessionConfiguration.category,
                mode: currentSessionConfiguration.mode,
                options: currentSessionConfiguration.options,
                preferredSampleRate: configuration.sampleRate,
                preferredIOBufferDuration: currentSessionConfiguration.preferredIOBufferDuration,
                preferredOutputNumberOfChannels: currentSessionConfiguration.preferredOutputNumberOfChannels,
                preferredInputNumberOfChannels: Int(configuration.channels)
            )
            
            try await configureAudioSession(newSessionConfig)
            currentSessionConfiguration = newSessionConfig
        }
        
        await notifyConfigurationChanged(configuration)
    }
    
    func updateMicrophoneConfiguration(_ configuration: MicrophoneConfiguration) async throws {
        guard currentState != .recording else {
            throw AudioError.invalidState("Cannot change microphone during recording")
        }
        
        currentMicrophoneConfiguration = configuration
        
        // Apply microphone configuration
        try await applyMicrophoneConfiguration(configuration)
    }
    
    func applyPreset(_ preset: AudioPreset) async throws {
        guard currentState != .recording else {
            throw AudioError.invalidState("Cannot change preset during recording")
        }
        
        currentPreset = preset
        
        // Apply preset configuration
        try await updateConfiguration(preset.configuration)
        try await configureAudioSession(preset.sessionConfiguration)
        try await updateMicrophoneConfiguration(preset.microphoneConfiguration)
        
        currentSessionConfiguration = preset.sessionConfiguration
        currentMicrophoneConfiguration = preset.microphoneConfiguration
    }
    
    func getAudioMetrics() async -> AudioMetrics {
        return AudioMetrics(
            currentState: currentState,
            currentConfiguration: currentConfiguration,
            audioLevels: audioLevels,
            recordingDuration: audioRecorder?.recordingDuration ?? 0.0,
            processingLatency: audioProcessor?.currentLatency ?? 0.0,
            cpuUsage: await performanceMonitor.getCurrentCPUUsage(),
            memoryUsage: await performanceMonitor.getCurrentMemoryUsage(),
            bufferSize: currentConfiguration.bufferSize,
            sampleRate: currentConfiguration.sampleRate,
            timestamp: Date()
        )
    }
    
    func getAvailableMicrophones() async -> [MicrophoneConfiguration] {
        return availableMicrophones
    }
    
    func setMicrophone(_ microphone: MicrophoneConfiguration) async throws {
        guard currentState != .recording else {
            throw AudioError.invalidState("Cannot change microphone during recording")
        }
        
        currentMicrophoneConfiguration = microphone
        try await applyMicrophoneConfiguration(microphone)
    }
    
    func muteRecording(_ mute: Bool) async throws {
        guard currentState == .recording else {
            throw AudioError.invalidState("Not currently recording")
        }
        
        inputNode?.volume = mute ? 0.0 : 1.0
    }
    
    func setGain(_ gain: Float) async throws {
        guard currentState == .recording || currentState == .configured else {
            throw AudioError.invalidState("Audio not ready for gain adjustment")
        }
        
        let clampedGain = max(0.0, min(gain, 2.0))
        inputNode?.volume = clampedGain
    }
    
    // MARK: - Private Methods
    
    private func initializeAudioManager() async {
        await setupAudioSessionNotifications()
        await discoverMicrophones()
    }
    
    private func configureAudioSession(_ configuration: AudioSessionConfiguration) async throws {
        do {
            try audioSession.setCategory(
                configuration.category,
                mode: configuration.mode,
                options: configuration.options
            )
            
            try audioSession.setPreferredSampleRate(configuration.preferredSampleRate)
            try audioSession.setPreferredIOBufferDuration(configuration.preferredIOBufferDuration)
            try audioSession.setPreferredOutputNumberOfChannels(configuration.preferredOutputNumberOfChannels)
            try audioSession.setPreferredInputNumberOfChannels(configuration.preferredInputNumberOfChannels)
            
            try audioSession.setActive(true)
            
        } catch {
            throw AudioError.sessionFailed(error)
        }
    }
    
    private func configureAudioEngine() async throws {
        // Get input and output nodes
        inputNode = audioEngine.inputNode
        outputNode = audioEngine.outputNode
        
        guard let inputNode = inputNode, let outputNode = outputNode else {
            throw AudioError.hardwareUnavailable
        }
        
        // Create mixer node
        mixerNode = AVAudioMixerNode()
        guard let mixerNode = mixerNode else {
            throw AudioError.processingFailed("Failed to create mixer node")
        }
        
        // Create effect node
        effectNode = AVAudioUnitEffect()
        guard let effectNode = effectNode else {
            throw AudioError.processingFailed("Failed to create effect node")
        }
        
        // Attach nodes
        audioEngine.attach(mixerNode)
        audioEngine.attach(effectNode)
        
        // Set input format
        let inputFormat = inputNode.outputFormat(forBus: 0)
        
        // Connect nodes
        audioEngine.connect(inputNode, to: mixerNode, format: inputFormat)
        audioEngine.connect(mixerNode, to: effectNode, format: inputFormat)
        audioEngine.connect(effectNode, to: outputNode, format: inputFormat)
        
        // Install tap for level monitoring
        mixerNode.installTap(
            onBus: 0,
            bufferSize: currentConfiguration.bufferSize,
            format: inputFormat
        ) { [weak self] buffer, _ in
            Task { @MainActor in
                await self?.processAudioBuffer(buffer)
            }
        }
    }
    
    private func initializeAudioProcessor() async {
        audioProcessor = AudioProcessor(configuration: currentConfiguration)
    }
    
    private func initializeAudioRecorder() async {
        audioRecorder = AudioRecorder(configuration: currentConfiguration)
    }
    
    private func discoverMicrophones() async {
        var microphones: [MicrophoneConfiguration] = []
        
        // Get built-in microphones
        if let availableInputs = audioSession.availableInputs {
            for input in availableInputs {
                if let portDesc = input as? AVAudioSessionPortDescription {
                    let microphone = MicrophoneConfiguration(
                        deviceID: portDesc.uid,
                        name: portDesc.portName,
                        position: getMicrophonePosition(from: portDesc.portType),
                        polarPattern: getMicrophonePolarPattern(from: portDesc),
                        gain: 1.0,
                        enabled: true
                    )
                    microphones.append(microphone)
                }
            }
        }
        
        availableMicrophones = microphones
        
        // Set default microphone if none selected
        if currentMicrophoneConfiguration.deviceID == nil && !microphones.isEmpty {
            currentMicrophoneConfiguration = microphones.first!
        }
    }
    
    private func getMicrophonePosition(from portType: AVAudioSession.Port) -> MicrophonePosition {
        switch portType {
        case .builtInMic:
            return .bottom
        case .builtInReceiver:
            return .top
        case .builtInSpeaker:
            return .bottom
        default:
            return .bottom
        }
    }
    
    private func getMicrophonePolarPattern(from portDesc: AVAudioSessionPortDescription) -> MicrophonePolarPattern {
        // Default to omnidirectional for built-in microphones
        return .omnidirectional
    }
    
    private func applyMicrophoneConfiguration(_ configuration: MicrophoneConfiguration) async throws {
        // Set preferred input if specified
        if let deviceID = configuration.deviceID,
           let availableInputs = audioSession.availableInputs {
            for input in availableInputs {
                if let portDesc = input as? AVAudioSessionPortDescription,
                   portDesc.uid == deviceID {
                    try audioSession.setPreferredInput(portDesc)
                    break
                }
            }
        }
        
        // Apply gain
        inputNode?.volume = configuration.gain
    }
    
    private func setupLevelMonitoring() async {
        levelUpdateInterval = currentConfiguration.enableLowLatency ? 0.02 : 0.05
    }
    
    private func startLevelMonitoring() async {
        guard !levelMonitoringEnabled else { return }
        
        levelMonitoringEnabled = true
        
        levelMonitoringTimer = Timer.scheduledTimer(withTimeInterval: levelUpdateInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.updateAudioLevels()
            }
        }
    }
    
    private func stopLevelMonitoring() async {
        levelMonitoringEnabled = false
        levelMonitoringTimer?.invalidate()
        levelMonitoringTimer = nil
    }
    
    private func updateAudioLevels() async {
        guard levelMonitoringEnabled else { return }
        
        // Audio levels are updated in processAudioBuffer:
        // This method can be used for additional level calculations if needed
    }
    
    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) async {
        guard levelMonitoringEnabled else { return }
        
        // Calculate audio levels
        let levels = AudioLevels.calculate(from: buffer)
        audioLevels = levels
        
        // Send level event
        let event = AudioLevelEvent(
            levels: levels,
            configuration: currentConfiguration
        )
        audioLevelContinuation.yield(event)
        
        // Process audio through processor
        if let processedBuffer = await audioProcessor?.processBuffer(buffer) {
            // The processed buffer would be used for recording
            // This is handled by the audio recorder
        }
        
        // Update performance metrics
        await performanceMonitor.recordAudioBuffer(buffer)
    }
    
    private func setupPerformanceMonitoring() async {
        await performanceMonitor.startMonitoring()
    }
    
    private func startPerformanceMonitoring() async {
        metricsUpdateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.updatePerformanceMetrics()
            }
        }
    }
    
    private func stopPerformanceMonitoring() async {
        metricsUpdateTimer?.invalidate()
        metricsUpdateTimer = nil
        await performanceMonitor.stopMonitoring()
    }
    
    private func updatePerformanceMetrics() async {
        // Performance metrics are updated continuously
        // This method can be used for periodic checks
    }
    
    private func requestAudioFocus() async throws {
        do {
            try await audioFocusManager.requestFocus()
            hasAudioFocus = true
            
            let event = AudioFocusEvent(
                type: .gained,
                timestamp: Date()
            )
            audioFocusContinuation.yield(event)
            
        } catch {
            throw AudioError.permissionDenied("Audio focus")
        }
    }
    
    private func abandonAudioFocus() async {
        await audioFocusManager.abandonFocus()
        hasAudioFocus = false
        
        let event = AudioFocusEvent(
            type: .lost,
            timestamp: Date()
        )
        audioFocusContinuation.yield(event)
    }
    
    private func setupAudioSessionNotifications() async {
        // Route change notification
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor in
                await self?.handleRouteChange(notification)
            }
        }
        
        // Interruption notification
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor in
                await self?.handleInterruption(notification)
            }
        }
        
        // Media services reset notification
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.mediaServicesWereResetNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.handleMediaServicesReset()
            }
        }
        
        // Media services lost notification
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.mediaServicesWereLostNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.handleMediaServicesLost()
            }
        }
    }
    
    private func handleRouteChange(_ notification: Notification) async {
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
            return
        }
        
        await handleRouteChangeReason(reason)
    }
    
    private func handleRouteChangeReason(_ reason: AVAudioSession.RouteChangeReason) async {
        switch reason {
        case .newDeviceAvailable:
            await discoverMicrophones()
        case .oldDeviceUnavailable:
            await discoverMicrophones()
        case .categoryChange:
            // Handle category change
            break
        case .override:
            // Handle route override
            break
        case .wakeFromSleep:
            // Handle wake from sleep
            break
        case .noSuitableRouteForCategory:
            await handleAudioError(AudioError.sessionCategoryNotAvailable)
        case .routeConfigurationChange:
            // Handle route configuration change
            break
        @unknown default:
            break
        }
    }
    
    private func handleInterruption(_ notification: Notification) async {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }
        
        switch type {
        case .began:
            await handleInterruptionBegan()
        case .ended:
            await handleInterruptionEnded(userInfo)
        @unknown default:
            break
        }
    }
    
    private func handleInterruptionBegan() async {
        if currentState == .recording {
            try? await pauseRecording()
        }
        
        await updateState(.interrupted)
        hasAudioFocus = false
        
        let event = AudioFocusEvent(
            type: .lost,
            timestamp: Date()
        )
        audioFocusContinuation.yield(event)
    }
    
    private func handleInterruptionEnded(_ userInfo: [AnyHashable: Any]) async {
        // Check if we should resume
        let shouldResume = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
        let shouldResumeOption = AVAudioSession.InterruptionOptions(rawValue: shouldResume)
        
        if shouldResumeOption.contains(.shouldResume) {
            do {
                try await requestAudioFocus()
                if currentState == .interrupted {
                    try? await resumeRecording()
                }
            } catch {
                await handleAudioError(error)
            }
        }
    }
    
    private func handleMediaServicesReset() async {
        // Reconfigure audio session and engine
        do {
            try await configureAudioSession(currentSessionConfiguration)
            try await configureAudioEngine()
            
            if currentState == .recording {
                try? await resumeRecording()
            }
        } catch {
            await handleAudioError(error)
        }
    }
    
    private func handleMediaServicesLost() async {
        await updateState(.error(AudioError.hardwareUnavailable))
        await handleAudioError(AudioError.hardwareUnavailable)
    }
    
    private func updateState(_ newState: AudioState) async {
        let previousState = currentState
        currentState = newState
        
        let event = AudioStateEvent(
            newState: newState,
            previousState: previousState
        )
        audioStateContinuation.yield(event)
    }
    
    private func notifyConfigurationChanged(_ configuration: AudioConfiguration) async {
        // Send configuration change notification
        // This can be used to update UI components
    }
    
    private func handleAudioError(_ error: Error) async {
        let audioError = error as? AudioError ?? AudioError.unknown(error.localizedDescription)
        
        let event = AudioErrorEvent(
            error: audioError,
            context: "AudioManager operation",
            recovery: audioError.recoverySuggestion
        )
        audioErrorContinuation.yield(event)
        
        // Update state if necessary
        if case .critical = audioError.severity {
            await updateState(.error(audioError))
        }
    }
    
    private func generateRecordingURL() -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let timestamp = Int(Date().timeIntervalSince1970)
        let filename = "audio_\(timestamp).\(currentConfiguration.format.fileExtension)"
        return documentsPath.appendingPathComponent(filename)
    }
    
    // MARK: - Cleanup
    
    deinit {
        Task { @MainActor in
            await stopLevelMonitoring()
            await stopPerformanceMonitoring()
            await abandonAudioFocus()
            
            // Remove notification observers
            NotificationCenter.default.removeObserver(self)
        }
    }
}

// MARK: - Audio Focus Manager (Compatibility)

actor AudioFocusManagerCompat: Sendable {
    private var hasFocus = false

    func requestFocus() async throws {
        hasFocus = true
    }

    func abandonFocus() async {
        hasFocus = false
    }
    
    func requestFocus() async throws {
        // Implementation for requesting audio focus
        hasFocus = true
    }
    
    func abandonFocus() async {
        // Implementation for abandoning audio focus
        hasFocus = false
    }
    
    var currentFocusState: Bool {
        return hasFocus
    }
}

// MARK: - Audio Performance Monitor

actor AudioPerformanceMonitor: Sendable {
    private var isMonitoring = false
    private var cpuUsage: Float = 0.0
    private var memoryUsage: UInt64 = 0
    private var bufferCount: Int = 0
    private var droppedBuffers: Int = 0
    
    func startMonitoring() async {
        isMonitoring = true
    }
    
    func stopMonitoring() async {
        isMonitoring = false
    }
    
    func recordAudioBuffer(_ buffer: AVAudioPCMBuffer) async {
        guard isMonitoring else { return }
        bufferCount += 1
    }
    
    func getCurrentCPUUsage() async -> Float {
        return cpuUsage
    }
    
    func getCurrentMemoryUsage() async -> UInt64 {
        return memoryUsage
    }
    
    func getBufferDropRate() async -> Float {
        guard bufferCount > 0 else { return 0.0 }
        return Float(droppedBuffers) / Float(bufferCount)
    }
}

// MARK: - AudioManager Compatibility Extension

extension AudioManager {
    // MARK: - Compatibility Properties

    var currentAudioSource: AudioSource {
        // Map current microphone configuration to AudioSource
        if availableMicrophones.isEmpty {
            return .builtInMic
        }

        let currentMic = currentMicrophoneConfiguration
        switch currentMic.position {
        case .bottom, .top:
            return .builtInMic
        case .external:
            return .externalMic
        case .bluetooth:
            return .bluetoothMic
        }
    }

    var isNoiseReductionEnabled: Bool {
        return currentConfiguration.noiseReduction.enabled
    }

    // MARK: - Compatibility Methods

    func getAvailableAudioSources() -> [AudioSource] {
        return AudioSource.allCases
    }

    func setAudioSource(_ source: AudioSource) {
        Task {
            // Find matching microphone configuration
            let matchingMic = availableMicrophones.first { mic in
                switch source {
                case .builtInMic:
                    return mic.position == .bottom || mic.position == .top
                case .externalMic:
                    return mic.position == .external
                case .bluetoothMic:
                    return mic.position == .bluetooth
                }
            }

            if let mic = matchingMic {
                try? await applyMicrophoneConfiguration(mic)
            }
        }
    }

    func setNoiseReductionEnabled(_ enabled: Bool) {
        Task {
            var newConfig = currentConfiguration
            newConfig.noiseReduction.enabled = enabled
            try? await updateConfiguration(newConfig)
        }
    }

    func setNoiseReductionGain(_ gain: Float) {
        Task {
            var newConfig = currentConfiguration
            newConfig.noiseReduction.gain = gain
            try? await updateConfiguration(newConfig)
        }
    }

    func startAudioLevelMonitoring() {
        Task {
            try? await startLevelMonitoring()
        }
    }

    func stopAudioLevelMonitoring() {
        Task {
            await stopLevelMonitoring()
        }
    }

    // MARK: - Callback Properties (for compatibility)

    var onAudioLevelChanged: ((Float) -> Void)? {
        get { nil }
        set { /* Store callback if needed */ }
    }

    var onClippingDetected: (() -> Void)? {
        get { nil }
        set { /* Store callback if needed */ }
    }
}