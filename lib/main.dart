import 'package:flutter/material.dart';
import 'Fasting/fasting_screen.dart';
import 'MenstrualCycle/cycle_tracking_screen.dart';
import 'Routines/routines_habits_screen.dart';
import 'Tasks/todo_screen.dart';
import 'Tasks/task_widget_service.dart';
import 'home.dart';
import 'Notifications/notification_service.dart';
import 'Notifications/notification_listener_service.dart';
import 'Data/backup_service.dart';
import 'Tasks/task_service.dart';
import 'theme/app_colors.dart';
import 'dart:io';
import 'dart:math';
import 'dart:async';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Reset notification service on hot reload in debug mode
  if (kDebugMode) {
    NotificationListenerService.reset();
  }

  runApp(const BBetterApp());
}

class BBetterApp extends StatelessWidget {
  const BBetterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BB',
      builder: (BuildContext context, Widget? child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        );
      },
      theme: AppTheme.theme,
      home: const MainScreen(), // TODO: Change back to LauncherScreen (use MainScreen() for hot reload testing)
      debugShowCheckedModeBanner: false,
    );
  }
}

// Animated Launcher Screen
class LauncherScreen extends StatefulWidget {
  const LauncherScreen({super.key});

  @override
  State<LauncherScreen> createState() => _LauncherScreenState();
}

