# DualApp Project Structure

## Directory Overview

```
Z/
├── README.md                           # Project overview and documentation
├── PROJECT_STRUCTURE.md                # This file - detailed structure documentation
├── DualApp.xcodeproj/                  # Xcode project configuration
│   ├── project.pbxproj
│   └── xcshareddata/
├── DualApp/                            # Main application bundle
│   ├── App/                           # Application entry point
│   │   ├── DualAppApp.swift           # SwiftUI App entry point
│   │   ├── DualAppAppDelegate.swift   # UIKit app delegate
│   │   └── MainActorMessages.swift    # Type-safe notification messages
│   ├── Core/                          # Core business logic
│   │   ├── Camera/                    # Camera management
│   │   │   ├── Actors/
│   │   │   │   ├── CameraManager.swift        # Main camera actor
│   │   │   │   ├── FrameCompositor.swift      # Frame processing actor
│   │   │   │   └── CaptureSessionActor.swift  # Session management actor
│   │   │   ├── Models/
│   │   │   │   ├── CameraConfiguration.swift  # Camera settings
│   │   │   │   ├── VideoQuality.swift         # Quality options
│   │   │   │   ├── CameraState.swift          # Camera states
│   │   │   │   └── CaptureDevice.swift        # Device abstraction
│   │   │   ├── Services/
│   │   │   │   ├── HardwareSyncService.swift  # iOS 26 hardware sync
│   │   │   │   ├── FormatSelectionService.swift # AI format selection
│   │   │   │   └── HDRConfigurationService.swift # Enhanced HDR
│   │   │   └── Extensions/
│   │   │       ├── AVCaptureDevice+Extensions.swift
│   │   │       └── AVCaptureSession+Extensions.swift
│   │   ├── Audio/                     # Audio management
│   │   │   ├── Actors/
│   │   │   │   ├── AudioManager.swift          # Main audio actor
│   │   │   │   └── AudioProcessor.swift        # Audio processing actor
│   │   │   ├── Models/
│   │   │   │   ├── AudioConfiguration.swift   # Audio settings
│   │   │   │   └── AudioLevels.swift          # Audio levels
│   │   │   └── Services/
│   │   │       ├── AudioSessionService.swift  # Session management
│   │   │       └── NoiseReductionService.swift # Noise reduction
│   │   ├── Permissions/               # Permission management
│   │   │   ├── Actors/
│   │   │   │   └── PermissionManager.swift    # Permission actor
│   │   │   ├── Models/
│   │   │   │   ├── PermissionStatus.swift     # Permission states
│   │   │   │   └── PermissionType.swift       # Permission types
│   │   │   └── Services/
│   │   │       └── PermissionCoordinator.swift # Permission coordination
│   │   └── Storage/                   # Data persistence
│   │       ├── Actors/
│   │       │   └── StorageManager.swift       # Storage actor
│   │       ├── Models/
│   │       │   ├── RecordingMetadata.swift    # Recording metadata
│   │       │   └── StorageLocation.swift      # Storage locations
│   │       └── Services/
│   │           └── CloudStorageService.swift  # Cloud integration
│   ├── Features/                      # Feature modules
│   │   ├── Recording/                 # Recording feature
│   │   │   ├── Views/
│   │   │   │   ├── RecordingView.swift        # Main recording view
│   │   │   │   ├── CameraControlsView.swift   # Camera controls
│   │   │   │   ├── RecordingControlsView.swift # Recording controls
│   │   │   │   └── TripleOutputView.swift     # Triple output UI
│   │   │   ├── ViewModels/
│   │   │   │   └── RecordingViewModel.swift   # Recording state
│   │   │   ├── Coordinators/
│   │   │   │   └── RecordingCoordinator.swift # Recording flow
│   │   │   └── Components/
│   │   │       ├── CameraPreview.swift        # Camera preview
│   │   │       ├── RecordingIndicator.swift   # Recording status
│   │   │       └── QualitySelector.swift      # Quality selection
│   │   ├── Gallery/                   # Gallery feature
│   │   │   ├── Views/
│   │   │   │   ├── GalleryView.swift          # Main gallery view
│   │   │   │   ├── VideoPlayerView.swift      # Video player
│   │   │   │   └── VideoDetailView.swift      # Video details
│   │   │   ├── ViewModels/
│   │   │   │   └── GalleryViewModel.swift     # Gallery state
│   │   │   ├── Coordinators/
│   │   │   │   └── GalleryCoordinator.swift   # Gallery flow
│   │   │   └── Components/
│   │   │       ├── VideoThumbnail.swift       # Video thumbnail
│   │   │       ├── VideoMetadata.swift        # Video metadata
│   │   │       └── ShareSheet.swift           # Share functionality
│   │   └── Settings/                  # Settings feature
│   │       ├── Views/
│   │       │   ├── SettingsView.swift         # Main settings view
│   │       │   ├── CameraSettingsView.swift   # Camera settings
│   │       │   └── PerformanceSettingsView.swift # Performance settings
│   │       ├── ViewModels/
│   │       │   └── SettingsViewModel.swift    # Settings state
│   │       ├── Coordinators/
│   │       │   └── SettingsCoordinator.swift  # Settings flow
│   │       └── Components/
│   │           ├── SettingsToggle.swift       # Settings toggle
│   │           ├── SettingsSlider.swift       # Settings slider
│   │           └── SettingsSection.swift      # Settings section
│   ├── DesignSystem/                   # Design system
│   │   ├── LiquidGlass/                # Liquid glass design
│   │   │   ├── Views/
│   │   │   │   ├── LiquidGlassView.swift      # Main liquid glass view
│   │   │   │   ├── LiquidGlassButton.swift    # Liquid glass button
│   │   │   │   ├── LiquidGlassCard.swift      # Liquid glass card
│   │   │   │   └── LiquidGlassContainer.swift # Liquid glass container
│   │   │   ├── Materials/
│   │   │   │   ├── LiquidGlassMaterial.swift  # Material definition
│   │   │   │   ├── GlassEffects.swift         # Glass effects
│   │   │   │   └── NoiseTexture.swift         # Noise texture
│   │   │   └── Modifiers/
│   │   │       ├── GlassModifier.swift        # Glass modifier
│   │   │       ├── BlurModifier.swift         # Blur modifier
│   │   │       └── ShadowModifier.swift       # Shadow modifier
│   │   ├── Components/                 # Reusable components
│   │   │   ├── Buttons/
│   │   │   │   ├── PrimaryButton.swift        # Primary button
│   │   │   │   ├── SecondaryButton.swift      # Secondary button
│   │   │   │   └── IconButton.swift           # Icon button
│   │   │   ├── Controls/
│   │   │   │   ├── SliderControl.swift        # Slider control
│   │   │   │   ├── ToggleControl.swift        # Toggle control
│   │   │   │   └── SegmentedControl.swift     # Segmented control
│   │   │   ├── Indicators/
│   │   │   │   ├── ProgressIndicator.swift    # Progress indicator
│   │   │   │   ├── StatusIndicator.swift      # Status indicator
│   │   │   │   └── RecordingIndicator.swift   # Recording indicator
│   │   │   └── Containers/
│   │   │       ├── CardContainer.swift        # Card container
│   │   │       ├── ModalContainer.swift       # Modal container
│   │   │       └── SheetContainer.swift       # Sheet container
│   │   ├── Tokens/                     # Design tokens
│   │   │   ├── Colors.swift                  # Color definitions
│   │   │   ├── Typography.swift              # Typography definitions
│   │   │   ├── Spacing.swift                 # Spacing definitions
│   │   │   ├── Shadows.swift                 # Shadow definitions
│   │   │   └── Animations.swift              # Animation definitions
│   │   └── Extensions/                 # View extensions
│   │       ├── View+Modifiers.swift          # View modifiers
│   │       ├── Color+Extensions.swift        # Color extensions
│   │       └── Font+Extensions.swift         # Font extensions
│   ├── Performance/                   # Performance management
│   │   ├── Memory/                     # Memory management
│   │   │   ├── Actors/
│   │   │   │   ├── MemoryManager.swift        # Memory manager actor
│   │   │   │   └── MemoryCompactionActor.swift # Memory compaction actor
│   │   │   ├── Models/
│   │   │   │   ├── MemoryPressure.swift       # Memory pressure levels
│   │   │   │   ├── MemoryMetrics.swift        # Memory metrics
│   │   │   │   └── MemoryThreshold.swift      # Memory thresholds
│   │   │   └── Services/
│   │   │       ├── MemoryMonitorService.swift # Memory monitoring
│   │   │       └── MemoryOptimizerService.swift # Memory optimization
│   │   ├── Battery/                    # Battery management
│   │   │   ├── Actors/
│   │   │   │   └── BatteryManager.swift       # Battery manager actor
│   │   │   ├── Models/
│   │   │   │   ├── BatteryState.swift         # Battery states
│   │   │   │   └── BatteryLevel.swift         # Battery levels
│   │   │   └── Services/
│   │   │       ├── BatteryMonitorService.swift # Battery monitoring
│   │   │       └── PowerOptimizerService.swift # Power optimization
│   │   └── Thermal/                    # Thermal management
│   │       ├── Actors/
│   │       │   └── ThermalManager.swift       # Thermal manager actor
│   │       ├── Models/
│   │       │   ├── ThermalState.swift         # Thermal states
│   │       │   └── ThermalThreshold.swift     # Thermal thresholds
│   │       └── Services/
│   │           ├── ThermalMonitorService.swift # Thermal monitoring
│   │           └── ThermalOptimizerService.swift # Thermal optimization
│   ├── VideoProcessing/               # Video processing
│   │   ├── Actors/
│   │   │   ├── VideoProcessor.swift          # Video processor actor
│   │   │   ├── FrameProcessor.swift          # Frame processor actor
│   │   │   └── VideoCompositor.swift         # Video compositor actor
│   │   ├── Models/
│   │   │   ├── VideoFormat.swift             # Video format
│   │   │   ├── ProcessingSettings.swift      # Processing settings
│   │   │   └── FrameMetadata.swift           # Frame metadata
│   │   ├── Services/
│   │   │   ├── VideoEncoderService.swift     # Video encoding
│   │   │   ├── VideoDecoderService.swift     # Video decoding
│   │   │   └── VideoFilterService.swift      # Video filtering
│   │   └── Utilities/
│   │       ├── PixelBuffer+Extensions.swift  # Pixel buffer utilities
│   │       ├── CVPixelBuffer+Span.swift      # Span-based buffer access
│   │       └── VideoUtils.swift              # Video utilities
│   ├── ErrorHandling/                 # Error handling
│   │   ├── Models/
│   │   │   ├── AppError.swift                # Application errors
│   │   │   ├── CameraError.swift             # Camera errors
│   │   │   ├── AudioError.swift              # Audio errors
│   │   │   └── StorageError.swift            # Storage errors
│   │   ├── Services/
│   │   │   ├── ErrorReporter.swift           # Error reporting
│   │   │   ├── ErrorRecoveryService.swift    # Error recovery
│   │   │   └── CrashReporter.swift           # Crash reporting
│   │   └── Extensions/
│   │       ├── Error+UserFriendly.swift      # User-friendly errors
│   │       └── Result+Extensions.swift       # Result extensions
│   ├── Utils/                         # Utilities
│   │   ├── Extensions/
│   │   │   ├── Foundation+Extensions.swift  # Foundation extensions
│   │   │   ├── UIKit+Extensions.swift        # UIKit extensions
│   │   │   └── SwiftUI+Extensions.swift     # SwiftUI extensions
│   │   ├── Helpers/
│   │   │   ├── DispatchQueue+Extensions.swift # Dispatch queue helpers
│   │   │   ├── Timer+Extensions.swift        # Timer helpers
│   │   │   └── Logger.swift                  # Logging utility
│   │   └── Constants/
│   │       ├── AppConstants.swift            # App constants
│   │       ├── CameraConstants.swift         # Camera constants
│   │       └── PerformanceConstants.swift    # Performance constants
│   └── Resources/                     # App resources
│       ├── Assets.xcassets/             # Image assets
│       │   ├── AppIcon.appiconset/
│       │   ├── CameraIcons/
│       │   ├── UIIcons/
│       │   └── LaunchImages/
│       ├── Localizable.strings           # Localization
│       ├── Info.plist                   # App configuration
│       └── entitlements.entitlements    # App entitlements
└── Tests/                              # Test suite
    ├── UnitTests/                      # Unit tests
    │   ├── Core/
    │   │   ├── CameraTests/
    │   │   ├── AudioTests/
    │   │   └── PermissionTests/
    │   ├── Features/
    │   │   ├── RecordingTests/
    │   │   ├── GalleryTests/
    │   │   └── SettingsTests/
    │   ├── Performance/
    │   │   ├── MemoryTests/
    │   │   ├── BatteryTests/
    │   │   └── ThermalTests/
    │   └── VideoProcessing/
    │       ├── VideoProcessorTests/
    │       └── FrameProcessorTests/
    ├── IntegrationTests/               # Integration tests
    │   ├── CameraIntegrationTests/
    │   ├── AudioIntegrationTests/
    │   └── PerformanceIntegrationTests/
    ├── UITests/                        # UI tests
    │   ├── RecordingUITests/
    │   ├── GalleryUITests/
    │   └── SettingsUITests/
    └── PerformanceTests/               # Performance tests
        ├── MemoryPerformanceTests/
        ├── CPUPerformanceTests/
        └── BatteryPerformanceTests/
```

