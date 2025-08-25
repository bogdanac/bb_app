import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../theme/app_colors.dart';
import 'notification_listener_service.dart';

class MotionAlertQuickSetup extends StatefulWidget {
  const MotionAlertQuickSetup({Key? key}) : super(key: key);

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
  List<String> _selectedApps = [];

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
        final List<dynamic> monitoredApps = settings['monitoredApps'] ?? [];
        
        setState(() {
          _isEnabled = settings['enabled'] ?? false;
          _nightMode = settings['nightModeOnly'] ?? true;
          _vacationMode = !_nightMode; // Opposite of night mode
          _selectedApps = monitoredApps
              .where((app) => app['enabled'] == true)
              .map<String>((app) => app['appName'] ?? '')
              .toList();
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
      
      // Create monitored apps list
      final monitoredApps = _selectedApps.map((appName) => {
        'packageName': _getPackageForApp(appName),
        'appName': appName,
        'enabled': true,
      }).toList();

      final settings = {
        'enabled': _isEnabled,
        'nightModeOnly': _nightMode,
        'monitoredApps': monitoredApps,
        'keywords': ['motion', 'detected', 'person', 'movement', 'alert'],
      };
      
      await prefs.setString('notification_alarm_settings', json.encode(settings));
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEnabled ? 'Motion alerts activated! 🔔' : 'Motion alerts disabled'),
            backgroundColor: _isEnabled ? Colors.green : Colors.orange,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error saving settings: $e');
    }
  }

  String _getPackageForApp(String appName) {
    // Map common apps to their package names
    const appPackages = {
      'Tapo': 'com.tplinkcloud.tapo',
      'Alfred Home Security Camera': 'com.ivuu',
      'IP Webcam': 'com.pas.webcam',
      'AtHome Camera': 'com.ichano.athome.camera',
      'WardenCam': 'com.wardenapp',
    };
    return appPackages[appName] ?? 'unknown';
  }

  void _toggleApp(String appName) {
    setState(() {
      if (_selectedApps.contains(appName)) {
        _selectedApps.remove(appName);
      } else {
        _selectedApps.add(appName);
      }
    });
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
                color: Colors.red.withOpacity(0.1),
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
                color: _nightMode && _isEnabled ? Colors.blue.withOpacity(0.1) : null,
                child: ListTile(
                  leading: Icon(
                    Icons.nightlight_round,
                    color: _nightMode && _isEnabled ? Colors.blue : Colors.grey,
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
                color: _vacationMode && _isEnabled ? Colors.orange.withOpacity(0.1) : null,
                child: ListTile(
                  leading: Icon(
                    Icons.luggage_rounded,
                    color: _vacationMode && _isEnabled ? Colors.orange : Colors.grey,
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
              if (_hasPermission && _isEnabled && _selectedApps.isNotEmpty) ...[
                const SizedBox(height: 16),
                Card(
                  color: Colors.green.withOpacity(0.1),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.check_circle,
                              color: Colors.green,
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
                        Text('Monitored apps: ${_selectedApps.join(", ")}'),
                        const SizedBox(height: 8),
                        Text(
                          _nightMode 
                            ? '💡 Battery optimized - only monitors at night'
                            : '⚠️ Higher battery usage - monitors 24/7',
                          style: TextStyle(
                            color: _nightMode ? Colors.green : Colors.orange,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              if (_isEnabled) ...[

                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        // Show Tapo prominently
                        CheckboxListTile(
                          title: const Text('Tapo', style: TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: const Text('TP-Link Security Camera (Recommended)'),
                          value: _selectedApps.contains('Tapo'),
                          onChanged: (value) {
                            _toggleApp('Tapo');
                            _saveSettings();
                          },
                          dense: true,
                        ),
                        // Show any other already selected apps
                        ..._selectedApps.where((app) => app != 'Tapo').map((app) => CheckboxListTile(
                              title: Text(app),
                              value: true,
                              onChanged: (value) {
                                _toggleApp(app);
                                _saveSettings();
                              },
                              dense: true,
                            )),
                      ],
                    ),
                  ),
                ),

                // Test Setup (compact version)
                if (_selectedApps.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const SizedBox(width: 4),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            NotificationListenerService.triggerLoudAlarm(
                              'Motion Detected!',
                              'Test alarm from your security setup',
                            );
                          },
                          icon: const Icon(Icons.volume_up, size: 18),
                          label: const Text('Test Alarm'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.green,
                            side: const BorderSide(color: Colors.green),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () {
                          NotificationListenerService.stopAlarm();
                        },
                        icon: const Icon(Icons.stop, size: 18),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.red.withOpacity(0.1),
                          foregroundColor: Colors.red,
                        ),
                        tooltip: 'Stop Alarm',
                      ),
                    ],
                  ),
                ],
                
                const SizedBox(height: 16),
              ],

            ],
          ],
        ),
      ),
    );
  }
}