class _LauncherScreenState extends State<LauncherScreen>
    with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _textController;
  late AnimationController _backgroundController;
  Timer? _emergencyTimer;

  late Animation<double> _logoScale;
  late Animation<double> _logoRotation;
  late Animation<double> _textOpacity;
  late Animation<double> _textSlide;
  late Animation<Color?> _backgroundColor;

  @override
  void initState() {
    super.initState();

    // Initialize animation controllers
    _logoController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _textController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _backgroundController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    // Initialize animations
    _logoScale = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _logoController,
      curve: Curves.elasticOut,
    ));

    _logoRotation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _logoController,
      curve: Curves.easeInOut,
    ));

    _textOpacity = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _textController,
      curve: Curves.easeIn,
    ));

    _textSlide = Tween<double>(
      begin: 50.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _textController,
      curve: Curves.easeOut,
    ));

    _backgroundColor = ColorTween(
      begin: const Color(0xFF1A1A1A),
      end: const Color(0xFF2A1B2A), // Dark background with your palette
    ).animate(CurvedAnimation(
      parent: _backgroundController,
      curve: Curves.easeInOut,
    ));

    _startAnimationSequence();
  }

  void _startAnimationSequence() async {
    try {
      // Check for widget intent early to skip launcher for widget triggers
      bool hasWidgetIntent = false;
      try {
        hasWidgetIntent = await TaskWidgetService.checkForWidgetIntent();
      } catch (e) {
        if (kDebugMode) print("ERROR checking widget intent: $e");
      }
      
      // If widget intent detected, skip launcher and go directly to main screen with task dialog
      if (hasWidgetIntent && mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const MainScreen()),
        );
        return;
      }
      
      // Emergency failsafe - navigate to main screen after maximum 15 seconds regardless of what happens
      _emergencyTimer = Timer(const Duration(seconds: 15), () {
        if (mounted && Navigator.of(context).canPop() == false) {
          if (kDebugMode) {
          }
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const MainScreen()),
          );
        }
      });

      // Start background animation
      if (mounted) _backgroundController.forward();

      // Start logo animation
      await Future.delayed(const Duration(milliseconds: 300));
      if (mounted) _logoController.forward();

      // Start text animation
      await Future.delayed(const Duration(milliseconds: 800));
      if (mounted) _textController.forward();

      // Initialize notifications and navigate with timeout protection
      await Future.delayed(const Duration(milliseconds: 1200));
      if (mounted) {
        // Wrap entire initialization in a timeout
        await _initializeApp().timeout(Duration(seconds: 10)).catchError((error) {
          if (kDebugMode) {
            print("App initialization ERROR: $error");
          }
        });
      }

      // Navigate to main screen (reduced delay since native splash handles initial display)
      await Future.delayed(const Duration(milliseconds: 200));
      if (mounted && Navigator.of(context).canPop() == false) {
        // Cancel emergency timer since we're navigating normally
        _emergencyTimer?.cancel();
        
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => const MainScreen(),
            transitionDuration: const Duration(milliseconds: 800),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.0, 0.1),
                    end: Offset.zero,
                  ).animate(CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOut,
                  )),
                  child: child,
                ),
              );
            },
          ),
        );
      } else {
        // Cancel emergency timer if we can't navigate (shouldn't happen)
        _emergencyTimer?.cancel();
      }
    } catch (e) {
      if (kDebugMode) print("ERROR in animation sequence: $e");
      // Fallback to main screen
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const MainScreen()),
        );
      }
    }
  }

  Future<void> _initializeApp() async {
    try {
      // Initialize notifications with timeout protection
      await (() async {
        final notificationService = NotificationService();
        await notificationService.initializeNotifications();
        await notificationService.scheduleWaterReminders();
        
        // Initialize task notifications
        final taskService = TaskService();
        await taskService.forceRescheduleAllNotifications();
      })().timeout(Duration(seconds: 10)).catchError((error) {
        if (kDebugMode) {
          print("Notification initialization ERROR: $error");
        }
      });
      
      // Initialize notification listener service for motion alerts with debug protection and timeout
      try {
        await NotificationListenerService.initialize().timeout(Duration(seconds: 5));
        if (kDebugMode) {
        }
      } catch (error) {
        if (kDebugMode) {
          print("❌ WARNING: NotificationListenerService failed to initialize: $error");
          print("Motion alerts may not work, but app will continue normally");
        }
      }

      // Perform auto-backup check (non-blocking with timeout)
      BackupService.performAutoBackup().timeout(Duration(seconds: 8)).catchError((error) {
        if (kDebugMode) {
          print("Auto backup check ERROR: $error");
        }
      });

      // Check for weekly cloud backup reminder
      BackupService.checkWeeklyCloudBackupReminder().timeout(Duration(seconds: 5)).catchError((error) {
        if (kDebugMode) {
          print("Cloud backup reminder check ERROR: $error");
        }
      });

      // Schedule nightly backups (non-blocking with timeout)
      BackupService.scheduleNightlyBackups().timeout(Duration(seconds: 5)).catchError((error) {
        if (kDebugMode) {
          print("Nightly backup scheduling ERROR: $error");
        }
      });

      // Schedule daily food tracking reminders (non-blocking with timeout)
      NotificationService().scheduleFoodTrackingReminder().timeout(Duration(seconds: 5)).catchError((error) {
        if (kDebugMode) {
          print("Food tracking reminder scheduling ERROR: $error");
        }
      });

      // Request notification permissions (non-blocking with timeout)
      if (Platform.isAndroid) {
        Permission.notification.request().timeout(Duration(seconds: 5)).then((status) {
          if (!status.isGranted && kDebugMode) {
            if (kDebugMode) {
              print("Notifications permission denied");
            }
          }
        }).catchError((error) {
          if (kDebugMode) print("ERROR requesting notification permission or timed out: $error");
        });
      }
    } catch (e) {
      if (kDebugMode) print("ERROR initializing app: $e");
      // Continue regardless of initialization errors
    }
  }

  @override
  void dispose() {
    _emergencyTimer?.cancel();
    _logoController.dispose();
    _textController.dispose();
    _backgroundController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_logoController, _textController, _backgroundController]),
      builder: (context, child) {
        return Scaffold(
          backgroundColor: _backgroundColor.value ?? AppColors.normalCardBackground,
          body: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.orange, // Orange top
                  AppColors.purple, // Purple middle
                  AppColors.black, // Black bottom
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Animated Logo
                  Transform.scale(
                    scale: _logoScale.value,
                    child: Transform.rotate(
                      angle: (_logoRotation.value * 0.1) - 0.1, //rotate a bit to the left
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.purple.withValues(alpha: 0.6),
                              blurRadius: 20,
                              spreadRadius: 5,
                            ),
                            BoxShadow(
                              color: AppColors.orange.withValues(alpha: 0.4),
                              blurRadius: 30,
                              spreadRadius: 10,
                            ),
                          ],
                        ),
                        child: ClipPath(
                          clipper: HexagonClipper(),
                          child: Container(
                            decoration: BoxDecoration(
                              image: DecorationImage(
                                image: AssetImage('assets/icon/ic_launcher.png'),
                                fit: BoxFit.cover, // Use cover to fill the hexagon shape
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 40),

                  // Animated Text
                  Transform.translate(
                    offset: Offset(0, _textSlide.value),
                    child: Opacity(
                      opacity: _textOpacity.value,
                      child: Column(
                        children: [
                          Text(
                            'bbetter',
                            style: TextStyle(
                              fontSize: 42,
                              fontWeight: FontWeight.bold,
                              color: AppColors.white.withValues(alpha: _textOpacity.value),
                              letterSpacing: 2,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Fabulous every day',
                            style: TextStyle(
                              fontSize: 16,
                              color: AppColors.orange.withValues(alpha: _textOpacity.value), // Orange color
                              fontWeight: FontWeight.w300,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 60),

                  // Loading indicator
                  Opacity(
                    opacity: _textOpacity.value,
                    child: const SizedBox(
                      width: 30,
                      height: 30,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.pink), // Pink loading
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with TickerProviderStateMixin, WidgetsBindingObserver {
  int _selectedIndex = 2; // Always start with Home (index 2)
  late AnimationController _animationController;

  final List<Widget> _screens = [
    const FastingScreen(),
    const CycleScreen(),
    const HomeScreen(),
    const TodoScreen(),
    const RoutinesHabitsScreen(),
  ];

// Custom navbar implementation below - no need for _navItems

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _checkForWidgetIntent();
  }

  void _checkForWidgetIntent() async {
    // Small delay to ensure the widget is ready
    await Future.delayed(const Duration(milliseconds: 100));
    
    if (mounted) {
      try {
        final hasWidgetIntent = await TaskWidgetService.checkForWidgetIntent();
        if (hasWidgetIntent && mounted) {
          // Navigate to tasks screen first, then show dialog
          setState(() {
            _selectedIndex = 3; // Tasks screen
          });
          // Small delay to ensure navigation completes
          await Future.delayed(const Duration(milliseconds: 300));
          if (mounted) {
            await TaskWidgetService.showQuickTaskDialog(context);
          }
        }
      } catch (e) {
        debugPrint('ERROR handling widget intent: $e');
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _animationController.dispose();
    super.dispose();
  }

  // Handle app lifecycle changes
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (mounted && state == AppLifecycleState.resumed) {
      // Check for widget intent when app resumes
      _checkForWidgetIntent();
      
      // Note: Removed automatic home reset to prevent interrupting user workflow
      // The app should stay on whatever screen the user was on
    }
  }

  void _onItemTapped(int index) {
    if (mounted && index != _selectedIndex) {
      _animationController.forward().then((_) {
        if (mounted) {
          setState(() {
            _selectedIndex = index;
          });
          _animationController.reverse();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _screens[_selectedIndex],
      ),
      bottomNavigationBar: Container(
        height: 70 + MediaQuery.of(context).padding.bottom, // Increased from 60 to 70
        decoration: BoxDecoration(
          color: AppColors.appBackground,
          boxShadow: [
            BoxShadow(
              color: AppColors.black.withValues(alpha: 0.3),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(5, (index) {
            final colors = [
              AppColors.yellow,        // Fasting - yellow
              AppColors.red,    // Menstrual - red
              AppColors.pink,          // Home - pink
              AppColors.coral,         // Tasks - coral
              AppColors.orange,        // Routines - orange
            ];

            final isSelected = _selectedIndex == index;
            
            return GestureDetector(
              onTap: () => _onItemTapped(index),
              child: Container(
                width: 56, // Increased from 50 to 56
                height: 56, // Increased from 50 to 56
                margin: const EdgeInsets.symmetric(vertical: 7), // Increased margin slightly
                decoration: BoxDecoration(
                  color: isSelected 
                      ? colors[index].withValues(alpha: 0.25) // More visible when selected
                      : colors[index].withValues(alpha: 0.08), // Subtle when not selected
                  borderRadius: BorderRadius.circular(20),
                  border: isSelected
                    ? Border.all(color: colors[index].withValues(alpha: 0.6), width: 1.5)
                    : Border.all(color: colors[index].withValues(alpha: 0.6), width: 0.5)
                ),
                child: Center(
                  child: Icon(
                    [Icons.local_fire_department, Icons.local_florist_rounded, Icons.home_rounded, Icons.task_alt_rounded, Icons.auto_awesome_rounded][index],
                    color: colors[index].withValues(alpha: 0.7),
                    size: isSelected ? 33 : 30,
                  ),
                ),
              ),
            );
          }),
          ),
        ),
      ),
    );
  }
}

// Custom clipper for hexagon shape
class HexagonClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    final width = size.width;
    final height = size.height;
    final centerX = width / 2;
    final centerY = height / 2;
    final radius = min(width, height) / 2 * 0.85; // Slightly smaller to fit nicely

    // Create hexagon path
    for (int i = 0; i < 6; i++) {
      final angle = (i * pi / 3) - (pi / 2); // Start from top
      final x = centerX + radius * cos(angle);
      final y = centerY + radius * sin(angle);
      
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}