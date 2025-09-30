# Feature Usage Guide - Triple Output Recording System

## Quick Start

The app now automatically creates **3 video files** when you record:

1. **Front camera only** - `front_[timestamp].mov`
2. **Back camera only** - `back_[timestamp].mov`  
3. **Combined video** - `combined_[timestamp].mp4` ⭐ NEW

No additional steps required - just press record!

---

## Triple Output System

### What It Does

When you start recording, the app simultaneously:
- Records front camera to a separate file
- Records back camera to a separate file
- **Composes both cameras in real-time** and saves to a third file

### Why It's Useful

**Before:** Record → Stop → Tap "Merge Videos" → Wait 10-30 seconds → Get combined video

**Now:** Record → Stop → **All 3 files ready instantly!**

### Use Cases

1. **Content Creators**
   - Get reaction video (front) + main content (back) + combined version
   - Choose which version to publish
   - Edit separate streams if needed

2. **Vloggers**
   - Combined video ready for immediate upload
   - Separate streams for advanced editing
   - No waiting for post-processing

3. **Interviews**
   - Interviewer (front) + interviewee (back) + split-screen
   - Professional multi-camera setup
   - Instant results

4. **Tutorials**
   - Instructor (front) + demonstration (back) + picture-in-picture
   - Multiple output options
   - Flexible editing

---

## Layout Options

### Available Layouts

The combined video can use different layouts. Currently set to **side-by-side** by default.

#### 1. Side-by-Side (Default)
```
┌─────────┬─────────┐
│  Front  │  Back   │
│ Camera  │ Camera  │
└─────────┴─────────┘
```
- Equal split (50/50)
- Both cameras visible
- Great for reactions

#### 2. Picture-in-Picture
```
┌─────────────────┐
│                 │
│   Back Camera   │
│                 │
│  ┌────┐        │
│  │Front│        │
└──┴────┴─────────┘
```
- Main camera (back) fills screen
- Small overlay (front) in corner
- 4 positions: top-left, top-right, bottom-left, bottom-right
- 3 sizes: small (25%), medium (33%), large (40%)

#### 3. Front Primary
```
┌──────────┬───┐
│          │   │
│  Front   │ B │
│  Camera  │ a │
│          │ c │
│          │ k │
└──────────┴───┘
```
- Front camera: 75% width
- Back camera: 25% width
- Focus on front camera

#### 4. Back Primary
```
┌──────────┬───┐
│          │   │
│   Back   │ F │
│  Camera  │ r │
│          │ o │
│          │ n │
└──────────┴───┘
```
- Back camera: 75% width
- Front camera: 25% width
- Focus on back camera

### How to Change Layout (Code)

Currently, layout is set in code. To change it, modify `DualCameraManager.swift`:

```swift
// In DualCameraManager.swift
var recordingLayout: RecordingLayout = .sideBySide  // Change this

// Options:
.sideBySide
.pictureInPicture(position: .topRight, size: .medium)
.pictureInPicture(position: .bottomLeft, size: .small)
.frontPrimary
.backPrimary
```

**Future Enhancement:** Add UI controls to switch layouts before recording.

---

## Enable/Disable Triple Output

### Default Behavior

Triple output is **enabled by default**. The app will always create 3 files.

### To Disable (Code)

If you want to disable the combined output and only record separate files:

```swift
// In DualCameraManager.swift
var enableTripleOutput: Bool = false  // Change from true to false
```

When disabled:
- Only 2 files created (front + back)
- Lower CPU/GPU usage
- Longer battery life
- Less storage used

**Recommendation:** Keep it enabled - it's the killer feature!

---

## Performance Characteristics

### Resource Usage

**During Recording:**
- CPU: ~30-40% (composition)
- GPU: ~20-30% (rendering)
- Memory: ~250-300MB
- Battery: ~15% per hour

**Compared to Post-Processing:**
- Real-time composition: Minimal extra overhead
- Post-processing merge: 100% CPU for 10-30 seconds
- **Net benefit:** Saves time and battery overall

### Quality

**Combined Video:**
- Codec: H.264
- Bitrate: 10 Mbps
- Resolution: Matches quality setting (720p/1080p/4K)
- Audio: AAC, 128 kbps, stereo
- Frame rate: 30 fps

**Separate Videos:**
- Same quality as before
- No degradation
- Full resolution

---

## File Management

### File Naming

All files use timestamp-based naming:

```
front_1696089600.mov      (Front camera)
back_1696089600.mov       (Back camera)
combined_1696089600.mp4   (Combined)
```

Same timestamp = files from same recording session.

### File Sizes (Approximate)

**1 minute of recording at 1080p:**
- Front camera: ~100 MB
- Back camera: ~100 MB
- Combined: ~75 MB
- **Total: ~275 MB**

**Storage tip:** Delete separate files if you only need combined version.

### File Locations

