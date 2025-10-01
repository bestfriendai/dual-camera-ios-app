# Dual Camera App

A professional dual-camera recording app for iOS devices with advanced features and controls.

## Features

### Core Functionality
- Simultaneous front and back camera recording
- Real-time video composition with multiple layouts
- Triple output recording system (front, back, combined)
- High-quality video recording with multiple resolution options

### Advanced Camera Controls
- Independent focus and exposure controls for each camera
- Smooth zoom with velocity tracking
- Tap-to-focus with visual feedback
- Pinch-to-zoom with haptic feedback
- White balance control

### Enhanced Audio Management
- Multiple audio source selection (built-in, Bluetooth, headset, USB)
- Real-time audio level monitoring with visualization
- Noise reduction with adjustable settings
- Clipping detection and warning

### User Experience
- Haptic feedback for all interactions
- Visual countdown with animations
- Persistent user settings
- Graceful error handling with recovery actions
- Performance monitoring and optimization

### Recording Modes
- **All Files**: Saves front, back, and combined videos separately
- **Combined Only**: Saves only the combined video with both cameras side by side
- **Front & Back Only**: Saves front and back camera videos separately

## Technical Implementation

### Architecture
- MVVM architecture with clean separation of concerns
- Modular design with reusable components
- Comprehensive error handling throughout the app
- Performance monitoring and optimization

### Key Components
- `DualCameraManager`: Core camera management and recording
- `FrameCompositor`: Real-time video composition with adaptive quality
- `PerformanceMonitor`: Comprehensive performance tracking
- `AudioManager`: Advanced audio management and processing
- `SettingsManager`: Persistent user preferences
- `ErrorHandlingManager`: Centralized error handling with recovery

### Performance Optimizations
- Adaptive quality management based on device performance
- Pixel buffer pooling for efficient memory usage
- Frame processing optimization with Metal rendering
- Memory pressure handling with graceful degradation

## Requirements

- iOS 13.0+
- Device with front and back cameras
- Xcode 12.0+

## Installation

1. Clone the repository
2. Open the project in Xcode
3. Build and run on a compatible device

## Usage

1. Grant camera and microphone permissions when prompted
2. Select recording mode (All Files, Combined Only, or Front & Back Only)
3. Adjust camera and audio settings as needed
4. Tap the record button to start recording
5. Tap the record button again to stop recording
6. View recordings in the gallery

## Settings

The app includes comprehensive settings for:
- Video quality and resolution
- Recording mode selection
- Audio source selection
- Haptic feedback preferences
- Visual countdown settings
- Noise reduction settings

## Performance

The app is optimized for performance with:
- Real-time frame rate monitoring
- Memory usage tracking
- CPU usage monitoring
- Automatic quality adjustment based on device performance
- Efficient resource management

## Troubleshooting

If you encounter issues:
1. Check that all permissions have been granted
2. Ensure sufficient storage space is available
3. Restart the app if performance issues occur
4. Check for iOS updates

## Contributing

Contributions are welcome! Please follow the established code patterns and submit pull requests for review.

## License

This project is licensed under the MIT License.