## Key Architecture Principles

### 1. Actor-Based Concurrency
All state management is handled through Swift 6.2 actors to ensure compile-time thread safety:
- **Main Actors**: For UI-related state
- **Global Actors**: For shared system resources
- **Custom Actors**: For feature-specific state

### 2. Feature-First Organization
Each feature is self-contained with its own:
- Views (SwiftUI-first with UIKit integration)
- ViewModels (@Observable pattern)
- Coordinators (navigation logic)
- Components (reusable UI elements)

### 3. Performance-First Design
Performance management is integrated throughout:
- Memory optimization with Span-based access
- Battery-aware quality adjustment
- Thermal state monitoring
- Hardware synchronization

### 4. Modern iOS 26+ Features
Leverages latest iOS capabilities:
- Hardware multi-cam synchronization
- AI-powered format selection
- Enhanced HDR with Dolby Vision IQ
- Liquid glass design system

## Module Dependencies

### Core Dependencies
- **Camera** depends on: Permissions, Performance
- **Audio** depends on: Permissions, Performance
- **VideoProcessing** depends on: Performance, Memory

### Feature Dependencies
- **Recording** depends on: Camera, Audio, VideoProcessing
- **Gallery** depends on: Storage, VideoProcessing
- **Settings** depends on: All core modules

