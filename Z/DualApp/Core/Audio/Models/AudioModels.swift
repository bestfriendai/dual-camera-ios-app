//
//  AudioModels.swift
//  DualApp
//
//  Created by DualApp Team on 10/3/25.
//

import Foundation
import AVFoundation
import SwiftUI

// MARK: - Audio Configuration

struct AudioConfiguration: Sendable, Codable, Equatable {
    let sampleRate: Double
    let channels: UInt32
    let bitDepth: UInt32
    let format: AudioFormat
    let quality: AudioQuality
    let enableNoiseReduction: Bool
    let enableSpatialAudio: Bool
    let enableEchoCancellation: Bool
    let enableAutomaticGainControl: Bool
    let bufferSize: UInt32
    let enableLowLatency: Bool
    
    static let `default` = AudioConfiguration(
        sampleRate: 44100.0,
        channels: 2,
        bitDepth: 16,
        format: .m4a,
        quality: .high,
        enableNoiseReduction: true,
        enableSpatialAudio: false,
        enableEchoCancellation: true,
        enableAutomaticGainControl: true,
        bufferSize: 1024,
        enableLowLatency: false
    )
    
    static let highQuality = AudioConfiguration(
        sampleRate: 48000.0,
        channels: 2,
        bitDepth: 24,
        format: .wav,
        quality: .lossless,
        enableNoiseReduction: true,
        enableSpatialAudio: true,
        enableEchoCancellation: true,
        enableAutomaticGainControl: true,
        bufferSize: 2048,
        enableLowLatency: false
    )
    
    static let lowLatency = AudioConfiguration(
        sampleRate: 44100.0,
        channels: 2,
        bitDepth: 16,
        format: .pcm,
        quality: .medium,
        enableNoiseReduction: false,
        enableSpatialAudio: false,
        enableEchoCancellation: false,
        enableAutomaticGainControl: false,
        bufferSize: 256,
        enableLowLatency: true
    )
    
    static let professional = AudioConfiguration(
        sampleRate: 192000.0,
        channels: 2,
        bitDepth: 32,
        format: .alac,
        quality: .lossless,
        enableNoiseReduction: true,
        enableSpatialAudio: true,
        enableEchoCancellation: true,
        enableAutomaticGainControl: false,
        bufferSize: 4096,
        enableLowLatency: false
    )
}

// MARK: - Audio Format

enum AudioFormat: String, CaseIterable, Sendable, Codable {
    case m4a = "m4a"
    case wav = "wav"
    case pcm = "pcm"
    case aac = "aac"
    case alac = "alac"
    case flac = "flac"
    
    var fileExtension: String {
        return rawValue
    }
    
    var supportsCompression: Bool {
        switch self {
        case .m4a, .aac, .alac, .flac:
            return true
        case .wav, .pcm:
            return false
        }
    }
    
    var avFormatID: UInt32 {
        switch self {
        case .m4a, .aac:
            return kAudioFormatMPEG4AAC
        case .wav, .pcm:
            return kAudioFormatLinearPCM
        case .alac:
            return kAudioFormatAppleLossless
        case .flac:
            return kAudioFormatFLAC
        }
    }
    
    var displayName: String {
        switch self {
        case .m4a:
            return "AAC (M4A)"
        case .wav:
            return "WAV"
        case .pcm:
            return "PCM"
        case .aac:
            return "AAC"
        case .alac:
            return "Apple Lossless"
        case .flac:
            return "FLAC"
        }
    }
    
    var description: String {
        switch self {
        case .m4a:
            return "Compressed AAC format, good quality with small file size"
        case .wav:
            return "Uncompressed WAV format, highest quality"
        case .pcm:
            return "Raw PCM data, uncompressed"
        case .aac:
            return "Advanced Audio Coding, efficient compression"
        case .alac:
            return "Apple Lossless Audio Codec, lossless compression"
        case .flac:
            return "Free Lossless Audio Codec, open source"
        }
    }
}

// MARK: - Audio Quality

