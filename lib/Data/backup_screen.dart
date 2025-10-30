import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'backup_service.dart';
import '../shared/date_format_utils.dart';
import '../theme/app_colors.dart';
import '../theme/app_styles.dart';
import '../shared/snackbar_utils.dart';
import '../shared/dialog_utils.dart';
import '../Services/firebase_backup_service.dart';

class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  Map<String, dynamic>? _backupInfo;
  Map<String, dynamic>? _detailedBackupStatus;
  bool _isLoading = true;
  bool _autoBackupEnabled = true;
  int _overdueThreshold = 6; // Days
  DateTime? _lastSessionBackup; // Track backup performed in current session

  @override
  void initState() {
    super.initState();
    _loadBackupInfo();
  }

  Future<void> _loadBackupInfo() async {
    try {
      final info = await BackupService.getBackupInfo();
      final detailedStatus = await BackupService.getDetailedBackupStatus();
      final threshold = await BackupService.getBackupOverdueThreshold();

      // Load auto backup setting
      final prefs = await SharedPreferences.getInstance();
      final autoBackupEnabled = prefs.getBool('auto_backup_enabled') ?? true;

      setState(() {
        _backupInfo = info;
        _detailedBackupStatus = detailedStatus;
        _overdueThreshold = threshold;
        _autoBackupEnabled = autoBackupEnabled;
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

        // Timestamp was already updated in BackupService.exportToFile()
        // Add small delay to ensure SharedPreferences is fully synced
        await Future.delayed(const Duration(milliseconds: 100));
        await _loadBackupInfo();
        if (mounted) {
          setState(() {}); // Force UI refresh
        }
      }
      
      if (mounted) {
        if (filePath != null) {
          // Show full path for clarity
          final fileName = filePath.split(Platform.isWindows ? '\\' : '/').last;
          final directory = filePath.substring(0, filePath.lastIndexOf(Platform.isWindows ? '\\' : '/'));

          SnackBarUtils.showSuccess(context, '✅ Backup exported!\nLocation: $directory\nFile: $fileName', duration: const Duration(seconds: 5));
        } else {
          SnackBarUtils.showError(context, '❌ Failed to export backup');
        }
      }
    } catch (e) {
      if (mounted) {
        String userFriendlyMessage = _getUserFriendlyErrorMessage(e.toString());
        SnackBarUtils.showError(context, userFriendlyMessage, duration: const Duration(seconds: 5));
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
        SnackBarUtils.showError(context, '❌ Cloud import error: $e');
      }
    }
  }

  Future<void> _restoreFromFirebase() async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('🔥 Restore from Firebase?'),
        content: const Text(
          'This will restore all your data from Firebase backup.\n\n'
          'Current data will be replaced. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Restore'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final hasBackup = await FirebaseBackupService().hasBackup();

      if (!hasBackup) {
        if (mounted) {
          SnackBarUtils.showError(context, '❌ No Firebase backup found');
        }
        return;
      }

      final restored = await FirebaseBackupService().restoreAllData();

      if (mounted) {
        if (restored) {
          SnackBarUtils.showSuccess(context, '✅ Data restored from Firebase!');
          // Reload the screen
          await _loadBackupInfo();
        } else {
          SnackBarUtils.showError(context, '❌ Failed to restore from Firebase');
        }
      }
    } catch (e) {
      if (mounted) {
        SnackBarUtils.showError(context, '❌ Firebase restore error: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
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
        // Check if found_files exists and is not null
        final foundFiles = locations['found_files'] as List? ?? [];

        // Show as full screen if there are many files or on small screens
        if (foundFiles.length > 3 || MediaQuery.of(context).size.height < 700) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => _BackupFilesFullScreen(
                onImport: _processImport,
              ),
            ),
          );
        } else {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('📁 Backup Files'),
              contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              content: ConstrainedBox(
                constraints: BoxConstraints(
                  minWidth: MediaQuery.of(context).size.width * 0.95,
                  maxWidth: MediaQuery.of(context).size.width * 0.95,
                  maxHeight: MediaQuery.of(context).size.height * 0.8,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (locations['found_files'].isEmpty) ...[
                        const Text(
                          'No backup files found.',
                          style: TextStyle(fontSize: 16),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Try exporting a backup first, then check these locations:',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        const SizedBox(height: 8),
                        ...locations['all_locations'].map<Widget>((path) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('• ', style: TextStyle(fontSize: 14)),
                              Expanded(
                                child: Text(
                                  path,
                                  style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
                                  softWrap: true,
                                ),
                              ),
                            ],
                          ),
                        )),
                      ] else ...[
                        // Full storage path
                        if (locations['found_files'].isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppColors.greyText.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.folder_outlined, size: 16, color: AppColors.greyText),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Storage Location:',
                                        style: TextStyle(fontSize: 11, color: AppColors.greyText, fontWeight: FontWeight.w500),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        locations['found_files'].first['location'],
                                        style: const TextStyle(fontSize: 11, color: AppColors.greyText, fontFamily: 'monospace'),
                                        softWrap: true,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        ...locations['found_files'].map<Widget>((file) => Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          elevation: 1,
                          color: Theme.of(context).cardColor.withValues(alpha: 0.8),
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppColors.dialogCardBackground,
                              borderRadius: AppStyles.borderRadiusSmall,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Date and size in one compact row
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(Icons.schedule, size: 14, color: Colors.blue),
                                          const SizedBox(width: 4),
                                          Text(
                                            _formatBackupDate(file['modified']),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                              color: Colors.blue,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Text(
                                        '${(file['size'] / 1024).round()} KB',
                                        style: const TextStyle(fontSize: 12, color: AppColors.greyText),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  // File name - more compact
                                  Text(
                                    file['name'].length > 35 
                                      ? '${file['name'].substring(0, 32)}...'
                                      : file['name'],
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                                  ),
                                  const SizedBox(height: 8),
                                  // Import and Delete buttons
                                  Row(
                                    children: [
                                      Expanded(
                                        child: SizedBox(
                                          height: 32,
                                          child: ElevatedButton.icon(
                                            onPressed: () {
                                              Navigator.of(context).pop();
                                              _processImport(file['path']);
                                            },
                                            icon: const Icon(Icons.download_rounded, size: 16),
                                            label: const Text('Import', style: TextStyle(fontSize: 13)),
                                            style: ElevatedButton.styleFrom(
                                              padding: const EdgeInsets.symmetric(horizontal: 12),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      SizedBox(
                                        height: 32,
                                        child: IconButton(
                                          onPressed: () async {
                                            final confirmed = await DialogUtils.showDeleteConfirmation(
                                              context,
                                              itemName: file['name'],
                                            );

                                            if (confirmed == true) {
                                              try {
                                                final backupFile = File(file['path']);
                                                if (await backupFile.exists()) {
                                                  await backupFile.delete();
                                                  if (!context.mounted) return;
                                                  // Refresh the info
                                                  await _loadBackupInfo();
                                                  if (!context.mounted) return;
                                                  SnackBarUtils.showSuccess(context, '✅ Backup file deleted');
                                                }
                                              } catch (e) {
                                                if (!context.mounted) return;
                                                SnackBarUtils.showError(context, '❌ Failed to delete: $e');
                                              }
                                            }
                                          },
                                          icon: const Icon(Icons.delete_rounded, color: Colors.red, size: 20),
                                          tooltip: 'Delete',
                                          padding: EdgeInsets.zero,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )),
                      ],
                    ],
                  ),
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
      }
    } catch (e) {
      if (mounted) {
        SnackBarUtils.showError(context, '❌ Error finding backup files: $e');
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

      // Debug timestamp issues
      if (difference < 0) {
        debugPrint('WARNING: Backup date is in the future! Date: $date, Now: $now, Difference: $difference days');
        // If date is in the future, show it as "Today" with time
        return 'Today ${DateFormatUtils.formatTime24(date)} (⚠️ Future timestamp)';
      }

      if (difference == 0) {
        return 'Today ${DateFormatUtils.formatTime24(date)}';
      } else if (difference == 1) {
        return 'Yesterday ${DateFormatUtils.formatTime24(date)}';
      } else if (difference < 7) {
        return '${DateFormatUtils.formatShort(date)}, ${DateFormatUtils.formatTime24(date)} ($difference days ago)';
      } else if (difference < 30) {
        final weeks = (difference / 7).round();
        return '${DateFormatUtils.formatLong(date)}, ${DateFormatUtils.formatTime24(date)} ($weeks week${weeks > 1 ? 's' : ''} ago)';
      } else if (difference < 365) {
        final months = (difference / 30).round();
        return '${DateFormatUtils.formatLong(date)}, ${DateFormatUtils.formatTime24(date)} ($months month${months > 1 ? 's' : ''} ago)';
      } else {
        final years = (difference / 365).round();
        return '${DateFormatUtils.formatLong(date)}, ${DateFormatUtils.formatTime24(date)} ($years year${years > 1 ? 's' : ''} ago)';
      }
    } catch (e) {
      return 'Unknown date';
    }
  }

  Future<void> _processImport(String filePath) async {
    // Show confirmation dialog first
    final fileName = filePath.split(Platform.pathSeparator).last;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.dialogBackground,
        title: const Row(
          children: [
            Icon(Icons.warning_rounded, color: Colors.orange),
            SizedBox(width: 8),
            Text('Import Backup?', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This will REPLACE all your current app data with the backup data.',
              style: TextStyle(color: AppColors.white70, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              'File: $fileName',
              style: const TextStyle(color: Colors.blue, fontSize: 13),
            ),
            const SizedBox(height: 12),
            const Text(
              'Your current data will be lost! Make sure you have a recent backup of your current data before proceeding.',
              style: TextStyle(color: Colors.red, fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.white70)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Import & Replace Data'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

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

          SnackBarUtils.showSuccess(context, message, duration: const Duration(seconds: 6));
        } else {
          SnackBarUtils.showError(context, '❌ Import failed: ${importResult['error']}', duration: const Duration(seconds: 6));
        }
      }
    } catch (e) {
      if (mounted) {
        String userFriendlyMessage = _getUserFriendlyErrorMessage(e.toString());
        SnackBarUtils.showError(context, userFriendlyMessage, duration: const Duration(seconds: 5));
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
      // Save cloud share timestamp BEFORE creating backup so it's included
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_cloud_share', DateTime.now().toIso8601String());
      await prefs.reload();

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

          // Refresh backup info after sharing
          await _loadBackupInfo();
          if (mounted) {
            setState(() {}); // Force UI refresh
          }
        } else {
          SnackBarUtils.showError(context, '❌ Failed to create backup for sharing');
        }
      }
    } catch (e) {
      if (mounted) {
        String userFriendlyMessage = _getUserFriendlyErrorMessage(e.toString());
        SnackBarUtils.showError(context, userFriendlyMessage, duration: const Duration(seconds: 5));
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
          SnackBarUtils.showError(context, '❌ Backup file not found for sharing');
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
      final dateTime = '${DateFormatUtils.formatLong(now)}, ${DateFormatUtils.formatTime24(now)}';
      final dateTimeShort = '${DateFormatUtils.formatLong(now)}, ${DateFormatUtils.formatTime24(now)}';
      
      await SharePlus.instance.share(
        ShareParams(
        files: [XFile(tempFile.path)],
        text: 'BBetter App Backup - $dateTime',
        subject: 'BBetter Backup File - $dateTimeShort')
      );

      // Cloud sharing timestamp was already saved before backup creation

      // Verify original file still exists after sharing
      if (await originalFile.exists()) {
        // File preserved successfully
      } else {
        debugPrint('WARNING: Original backup file was removed during sharing!');
        if (mounted) {
          SnackBarUtils.showWarning(context, '⚠️ Warning: Local backup file may have been moved during sharing');
        }
      }

      // Clean up temp file after a delay (let sharing complete first)
      Future.delayed(const Duration(seconds: 10), () async {
        try {
          if (await tempFile.exists()) {
            await tempFile.delete();
          }
        } catch (e) {
          debugPrint('Could not clean up temp file: $e');
        }
      });

    } catch (e) {
      if (mounted) {
        SnackBarUtils.showError(context, '❌ Error sharing backup: $e');
      }
    }
  }

  String _formatLastBackup(String? lastBackup) {
    // If no stored backup time but we have session backup, show "Today"
    if (lastBackup == null && _lastSessionBackup != null) {
      final now = DateTime.now();
      final nowDate = DateTime(now.year, now.month, now.day);
      final sessionDate = DateTime(_lastSessionBackup!.year, _lastSessionBackup!.month, _lastSessionBackup!.day);
      final difference = nowDate.difference(sessionDate).inDays;
      if (difference == 0) return 'Today';
    }

    if (lastBackup == null) return 'Never';
    try {
      final date = DateTime.parse(lastBackup);
      final now = DateTime.now();

      // Compare calendar dates, not time differences
      final nowDate = DateTime(now.year, now.month, now.day);
      final backupDate = DateTime(date.year, date.month, date.day);
      final difference = nowDate.difference(backupDate).inDays;

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

  String _formatBackupStatus(String? lastBackup, bool isOverdue, int? daysSince) {
    if (lastBackup == null) {
      return 'Never (⚠️ Overdue)';
    }

    final formatted = _formatLastBackup(lastBackup);
    if (isOverdue && daysSince != null) {
      return '$formatted (⚠️ $daysSince days ago)';
    }
    return formatted;
  }

  Widget _buildStatusRow(IconData icon, String label, String value, bool isOverdue) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: isOverdue ? Colors.orange : AppColors.greyText),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 14))),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: isOverdue ? Colors.orange : null,
            ),
          ),
        ],
      ),
    );
  }

  String _getUserFriendlyErrorMessage(String error) {
    if (error.contains('Storage permission denied')) {
      return '❌ Storage permission required\nPlease allow file access in app settings';
    } else if (error.contains('Downloads directory access')) {
      return '❌ Cannot access Downloads folder\nCheck storage permissions';
    } else if (error.contains('Backup file validation failed')) {
      return '❌ Backup file corrupted\nTry creating a new backup';
    } else if (error.contains('Invalid backup file format')) {
      return '❌ Invalid backup file\nFile may be corrupted or incompatible';
    } else if (error.contains('Incompatible backup version')) {
      return '❌ Incompatible backup version\nBackup was created with a newer app version';
    } else if (error.contains('Backup file not found')) {
      return '❌ Backup file not found\nFile may have been moved or deleted';
    } else {
      return '❌ Error: ${error.split(':').last.trim()}';
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

                  // Backup Status Info
                  if (_detailedBackupStatus != null && !_detailedBackupStatus!.containsKey('error')) ...[
                    // Overall warning if any backup is overdue
                    if (_detailedBackupStatus!['any_overdue'] == true) ...[
                      Card(
                        color: Colors.orange.withValues(alpha: 0.1),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              const Icon(Icons.warning_rounded, color: Colors.orange, size: 24),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Backup Overdue Warning',
                                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange),
                                    ),
                                    Text(
                                      'Some backups are more than $_overdueThreshold days old. Please update your backups.',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],

                    // Detailed backup status
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Backup Status',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 12),
                            _buildStatusRow(
                              Icons.touch_app,
                              'Last Manual Backup',
                              _formatBackupStatus(
                                _detailedBackupStatus!['last_manual_backup'],
                                _detailedBackupStatus!['manual_overdue'] ?? false,
                                _detailedBackupStatus!['days_since_manual'],
                              ),
                              _detailedBackupStatus!['manual_overdue'] ?? false,
                            ),
                            _buildStatusRow(
                              Icons.schedule,
                              'Last Auto Backup',
                              _formatBackupStatus(
                                _detailedBackupStatus!['last_auto_backup'],
                                _detailedBackupStatus!['auto_overdue'] ?? false,
                                _detailedBackupStatus!['days_since_auto'],
                              ),
                              _detailedBackupStatus!['auto_overdue'] ?? false,
                            ),
                            _buildStatusRow(
                              Icons.cloud_upload,
                              'Last Cloud Share',
                              _formatBackupStatus(
                                _detailedBackupStatus!['last_cloud_share'],
                                _detailedBackupStatus!['cloud_overdue'] ?? false,
                                _detailedBackupStatus!['days_since_cloud'],
                              ),
                              _detailedBackupStatus!['cloud_overdue'] ?? false,
                            ),
                            _buildFirebaseBackupStatusRow(),
                          ],
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 8),

                  // Export Section
                  const Center(
                    child: Text(
                      'Export',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 8),

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

                  const SizedBox(height: 8),

                  // Import Section
                  const Center(
                    child: Text(
                      'Restore',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 8),

                  Card(
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.cloud_upload, color: Colors.orange),
                          title: const Text('Restore from Firebase'),
                          subtitle: const Text('Restore automatic cloud backup'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: _restoreFromFirebase,
                        ),
                        const Divider(height: 0),
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

                  const SizedBox(height: 8),

                  // Auto backup settings moved to position 6
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Column(
                        children: [
                          SwitchListTile(
                            title: const Text('Automatic Daily Backups'),
                            subtitle: const Text('Auto-backup when app starts (once per day)'),
                            value: _autoBackupEnabled,
                            onChanged: (value) async {
                              setState(() {
                                _autoBackupEnabled = value;
                              });
                              // Save this setting
                              final prefs = await SharedPreferences.getInstance();
                              await prefs.setBool('auto_backup_enabled', value);

                              // Just save the setting - backup will check on next startup
                              // No need for complex timers
                            },
                            contentPadding: EdgeInsets.zero,
                          ),
                          const Divider(),
                          ListTile(
                            title: const Text('Backup Warning Threshold'),
                            subtitle: Text('Show overdue warnings after $_overdueThreshold days without backup'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.remove),
                                  onPressed: _overdueThreshold > 1 ? () async {
                                    final newThreshold = _overdueThreshold - 1;
                                    await BackupService.setBackupOverdueThreshold(newThreshold);

                                    // Just update the threshold and recalculate overdue status
                                    final updatedStatus = await BackupService.getDetailedBackupStatus();
                                    setState(() {
                                      _overdueThreshold = newThreshold;
                                      _detailedBackupStatus = updatedStatus;
                                    });
                                  } : null,
                                ),
                                Text('$_overdueThreshold'),
                                IconButton(
                                  icon: const Icon(Icons.add),
                                  onPressed: _overdueThreshold < 30 ? () async {
                                    final newThreshold = _overdueThreshold + 1;
                                    await BackupService.setBackupOverdueThreshold(newThreshold);

                                    // Just update the threshold and recalculate overdue status
                                    final updatedStatus = await BackupService.getDetailedBackupStatus();
                                    setState(() {
                                      _overdueThreshold = newThreshold;
                                      _detailedBackupStatus = updatedStatus;
                                    });
                                  } : null,
                                ),
                              ],
                            ),
                            contentPadding: EdgeInsets.zero,
                          ),
                          if (_autoBackupEnabled) ...[
                            const Divider(),
                            const Text(
                              '💡 Auto backups happen once per day when you open the app. Manual backups and cloud sharing should be done regularly for extra protection.',
                              style: TextStyle(fontSize: 12, color: AppColors.greyText),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Original backup info for file details moved to bottom
                  if (_backupInfo != null && !_backupInfo!.containsKey('error')) ...[
                    const Center(
                      child: Text(
                        'Backup Details',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 8),
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

  Widget _buildFirebaseBackupStatusRow() {
    return FutureBuilder<String>(
      future: _getLastFirebaseBackup(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildStatusRow(
            Icons.cloud_upload,
            'Last Firebase Backup',
            'Loading...',
            false,
          );
        }

        final lastBackup = snapshot.data ?? 'Never';
        return _buildStatusRow(
          Icons.cloud_upload,
          'Last Firebase Backup',
          lastBackup,
          false,
        );
      },
    );
  }

  Future<String> _getLastFirebaseBackup() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastBackupStr = prefs.getString('last_firebase_backup');

      if (lastBackupStr == null) {
        return 'Never';
      }

      return _formatLastBackup(lastBackupStr);
    } catch (e) {
      return 'Never';
    }
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.greyText),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 14))),
          Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class _BackupFilesFullScreen extends StatefulWidget {
  final Function(String) onImport;

  const _BackupFilesFullScreen({
    required this.onImport,
  });

  @override
  State<_BackupFilesFullScreen> createState() => _BackupFilesFullScreenState();
}

