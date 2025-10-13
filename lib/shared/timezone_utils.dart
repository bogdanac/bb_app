import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/foundation.dart';

/// Shared timezone utilities to handle timezone conversions consistently across the app.
///
/// This utility addresses the timezone bugs that occur when mixing tz.local and tz.UTC
/// throughout the codebase. All timezone operations should use these utilities.
class TimezoneUtils {

  /// Creates a timezone-aware DateTime with proper error handling.
  ///
  /// Uses the same pattern from backup_service.dart that fixed the backup date timezone bug.
  /// Always tries tz.local first, falls back to UTC on error.
  ///
  /// [dateTime] - The DateTime to convert to timezone-aware
  /// [debugContext] - Optional context for debugging (e.g., "water_reminder", "notification")
  static tz.TZDateTime createTZDateTime(DateTime dateTime, {String? debugContext}) {
    tz.TZDateTime scheduledDate;
    try {
      scheduledDate = tz.TZDateTime.from(dateTime, tz.local);
    } catch (e) {
      if (kDebugMode) {
        final context = debugContext ?? 'unknown';
        print('$context timezone error, using UTC fallback: $e');
      }
      scheduledDate = tz.TZDateTime.from(dateTime.toUtc(), tz.UTC);
    }
    return scheduledDate;
  }

  /// Creates a timezone-aware DateTime from current time with proper error handling.
  ///
  /// [debugContext] - Optional context for debugging
  static tz.TZDateTime now({String? debugContext}) {
    return createTZDateTime(DateTime.now(), debugContext: debugContext);
  }

  /// Gets the current timezone location with error handling.
  ///
  /// Returns tz.local if available, tz.UTC as fallback.
  /// [debugContext] - Optional context for debugging
  static tz.Location getLocation({String? debugContext}) {
    try {
      return tz.local;
    } catch (e) {
      if (kDebugMode) {
        final context = debugContext ?? 'unknown';
        print('$context timezone location error, using UTC: $e');
      }
      return tz.UTC;
    }
  }

  /// Creates a timezone-aware DateTime with explicit timezone preference.
  ///
  /// [dateTime] - The DateTime to convert
  /// [preferLocal] - If true, tries tz.local first (default). If false, uses tz.UTC
  /// [debugContext] - Optional context for debugging
  static tz.TZDateTime createTZDateTimeWithPreference(
    DateTime dateTime, {
    bool preferLocal = true,
    String? debugContext,
  }) {
    if (preferLocal) {
      return createTZDateTime(dateTime, debugContext: debugContext);
    } else {
      // Force UTC usage (for compatibility with legacy code)
      return tz.TZDateTime.from(dateTime.toUtc(), tz.UTC);
    }
  }

  /// Creates a timezone-aware DateTime for notifications.
  ///
  /// Specifically designed for notification scheduling where timing precision matters.
  /// [dateTime] - The DateTime to schedule notification for
  static tz.TZDateTime forNotification(DateTime dateTime) {
    return createTZDateTime(dateTime, debugContext: 'notification');
  }

  /// Creates a timezone-aware DateTime for water reminders.
  ///
  /// [dateTime] - The DateTime to schedule water reminder for
  static tz.TZDateTime forWaterReminder(DateTime dateTime) {
    return createTZDateTime(dateTime, debugContext: 'water_reminder');
  }

  /// Creates a timezone-aware DateTime for routine reminders.
  ///
  /// [dateTime] - The DateTime to schedule routine reminder for
  static tz.TZDateTime forRoutineReminder(DateTime dateTime) {
    return createTZDateTime(dateTime, debugContext: 'routine_reminder');
  }

  /// Creates a timezone-aware DateTime for backup reminders.
  ///
  /// [dateTime] - The DateTime to schedule backup reminder for
  static tz.TZDateTime forBackupReminder(DateTime dateTime) {
    return createTZDateTime(dateTime, debugContext: 'backup_reminder');
  }

  /// Formats a date string for storage that is timezone-safe.
  ///
  /// Uses the local timezone to generate consistent date strings.
  /// This prevents issues where dates change based on UTC vs local time.
  static String formatDateForStorage([DateTime? dateTime]) {
    final date = dateTime ?? DateTime.now();
    // Always use local time for date formatting to avoid timezone shifts
    return '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// Gets the effective date for app purposes (after 2 AM rule).
  ///
  /// Used by routines and other features that consider "yesterday" until 2 AM.
  /// This ensures consistency across the app for date-based logic.
  static String getEffectiveDateString() {
    final effectiveDateTime = getEffectiveDateTime();
    return formatDateForStorage(effectiveDateTime);
  }

  /// Gets the effective DateTime for app purposes (after 2 AM rule).
  ///
  /// Returns the DateTime that should be considered as "today" based on the 2 AM rule.
  static DateTime getEffectiveDateTime() {
    final now = DateTime.now();

    // If it's before 2 AM, consider it as the previous day
    if (now.hour < 2) {
      return now.subtract(const Duration(days: 1));
    }

    return now;
  }

  /// Gets today's date string in a timezone-safe way.
  ///
  /// Always uses local time to avoid timezone-related date shifts.
  static String getTodayString() {
    return formatDateForStorage();
  }
}