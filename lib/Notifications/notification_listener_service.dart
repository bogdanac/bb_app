import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:convert';

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
  
  // Play loud alarm sound
  static Future<void> _playLoudAlarm() async {
    try {
      // Stop any current sound
      await _audioPlayer.stop();
      
      // Set volume to maximum and play alarm
      await _audioPlayer.setVolume(1.0);
      await _audioPlayer.setReleaseMode(ReleaseMode.loop);
      
      // Use system alarm sound or custom sound
      await _audioPlayer.play(AssetSource('sounds/alarm.mp3'));
      
      // Stop alarm after 30 seconds
      Future.delayed(const Duration(seconds: 30), () {
        _audioPlayer.stop();
      });
      
    } catch (e) {
      debugPrint('Error playing alarm: $e');
      // Fallback to system sound
      await SystemSound.play(SystemSoundType.alert);
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
  
  // Stop alarm
  static Future<void> stopAlarm() async {
    try {
      await _audioPlayer.stop();
    } catch (e) {
      debugPrint('Error stopping alarm: $e');
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