# Dual Camera Implementation

This document describes the architecture and implementation of the advanced dual camera system for DualApp, supporting simultaneous recording from front and back cameras with hardware synchronization.

## Architecture Overview

The dual camera system is built with a modular, actor-based architecture that ensures thread safety and optimal performance. The main components are:

### Core Components

1. **DualCameraSession** - The main coordinator for dual camera operations
2. **CameraCaptureService** - Handles frame processing and filtering
3. **VideoRecorder** - Manages recording to multiple outputs
4. **MetalRenderer** - Provides high-performance video rendering
5. **ErrorRecoveryManager** - Handles error detection and recovery

### Supporting Components

1. **HardwareSynchronizer** - Synchronizes camera hardware for minimal latency
2. **FrameSyncCoordinator** - Coordinates frame synchronization between cameras
3. **AdaptiveQualityManager** - Dynamically adjusts quality based on system conditions
4. **PerformanceMonitor** - Monitors system performance and resource usage

## Key Features

### Multi-Camera Recording

- Simultaneous recording from front and back cameras
- Hardware synchronization with 1ms target latency (iOS 26+)
- Multiple output formats: side-by-side, picture-in-picture, split-screen, overlay

### Adaptive Quality Management

- Dynamic quality adjustment based on thermal state, battery level, and memory usage
- Automatic performance optimization
- User-configurable quality presets

### Advanced Rendering

- Metal-based rendering for optimal performance
- Real-time filters and effects
- Support for HDR and wide color gamuts

### Comprehensive Error Handling

- Automatic error detection and recovery
- Multiple recovery strategies for different error types
- Graceful degradation under stress conditions

## Implementation Details

### DualCameraSession

The `DualCameraSession` actor is the main coordinator for dual camera operations. It handles:

- Camera discovery and configuration
- Hardware synchronization setup
- Frame stream management
- Recording coordination

```swift
@MainActor
actor DualCameraSession: Sendable {
    // State management
    private(set) var state: DualCameraSessionState = .notInitialized
    private(set) var activeConfiguration: CameraConfiguration?
    
    // Event streaming
    let events: AsyncStream<DualCameraEvent>
    let frameStream: AsyncStream<DualCameraFrame>
    
    // Main operations
    func initializeSession() async throws
    func startRecording() async throws -> RecordingSession
    func stopRecording() async throws
}
```

### Hardware Synchronization

The system leverages iOS 26+ hardware synchronization features for minimal latency:

```swift
@available(iOS 26.0, *)
private func configureIOS26Synchronization() async {
    session.synchronizedCaptureMode = .synchronized
    session.synchronizationLatency = CMTime(value: CMTimeValue(targetLatency * 1000000), timescale: 1000000)
    session.isHardwareClockSynchronizationEnabled = true
}
```

### Frame Processing Pipeline

The frame processing pipeline supports multiple processors and filters:

```swift
protocol FrameProcessor: Sendable, Identifiable {
    func process(_ frame: DualCameraFrame, configuration: CameraConfiguration) async throws -> DualCameraFrame
}

protocol FrameFilter: Sendable, Identifiable {
    func apply(to frame: DualCameraFrame, configuration: CameraConfiguration) async throws -> DualCameraFrame
}
```

### Adaptive Quality Management

The adaptive quality system monitors system conditions and adjusts recording parameters:

```swift
class AdaptiveQualityManager {
    func getRecommendedConfiguration() async -> CameraConfiguration? {
        let currentPerformance = await getCurrentPerformanceSnapshot()
        let recommendedLevel = determineOptimalQualityLevel(performance: currentPerformance)
        return applyQualityLevel(recommendedLevel, to: baseConfig)
    }
}
```

## Usage

### Basic Setup

