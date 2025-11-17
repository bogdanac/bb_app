import 'package:intl/intl.dart';

/// Centralized date formatting utilities with Romanian format (day month year)
///
/// Examples:
/// - Short: "27 nov"
/// - Long: "27 nov 1993"
/// - Full: "27 noiembrie 1993"
/// - Time: "14:30"
class DateFormatUtils {
  // Romanian month abbreviations
  static const _monthsShort = [
    'ian', 'feb', 'mar', 'apr', 'mai', 'iun',
    'iul', 'aug', 'sep', 'oct', 'nov', 'dec'
  ];

  static const _monthsFull = [
    'ianuarie', 'februarie', 'martie', 'aprilie', 'mai', 'iunie',
    'iulie', 'august', 'septembrie', 'octombrie', 'noiembrie', 'decembrie'
  ];

  /// Format date as "27 nov" (Romanian short format)
  /// If the date is in a different year than current year, includes year: "27 nov 2026"
  static String formatShort(DateTime date) {
    final currentYear = DateTime.now().year;
    if (date.year != currentYear) {
      return '${date.day} ${_monthsShort[date.month - 1]} ${date.year}';
    }
    return '${date.day} ${_monthsShort[date.month - 1]}';
  }

  /// Format date as "27 nov 1993" (Romanian long format)
  static String formatLong(DateTime date) {
    return '${date.day} ${_monthsShort[date.month - 1]} ${date.year}';
  }

  /// Format date as "27 noiembrie 1993" (Romanian full format with full month name)
  static String formatFull(DateTime date) {
    return '${date.day} ${_monthsFull[date.month - 1]} ${date.year}';
  }

  /// Format date as "27 noiembrie" (Romanian short with full month name, no year)
  static String formatShortWithFullMonth(DateTime date) {
    return '${date.day} ${_monthsFull[date.month - 1]}';
  }

  /// Format time as "14:30" (24-hour format)
  static String formatTime24(DateTime time) {
    return DateFormat('HH:mm').format(time);
  }

  /// Format time as "2:30 PM" (12-hour format with AM/PM)
  static String formatTime12(DateTime time) {
    return DateFormat('h:mm a').format(time);
  }

  /// Format date and time as "27 nov 1993, 14:30"
  static String formatDateTime(DateTime dateTime) {
    return '${formatLong(dateTime)}, ${formatTime24(dateTime)}';
  }

  /// Format date range as "27 nov - 3 dec"
  static String formatRange(DateTime start, DateTime end) {
    if (start.year == end.year && start.month == end.month) {
      // Same month: "27 - 30 nov"
      return '${start.day} - ${end.day} ${_monthsShort[end.month - 1]}';
    } else if (start.year == end.year) {
      // Same year: "27 nov - 3 dec"
      return '${formatShort(start)} - ${formatShort(end)}';
    } else {
      // Different years: "27 nov 1993 - 3 ian 1994"
      return '${formatLong(start)} - ${formatLong(end)}';
    }
  }

  /// Format relative date: "today", "yesterday", "tomorrow", or date
  static String formatRelative(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final compareDate = DateTime(date.year, date.month, date.day);

    final difference = compareDate.difference(today).inDays;

    if (difference == 0) {
      return 'azi'; // today
    } else if (difference == -1) {
      return 'ieri'; // yesterday
    } else if (difference == 1) {
      return 'mâine'; // tomorrow
    } else if (difference > 1 && difference <= 7) {
      return 'în $difference zile'; // in X days
    } else if (difference < -1 && difference >= -7) {
      return 'acum ${-difference} zile'; // X days ago
    } else {
      return formatShort(date);
    }
  }

  /// Format as "27/11/1993" (numeric format)
  static String formatNumeric(DateTime date) {
    return DateFormat('dd/MM/yyyy').format(date);
  }

  /// Format as "27/11" (short numeric format, no year)
  static String formatShortNumeric(DateTime date) {
    return DateFormat('dd/MM').format(date);
  }

  /// Strip time from DateTime, returning date at midnight
  static DateTime stripTime(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  /// Check if two dates are the same day (ignoring time)
  static bool isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
           date1.month == date2.month &&
           date1.day == date2.day;
  }

  /// Get day of week in Romanian: "luni", "marți", etc.
  static String getDayOfWeek(DateTime date) {
    const days = ['luni', 'marți', 'miercuri', 'joi', 'vineri', 'sâmbătă', 'duminică'];
    return days[date.weekday - 1];
  }

  /// Format as "luni, 27 nov" (day of week + date)
  static String formatWithDayOfWeek(DateTime date) {
    return '${getDayOfWeek(date)}, ${formatShort(date)}';
  }

  /// Format duration as "2h 30m"
  static String formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);

    if (hours > 0 && minutes > 0) {
      return '${hours}h ${minutes}m';
    } else if (hours > 0) {
      return '${hours}h';
    } else {
      return '${minutes}m';
    }
  }

  /// Format month and year as "noiembrie 1993"
  static String formatMonthYear(DateTime date) {
    return '${_monthsFull[date.month - 1]} ${date.year}';
  }

  /// Format as "luni, 27 noiembrie" (full date with day of week and full month)
  static String formatFullDate(DateTime date) {
    return '${getDayOfWeek(date)}, ${date.day} ${_monthsFull[date.month - 1]}';
  }

  /// Format as ISO 8601 string for storage
  static String formatISO(DateTime date) {
    return date.toIso8601String();
  }

  /// Parse ISO 8601 string
  static DateTime? parseISO(String? isoString) {
    if (isoString == null) return null;
    try {
      return DateTime.parse(isoString);
    } catch (e) {
      return null;
    }
  }
}
