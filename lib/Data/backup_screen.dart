import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'backup_service.dart';

class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  Map<String, dynamic>? _backupInfo;
  bool _isLoading = true;
  bool _autoBackupEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadBackupInfo();
  }

  Future<void> _loadBackupInfo() async {
    try {
      final info = await BackupService.getBackupInfo();
      setState(() {
        _backupInfo = info;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _exportBackup() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final filePath = await BackupService.exportToFile();
      
      if (mounted) {
        if (filePath != null) {
          // Extract just the directory name for user-friendly message
          final fileName = filePath.split(Platform.isWindows ? '\\' : '/').last;
          final isInBackups = filePath.contains('Backups');
          final folderName = isInBackups ? 'App Backups' : 'Documents';
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ Backup exported to $folderName folder!\nFile: $fileName'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 6),
              action: SnackBarAction(
                label: 'Share',
                textColor: Colors.white,
                onPressed: () => _shareBackupFile(filePath),
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ Failed to export backup'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
      _loadBackupInfo();
    }
  }

  Future<void> _importBackup() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          _isLoading = true;
        });

        final success = await BackupService.importFromFile(result.files.single.path!);
        
        if (mounted) {
          if (success) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('✅ Backup restored successfully! Restart app to see changes.'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 4),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('❌ Failed to restore backup'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _exportAndShare() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final filePath = await BackupService.exportToFile();
      
      if (mounted) {
        if (filePath != null) {
          // Directly share the file
          await _shareBackupFile(filePath);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ Failed to create backup for sharing'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
      _loadBackupInfo();
    }
  }

  Future<void> _shareBackupFile(String filePath) async {
    try {
      await SharePlus.instance.share(
        ShareParams(
        files: [XFile(filePath)],
        text: 'BBetter App Backup - ${DateTime.now().toString().split(' ')[0]}',
        subject: 'BBetter Backup File')
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error sharing backup: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatLastBackup(String? lastBackup) {
    if (lastBackup == null) return 'Never';
    try {
      final date = DateTime.parse(lastBackup);
      final now = DateTime.now();
      final difference = now.difference(date).inDays;
      
      if (difference == 0) {
        return 'Today';
      } else if (difference == 1) {
        return 'Yesterday';
      } else {
        return '$difference days ago';
      }
    } catch (e) {
      return 'Unknown';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Backup & Restore'),
        backgroundColor: Colors.transparent,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // Backup Info
                  if (_backupInfo != null && !_backupInfo!.containsKey('error')) ...[
                    const Text(
                      'Your Data',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),

                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            _buildInfoRow(Icons.data_usage, 'Total Items', '${_backupInfo!['total_items']} items'),
                            const Divider(),
                            _buildInfoRow(Icons.timer, 'Fasting Progress', '${_backupInfo!['categories']['fasting']} records'),
                            _buildInfoRow(Icons.favorite, 'Menstrual Cycle', '${_backupInfo!['categories']['menstrual_cycle']} records'),
                            _buildInfoRow(Icons.task_alt, 'Tasks & Categories', '${_backupInfo!['categories']['tasks'] + _backupInfo!['categories']['task_categories']} items'),
                            _buildInfoRow(Icons.auto_awesome, 'Routines', '${_backupInfo!['categories']['routines']} items'),
                            _buildInfoRow(Icons.water_drop, 'Water Tracking', '${_backupInfo!['categories']['water_tracking']} items'),
                            _buildInfoRow(Icons.notifications, 'Notifications', '${_backupInfo!['categories']['notifications']} items'),
                            _buildInfoRow(Icons.settings, 'Settings & Preferences', '${_backupInfo!['categories']['settings'] + _backupInfo!['categories']['app_preferences']} items'),
                            const Divider(),
                            _buildInfoRow(Icons.storage, 'Backup Size', '~${_backupInfo!['backup_size_kb']} KB'),
                            _buildInfoRow(Icons.schedule, 'Last Auto Backup', _formatLastBackup(_backupInfo!['last_auto_backup'])),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),
                  ],

                  // Export Section
                  const Text(
                    'Export Backup',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),

                  Card(
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.download_rounded, color: Colors.green),
                          title: const Text('Export to File'),
                          subtitle: const Text('Save backup to App Backups folder'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: _exportBackup,
                        ),
                        const Divider(height: 0),
                        ListTile(
                          leading: const Icon(Icons.share_rounded, color: Colors.blue),
                          title: const Text('Share Backup'),
                          subtitle: const Text('Share to Google Drive, email, or other apps'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: _exportAndShare,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Import Section
                  const Text(
                    'Restore Backup',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),

                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.upload_file_rounded, color: Colors.orange),
                      title: const Text('Import from File'),
                      subtitle: const Text('Select backup file to restore'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _importBackup,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Auto Backup Settings
                  const Text(
                    'Auto Backup',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),

                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          SwitchListTile(
                            title: const Text('Automatic Weekly Backups'),
                            subtitle: const Text('Auto-backup every 7 days to App Backups folder'),
                            value: _autoBackupEnabled,
                            onChanged: (value) {
                              setState(() {
                                _autoBackupEnabled = value;
                              });
                              // Save this setting
                            },
                            contentPadding: EdgeInsets.zero,
                          ),
                          if (_autoBackupEnabled) ...[
                            const Divider(),
                            const Text(
                              '💡 Tip: Auto backups happen in the background. You can also manually export anytime above.',
                              style: TextStyle(fontSize: 12, color: Colors.grey),
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

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 14))),
          Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}