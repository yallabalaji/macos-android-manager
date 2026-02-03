# Android Device Info

A macOS application built with Swift and SwiftUI that displays information about connected Android devices using ADB (Android Debug Bridge).

## Features

- 📱 **Device Detection**: Automatically detects connected Android devices
- 📊 **Device Information**: Displays model, manufacturer, and Android version
- 💾 **Storage Details**: Shows total and available storage with visual progress bar
- 🔄 **Real-time Updates**: Refresh button to update device information
- 🎨 **Modern UI**: Clean SwiftUI interface with a polished design

## Prerequisites

Before running this app, you need to have ADB installed on your Mac:

### Option 1: Install via Homebrew
```bash
brew install android-platform-tools
```

### Option 2: Install via Android Studio
ADB comes bundled with Android Studio. If you have Android Studio installed, ADB is typically located at:
```
~/Library/Android/sdk/platform-tools/adb
```

### Verify ADB Installation
```bash
which adb
# or
adb version
```

## Android Device Setup

1. **Enable Developer Options** on your Android device:
   - Go to Settings → About Phone
   - Tap "Build Number" 7 times

2. **Enable USB Debugging**:
   - Go to Settings → Developer Options
   - Enable "USB Debugging"

3. **Connect Device**:
   - Connect your Android device via USB
   - When prompted on the device, authorize the computer

4. **Verify Connection**:
   ```bash
   adb devices
   ```
   You should see your device listed.

## Building and Running

1. **Open the Project**:
   ```bash
   open AndroidDeviceInfo/AndroidDeviceInfo.xcodeproj
   ```

2. **Build the Project**:
   - In Xcode, press `⌘+B` to build

3. **Run the App**:
   - Press `⌘+R` to run the app
   - The app will launch and automatically detect your connected Android device

## How It Works

The app uses ADB commands to communicate with connected Android devices:

- **Device Detection**: `adb devices` - Lists connected devices
- **Device Properties**: `adb shell getprop` - Retrieves device properties like model, manufacturer, and Android version
- **Storage Information**: `adb shell df /data` - Gets storage statistics

## Project Structure

```
AndroidDeviceInfo/
├── AndroidDeviceInfo/
│   ├── AndroidDeviceInfoApp.swift    # App entry point
│   ├── ContentView.swift              # Main UI view
│   ├── Models/
│   │   └── DeviceInfo.swift          # Device data model
│   ├── Utilities/
│   │   └── ADBManager.swift          # ADB command execution
│   ├── Assets.xcassets/              # App assets
│   ├── Info.plist                    # App configuration
│   └── AndroidDeviceInfo.entitlements
└── AndroidDeviceInfo.xcodeproj/      # Xcode project
```

## Troubleshooting

### App shows "No Device Connected"
- Verify USB debugging is enabled on your Android device
- Check that the device is authorized (check device screen for authorization prompt)
- Run `adb devices` in Terminal to verify ADB can see the device
- Try disconnecting and reconnecting the device

### ADB not found
- Install ADB using Homebrew: `brew install android-platform-tools`
- Or add Android SDK platform-tools to your PATH

### Permission Issues
- Make sure the app has necessary permissions
- The device must be authorized on your Mac

## Requirements

- macOS 13.0 or later
- Xcode 15.0 or later
- ADB (Android Debug Bridge)
- Android device with USB debugging enabled

## License

This project is open source and available for educational purposes.
