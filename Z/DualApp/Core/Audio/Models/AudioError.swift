//
//  AudioError.swift
//  DualApp
//
//  Created by DualApp Team on 10/3/25.
//

import Foundation
import AVFoundation

// MARK: - Audio Error

enum AudioError: LocalizedError, Sendable {
    // Configuration Errors
    case configurationFailed(String)
    case invalidConfiguration(String)
    case configurationNotSupported(String)
    case configurationConflict(String)
    
    // Session Errors
    case sessionFailed(Error)
    case sessionNotActive
    case sessionAlreadyActive
    case sessionInterrupted
    case sessionCategoryNotAvailable
    case sessionModeNotAvailable
    case sessionOptionsNotAvailable
    
    // Recording Errors
    case alreadyRecording
    case notRecording
    case recordingFailed(String)
    case recordingStoppedUnexpectedly
    case recordingLimitExceeded
    case recordingSpaceInsufficient
    case recordingFormatNotSupported
    case recordingDeviceNotAvailable
    case recordingPermissionDenied
    
    // Playback Errors
    case playbackFailed(String)
    case playbackInterrupted
    case playbackDeviceNotAvailable
    case playbackFormatNotSupported
    case playbackFileNotFound
    case playbackFileCorrupted
    
    // Processing Errors
    case processingFailed(String)
    case processingLatencyTooHigh
    case processingOverload
    case processingNotAvailable
    case processingChainBroken
    
    // Hardware Errors
    case hardwareUnavailable
    case hardwareNotSupported
    case hardwareConfigurationFailed
    case hardwareOverloaded
    case hardwareThermalLimit
    case hardwareBatteryLow
    
    // Format Errors
    case formatNotSupported
    case formatConversionFailed
    case formatInvalid
    case codecNotAvailable
    case sampleRateNotSupported
    case bitDepthNotSupported
    case channelCountNotSupported
    
    // File System Errors
    case fileSystemError(String)
    case fileNotFound(String)
    case filePermissionDenied(String)
    case fileCorrupted(String)
    case diskSpaceInsufficient
    case directoryNotFound(String)
    case directoryPermissionDenied(String)
    
    // Network Errors
    case networkUnavailable
    case networkTimeout
    case networkAuthenticationFailed
    case networkServerError(Int)
    case networkConnectionLost
    
    // Permission Errors
    case permissionDenied(String)
    case permissionRestricted(String)
    case permissionNotDetermined
    case permissionSystemDenied
    
    // State Errors
    case invalidState(String)
    case stateTransitionFailed(String)
    case operationNotAvailableInCurrentState(String)
    case resourceNotAvailable(String)
    
    // Memory Errors
    case memoryInsufficient
    case memoryAllocationFailed
    case bufferOverflow
    case bufferUnderflow
    
    // Synchronization Errors
    case synchronizationFailed(String)
    case timingMismatch
    case driftExceeded
    case clockNotAvailable
    
    // Export Errors
    case exportFailed(String)
    
    // Unknown Errors
    case unknown(String)
    