enum AudioQuality: String, CaseIterable, Sendable, Codable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case lossless = "lossless"
    case ultra = "ultra"
    
    var bitRate: Int {
        switch self {
        case .low:
            return 64000
        case .medium:
            return 128000
        case .high:
            return 256000
        case .lossless:
            return 1411000
        case .ultra:
            return 2822000
        }
    }
    
    var encoderQuality: Int {
        switch self {
        case .low:
            return AVAudioQuality.low.rawValue
        case .medium:
            return AVAudioQuality.medium.rawValue
        case .high:
            return AVAudioQuality.high.rawValue
        case .lossless:
            return AVAudioQuality.max.rawValue
        case .ultra:
            return AVAudioQuality.max.rawValue
        }
    }
    
    var displayName: String {
        switch self {
        case .low:
            return "Low (64 kbps)"
        case .medium:
            return "Medium (128 kbps)"
        case .high:
            return "High (256 kbps)"
        case .lossless:
            return "Lossless (1411 kbps)"
        case .ultra:
            return "Ultra (2822 kbps)"
        }
    }
    
    var description: String {
        switch self {
        case .low:
            return "Good for voice recordings, small file size"
        case .medium:
            return "Balanced quality and file size"
        case .high:
            return "High quality for music recordings"
        case .lossless:
            return "CD quality, no compression artifacts"
        case .ultra:
            return "Studio quality, maximum fidelity"
        }
    }
}

// MARK: - Audio State

enum AudioState: String, CaseIterable, Sendable, Codable {
    case inactive = "inactive"
    case configured = "configured"
    case recording = "recording"
    case paused = "paused"
    case playing = "playing"
    case processing = "processing"
    case interrupted = "interrupted"
    case error = "error"
    
    var canRecord: Bool {
        switch self {
        case .configured:
            return true
        default:
            return false
        }
    }
    
    var canPlay: Bool {
        switch self {
        case .configured, .paused:
            return true
        default:
            return false
        }
    }
    
    var canProcess: Bool {
        switch self {
        case .configured, .recording, .playing:
            return true
        default:
            return false
        }
    }
    
    var displayName: String {
        switch self {
        case .inactive:
            return "Inactive"
        case .configured:
            return "Ready"
        case .recording:
            return "Recording"
        case .paused:
            return "Paused"
        case .playing:
            return "Playing"
        case .processing:
            return "Processing"
        case .interrupted:
            return "Interrupted"
        case .error:
            return "Error"
        }
    }
    
    var description: String {
        switch self {
        case .inactive:
            return "Audio system is not initialized"
        case .configured:
            return "Audio system is ready for use"
        case .recording:
            return "Currently recording audio"
        case .paused:
            return "Recording is paused"
        case .playing:
            return "Currently playing audio"
        case .processing:
            return "Processing audio data"
        case .interrupted:
            return "Audio was interrupted"
        case .error:
            return "Audio system encountered an error"
        }
    }
}

// MARK: - Audio Levels

struct AudioLevels: Sendable, Codable {
    let averagePower: Float
    let peakPower: Float
    let rmsLevel: Float
    let peakLevel: Float
    let leftChannelLevel: Float
    let rightChannelLevel: Float
    let timestamp: Date
    
    init(
        averagePower: Float = -120.0,
        peakPower: Float = -120.0,
        rmsLevel: Float = 0.0,
        peakLevel: Float = 0.0,
        leftChannelLevel: Float = 0.0,
        rightChannelLevel: Float = 0.0,
        timestamp: Date = Date()
    ) {
        self.averagePower = averagePower
        self.peakPower = peakPower
        self.rmsLevel = rmsLevel
        self.peakLevel = peakLevel
        self.leftChannelLevel = leftChannelLevel
        self.rightChannelLevel = rightChannelLevel
        self.timestamp = timestamp
    }
    
