//
//  AudioManager.swift
//  DualCameraApp
//
//  Enhanced audio management with source selection, level monitoring, and noise reduction
//

import Foundation
import AVFoundation
import UIKit

class AudioManager: NSObject {
    
    // MARK: - Properties
    
    private var audioEngine: AVAudioEngine?
    private var inputNode: AVAudioInputNode?
    private var mixer: AVAudioMixerNode?
    private var audioRecorder: AVAudioRecorder?
    private var audioFile: AVAudioFile?
    
    // Audio monitoring
    private var audioLevelTimer: Timer?
    private var audioLevelBuffer: [Float] = []
    private let maxAudioLevelSamples = 100
    private var currentAudioLevel: Float = 0.0
    
    // Noise reduction
    private var noiseReductionEnabled: Bool = true
    private var noiseGateThreshold: Float = 0.05
    private var noiseReductionGain: Float = 0.8
    
    // Audio source
    private var selectedAudioSource: AudioSource = .builtIn
    private var bluetoothDevice: BluetoothAudioDevice?
    
    // Callbacks
    var onAudioLevelChanged: ((Float) -> Void)?
    var onAudioSourceChanged: ((AudioSource) -> Void)?
    var onClippingDetected: (() -> Void)?
    
    // MARK: - Audio Source Types
    
    enum AudioSource {
        case builtIn
        case bluetooth
        case headset
        case usb
        
        var displayName: String {
            switch self {
            case .builtIn:
                return "Built-in Microphone"
            case .bluetooth:
                return "Bluetooth Microphone"
            case .headset:
                return "Headset Microphone"
            case .usb:
                return "USB Microphone"
            }
        }
    }
    
    // MARK: - Bluetooth Audio Device
    
    struct BluetoothAudioDevice {
        let name: String
        let identifier: String
        let isConnected: Bool
    }
    
    // MARK: - Initialization
    
    override init() {
        super.init()
        setupAudioSession()
        setupAudioEngine()
        loadSavedSettings()
    }
    
    deinit {
        stopAudioLevelMonitoring()
        audioEngine?.stop()
    }
    
    // MARK: - Setup
    
    private func setupAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            
            // Set category to play and record
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            
            // Set preferred sample rate and buffer duration
            try audioSession.setPreferredSampleRate(44100.0)
            try audioSession.setPreferredIOBufferDuration(0.005)
            
            // Activate audio session
            try audioSession.setActive(true)
            
