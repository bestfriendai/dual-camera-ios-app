# Camera Preview Fix

## Issue
Camera was stuck at "Starting..." and not showing the preview.

## Root Cause
The delayed session start I added (0.1 second delay) was causing a race condition where:
1. The delegate callback was fired asynchronously on main thread
2. The session start was scheduled with a delay on main thread
3. The timing was unpredictable and could cause the session to not start properly

## Fix Applied
Reverted to starting the session immediately on the sessionQueue after configuration completes:

```swift
// Before (BROKEN):
DispatchQueue.main.async {
    self.delegate?.didFinishCameraSetup()
}

DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
    self.sessionQueue.async {
        session.startRunning()
    }
}

// After (FIXED):
DispatchQueue.main.async {
    self.delegate?.didFinishCameraSetup()
}

// Start session immediately on sessionQueue
if let session = self.captureSession, !session.isRunning {
    session.startRunning()
}
```

## Additional Improvements
1. Added `hasRequestedPermissions` flag to prevent duplicate permission requests
2. Enhanced debug logging throughout the camera setup flow
3. Added detailed logging in `setupPreviewLayers()` to diagnose issues

## Testing Instructions

### On Simulator:
1. Build and run the app
2. You should see "Simulator Mode" messages in both camera previews
3. The app should not be stuck at "Starting..."

### On Physical Device:
1. Build and run on a device with multi-camera support (iPhone XS or later)
2. Grant camera, microphone, and photo library permissions when prompted
3. Both camera previews should appear within 1-2 seconds
4. No black screens should appear
5. Test all buttons:
   - Record button (should start/stop recording)
   - Flash button (should toggle flash)
   - Swap camera button (should swap front/back order)
   - Quality button (should show quality options)
   - Gallery button (should open gallery)
   - Grid button (should toggle grid overlay)
   - Triple output button (should show output options)
   - Audio source button (should show audio options)

## Debug Logging
The app now includes extensive debug logging. Look for these messages in the console:

```
VIEWCONTROLLER: viewDidAppear
VIEWCONTROLLER: Requesting permissions (optimized)
DEBUG: Requesting all permissions in parallel...
VIEWCONTROLLER: Permissions result - allGranted: true
VIEWCONTROLLER: All permissions granted, setting up cameras
VIEWCONTROLLER: Setting up cameras after permissions
VIEWCONTROLLER: Calling dualCameraManager.setupCameras()
DEBUG: Setting up cameras (attempt 1/3)...
DEBUG: Front camera: Front Camera
DEBUG: Back camera: Back Camera
DEBUG: Audio device: iPhone Microphone
DEBUG: MultiCam supported: true
DEBUG: Starting capture session...
DEBUG: ✅ Capture session started - isRunning: true
VIEWCONTROLLER: didFinishCameraSetup called - assigning preview layers
VIEWCONTROLLER: Setting up preview layers
VIEWCONTROLLER: Assigning preview layers to views
VIEWCONTROLLER: ✅ Preview layers assigned
VIEWCONTROLLER: ✅ Camera setup complete, preview layers assigned
```

## Expected Behavior
1. App launches quickly (< 1 second to UI)
2. Permission dialogs appear together (not sequentially)
3. Camera previews initialize within 1-2 seconds
4. Both front and back camera previews show live video
5. All buttons are responsive and functional

## If Still Stuck at "Starting..."

Check the console logs for:
1. Permission request results
2. Camera device discovery
3. Session configuration
4. Preview layer assignment

Common issues:
- **Permissions denied**: Check Settings > Privacy > Camera/Microphone
- **MultiCam not supported**: Device must be iPhone XS or later
- **Simulator mode**: Simulator will show placeholder messages, not actual camera
- **Preview layers nil**: Check if `didFinishCameraSetup()` is being called

## Files Modified
1. `DualCameraApp/DualCameraManager.swift` - Fixed session start timing
2. `DualCameraApp/ViewController.swift` - Added permission flag and enhanced logging

## Performance Maintained
All performance optimizations from the previous fix are still in place:
- ✅ Parallel permission requests
- ✅ Permission caching
- ✅ Async device discovery
- ✅ Background audio session configuration
- ✅ Deferred non-critical setup

The only change is removing the problematic delay before starting the session.

