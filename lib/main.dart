import 'package:flutter/material.dart';
import 'Fasting/fasting_screen.dart';
import 'MenstrualCycle/cycle_tracking_screen.dart';
import 'Routines/routines_screen.dart';
import 'Tasks/todo_screen.dart';
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
  const BBetterApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'I am fabulous',
      builder: (BuildContext context, Widget? child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        );
      },
      theme: AppTheme.theme,
      // Skip launcher in debug mode to avoid hot reload issues
      home: kDebugMode ? const MainScreen() : const LauncherScreen(),
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
      // Emergency failsafe - navigate to main screen after maximum 15 seconds regardless of what happens
      _emergencyTimer = Timer(const Duration(seconds: 15), () {
        if (mounted && Navigator.of(context).canPop() == false) {
          if (kDebugMode) {
            print("Emergency navigation triggered - launcher took too long");
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
            print("App initialization failed or timed out: $error");
          }
        });
      }

      // Navigate to main screen
      await Future.delayed(const Duration(milliseconds: 500));
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
      if (kDebugMode) print("Error in animation sequence: $e");
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
          print("Notification initialization failed or timed out: $error");
        }
      });
      
      // Initialize notification listener service for motion alerts with debug protection and timeout
      (() async {
        await NotificationListenerService.initialize();
        if (kDebugMode) {
          print("NotificationListenerService initialized successfully in debug mode");
        }
      })().timeout(Duration(seconds: 5)).catchError((error) {
        if (kDebugMode) {
          print("Warning: NotificationListenerService failed to initialize or timed out: $error");
          print("Motion alerts may not work, but app will continue normally");
        }
      });

      // Perform auto-backup check (non-blocking with timeout)
      BackupService.performAutoBackup().timeout(Duration(seconds: 8)).catchError((error) {
        if (kDebugMode) {
          print("Auto backup check failed or timed out: $error");
        }
      });

      // Request notification permissions (non-blocking with timeout)
      if (Platform.isAndroid) {
        Permission.notification.request().timeout(Duration(seconds: 5)).then((status) {
          if (!status.isGranted && kDebugMode) {
            print("Notifications permission denied");
          }
        }).catchError((error) {
          if (kDebugMode) print("Error requesting notification permission or timed out: $error");
        });
      }
    } catch (e) {
      if (kDebugMode) print("Error initializing app: $e");
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
          backgroundColor: _backgroundColor.value ?? AppColors.darkBackground,
          body: Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0.0, -0.3),
                radius: 1.2,
                colors: [
                  AppColors.redPrimary, // Red/Pink
                  AppColors.orange, // Orange
                  AppColors.purple, // Purple
                  AppColors.darkBackground, // Dark background
                ],
                stops: const [0.0, 0.4, 0.7, 1.0],
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
                              color: AppColors.redPrimary.withOpacity(0.4),
                              blurRadius: 25,
                              spreadRadius: 8,
                            ),
                            BoxShadow(
                              color: AppColors.orange.withOpacity(0.3),
                              blurRadius: 15,
                              spreadRadius: 3,
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
                              color: Colors.white.withOpacity(_textOpacity.value),
                              letterSpacing: 2,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Fabulous every day',
                            style: TextStyle(
                              fontSize: 16,
                              color: AppColors.orange.withOpacity(_textOpacity.value), // Orange color
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
    const RoutinesScreen(),
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

    // Reset to Home when app resumes (without infinite loop)
    if (mounted && state == AppLifecycleState.resumed && _selectedIndex != 2) {
      setState(() {
        _selectedIndex = 2;
      });
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
          color: const Color(0xFF1A1A1A),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
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
              AppColors.orange, // Orange for Fasting
              AppColors.pink, // Pink for Cycle  
              AppColors.coral, // Coral for Home (instead of yellow)
              AppColors.purple, // Purple for Tasks
              AppColors.yellow, // Yellow for Routines (morning routines)
            ];
            
            final icons = [
              Icons.timer_rounded,
              Icons.favorite_rounded, 
              Icons.home_rounded,
              Icons.task_alt_rounded,
              Icons.auto_awesome_rounded,
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
                      ? colors[index].withOpacity(0.25) // More subtle selected state
                      : colors[index].withOpacity(0.08), // Very subtle unselected
                  borderRadius: BorderRadius.circular(20),
                  border: isSelected 
                      ? Border.all(color: colors[index].withOpacity(0.6), width: 1.5) // Subtle border when selected
                      : null,
                ),
                child: Center(
                  child: Icon(
                    icons[index],
                    color: isSelected ? colors[index] : colors[index].withOpacity(0.7), // Colored icons
                    size: isSelected ? 32 : 30, // Increased from 28/26 to 32/30
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