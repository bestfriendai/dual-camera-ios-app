# Testing Checklist - Dual Camera App

## Pre-Testing Setup

### Requirements
- [ ] Physical iPhone device (iPhone XS or newer)
- [ ] iOS 15.0 or later
- [ ] At least 5GB free storage
- [ ] Xcode 15+ installed
- [ ] Developer account configured

### Build and Install
- [ ] Clean build successful
- [ ] No compiler errors
- [ ] No compiler warnings (except AppIntents)
- [ ] App installs on device
- [ ] App launches without crash

---

## Phase 1: Startup Performance Testing

### App Launch
- [ ] Cold launch (app not in memory) < 1 second
- [ ] Warm launch (app in background) < 0.5 seconds
- [ ] Hot launch (app suspended) < 0.3 seconds
- [ ] Loading indicator appears immediately
- [ ] Status label shows "Initializing cameras..."
- [ ] Loading indicator disappears when ready
- [ ] Status label changes to "Ready to record"

### Camera Initialization
- [ ] Camera permission prompt appears
- [ ] Audio permission prompt appears
- [ ] Camera preview appears after permissions granted
- [ ] Both camera previews show live feed
- [ ] No black screens or frozen frames
- [ ] Camera ready in < 1.5 seconds from launch

### Memory Usage
- [ ] Memory at launch < 100MB
- [ ] No memory leaks during launch
- [ ] Memory stable after initialization

### Performance Monitoring
- [ ] Open Instruments
- [ ] Select os_signpost template
- [ ] Run app and check "App Launch" interval
- [ ] Verify "Camera Setup" interval
- [ ] Both intervals < 1.5 seconds total

---

## Phase 2: Triple Output Recording

### Basic Recording
- [ ] Tap record button
- [ ] Recording starts immediately
- [ ] Timer shows elapsed time
- [ ] Both camera previews remain smooth
- [ ] Tap stop button
- [ ] Recording stops immediately
- [ ] Status shows "Processing..." briefly
- [ ] Status returns to "Ready to record"

### File Creation
- [ ] Navigate to gallery
- [ ] Verify 3 files created:
  - [ ] front_[timestamp].mov exists
  - [ ] back_[timestamp].mov exists
  - [ ] combined_[timestamp].mp4 exists
- [ ] All 3 files have same timestamp
- [ ] All 3 files are playable

### Video Quality - Front Camera
- [ ] Open front_[timestamp].mov
- [ ] Video plays smoothly
- [ ] Audio is clear
- [ ] Resolution matches quality setting
- [ ] No frame drops or stuttering
- [ ] Orientation correct (portrait)

### Video Quality - Back Camera
- [ ] Open back_[timestamp].mov
- [ ] Video plays smoothly
- [ ] No audio (expected - audio on front only)
- [ ] Resolution matches quality setting
- [ ] No frame drops or stuttering
- [ ] Orientation correct (portrait)

### Video Quality - Combined
- [ ] Open combined_[timestamp].mp4
- [ ] Video plays smoothly
- [ ] Audio is clear (from front camera)
- [ ] Both cameras visible in layout
- [ ] Layout correct (side-by-side default)
- [ ] No sync issues between cameras
- [ ] No sync issues between audio/video
- [ ] Resolution matches quality setting
- [ ] No artifacts or glitches

### Different Quality Settings

**720p HD:**
- [ ] Record 30-second video
- [ ] All 3 files created
- [ ] Combined video is 1280x720
- [ ] File sizes reasonable (~50MB combined)
- [ ] Quality acceptable

**1080p Full HD:**
- [ ] Record 30-second video
- [ ] All 3 files created
- [ ] Combined video is 1920x1080
- [ ] File sizes reasonable (~75MB combined)
- [ ] Quality good

**4K Ultra HD:**
- [ ] Record 30-second video
- [ ] All 3 files created
- [ ] Combined video is 3840x2160
- [ ] File sizes reasonable (~150MB combined)
- [ ] Quality excellent
- [ ] No performance issues

### Recording Duration Tests

**Short Recording (< 5 seconds):**
- [ ] Record 3-second video
- [ ] All 3 files created
- [ ] Videos playable
- [ ] No errors

**Medium Recording (1-2 minutes):**
- [ ] Record 90-second video
- [ ] All 3 files created
- [ ] Videos playable
- [ ] No frame drops
- [ ] No overheating

**Long Recording (5+ minutes):**
- [ ] Record 5-minute video
- [ ] All 3 files created
- [ ] Videos playable
- [ ] Check device temperature
- [ ] Check battery usage
- [ ] No crashes or errors

### Layout Testing

**Note:** Currently requires code changes. Test each layout:

**Side-by-Side:**
- [ ] Set `recordingLayout = .sideBySide`
- [ ] Record test video
- [ ] Combined video shows 50/50 split
- [ ] Front camera on left
- [ ] Back camera on right

