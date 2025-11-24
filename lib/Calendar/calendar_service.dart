import 'package:device_calendar/device_calendar.dart';
import '../shared/error_logger.dart';

class CalendarService {
  static final CalendarService _instance = CalendarService._internal();
  factory CalendarService() => _instance;
  CalendarService._internal();

  final DeviceCalendarPlugin _deviceCalendarPlugin = DeviceCalendarPlugin();

  // Check if calendar permission is granted
  Future<bool> hasCalendarPermission() async {
    try {
      await ErrorLogger.logError(
        source: 'CalendarService.hasCalendarPermission',
        error: 'Checking calendar permissions...',
        stackTrace: '',
      );

      final permissionsGranted = await _deviceCalendarPlugin.hasPermissions();
      final hasPermission = permissionsGranted.isSuccess && (permissionsGranted.data ?? false);

      await ErrorLogger.logError(
        source: 'CalendarService.hasCalendarPermission',
        error: 'Calendar permission check result: $hasPermission, Permissions result: ${permissionsGranted.data}, Is success: ${permissionsGranted.isSuccess}${permissionsGranted.errors.isNotEmpty ? ", Permission errors: ${permissionsGranted.errors}" : ""}',
        stackTrace: '',
      );

      return hasPermission;
    } catch (e, stackTrace) {
      await ErrorLogger.logError(
        source: 'CalendarService.hasCalendarPermission',
        error: 'Error checking calendar permission: $e',
        stackTrace: stackTrace.toString(),
      );
      return false;
    }
  }

  // Request calendar permission
  Future<bool> requestCalendarPermission() async {
    try {
      await ErrorLogger.logError(
        source: 'CalendarService.requestCalendarPermission',
        error: 'Requesting calendar permission...',
        stackTrace: '',
      );

      final permissionsGranted = await _deviceCalendarPlugin.requestPermissions();
      final success = permissionsGranted.isSuccess && (permissionsGranted.data ?? false);

      await ErrorLogger.logError(
        source: 'CalendarService.requestCalendarPermission',
        error: 'Permission request result: $success, Request data: ${permissionsGranted.data}, Is success: ${permissionsGranted.isSuccess}${permissionsGranted.errors.isNotEmpty ? ", Request errors: ${permissionsGranted.errors}" : ""}',
        stackTrace: '',
      );
      
      // If permission was denied, throw a user-friendly exception
      if (!success) {
        if (permissionsGranted.errors.isNotEmpty) {
          final errorMsg = permissionsGranted.errors.first.errorMessage;
          if (errorMsg.contains('denied') || errorMsg.contains('not allowed')) {
            throw Exception('Calendar permission was denied. Please enable it manually in Settings.');
          }
        }
        throw Exception('ERROR get calendar permission. Please try again or enable it manually in Settings.');
      }

      return success;
    } catch (e, stackTrace) {
      await ErrorLogger.logError(
        source: 'CalendarService.requestCalendarPermission',
        error: 'Error requesting calendar permission: $e',
        stackTrace: stackTrace.toString(),
      );
      rethrow; // Let the UI handle the specific error message
    }
  }