    static func calculate(from buffer: AVAudioPCMBuffer) -> AudioLevels {
        guard let channelData = buffer.floatChannelData else {
            return AudioLevels()
        }
        
        let frameLength = Int(buffer.frameLength)
        let channelCount = Int(buffer.format.channelCount)
        
        var sum: Float = 0.0
        var maxPeak: Float = 0.0
        var leftSum: Float = 0.0
        var rightSum: Float = 0.0
        var leftPeak: Float = 0.0
        var rightPeak: Float = 0.0
        
        for channel in 0..<channelCount {
            let channelPointer = channelData[channel]
            
            for i in 0..<frameLength {
                let sample = abs(channelPointer[i])
                sum += sample * sample
                maxPeak = max(maxPeak, sample)
                
                if channel == 0 {
                    leftSum += sample * sample
                    leftPeak = max(leftPeak, sample)
                } else if channel == 1 {
                    rightSum += sample * sample
                    rightPeak = max(rightPeak, sample)
                }
            }
        }
        
        let rms = sqrt(sum / Float(frameLength * channelCount))
        let averagePower = 20.0 * log10(max(rms, 0.001))
        let peakPower = 20.0 * log10(max(maxPeak, 0.001))
        
        let leftRms = sqrt(leftSum / Float(frameLength))
        let leftLevel = leftRms
        
        let rightRms = sqrt(rightSum / Float(frameLength))
        let rightLevel = rightRms
        
        return AudioLevels(
            averagePower: averagePower,
            peakPower: peakPower,
            rmsLevel: rms,
            peakLevel: maxPeak,
            leftChannelLevel: leftLevel,
            rightChannelLevel: rightLevel,
            timestamp: Date()
        )
    }
    
    var normalizedLevel: Float {
        return max(0.0, min(1.0, (rmsLevel + 60.0) / 60.0))
    }
    
    var isClipping: Bool {
        return peakLevel >= 0.99
    }
    
    var isSilent: Bool {
        return rmsLevel < 0.01
    }
}

// MARK: - Audio Metrics

struct AudioMetrics: Sendable, Codable {
    let currentState: AudioState
    let currentConfiguration: AudioConfiguration
    let audioLevels: AudioLevels
    let recordingDuration: TimeInterval
    let processingLatency: TimeInterval
    let cpuUsage: Float
    let memoryUsage: UInt64
    let bufferSize: UInt32
    let sampleRate: Double
    let timestamp: Date
    
    init(
        currentState: AudioState = .inactive,
        currentConfiguration: AudioConfiguration = .default,
        audioLevels: AudioLevels = AudioLevels(),
        recordingDuration: TimeInterval = 0.0,
        processingLatency: TimeInterval = 0.0,
        cpuUsage: Float = 0.0,
        memoryUsage: UInt64 = 0,
        bufferSize: UInt32 = 1024,
        sampleRate: Double = 44100.0,
        timestamp: Date = Date()
    ) {
        self.currentState = currentState
        self.currentConfiguration = currentConfiguration
        self.audioLevels = audioLevels
        self.recordingDuration = recordingDuration
        self.processingLatency = processingLatency
        self.cpuUsage = cpuUsage
        self.memoryUsage = memoryUsage
        self.bufferSize = bufferSize
        self.sampleRate = sampleRate
        self.timestamp = timestamp
    }
}

// MARK: - Audio Events

struct AudioStateEvent: Sendable, Codable {
    let newState: AudioState
    let previousState: AudioState
    let timestamp: Date
    let metadata: [String: String]
    
    init(newState: AudioState, previousState: AudioState, metadata: [String: String] = [:]) {
        self.newState = newState
        self.previousState = previousState
        self.timestamp = Date()
        self.metadata = metadata
    }
}

struct AudioLevelEvent: Sendable, Codable {
    let levels: AudioLevels
    let timestamp: Date
    let configuration: AudioConfiguration
    
    init(levels: AudioLevels, configuration: AudioConfiguration) {
        self.levels = levels
        self.timestamp = Date()
        self.configuration = configuration
    }
}

struct AudioErrorEvent: Sendable {
    let error: AudioError
    let timestamp: Date
    let context: String
    let recovery: String?
    
    init(error: AudioError, context: String, recovery: String? = nil) {
        self.error = error
        self.timestamp = Date()
        self.context = context
        self.recovery = recovery
    }
}

