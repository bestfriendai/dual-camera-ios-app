# Dual Camera iOS App

A Swift iOS application that allows users to record videos from both front and back cameras simultaneously, creating unique dual-perspective content perfect for vlogs, tutorials, and creative storytelling.

## 🎉 Latest Update - v2.1 (Crash Fix)

**✅ FIXED:** The critical EXC_BAD_ACCESS crash has been resolved! The app now launches smoothly without freezing at the splash screen.

**What was fixed:**
- Proper camera initialization order (permissions → setup → start)
- Added safety guards to prevent premature camera access
- Fixed memory management with weak references
- Added background/foreground handling
- Improved error handling throughout

**Status:** ✅ Build Successful | ✅ Ready for Testing | ✅ Stable

## Features

### Core Functionality
- **Simultaneous Dual Camera Recording**: Record from both front and back cameras at the same time
- **Real-time Preview**: Live preview of both camera feeds during recording
- **Video Merging**: Combine both recordings into a single video with multiple layout options
- **Multiple Quality Settings**: Choose from 720p HD, 1080p Full HD, or 4K Ultra HD recording
- **Flexible Video Layouts**: Side-by-side or Picture-in-Picture (PIP) merge options

### User Interface
- Clean, modern glassmorphism design with intuitive controls
- Visual recording status indicators with timer
- Easy-to-use recording controls
- Real-time status updates with progress indicators
- Swappable camera view layouts

### Advanced Camera Controls
- **Pinch to Zoom**: Zoom in/out on both camera views independently (up to 5x)
- **Tap to Focus**: Tap on camera previews to set focus and exposure points
- **Flash Control**: Toggle flash/torch for back camera
- **Quality Selector**: Change video quality on the fly

### Video Management
- **Video Gallery**: Browse all recorded and merged videos
- **Video Playback**: Built-in video player for previewing recordings
- **Share Videos**: Share videos directly from the gallery
- **Delete Videos**: Remove unwanted recordings
- **Automatic Cleanup**: Old temporary files are automatically cleaned up after 7 days

### Technical Features
- AVFoundation-based camera management
- Dual session handling for optimal performance
- Automatic permission requests for camera, microphone, and photo library
- Background processing for video merging with progress tracking
- Photos library integration for saving merged videos
- Memory-optimized video processing
- Automatic resource cleanup and management
- Support for multiple video quality presets

## Requirements

- iOS 12.0 or later
- iPhone with front and back cameras
- Camera and microphone permissions
- Photo library access permission

## Project Structure

```
DualCameraApp/
├── AppDelegate.swift                # App lifecycle management
├── SceneDelegate.swift              # Scene-based lifecycle (iOS 13+)
├── ViewController.swift             # Main UI and camera controls
├── DualCameraManager.swift          # Core camera session management
├── VideoMerger.swift                # Video composition and merging logic
├── VideoGalleryViewController.swift # Video gallery and management
├── GlassmorphismView.swift         # Custom glassmorphism UI component
└── Info.plist                      # App configuration and permissions
```

## Key Components

### DualCameraManager
The heart of the app that manages:
- Dual camera session setup and configuration
- Video recording from both cameras
- Audio capture from the front camera
- Preview layer management
- Recording state management

### ViewController
Main interface that provides:
- Dual camera preview displays
- Recording controls and status
- User interaction handling
- Video merging interface

### VideoMerger
Video processing functionality:
- Side-by-side video composition
- Audio synchronization
- High-quality video export
- Photos library integration

## Usage

### Recording Videos
1. Launch the app and grant camera/microphone permissions
2. (Optional) Tap the quality button (top-right) to select video quality (720p, 1080p, or 4K)
3. Position yourself to get the desired front and back camera views
4. Use pinch gestures to zoom in/out on either camera view
5. Tap on camera previews to set focus and exposure points
6. Tap the record button to begin simultaneous recording
7. Tap the stop button when finished
8. Videos are automatically saved to the app's documents directory

