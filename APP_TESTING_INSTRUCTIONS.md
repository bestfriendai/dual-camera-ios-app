# Dual Camera App - Testing Instructions

## ✅ App Successfully Installed on Patrick's iPhone 17 Pro!

The app is now installed and ready to test. Follow these instructions to verify all features work correctly.

---

## 📱 What This App Does

**Records from BOTH cameras simultaneously** - front and back camera record at the same time, creating two separate video files that can be merged into one.

---

## 🚀 Testing Checklist

### Step 1: Launch the App
1. **Find the app** on Patrick's iPhone (look for "Dual Camera" icon)
2. **Tap to open** the app
3. You should see:
   - Two black preview boxes (front camera + back camera)
   - A red record button at the bottom
   - Quality button (top right)
   - Gallery button (top left)

### Step 2: Grant Permissions (CRITICAL!)
When you first open the app, you'll be asked for permissions:

1. **Camera Permission** - Tap "OK" or "Allow"
   - This lets the app access both cameras
   
2. **Microphone Permission** - Tap "OK" or "Allow"
   - This lets the app record audio
   
3. **Photos Permission** - Tap "Allow" or "Allow Access to All Photos"
   - This lets the app save merged videos

**⚠️ Important:** If you accidentally tap "Don't Allow", go to:
Settings → Dual Camera → Enable Camera, Microphone, and Photos

### Step 3: Test Camera Previews
After granting permissions, you should see:
- **Top preview box** = Live view from one camera (back camera by default)
- **Bottom preview box** = Live view from other camera (front camera by default)

**If you see black boxes:**
- Wait 2-3 seconds for cameras to initialize
- Make sure you granted camera permission
- Try closing and reopening the app

### Step 4: Test Recording (Main Feature!)
1. **Tap the red RECORD button** (large circle at bottom center)
   - Button should turn into a STOP button (square)
   - Timer should appear showing recording time (00:00, 00:01, etc.)
   - Status text should say "Recording..."

2. **Move around and test both cameras**
   - You should see yourself in the front camera preview
   - You should see what's behind you in the back camera preview
   - Both cameras are recording simultaneously!

3. **Tap the STOP button** to finish recording
   - Timer should disappear
   - Status should say "Recording stopped"
   - "Merge Videos" button should become enabled

### Step 5: Test Video Merging
After recording, you'll have two separate video files. Let's merge them:

1. **Tap "Merge Videos"** button
2. Choose a layout:
   - **Side-by-Side**: Both cameras shown equally side-by-side
   - **Picture-in-Picture**: Back camera as main view, front camera as small overlay

3. **Wait for processing**
   - You'll see a progress bar (0% → 100%)
   - Status will show "Exporting video... X%"
   - This may take 10-30 seconds depending on video length

4. **Check Photos app**
   - When complete, status will say "Merged video saved to Photos!"
   - Open your Photos app
   - Find the newest video
   - Play it and verify both cameras are visible in the merged video

### Step 6: Test Additional Features

#### Quality Settings
1. Tap the **quality button** (top right, shows "1080p")
2. Select different quality:
   - **720p HD** - Good quality, smaller file size
   - **1080p Full HD** - Great quality (default)
   - **4K Ultra HD** - Best quality, largest file size
3. Record a video to test the selected quality

#### Zoom Feature
1. During preview (before recording), **pinch to zoom** on either camera view
2. You can zoom each camera independently (1x to 5x zoom)
3. Zoom works during recording too!

#### Focus/Exposure
1. **Tap anywhere on a camera preview** to set focus point
2. You'll see a yellow circle animation
3. Camera will focus on that point

#### Flash
1. Tap the **flash button** (lightning bolt, left side)
2. Flash/torch toggles on the back camera
3. Try this in a dark room to see the effect

#### Swap Camera Views
1. Tap the **swap button** (circular arrows, right side)
2. This swaps which camera is on top vs bottom
3. Useful for different shooting angles

#### Video Gallery
1. Tap the **gallery button** (top left, grid icon)
2. You'll see all your recorded videos
3. Tap any video to:
   - **Play** - Watch in full screen
   - **Share** - Send via Messages, Mail, AirDrop
   - **Delete** - Remove from storage

---

## 🎯 Key Features to Verify

### ✅ Simultaneous Recording
- [ ] Both camera previews show live video
- [ ] Recording timer appears when recording
- [ ] Both cameras record at the same time
- [ ] Recording stops when you tap stop

