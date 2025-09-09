import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import 'backup_service.dart';
import '../theme/app_colors.dart';

class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  Map<String, dynamic>? _backupInfo;
  bool _isLoading = true;
  bool _autoBackupEnabled = true;
  DateTime? _lastSessionBackup; // Track backup performed in current session

  @override
  void initState() {
    super.initState();
    _loadBackupInfo();
  }

  Future<void> _loadBackupInfo() async {
    try {
      final info = await BackupService.getBackupInfo();
      
      debugPrint('Loaded backup info - last_backup_time: ${info['last_backup_time']}');
      
      setState(() {
        _backupInfo = info;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading backup info: $e');
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
      
      // Force immediate update of backup info after successful export
      if (filePath != null) {
        // Track the backup time in this session
        _lastSessionBackup = DateTime.now();
        // Add small delay to ensure SharedPreferences is fully synced
        await Future.delayed(const Duration(milliseconds: 100));
        await _loadBackupInfo();
        if (mounted) {
          setState(() {}); // Force UI refresh
        }
      }
      
      if (mounted) {
        if (filePath != null) {
          // Extract just the directory name for user-friendly message
          final fileName = filePath.split(Platform.isWindows ? '\\' : '/').last;
          String folderName = 'Documents';
          if (filePath.contains('BBetter_Backups')) {
            folderName = 'Downloads/BBetter_Backups';
          } else if (filePath.contains('Backups')) {
            folderName = 'App Backups';
          } else if (filePath.contains('Download')) {
            folderName = 'Downloads';
          }
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ Backup exported to $folderName folder!\nFile: $fileName'),
              backgroundColor: AppColors.successGreen,
              duration: const Duration(seconds: 4),
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
    }
  }


  Future<void> _importFromCloud() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        await _processImport(result.files.single.path!);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Cloud import error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _findBackupFiles() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final locations = await BackupService.getBackupLocations();
      
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('📁 Found Backup Files'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (locations['found_files'].isEmpty) ...[
                    const Text('No backup files found.'),
                    const SizedBox(height: 12),
                    const Text('Try exporting a backup first, then check these locations:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    ...locations['all_locations'].map<Widget>((path) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text('• $path', style: const TextStyle(fontSize: 12, fontFamily: 'monospace')),
                    )),
                  ] else ...[
                    Text('Found ${locations['found_files'].length} backup file(s):', style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    ...locations['found_files'].map<Widget>((file) => Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(file['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            const SizedBox(height: 4),
                            Text('📍 ${file['location']}', style: const TextStyle(fontSize: 10, fontFamily: 'monospace')),
                            const SizedBox(height: 2),
                            Text('📅 ${_formatBackupDate(file['modified'])}', style: const TextStyle(fontSize: 10)),
                            Text('💾 ${(file['size'] / 1024).round()} KB', style: const TextStyle(fontSize: 10)),
                            const SizedBox(height: 4),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: () {
                                  Navigator.of(context).pop();
                                  _processImport(file['path']);
                                },
                                child: const Text('Import This File'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error finding backup files: $e'),
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

  String _formatBackupDate(String isoString) {
    try {
      final date = DateTime.parse(isoString);
      final now = DateTime.now();
      final difference = now.difference(date).inDays;
      
      if (difference == 0) {
        return 'Today ${DateFormat('HH:mm').format(date)}';
      } else if (difference == 1) {
        return 'Yesterday ${DateFormat('HH:mm').format(date)}';
      } else if (difference < 7) {
        return '${DateFormat('MMM dd, HH:mm').format(date)} ($difference days ago)';
      } else if (difference < 30) {
        final weeks = (difference / 7).round();
        return '${DateFormat('MMM dd, yyyy HH:mm').format(date)} ($weeks week${weeks > 1 ? 's' : ''} ago)';
      } else if (difference < 365) {
        final months = (difference / 30).round();
        return '${DateFormat('MMM dd, yyyy HH:mm').format(date)} ($months month${months > 1 ? 's' : ''} ago)';
      } else {
        final years = (difference / 365).round();
        return '${DateFormat('MMM dd, yyyy HH:mm').format(date)} ($years year${years > 1 ? 's' : ''} ago)';
      }
    } catch (e) {
      return 'Unknown date';
    }
  }

  Future<void> _processImport(String filePath) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final importResult = await BackupService.importFromFile(filePath);
      
      if (mounted) {
        if (importResult['success']) {
          final restoredCount = importResult['restored_count'] ?? 0;
          final errors = importResult['errors'] ?? [];
          
          String message = '✅ Backup restored successfully!\n'
              'Restored $restoredCount items';
          
          if (errors.isNotEmpty) {
            message += '\n${errors.length} items had issues';
          }
          
          message += '\nRestart app to see changes.';
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              backgroundColor: AppColors.successGreen,
              duration: const Duration(seconds: 6),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ Import failed: ${importResult['error']}'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 6),
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
    }
  }

  Future<void> _exportAndShare() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final filePath = await BackupService.exportToFile();
      
      // Force immediate update of backup info after successful export
      if (filePath != null) {
        // Track the backup time in this session
        _lastSessionBackup = DateTime.now();
        // Add small delay to ensure SharedPreferences is fully synced
        await Future.delayed(const Duration(milliseconds: 100));
        await _loadBackupInfo();
      }
      
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
    }
  }

  Future<void> _shareBackupFile(String filePath) async {
    try {
      // Verify the original file exists before sharing
      final originalFile = File(filePath);
      if (!await originalFile.exists()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ Backup file not found for sharing'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Create a temporary copy for sharing to prevent file system issues
      final fileName = filePath.split(Platform.pathSeparator).last;
      final tempDir = Directory.systemTemp;
      final tempFile = File('${tempDir.path}${Platform.pathSeparator}share_$fileName');
      
      // Copy the file to temp location
      await originalFile.copy(tempFile.path);

      final now = DateTime.now();
      final dateTime = DateFormat('yyyy-MM-dd HH:mm:ss').format(now);
      final dateTimeShort = DateFormat('yyyy-MM-dd HH:mm').format(now);
      
      await SharePlus.instance.share(
        ShareParams(
        files: [XFile(tempFile.path)],
        text: 'BBetter App Backup - $dateTime',
        subject: 'BBetter Backup File - $dateTimeShort')
      );

      // Verify original file still exists after sharing
      if (await originalFile.exists()) {
        debugPrint('Original backup file preserved at: $filePath');
      } else {
        debugPrint('WARNING: Original backup file was removed during sharing!');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('⚠️ Warning: Local backup file may have been moved during sharing'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }

      // Clean up temp file after a delay (let sharing complete first)
      Future.delayed(const Duration(seconds: 10), () async {
        try {
          if (await tempFile.exists()) {
            await tempFile.delete();
            debugPrint('Cleaned up temporary share file');
          }
        } catch (e) {
          debugPrint('Could not clean up temp file: $e');
        }
      });

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
    // If no stored backup time but we have session backup, show "Today"
    if (lastBackup == null && _lastSessionBackup != null) {
      final now = DateTime.now();
      final difference = now.difference(_lastSessionBackup!).inDays;
      if (difference == 0) return 'Today';
    }
    
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
                            _buildInfoRow(Icons.schedule, 'Last Backup', _formatLastBackup(_backupInfo!['last_backup_time'])),
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
                          leading: const Icon(Icons.download_rounded, color: AppColors.successGreen),
                          title: const Text('Export to File'),
                          subtitle: const Text('Save backup to App Backups folder'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: _exportBackup,
                        ),
                        const Divider(height: 0),
                        ListTile(
                          leading: const Icon(Icons.share_rounded, color: AppColors.waterBlue),
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
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.search, color: Colors.purple),
                          title: const Text('Find My Backup Files'),
                          subtitle: const Text('Locate existing backup files on device'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: _findBackupFiles,
                        ),
                        const Divider(height: 0),
                        ListTile(
                          leading: const Icon(Icons.cloud_download, color: AppColors.waterBlue),
                          title: const Text('Import from Cloud Storage'),
                          subtitle: const Text('Select backup from Google Drive, etc.'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: _importFromCloud,
                        ),
                      ],
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
                            title: const Text('Automatic Daily Backups'),
                            subtitle: const Text('Auto-backup every day to App Backups folder'),
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
                            Row(
                              children: [
                                const Icon(Icons.schedule, size: 14, color: Colors.grey),
                                const SizedBox(width: 6),
                                Text(
                                  'Last backup: ${_formatLastBackup(_backupInfo?['last_backup_time'])}',
                                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              '💡 Tip: Auto backups happen daily in the background. You can also manually export anytime above.',
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