// MARK: - Audio Session Configuration

struct AudioSessionConfiguration: Sendable {
    let category: AVAudioSession.Category
    let mode: AVAudioSession.Mode
    let options: AVAudioSession.CategoryOptions
    let preferredSampleRate: Double
    let preferredIOBufferDuration: TimeInterval
    let preferredOutputNumberOfChannels: Int
    let preferredInputNumberOfChannels: Int
    
    static let `default` = AudioSessionConfiguration(
        category: .playAndRecord,
        mode: .videoRecording,
        options: [.defaultToSpeaker, .allowBluetoothA2DP, .allowAirPlay],
        preferredSampleRate: 44100.0,
        preferredIOBufferDuration: 0.005,
        preferredOutputNumberOfChannels: 2,
        preferredInputNumberOfChannels: 2
    )
    
    static let recording = AudioSessionConfiguration(
        category: .playAndRecord,
        mode: .videoRecording,
        options: [.defaultToSpeaker, .allowBluetoothA2DP, .allowAirPlay, .mixWithOthers],
        preferredSampleRate: 48000.0,
        preferredIOBufferDuration: 0.005,
        preferredOutputNumberOfChannels: 2,
        preferredInputNumberOfChannels: 2
    )
    
    static let playback = AudioSessionConfiguration(
        category: .playback,
        mode: .moviePlayback,
        options: [.allowBluetoothA2DP, .allowAirPlay],
        preferredSampleRate: 44100.0,
        preferredIOBufferDuration: 0.005,
        preferredOutputNumberOfChannels: 2,
        preferredInputNumberOfChannels: 0
    )
    
    static let lowLatency = AudioSessionConfiguration(
        category: .playAndRecord,
        mode: .voiceChat,
        options: [.defaultToSpeaker, .allowBluetoothA2DP],
        preferredSampleRate: 44100.0,
        preferredIOBufferDuration: 0.002,
        preferredOutputNumberOfChannels: 2,
        preferredInputNumberOfChannels: 2
    )
}

// MARK: - Microphone Configuration

struct MicrophoneConfiguration: Sendable, Codable {
    let deviceID: String?
    let name: String
    let position: MicrophonePosition
    let polarPattern: MicrophonePolarPattern
    let gain: Float
    let enabled: Bool
    
    static let `default` = MicrophoneConfiguration(
        deviceID: nil,
        name: "Built-in Microphone",
        position: .bottom,
        polarPattern: .omnidirectional,
        gain: 1.0,
        enabled: true
    )
}

enum MicrophonePosition: String, CaseIterable, Sendable, Codable {
    case top = "top"
    case bottom = "bottom"
    case front = "front"
    case back = "back"
    case left = "left"
    case right = "right"
    
    var displayName: String {
        switch self {
        case .top:
            return "Top"
        case .bottom:
            return "Bottom"
        case .front:
            return "Front"
        case .back:
            return "Back"
        case .left:
            return "Left"
        case .right:
            return "Right"
        }
    }
}

enum MicrophonePolarPattern: String, CaseIterable, Sendable, Codable {
    case omnidirectional = "omnidirectional"
    case cardioid = "cardioid"
    case subcardioid = "subcardioid"
    case supercardioid = "supercardioid"
    case bidirectional = "bidirectional"
    
    var displayName: String {
        switch self {
        case .omnidirectional:
            return "Omnidirectional"
        case .cardioid:
            return "Cardioid"
        case .subcardioid:
            return "Subcardioid"
        case .supercardioid:
            return "Supercardioid"
        case .bidirectional:
            return "Bidirectional"
        }
    }
    
    var description: String {
        switch self {
        case .omnidirectional:
            return "Picks up sound from all directions"
        case .cardioid:
            return "Picks up sound from the front, rejects from the back"
        case .subcardioid:
            return "Less directional than cardioid"
        case .supercardioid:
            return "More directional than cardioid"
        case .bidirectional:
            return "Picks up sound from front and back"
        }
    }
}

