// fasting_card.dart - Actualizat cu sincronizare
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:convert';
import 'fasting_notifier.dart';

class FastingCard extends StatefulWidget {
  const FastingCard({super.key});

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
    final isSunday = now.weekday == 7;
    final is25th = now.day == 25;

    if (isSunday) return '24h';
    if (is25th) {
      final month = now.month;
      if (month % 3 == 1) return '48h';
      return '36h';
    }
    if (now.month == 1 && is25th) return '3-days';
    if (now.month == 9 && is25th) return '3-days';

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
      }
    });
  }

  // Start fasting (compatible cu FastingScreen)
  void _startFast() {
    HapticFeedback.mediumImpact();

    final recommendedType = _getRecommendedFastType();
    if (recommendedType.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No fast scheduled for today'),
          backgroundColor: Colors.orange,
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

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('🚀 $recommendedType started!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  // Stop fasting (compatible cu FastingScreen)
  void _stopFast() {
    HapticFeedback.mediumImpact();
    _timer?.cancel();

    // Salvează în istoric înainte de oprire
    _saveToHistory();

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
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: isFasting
                ? [
              Colors.orange.withOpacity(0.3),
              Colors.orange.withOpacity(0.1),
            ]
                : [
              Theme.of(context).colorScheme.primary.withOpacity(0.3),
              Theme.of(context).colorScheme.primary.withOpacity(0.1),
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isFasting ? Icons.timer : Icons.timer_rounded,
                  color: isFasting ? Colors.orange : Theme.of(context).colorScheme.primary,
                  size: 28,
                ),
                const SizedBox(width: 12),
                const Text(
                  'Fasting',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),

            if (isFasting) ...[
              // Progress section when fasting
              Text(
                '${_formatDuration(fastingDuration)} / ${currentFastType}',
                style: const TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 12),

              // Progress bar
              LinearProgressIndicator(
                value: _getProgress(),
                backgroundColor: Colors.grey[300],
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.orange),
                minHeight: 12,
              ),
              const SizedBox(height: 16),

              // Stop button
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
                icon: const Icon(Icons.stop_rounded),
                label: const Text('Finish fasting'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red[400],
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ] else ...[
              // Start section when not fasting
              if (recommendedFast.isNotEmpty) ...[
                // Start button
                ElevatedButton.icon(
                  onPressed: _startFast,
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: Text('Start $recommendedFast'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.black87,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ] else ...[
                const Text(
                  'No fast scheduled',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Fasts are available on Sundays and the 25th',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}