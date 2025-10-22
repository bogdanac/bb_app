import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'notification_listener_service.dart';
import '../theme/app_colors.dart';
import '../shared/snackbar_utils.dart';

class MotionAlertQuickSetup extends StatefulWidget {
  const MotionAlertQuickSetup({super.key});

  @override
  State<MotionAlertQuickSetup> createState() => _MotionAlertQuickSetupState();
}

class _MotionAlertQuickSetupState extends State<MotionAlertQuickSetup> {
  bool _hasPermission = false;
  bool _isLoading = true;
  
  // Settings
  bool _nightMode = true; // Only at night (22:00-08:00)
  bool _vacationMode = false; // 24/7 mode
  bool _isEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      // Check permission
      final hasPermission = await NotificationListenerService.isPermissionGranted();
      
      // Load existing settings
      final prefs = await SharedPreferences.getInstance();
      final settingsJson = prefs.getString('notification_alarm_settings');
      
      if (settingsJson != null) {
        final settings = json.decode(settingsJson) as Map<String, dynamic>;
        
        setState(() {
          _isEnabled = settings['enabled'] ?? false;
          _nightMode = settings['nightModeOnly'] ?? true;
          _vacationMode = !_nightMode; // Opposite of night mode
        });
      }
      
      setState(() {
        _hasPermission = hasPermission;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading settings: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _requestPermission() async {
    try {
      await NotificationListenerService.requestPermission();
      await Future.delayed(const Duration(seconds: 2));
      final hasPermission = await NotificationListenerService.isPermissionGranted();
      setState(() {
        _hasPermission = hasPermission;
      });
    } catch (e) {
      debugPrint('Error requesting permission: $e');
    }
  }

  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final settings = {
        'enabled': _isEnabled,
        'nightModeOnly': _nightMode && _isEnabled, // Only true if both enabled and night mode
        'keyword': 'detected',
      };
      
      await prefs.setString('notification_alarm_settings', json.encode(settings));
      
      if (mounted) {
        if (_isEnabled) {
          SnackBarUtils.showSuccess(context, 'Motion alerts activated! 🔔');
        } else {
          SnackBarUtils.showWarning(context, 'Motion alerts disabled');
        }
      }
    } catch (e) {
      debugPrint('Error saving settings: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Motion Alert Setup'),
          backgroundColor: Colors.transparent,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Motion Alert Setup'),
        backgroundColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Permission Step - only show if permission not granted
            if (!_hasPermission)
              Card(
                color: Colors.red.withValues(alpha: 0.1),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.warning,
                            color: Colors.red,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Permission Required',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _requestPermission,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Grant Notification Access'),
                      ),
                    ],
                  ),
                ),
              ),

            if (_hasPermission) ...[

              // Night Mode
              Card(
                color: _nightMode && _isEnabled ? AppColors.yellow.withValues(alpha: 0.1) : null,
                child: ListTile(
                  leading: Icon(
                    Icons.nightlight_round,
                    color: _nightMode && _isEnabled ? AppColors.yellow : AppColors.greyText,
                  ),
                  title: const Text('Night Mode'),
                  subtitle: const Text('Alerts only between 22:00-08:00 (recommended)'),
                  trailing: Switch(
                    value: _nightMode && _isEnabled,
                    onChanged: (value) {
                      setState(() {
                        if (value) {
                          _isEnabled = true;
                          _nightMode = true;
                          _vacationMode = false;
                        } else {
                          _isEnabled = false;
                        }
                      });
                      _saveSettings();
                    },
                  ),
                ),
              ),

              const SizedBox(height: 8),

              // Vacation Mode
              Card(
                color: _vacationMode && _isEnabled ? AppColors.orange.withValues(alpha: 0.1) : null,
                child: ListTile(
                  leading: Icon(
                    Icons.luggage_rounded,
                    color: _vacationMode && _isEnabled ? AppColors.orange : AppColors.greyText,
                  ),
                  title: const Text('Vacation Mode'),
                  subtitle: const Text('24/7 alerts (higher battery usage)'),
                  trailing: Switch(
                    value: _vacationMode && _isEnabled,
                    onChanged: (value) {
                      setState(() {
                        if (value) {
                          _isEnabled = true;
                          _nightMode = false;
                          _vacationMode = true;
                        } else {
                          _isEnabled = false;
                        }
                      });
                      _saveSettings();
                    },
                  ),
                ),
              ),

              // Status Summary - show after mode selection when enabled
              if (_hasPermission && _isEnabled) ...[
                const SizedBox(height: 16),
                Card(
                  color: AppColors.yellow.withValues(alpha: 0.1),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.check_circle,
                              color: AppColors.yellow,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Motion Alerts Active',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text('Mode: ${_nightMode ? "Night Mode (22:00-08:00)" : "24/7 Vacation Mode"}'),
                        const Text('Triggers on: Any notification containing "detected" OR "motion" OR "alert" OR "movement"'),
                        const SizedBox(height: 8),
                        Text(
                          _nightMode 
                            ? '💡 Battery optimized - only monitors at night'
                            : '⚠️ Higher battery usage - monitors 24/7',
                          style: TextStyle(
                            color: _nightMode ? AppColors.yellow : AppColors.orange,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          NotificationListenerService.isInitialized 
                            ? '✅ Service initialized and ready'
                            : '❌ Service not properly initialized',
                          style: TextStyle(
                            color: NotificationListenerService.isInitialized ? AppColors.yellow : Colors.red,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              if (_isEnabled) ...[
                const SizedBox(height: 16),
                // Test Alarm Buttons
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          debugPrint('=== TESTING MOTION ALARM ===');
                          await NotificationListenerService.triggerLoudAlarm('Motion Alert', 'Person detected - Test');
                        },
                        icon: const Icon(Icons.volume_up, size: 18),
                        label: const Text('Test Alarm'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.orange,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () {
                        NotificationListenerService.stopAlarm();
                      },
                      icon: const Icon(Icons.stop, size: 18),
                      label: const Text('Stop'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],

            ],
          ],
        ),
      ),
    );
  }
}