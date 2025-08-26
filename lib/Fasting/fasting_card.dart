// fasting_card.dart - Actualizat cu sincronizare
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:convert';
import 'fasting_notifier.dart';
import '../Notifications/notification_service.dart';

class FastingCard extends StatefulWidget {
  final VoidCallback? onHiddenForToday;
  
  const FastingCard({super.key, this.onHiddenForToday});

  @override
  State<FastingCard> createState() => _FastingCardState();
}

class _FastingCardState extends State<FastingCard> {
  bool isFasting = false;
  DateTime? fastingStartTime;
  DateTime? fastingEndTime;
  Duration fastingDuration = Duration.zero;
  Timer? _timer;
  String currentFastType = '';
  final FastingNotifier _notifier = FastingNotifier();
  final NotificationService _notificationService = NotificationService();

  @override
  void initState() {
    super.initState();
    _loadFastingState();
    _notifier.addListener(_onFastingStateChanged);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _notifier.removeListener(_onFastingStateChanged);
    super.dispose();
  }

  void _onFastingStateChanged() {
    _loadFastingState();
  }

  // Load fasting state from SharedPreferences (sincronizat cu FastingScreen)
  Future<void> _loadFastingState() async {
    final prefs = await SharedPreferences.getInstance();

    // Folosim aceleași chei ca în FastingScreen pentru sincronizare perfectă
    final isFastingStored = prefs.getBool('is_fasting') ?? false;
    final startTimeString = prefs.getString('current_fast_start');
    final endTimeString = prefs.getString('current_fast_end');
    final fastType = prefs.getString('current_fast_type') ?? '';

    if (startTimeString != null && isFastingStored) {
      final startTime = DateTime.parse(startTimeString);
      final endTime = endTimeString != null ? DateTime.parse(endTimeString) : null;
      final now = DateTime.now();

      // Verifică dacă postul e încă activ
      if (endTime != null && now.isBefore(endTime)) {
        setState(() {
          isFasting = true;
          fastingStartTime = startTime;
          fastingEndTime = endTime;
          currentFastType = fastType;
          fastingDuration = now.difference(startTime);
        });
        _startTimer();
      }
    } else {
      setState(() {
        isFasting = false;
        fastingStartTime = null;
        fastingEndTime = null;
        currentFastType = '';
        fastingDuration = Duration.zero;
      });
      _timer?.cancel();
    }
  }

  // Save fasting state (sincronizat cu FastingScreen)
  Future<void> _saveFastingState() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setBool('is_fasting', isFasting);

    if (isFasting && fastingStartTime != null && fastingEndTime != null) {
      await prefs.setString('current_fast_start', fastingStartTime!.toIso8601String());
      await prefs.setString('current_fast_end', fastingEndTime!.toIso8601String());
      await prefs.setString('current_fast_type', currentFastType);
    } else {
      await prefs.remove('current_fast_start');
      await prefs.remove('current_fast_end');
      await prefs.remove('current_fast_type');
    }

