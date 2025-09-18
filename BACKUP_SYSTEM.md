# BBetter App - Backup & Restore System

## Overview

The BBetter app includes a comprehensive backup and restore system that allows users to export their data, share it across devices, and restore from previous backups. The system handles all app data including fasting records, menstrual cycle data, tasks, routines, habits, and user preferences.

## Architecture

### Core Components

1. **BackupService** (`lib/Data/backup_service.dart`) - Main service handling backup logic
2. **BackupScreen** (`lib/Data/backup_screen.dart`) - User interface for backup operations
3. **Automatic Scheduling** - Background daily backups with notification system
4. **File Management** - Intelligent file location detection and cleanup

## Features

### 📤 Export Options

#### Manual Export to File
- **Location**: Downloads/BBetter_Backups/ (primary) or App Documents/Backups/ (fallback)
- **Format**: JSON with organized data structure
- **Filename**: `YYYY-MM-DD HH.mm - bbetter_backup.json`
- **Auto-cleanup**: Removes backups older than 7 days if newer ones exist

#### Share to Cloud/Other Apps
- Creates temporary copy for sharing
- Supports Google Drive, email, messaging apps
- Preserves original backup file
- Auto-cleanup of temporary files

### 📥 Restore Options

#### Find My Backup Files
- Scans multiple storage locations automatically
- Shows backup files with date-first display
- Global storage path indicator (no repetitive paths)
- File size information
- One-click import for each backup

#### Import from Cloud Storage
- File picker integration for cloud services
- Supports .json files from any location
- Detailed import validation and error handling

### ⏰ Automatic Daily Backups

#### Scheduling
- **Time**: 2:00 AM daily
- **Method**: Local notifications with background execution
- **Timezone Handling**: UTC fallback if local timezone fails
- **Persistence**: Tracks last backup time across app restarts

#### Error Handling
- Timezone initialization failures
- Storage permission issues
- File system access problems
- Network/cloud storage issues

## Data Structure

### Backup File Format
```json
{
  "version": "1.0",
  "timestamp": "2025-09-12T14:30:00.000Z",
  "fasting": { /* fasting records */ },
  "menstrual_cycle": { /* cycle data */ },
  "tasks": { /* task records */ },
  "task_categories": { /* category definitions */ },
  "routines": { /* routine configurations */ },
  "habits": { /* habit tracking */ },
  "food_tracking": { /* nutrition data */ },
  "water_tracking": { /* hydration records */ },
  "notifications": { /* notification settings */ },
  "settings": { /* app configuration */ },
  "app_preferences": { /* user preferences */ }
}
```

### Data Categorization Logic
Data is intelligently categorized using key prefixes and patterns:
- `fasting_*`, `fast*`, `is_fasting` → fasting category
- `menstrual_*`, `cycle*`, `period*` → menstrual_cycle category  
- `task*`, `todo*`, `priority*` → tasks category
- `routine*`, `morning*` → routines category
- And so on...

## Storage Locations

### Android File Paths (Priority Order)
1. **Primary**: `/storage/emulated/0/Download/BBetter_Backups/`
2. **Fallback**: `/storage/emulated/0/Download/`
3. **App Private**: `/data/data/com.bb.bb_app/app_flutter/Backups/`
4. **App Root**: `/data/data/com.bb.bb_app/app_flutter/`

### File Detection Algorithm
- Scans all possible locations
- Identifies backup files by name patterns:
  - Contains "bbetter_backup"
  - Contains "backup" 
  - Contains "bbetter"
  - Files > 1KB (potential backups)

## User Interface

### Backup Screen Layout

#### Auto Backup Card (Top)
```
┌─────────────────────────────────────┐
│ 🔄 Automatic Daily Backups         │
│ ○ Auto-backup every day...         │
│ ├─────────────────────────────────────│
│ │ 🕐 Last backup: Yesterday       │
│ │ 💡 Tip: Auto backups happen... │
└─────────────────────────────────────┘
```

#### Data Summary Card
```
┌─────────────────────────────────────┐
│ 📊 Total Items: 156 items          │
│ ├─────────────────────────────────────│
│ │ ⏱️  Fasting Progress: 12 records  │
│ │ ❤️  Menstrual Cycle: 8 records   │
│ │ ✅ Tasks & Categories: 45 items   │
│ │ ⭐ Routines: 5 items             │
│ │ 💧 Water Tracking: 31 items      │
│ │ 🔔 Notifications: 15 items       │
│ │ ⚙️  Settings: 40 items           │
│ ├─────────────────────────────────────│
│ │ 💾 Backup Size: ~45 KB           │
│ │ 📅 Last Backup: Yesterday        │
└─────────────────────────────────────┘
```

#### Export Section
```
              Export
┌─────────────────────────────────────┐
│ 📥 Export to File                   │ →
│    Save backup to App Backups...   │
├─────────────────────────────────────┤
│ 🔗 Share Backup                     │ →
│    Share to Google Drive, email...  │
└─────────────────────────────────────┘
```

#### Restore Section  
```
             Restore
┌─────────────────────────────────────┐
│ 🔍 Find My Backup Files             │ →
│    Locate existing backup files...  │
├─────────────────────────────────────┤
│ ☁️  Import from Cloud Storage       │ →
│    Select backup from Google...     │
└─────────────────────────────────────┘
```

