import 'package:device_calendar/device_calendar.dart';
import 'package:flutter/foundation.dart';
import '../shared/error_logger.dart';

class CalendarService {
  static final CalendarService _instance = CalendarService._internal();
  factory CalendarService() => _instance;
  CalendarService._internal();

  final DeviceCalendarPlugin _deviceCalendarPlugin = DeviceCalendarPlugin();

  // Check if calendar permission is granted
  Future<bool> hasCalendarPermission() async {
    try {
      if (kDebugMode) {
        print('Checking calendar permissions...');
      }
      
      final permissionsGranted = await _deviceCalendarPlugin.hasPermissions();
      final hasPermission = permissionsGranted.isSuccess && (permissionsGranted.data ?? false);
      
      if (kDebugMode) {
        print('Calendar permission check result: $hasPermission');
        print('Permissions result: ${permissionsGranted.data}');
        print('Is success: ${permissionsGranted.isSuccess}');
        if (permissionsGranted.errors.isNotEmpty) {
          print('Permission errors: ${permissionsGranted.errors}');
        }
      }
      
      return hasPermission;
    } catch (e) {
      if (kDebugMode) {
        print('ERROR checking calendar permission: $e');
      }
      return false;
    }
  }

  // Request calendar permission
  Future<bool> requestCalendarPermission() async {
    try {
      if (kDebugMode) {
        print('Requesting calendar permission...');
      }
      
      final permissionsGranted = await _deviceCalendarPlugin.requestPermissions();
      final success = permissionsGranted.isSuccess && (permissionsGranted.data ?? false);
      
      if (kDebugMode) {
        print('Permission request result: $success');
        print('Request data: ${permissionsGranted.data}');
        print('Is success: ${permissionsGranted.isSuccess}');
        if (permissionsGranted.errors.isNotEmpty) {
          print('Request errors: ${permissionsGranted.errors}');
        }
      }
      
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
    } catch (e) {
      if (kDebugMode) {
        print('ERROR requesting calendar permission: $e');
      }
      rethrow; // Let the UI handle the specific error message
    }
  }

  // Get today's events from all calendars
  Future<List<Event>> getTodaysEvents() async {
    try {
      // Try to retrieve calendars directly - if permission is truly missing, this will fail
      // This is more reliable than hasPermissions() which can give false negatives
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
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      List<Event> allEvents = [];

      for (final calendar in calendars) {
        try {
          final eventsResult = await _deviceCalendarPlugin.retrieveEvents(
            calendar.id!,
            RetrieveEventsParams(
              startDate: startOfDay,
              endDate: endOfDay,
            ),
          );

          if (eventsResult.isSuccess && eventsResult.data != null) {
            allEvents.addAll(eventsResult.data!);
          } else {
            await ErrorLogger.logError(
              source: 'CalendarService.getTodaysEvents',
              error: 'Failed to retrieve events from calendar',
              context: {
                'calendarName': calendar.name,
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
            error: 'Exception retrieving events from calendar ${calendar.name}: $e',
            stackTrace: stackTrace.toString(),
            context: {
              'calendarName': calendar.name,
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
          'calendarNames': calendars.map((c) => c.name).toList(),
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