  // Get today's events from all calendars
  Future<List<Event>> getTodaysEvents() async {
    try {
      // Request permissions first - this ensures the plugin has proper access
      // Even if Android settings show permission granted, the plugin may need this call
      final permResult = await _deviceCalendarPlugin.requestPermissions();
      if (!permResult.isSuccess || !(permResult.data ?? false)) {
        await ErrorLogger.logError(
          source: 'CalendarService.getTodaysEvents',
          error: 'Calendar permission not granted via plugin',
          context: {
            'isSuccess': permResult.isSuccess,
            'data': permResult.data,
            'errors': permResult.errors.map((e) => e.errorMessage).toList(),
          },
        );
        return [];
      }

      final calendarsResult = await _deviceCalendarPlugin.retrieveCalendars();
      if (!calendarsResult.isSuccess || calendarsResult.data == null) {
        await ErrorLogger.logError(
          source: 'CalendarService.getTodaysEvents',
          error: 'Failed to retrieve calendars',
          context: {
            'isSuccess': calendarsResult.isSuccess,
            'hasData': calendarsResult.data != null,
            'errors': calendarsResult.errors.map((e) => e.errorMessage).toList(),
          },
        );
        return [];
      }

      final calendars = calendarsResult.data!;

      // Log if no calendars found
      if (calendars.isEmpty) {
        await ErrorLogger.logError(
          source: 'CalendarService.getTodaysEvents',
          error: 'No calendars found on device',
          context: {
            'calendarCount': 0,
          },
        );
        return [];
      }

      final today = DateTime.now();
      // Use local DateTime for calendar queries
      final startOfDay = DateTime(today.year, today.month, today.day, 0, 0, 0);
      final endOfDay = DateTime(today.year, today.month, today.day, 23, 59, 59);

      List<Event> allEvents = [];

      for (final calendar in calendars) {
        // Skip calendars without an ID
        if (calendar.id == null) {
          await ErrorLogger.logError(
            source: 'CalendarService.getTodaysEvents',
            error: 'Calendar has null ID, skipping',
            context: {
              'calendarName': calendar.name ?? 'Unknown',
              'accountName': calendar.accountName,
              'accountType': calendar.accountType,
            },
          );
          continue;
        }

        try {
          final eventsResult = await _deviceCalendarPlugin.retrieveEvents(
            calendar.id!,
            RetrieveEventsParams(
              startDate: startOfDay,
              endDate: endOfDay,
            ),
          );

          if (eventsResult.isSuccess && eventsResult.data != null) {
            final eventCount = eventsResult.data!.length;
            allEvents.addAll(eventsResult.data!);
            // Log each calendar's result for debugging
            await ErrorLogger.logError(
              source: 'CalendarService.getTodaysEvents',
              error: 'Calendar query result',
              context: {
                'calendarName': calendar.name ?? 'Unknown',
                'calendarId': calendar.id,
                'eventsFound': eventCount,
                'accountName': calendar.accountName,
                'isReadOnly': calendar.isReadOnly,
              },
            );
          } else {
            await ErrorLogger.logError(
              source: 'CalendarService.getTodaysEvents',
              error: 'Failed to retrieve events from calendar',
              context: {
                'calendarName': calendar.name ?? 'Unknown',
                'calendarId': calendar.id,
                'isSuccess': eventsResult.isSuccess,
                'hasData': eventsResult.data != null,
                'errors': eventsResult.errors.map((e) => e.errorMessage).toList(),
              },
            );
          }
        } catch (e, stackTrace) {
          await ErrorLogger.logError(
            source: 'CalendarService.getTodaysEvents',
            error: 'Exception retrieving events from calendar: $e',
            stackTrace: stackTrace.toString(),
            context: {
              'calendarName': calendar.name ?? 'Unknown',
              'calendarId': calendar.id,
            },
          );
        }
      }

      // Filter out past events (events that have already ended)
      final now = DateTime.now();
      final currentAndFutureEvents = allEvents.where((event) {
        // If event has no end time, check if start time is in the future (or happening now)
        if (event.end == null) {
          if (event.start == null) return true; // Keep all-day events without times
          return event.start!.isAfter(now) || event.start!.isAtSameMomentAs(now);
        }
        
        // If event has end time, check if it hasn't ended yet
        return event.end!.isAfter(now);
      }).toList();

      // Sort remaining events by start time
      currentAndFutureEvents.sort((a, b) {
        if (a.start == null && b.start == null) return 0;
        if (a.start == null) return 1;
        if (b.start == null) return -1;
        return a.start!.compareTo(b.start!);
      });

      // Log the results for debugging
      await ErrorLogger.logError(
        source: 'CalendarService.getTodaysEvents',
        error: 'Calendar fetch completed',
        context: {
          'calendarsChecked': calendars.length,
          'calendarNames': calendars.map((c) => c.name ?? 'Unknown').toList(),
          'totalEventsFound': allEvents.length,
          'afterFiltering': currentAndFutureEvents.length,
          'startOfDay': startOfDay.toIso8601String(),
          'endOfDay': endOfDay.toIso8601String(),
          'currentTime': now.toIso8601String(),
        },
      );

      return currentAndFutureEvents;
    } catch (e, stackTrace) {
      await ErrorLogger.logError(
        source: 'CalendarService.getTodaysEvents',
        error: 'Exception in getTodaysEvents: $e',
        stackTrace: stackTrace.toString(),
        context: {
          'currentTime': DateTime.now().toIso8601String(),
        },
      );
      return [];
    }
  }

  // Format time for display
  String formatEventTime(DateTime? dateTime) {
    if (dateTime == null) return '';
    
    final hour = dateTime.hour;
    final minute = dateTime.minute.toString().padLeft(2, '0');
    
    if (hour == 0 && minute == '00') {
      return 'All day';
    }
    
    return '${hour.toString().padLeft(2, '0')}:$minute';
  }

  // Get event duration text
  String getEventDuration(Event event) {
    if (event.start == null) return '';
    
    final startTime = formatEventTime(event.start);
    
    if (event.end == null) return startTime;
    
    final endTime = formatEventTime(event.end);
    
    if (startTime == 'All day') return 'All day';
    
    return '$startTime - $endTime';
  }

  // Check if an event is currently happening
  bool isEventActive(Event event) {
    final now = DateTime.now();
    
    if (event.start == null) return false;
    
    // Event has started
    final hasStarted = event.start!.isBefore(now) || event.start!.isAtSameMomentAs(now);
    
    // If no end time, consider it active if it started today
    if (event.end == null) {
      final today = DateTime.now();
      final startOfToday = DateTime(today.year, today.month, today.day);
      return hasStarted && event.start!.isAfter(startOfToday);
    }
    
    // Event hasn't ended yet
    final hasNotEnded = event.end!.isAfter(now);
    
    return hasStarted && hasNotEnded;
  }
}