### Backup Files Dialog

#### Global Storage Info
```
📁 Storage: /storage/emulated/0/Download/BBetter_Backups
```

#### File Cards (Date-First Display)
```
┌─────────────────────────────────────┐
│ 📅 Today 14:30                      │
│ 2025-09-12 14.30 - bbetter_backup.json │
│ 💾 45 KB                            │
│ [    Import This File    ]          │
└─────────────────────────────────────┘

┌─────────────────────────────────────┐
│ 📅 Yesterday 20:24                  │
│ 2025-09-11 20.24 - bbetter_backup.json │
│ 💾 43 KB                            │
│ [    Import This File    ]          │
└─────────────────────────────────────┘
```

## Technical Implementation

### BackupService Class Methods

#### Core Operations
- `exportToFile()` - Creates backup file with timestamp
- `importFromFile(path)` - Restores data from backup file
- `getBackupInfo()` - Returns data summary and last backup time
- `getBackupLocations()` - Scans and returns available backup files

#### Automatic Backup
- `performAutoBackup()` - Executes daily backup routine
- `scheduleNightlyBackups()` - Sets up recurring notifications
- `_scheduleNextAutoBackup()` - Schedules next backup notification
- `_scheduleCloudBackupNotification()` - Weekly cloud backup reminder

#### Utility Methods
- `_getAllAppData()` - Collects all SharedPreferences data
- `_getLastBackup()` - Determines most recent backup timestamp
- `_cleanupOldBackups()` - Removes files older than 7 days
- `_setPreferenceValue()` - Safely writes preference values

### Error Handling

#### Common Issues & Solutions

**Storage Permissions**
- Requests appropriate Android permissions
- Fallback to app-private directories
- Graceful degradation for restricted access

**Timezone Errors**  
- UTC fallback when local timezone fails
- Error logging for debugging
- Continued functionality despite timezone issues

**File System Issues**
- Multiple storage location attempts
- Temporary file handling for sharing
- Automatic cleanup on failures

**Import Validation**
- JSON format verification
- Required field validation
- Partial import with error reporting

### Date & Time Handling

#### Last Backup Display Logic
```dart
// Calendar date comparison (not time-based)
final nowDate = DateTime(now.year, now.month, now.day);
final backupDate = DateTime(date.year, date.month, date.day);
final difference = nowDate.difference(backupDate).inDays;

// Results:
// difference == 0 → "Today"
// difference == 1 → "Yesterday"  
// difference > 1  → "X days ago"
```

#### Filename Timestamps
- Format: `YYYY-MM-DD HH.mm` 
- Example: `2025-09-12 14.30`
- Human-readable with proper sorting

## Configuration

### Backup Settings
- **Auto Backup**: Enabled/disabled by user
- **Notification Channels**: 
  - `auto_backup` - Daily backup notifications
  - `backup_reminders` - Weekly cloud backup reminders
- **File Retention**: 7 days for old backups
- **Backup Time**: 2:00 AM daily

### Storage Preferences
- **Primary Location**: Downloads/BBetter_Backups (user accessible)
- **Fallback Locations**: App directories (private storage)
- **File Naming**: Date-first for chronological sorting
- **Format**: Indented JSON for readability

## Security & Privacy

### Data Protection
- All backups stored locally by default
- User controls sharing/cloud upload
- No automatic cloud synchronization
- App-private storage fallbacks

### File Permissions
- Requests only necessary storage permissions
- Handles permission denials gracefully
- Uses scoped storage on Android 10+
- Respects user privacy preferences

## Troubleshooting

### Common Issues

**"Last backup: Never"**
- No backup files found in storage locations
- SharedPreferences timestamps missing
- File system access issues
- Check storage permissions

**Auto backup not working**
- Timezone initialization failed (check logs)
- Notification permissions disabled
- Battery optimization blocking background tasks
- Storage space insufficient

**Import fails**
- Invalid JSON format in backup file
- Corrupted or partial backup file
- Incompatible backup version
- Storage permission issues

**Files not found**
- Backups moved by file manager
- Storage location changed by system
- SD card removed/unmounted
- Cache cleared by system

### Debug Information

The system provides detailed logging for troubleshooting:
- File scanning operations
- Timezone fallback usage
- Storage permission status  
- Import/export success/failure
- Cleanup operations

### Performance Considerations

- **File Scanning**: Optimized to scan common locations first
- **Cleanup**: Runs only when necessary (after exports)
- **Memory Usage**: Streams large backup files
- **Background Processing**: Minimal impact on app performance

## Future Enhancements

### Potential Improvements
- **Cloud Integration**: Direct Google Drive/Dropbox sync
- **Incremental Backups**: Only changed data since last backup
- **Compression**: Reduce backup file sizes
- **Encryption**: Optional password protection for backups
- **Multiple Profiles**: Separate backup sets per user
- **Scheduled Cleanup**: User-configurable retention policies

### Version Compatibility
- **Current Version**: 1.0
- **Forward Compatibility**: Version checking for future formats
- **Migration**: Automatic upgrade of older backup formats
- **Validation**: Schema validation for data integrity

---

*This documentation covers the complete backup and restore system as implemented in the BBetter app. For technical support or feature requests, refer to the app's issue tracking system.*