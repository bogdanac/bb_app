import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:convert';
import 'dart:async';

class NotificationListenerService {
  static const MethodChannel _channel = MethodChannel('notification_listener');
  static final AudioPlayer _audioPlayer = AudioPlayer();
  static bool _isInitialized = false;
  static Timer? _alarmCheckTimer;
  
  // Initialize the service
  static Future<void> initialize() async {
    try {
      debugPrint('🔧 Starting NotificationListenerService initialization...');
      // Prevent multiple initialization attempts (helps with hot reload)
      if (_isInitialized) {
        debugPrint('NotificationListenerService already initialized, skipping...');
        return;
      }
      
      // Set up method call handler FIRST - this is critical
      debugPrint('🔧 Setting up method call handler...');
      _channel.setMethodCallHandler((call) async {
        try {
          debugPrint('🔧 Method call handler triggered for: ${call.method}');
          await _handleMethodCall(call);
        } catch (e, stackTrace) {
          debugPrint('❌ Error in method call handler: $e');
          debugPrint('❌ Stack trace: $stackTrace');
          // Don't rethrow - let the app continue
        }
      });
      debugPrint('🔧 Method call handler set up successfully');
      
      // Initialize notification action handler for stop button
      await _initializeNotificationActions();
      
      // Initialize audio player for alarm functionality
      await _initializeAudioPlayer();
      
      // Initialize the native service with timeout
      debugPrint('🔧 Calling native initialize...');
      final result = await _channel.invokeMethod('initialize').timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          debugPrint('⚠️ NotificationListener native initialization timed out');
          return "timeout";
        },
      );
      debugPrint('🔧 Native initialize result: $result');
      
      _isInitialized = true;
      debugPrint('✅ NotificationListenerService initialized successfully');
      