### Design System Dependencies
- **LiquidGlass** depends on: Core iOS frameworks
- **Components** depends on: LiquidGlass, Tokens
- **Tokens** are self-contained

## Swift 6.2 Implementation Notes

### Actor Isolation
- All mutable state is actor-isolated
- MainActor used for UI state
- Custom actors for background processing

### Sendable Conformance
- All shared data types conform to Sendable
- Value types preferred for thread safety
- Reference types properly synchronized

### AsyncStream Usage
- Replaces delegate patterns
- Type-safe event communication
- Backpressure handling

### Span Implementation
- High-performance pixel buffer access
- Zero-cost bounds checking
- Memory-safe operations

## Performance Optimizations

### Memory Management
- Predictive memory compaction
- Span-based buffer access
- Automatic resource cleanup

### Battery Optimization
- Adaptive quality adjustment
- Power-aware processing
- Background task optimization

### Thermal Management
- Proactive thermal monitoring
- Quality degradation strategies
- Heat dissipation optimization

## Testing Strategy

### Unit Testing
- All actors tested in isolation
- Mock dependencies for testing
- Performance benchmarks included

### Integration Testing
- End-to-end camera pipeline
- Memory pressure scenarios
- Battery life validation

### UI Testing
- SwiftUI view testing
- Accessibility validation
- Performance testing

## Build Configuration

### Debug Configuration
- Strict concurrency checking
- Thread sanitizer enabled
- Memory debugging tools
- Performance profiling

### Release Configuration
- Optimized compilation
- Dead code elimination
- Size optimization
- Performance tuning

## Deployment Considerations

### App Store Requirements
- iOS 26.0+ minimum
- Swift 6.2 runtime
- Privacy manifest
- Performance metrics

### Device Support
- iPhone 12+ (minimum)
- Dual camera required
- 4GB RAM recommended
- A14 Bionic chip preferred
