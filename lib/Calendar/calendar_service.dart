import 'package:device_calendar/device_calendar.dart';
import 'package:flutter/foundation.dart';

class CalendarService {
  static final CalendarService _instance = CalendarService._internal();
  factory CalendarService() => _instance;
  CalendarService._internal();

  DeviceCalendarPlugin _deviceCalendarPlugin = DeviceCalendarPlugin();

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
        print('Error checking calendar permission: $e');
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
        throw Exception('Failed to get calendar permission. Please try again or enable it manually in Settings.');
      }
      
      return success;
    } catch (e) {
      if (kDebugMode) {
        print('Error requesting calendar permission: $e');
      }
      rethrow; // Let the UI handle the specific error message
    }
  }

  // Get today's events from all calendars
  Future<List<Event>> getTodaysEvents() async {
    try {
      final hasPermission = await hasCalendarPermission();
      if (!hasPermission) {
        if (kDebugMode) {
          print('Calendar permission not granted');
        }
        return [];
      }

      final calendarsResult = await _deviceCalendarPlugin.retrieveCalendars();
      if (!calendarsResult.isSuccess || calendarsResult.data == null) {
        if (kDebugMode) {
          print('Failed to retrieve calendars');
        }
        return [];
      }

      final calendars = calendarsResult.data!;
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
          }
        } catch (e) {
          if (kDebugMode) {
            print('Error retrieving events from calendar ${calendar.name}: $e');
          }
        }
      }

      // Sort events by start time
      allEvents.sort((a, b) {
        if (a.start == null && b.start == null) return 0;
        if (a.start == null) return 1;
        if (b.start == null) return -1;
        return a.start!.compareTo(b.start!);
      });

      if (kDebugMode) {
        print('Found ${allEvents.length} events for today');
      }

      return allEvents;
    } catch (e) {
      if (kDebugMode) {
        print('Error getting today\'s events: $e');
      }
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
}