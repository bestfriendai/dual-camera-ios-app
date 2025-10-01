# Front Camera Horizontal Flip/Mirror - Fixed

## Issue
When moving the camera, the front camera preview moved in the opposite direction compared to the back camera, creating a confusing experience. This is because front cameras typically show a non-mirrored view by default, but users expect a "mirror" view like they see in selfie cameras.

## Solution
Enabled horizontal mirroring (video mirroring) for the front camera on ALL outputs:
- ✅ Preview layer (what you see on screen)
- ✅ Movie recording output (saved video files)
- ✅ Photo capture output (saved photos)
- ✅ Data output for triple recording (combined video)

## Changes Made

### DualCameraManager.swift

Added video mirroring to all front camera connections. **Important**: Must set `automaticallyAdjustsVideoMirroring = false` before setting `isVideoMirrored = true`, otherwise the app crashes with:
```
*** -[AVCaptureConnection setVideoMirrored:] Cannot be set when automaticallyAdjustsVideoMirroring is YES
```

#### 1. Preview Connection (Line 267)
```swift
if frontPreviewConnection.isVideoMirroringSupported {
    frontPreviewConnection.automaticallyAdjustsVideoMirroring = false
    frontPreviewConnection.isVideoMirrored = true
}
```
**Effect**: Front camera preview now shows mirrored view like a mirror

#### 2. Movie Recording Connection (Line 320)
```swift
if frontConnection.isVideoMirroringSupported {
    frontConnection.automaticallyAdjustsVideoMirroring = false
    frontConnection.isVideoMirrored = true
}
```
**Effect**: Saved front camera videos are mirrored

#### 3. Photo Capture Connection (Line 347)
```swift
if frontPhotoConnection.isVideoMirroringSupported {
    frontPhotoConnection.automaticallyAdjustsVideoMirroring = false
    frontPhotoConnection.isVideoMirrored = true
}
```
**Effect**: Front camera photos are mirrored

#### 4. Data Output Connection for Triple Recording (Line 391)
```swift
if frontDataConnection.isVideoMirroringSupported {
    frontDataConnection.automaticallyAdjustsVideoMirroring = false
    frontDataConnection.isVideoMirrored = true
}
```
**Effect**: Front camera in combined/merged videos is mirrored

## User Experience

### Before Fix
- Move camera left → front preview moves right, back preview moves left
- Confusing and disorienting
- Text appears backwards in front camera

### After Fix
- Move camera left → BOTH previews move left (natural/intuitive)
- Front camera acts like a mirror (expected behavior)
- Movement direction matches between cameras
- Text still appears backwards (normal for mirror view)

## How Video Mirroring Works

Video mirroring flips the image horizontally along the vertical axis:

```
Original:        Mirrored:
[  A  B  ]  →   [  B  A  ]
```

This is the standard behavior for front-facing cameras in apps like:
- iPhone Camera app (selfie mode)
- FaceTime
- Instagram/Snapchat front camera
- Zoom/video conferencing apps

## Technical Details

### What Gets Mirrored
- ✅ Visual preview on screen
- ✅ Recorded video file
- ✅ Captured photo
- ✅ Combined/merged video (front camera portion)

### What Doesn't Change
- ❌ Back camera (remains non-mirrored)
- ❌ Audio (not affected)
- ❌ Metadata (orientation, timestamps)

### Platform Support
- Requires `isVideoMirroringSupported` to be `true`
- Supported on all devices with front camera
- Works on iOS 13+ (required for multicam)

## Testing

### Test Movement Synchronization
1. Hold phone steady
2. Start recording
3. Move camera slowly to the left
4. **Expected**: Both previews move left together
5. Move camera slowly to the right
6. **Expected**: Both previews move right together

### Test Text/Objects
1. Hold up text/object in front of camera
2. Check front camera preview
3. **Expected**: Text appears backwards (mirrored)
4. Check back camera preview
5. **Expected**: Text appears normal (not mirrored)

### Test Saved Videos
1. Record a video with text visible in front camera
2. Save and open in Photos app
3. Front camera video should show text backwards (mirrored)
4. Back camera video should show text normal
5. Combined video: front side mirrored, back side normal

## Common Questions

### Q: Why is text backwards in the front camera?
**A**: This is normal and expected! It's how mirrors work. When you look in a mirror, text appears backwards. Same principle here.

### Q: Can I turn off mirroring?
**A**: Yes, remove the `isVideoMirrored = true` lines to disable mirroring. However, this will make camera movement feel unnatural.

### Q: Why doesn't iPhone Camera app show backwards text?
**A**: Apple's Camera app DOES show mirrored preview (backwards text) while recording, but automatically flips the final saved photo/video. Some apps do this, some don't. Our app saves the mirrored version.

### Q: Should the back camera also be mirrored?
**A**: No! The back camera should never be mirrored. It captures the world as-is, not as a reflection.

## Advanced: Un-mirroring Saved Videos

If you want preview mirrored but saved videos normal (like Apple Camera):

```swift
// Keep preview mirrored
if frontPreviewConnection.isVideoMirroringSupported {
    frontPreviewConnection.isVideoMirrored = true
}

// But disable for recording
if frontConnection.isVideoMirroringSupported {
    frontConnection.isVideoMirrored = false  // Changed to false
}
```

This creates a disconnect between what you see and what's saved, but matches Apple Camera behavior.

## Summary

All front camera outputs now use horizontal mirroring for a natural, intuitive camera experience where movement direction matches between front and back cameras.