```swift
struct ContentView: View {
    @StateObject private var dualCameraSession = DualCameraSession()
    
    var body: some View {
        DualCameraView()
            .onAppear {
                setupDualCameraSession()
            }
    }
    
    private func setupDualCameraSession() {
        Task {
            try await dualCameraSession.initializeSession()
            try await dualCameraSession.startSession()
        }
    }
}
```

### Recording

```swift
// Start recording
let recordingSession = try await dualCameraSession.startRecording()

// Stop recording
try await dualCameraSession.stopRecording()
```

### Configuration

```swift
let configuration = CameraConfiguration(
    quality: .uhd4k,
    frameRate: 60,
    hdrEnabled: true,
    multiCamEnabled: true,
    videoStabilizationEnabled: true
)

try await dualCameraSession.configureSession(with: configuration)
```

## Performance Considerations

### Memory Management

- Efficient frame buffer pools
- Automatic memory pressure handling
- Configurable memory limits

### Thermal Management

- Dynamic quality adjustment based on thermal state
- Automatic thermal throttling
- User-configurable thermal thresholds

### Battery Optimization

- Adaptive quality based on battery level
- Power-saving presets
- Battery usage monitoring

## Error Handling

The system includes comprehensive error handling with multiple recovery strategies:

```swift
enum DualCameraError: LocalizedError, Sendable {
    case invalidState
    case multiCamNotSupported
    case thermalLimitReached
    case batteryLevelLow
    // ... more error cases
}
```

### Recovery Strategies

1. **Camera Session Recovery** - Restarts camera session on failure
2. **Thermal Recovery** - Reduces performance to lower thermal load
3. **Memory Recovery** - Clears caches and releases memory
4. **Battery Recovery** - Enables power-saving mode
5. **Hardware Recovery** - Reinitializes hardware components

## Device Compatibility

### Minimum Requirements

- iOS 16.0+ (basic functionality)
- iOS 26.0+ (hardware synchronization)
- A12 Bionic chip or newer (recommended)
- Devices with multiple cameras (front and back)

### Supported Devices

- iPhone 11 and newer (full feature support)
- iPhone XS/XR (limited feature support)
- iPad Pro with multiple cameras (limited feature support)

## Future Enhancements

### Planned Features

1. **AI-powered scene detection** - Automatic scene recognition and optimization
2. **Advanced video effects** - Real-time video effects and transitions
3. **Cloud integration** - Direct upload to cloud services
4. **Multi-device recording** - Synchronized recording across multiple devices

### Performance Improvements

1. **Neural Engine integration** - Use Neural Engine for frame processing
2. **GPU-accelerated encoding** - Hardware-accelerated video encoding
3. **Advanced compression** - More efficient video compression algorithms

## Testing

### Unit Tests

- Comprehensive unit tests for all actors and services
- Mock implementations for hardware-dependent components
- Performance benchmarks for critical paths

### Integration Tests

- End-to-end testing of recording workflows
- Device-specific testing on supported hardware
- Stress testing under various conditions

### UI Tests

- SwiftUI view testing for all UI components
- User interaction testing
- Accessibility testing

## Troubleshooting

### Common Issues

1. **Camera permission denied**
   - Ensure camera permissions are granted in Settings
   - Check if the app is in restricted mode

2. **Multi-camera not supported**
   - Verify device supports multiple cameras
   - Check iOS version (iOS 16+ required)

3. **Performance issues**
   - Check thermal state and battery level
   - Try reducing recording quality
   - Close other apps to free resources

4. **Recording failures**
   - Check available storage space
   - Verify output format is supported
   - Check for hardware errors

### Debug Mode

Enable debug mode to see performance metrics and detailed logging:

```swift
#if DEBUG
// Enable performance metrics overlay
// Enable detailed logging
#endif
```

## Conclusion

The dual camera implementation provides a robust, high-performance solution for simultaneous recording from multiple cameras. The modular architecture allows for easy extension and maintenance, while the adaptive quality management ensures optimal performance across a wide range of devices and conditions.

For more information, refer to the individual component documentation and code comments.