    var errorDescription: String? {
        switch self {
        // Configuration Errors
        case .configurationFailed(let reason):
            return "Audio configuration failed: \(reason)"
        case .invalidConfiguration(let reason):
            return "Invalid audio configuration: \(reason)"
        case .configurationNotSupported(let reason):
            return "Audio configuration not supported: \(reason)"
        case .configurationConflict(let reason):
            return "Audio configuration conflict: \(reason)"
            
        // Session Errors
        case .sessionFailed(let error):
            return "Audio session failed: \(error.localizedDescription)"
        case .sessionNotActive:
            return "Audio session is not active"
        case .sessionAlreadyActive:
            return "Audio session is already active"
        case .sessionInterrupted:
            return "Audio session was interrupted"
        case .sessionCategoryNotAvailable:
            return "Audio session category is not available"
        case .sessionModeNotAvailable:
            return "Audio session mode is not available"
        case .sessionOptionsNotAvailable:
            return "Audio session options are not available"
            
        // Recording Errors
        case .alreadyRecording:
            return "Already recording audio"
        case .notRecording:
            return "Not currently recording"
        case .recordingFailed(let reason):
            return "Audio recording failed: \(reason)"
        case .recordingStoppedUnexpectedly:
            return "Audio recording stopped unexpectedly"
        case .recordingLimitExceeded:
            return "Audio recording limit exceeded"
        case .recordingSpaceInsufficient:
            return "Insufficient storage space for recording"
        case .recordingFormatNotSupported:
            return "Audio recording format is not supported"
        case .recordingDeviceNotAvailable:
            return "Audio recording device is not available"
        case .recordingPermissionDenied:
            return "Audio recording permission is denied"
            
        // Playback Errors
        case .playbackFailed(let reason):
            return "Audio playback failed: \(reason)"
        case .playbackInterrupted:
            return "Audio playback was interrupted"
        case .playbackDeviceNotAvailable:
            return "Audio playback device is not available"
        case .playbackFormatNotSupported:
            return "Audio playback format is not supported"
        case .playbackFileNotFound:
            return "Audio playback file was not found"
        case .playbackFileCorrupted:
            return "Audio playback file is corrupted"
            
        // Processing Errors
        case .processingFailed(let reason):
            return "Audio processing failed: \(reason)"
        case .processingLatencyTooHigh:
            return "Audio processing latency is too high"
        case .processingOverload:
            return "Audio processing is overloaded"
        case .processingNotAvailable:
            return "Audio processing is not available"
        case .processingChainBroken:
            return "Audio processing chain is broken"
            
        // Hardware Errors
        case .hardwareUnavailable:
            return "Audio hardware is unavailable"
        case .hardwareNotSupported:
            return "Audio hardware is not supported"
        case .hardwareConfigurationFailed:
            return "Audio hardware configuration failed"
        case .hardwareOverloaded:
            return "Audio hardware is overloaded"
        case .hardwareThermalLimit:
            return "Audio hardware thermal limit reached"
        case .hardwareBatteryLow:
            return "Audio hardware battery is too low"
            
        // Format Errors
        case .formatNotSupported:
            return "Audio format is not supported"
        case .formatConversionFailed:
            return "Audio format conversion failed"
        case .formatInvalid:
            return "Audio format is invalid"
        case .codecNotAvailable:
            return "Audio codec is not available"
        case .sampleRateNotSupported:
            return "Audio sample rate is not supported"
        case .bitDepthNotSupported:
            return "Audio bit depth is not supported"
        case .channelCountNotSupported:
            return "Audio channel count is not supported"
            
        // File System Errors
        case .fileSystemError(let reason):
            return "File system error: \(reason)"
        case .fileNotFound(let path):
            return "File not found: \(path)"
        case .filePermissionDenied(let path):
            return "File permission denied: \(path)"
        case .fileCorrupted(let path):
            return "File is corrupted: \(path)"
        case .diskSpaceInsufficient:
            return "Insufficient disk space"
        case .directoryNotFound(let path):
            return "Directory not found: \(path)"
        case .directoryPermissionDenied(let path):
            return "Directory permission denied: \(path)"
            
        // Network Errors
        case .networkUnavailable:
            return "Network is unavailable"
        case .networkTimeout:
            return "Network request timed out"
        case .networkAuthenticationFailed:
            return "Network authentication failed"
        case .networkServerError(let code):
            return "Network server error: \(code)"
        case .networkConnectionLost:
            return "Network connection was lost"
            
        // Permission Errors
        case .permissionDenied(let permission):
            return "Permission denied: \(permission)"
        case .permissionRestricted(let permission):
            return "Permission restricted: \(permission)"
        case .permissionNotDetermined:
            return "Permission has not been determined"
        case .permissionSystemDenied:
            return "Permission denied by system"
            
        // State Errors
        case .invalidState(let state):
            return "Invalid audio state: \(state)"
        case .stateTransitionFailed(let transition):
            return "State transition failed: \(transition)"
        case .operationNotAvailableInCurrentState(let operation):
            return "Operation not available in current state: \(operation)"
        case .resourceNotAvailable(let resource):
            return "Resource not available: \(resource)"
            
        // Memory Errors
        case .memoryInsufficient:
            return "Insufficient memory for audio operation"
        case .memoryAllocationFailed:
            return "Memory allocation failed for audio operation"
        case .bufferOverflow:
            return "Audio buffer overflow"
        case .bufferUnderflow:
            return "Audio buffer underflow"
            
        // Synchronization Errors
        case .synchronizationFailed(let reason):
            return "Audio synchronization failed: \(reason)"
        case .timingMismatch:
            return "Audio timing mismatch"
        case .driftExceeded:
            return "Audio drift exceeded limits"
        case .clockNotAvailable:
            return "Audio clock is not available"
            
        // Export Errors
        case .exportFailed(let reason):
            return "Audio export failed: \(reason)"
            
        // Unknown Errors
        case .unknown(let reason):
            return "Unknown audio error: \(reason)"
        }
    }
    