**Picture-in-Picture (Top Right):**
- [ ] Set `recordingLayout = .pictureInPicture(position: .topRight, size: .medium)`
- [ ] Record test video
- [ ] Back camera fills screen
- [ ] Front camera in top-right corner
- [ ] PIP has white border

**Picture-in-Picture (Bottom Left):**
- [ ] Set `recordingLayout = .pictureInPicture(position: .bottomLeft, size: .small)`
- [ ] Record test video
- [ ] Back camera fills screen
- [ ] Front camera in bottom-left corner
- [ ] PIP smaller than medium

**Front Primary:**
- [ ] Set `recordingLayout = .frontPrimary`
- [ ] Record test video
- [ ] Front camera takes 75% width
- [ ] Back camera takes 25% width

**Back Primary:**
- [ ] Set `recordingLayout = .backPrimary`
- [ ] Record test video
- [ ] Back camera takes 75% width
- [ ] Front camera takes 25% width

---

## Phase 3: UI/UX Testing

### Glassmorphism
- [ ] Controls container has blur effect
- [ ] Blur is modern (ultra-thin material)
- [ ] Border visible and subtle
- [ ] Corner radius smooth (24pt)
- [ ] Shadow visible for depth
- [ ] Vibrancy effect working

### Responsive UI
- [ ] All buttons respond immediately
- [ ] No lag when tapping controls
- [ ] Smooth transitions
- [ ] Loading states clear
- [ ] Error messages readable

### Dark Mode
- [ ] Enable dark mode in iOS settings
- [ ] App adapts correctly
- [ ] Text remains readable
- [ ] Glassmorphism still visible
- [ ] No contrast issues

### Orientation
- [ ] App locked to portrait (expected)
- [ ] Rotating device doesn't break UI
- [ ] Camera previews remain correct

---

## Phase 4: Performance Testing

### CPU Usage
- [ ] Open Activity Monitor
- [ ] Launch app
- [ ] CPU usage < 50% at idle
- [ ] Start recording
- [ ] CPU usage 30-50% during recording
- [ ] Stop recording
- [ ] CPU returns to idle levels

### GPU Usage
- [ ] Use Xcode GPU profiler
- [ ] Launch app
- [ ] GPU usage minimal at idle
- [ ] Start recording
- [ ] GPU usage 20-40% during recording
- [ ] No GPU warnings or errors

### Memory Usage
- [ ] Launch app: < 100MB
- [ ] Start recording: < 300MB
- [ ] During recording: stable, no growth
- [ ] Stop recording: memory released
- [ ] No memory leaks detected

### Battery Usage
- [ ] Fully charge device
- [ ] Record for 1 hour total (multiple sessions)
- [ ] Check battery usage in Settings
- [ ] Battery drain < 20% per hour
- [ ] Device doesn't overheat

### Thermal Performance
- [ ] Record 4K video for 5 minutes
- [ ] Monitor device temperature
- [ ] Device should be warm but not hot
- [ ] No thermal warnings
- [ ] No automatic quality reduction (yet)

### Storage Usage
- [ ] Check available storage before test
- [ ] Record 10 videos (30 seconds each)
- [ ] Check storage used
- [ ] Verify ~3x storage vs single camera
- [ ] Delete videos
- [ ] Verify storage freed

---

## Phase 5: Edge Cases & Error Handling

### Low Storage
- [ ] Fill device storage to < 500MB
- [ ] Try to record
- [ ] Verify appropriate error/warning
- [ ] App doesn't crash

### Interrupted Recording
- [ ] Start recording
- [ ] Receive phone call
- [ ] Recording stops gracefully
- [ ] Files saved correctly
- [ ] App recovers after call

### Background/Foreground
- [ ] Start recording
- [ ] Press home button
- [ ] Recording stops
- [ ] Return to app
- [ ] App state correct
- [ ] Can record again

### Permission Denied
- [ ] Deny camera permission
- [ ] App shows alert
- [ ] Alert has "Settings" button
- [ ] Tapping opens Settings
- [ ] Grant permission
- [ ] Return to app
- [ ] Camera works

### Multiple Sessions
- [ ] Record video
- [ ] Stop
- [ ] Record another video immediately
- [ ] Stop
- [ ] Repeat 5 times
- [ ] All recordings successful
- [ ] No degradation in performance

---

## Phase 6: Integration Testing

### Gallery Integration
- [ ] Record several videos
- [ ] Open gallery
- [ ] All videos listed
- [ ] Thumbnails generated
- [ ] Tap video to play
- [ ] Playback works
- [ ] Share button works
- [ ] Delete button works

### Video Merger (Legacy)
- [ ] Record video (creates 3 files)
- [ ] Tap "Merge Videos" button
- [ ] Can still manually merge if desired
- [ ] Manual merge creates 4th file
- [ ] No conflicts with auto-merged file

### Camera Controls
- [ ] Flash toggle works
- [ ] Zoom works on both cameras
- [ ] Focus tap works on both cameras
- [ ] Swap cameras works
- [ ] Quality selector works