// MARK: - Audio Presets

struct AudioPreset: Sendable, Identifiable {
    let id: UUID
    let name: String
    let description: String
    let configuration: AudioConfiguration
    let sessionConfiguration: AudioSessionConfiguration
    let microphoneConfiguration: MicrophoneConfiguration
    let isBuiltIn: Bool
    
    init(
        name: String,
        description: String,
        configuration: AudioConfiguration,
        sessionConfiguration: AudioSessionConfiguration = .default,
        microphoneConfiguration: MicrophoneConfiguration = .default,
        isBuiltIn: Bool = false
    ) {
        self.id = UUID()
        self.name = name
        self.description = description
        self.configuration = configuration
        self.sessionConfiguration = sessionConfiguration
        self.microphoneConfiguration = microphoneConfiguration
        self.isBuiltIn = isBuiltIn
    }
}

extension AudioPreset {
    static let builtInPresets: [AudioPreset] = [
        AudioPreset(
            name: "Voice Recording",
            description: "Optimized for voice recording with noise reduction",
            configuration: AudioConfiguration(
                sampleRate: 44100.0,
                channels: 1,
                bitDepth: 16,
                format: .m4a,
                quality: .high,
                enableNoiseReduction: true,
                enableSpatialAudio: false,
                enableEchoCancellation: true,
                enableAutomaticGainControl: true,
                bufferSize: 1024,
                enableLowLatency: false
            ),
            isBuiltIn: true
        ),
        
        AudioPreset(
            name: "Music Recording",
            description: "High quality stereo recording for music",
            configuration: AudioConfiguration(
                sampleRate: 48000.0,
                channels: 2,
                bitDepth: 24,
                format: .wav,
                quality: .lossless,
                enableNoiseReduction: false,
                enableSpatialAudio: true,
                enableEchoCancellation: false,
                enableAutomaticGainControl: false,
                bufferSize: 2048,
                enableLowLatency: false
            ),
            isBuiltIn: true
        ),
        
        AudioPreset(
            name: "Video Recording",
            description: "Balanced quality for video recording",
            configuration: AudioConfiguration(
                sampleRate: 48000.0,
                channels: 2,
                bitDepth: 16,
                format: .aac,
                quality: .high,
                enableNoiseReduction: true,
                enableSpatialAudio: false,
                enableEchoCancellation: true,
                enableAutomaticGainControl: true,
                bufferSize: 1024,
                enableLowLatency: false
            ),
            isBuiltIn: true
        ),
        
        AudioPreset(
            name: "Podcast",
            description: "Professional quality for podcast recording",
            configuration: AudioConfiguration(
                sampleRate: 48000.0,
                channels: 2,
                bitDepth: 24,
                format: .wav,
                quality: .lossless,
                enableNoiseReduction: true,
                enableSpatialAudio: false,
                enableEchoCancellation: true,
                enableAutomaticGainControl: true,
                bufferSize: 2048,
                enableLowLatency: false
            ),
            isBuiltIn: true
        ),
        
        AudioPreset(
            name: "Low Latency",
            description: "Minimal latency for real-time applications",
            configuration: AudioConfiguration(
                sampleRate: 44100.0,
                channels: 2,
                bitDepth: 16,
                format: .pcm,
                quality: .medium,
                enableNoiseReduction: false,
                enableSpatialAudio: false,
                enableEchoCancellation: false,
                enableAutomaticGainControl: false,
                bufferSize: 256,
                enableLowLatency: true
            ),
            isBuiltIn: true
        ),
        
        AudioPreset(
            name: "Professional",
            description: "Studio quality for professional recording",
            configuration: AudioConfiguration(
                sampleRate: 192000.0,
                channels: 2,
                bitDepth: 32,
                format: .alac,
                quality: .lossless,
                enableNoiseReduction: true,
                enableSpatialAudio: true,
                enableEchoCancellation: false,
                enableAutomaticGainControl: false,
                bufferSize: 4096,
                enableLowLatency: false
            ),
            isBuiltIn: true
        )
    ]
}