      // Test method channel connectivity
      await testMethodChannel();
    } catch (e, stackTrace) {
      debugPrint('❌ Error initializing notification listener: $e');
      debugPrint('❌ Stack trace: $stackTrace');
      // Don't rethrow - let the app continue without motion alerts
    }
  }
  
  // Handle calls from native Android code
  static Future<void> _handleMethodCall(MethodCall call) async {
    debugPrint('🔔 Flutter received method call: ${call.method}');
    debugPrint('🔔 Arguments: ${call.arguments}');
    debugPrint('🔔 Arguments type: ${call.arguments.runtimeType}');
    
    switch (call.method) {
      case 'onNotificationReceived':
        debugPrint('🔔 Processing onNotificationReceived...');
        try {
          await _handleNotification(call.arguments);
          debugPrint('🔔 onNotificationReceived processed successfully');
        } catch (e, stackTrace) {
          debugPrint('❌ Error in _handleNotification: $e');
          debugPrint('❌ Stack trace: $stackTrace');
          rethrow; // Re-throw to see if Android gets the error
        }
        break;
      default:
        debugPrint('❓ Unknown method: ${call.method}');
    }
  }
  
  // Handle incoming notification
  // Public method for testing motion alerts
  static Future<void> testMotionAlert({
    required String packageName,
    required String title, 
    required String text,
  }) async {
    debugPrint('🧪 === TESTING MOTION ALERT ===');
    debugPrint('Simulating notification from: $packageName');
    debugPrint('Title: $title');
    debugPrint('Text: $text');
    
    // Ensure all strings are plain strings without formatting
    final notification = {
      'packageName': packageName.toString().trim(),
      'title': title.toString().trim(),
      'text': text.toString().trim(),
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
    
    await _handleNotification(notification);
  }

  static Future<void> _handleNotification(Map<dynamic, dynamic> notification) async {
    try {
      debugPrint('🔔 _handleNotification started');
      debugPrint('🔔 Raw notification: $notification');
      
      // Safely extract strings, handling potential SpannableString objects
      final String packageName = (notification['packageName'] ?? '').toString().trim();
      final String title = (notification['title'] ?? '').toString().trim();
      final String text = (notification['text'] ?? '').toString().trim();
      
      debugPrint('🔔 === NOTIFICATION RECEIVED ===');
      debugPrint('🔔 Package: $packageName');
      debugPrint('🔔 Title: $title');
      debugPrint('🔔 Text: $text');
      debugPrint('🔔 Full notification data: $notification');
      
      // Check if this notification should trigger an alarm
      debugPrint('🔔 Checking if should trigger alarm...');
      final shouldTrigger = await _shouldTriggerAlarm(packageName, title, text);
      debugPrint('🔔 Should trigger alarm: $shouldTrigger');
      
      if (shouldTrigger) {
        debugPrint('🚨 TRIGGERING ALARM NOW! 🚨');
        await triggerLoudAlarm(title, text);
        debugPrint('🚨 Alarm triggered successfully');
      } else {
        debugPrint('🔔 Not triggering alarm - conditions not met');
      }
      
      debugPrint('🔔 _handleNotification completed');
    } catch (e, stackTrace) {
      debugPrint('❌ Error handling notification: $e');
      debugPrint('❌ Stack trace: $stackTrace');
      rethrow;
    }
  }
  
  // Check if notification should trigger alarm
  static Future<bool> _shouldTriggerAlarm(String packageName, String title, String text) async {
    try {
      debugPrint('=== CHECKING ALARM TRIGGER CONDITIONS ===');
      
      final prefs = await SharedPreferences.getInstance();
      final settingsJson = prefs.getString('notification_alarm_settings');
      
      debugPrint('Settings JSON: $settingsJson');
      
      if (settingsJson == null) {
        debugPrint('❌ No settings found - alarm disabled');
        return false;
      }
      
      final settings = json.decode(settingsJson) as Map<String, dynamic>;
      final List<dynamic> monitoredApps = settings['monitoredApps'] ?? [];
      final bool isEnabled = settings['enabled'] ?? false;
      final bool nightModeOnly = settings['nightModeOnly'] ?? true;
      
      debugPrint('Enabled: $isEnabled');
      debugPrint('Night mode only: $nightModeOnly');
      debugPrint('Monitored apps: $monitoredApps');
      
      if (!isEnabled) {
        debugPrint('❌ Feature is disabled');
        return false;
      }
      
      // Check if it's night time (if night mode only)
      if (nightModeOnly) {
        final now = DateTime.now();
        final hour = now.hour;
        debugPrint('Current hour: $hour');
        // Consider night time as 22:00 to 08:00
        if (!(hour >= 22 || hour <= 8)) {
          debugPrint('❌ Not night time (22:00-08:00)');
          return false;
        } else {
          debugPrint('✅ Night time check passed');
        }
      } else {
        debugPrint('✅ Vacation mode - 24/7 monitoring active, skipping time check');
      }
      
      // Skip app monitoring - trigger for any app with keywords
      debugPrint('✅ Skipping app monitoring - checking keywords for any notification');
      
      // Check for single motion detection keyword
      final keyword = settings['keyword'] ?? 'detected';
      final contentToCheck = '$title $text'.toLowerCase();
      
      debugPrint('Keyword: $keyword');
      debugPrint('Content to check: "$contentToCheck"');
      
      // Check for single keyword match
      final hasKeyword = contentToCheck.contains(keyword.toString().toLowerCase());
      
      debugPrint('Matched keyword: ${hasKeyword ? keyword : 'none'}');
      
      debugPrint('Contains keyword: $hasKeyword');
      
      if (hasKeyword) {
        debugPrint('✅ All conditions met - will trigger alarm');
      } else {
        debugPrint('❌ No matching keywords found');
      }
      
      return hasKeyword;
      
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
  
  // Initialize notification actions to handle stop button
  static Future<void> _initializeNotificationActions() async {
    try {
      final FlutterLocalNotificationsPlugin notifications = FlutterLocalNotificationsPlugin();
      
      // Handle notification actions (like stop button) - simplified setup with timeout
      await notifications.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
        onDidReceiveNotificationResponse: (NotificationResponse response) async {
          if (response.actionId == 'stop_alarm') {
            await stopAlarm();
          }
        },
      ).timeout(
        const Duration(seconds: 3),
        onTimeout: () {
          debugPrint('❌ Notification actions initialization timed out');
          throw TimeoutException('Notification actions timeout', const Duration(seconds: 3));
        },
      );
    } catch (e) {
      debugPrint('❌ Error initializing notification actions: $e');
      // Don't rethrow - continue without notification actions
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
      debugPrint('Starting LOUD alarm with maximum volume...');
      
      // PRIORITY 0: Set system alarm volume to maximum first
      await _setMaximumAlarmVolume();
      
      // PRIORITY 1: Audio player with alarm stream (this works!)
      await _audioPlayer.stop();
      
      await _audioPlayer.setAudioContext(AudioContext(
        android: AudioContextAndroid(
          isSpeakerphoneOn: true,
          stayAwake: true,
          contentType: AndroidContentType.sonification,
          usageType: AndroidUsageType.alarm, // This bypasses media volume
          audioFocus: AndroidAudioFocus.gainTransientMayDuck, // More aggressive audio focus
        ),
      ));
      
      await _audioPlayer.setVolume(1.0); // Maximum volume
      await _audioPlayer.setReleaseMode(ReleaseMode.loop);
      
      await _audioPlayer.play(AssetSource('sounds/alarm.mp3'));
      debugPrint('Audio player alarm started at MAXIMUM volume (uses ALARM volume)');
      
      // Stop after 30 seconds
      Future.delayed(const Duration(seconds: 30), () async {
        await stopAlarm();
        debugPrint('Alarm stopped');
      });
      
      // PRIORITY 2: Vibration (always works)
      await _triggerVibration();
      
      // PRIORITY 3: System alarm sound (without problematic notification)
      await _playSystemAlarmSound();
      
      debugPrint('Full LOUD alarm sequence activated');
      
    } catch (e) {
      debugPrint('Audio player alarm failed: $e');
      
      // Emergency fallback - no notifications due to bugs
      await _triggerVibration();
      await _playSystemAlarmSound(); // Use our safe system alarm sound function
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
  
  // Play system alarm sound without showing notification (to avoid icon crash)
  static Future<void> _playSystemAlarmSound() async {
    try {
      debugPrint('Playing system alarm sound...');
      // Use multiple system sound alerts in sequence for louder effect
      for (int i = 0; i < 10; i++) {
        await SystemSound.play(SystemSoundType.alert);
        await Future.delayed(const Duration(milliseconds: 300));
      }
      debugPrint('System alarm sound completed');
    } catch (e) {
      debugPrint('Error playing system alarm sound: $e');
    }
  }


  // Set maximum alarm volume via native method
  static Future<void> _setMaximumAlarmVolume() async {
    try {
      debugPrint('Setting system alarm volume to maximum...');
      await _channel.invokeMethod('setMaxAlarmVolume');
      debugPrint('System alarm volume set to maximum');
    } catch (e) {
      debugPrint('Error setting maximum alarm volume: $e');
    }
  }

  // Stop alarm
  static Future<void> stopAlarm() async {
    try {
      await _audioPlayer.stop();
      
      // Also dismiss the alarm notification
      final FlutterLocalNotificationsPlugin notifications = FlutterLocalNotificationsPlugin();
      await notifications.cancel(9999);
      
      // Restore original alarm volume
      await _restoreAlarmVolume();
    } catch (e) {
      debugPrint('Error stopping alarm: $e');
    }
  }

  // Restore original alarm volume
  static Future<void> _restoreAlarmVolume() async {
    try {
      await _channel.invokeMethod('restoreAlarmVolume');
      debugPrint('Original alarm volume restored');
    } catch (e) {
      debugPrint('Error restoring alarm volume: $e');
    }
  }
  
  
  // Test the full loud alarm system
  static Future<void> testFullAlarm() async {
    debugPrint('=== TESTING FULL LOUD ALARM SYSTEM ===');
    await triggerLoudAlarm('TEST ALARM', 'This is a test of the loud alarm system');
  }

  // Test method channel connectivity
  static Future<void> testMethodChannel() async {
    try {
      debugPrint('Testing method channel...');
      final result = await _channel.invokeMethod('testMethodChannel');
      debugPrint('Method channel test result: $result');
    } catch (e) {
      debugPrint('Method channel test failed: $e');
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
  
  // Check if service is initialized
  static bool get isInitialized => _isInitialized;
  
  // Reset service (useful for hot reload)
  static void reset() {
    try {
      _isInitialized = false;
      _audioPlayer.stop();
      _alarmCheckTimer?.cancel();
      _alarmCheckTimer = null;
      debugPrint('NotificationListenerService reset for hot reload');
    } catch (e) {
      debugPrint('Error resetting service: $e');
    }
  }
}