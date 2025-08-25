import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:convert';
import 'dart:typed_data';

class NotificationListenerService {
  static const MethodChannel _channel = MethodChannel('notification_listener');
  static final AudioPlayer _audioPlayer = AudioPlayer();
  static bool _isInitialized = false;
  
  // Initialize the service
  static Future<void> initialize() async {
    try {
      // Prevent multiple initialization attempts (helps with hot reload)
      if (_isInitialized) {
        debugPrint('NotificationListenerService already initialized, skipping...');
        return;
      }
      
      // Initialize audio player for alarm functionality
      await _initializeAudioPlayer();
      
      // Set up method call handler with error protection
      _channel.setMethodCallHandler((call) async {
        try {
          await _handleMethodCall(call);
        } catch (e) {
          debugPrint('Error in method call handler: $e');
          // Don't rethrow - let the app continue
        }
      });
      
      // Initialize the native service with timeout
      await _channel.invokeMethod('initialize').timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          debugPrint('NotificationListener initialization timed out');
          return null;
        },
      );
      
      _isInitialized = true;
      debugPrint('NotificationListenerService initialized successfully');
    } catch (e) {
      debugPrint('Error initializing notification listener: $e');
      // Don't rethrow - let the app continue without motion alerts
    }
  }
  
  // Handle calls from native Android code
  static Future<void> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onNotificationReceived':
        await _handleNotification(call.arguments);
        break;
      default:
        debugPrint('Unknown method: ${call.method}');
    }
  }
  
  // Handle incoming notification
  static Future<void> _handleNotification(Map<dynamic, dynamic> notification) async {
    try {
      final String packageName = notification['packageName'] ?? '';
      final String title = notification['title'] ?? '';
      final String text = notification['text'] ?? '';
      
      debugPrint('Notification received from: $packageName');
      debugPrint('Title: $title');
      debugPrint('Text: $text');
      
      // Check if this notification should trigger an alarm
      if (await _shouldTriggerAlarm(packageName, title, text)) {
        await triggerLoudAlarm(title, text);
      }
    } catch (e) {
      debugPrint('Error handling notification: $e');
    }
  }
  
  // Check if notification should trigger alarm
  static Future<bool> _shouldTriggerAlarm(String packageName, String title, String text) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final settingsJson = prefs.getString('notification_alarm_settings');
      
      if (settingsJson == null) return false;
      
      final settings = json.decode(settingsJson) as Map<String, dynamic>;
      final List<dynamic> monitoredApps = settings['monitoredApps'] ?? [];
      final bool isEnabled = settings['enabled'] ?? false;
      final bool nightModeOnly = settings['nightModeOnly'] ?? true;
      
      if (!isEnabled) return false;
      
      // Check if it's night time (if night mode only)
      if (nightModeOnly) {
        final now = DateTime.now();
        final hour = now.hour;
        // Consider night time as 22:00 to 08:00
        if (!(hour >= 22 || hour <= 8)) {
          return false;
        }
      }
      
      // Check if this app is monitored
      final isMonitored = monitoredApps.any((app) => 
        app['packageName'] == packageName && app['enabled'] == true
      );
      
      if (!isMonitored) return false;
      
      // Check for motion detection keywords
      final keywords = settings['keywords'] ?? ['motion', 'detected', 'movement', 'alert'];
      final contentToCheck = '$title $text'.toLowerCase();
      
      return keywords.any((keyword) => 
        contentToCheck.contains(keyword.toString().toLowerCase())
      );
      
    } catch (e) {
      debugPrint('Error checking alarm trigger: $e');
      return false;
    }
  }
  
  // Trigger loud alarm
  static Future<void> triggerLoudAlarm(String title, String text) async {
    try {
      debugPrint('Triggering loud alarm for: $title');
      
      // Play loud alarm sound
      await _playLoudAlarm();
      
      // Show system alert
      await _showSystemAlert(title, text);
      
      // Vibrate phone
      await _vibratePhone();
      
    } catch (e) {
      debugPrint('Error triggering alarm: $e');
    }
  }
  
  // Initialize audio player with basic settings
  static Future<void> _initializeAudioPlayer() async {
    try {
      debugPrint('Initializing audio player...');
      
      // Don't set audio context during initialization - do it when playing
      // Just verify the player is ready
      await _audioPlayer.setVolume(0.0); // Silent test
      await _audioPlayer.stop(); // Ensure stopped
      
      debugPrint('Audio player ready');
    } catch (e) {
      debugPrint('Error initializing audio player: $e');
    }
  }
  
  // Play loud alarm sound - AUDIO PLAYER PRIORITY
  static Future<void> _playLoudAlarm() async {
    try {
      debugPrint('Starting alarm with audio player priority...');
      
      // PRIORITY 1: Audio player with alarm stream (this works!)
      await _audioPlayer.stop();
      
      await _audioPlayer.setAudioContext(AudioContext(
        android: AudioContextAndroid(
          isSpeakerphoneOn: true,
          stayAwake: true,
          contentType: AndroidContentType.sonification,
          usageType: AndroidUsageType.alarm, // This bypasses media volume
          audioFocus: AndroidAudioFocus.gain,
        ),
      ));
      
      await _audioPlayer.setVolume(1.0);
      await _audioPlayer.setReleaseMode(ReleaseMode.loop);
      
      await _audioPlayer.play(AssetSource('sounds/alarm.mp3'));
      debugPrint('Audio player alarm started (uses ALARM volume)');
      
      // Stop after 30 seconds
      Future.delayed(const Duration(seconds: 30), () async {
        await _audioPlayer.stop();
        debugPrint('Alarm stopped');
      });
      
      // PRIORITY 2: Vibration (always works)
      await _triggerVibration();
      
      // PRIORITY 3: Show notification (for visibility, not sound)
      await _showLoudNotification();
      
      debugPrint('Full alarm sequence activated');
      
    } catch (e) {
      debugPrint('Audio player alarm failed: $e');
      
      // Emergency fallback
      await _triggerVibration();
      await _showLoudNotification();
      
      // System sound backup
      for (int i = 0; i < 10; i++) {
        await SystemSound.play(SystemSoundType.alert);
        await Future.delayed(const Duration(milliseconds: 800));
      }
    }
  }
  
  // Trigger vibration
  static Future<void> _triggerVibration() async {
    try {
      debugPrint('Triggering vibration...');
      await HapticFeedback.heavyImpact();
      // Add additional vibration patterns for more noticeable feedback
      await Future.delayed(const Duration(milliseconds: 200));
      await HapticFeedback.heavyImpact();
      await Future.delayed(const Duration(milliseconds: 200));
      await HapticFeedback.heavyImpact();
    } catch (e) {
      debugPrint('Vibration failed: $e');
    }
  }
  
  // Show system alert
  static Future<void> _showSystemAlert(String title, String text) async {
    try {
      await _channel.invokeMethod('showSystemAlert', {
        'title': 'Motion Detected!',
        'message': '$title\\n$text',
      });
    } catch (e) {
      debugPrint('Error showing system alert: $e');
    }
  }
  
  // Vibrate phone
  static Future<void> _vibratePhone() async {
    try {
      await HapticFeedback.vibrate();
      // For longer vibration, we'll use the native channel
      await _channel.invokeMethod('vibrateLong');
    } catch (e) {
      debugPrint('Error vibrating phone: $e');
    }
  }
  
  // Check if notification listener permission is granted
  static Future<bool> isPermissionGranted() async {
    try {
      return await _channel.invokeMethod('isPermissionGranted') ?? false;
    } catch (e) {
      debugPrint('Error checking permission: $e');
      return false;
    }
  }
  
  // Request notification listener permission
  static Future<void> requestPermission() async {
    try {
      await _channel.invokeMethod('requestPermission');
    } catch (e) {
      debugPrint('Error requesting permission: $e');
    }
  }
  
  // Get list of installed apps
  static Future<List<Map<String, String>>> getInstalledApps() async {
    try {
      final result = await _channel.invokeMethod('getInstalledApps');
      return List<Map<String, String>>.from(
        result.map((app) => Map<String, String>.from(app))
      );
    } catch (e) {
      debugPrint('Error getting installed apps: $e');
      return [];
    }
  }

  // Get common camera apps (faster alternative)
  static List<Map<String, String>> getCommonCameraApps() {
    return [
      {'appName': 'Tapo', 'packageName': 'com.tplinkcloud.tapo'},
      {'appName': 'Camera', 'packageName': 'com.android.camera'},
      {'appName': 'Camera2', 'packageName': 'com.android.camera2'},
      {'appName': 'Google Camera', 'packageName': 'com.google.android.GoogleCamera'},
      {'appName': 'Samsung Camera', 'packageName': 'com.sec.android.app.camera'},
      {'appName': 'IP Webcam', 'packageName': 'com.pas.webcam'},
      {'appName': 'Alfred Home Security Camera', 'packageName': 'com.ivuu'},
      {'appName': 'AtHome Camera', 'packageName': 'com.ichano.athome.camera'},
      {'appName': 'Manything', 'packageName': 'com.manything.android'},
      {'appName': 'WardenCam', 'packageName': 'com.wardenapp'},
      {'appName': 'Presence by People Power', 'packageName': 'com.presencepro'},
    ];
  }
  
  // Show loud notification with alarm sound
  static Future<void> _showLoudNotification() async {
    try {
      final FlutterLocalNotificationsPlugin notifications = FlutterLocalNotificationsPlugin();
      
      await notifications.show(
        9999, // High priority ID
        '🚨 MOTION DETECTED!',
        'Security alert - Check your cameras immediately!',
        NotificationDetails(
          android: AndroidNotificationDetails(
            'motion_alert_loud',
            'Security Motion Alerts',
            channelDescription: 'Critical security motion detection alerts',
            importance: Importance.max,
            priority: Priority.max,
            category: AndroidNotificationCategory.alarm,
            fullScreenIntent: true,
            enableLights: true,
            enableVibration: true,
            playSound: true,
            sound: const RawResourceAndroidNotificationSound('alarm'), // Use system alarm sound
            ledColor: Colors.red,
            ledOnMs: 300,
            ledOffMs: 300,
            vibrationPattern: Int64List.fromList([0, 1000, 500, 1000]),
            audioAttributesUsage: AudioAttributesUsage.alarm, // CRITICAL: Use alarm audio stream
            ongoing: true,
            autoCancel: false,
            actions: [
              const AndroidNotificationAction(
                'stop_alarm',
                'STOP ALARM',
                showsUserInterface: true,
              ),
            ],
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
            sound: 'alarm.aiff',
            interruptionLevel: InterruptionLevel.critical,
          ),
        ),
      );
    } catch (e) {
      debugPrint('Error showing loud notification: $e');
    }
  }

  // Stop alarm
  static Future<void> stopAlarm() async {
    try {
      await _audioPlayer.stop();
      
      // Also dismiss the alarm notification
      final FlutterLocalNotificationsPlugin notifications = FlutterLocalNotificationsPlugin();
      await notifications.cancel(9999);
    } catch (e) {
      debugPrint('Error stopping alarm: $e');
    }
  }
  
  
  // Simple test to verify basic audio functionality
  static Future<void> testAlarmSound() async {
    debugPrint('=== SIMPLE ALARM TEST ===');
    debugPrint('Make sure ALARM volume is up (not media volume)');
    
    try {
      // Simple test - just try to play the sound
      await _audioPlayer.stop();
      
      await _audioPlayer.setAudioContext(AudioContext(
        android: AudioContextAndroid(
          isSpeakerphoneOn: true,
          stayAwake: true,
          contentType: AndroidContentType.sonification,
          usageType: AndroidUsageType.alarm,
          audioFocus: AndroidAudioFocus.gain,
        ),
      ));
      
      await _audioPlayer.setVolume(1.0);
      await _audioPlayer.setReleaseMode(ReleaseMode.stop);
      
      final source = AssetSource('sounds/alarm.mp3');
      await _audioPlayer.play(source);
      
      debugPrint('Playing test sound for 5 seconds...');
      
      // Stop after 5 seconds
      Future.delayed(const Duration(seconds: 5), () async {
        await _audioPlayer.stop();
        debugPrint('Test sound stopped');
      });
      
      debugPrint('If you hear sound, the alarm should work');
      debugPrint('If no sound, check your ALARM volume setting');
      
    } catch (e) {
      debugPrint('Audio test failed: $e');
      // Try system sound as backup
      await SystemSound.play(SystemSoundType.alert);
    }
  }
  
  // Reset service (useful for hot reload)
  static void reset() {
    try {
      _isInitialized = false;
      _audioPlayer.stop();
      debugPrint('NotificationListenerService reset for hot reload');
    } catch (e) {
      debugPrint('Error resetting service: $e');
    }
  }
}