### Photo Mode
- [ ] Switch to photo mode
- [ ] Take photo
- [ ] Both cameras capture
- [ ] Photos saved correctly
- [ ] Switch back to video mode
- [ ] Recording still works

---

## Phase 7: Device Compatibility

### Test on Multiple Devices

**iPhone XS (Minimum Supported):**
- [ ] App installs
- [ ] Multi-cam works
- [ ] Triple output works
- [ ] Performance acceptable
- [ ] No crashes

**iPhone 12 (Baseline):**
- [ ] App installs
- [ ] All features work
- [ ] Performance good
- [ ] 4K recording smooth

**iPhone 15 Pro (Latest):**
- [ ] App installs
- [ ] All features work
- [ ] Performance excellent
- [ ] Ready for future features (spatial video, etc.)

### iOS Version Testing

**iOS 15.0 (Minimum):**
- [ ] App runs
- [ ] All features work
- [ ] No API compatibility issues

**iOS 17.0:**
- [ ] App runs
- [ ] All features work
- [ ] Modern features available

**iOS 18.0+ (Latest):**
- [ ] App runs
- [ ] Modern materials work
- [ ] All features work
- [ ] Ready for iOS 18 features

---

## Phase 8: Regression Testing

### Existing Features Still Work

**Basic Recording:**
- [ ] Single camera recording works
- [ ] Separate files still created
- [ ] Quality settings work
- [ ] Flash works
- [ ] Zoom works

**Video Gallery:**
- [ ] Gallery loads
- [ ] Videos play
- [ ] Share works
- [ ] Delete works
- [ ] Thumbnails correct

**Manual Merge:**
- [ ] Can select two videos
- [ ] Merge button appears
- [ ] Merge completes
- [ ] Merged video correct
- [ ] Progress shown

**Settings:**
- [ ] Quality selector works
- [ ] Mode switcher works
- [ ] Grid overlay works
- [ ] Storage label updates

---

## Phase 9: User Acceptance Testing

### First-Time User Experience
- [ ] App is intuitive
- [ ] No confusion about triple output
- [ ] Loading states clear
- [ ] Error messages helpful
- [ ] Gallery easy to navigate

### Power User Experience
- [ ] Quick access to features
- [ ] No unnecessary steps
- [ ] Efficient workflow
- [ ] Professional results
- [ ] Flexible options

### Accessibility
- [ ] VoiceOver works
- [ ] Dynamic type supported
- [ ] Contrast sufficient
- [ ] Touch targets large enough
- [ ] No color-only indicators

---

## Phase 10: Final Validation

### Build Verification
- [ ] Clean build succeeds
- [ ] Archive succeeds
- [ ] No warnings (except AppIntents)
- [ ] App size reasonable (< 50MB)
- [ ] All assets included

### Documentation
- [ ] README.md updated
- [ ] IMPLEMENTATION_COMPLETE.md accurate
- [ ] FEATURE_USAGE_GUIDE.md helpful
- [ ] Code comments clear
- [ ] API documented

### Code Quality
- [ ] No force unwraps
- [ ] Proper error handling
- [ ] Memory management correct
- [ ] Thread safety verified
- [ ] No retain cycles

---

## Success Criteria

### Must Pass (Critical)
- ✅ App builds without errors
- ✅ App launches in < 1 second
- ✅ Triple output creates 3 files
- ✅ All 3 files playable
- ✅ No crashes during normal use
- ✅ Memory usage < 300MB during recording

### Should Pass (Important)
- ✅ Camera ready in < 1.5 seconds
- ✅ Combined video quality excellent
- ✅ No frame drops at 1080p
- ✅ Battery usage < 20% per hour
- ✅ UI responsive and smooth

### Nice to Have (Optional)
- ✅ 4K recording smooth on all devices
- ✅ No thermal issues during long recordings
- ✅ Perfect audio/video sync
- ✅ All layouts work perfectly

---

## Issue Tracking

### Critical Issues (Must Fix)
- [ ] Issue 1: _____________________
- [ ] Issue 2: _____________________

### Major Issues (Should Fix)
- [ ] Issue 1: _____________________
- [ ] Issue 2: _____________________

### Minor Issues (Nice to Fix)
- [ ] Issue 1: _____________________
- [ ] Issue 2: _____________________

---

## Sign-Off

**Tested By:** _____________________  
**Date:** _____________________  
**Device:** _____________________  
**iOS Version:** _____________________  

**Overall Status:** ⬜ PASS  ⬜ FAIL  ⬜ NEEDS WORK

**Notes:**
_____________________________________________
_____________________________________________
_____________________________________________

**Ready for Production:** ⬜ YES  ⬜ NO

---

## Next Steps After Testing

If all tests pass:
1. Create TestFlight build
2. Invite beta testers
3. Gather feedback
4. Iterate if needed
5. Submit to App Store

If issues found:
1. Document all issues
2. Prioritize by severity
3. Fix critical issues first
4. Re-test after fixes
5. Repeat until all pass

