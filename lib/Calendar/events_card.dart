import 'package:flutter/material.dart';
import 'package:device_calendar/device_calendar.dart';
import 'package:permission_handler/permission_handler.dart';
import '../theme/app_colors.dart';
import 'calendar_service.dart';

// CALENDAR EVENTS CARD
class CalendarEventsCard extends StatefulWidget {
  const CalendarEventsCard({super.key});

  @override
  State<CalendarEventsCard> createState() => _CalendarEventsCardState();
}

class _CalendarEventsCardState extends State<CalendarEventsCard> {
  final CalendarService _calendarService = CalendarService();
  List<Event> _events = [];
  bool _isLoading = true;
  bool _hasPermission = false;
  String _errorMessage = '';
  
  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  // Public method that can be called from parent widgets
  Future<void> refreshEvents() async {
    await _loadEvents();
  }

  Future<void> _loadEvents() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      bool hasPermission = await _calendarService.hasCalendarPermission();
      
      if (!hasPermission) {
        setState(() {
          _hasPermission = false;
          _isLoading = false;
        });
        return;
      }

      final events = await _calendarService.getTodaysEvents();
      
      if (mounted) {
        setState(() {
          _events = events;
          _hasPermission = true;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error loading events: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _requestPermission() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    
    try {
      final granted = await _calendarService.requestCalendarPermission();
      if (granted) {
        // Permission granted, load events
        await _loadEvents();
      } else {
        setState(() {
          _errorMessage = 'Permission not granted. Please try again or enable manually in Settings.';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        // Clean up the error message for the user
        String cleanError = e.toString().replaceFirst('Exception: ', '');
        _errorMessage = cleanError;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Hide the entire card if no events are available and not loading/error states
    if (!_isLoading && _hasPermission && _errorMessage.isEmpty && _events.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: AppColors.lightPink.withValues(alpha: 0.15),
        ),
        child: Stack(
          children: [
            // Main content with padding
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_isLoading)
                const Center(
                  child: CircularProgressIndicator(),
                )
              else if (!_hasPermission)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Calendar access needed to show your events',
                      style: TextStyle(fontSize: 16, color: AppColors.white70),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _requestPermission,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.pink,
                              foregroundColor: AppColors.white,
                            ),
                            child: const Text('Grant Calendar Access'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: () async {
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Calendar Permission'),
                                content: const Text(
                                  'To view your calendar events:\n\n'
                                  '1. Go to Settings > Apps > bbApp > Permissions\n'
                                  '2. Enable Calendar permission\n'
                                  '3. Return to the app and tap refresh',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () async {
                                      Navigator.pop(context);
                                      // Try to open app settings
                                      try {
                                        await Permission.calendarFullAccess.request();
                                      } catch (e) {
                                        // If that doesn't work, just close dialog
                                      }
                                    },
                                    child: const Text('Open Settings'),
                                  ),
                                ],
                              ),
                            );
                          },
                          icon: const Icon(Icons.help_outline),
                          color: AppColors.pink,
                          tooltip: 'Help',
                        ),
                      ],
                    ),
                  ],
                )
              else if (_errorMessage.isNotEmpty)
                Text(
                  _errorMessage,
                  style: const TextStyle(fontSize: 16, color: AppColors.error),
                )
              else if (_events.isEmpty)
                Container(
                  width: double.infinity,
                  alignment: Alignment.centerLeft,
                  child: const Text(
                    'No events scheduled for today',
                    style: TextStyle(fontSize: 16, color: AppColors.white70),
                  ),
                )
              else
                Column(
                  children: _events.take(4).map((event) {
                    int index = _events.take(4).toList().indexOf(event);
                    bool isLast = index == _events.take(4).length - 1;
                    return _buildEventItem(event, isLast: isLast);
                  }).toList(),
                ),
              
              if (_events.length > 4)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '... and ${_events.length - 4} more events',
                    style: const TextStyle(fontSize: 12, color: AppColors.white60),
                  ),
                ),
              ],
            ),
          ),
            
          ],
        ),
      ),
    );
  }

  Color _getEventColor(Event event) {
    final colors = [
      AppColors.lightRed,
      AppColors.lightYellow,
      AppColors.lightOrange,
      AppColors.lightCoral,
      AppColors.lightPurple,
      AppColors.lightPink,
      AppColors.lightGreen,
    ];
    
    final hash = (event.title?.hashCode ?? 0) + (event.eventId?.hashCode ?? 0);
    return colors[hash.abs() % colors.length];
  }

  Widget _buildEventItem(Event event, {bool isLast = false}) {
    final isActive = _calendarService.isEventActive(event);
    
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 4,
            height: 40,
            decoration: BoxDecoration(
              color: isActive ? AppColors.successGreen : _getEventColor(event),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        event.title ?? 'Untitled Event',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.white,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isActive) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.successGreen,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'NOW',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.white,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      size: 14,
                      color: isActive ? AppColors.successGreen : AppColors.white70,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _calendarService.getEventDuration(event),
                      style: TextStyle(
                        fontSize: 14,
                        color: isActive ? AppColors.successGreen : AppColors.white70,
                      ),
                    ),
                  ],
                ),
                if (event.location != null && event.location!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on,
                        size: 14,
                        color: isActive ? AppColors.successGreen : AppColors.white70,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          event.location!,
                          style: TextStyle(
                            fontSize: 14,
                            color: isActive ? AppColors.successGreen : AppColors.white70,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}