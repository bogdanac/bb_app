# Motion Alert Setup Instructions

This feature allows your app to monitor camera notifications and play loud alarms at night when motion is detected.

## Features Implemented
✅ **Settings Screen** - Configure which apps to monitor
✅ **Night Mode Only** - Only triggers between 22:00-08:00
✅ **Keyword Detection** - Looks for "person" or "detected" in notifications
✅ **Loud Alarm** - Plays loud sound even in silent mode
✅ **Permission Handling** - Requests notification listener permission

## Android Implementation Needed

### 1. Add Permissions to android/app/src/main/AndroidManifest.xml
```xml
<uses-permission android:name="android.permission.BIND_NOTIFICATION_LISTENER_SERVICE" />
<uses-permission android:name="android.permission.VIBRATE" />
<uses-permission android:name="android.permission.WAKE_LOCK" />
<uses-permission android:name="android.permission.MODIFY_AUDIO_SETTINGS" />
```

### 2. Create NotificationListenerService in Android
File: `android/app/src/main/kotlin/com/example/bb_app/NotificationListener.kt`

### 3. Create MethodChannel Handler
File: `android/app/src/main/kotlin/com/example/bb_app/MainActivity.kt`

### 4. Add Alarm Sound
Place a loud alarm sound file in: `assets/sounds/alarm.mp3`

## How It Works

1. **Setup**: User grants notification listener permission
2. **Configuration**: User selects camera app to monitor
3. **Detection**: Service monitors notifications from selected apps
4. **Filtering**: Only processes notifications containing "person" or "detected"
5. **Time Check**: Only triggers during night hours (22:00-08:00)
6. **Alert**: Plays loud alarm, vibrates, and shows system alert

## Usage

1. Go to Settings → Notifications → Night Motion Alerts
2. Grant notification listener permission
3. Enable night alerts
4. Select your camera/security app
5. Test the alarm to ensure it works

## Technical Notes

- Uses Android NotificationListenerService
- AudioManager to override volume settings
- Flutter MethodChannel for communication
- SharedPreferences for settings storage
- Works even when phone is in silent/DND mode

## Security & Privacy

- Only processes notifications from apps you explicitly select
- No notification content is stored or transmitted
- Runs only during configured night hours
- Can be disabled at any time