class _BackupFilesFullScreenState extends State<_BackupFilesFullScreen> {
  Map<String, dynamic>? locations;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBackupFiles();
  }

  Future<void> _loadBackupFiles() async {
    setState(() {
      isLoading = true;
    });
    final info = await BackupService.getBackupLocations();
    setState(() {
      locations = info;
      isLoading = false;
    });
  }

  String _formatBackupDate(String isoString) {
    try {
      final date = DateTime.parse(isoString);
      final now = DateTime.now();
      final difference = now.difference(date).inDays;

      // Debug timestamp issues
      if (difference < 0) {
        debugPrint('WARNING: Backup date is in the future! Date: $date, Now: $now, Difference: $difference days');
        // If date is in the future, show it as "Today" with time
        return 'Today ${DateFormatUtils.formatTime24(date)} (⚠️ Future timestamp)';
      }

      if (difference == 0) {
        return 'Today ${DateFormatUtils.formatTime24(date)}';
      } else if (difference == 1) {
        return 'Yesterday ${DateFormatUtils.formatTime24(date)}';
      } else if (difference < 7) {
        return '${DateFormatUtils.formatShort(date)}, ${DateFormatUtils.formatTime24(date)} ($difference days ago)';
      } else if (difference < 30) {
        final weeks = (difference / 7).round();
        return '${DateFormatUtils.formatLong(date)}, ${DateFormatUtils.formatTime24(date)} ($weeks week${weeks > 1 ? 's' : ''} ago)';
      } else if (difference < 365) {
        final months = (difference / 30).round();
        return '${DateFormatUtils.formatLong(date)}, ${DateFormatUtils.formatTime24(date)} ($months month${months > 1 ? 's' : ''} ago)';
      } else {
        final years = (difference / 365).round();
        return '${DateFormatUtils.formatLong(date)}, ${DateFormatUtils.formatTime24(date)} ($years year${years > 1 ? 's' : ''} ago)';
      }
    } catch (e) {
      return 'Unknown date';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading || locations == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Backup Files'),
          backgroundColor: Colors.transparent,
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Backup Files'),
        backgroundColor: Colors.transparent,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if ((locations!['found_files'] as List? ?? []).isEmpty) ...[
              const Text(
                'No backup files found.',
                style: TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 16),
              const Text(
                'Try exporting a backup first, then check these locations:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.builder(
                  itemCount: locations!['all_locations'].length,
                  itemBuilder: (context, index) {
                    final path = locations!['all_locations'][index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('• ', style: TextStyle(fontSize: 16)),
                          Expanded(
                            child: Text(
                              path,
                              style: const TextStyle(fontSize: 14, fontFamily: 'monospace'),
                              softWrap: true,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ] else ...[
              // Storage location info
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.greyText.withValues(alpha: 0.15),
                  borderRadius: AppStyles.borderRadiusSmall,
                ),
                child: Row(
                  children: [
                    const Icon(Icons.folder_outlined, size: 20, color: AppColors.greyText),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Storage Location:',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            locations!['found_files'].first['location'],
                            style: const TextStyle(fontSize: 13, color: AppColors.greyText),
                            softWrap: true,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '${locations!['found_files'].length} backup files found:',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.builder(
                  itemCount: locations!['found_files'].length,
                  itemBuilder: (context, index) {
                    final file = locations!['found_files'][index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 2,
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.dialogCardBackground,
                          borderRadius: AppStyles.borderRadiusSmall,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Date and size
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.schedule, size: 16, color: Colors.blue),
                                      const SizedBox(width: 6),
                                      Text(
                                        _formatBackupDate(file['modified']),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: Colors.blue,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    '${(file['size'] / 1024).round()} KB',
                                    style: const TextStyle(fontSize: 13, color: AppColors.greyText),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              // File name
                              Text(
                                file['name'],
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                                softWrap: true,
                              ),
                              const SizedBox(height: 12),
                              // Import and Delete buttons
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: () {
                                        Navigator.of(context).pop();
                                        widget.onImport(file['path']);
                                      },
                                      icon: const Icon(Icons.download_rounded),
                                      label: const Text('Import'),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    onPressed: () async {
                                      final confirmed = await DialogUtils.showDeleteConfirmation(
                                        context,
                                        itemName: file['name'],
                                      );

                                      if (confirmed == true) {
                                        try {
                                          final backupFile = File(file['path']);
                                          if (await backupFile.exists()) {
                                            await backupFile.delete();
                                            if (!context.mounted) return;
                                            // Refresh the list
                                            await _loadBackupFiles();
                                            if (!context.mounted) return;
                                            SnackBarUtils.showSuccess(context, '✅ Backup file deleted');
                                          }
                                        } catch (e) {
                                          if (!context.mounted) return;
                                          SnackBarUtils.showError(context, '❌ Failed to delete: $e');
                                        }
                                      }
                                    },
                                    icon: const Icon(Icons.delete_rounded, color: Colors.red),
                                    tooltip: 'Delete backup',
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}