    var failureReason: String? {
        switch self {
        case .configurationFailed:
            return "The audio system could not be configured with the specified parameters"
        case .invalidConfiguration:
            return "The provided audio configuration contains invalid parameters"
        case .configurationNotSupported:
            return "The audio configuration is not supported by the current hardware"
        case .configurationConflict:
            return "The audio configuration conflicts with existing settings"
            
        case .sessionFailed:
            return "The audio session encountered an error during operation"
        case .sessionNotActive:
            return "The audio session must be active before performing this operation"
        case .sessionAlreadyActive:
            return "The audio session is already active"
        case .sessionInterrupted:
            return "The audio session was interrupted by the system or another app"
        case .sessionCategoryNotAvailable:
            return "The requested audio session category is not available"
        case .sessionModeNotAvailable:
            return "The requested audio session mode is not available"
        case .sessionOptionsNotAvailable:
            return "The requested audio session options are not available"
            
        case .alreadyRecording:
            return "Cannot start recording while already recording"
        case .notRecording:
            return "Cannot stop recording when not currently recording"
        case .recordingFailed:
            return "The audio recording encountered an error and could not continue"
        case .recordingStoppedUnexpectedly:
            return "The audio recording stopped unexpectedly"
        case .recordingLimitExceeded:
            return "The audio recording exceeded the maximum allowed duration"
        case .recordingSpaceInsufficient:
            return "There is not enough storage space to continue recording"
        case .recordingFormatNotSupported:
            return "The requested audio recording format is not supported"
        case .recordingDeviceNotAvailable:
            return "No audio recording device is available"
        case .recordingPermissionDenied:
            return "Audio recording permission has been denied"
            
        case .playbackFailed:
            return "The audio playback encountered an error and could not continue"
        case .playbackInterrupted:
            return "The audio playback was interrupted by the system or another app"
        case .playbackDeviceNotAvailable:
            return "No audio playback device is available"
        case .playbackFormatNotSupported:
            return "The requested audio playback format is not supported"
        case .playbackFileNotFound:
            return "The audio file for playback was not found"
        case .playbackFileCorrupted:
            return "The audio file for playback is corrupted and cannot be played"
            
        case .processingFailed:
            return "The audio processing encountered an error and could not continue"
        case .processingLatencyTooHigh:
            return "The audio processing latency is too high for real-time operation"
        case .processingOverload:
            return "The audio processing system is overloaded"
        case .processingNotAvailable:
            return "Audio processing is not available on this device"
        case .processingChainBroken:
            return "The audio processing chain is broken"
            
        case .hardwareUnavailable:
            return "The audio hardware is currently unavailable"
        case .hardwareNotSupported:
            return "The audio hardware is not supported on this device"
        case .hardwareConfigurationFailed:
            return "The audio hardware configuration failed"
        case .hardwareOverloaded:
            return "The audio hardware is overloaded"
        case .hardwareThermalLimit:
            return "The audio hardware has reached its thermal limit"
        case .hardwareBatteryLow:
            return "The audio hardware battery is too low for operation"
            
        case .formatNotSupported:
            return "The audio format is not supported"
        case .formatConversionFailed:
            return "The audio format conversion failed"
        case .formatInvalid:
            return "The audio format is invalid"
        case .codecNotAvailable:
            return "The audio codec is not available"
        case .sampleRateNotSupported:
            return "The audio sample rate is not supported"
        case .bitDepthNotSupported:
            return "The audio bit depth is not supported"
        case .channelCountNotSupported:
            return "The audio channel count is not supported"
            
        case .fileSystemError:
            return "A file system error occurred"
        case .fileNotFound:
            return "The requested file was not found"
        case .filePermissionDenied:
            return "Permission to access the file was denied"
        case .fileCorrupted:
            return "The file is corrupted and cannot be used"
        case .diskSpaceInsufficient:
            return "There is insufficient disk space available"
        case .directoryNotFound:
            return "The requested directory was not found"
        case .directoryPermissionDenied:
            return "Permission to access the directory was denied"
            
        case .networkUnavailable:
            return "The network is not available"
        case .networkTimeout:
            return "The network request timed out"
        case .networkAuthenticationFailed:
            return "Network authentication failed"
        case .networkServerError:
            return "The network server returned an error"
        case .networkConnectionLost:
            return "The network connection was lost"
            
        case .permissionDenied:
            return "The required permission has been denied"
        case .permissionRestricted:
            return "The required permission is restricted"
        case .permissionNotDetermined:
            return "The required permission has not been determined"
        case .permissionSystemDenied:
            return "The permission was denied by the system"
            
        case .invalidState:
            return "The audio system is in an invalid state"
        case .stateTransitionFailed:
            return "The state transition failed"
        case .operationNotAvailableInCurrentState:
            return "The operation is not available in the current state"
        case .resourceNotAvailable:
            return "The required resource is not available"
            
        case .memoryInsufficient:
            return "There is insufficient memory for the audio operation"
        case .memoryAllocationFailed:
            return "Memory allocation failed for the audio operation"
        case .bufferOverflow:
            return "The audio buffer has overflowed"
        case .bufferUnderflow:
            return "The audio buffer has underflowed"
            
        case .synchronizationFailed:
            return "Audio synchronization failed"
        case .timingMismatch:
            return "There is a timing mismatch in the audio"
        case .driftExceeded:
            return "The audio drift has exceeded acceptable limits"
        case .clockNotAvailable:
            return "The audio clock is not available"
            
        case .exportFailed:
            return "The audio export failed"
            
        case .unknown:
            return "An unknown error occurred"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        // Configuration Errors
        case .configurationFailed:
            return "Check the audio configuration parameters and try again"
        case .invalidConfiguration:
            return "Verify all configuration parameters are valid"
        case .configurationNotSupported:
            return "Try a different audio configuration that is supported"
        case .configurationConflict:
            return "Resolve the configuration conflict and try again"
            
        // Session Errors
        case .sessionFailed:
            return "Restart the audio session and try again"
        case .sessionNotActive:
            return "Activate the audio session before performing this operation"
        case .sessionAlreadyActive:
            return "The audio session is already active"
        case .sessionInterrupted:
            return "Wait for the interruption to end and try again"
        case .sessionCategoryNotAvailable:
            return "Choose a different audio session category"
        case .sessionModeNotAvailable:
            return "Choose a different audio session mode"
        case .sessionOptionsNotAvailable:
            return "Choose different audio session options"
            
        // Recording Errors
        case .alreadyRecording:
            return "Stop the current recording before starting a new one"
        case .notRecording:
            return "Start recording before attempting to stop"
        case .recordingFailed:
            return "Check the recording settings and try again"
        case .recordingStoppedUnexpectedly:
            return "Restart the recording and check for system issues"
        case .recordingLimitExceeded:
            return "Use a shorter recording duration or different format"
        case .recordingSpaceInsufficient:
            return "Free up storage space and try again"
        case .recordingFormatNotSupported:
            return "Choose a different recording format"
        case .recordingDeviceNotAvailable:
            return "Check audio device connections"
        case .recordingPermissionDenied:
            return "Grant microphone permissions in Settings"
            
        // Playback Errors
        case .playbackFailed:
            return "Check the audio file and playback settings"
        case .playbackInterrupted:
            return "Wait for the interruption to end and try again"
        case .playbackDeviceNotAvailable:
            return "Check audio output device connections"
        case .playbackFormatNotSupported:
            return "Choose a different audio format"
        case .playbackFileNotFound:
            return "Verify the audio file exists and is accessible"
        case .playbackFileCorrupted:
            return "Use a different audio file"
            
        // Processing Errors
        case .processingFailed:
            return "Check the processing settings and try again"
        case .processingLatencyTooHigh:
            return "Reduce the processing load or increase buffer size"
        case .processingOverload:
            return "Reduce the processing load or use a simpler configuration"
        case .processingNotAvailable:
            return "Audio processing is not available on this device"
        case .processingChainBroken:
            return "Rebuild the audio processing chain"
            
        // Hardware Errors
        case .hardwareUnavailable:
            return "Check audio hardware connections"
        case .hardwareNotSupported:
            return "Use a device that supports the required audio features"
        case .hardwareConfigurationFailed:
            return "Reconfigure the audio hardware settings"
        case .hardwareOverloaded:
            return "Reduce the audio processing load"
        case .hardwareThermalLimit:
            return "Allow the device to cool down and try again"
        case .hardwareBatteryLow:
            return "Charge the device and try again"
            
        // Format Errors
        case .formatNotSupported:
            return "Choose a different audio format"
        case .formatConversionFailed:
            return "Try a different format conversion"
        case .formatInvalid:
            return "Use a valid audio format"
        case .codecNotAvailable:
            return "Choose a format with an available codec"
        case .sampleRateNotSupported:
            return "Use a supported sample rate"
        case .bitDepthNotSupported:
            return "Use a supported bit depth"
        case .channelCountNotSupported:
            return "Use a supported channel count"
            
        // File System Errors
        case .fileSystemError:
            return "Check the file system and try again"
        case .fileNotFound:
            return "Verify the file path and try again"
        case .filePermissionDenied:
            return "Grant file permissions and try again"
        case .fileCorrupted:
            return "Use a different file"
        case .diskSpaceInsufficient:
            return "Free up disk space and try again"
        case .directoryNotFound:
            return "Verify the directory path and try again"
        case .directoryPermissionDenied:
            return "Grant directory permissions and try again"
            
        // Network Errors
        case .networkUnavailable:
            return "Check network connection and try again"
        case .networkTimeout:
            return "Try again with a better connection"
        case .networkAuthenticationFailed:
            return "Check authentication credentials"
        case .networkServerError:
            return "Try again later or contact support"
        case .networkConnectionLost:
            return "Restore network connection and try again"
            
        // Permission Errors
        case .permissionDenied:
            return "Grant the required permission in Settings"
        case .permissionRestricted:
            return "Contact administrator for permission access"
        case .permissionNotDetermined:
            return "Request the required permission"
        case .permissionSystemDenied:
            return "The system has denied this permission"
            
        // State Errors
        case .invalidState:
            return "Reset the audio system and try again"
        case .stateTransitionFailed:
            return "Retry the state transition"
        case .operationNotAvailableInCurrentState:
            return "Change to the appropriate state and try again"
        case .resourceNotAvailable:
            return "Wait for the resource to become available"
            
        // Memory Errors
        case .memoryInsufficient:
            return "Free up memory and try again"
        case .memoryAllocationFailed:
            return "Restart the app and try again"
        case .bufferOverflow:
            return "Reduce the buffer size or processing load"
        case .bufferUnderflow:
            return "Increase the buffer size or processing load"
            
        // Synchronization Errors
        case .synchronizationFailed:
            return "Resynchronize the audio and try again"
        case .timingMismatch:
            return "Adjust the timing settings"
        case .driftExceeded:
            return "Resynchronize the audio streams"
        case .clockNotAvailable:
            return "Restart the audio system"
            
        // Export Errors
        case .exportFailed:
            return "Check export settings and try again"
            
        // Unknown Errors
        case .unknown:
            return "Restart the app and try again"
        }
    }
    
