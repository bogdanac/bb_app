import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'fasting_history_screen.dart';
import 'fasting_notifier.dart';
import '../Notifications/notification_service.dart';

class FastingScreen extends StatefulWidget {
  const FastingScreen({super.key});

  @override
  State<FastingScreen> createState() => _FastingScreenState();
}

class _FastingScreenState extends State<FastingScreen>
    with TickerProviderStateMixin {
  DateTime? _currentFastStart;
  DateTime? _currentFastEnd;
  bool _isFasting = false;
  Timer? _fastingTimer;
  Duration _elapsedTime = Duration.zero;
  Duration _totalFastDuration = Duration.zero;
  List<Map<String, dynamic>> _fastingHistory = [];
  String _currentFastType = '';
  late AnimationController _progressController;
  late AnimationController _pulseController;
  final FastingNotifier _notifier = FastingNotifier();
  final NotificationService _notificationService = NotificationService();

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    // Start pulse animation only when fasting
    _loadFastingData();
    _startFastingTimer();
    _notifier.addListener(_onFastingStateChanged);
  }

  @override
  void dispose() {
    _fastingTimer?.cancel();
    _progressController.dispose();
    _pulseController.dispose();
    _notifier.removeListener(_onFastingStateChanged);
    super.dispose();
  }

  void _onFastingStateChanged() {
    _loadFastingData();
  }

  Future<void> _loadFastingData() async {
    final prefs = await SharedPreferences.getInstance();

    _isFasting = prefs.getBool('is_fasting') ?? false;
    final startStr = prefs.getString('current_fast_start');
    final endStr = prefs.getString('current_fast_end');

    if (startStr != null) _currentFastStart = DateTime.parse(startStr);
    if (endStr != null) _currentFastEnd = DateTime.parse(endStr);

    _currentFastType = prefs.getString('current_fast_type') ?? '';

    // Load fasting history
    final historyStr = prefs.getStringList('fasting_history') ?? [];
    _fastingHistory = historyStr
        .map((item) => Map<String, dynamic>.from(jsonDecode(item) as Map))
        .toList();

    _calculateFastingProgress();

    // Start/stop pulse animation based on fasting state
    if (_isFasting && !_pulseController.isAnimating) {
      _pulseController.repeat(reverse: true);
      // Show notification if fasting is in progress
      _updateFastingNotification();
    } else if (!_isFasting && _pulseController.isAnimating) {
      _pulseController.stop();
      _pulseController.reset();
      // Cancel notification if not fasting
      _notificationService.cancelFastingProgressNotification();
    }

    if (mounted) setState(() {});
  }

  Future<void> _saveFastingData() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setBool('is_fasting', _isFasting);
    if (_currentFastStart != null) {
      await prefs.setString(
          'current_fast_start', _currentFastStart!.toIso8601String());
    } else {
      await prefs.remove('current_fast_start');
    }
    if (_currentFastEnd != null) {
      await prefs.setString(
          'current_fast_end', _currentFastEnd!.toIso8601String());
    } else {
      await prefs.remove('current_fast_end');
    }
    await prefs.setString('current_fast_type', _currentFastType);

    // Save history
    final historyStr = _fastingHistory.map((item) => jsonEncode(item)).toList();
    await prefs.setStringList('fasting_history', historyStr);

    // Notifică toate componentele că starea s-a schimbat
    _notifier.notifyFastingStateChanged();
  }

  void _calculateFastingProgress() {
    if (_isFasting && _currentFastStart != null) {
      final now = DateTime.now();
      _elapsedTime = now.difference(_currentFastStart!);

      if (_currentFastEnd != null) {
        _totalFastDuration = _currentFastEnd!.difference(_currentFastStart!);
      }

      // Nu mai verificăm autocompletarea - doar calculăm progresul
    }
  }

  void _startFastingTimer() {
    _fastingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_isFasting) {
        _calculateFastingProgress();
        _updateFastingNotification();
        if (mounted) setState(() {});
      }
    });
  }

  void _updateFastingNotification() {
    if (_isFasting && _currentFastStart != null) {
      final phaseInfo = _getFastingPhaseInfo();
      _notificationService.showFastingProgressNotification(
        fastType: _currentFastType,
        elapsedTime: _elapsedTime,
        totalDuration: _totalFastDuration,
        currentPhase: phaseInfo['phase'],
      );
    }
  }

  String _getRecommendedFastType() {
    final now = DateTime.now();
    final isFriday = now.weekday == 5;
    final is25th = now.day == 25;

    // Smart scheduling: combine Friday and 25th fasts when close
    if (isFriday || is25th) {
      return _getSmartFastRecommendation(now, isFriday, is25th);
    }

    // Fasting screen has a 5-day grace period - check recent fasting days
    return _getRecommendedFastWithGracePeriod(now);
  }

  // Smart scheduling logic to avoid double fasts when Friday and 25th are close
  String _getSmartFastRecommendation(DateTime now, bool isFriday, bool is25th) {
    // If today is the 25th, check if there was a recent Friday or upcoming Friday
    if (is25th) {
      final month = now.month;
      String longerFastType;
      if (month == 1 || month == 9) {
        longerFastType = '3-Day Water Fast';
      } else if (month % 3 == 1) {
        longerFastType = '48h Quarterly Fast';
      } else {
        longerFastType = '36h Monthly Fast';
      }
      
      // Check if Friday was within the last 4-6 days or will be within next 4-6 days
      final daysUntilFriday = (5 - now.weekday + 7) % 7; // Days until next Friday (0 if today is Friday)
      final daysSinceLastFriday = now.weekday >= 5 ? now.weekday - 5 : now.weekday + 2; // Days since last Friday
      
      // If Friday is close (within 6 days either way), skip Friday fast and do the longer fast on 25th
      if (daysSinceLastFriday <= 6 || daysUntilFriday <= 6) {
        return longerFastType; // Do the longer fast on the 25th
      }
      
      return longerFastType;
    }
    
    // If today is Friday, check if 25th is close
    if (isFriday) {
      final daysUntil25th = 25 - now.day;
      
      // If 25th is within 4-6 days, do the longer fast on Friday instead
      if (daysUntil25th >= 0 && daysUntil25th <= 6) {
        final month = now.month;
        
        // Use the appropriate longer fast type
        if (month == 1 || month == 9) {
          return '3-Day Water Fast';
        } else if (month % 3 == 1) {
          return '48h Quarterly Fast';
        } else {
          return '36h Monthly Fast';
        }
      }
      
      // Check if 25th was recent (within last 6 days) 
      if (now.day < 25 && (25 - now.day) > 25) { // 25th was last month
        final lastMonth = now.month == 1 ? 12 : now.month - 1;
        final daysSince25thLastMonth = now.day + (DateTime(now.year, now.month, 0).day - 25);
        
        if (daysSince25thLastMonth <= 6) {
          // 25th was recent, do the longer fast type on Friday
          if (lastMonth == 1 || lastMonth == 9) {
            return '3-Day Water Fast';
          } else if (lastMonth % 3 == 1) {
            return '48h Quarterly Fast';
          } else {
            return '36h Monthly Fast';
          }
        }
      }
      
      return '24h Weekly Fast'; // Normal Friday fast
    }
    
    return '';
  }

  // Get recommended fast with 5-day grace period (for fasting screen only)
  String _getRecommendedFastWithGracePeriod(DateTime now) {
    // Check if Friday was within the last 5 days
    final daysSinceLastFriday = now.weekday >= 5 ? now.weekday - 5 : now.weekday + 2;
    if (daysSinceLastFriday <= 5 && daysSinceLastFriday > 0) {
      // Calculate what the fast would have been on that Friday
      final lastFriday = now.subtract(Duration(days: daysSinceLastFriday));
      final daysUntil25thFromLastFriday = 25 - lastFriday.day;
      
      // Check if 25th was close to that Friday
      if (daysUntil25thFromLastFriday >= 0 && daysUntil25thFromLastFriday <= 6) {
        final month = lastFriday.month;
        if (month == 1 || month == 9) {
          return '3-Day Water Fast';
        } else if (month % 3 == 1) {
          return '48h Quarterly Fast';
        } else {
          return '36h Monthly Fast';
        }
      } else {
        return '24h Weekly Fast';
      }
    }
    
    // Check if 25th was within the last 5 days
    final daysSince25th = now.day > 25 ? now.day - 25 : 0;
    if (daysSince25th <= 5 && daysSince25th > 0) {
      final month = now.month;
      if (month == 1 || month == 9) {
        return '3-Day Water Fast';
      } else if (month % 3 == 1) {
        return '48h Quarterly Fast';
      } else {
        return '36h Monthly Fast';
      }
    }
    
    // Check if 25th was in the previous month within 5 days
    if (now.day <= 5) {
      final lastMonth = now.month == 1 ? 12 : now.month - 1;
      final daysInLastMonth = DateTime(now.year, now.month, 0).day;
      final daysSince25thLastMonth = now.day + (daysInLastMonth - 25);
      
      if (daysSince25thLastMonth <= 5) {
        if (lastMonth == 1 || lastMonth == 9) {
          return '3-Day Water Fast';
        } else if (lastMonth % 3 == 1) {
          return '48h Quarterly Fast';
        } else {
          return '36h Monthly Fast';
        }
      }
    }

    return '';
  }

  Duration _getFastDuration(String fastType) {
    switch (fastType) {
      case '24h Weekly Fast':
        return const Duration(hours: 24);
      case '36h Monthly Fast':
        return const Duration(hours: 36);
      case '48h Quarterly Fast':
        return const Duration(hours: 48);
      case '3-Day Water Fast':
        return const Duration(days: 3);
      default:
        return const Duration(hours: 24);
    }
  }

  void _startFast(String fastType) {
    final now = DateTime.now();
    final duration = _getFastDuration(fastType);

    setState(() {
      _isFasting = true;
      _currentFastStart = now;
      _currentFastEnd = now.add(duration);
      _currentFastType = fastType;
      _elapsedTime = Duration.zero;
      _totalFastDuration = duration;
    });

    _saveFastingData();
    _progressController.forward();
    _pulseController.repeat(reverse: true);

    // Show initial notification
    _updateFastingNotification();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('🚀 $fastType started! You got this!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  // Start quick fast (12h or 16h)
  void _startQuickFast(int hours) {
    final now = DateTime.now();
    final duration = Duration(hours: hours);
    final fastType = '${hours}h Fast';

    setState(() {
      _isFasting = true;
      _currentFastStart = now;
      _currentFastEnd = now.add(duration);
      _currentFastType = fastType;
      _elapsedTime = Duration.zero;
      _totalFastDuration = duration;
    });

    _saveFastingData();
    _progressController.forward();
    _pulseController.repeat(reverse: true);

    // Show initial notification
    _updateFastingNotification();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('🚀 $fastType started!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _endFast() {
    if (_currentFastStart != null) {
      final endTime = DateTime.now();
      final actualDuration = endTime.difference(_currentFastStart!);

      _fastingHistory.add({
        'type': _currentFastType,
        'startTime': _currentFastStart!.toIso8601String(),
        'endTime': endTime.toIso8601String(),
        'plannedDuration': _totalFastDuration.inMinutes,
        'actualDuration': actualDuration.inMinutes,
      });

      setState(() {
        _isFasting = false;
        _currentFastStart = null;
        _currentFastEnd = null;
        _currentFastType = '';
        _elapsedTime = Duration.zero;
        _totalFastDuration = Duration.zero;
      });

      _saveFastingData();
      _progressController.reset();
      _pulseController.stop();
      _pulseController.reset();

      // Cancel progress notification and show completion notification
      _notificationService.cancelFastingProgressNotification();
      _notificationService.showFastingCompletedNotification(
        fastType: _currentFastType,
        actualDuration: actualDuration,
      );

      _showCongratulationDialog(actualDuration);
    }
  }

  void _postponeFast() {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    final newStartTime =
    DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 14, 0);

    setState(() {
      _currentFastStart = newStartTime;
      _currentFastEnd = newStartTime.add(_totalFastDuration);
    });

    _saveFastingData();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Fast postponed to tomorrow at 2 PM'),
        backgroundColor: Color(0xFFF98834),
      ),
    );
  }

  void _showCongratulationDialog(Duration actualDuration) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('🎉 Congratulations!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('You completed your fast!'),
            const SizedBox(height: 16),
            Text(
              'Duration: ${_formatDuration(actualDuration)}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Awesome!'),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    return '${hours}h ${minutes}m';
  }

  // Enhanced fasting phases with detailed information
  Map<String, dynamic> _getFastingPhaseInfo() {
    if (!_isFasting || _elapsedTime == Duration.zero) {
      return {
        'phase': 'Ready to Fast',
        'message': 'Begin your transformative journey',
        'color': Colors.grey,
        'progress': 0.0,
      };
    }

    final hoursElapsed = _elapsedTime.inHours;

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
        'color': Color(0xFFF98834),
        'progress': ((hoursElapsed - 8) / 4).clamp(0.0, 1.0),
      };
    } else if (hoursElapsed < 16) {
      return {
        'phase': 'Ketosis Initiation',
        'message': 'Ketone production is ramping up',
        'color': Color(0xFFBD3AA6),
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
        'message': 'HGH levels are significantly elevated',
        'color': Colors.green,
        'progress': ((hoursElapsed - 20) / 4).clamp(0.0, 1.0),
      };
    } else if (hoursElapsed < 36) {
      return {
        'phase': 'Autophagy Activation',
        'message': 'Cellular repair and regeneration active',
        'color': Colors.teal,
        'progress': ((hoursElapsed - 24) / 12).clamp(0.0, 1.0),
      };
    } else if (hoursElapsed < 48) {
      return {
        'phase': 'Enhanced Autophagy',
        'message': 'Peak cellular cleanup and renewal',
        'color': Color(0xFFFB3380),
        'progress': ((hoursElapsed - 36) / 12).clamp(0.0, 1.0),
      };
    } else {
      return {
        'phase': 'Maximum Benefits',
        'message': 'Ultimate metabolic transformation',
        'color': Color(0xFFBD3AA6),
        'progress': 1.0,
      };
    }
  }

  String _getLongestFast() {
    if (_fastingHistory.isEmpty) return '0h 0m';

    final longestMinutes = _fastingHistory
        .map((fast) => fast['actualDuration'] as int)
        .reduce((a, b) => a > b ? a : b);

    final hours = longestMinutes ~/ 60;
    final minutes = longestMinutes % 60;
    return '${hours}h ${minutes}m';
  }

  Widget _buildEnhancedCircularProgress() {
    final phaseInfo = _getFastingPhaseInfo();
    final totalProgress = _totalFastDuration.inMinutes > 0
        ? _elapsedTime.inMinutes / _totalFastDuration.inMinutes
        : 0.0;

    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return SizedBox(
          width: 280,
          height: 280,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Outer glow effect - doar dacă se face fasting
              if (_isFasting)
                Container(
                  width: 260 + (_pulseController.value * 20),
                  height: 260 + (_pulseController.value * 20),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: phaseInfo['color'].withValues(alpha: 0.3 * _pulseController.value),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                ),

              // Background circle
              Container(
                width: 240,
                height: 240,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: phaseInfo['color'].withValues(alpha: 0.1),
                ),
              ),

              // Main progress circle
              SizedBox(
                width: 240,
                height: 240,
                child: CircularProgressIndicator(
                  value: totalProgress.clamp(0.0, 1.0),
                  strokeWidth: 12,
                  backgroundColor: Colors.grey.withValues(alpha: 0.2),
                  valueColor: AlwaysStoppedAnimation<Color>(phaseInfo['color']),
                ),
              ),

              // Phase progress circle (inner)
              SizedBox(
                width: 180,
                height: 180,
                child: CircularProgressIndicator(
                  value: phaseInfo['progress'],
                  strokeWidth: 8,
                  backgroundColor: Colors.transparent,
                  valueColor: AlwaysStoppedAnimation<Color>(
                      phaseInfo['color'].withValues(alpha: 0.6)
                  ),
                ),
              ),

              // Center content
              Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Theme.of(context).scaffoldBackgroundColor,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_isFasting) ...[
                      Text(
                        _formatDuration(_elapsedTime),
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: phaseInfo['color'],
                        ),
                      ),
                      if (_currentFastEnd != null) ...[
                        Text(
                          'of ${_formatDuration(_totalFastDuration)}',
                          style: const TextStyle(
                              fontSize: 14,
                              color: Colors.grey
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${(totalProgress * 100).toInt()}%',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: phaseInfo['color'],
                          ),
                        ),
                      ],
                    ] else ...[
                      Icon(
                        Icons.timer_outlined,
                        size: 48,
                        color: phaseInfo['color'],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Ready',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final recommendedFast = _getRecommendedFastType();
    final phaseInfo = _getFastingPhaseInfo();
    final now = DateTime.now();
    final showPostponeButton =
        now.hour >= 17 && !_isFasting && recommendedFast.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Fasting'),
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      FastingHistoryScreen(history: _fastingHistory),
                ),
              );
              // Refresh data when returning from history
              _loadFastingData();
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Quick start buttons - always visible at top
            if (!_isFasting) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      // Quick start buttons row
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _startQuickFast(12),
                              icon: const Icon(Icons.timer_outlined),
                              label: const Text('12h Fast'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _startQuickFast(16),
                              icon: const Icon(Icons.timer_outlined),
                              label: const Text('16h Fast'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.deepOrange,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 4),
            ],
            
            // Enhanced Current Fast Status Card
            Card(
              elevation: 8,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      phaseInfo['color'].withValues(alpha: 0.2),
                      phaseInfo['color'].withValues(alpha: 0.05),
                    ],
                  ),
                ),
                child: Column(
                  children: [
                    // Enhanced Circular Progress
                    _buildEnhancedCircularProgress(),

                    const SizedBox(height: 24),

                    // Phase Information
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: phaseInfo['color'].withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: phaseInfo['color'].withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _isFasting ? Icons.bolt : Icons.timer_outlined,
                                color: phaseInfo['color'],
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                phaseInfo['phase'],
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: phaseInfo['color'],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            phaseInfo['message'],
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.grey,
                              fontStyle: FontStyle.italic,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Control Buttons
            if (_isFasting) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _endFast,
                  icon: const Icon(Icons.stop_rounded),
                  label: const Text('End Fast'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ] else if (recommendedFast.isNotEmpty) ...[
              // Show scheduled fast start button if available  
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _startFast(recommendedFast),
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: Text('Start $recommendedFast'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              if (showPostponeButton) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _postponeFast,
                    icon: const Icon(Icons.schedule_rounded),
                    label: const Text('Postpone to Tomorrow'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ],

            const SizedBox(height: 12),

            // Statistics Card
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Your Progress',
                      style:
                      TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatItem(
                          'Total Fasts',
                          '${_fastingHistory.length}',
                          Icons.flag_rounded,
                          Colors.blue,
                        ),
                        _buildStatItem(
                          'Longest Fast',
                          _getLongestFast(),
                          Icons.timer_rounded,
                          Colors.orange,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(
      String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 32),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 14, color: Colors.grey),
        ),
      ],
    );
  }
}