    // Notifică toate componentele că starea s-a schimbat
    _notifier.notifyFastingStateChanged();
  }

  // Determină tipul de post recomandat (sincronizat cu logica din FastingScreen)
  String _getRecommendedFastType() {
    final now = DateTime.now();
    final isFriday = now.weekday == 5;
    final is25th = now.day == 25;

    // Smart scheduling: combine Friday and 25th fasts when close
    if (isFriday || is25th) {
      return _getSmartFastRecommendation(now, isFriday, is25th);
    }

    return '';
  }

  // Smart scheduling logic to avoid double fasts when Friday and 25th are close
  String _getSmartFastRecommendation(DateTime now, bool isFriday, bool is25th) {
    // If today is the 25th, check if there was a recent Friday or upcoming Friday
    if (is25th) {
      final month = now.month;
      String longerFastType;
      if (month == 1 || month == 9) {
        longerFastType = '3-days';
      } else if (month % 3 == 1) {
        longerFastType = '48h';
      } else {
        longerFastType = '36h';
      }
      
      // Check if Friday was within the last 4-6 days or will be within next 4-6 days
      final daysUntilFriday = (5 - now.weekday + 7) % 7; // Days until next Friday (0 if today is Friday)
      final daysSinceLastFriday = now.weekday >= 5 ? now.weekday - 5 : now.weekday + 2; // Days since last Friday
      
      // If Friday is close (within 6 days either way), do the longer fast today
      if (daysSinceLastFriday <= 6 || daysUntilFriday <= 6) {
        return longerFastType; // Do the longer fast on the 25th
      }
      
      return longerFastType;
    }
    
    // If today is Friday, check if 25th is close
    if (isFriday) {
      final daysUntil25th = 25 - now.day;
      
      // If 25th is within 4-6 days (past or future), do the longer fast on Friday instead
      if ((daysUntil25th >= 0 && daysUntil25th <= 6) || (now.day < 25 && (25 - now.day) <= 6)) {
        final month = daysUntil25th >= 0 ? now.month : (now.month == 1 ? 12 : now.month - 1);
        
        // Use the appropriate longer fast type
        if (month == 1 || month == 9) {
          return '3-days';
        } else if (month % 3 == 1) {
          return '48h';
        } else {
          return '36h';
        }
      }
      
      return '24h'; // Normal Friday fast
    }
    
    return '';
  }

  Duration _getFastDuration(String fastType) {
    switch (fastType) {
      case '24h':
        return const Duration(hours: 24);
      case '36h':
        return const Duration(hours: 36);
      case '48h':
        return const Duration(hours: 48);
      case '3-days':
        return const Duration(days: 3);
      default:
        return const Duration(hours: 24);
    }
  }

  // Start fasting timer
  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (fastingStartTime != null && fastingEndTime != null) {
        final now = DateTime.now();
        final newDuration = now.difference(fastingStartTime!);

        setState(() {
          fastingDuration = newDuration;
        });

        // Update notification every minute to avoid too frequent updates
        if (newDuration.inSeconds % 60 == 0) {
          _updateFastingNotification();
        }
      }
    });
  }

  void _updateFastingNotification() {
    if (isFasting && fastingStartTime != null && fastingEndTime != null) {
      final totalDuration = fastingEndTime!.difference(fastingStartTime!);
      final phaseInfo = _getFastingPhaseInfo();
      _notificationService.showFastingProgressNotification(
        fastType: currentFastType,
        elapsedTime: fastingDuration,
        totalDuration: totalDuration,
        currentPhase: phaseInfo['phase'],
      );
    }
  }

  // Start fasting (compatible cu FastingScreen)
  void _startFast() {
    HapticFeedback.mediumImpact();

    final recommendedType = _getRecommendedFastType();
    if (recommendedType.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No fast scheduled for today'),
          backgroundColor: AppColors.orange,
        ),
      );
      return;
    }

    final now = DateTime.now();
    final duration = _getFastDuration(recommendedType);

    setState(() {
      isFasting = true;
      fastingStartTime = now;
      fastingEndTime = now.add(duration);
      currentFastType = recommendedType;
      fastingDuration = Duration.zero;
    });

    _saveFastingState();
    _startTimer();

    // Show initial notification
    _updateFastingNotification();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('🚀 $recommendedType started!'),
        backgroundColor: AppColors.successGreen, // Green for success
      ),
    );
  }


  // Stop fasting (compatible cu FastingScreen)
  void _stopFast() {
    HapticFeedback.mediumImpact();
    _timer?.cancel();

    // Salvează în istoric înainte de oprire
    _saveToHistory();

    // Cancel progress notification and show completion notification
    final actualDuration = DateTime.now().difference(fastingStartTime!);
    _notificationService.cancelFastingProgressNotification();
    _notificationService.showFastingCompletedNotification(
      fastType: currentFastType,
      actualDuration: actualDuration,
    );

    setState(() {
      isFasting = false;
      fastingStartTime = null;
      fastingEndTime = null;
      currentFastType = '';
      fastingDuration = Duration.zero;
    });

    _saveFastingState();
  }

  // Save to history (compatible cu FastingScreen)
  Future<void> _saveToHistory() async {
    if (fastingStartTime == null) return;

    final prefs = await SharedPreferences.getInstance();
    final historyStr = prefs.getStringList('fasting_history') ?? [];

    final endTime = DateTime.now();
    final actualDuration = endTime.difference(fastingStartTime!);
    final plannedDuration = fastingEndTime?.difference(fastingStartTime!) ?? actualDuration;

    final fastEntry = {
      'type': currentFastType,
      'startTime': fastingStartTime!.toIso8601String(),
      'endTime': endTime.toIso8601String(),
      'plannedDuration': plannedDuration.inMinutes,
      'actualDuration': actualDuration.inMinutes,
    };

    historyStr.add(jsonEncode(fastEntry));
    await prefs.setStringList('fasting_history', historyStr);
  }

  // Format duration to readable string
  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    return '${hours}h ${minutes}m';
  }

  // Calculate progress percentage
  double _getProgress() {
    if (!isFasting || fastingStartTime == null || fastingEndTime == null) return 0.0;

    final totalDuration = fastingEndTime!.difference(fastingStartTime!);
    final currentDuration = DateTime.now().difference(fastingStartTime!);

    return (currentDuration.inMinutes / totalDuration.inMinutes).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final recommendedFast = _getRecommendedFastType();

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: isFasting 
              ? AppColors.orange.withValues(alpha: 0.08) // More subtle orange
              : AppColors.yellow.withValues(alpha: 0.08), // Yellow theme when not fasting
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isFasting) ...[
              // Progress section when fasting
              Row(
                children: [
                  Icon(
                    Icons.timer,
                    color: AppColors.orange,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '${_formatDuration(fastingDuration)} / $currentFastType',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (BuildContext context) {
                          return AlertDialog(
                            title: const Text('Confirm'),
                            content: const Text('Are you ready to finish your fasting?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.of(context).pop();
                                  _stopFast();
                                },
                                child: const Text('Stop'),
                              ),
                            ],
                          );
                        },
                      );
                    },
                    icon: const Icon(Icons.stop_rounded, size: 20),
                    label: const Text('Stop', style: TextStyle(fontSize: 14)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.error,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      minimumSize: const Size(80, 40),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: _getProgress(),
                backgroundColor: Colors.grey[300],
                valueColor: AlwaysStoppedAnimation<Color>(_getCurrentPhaseColor()),
                minHeight: 8,
              ),
            ] else ...[
              // Not fasting section - compact horizontal layout
              Row(
                children: [
                  Icon(
                    Icons.timer_rounded,
                    color: AppColors.yellow,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: recommendedFast.isNotEmpty
                    ? Text(
                        recommendedFast,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      )
                    : const Text(
                        'No fast today',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white70),
                          ),
                  ),
                  if (recommendedFast.isNotEmpty) ...[
                    ElevatedButton.icon(
                      onPressed: _startFast,
                      icon: const Icon(Icons.play_arrow_rounded, size: 24),
                      label: const Text('Start', style: TextStyle(fontSize: 16)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.yellow,
                        foregroundColor: Colors.black87,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        minimumSize: const Size(80, 40),
                      ),
                    ),
                    // Not Today button inline with Start button
                    if (widget.onHiddenForToday != null) ...[
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: widget.onHiddenForToday,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white54,
                          side: const BorderSide(color: Colors.white24),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          minimumSize: const Size(0, 40),
                        ),
                        child: const Icon(Icons.close_rounded, size: 16),
                      ),
                    ],
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Get current fasting phase info (synchronized with fasting screen)
  Map<String, dynamic> _getFastingPhaseInfo() {
    if (!isFasting || fastingStartTime == null) {
      return {
        'phase': 'Ready to Fast',
        'message': 'Begin your transformative journey',
        'color': Colors.grey,
        'progress': 0.0,
      };
    }

    final hoursElapsed = fastingDuration.inHours;

    if (hoursElapsed < 4) {
      return {
        'phase': 'Digestion Phase',
        'message': 'Your body is processing the last meal',
        'color': Colors.blue,
        'progress': (hoursElapsed / 4).clamp(0.0, 1.0),
      };
    } else if (hoursElapsed < 8) {
      return {
        'phase': 'Glycogen Depletion',
        'message': 'Transitioning to stored energy',
        'color': Colors.lightBlue,
        'progress': ((hoursElapsed - 4) / 4).clamp(0.0, 1.0),
      };
    } else if (hoursElapsed < 12) {
      return {
        'phase': 'Fat Burning Begins',
        'message': 'Your body starts burning fat for fuel',
        'color': const Color(0xFFF98834),
        'progress': ((hoursElapsed - 8) / 4).clamp(0.0, 1.0),
      };
    } else if (hoursElapsed < 16) {
      return {
        'phase': 'Ketosis Initiation',
        'message': 'Ketone production is ramping up',
        'color': const Color(0xFFBD3AA6),
        'progress': ((hoursElapsed - 12) / 4).clamp(0.0, 1.0),
      };
    } else if (hoursElapsed < 20) {
      return {
        'phase': 'Deep Ketosis',
        'message': 'Mental clarity and energy surge',
        'color': Colors.indigo,
        'progress': ((hoursElapsed - 16) / 4).clamp(0.0, 1.0),
      };
    } else if (hoursElapsed < 24) {
      return {
        'phase': 'Growth Hormone Peak',
        'message': 'Enhanced fat burning and muscle preservation',
        'color': Colors.deepPurple,
        'progress': ((hoursElapsed - 20) / 4).clamp(0.0, 1.0),
      };
    } else if (hoursElapsed < 36) {
      return {
        'phase': 'Autophagy Activation',
        'message': 'Cellular repair and regeneration begin',
        'color': Colors.green,
        'progress': ((hoursElapsed - 24) / 12).clamp(0.0, 1.0),
      };
    } else if (hoursElapsed < 48) {
      return {
        'phase': 'Enhanced Autophagy',
        'message': 'Deep cellular cleansing and renewal',
        'color': Colors.teal,
        'progress': ((hoursElapsed - 36) / 12).clamp(0.0, 1.0),
      };
    } else {
      return {
        'phase': 'Maximum Benefits',
        'message': 'Peak metabolic and cellular benefits',
        'color': Colors.amber,
        'progress': 1.0,
      };
    }
  }

  // Get current fasting phase color
  Color _getCurrentPhaseColor() {
    return _getFastingPhaseInfo()['color'];
  }
}