            print("Audio session configured successfully")
        } catch {
            print("Failed to configure audio session: \(error)")
        }
    }
    
    private func setupAudioEngine() {
        audioEngine = AVAudioEngine()
        
        guard let audioEngine = audioEngine else { return }
        
        // Get input node
        inputNode = audioEngine.inputNode
        
        // Create mixer for audio processing
        mixer = AVAudioMixerNode()
        audioEngine.attach(mixer!)
        
        // Connect input to mixer
        let inputFormat = inputNode?.outputFormat(forBus: 0)
        if let inputFormat = inputFormat {
            audioEngine.connect(inputNode!, to: mixer!, format: inputFormat)
        }
        
        // Connect mixer to main mixer
        let mixerFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 44100, channels: 1, interleaved: false)
        if let mixerFormat = mixerFormat {
            audioEngine.connect(mixer!, to: audioEngine.mainMixerNode, format: mixerFormat)
        }
        
        // Install tap on mixer for monitoring
        if let mixerFormat = mixerFormat {
            mixer?.installTap(onBus: 0, bufferSize: 1024, format: mixerFormat) { [weak self] (buffer, time) in
                self?.processAudioBuffer(buffer)
            }
        }
        
        // Start the engine
        do {
            try audioEngine.start()
            print("Audio engine started successfully")
        } catch {
            print("Failed to start audio engine: \(error)")
        }
    }
    
    private func loadSavedSettings() {
        let settings = SettingsManager.shared
        
        // Load audio source
        if let audioSourceString = settings.audioSource as String? {
            switch audioSourceString {
            case "bluetooth":
                selectedAudioSource = .bluetooth
            case "headset":
                selectedAudioSource = .headset
            case "usb":
                selectedAudioSource = .usb
            default:
                selectedAudioSource = .builtIn
            }
        }
        
        // Load noise reduction settings
        noiseReductionEnabled = settings.enableNoiseReduction
    }
    
    // MARK: - Audio Processing
    
    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        
        let frameLength = Int(buffer.frameLength)
        var sum: Float = 0.0
        var maxValue: Float = 0.0
        
        // Calculate RMS and peak values
        for i in 0..<frameLength {
            let sample = channelData[i]
            let absSample = abs(sample)
            sum += sample * sample
            maxValue = max(maxValue, absSample)
        }
        
        // Calculate RMS (root mean square)
        let rms = sqrt(sum / Float(frameLength))
        
        // Apply noise gate if enabled
        let gatedValue = noiseReductionEnabled && rms < noiseGateThreshold ? 0.0 : rms
        
        // Apply noise reduction gain if enabled
        let processedValue = noiseReductionEnabled ? gatedValue * noiseReductionGain : gatedValue
        
        // Update current audio level
        DispatchQueue.main.async {
            self.currentAudioLevel = processedValue
            self.onAudioLevelChanged?(processedValue)
            
            // Check for clipping
            if maxValue > 0.95 {
                self.onClippingDetected?()
            }
        }
        
        // Update audio level buffer for visualization
        audioLevelBuffer.append(processedValue)
        if audioLevelBuffer.count > maxAudioLevelSamples {
            audioLevelBuffer.removeFirst()
        }
    }
    
    // MARK: - Audio Source Management
    
    func setAudioSource(_ source: AudioSource) {
        selectedAudioSource = source
        
        // Configure audio session for the selected source
        do {
            let audioSession = AVAudioSession.sharedInstance()
            
            switch source {
            case .builtIn:
                try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
                
            case .bluetooth:
                try audioSession.setCategory(.playAndRecord, mode: .default, options: [.allowBluetooth, .allowBluetoothA2DP])
                
            case .headset:
                try audioSession.setCategory(.playAndRecord, mode: .default, options: [.allowAirPlay, .allowBluetooth])
                
            case .usb:
                try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            }
            
            // Save setting
            SettingsManager.shared.audioSource = source.displayName
            
            onAudioSourceChanged?(source)
        } catch {
            print("Failed to set audio source: \(error)")
        }
    }
    
    func getAvailableAudioSources() -> [AudioSource] {
        var sources: [AudioSource] = [.builtIn]
        
        // Check for Bluetooth
        if isBluetoothAvailable() {
            sources.append(.bluetooth)
        }
        
        // Check for headset
        if isHeadsetAvailable() {
            sources.append(.headset)
        }
        
        // Check for USB
        if isUSBAudioAvailable() {
            sources.append(.usb)
        }
        
        return sources
    }
    
    private func isBluetoothAvailable() -> Bool {
        // Check if Bluetooth is available and connected
        return AVAudioSession.sharedInstance().availableInputs?.contains(where: { $0.portType == .bluetoothHFP || $0.portType == .bluetoothA2DP }) ?? false
    }
    
    private func isHeadsetAvailable() -> Bool {
        // Check if headset is available and connected
        return AVAudioSession.sharedInstance().availableInputs?.contains(where: { $0.portType == .headsetMic }) ?? false
    }
    
    private func isUSBAudioAvailable() -> Bool {
        return false
    }
    
    // MARK: - Audio Level Monitoring
    
    func startAudioLevelMonitoring() {
        stopAudioLevelMonitoring() // Stop any existing timer
        
        audioLevelTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.updateAudioLevel()
        }
    }
    
    func stopAudioLevelMonitoring() {
        audioLevelTimer?.invalidate()
        audioLevelTimer = nil
    }
    
    private func updateAudioLevel() {
        // The audio level is already updated in processAudioBuffer
        // This method can be used for additional periodic updates if needed
    }
    
    func getCurrentAudioLevel() -> Float {
        return currentAudioLevel
    }
    
    func getAudioLevelBuffer() -> [Float] {
        return audioLevelBuffer
    }
    
    // MARK: - Noise Reduction
    
    func setNoiseReductionEnabled(_ enabled: Bool) {
        noiseReductionEnabled = enabled
        SettingsManager.shared.enableNoiseReduction = enabled
    }
    
    func setNoiseGateThreshold(_ threshold: Float) {
        noiseGateThreshold = max(0.0, min(1.0, threshold))
    }
    
    func setNoiseReductionGain(_ gain: Float) {
        noiseReductionGain = max(0.0, min(1.0, gain))
    }
    
    // MARK: - Audio Recording
    
    func startAudioRecording(to url: URL) -> Bool {
        // Create audio file
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderBitRateKey: 128000,
            AVLinearPCMBitDepthKey: 16,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        do {
            audioRecorder = try AVAudioRecorder(url: url, settings: settings)
            audioRecorder?.record()
            return true
        } catch {
            print("Failed to start audio recording: \(error)")
            return false
        }
    }
    
    func stopAudioRecording() {
        audioRecorder?.stop()
        audioRecorder = nil
    }
    
    // MARK: - Audio Analysis
    
    func getAverageAudioLevel() -> Float {
        guard !audioLevelBuffer.isEmpty else { return 0.0 }
        
        let sum = audioLevelBuffer.reduce(0, +)
        return sum / Float(audioLevelBuffer.count)
    }
    
    func getPeakAudioLevel() -> Float {
        guard !audioLevelBuffer.isEmpty else { return 0.0 }
        
        return audioLevelBuffer.max() ?? 0.0
    }
    
    func isAudioClipping() -> Bool {
        return getPeakAudioLevel() > 0.95
    }
    
    // MARK: - Audio Session Management
    
    func configureForRecording() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            
            // Set category for recording
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            
            // Set preferred sample rate and buffer duration for recording
            try audioSession.setPreferredSampleRate(44100.0)
            try audioSession.setPreferredIOBufferDuration(0.005)
            
            print("Audio session configured for recording")
        } catch {
            print("Failed to configure audio session for recording: \(error)")
        }
    }
    
    func configureForPlayback() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            
            // Set category for playback
            try audioSession.setCategory(.playback, mode: .default, options: [])
            
            print("Audio session configured for playback")
        } catch {
            print("Failed to configure audio session for playback: \(error)")
        }
    }
    
    // MARK: - Public Properties
    
    var currentAudioSource: AudioSource {
        return selectedAudioSource
    }
    
    var isNoiseReductionEnabled: Bool {
        return noiseReductionEnabled
    }
}