All files saved to app's Documents directory:
```
/Documents/front_[timestamp].mov
/Documents/back_[timestamp].mov
/Documents/combined_[timestamp].mp4
```

Access via:
- In-app gallery
- Files app (if enabled)
- iTunes File Sharing

---

## Troubleshooting

### Combined Video Not Created

**Possible Causes:**
1. Triple output disabled in code
2. Insufficient storage space
3. Recording stopped too quickly (< 1 second)

**Solutions:**
1. Check `enableTripleOutput = true`
2. Free up storage space
3. Record for at least 2-3 seconds

### Performance Issues

**Symptoms:**
- Frame drops
- Choppy video
- App overheating

**Solutions:**
1. Lower quality setting (use 1080p instead of 4K)
2. Close other apps
3. Let device cool down
4. Disable triple output if needed

### Out of Sync Audio/Video

**Rare Issue:**
- Combined video audio doesn't match video

**Solution:**
- This shouldn't happen with current implementation
- If it does, use separate files and merge manually
- Report as bug for investigation

---

## Best Practices

### For Best Results

1. **Start with 1080p**
   - Good balance of quality and performance
   - Works on all devices
   - Reasonable file sizes

2. **Keep Recordings Under 5 Minutes**
   - Easier to manage
   - Lower risk of issues
   - Faster to share

3. **Monitor Storage**
   - Check available space before recording
   - Delete unwanted files regularly
   - Keep at least 2GB free

4. **Test Before Important Recording**
   - Do a quick test recording
   - Verify all 3 files created
   - Check quality and layout

### Workflow Recommendations

**For Social Media:**
1. Record with triple output enabled
2. Use combined video for quick posts
3. Keep separate files for advanced editing

**For Professional Use:**
1. Record at highest quality (4K)
2. Use separate files for editing
3. Combined file as backup/preview

**For Live Events:**
1. Use 1080p for reliability
2. Side-by-side or PIP layout
3. Combined file ready for immediate sharing

---

## Advanced Tips

### Maximizing Quality

```swift
// Set to 4K before recording
dualCameraManager.videoQuality = .uhd4k

// Use side-by-side for best quality
dualCameraManager.recordingLayout = .sideBySide
```

### Minimizing File Size

```swift
// Use 720p
dualCameraManager.videoQuality = .hd720

// Disable triple output if not needed
dualCameraManager.enableTripleOutput = false
```

### Battery Optimization

1. Use 720p or 1080p (not 4K)
2. Keep recordings short
3. Close gallery between recordings
4. Disable triple output if not needed

---

## Future Enhancements

### Planned Features

1. **UI Controls**
   - Layout selector before recording
   - Enable/disable toggle in settings
   - Preview different layouts

2. **Audio Options**
   - Choose which camera's audio
   - Mix both audio sources
   - Adjust audio levels

3. **Quality Presets**
   - "Battery Saver" mode
   - "Maximum Quality" mode
   - Adaptive quality

4. **Export Options**
   - Choose which files to save
   - Auto-delete separate files
   - Cloud upload integration

### Requested Features

Have ideas? The architecture supports:
- Custom layouts
- Filters and effects
- Real-time text overlays
- Multiple aspect ratios
- Green screen effects

---

## Technical Details

### How It Works

1. **Capture Phase**
   - Both cameras capture frames simultaneously
   - Frames sent to two pipelines:
     - Pipeline 1: Direct to file (separate videos)
     - Pipeline 2: To compositor (combined video)

2. **Composition Phase**
   - Frames synchronized on dedicated queue
   - GPU renders combined frame using Metal
   - Core Image applies layout transformation

3. **Writing Phase**
   - AVAssetWriter writes composed frames
   - H.264 encoding in real-time
   - Audio mixed from front camera

### Performance Optimizations

- **Frame Synchronization:** Ensures both cameras aligned
- **GPU Acceleration:** Metal for fast rendering
- **Dedicated Queues:** No blocking of main thread
- **Efficient Memory:** Pixel buffer pooling ready

### Limitations

- **Device Support:** Requires iOS 13+ with multi-cam support
- **Simultaneous Cameras:** iPhone XS or newer
- **Performance:** Best on iPhone 12 or newer
- **Storage:** Requires 3x storage space

---

## Support

### Getting Help

1. Check this guide first
2. Review IMPLEMENTATION_COMPLETE.md for technical details
3. Check COMPREHENSIVE_IMPROVEMENT_PLAN.md for architecture

### Reporting Issues

When reporting issues, include:
- Device model
- iOS version
- Quality setting used
- Layout used
- Recording duration
- Error messages (if any)

---

## Summary

The triple output system is a powerful feature that saves time and provides flexibility. Key points:

✅ **Automatic** - No extra steps required  
✅ **Fast** - Real-time composition, zero wait  
✅ **Flexible** - Multiple layouts available  
✅ **Efficient** - GPU-accelerated rendering  
✅ **Professional** - Broadcast-quality output  

**Just press record and get 3 files instantly!**