    var severity: AudioErrorSeverity {
        switch self {
        case .configurationFailed, .invalidConfiguration, .configurationNotSupported, .configurationConflict:
            return .warning
        case .sessionFailed, .sessionNotActive, .sessionAlreadyActive, .sessionInterrupted,
             .sessionCategoryNotAvailable, .sessionModeNotAvailable, .sessionOptionsNotAvailable:
            return .error
        case .alreadyRecording, .notRecording, .recordingFailed, .recordingStoppedUnexpectedly,
             .recordingLimitExceeded, .recordingSpaceInsufficient, .recordingFormatNotSupported,
             .recordingDeviceNotAvailable, .recordingPermissionDenied:
            return .error
        case .playbackFailed, .playbackInterrupted, .playbackDeviceNotAvailable,
             .playbackFormatNotSupported, .playbackFileNotFound, .playbackFileCorrupted:
            return .error
        case .processingFailed, .processingLatencyTooHigh, .processingOverload,
             .processingNotAvailable, .processingChainBroken:
            return .error
        case .hardwareUnavailable, .hardwareNotSupported, .hardwareConfigurationFailed,
             .hardwareOverloaded, .hardwareThermalLimit, .hardwareBatteryLow:
            return .critical
        case .formatNotSupported, .formatConversionFailed, .formatInvalid, .codecNotAvailable,
             .sampleRateNotSupported, .bitDepthNotSupported, .channelCountNotSupported:
            return .warning
        case .fileSystemError, .fileNotFound, .filePermissionDenied, .fileCorrupted,
             .diskSpaceInsufficient, .directoryNotFound, .directoryPermissionDenied:
            return .error
        case .networkUnavailable, .networkTimeout, .networkAuthenticationFailed,
             .networkServerError, .networkConnectionLost:
            return .warning
        case .permissionDenied, .permissionRestricted, .permissionNotDetermined, .permissionSystemDenied:
            return .error
        case .invalidState, .stateTransitionFailed, .operationNotAvailableInCurrentState,
             .resourceNotAvailable:
            return .error
        case .memoryInsufficient, .memoryAllocationFailed, .bufferOverflow, .bufferUnderflow:
            return .critical
        case .synchronizationFailed, .timingMismatch, .driftExceeded, .clockNotAvailable:
            return .error
        case .exportFailed:
            return .error
        case .unknown:
            return .error
        }
    }
    
