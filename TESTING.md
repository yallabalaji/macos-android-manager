# Testing the Android Device Info App

## ✅ Prerequisites Verified
Your Android device is connected and visible to ADB:
```
Device ID: ZD2229SNWD
Status: device (authorized)
```

## How to Run the App

### Option 1: Using Xcode (Recommended)

The Xcode project has been opened for you. Follow these steps:

1. **In Xcode, select the target**:
   - At the top of Xcode, you'll see "AndroidDeviceInfo" next to a device selector
   - Click the device selector and choose "My Mac"

2. **Build the project**:
   - Press `⌘ + B` (Command + B) to build
   - Wait for the build to complete (check the progress bar at top)

3. **Run the app**:
   - Press `⌘ + R` (Command + R) to run
   - The app window should appear showing your device information

4. **What you should see**:
   - ✅ Green "Device Connected" status
   - Device model, manufacturer, and Android version
   - Storage information with a progress bar

### Option 2: Build from Command Line

If you prefer terminal, you can build and run:

```bash
# Navigate to project directory
cd /Users/balaji/Projects/AndroidSwift

# Build the project
xcodebuild -project AndroidDeviceInfo/AndroidDeviceInfo.xcodeproj \
  -scheme AndroidDeviceInfo \
  -configuration Debug \
  build

# Run the built app
open AndroidDeviceInfo/build/Debug/AndroidDeviceInfo.app
```

## Testing Checklist

### 1. Device Detection
- [ ] App shows "Device Connected" with green indicator
- [ ] Disconnect device → should show "No Device Connected" with red indicator
- [ ] Reconnect device → click refresh button → should detect again

### 2. Device Information
- [ ] Model name is displayed correctly
- [ ] Manufacturer is shown
- [ ] Android version is accurate

To verify, compare with terminal output:
```bash
# Check model
adb shell getprop ro.product.model

# Check manufacturer
adb shell getprop ro.product.manufacturer

# Check Android version
adb shell getprop ro.build.version.release
```

### 3. Storage Information
- [ ] Total storage is displayed in GB
- [ ] Available storage is shown
- [ ] Progress bar shows usage percentage
- [ ] Numbers match device settings

To verify storage in terminal:
```bash
adb shell df /data
```

### 4. Refresh Functionality
- [ ] Click refresh button
- [ ] Information updates correctly
- [ ] No errors or crashes

## Troubleshooting

### Issue: Build Fails in Xcode

**Error: "Developer directory not found"**
```bash
# Set Xcode path
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
```

**Error: "Signing certificate not found"**
- In Xcode, select the project in the navigator
- Go to "Signing & Capabilities" tab
- Under "Team", select your Apple ID or "Sign to Run Locally"

### Issue: App Shows "No Device Connected"

1. **Verify ADB can see device**:
   ```bash
   adb devices
   ```
   Should show your device as "device" (not "unauthorized")

2. **Check ADB path**:
   ```bash
   which adb
   ```
   Common locations:
   - `/opt/homebrew/bin/adb` (Apple Silicon Mac)
   - `/usr/local/bin/adb` (Intel Mac)

3. **Restart ADB server**:
   ```bash
   adb kill-server
   adb start-server
   adb devices
   ```

4. **Check device authorization**:
   - Look at your Android device screen
   - You may need to tap "Allow" on a USB debugging prompt

### Issue: Storage Shows 0 GB

This can happen if the app doesn't have permission to read storage info. Try:
```bash
# Test storage command manually
adb shell df /data
```

If this works in terminal but not in the app, the ADB path might be incorrect.

## Expected Output Example

When working correctly, you should see something like:

```
Connection Status: Device Connected ✅

Device Details:
- Model: [Your device model]
- Manufacturer: [Your device manufacturer]
- Android Version: [Your Android version]

Storage:
- Used: XX.X GB (XX%)
- Total Storage: XX.X GB
- Available: XX.X GB
```

## Next Steps After Testing

Once the app is working:

1. **Test edge cases**:
   - Disconnect/reconnect device while app is running
   - Connect different Android devices
   - Test with low storage device

2. **Provide feedback**:
   - Note any bugs or issues
   - Suggest UI improvements
   - Identify missing features

3. **Start Phase 1 development** (if interested):
   - Implement file browser
   - Add file transfer capabilities
   - See ROADMAP.md for details

## Quick Test Commands

Run these in terminal to verify ADB is working:

```bash
# List devices
adb devices

# Get device info
adb shell getprop ro.product.model
adb shell getprop ro.product.manufacturer
adb shell getprop ro.build.version.release

# Get storage
adb shell df /data

# Test connection
adb shell echo "Connection successful"
```

If all these commands work, the app should work too!
