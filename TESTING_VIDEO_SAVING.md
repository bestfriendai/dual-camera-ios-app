# Testing Video Saving to Photos Library

## Quick Test Steps

### 1. Build and Install
```bash
# Open in Xcode and build to your iPhone
open DualCameraApp.xcodeproj
```

### 2. Grant Permissions
When the app launches, grant these permissions:
- ✅ Camera access
- ✅ Microphone access
- ✅ Photo Library access (important!)

### 3. Record a Short Video
1. Open the app
2. Tap the record button (red circle)
3. Record for 5-10 seconds
4. Tap stop

### 4. Check Photos App
1. Open Photos app on your iPhone
2. Go to "Recents" album
3. You should see **3 new videos**:
   - Front camera video
   - Back camera video
   - Combined side-by-side video

### 5. Verify Videos
- Play each video to ensure they work
- Check that audio is present
- Verify the combined video shows both cameras

## What to Look For

### ✅ Success Indicators
- 3 videos appear in Photos app immediately after recording
- Videos play smoothly with audio
- Combined video shows both camera views properly
- No error messages in the app

### ⚠️ Potential Issues

#### Photos Permission Not Granted
**Symptom**: Videos don't appear in Photos app
**Fix**: 
1. Open Settings > Privacy & Security > Photos
2. Find "Dual Camera" app
3. Set to "Add Photos Only" or "Full Access"

#### Low Storage Space
**Symptom**: Recording fails or videos are corrupted
**Check**: Settings > General > iPhone Storage
**Need**: At least 500MB free space

#### Videos in Documents but not Photos
**Symptom**: Videos exist in app but not Photos library
**Fix**: This was the original bug - should be fixed now
**Verify**: Check Xcode console for "Video saved to Photos" messages

## Debug Console Messages

Look for these in Xcode console:

```
✅ Good Messages:
- "DEBUG: Recording finished successfully to: front_[timestamp].mov"
- "DEBUG: Recording finished successfully to: back_[timestamp].mov"  
- "DEBUG: Video saved to Photos: front_[timestamp].mov"
- "DEBUG: Video saved to Photos: back_[timestamp].mov"
- "Combined video saved successfully"
- "DEBUG: Video saved to Photos: combined_[timestamp].mp4"

❌ Error Messages to Watch For:
- "DEBUG: Photos access denied, cannot save video"
- "DEBUG: Failed to save video to Photos: ..."
- "Recording file is too small, likely failed"
```

## File Locations

### Temporary Storage (app's Documents folder)
- Front: `Documents/front_[timestamp].mov`
- Back: `Documents/back_[timestamp].mov`
- Combined: `Documents/combined_[timestamp].mp4`

These are kept for backup and cleaned up after 7 days.

### Permanent Storage (Photos Library)
- All 3 videos are saved to Photos
- They appear in "Recents" album
- Available in other apps via photo picker

## Troubleshooting

### No Videos in Photos After Recording

1. **Check permissions**:
   ```
   Settings > Privacy & Security > Photos > Dual Camera
   Must be "Add Photos Only" or higher
   ```

2. **Check Xcode console**:
   - Look for "Video saved to Photos" messages
   - Check for error messages

3. **Force quit and restart app**:
   - Sometimes permissions need app restart

4. **Check storage space**:
   - Need at least 500MB free

### Videos Are Corrupted or Won't Play

1. **Check recording duration**:
   - Must record at least 1 second
   - Very short recordings may fail

2. **Check storage during recording**:
   - Low space can corrupt videos

3. **Try lower quality**:
   - Change from 4K to 1080p or 720p

### Only Merged Video Saves (Old Bug)

If you still see only the merged video:
1. Clean build folder: Xcode > Product > Clean Build Folder
2. Delete app from iPhone
3. Rebuild and reinstall
4. This ensures new code is running

## Advanced: Verify in Documents Folder

You can check the app's Documents folder using Xcode:

1. Window > Devices and Simulators
2. Select your iPhone
3. Click the gear icon below installed apps
4. Select "Dual Camera" 
5. Click "Download Container"
6. Show in Finder
7. Navigate to AppData/Documents/
8. You should see the video files

## Expected Results

After a 10-second recording with triple output enabled:

| File | Size (1080p) | Location | Format |
|------|-------------|----------|--------|
| front_[timestamp].mov | ~20-50 MB | Documents + Photos | MOV |
| back_[timestamp].mov | ~20-50 MB | Documents + Photos | MOV |
| combined_[timestamp].mp4 | ~40-100 MB | Documents + Photos | MP4 |

**Total Photos app entries**: 3 videos
**Total Documents folder entries**: 3 videos (temporary, auto-cleaned)
