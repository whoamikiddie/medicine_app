# ADB Debugging Guide for Flutter Medicine App

## Setup ADB

### 1. Check if ADB is installed
```bash
adb version
```

If not installed:
- **macOS**: `brew install android-platform-tools`
- **Windows**: Download from [Android SDK Platform Tools](https://developer.android.com/studio/releases/platform-tools)
- **Linux**: `sudo apt-get install android-tools-adb`

### 2. Enable USB Debugging on Android Device
1. Go to **Settings** → **About Phone**
2. Tap **Build Number** 7 times (enables Developer Options)
3. Go to **Settings** → **Developer Options**
4. Enable **USB Debugging**
5. Connect phone via USB

### 3. Verify Connection
```bash
# List connected devices
adb devices

# Should show:
# List of devices attached
# ABC123XYZ    device
```

If shows "unauthorized":
- Check phone screen for authorization popup
- Tap "Allow" and check "Always allow from this computer"

---

## Basic ADB Commands

### Device Management
```bash
# List all connected devices
adb devices

# Connect to specific device (if multiple)
adb -s ABC123XYZ shell

# Reboot device
adb reboot

# Check Android version
adb shell getprop ro.build.version.release

# Check device model
adb shell getprop ro.product.model
```

### App Management
```bash
# Install APK
adb install path/to/app.apk

# Install and replace existing app
adb install -r path/to/app.apk

# Uninstall app
adb uninstall com.example.medicine_app

# Clear app data (keeps app installed)
adb shell pm clear com.example.medicine_app

# List installed packages
adb shell pm list packages | grep medicine

# Get app info
adb shell dumpsys package com.example.medicine_app
```

---

## Debugging Notifications

### 1. View Real-Time Logs
```bash
# All logs from your app
adb logcat | grep -E "flutter|Notification|Provider|Medicine"

# Only notification-related logs
adb logcat | grep Notification

# Clear logs and start fresh
adb logcat -c && adb logcat

# Save logs to file
adb logcat > app_logs.txt
```

### 2. Check Notification Permissions
```bash
# Check if notification permission is granted
adb shell dumpsys notification | grep -A 5 "com.example.medicine_app"

# Check all app permissions
adb shell dumpsys package com.example.medicine_app | grep permission

# Grant notification permission manually
adb shell pm grant com.example.medicine_app android.permission.POST_NOTIFICATIONS

# Grant exact alarm permission (Android 12+)
adb shell pm grant com.example.medicine_app android.permission.SCHEDULE_EXACT_ALARM
```

### 3. Check Scheduled Alarms
```bash
# View all scheduled alarms for your app
adb shell dumpsys alarm | grep -A 20 "com.example.medicine_app"

# Count pending alarms
adb shell dumpsys alarm | grep "com.example.medicine_app" | wc -l

# View alarm manager stats
adb shell dumpsys alarm
```

### 4. Check Notification Channels
```bash
# List all notification channels for your app
adb shell dumpsys notification | grep -A 30 "com.example.medicine_app"

# Check channel importance
adb shell dumpsys notification | grep "medicine_reminder"
```

### 5. Battery Optimization Status
```bash
# Check if app is battery optimized
adb shell dumpsys deviceidle whitelist | grep medicine

# Disable battery optimization (requires root or manual)
adb shell dumpsys battery unplug
adb shell settings put global low_power 0
```

---

## Testing Notifications

### 1. Send Test Notification via ADB
```bash
# Send a test notification
adb shell cmd notification post -S bigtext \
  -t "Test Medicine Reminder" \
  "Tag" \
  "Time to take your medicine!"
```

### 2. Trigger Notification Immediately
```bash
# Fast-forward time (requires root)
adb shell su -c "date 121512302024.00"  # MMDDhhmmYYYY.ss

# Reset time
adb shell su -c "settings put global auto_time 1"
```

### 3. Force App to Foreground
```bash
# Start your app
adb shell am start -n com.example.medicine_app/.MainActivity

# Force stop app
adb shell am force-stop com.example.medicine_app

# Clear app and restart
adb shell pm clear com.example.medicine_app && \
adb shell am start -n com.example.medicine_app/.MainActivity
```

---

## Flutter-Specific Debugging

### 1. Flutter Logs
```bash
# Run Flutter with verbose logging
flutter run --verbose

# View Flutter logs only
adb logcat | grep "flutter"

# Filter by log level
adb logcat *:E  # Errors only
adb logcat *:W  # Warnings and above
adb logcat *:I  # Info and above
```

### 2. Hot Reload & Restart
```bash
# While flutter run is active:
# Press 'r' for hot reload
# Press 'R' for hot restart
# Press 'q' to quit

# Or use commands:
flutter attach  # Attach to running app
```

### 3. Check Flutter Doctor
```bash
flutter doctor -v
flutter doctor --android-licenses
```

---

## Advanced Debugging

### 1. Screen Recording
```bash
# Record screen (max 3 minutes)
adb shell screenrecord /sdcard/demo.mp4

# Stop recording: Ctrl+C

# Pull video to computer
adb pull /sdcard/demo.mp4 .
```

### 2. Take Screenshot
```bash
# Capture screenshot
adb shell screencap /sdcard/screen.png

# Pull to computer
adb pull /sdcard/screen.png .
```

### 3. Monitor Network
```bash
# Check internet connectivity
adb shell ping -c 4 8.8.8.8

# Check if Firebase is reachable
adb shell ping -c 4 firestore.googleapis.com
```

### 4. File System Access
```bash
# List app files
adb shell ls -la /data/data/com.example.medicine_app/

# Pull app database
adb shell run-as com.example.medicine_app \
  cp /data/data/com.example.medicine_app/databases/your.db /sdcard/
adb pull /sdcard/your.db .

# View shared preferences
adb shell run-as com.example.medicine_app \
  cat /data/data/com.example.medicine_app/shared_prefs/*.xml
```

---

## Troubleshooting Common Issues

### Issue: "adb: device unauthorized"
```bash
# Solution 1: Revoke USB debugging authorizations
adb kill-server
adb start-server
adb devices
# Check phone for authorization popup

# Solution 2: Reset ADB keys
rm ~/.android/adbkey*
adb kill-server
adb start-server
```

### Issue: "adb: no devices/emulators found"
```bash
# Check USB connection
adb devices

# Try different USB port or cable

# Restart ADB server
adb kill-server
adb start-server

# Check USB debugging is enabled on phone
```

### Issue: "Permission denied"
```bash
# Some commands require root access
adb root  # Restart ADB as root (requires rooted device)

# Or use run-as for app-specific access
adb shell run-as com.example.medicine_app
```

---

## Useful Debugging Workflow

### Complete Debugging Session
```bash
# 1. Clear old logs
adb logcat -c

# 2. Uninstall old app
adb uninstall com.example.medicine_app

# 3. Install fresh build
flutter build apk
adb install build/app/outputs/flutter-apk/app-release.apk

# 4. Start logging in one terminal
adb logcat | grep -E "flutter|Notification|Provider" > debug.log

# 5. Launch app in another terminal
adb shell am start -n com.example.medicine_app/.MainActivity

# 6. Monitor logs
tail -f debug.log

# 7. Check scheduled notifications
adb shell dumpsys alarm | grep medicine

# 8. Verify permissions
adb shell dumpsys package com.example.medicine_app | grep permission
```

---

## Quick Reference Commands

```bash
# Essential commands for notification debugging
adb devices                                    # Check connection
adb logcat | grep Notification                 # View notification logs
adb shell dumpsys alarm | grep medicine        # Check scheduled alarms
adb shell dumpsys notification | grep medicine # Check notification status
adb uninstall com.example.medicine_app        # Clean uninstall
flutter clean && flutter run                   # Fresh build
```

---

## Pro Tips

1. **Use multiple terminals**: One for `flutter run`, one for `adb logcat`
2. **Save logs**: Always redirect logs to file for later analysis
3. **Filter early**: Use grep to reduce noise in logs
4. **Check time**: Ensure device time is correct for scheduled notifications
5. **Test on real device**: Emulators may not accurately simulate notifications
6. **Clear data often**: `adb shell pm clear` helps reset state
7. **Check battery**: Low battery can affect background tasks
8. **Disable power saving**: Some phones kill background apps aggressively

---

## Notification-Specific Checklist

```bash
# Run these commands to verify notification setup:

# 1. Check permissions
adb shell dumpsys package com.example.medicine_app | grep "POST_NOTIFICATIONS\|SCHEDULE_EXACT_ALARM"

# 2. Check notification channels
adb shell dumpsys notification | grep -A 10 "medicine_reminder_v3"

# 3. Check pending alarms
adb shell dumpsys alarm | grep -c "com.example.medicine_app"

# 4. Check battery optimization
adb shell dumpsys deviceidle whitelist | grep medicine

# 5. View recent notifications
adb shell dumpsys notification --noredact | grep -A 20 "com.example.medicine_app"
```

If all checks pass but notifications still don't work, the issue is likely:
- Phone manufacturer restrictions (Xiaomi, Oppo, etc.)
- Battery optimization not disabled
- App killed by system
- Notification channel blocked by user

---

## Additional Resources

- [Android Debug Bridge (ADB) Official Docs](https://developer.android.com/studio/command-line/adb)
- [Flutter Debugging Guide](https://docs.flutter.dev/testing/debugging)
- [Android Notification Troubleshooting](https://developer.android.com/training/notify-user/build-notification)