### Merging Videos
1. After recording, tap "Merge Videos"
2. Select your preferred layout:
   - **Side-by-Side**: Both cameras shown equally side-by-side
   - **Picture-in-Picture**: Back camera as main view with front camera as small overlay
3. Watch the progress bar as the app processes and combines both recordings
4. The merged video will be automatically saved to your Photos library
5. Old temporary files are cleaned up automatically

### Managing Videos
1. Tap the gallery button (top-left) to open the video gallery
2. Browse all your recorded and merged videos
3. Tap any video to:
   - **Play**: Watch the video in full-screen player
   - **Share**: Share via Messages, Mail, AirDrop, etc.
   - **Delete**: Remove the video from storage

### Camera Controls
- **Swap Views**: Tap the swap button to switch which camera is the main view
- **Flash**: Toggle the flash/torch for the back camera
- **Zoom**: Pinch to zoom on either camera view (1x to 5x)
- **Focus**: Tap anywhere on a camera view to set focus and exposure

## Permissions Required

The app requires the following permissions (automatically requested):

- **Camera Access**: For recording from front and back cameras
- **Microphone Access**: For audio recording
- **Photo Library Access**: For saving merged videos

## Implementation Details

### Camera Session Management
- Separate `AVCaptureSession` instances for each camera
- Audio input attached only to the front camera session
- `AVCaptureMovieFileOutput` for direct video file recording
- Optimized for performance and battery life

### Video Composition
- Uses `AVMutableComposition` for combining video tracks
- `AVVideoComposition` for side-by-side layout
- Maintains original video quality and frame rates
- Synchronizes audio from the front camera

### UI Design
- Responsive layout supporting all iPhone sizes
- Real-time status updates during recording
- Visual feedback for recording state
- Error handling with user-friendly messages

## Building and Running

1. Open the project in Xcode 12 or later
2. Select your target device (iPhone with dual cameras)
3. Build and run the project
4. Grant required permissions when prompted
5. Start recording with both cameras!

## Customization Options

### Recording Settings
- Modify video quality in `DualCameraManager.swift`
- Adjust frame rates and video formats
- Configure audio settings

### UI Customization
- Update colors and fonts in `ViewController.swift`
- Modify layout proportions and spacing
- Add custom branding and styling

### Video Layout
- Change side-by-side to picture-in-picture in `VideoMerger.swift`
- Adjust video positioning and scaling
- Add transitions and effects

## Troubleshooting

### Common Issues
- **Black camera preview**: Check camera permissions
- **No audio in recordings**: Verify microphone permissions
- **Merge failure**: Ensure both cameras recorded successfully
- **App crashes**: Check device compatibility (requires dual cameras)

### Performance Tips
- Close other camera apps before use
- Ensure sufficient storage space
- Use in well-lit environments for better quality
- Keep recording sessions reasonable in length

## Recent Improvements

### Version 2.0 Features
- ✅ Multiple video quality settings (720p, 1080p, 4K)
- ✅ Picture-in-picture video layout option
- ✅ Pinch-to-zoom functionality for both cameras
- ✅ Tap-to-focus and exposure control
- ✅ Video gallery with playback, sharing, and deletion
- ✅ Progress indicators for video export
- ✅ Improved error handling and user feedback
- ✅ Memory optimization and automatic cleanup
- ✅ Modern glassmorphism UI design
- ✅ Swappable camera view layouts

## Future Enhancements

Potential features for future versions:
- Real-time filters and effects
- Live streaming capabilities
- Advanced audio controls and mixing
- Custom watermarks and branding
- Video trimming and editing
- Cloud backup integration
- Multi-camera support (3+ cameras on supported devices)

## Technical Specifications

- **Language**: Swift 5.0+
- **Framework**: AVFoundation, Photos, UIKit
- **Architecture**: Delegate pattern, MVC
- **Target iOS**: 12.0+
- **Camera Requirements**: Front and back camera support

## License

This project is provided as-is for educational and development purposes. Feel free to modify and enhance according to your needs.

---

**Note**: This app is designed for iPhone devices with dual camera capabilities. Some features may be limited on devices with single cameras or iPads.