### ✅ Video Merging
- [ ] Merge Videos button is enabled after recording
- [ ] Can choose Side-by-Side or Picture-in-Picture
- [ ] Progress bar shows during export
- [ ] Merged video saves to Photos app
- [ ] Both cameras are visible in merged video

### ✅ Camera Controls
- [ ] Pinch to zoom works on both previews
- [ ] Tap to focus works on both previews
- [ ] Flash toggles on/off
- [ ] Swap button changes camera order
- [ ] Quality selector changes video resolution

### ✅ Gallery
- [ ] Gallery shows all recorded videos
- [ ] Can play videos
- [ ] Can share videos
- [ ] Can delete videos

---

## ⚠️ Troubleshooting

### Camera previews are black
**Solution:**
1. Close the app completely (swipe up from bottom, swipe app away)
2. Go to Settings → Dual Camera
3. Make sure Camera permission is enabled
4. Reopen the app

### "Multi-camera not supported" error
**Solution:**
- This device (iPhone 17 Pro) DOES support multi-camera
- If you see this error, there may be another camera app running
- Close all other camera apps and try again

### Recording but no video file
**Solution:**
1. Check if you have enough storage space
2. Settings → General → iPhone Storage
3. Make sure you have at least 1GB free

### Merge fails or takes too long
**Solution:**
1. Make sure recordings aren't too long (keep under 2 minutes for testing)
2. Try merging again - it might work on second attempt
3. Check that Photos permission is enabled

### App crashes on launch
**Solution:**
1. Force quit the app
2. Restart iPhone
3. Open app again
4. Grant all permissions

---

## 📊 Expected Behavior

### On Launch
- App opens to camera interface
- Both previews initialize within 2-3 seconds
- Status shows "Ready to record"

### During Recording
- Both previews continue to show live video
- Timer counts up: 00:00 → 00:01 → 00:02...
- Record button changes to stop button
- All other buttons are disabled during recording

### After Recording
- Timer disappears
- Status shows "Recording stopped"
- Merge Videos button becomes active
- Can record again or merge existing videos

### During Merge
- Progress bar shows percentage
- Status updates with progress
- Merge button is disabled
- Takes 10-30 seconds typically

### After Merge
- Progress bar disappears
- Status shows "Merged video saved to Photos!"
- Can find merged video in Photos app
- Temporary files are cleaned up automatically

---

## 🎬 Testing Scenarios

### Scenario 1: Basic Recording
1. Open app → Grant permissions
2. Tap record → Record for 10 seconds
3. Tap stop → Tap Merge Videos
4. Choose Side-by-Side → Wait for export
5. Open Photos app → Verify merged video

### Scenario 2: Quality Test
1. Tap quality button → Select 4K
2. Record a 5-second video
3. Merge videos
4. Check video quality in Photos app

### Scenario 3: Zoom & Focus Test
1. Pinch to zoom front camera to 3x
2. Pinch to zoom back camera to 2x
3. Tap on a specific object in front camera
4. Record for 5 seconds
5. Verify zoom levels in recorded video

### Scenario 4: Multiple Recordings
1. Record video #1 (5 seconds)
2. Record video #2 (5 seconds)
3. Record video #3 (5 seconds)
4. Open gallery → Should see all 6 videos (3 front + 3 back + merged)
5. Merge each recording separately

---

## 📝 Notes

- The app uses **AVCaptureMultiCamSession** for true simultaneous recording
- Both cameras record completely independently
- Audio is captured from the front camera recording
- Merged videos maintain original quality
- Old temporary files auto-delete after 7 days

---

## ✅ Success Criteria

The app is working correctly if:

1. ✅ Both camera previews show live video
2. ✅ Recording creates two separate video files
3. ✅ Both cameras record at exactly the same time
4. ✅ Merge creates a single video with both camera views
5. ✅ Merged video includes audio
6. ✅ Video saves to Photos app successfully
7. ✅ Gallery shows all recordings
8. ✅ All camera controls (zoom, focus, flash) work

---

## 🐛 Bug Reporting

If you find any issues, note:
- What you were doing when it happened
- What you expected to happen
- What actually happened
- Any error messages shown
- Whether it happens consistently or randomly

---

**App Version:** 2.1  
**Device:** Patrick's iPhone 17 Pro (iOS 26.0)  
**Status:** ✅ Installed and Ready for Testing