    var category: AudioErrorCategory {
        switch self {
        case .configurationFailed, .invalidConfiguration, .configurationNotSupported, .configurationConflict:
            return .configuration
        case .sessionFailed, .sessionNotActive, .sessionAlreadyActive, .sessionInterrupted,
             .sessionCategoryNotAvailable, .sessionModeNotAvailable, .sessionOptionsNotAvailable:
            return .session
        case .alreadyRecording, .notRecording, .recordingFailed, .recordingStoppedUnexpectedly,
             .recordingLimitExceeded, .recordingSpaceInsufficient, .recordingFormatNotSupported,
             .recordingDeviceNotAvailable, .recordingPermissionDenied:
            return .recording
        case .playbackFailed, .playbackInterrupted, .playbackDeviceNotAvailable,
             .playbackFormatNotSupported, .playbackFileNotFound, .playbackFileCorrupted:
            return .playback
        case .processingFailed, .processingLatencyTooHigh, .processingOverload,
             .processingNotAvailable, .processingChainBroken:
            return .processing
        case .hardwareUnavailable, .hardwareNotSupported, .hardwareConfigurationFailed,
             .hardwareOverloaded, .hardwareThermalLimit, .hardwareBatteryLow:
            return .hardware
        case .formatNotSupported, .formatConversionFailed, .formatInvalid, .codecNotAvailable,
             .sampleRateNotSupported, .bitDepthNotSupported, .channelCountNotSupported:
            return .format
        case .fileSystemError, .fileNotFound, .filePermissionDenied, .fileCorrupted,
             .diskSpaceInsufficient, .directoryNotFound, .directoryPermissionDenied:
            return .fileSystem
        case .networkUnavailable, .networkTimeout, .networkAuthenticationFailed,
             .networkServerError, .networkConnectionLost:
            return .network
        case .permissionDenied, .permissionRestricted, .permissionNotDetermined, .permissionSystemDenied:
            return .permission
        case .invalidState, .stateTransitionFailed, .operationNotAvailableInCurrentState,
             .resourceNotAvailable:
            return .state
        case .memoryInsufficient, .memoryAllocationFailed, .bufferOverflow, .bufferUnderflow:
            return .memory
        case .synchronizationFailed, .timingMismatch, .driftExceeded, .clockNotAvailable:
            return .synchronization
        case .exportFailed:
            return .fileSystem
        case .unknown:
            return .unknown
        }
    }
}

