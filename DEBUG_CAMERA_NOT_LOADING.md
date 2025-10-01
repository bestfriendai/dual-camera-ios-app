# Debug: Camera Not Loading

## Immediate Steps

### 1. Clean Build
```bash
# In Xcode:
1. Product > Clean Build Folder (Shift+Cmd+K)
2. Delete app from iPhone
3. Rebuild and install
```

### 2. Check Xcode Console

Look for these debug messages in order:

```
✅ Expected Flow:
DEBUG: Setting up cameras...
DEBUG: Front camera: [device name]
DEBUG: Back camera: [device name]
DEBUG: Audio device: [device name]
DEBUG: MultiCam supported: true
DEBUG: Starting multicam session configuration
DEBUG: Front preview mirroring supported: true
DEBUG: Auto adjusts before: true
DEBUG: Auto adjusts after: false
DEBUG: Front preview mirrored: true
DEBUG: Configuration complete - all outputs configured successfully
DEBUG: Committing configuration changes
DEBUG: Configuration committed successfully
DEBUG: Capture session started successfully
```

### 3. Check for Errors

Look for these error patterns:

```
❌ Configuration Failed:
- "Unable to add front camera input"
- "Unable to configure front preview layer"
- "Failed to obtain camera ports"
- Any "throw DualCameraError" messages

❌ Mirroring Issues:
- "Cannot be set when automaticallyAdjustsVideoMirroring is YES"
- "Front preview mirroring NOT supported"

❌ Session Issues:
- "Cannot start session"
- "Session interrupted"
- "isRunning: false"
```

## Common Issues

### Issue: "automaticallyAdjustsVideoMirroring" crash
**Symptom**: App crashes when starting camera
**Cause**: Trying to set isVideoMirrored while auto-adjust is on
**Status**: Should be FIXED - we now set `automaticallyAdjustsVideoMirroring = false` first

### Issue: Camera permissions denied
**Symptom**: Black screens, no preview
**Check**: Settings > Privacy > Camera > Dual Camera (should be ON)
**Fix**: Grant permissions and restart app

### Issue: MultiCam not supported
**Symptom**: Error "This device does not support simultaneous front and back camera capture"
**Check**: Need iPhone XS/XR or newer with iOS 13+
**Fix**: None - device limitation

### Issue: Session won't start
**Symptom**: Spinner keeps spinning, cameras never appear
**Debug**: Look for "Capture session started successfully" in console
**Possible causes**:
- Configuration failed silently
- isDeferredSetupComplete = false
- Preview layers not created

## Debug Version with Extra Logging

The current version has extensive debug logging. Run the app and copy ALL console output, then look for:

1. **Where does it stop?**
   - Last DEBUG message shows where configuration failed

2. **Any error messages?**
   - Red errors or warnings

3. **Session state?**
   - "isRunning: true" means session started
   - "isRunning: false" means session never started

## Quick Fix: Disable Mirroring Temporarily

If mirroring is causing issues, temporarily disable it:

### DualCameraManager.swift

Comment out all mirroring code:

```swift
// if frontPreviewConnection.isVideoMirroringSupported {
//     if frontPreviewConnection.automaticallyAdjustsVideoMirroring {
//         frontPreviewConnection.automaticallyAdjustsVideoMirroring = false
//     }
//     frontPreviewConnection.isVideoMirrored = true
// }
```

Do this for all 4 mirroring locations (preview, recording, photo, data).

If camera loads without mirroring, then mirroring is the problem.

## What Changed That Might Break Things

### Recent Changes:
1. Added `import Photos` - should not affect camera loading
2. Added `saveVideoToPhotosLibrary()` method - only called after recording
3. Enabled triple output mode - happens during recording, not setup
4. Added video mirroring - THIS could cause issues

### Mirroring Changes (4 locations):
- Line ~267: Front preview connection
- Line ~320: Front movie recording connection
- Line ~347: Front photo connection
- Line ~391: Front data output connection

Each adds:
```swift
if connection.automaticallyAdjustsVideoMirroring {
    connection.automaticallyAdjustsVideoMirroring = false
}
connection.isVideoMirrored = true
```

## Test: Minimal Configuration

Create a test build that ONLY does camera setup, no mirroring:

1. Comment out ALL mirroring code (8 lines total across 4 locations)
2. Build and run
3. If camera loads → mirroring is the problem
4. If camera still doesn't load → different issue

## Next Steps

1. **Build and run** with current debug logging
2. **Copy entire Xcode console output**
3. **Look for the last "DEBUG:" message** - that's where it's failing
4. **Check for any errors** (red text)
5. **Share console output** to diagnose

The debug messages will tell us exactly where the configuration is failing.
