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
            // Header
            Card(
              color: AppColors.purple.withOpacity(0.1),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.security_rounded, color: AppColors.purple, size: 28),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Get loud alerts when your security cameras detect motion',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Permission Step
            Card(
              color: _hasPermission ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _hasPermission ? Icons.check_circle : Icons.warning,
                          color: _hasPermission ? Colors.green : Colors.red,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          _hasPermission ? 'Permission Granted ✓' : 'Permission Required',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    if (!_hasPermission) ...[
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
                  ],
                ),
              ),
            ),

            if (_hasPermission) ...[
              const SizedBox(height: 20),

              // Quick Setup Options
              const Text(
                'Quick Setup',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),

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

              const SizedBox(height: 12),

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

              if (_isEnabled) ...[
                const SizedBox(height: 24),

                // App Selection
                const Text(
                  'Select Camera Apps',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),

                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        ...['Tapo', 'Alfred Home Security Camera', 'IP Webcam', 'AtHome Camera', 'WardenCam']
                            .map((app) => CheckboxListTile(
                                  title: Text(app),
                                  value: _selectedApps.contains(app),
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

                const SizedBox(height: 20),

                // Test Button
                if (_selectedApps.isNotEmpty) ...[
                  Card(
                    color: Colors.green.withOpacity(0.1),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          const Text(
                            'Test Your Setup',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    NotificationListenerService.triggerLoudAlarm(
                                      'Motion Detected!',
                                      'Test alarm from your security setup',
                                    );
                                  },
                                  icon: const Icon(Icons.volume_up),
                                  label: const Text('Test Alarm'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                onPressed: () {
                                  NotificationListenerService.stopAlarm();
                                },
                                icon: const Icon(Icons.stop),
                                style: IconButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],

              // Status Summary
              const SizedBox(height: 24),
              Card(
                color: _isEnabled ? Colors.green.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _isEnabled ? Icons.check_circle : Icons.info,
                            color: _isEnabled ? Colors.green : Colors.grey,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            _isEnabled ? 'Motion Alerts Active' : 'Motion Alerts Disabled',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (_isEnabled) ...[
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
                      ] else ...[
                        const Text('Select a mode above to activate motion alerts'),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}