// MARK: - Error Severity

enum AudioErrorSeverity: String, CaseIterable, Sendable, Codable {
    case info = "info"
    case warning = "warning"
    case error = "error"
    case critical = "critical"
    
    var displayName: String {
        switch self {
        case .info:
            return "Info"
        case .warning:
            return "Warning"
        case .error:
            return "Error"
        case .critical:
            return "Critical"
        }
    }
    
    var color: String {
        switch self {
        case .info:
            return "blue"
        case .warning:
            return "yellow"
        case .error:
            return "red"
        case .critical:
            return "purple"
        }
    }
}

// MARK: - Error Category

enum AudioErrorCategory: String, CaseIterable, Sendable, Codable {
    case configuration = "configuration"
    case session = "session"
    case recording = "recording"
    case playback = "playback"
    case processing = "processing"
    case hardware = "hardware"
    case format = "format"
    case fileSystem = "fileSystem"
    case network = "network"
    case permission = "permission"
    case state = "state"
    case memory = "memory"
    case synchronization = "synchronization"
    case unknown = "unknown"
    
    var displayName: String {
        switch self {
        case .configuration:
            return "Configuration"
        case .session:
            return "Session"
        case .recording:
            return "Recording"
        case .playback:
            return "Playback"
        case .processing:
            return "Processing"
        case .hardware:
            return "Hardware"
        case .format:
            return "Format"
        case .fileSystem:
            return "File System"
        case .network:
            return "Network"
        case .permission:
            return "Permission"
        case .state:
            return "State"
        case .memory:
            return "Memory"
        case .synchronization:
            return "Synchronization"
        case .unknown:
            return "Unknown"
        }
    }
}

