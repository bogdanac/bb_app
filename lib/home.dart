import 'package:bb_app/MenstrualCycle/cycle_tracking_screen.dart';
import 'package:flutter/material.dart';
import 'theme/app_colors.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:bb_app/Calendar/events_card.dart';
import 'package:bb_app/MenstrualCycle/menstrual_cycle_card.dart';
import 'package:bb_app/WaterTracking/water_tracking_card.dart';
import 'package:bb_app/Tasks/daily_tasks_card.dart';
import 'package:bb_app/Routines/morning_routine_card.dart';
import 'package:bb_app/Fasting/fasting_card.dart';
import 'package:bb_app/Notifications/notification_service.dart';

// HOME SCREEN
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  int waterIntake = 0;
  bool showFastingSection = false;
  bool showMorningRoutine = true;
  bool _isLoading = true;
  bool _isDisposed = false;

  // Add a key to force rebuild of MenstrualCycleCard
  Key _menstrualCycleKey = UniqueKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeData();
  }

  @override
  void dispose() {
    _isDisposed = true;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _initializeData() async {
    try {
      await _loadWaterIntake();
      _checkFastingVisibility();
      _checkMorningRoutineVisibility();

      // Inițializează și programează notificările de apă
      await _initializeWaterNotifications();

      if (!_isDisposed && mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error initializing home data: $e');
      if (!_isDisposed && mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _initializeWaterNotifications() async {
    try {
      final notificationService = NotificationService();

      // Programează notificările de apă pentru ziua curentă
      await notificationService.scheduleWaterReminders();

      // Verifică dacă trebuie să anuleze notificări pe baza progresului curent
      await notificationService.checkAndCancelWaterNotifications(waterIntake);

      debugPrint('Water notifications initialized successfully');
    } catch (e) {
      debugPrint('Error initializing water notifications: $e');
    }
  }

  // This method is called when the app comes back to foreground
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_isDisposed && mounted && state == AppLifecycleState.resumed) {
      // Refresh water intake in case widget updated it
      _loadWaterIntake();
      // Refresh the menstrual cycle card when returning to the app
      _refreshMenstrualCycleData();
    }
  }

  bool get _shouldShowWaterTracking {
    return waterIntake < 1500; // Changed to match the goal in WaterTrackingCard
  }

  Future<void> _loadWaterIntake() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      final today = DateFormat('yyyy-MM-dd').format(now);

      // Verifică dacă este după ora 2:00 și dacă avem date de ieri
      final lastResetDate = prefs.getString('last_water_reset_date');
      final shouldReset = _shouldResetWaterToday(now, lastResetDate);

      int intake;
      if (shouldReset) {
        // Resetează pentru ziua nouă
        intake = 0;
        await prefs.setInt('water_$today', intake);
        await prefs.setString('last_water_reset_date', today);

        // Reprogramează notificările pentru ziua nouă
        final notificationService = NotificationService();
        await notificationService.rescheduleWaterNotificationsForTomorrow();

        debugPrint('Water intake reset for new day: $today');
      } else {
        // Încarcă datele pentru ziua curentă
        intake = prefs.getInt('water_$today') ?? 0;
      }

      if (!_isDisposed && mounted) {
        setState(() {
          waterIntake = intake;
        });
      }
    } catch (e) {
      debugPrint('Error loading water intake: $e');
    }
  }

  bool _shouldResetWaterToday(DateTime now, String? lastResetDate) {
    if (lastResetDate == null) return true; // Prima rulare

    try {
      final lastReset = DateTime.parse(lastResetDate);
      final today = DateTime(now.year, now.month, now.day);
      final lastResetDay = DateTime(lastReset.year, lastReset.month, lastReset.day);

      // Verifică dacă suntem în o zi diferită ȘI după ora 2:00
      if (today.isAfter(lastResetDay)) {
        // Dacă suntem în ziua următoare, verifică ora
        if (now.hour >= 2) {
          return true; // Reset după 2:00 în ziua nouă
        } else {
          // Dacă suntem în ziua nouă dar înainte de 2:00,
          // verifică dacă ultima resetare a fost înainte de 2:00 ieri
          return true; // Pentru simplitate, resetează oricum
        }
      }

      return false; // Aceeași zi sau nu e timpul pentru reset
    } catch (e) {
      debugPrint('Error parsing last reset date: $e');
      return true; // În caz de eroare, resetează
    }
  }

  void _checkFastingVisibility() {
    final now = DateTime.now();
    final isSunday = now.weekday == 7;
    final is25th = now.day == 25;

    if (!_isDisposed && mounted) {
      setState(() {
        showFastingSection = isSunday || is25th;
      });
    }
  }

  void _checkMorningRoutineVisibility() async {
    final now = DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    final today = DateFormat('yyyy-MM-dd').format(now);
    final hiddenToday = prefs.getBool('morning_routine_hidden_$today') ?? false;

    if (!_isDisposed && mounted) {
      setState(() {
        // Show if it's between 4 AM and 5 PM and not manually hidden today
        showMorningRoutine = now.hour >= 4 && now.hour < 17 && !hiddenToday;
      });
    }
  }

  // Method to refresh menstrual cycle data
  void _refreshMenstrualCycleData() {
    if (!_isDisposed && mounted) {
      setState(() {
        _menstrualCycleKey = UniqueKey();
      });
    }
  }

  Future<void> _onRefresh() async {
    try {
      await _loadWaterIntake();
      _checkFastingVisibility();
      _checkMorningRoutineVisibility();
      _refreshMenstrualCycleData();
    } catch (e) {
      debugPrint('Error refreshing data: $e');
    }
  }

  Future<void> _onWaterAdded() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final oldIntake = waterIntake;
      final newIntake = waterIntake + 125;
      const int goal = 1500;

      if (!_isDisposed && mounted) {
        setState(() {
          waterIntake = newIntake;
        });
        await prefs.setInt('water_$today', newIntake);

        // Show congratulations when goal is reached
        if (oldIntake < goal && newIntake >= goal) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🎉 Daily water goal achieved! Great job!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
        }

        // Verifică și anulează notificările pe baza noului progres
        final notificationService = NotificationService();
        await notificationService.checkAndCancelWaterNotifications(newIntake);
      }
    } catch (e) {
      debugPrint('Error adding water: $e');
    }
  }

  void _onMorningRoutineCompleted() {
    if (!_isDisposed && mounted) {
      setState(() {
        showMorningRoutine = false;
      });
    }
  }

  void _onMorningRoutineHiddenForToday() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    await prefs.setBool('morning_routine_hidden_$today', true);
    
    if (!_isDisposed && mounted) {
      setState(() {
        showMorningRoutine = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('BBetter', style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: Colors.transparent,
        ),
        body: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.coral),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('bbetter', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
      ),
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(12), // Slightly tighter overall padding
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Menstrual Cycle Section with key for rebuilding
              MenstrualCycleCard(
                key: _menstrualCycleKey,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const CycleScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12), // Reduced spacing

              // Calendar Events Section
              const CalendarEventsCard(),
              const SizedBox(height: 12), // Reduced spacing


              // Fasting Section (conditional)
              if (showFastingSection) ...[
                const FastingCard(),
                const SizedBox(height: 12), // Reduced spacing
              ],

              // Water Tracking Section (conditional)
              if (_shouldShowWaterTracking) ...[
                WaterTrackingCard(
                  waterIntake: waterIntake,
                  onWaterAdded: _onWaterAdded,
                ),
                const SizedBox(height: 12), // Reduced spacing
              ],

              // Morning Routine Section (conditional)
              if (showMorningRoutine) ...[
                MorningRoutineCard(
                  onCompleted: _onMorningRoutineCompleted,
                  onHiddenForToday: _onMorningRoutineHiddenForToday,
                ),
                const SizedBox(height: 12), // Reduced spacing
              ],

              // Daily Tasks Section
              const DailyTasksCard(),
            ],
          ),
        ),
      ),
    );
  }
}