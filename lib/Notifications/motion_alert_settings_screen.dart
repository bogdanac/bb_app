import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../theme/app_colors.dart';
import 'notification_listener_service.dart';
import '../shared/snackbar_utils.dart';

class MotionAlertSettingsScreen extends StatefulWidget {
  const MotionAlertSettingsScreen({super.key});

  @override
  State<MotionAlertSettingsScreen> createState() => _MotionAlertSettingsScreenState();
}

class _MotionAlertSettingsScreenState extends State<MotionAlertSettingsScreen> {
  bool _isEnabled = false;
  bool _hasPermission = false;
  List<Map<String, dynamic>> _monitoredApps = [];
  List<Map<String, String>> _availableApps = [];
  bool _isLoading = true;
  bool _isLoadingApps = false;
  bool _isRefreshingPermission = false;
  bool _showAllCameraApps = false;

  @override
  void initState() {
    super.initState();
    _initializeEverything();
  }

  Future<void> _initializeEverything() async {
    try {
      await _loadSettings();
      await _checkPermission();
      
      // If we have permission, load all apps immediately
      if (_hasPermission) {
        setState(() {
          _isLoadingApps = true;
        });
        await _loadAllAvailableApps();
      } else {
        // Show common camera apps as fallback
        setState(() {
          _availableApps = NotificationListenerService.getCommonCameraApps();
        });
      }
    } catch (e) {
      debugPrint('Error initializing motion alert settings: $e');
      // Fallback to common apps if initialization fails
      if (mounted) {
        setState(() {
          _availableApps = NotificationListenerService.getCommonCameraApps();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final settingsJson = prefs.getString('notification_alarm_settings');
      
      if (settingsJson != null) {
        final settings = json.decode(settingsJson) as Map<String, dynamic>;
        setState(() {
          _isEnabled = settings['enabled'] ?? false;
          _monitoredApps = List<Map<String, dynamic>>.from(settings['monitoredApps'] ?? []);
        });
      }
    } catch (e) {
      debugPrint('Error loading settings: $e');
    }
  }

  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final settings = {
        'enabled': _isEnabled,
        'nightModeOnly': true,
        'monitoredApps': _monitoredApps,
        'keyword': 'detected',
      };
      
      await prefs.setString('notification_alarm_settings', json.encode(settings));
      
      if (mounted) {
        SnackBarUtils.showSuccess(context, 'Settings saved successfully');
      }
    } catch (e) {
      debugPrint('Error saving settings: $e');
    }
  }

  Future<void> _checkPermission() async {
    try {
      final hasPermission = await NotificationListenerService.isPermissionGranted();
      setState(() {
        _hasPermission = hasPermission;
      });
    } catch (e) {
      debugPrint('Error checking permission: $e');
    }
  }

  Future<void> _requestPermission() async {
    try {
      setState(() {
        _isRefreshingPermission = true;
      });
      
      await NotificationListenerService.requestPermission();
      
      // Wait a bit longer for user to grant permission
      await Future.delayed(const Duration(seconds: 2));
      
      // Check permission status
      await _checkPermission();
      
      // If permission granted, load all apps
      if (_hasPermission) {
        setState(() {
          _isLoadingApps = true;
        });
        await _loadAllAvailableApps();
      }
      
    } catch (e) {
      debugPrint('Error requesting permission: $e');
    } finally {
      setState(() {
        _isRefreshingPermission = false;
      });
    }
  }

  Future<void> _loadAllAvailableApps() async {
    try {
      final apps = await NotificationListenerService.getInstalledApps();
      setState(() {
        _availableApps = apps;
        _isLoadingApps = false;
      });
    } catch (e) {
      debugPrint('Error loading apps: $e');
      setState(() {
        _isLoadingApps = false;
      });
    }
  }

  void _toggleApp(String packageName, String appName) {
    setState(() {
      final existingIndex = _monitoredApps.indexWhere((app) => app['packageName'] == packageName);
      
      if (existingIndex >= 0) {
        _monitoredApps[existingIndex]['enabled'] = !_monitoredApps[existingIndex]['enabled'];
      } else {
        _monitoredApps.add({
          'packageName': packageName,
          'appName': appName,
          'enabled': true,
        });
      }
    });
    _saveSettings();
  }

  bool _isAppMonitored(String packageName) {
    final app = _monitoredApps.firstWhere(
      (app) => app['packageName'] == packageName,
      orElse: () => {'enabled': false},
    );
    return app['enabled'] ?? false;
  }

  List<Map<String, String>> _getFilteredApps() {
    if (_showAllCameraApps) {
      return _availableApps;
    }
    
    // Show only Tapo app and other selected apps
    final tapoApps = _availableApps.where((app) => 
      app['appName']?.toLowerCase().contains('tapo') == true ||
      app['packageName']?.toLowerCase().contains('tapo') == true
    ).toList();
    
    // Also include any apps that are already monitored/enabled
    final monitoredApps = _availableApps.where((app) => 
      _isAppMonitored(app['packageName'] ?? '')
    ).toList();
    
    // Combine both lists and remove duplicates
    final combined = <Map<String, String>>[...tapoApps];
    for (final app in monitoredApps) {
      if (!combined.any((existing) => existing['packageName'] == app['packageName'])) {
        combined.add(app);
      }
    }
    
    return combined;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Night Motion Alerts'),
          backgroundColor: Colors.transparent,
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Night Motion Alerts'),
        backgroundColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Motion Alerts Status Card (on top)
            if (_isEnabled && _hasPermission && _monitoredApps.any((app) => app['enabled'] == true))
              Card(
                color: AppColors.yellow.withValues(alpha: 0.15),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.security_rounded, color: AppColors.yellow, size: 28),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Motion Alerts Active ✓',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.yellow),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Security alerts enabled for night hours (22:00-08:00)',
                              style: TextStyle(color: Colors.black54),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.check_circle, color: AppColors.yellow, size: 24),
                    ],
                  ),
                ),
              ),
            
            if (_isEnabled && _hasPermission && _monitoredApps.any((app) => app['enabled'] == true))
              const SizedBox(height: 16),
            
            // Simple description
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.nightlight_round, color: AppColors.purple, size: 28),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Get loud alerts when your security cameras detect motion at night (22:00-08:00)',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Step 1: Permission (only show if not granted)
            if (!_hasPermission)
              Card(
                color: AppColors.orange.withValues(alpha: 0.1),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.looks_one_rounded,
                            color: AppColors.orange,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Step 1: Grant Permission',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _isRefreshingPermission
                        ? const Row(
                            children: [
                              SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                              SizedBox(width: 12),
                              Text('Checking permission...')
                            ],
                          )
                        : ElevatedButton(
                            onPressed: _requestPermission,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.orange,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Grant Notification Access'),
                          ),
                    ],
                  ),
                ),
              ),
            
            if (!_hasPermission) const SizedBox(height: 16),
            
            // Step 2: Enable alerts
            Card(
              color: _isEnabled ? Colors.green.withValues(alpha: 0.1) : AppColors.normalCardBackground,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _isEnabled ? Icons.check_circle : Icons.looks_two_rounded,
                          color: _isEnabled ? Colors.green : (_hasPermission ? AppColors.purple : AppColors.greyText),
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Step 2: Enable Night Alerts',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      title: const Text('Enable Night Alerts'),
                      subtitle: const Text('Trigger loud alarm when motion detected'),
                      value: _isEnabled,
                      onChanged: _hasPermission ? (value) {
                        setState(() {
                          _isEnabled = value;
                        });
                        _saveSettings();
                      } : null,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Step 3: Select app
            Card(
              color: _monitoredApps.any((app) => app['enabled'] == true) 
                ? Colors.green.withValues(alpha: 0.1) 
                : AppColors.appBackground,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _monitoredApps.any((app) => app['enabled'] == true) 
                            ? Icons.check_circle 
                            : Icons.looks_3_rounded,
                          color: _monitoredApps.any((app) => app['enabled'] == true) 
                            ? Colors.green 
                            : (_hasPermission && _isEnabled ? AppColors.coral : AppColors.greyText),
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Step 3: Select Security Camera App',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    
                    if (!_hasPermission || !_isEnabled)
                      const Text(
                        'Complete steps above first',
                        style: TextStyle(color: AppColors.greyText),
                      )
                    else if (_isLoadingApps)
                      const Row(
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 12),
                          Text('Loading apps...')
                        ],
                      )
                    else if (_availableApps.isEmpty)
                      const Text(
                        'No apps found. Try refreshing by toggling permission.',
                        style: TextStyle(color: AppColors.greyText),
                      )
                    else ...[
                      // Filtered app list
                      ..._getFilteredApps().map((app) {
                        final isMonitored = _isAppMonitored(app['packageName'] ?? '');
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          child: CheckboxListTile(
                            title: Text(app['appName'] ?? 'Unknown'),
                            subtitle: Text(app['packageName'] ?? ''),
                            value: isMonitored,
                            onChanged: (value) {
                              _toggleApp(app['packageName'] ?? '', app['appName'] ?? '');
                            },
                            dense: true,
                          ),
                        );
                      }),
                      
                      // Show/Hide all apps button
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: () {
                          setState(() {
                            _showAllCameraApps = !_showAllCameraApps;
                          });
                        },
                        icon: Icon(_showAllCameraApps ? Icons.expand_less : Icons.expand_more),
                        label: Text(_showAllCameraApps ? 'Show Less' : 'Show All Camera Apps'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.purple,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}