// MARK: - Audio Error Extensions

extension AudioError {
    init?(from avError: NSError) {
        let domain = avError.domain
        let code = avError.code
        
        if domain == "AVAudioSessionErrorDomain" {
            switch code {
            case AVAudioSession.ErrorCode.isBusy.rawValue:
                self = .sessionAlreadyActive
            case AVAudioSession.ErrorCode.cannotInterruptOthers.rawValue:
                self = .sessionOptionsNotAvailable
            case AVAudioSession.ErrorCode.missingEntitlement.rawValue:
                self = .permissionDenied("Audio session entitlement")
            case AVAudioSession.ErrorCode.siriIsRecording.rawValue:
                self = .sessionInterrupted
            case AVAudioSession.ErrorCode.cannotStartPlaying.rawValue:
                self = .playbackFailed("Cannot start playback")
            case AVAudioSession.ErrorCode.cannotStartRecording.rawValue:
                self = .recordingFailed("Cannot start recording")
            case AVAudioSession.ErrorCode.badParam.rawValue:
                self = .invalidConfiguration("Bad parameter")
            case AVAudioSession.ErrorCode.insufficientPriority.rawValue:
                self = .hardwareOverloaded
            case AVAudioSession.ErrorCode.sessionNotActive.rawValue:
                self = .sessionNotActive
            // Note: Some error codes may not be available in all iOS versions
            case 560557684: // mediaServicesWereLost
                self = .hardwareUnavailable
            case 561015905: // mediaServicesWereReset
                self = .sessionFailed(avError)
            default:
                self = .unknown("AVAudioSession error: \(avError.localizedDescription)")
            }
        } else if domain == NSOSStatusErrorDomain {
            switch Int32(code) {
            case kAudioFileUnspecifiedError:
                self = .fileSystemError("Unspecified audio file error")
            case kAudioFileUnsupportedFileTypeError:
                self = .formatNotSupported
            case kAudioFileUnsupportedDataFormatError:
                self = .formatConversionFailed
            case kAudioFileUnsupportedPropertyError:
                self = .formatInvalid
            case -43: // kAudioFileBadFilePathError equivalent
                self = .fileNotFound(avError.localizedDescription)
            case -54: // kAudioFilePermissionError equivalent
                self = .filePermissionDenied(avError.localizedDescription)
            case kAudioFileNotOpenError:
                self = .fileSystemError("Audio file not open")
            case kAudioFileEndOfFileError:
                self = .fileCorrupted("Unexpected end of file")
            case kAudioFilePositionError:
                self = .fileSystemError("Invalid file position")
            case kAudioFileFileNotFoundError:
                self = .fileNotFound(avError.localizedDescription)
            default:
                self = .unknown("Audio system error: \(avError.localizedDescription)")
            }
        } else {
            self = .unknown("Unknown error: \(avError.localizedDescription)")
        }
    }
}