import 'package:flutter/material.dart';
import 'Fasting/fasting_screen.dart';
import 'MenstrualCycle/cycle_tracking_screen.dart';
import 'Routines/routines_screen.dart';
import 'Tasks/todo_screen.dart';
import 'home.dart';
import 'Notifications/notification_service.dart';
import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(const BBetterApp());
}

class BBetterApp extends StatelessWidget {
  const BBetterApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'I am fabulous',
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: const Color(0xC11A1A1A),
        cardColor: const Color(0x6B2D2D2D),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xF272BDEC), // Pastel orange
          secondary: Color(0xFFFFF176), // Pastel yellow
          tertiary: Color(0xFFFFC774), // Pastel orange
          surface: Color(0xFF2D2D2D),
          surfaceContainerHighest: Color(0xC11A1A1A),
          onPrimary: Colors.black87,
          onSecondary: Colors.black87,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xE8FF0000),
          elevation: 0,
          centerTitle: true,
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Color(0x6B2D2D2D),
          selectedItemColor: Color(0xF272BDEC),
          unselectedItemColor: Colors.grey,
          type: BottomNavigationBarType.fixed,
        ),
      ),
      home: const LauncherScreen(),
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
      end: const Color(0xFF4A1B4A), // Dark fuchsia background
    ).animate(CurvedAnimation(
      parent: _backgroundController,
      curve: Curves.easeInOut,
    ));

    _startAnimationSequence();
  }

  void _startAnimationSequence() async {
    // Start background animation
    _backgroundController.forward();

    // Start logo animation
    await Future.delayed(const Duration(milliseconds: 300));
    _logoController.forward();

    // Start text animation
    await Future.delayed(const Duration(milliseconds: 800));
    _textController.forward();

    // Initialize notifications and navigate
    await Future.delayed(const Duration(milliseconds: 1200));
    await _initializeApp();

    // Navigate to main screen
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) {
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
    }
  }

  Future<void> _initializeApp() async {
    try {
      // Initialize notifications
      final notificationService = NotificationService();
      await notificationService.initializeNotifications();
      await notificationService.scheduleWaterReminders();

      // Request notification permissions (non-blocking)
      if (Platform.isAndroid) {
        Permission.notification.request().then((status) {
          if (!status.isGranted && kDebugMode) {
            print("Notifications permission denied");
          }
        }).catchError((error) {
          if (kDebugMode) print("Error requesting notification permission: $error");
        });
      }
    } catch (e) {
      if (kDebugMode) print("Error initializing app: $e");
      // Continue regardless of initialization errors
    }
  }

  @override
  void dispose() {
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
          backgroundColor: _backgroundColor.value ?? const Color(0xFF1A1A1A),
          body: Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0.0, -0.3),
                radius: 1.2,
                colors: [
                  const Color(0xFFFF6B9D), // Bright fuchsia
                  const Color(0xFFE91E63), // Deep pink
                  const Color(0xFF9C27B0), // Purple
                  const Color(0xFF673AB7), // Deep purple
                ],
                stops: const [0.0, 0.3, 0.7, 1.0],
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
                      angle: _logoRotation.value * 0.1,
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFFFF9800), // Bright orange
                              Color(0xFFFF6B35), // Orange-red
                              Color(0xFFFF1744), // Bright red-pink
                              Color(0xFFE91E63), // Fuchsia
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            stops: [0.0, 0.3, 0.7, 1.0],
                          ),
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFF6B9D).withOpacity(0.4),
                              blurRadius: 25,
                              spreadRadius: 8,
                            ),
                            BoxShadow(
                              color: const Color(0xFFFF9800).withOpacity(0.3),
                              blurRadius: 15,
                              spreadRadius: 3,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.apps_rounded, // Changed to a cube-like icon
                          color: Colors.white,
                          size: 60,
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
                            'BBetter',
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
                              color: const Color(0xFFFF9800).withOpacity(_textOpacity.value), // Orange color
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
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF6B9D)), // Fuchsia loading
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

  final List<BottomNavigationBarItem> _navItems = [
    const BottomNavigationBarItem(
      icon: Icon(Icons.timer_rounded),
      label: 'Fasting',
    ),
    const BottomNavigationBarItem(
      icon: Icon(Icons.favorite_rounded),
      label: 'Cycle',
    ),
    const BottomNavigationBarItem(
      icon: Icon(Icons.home_rounded),
      label: 'Home',
    ),
    const BottomNavigationBarItem(
      icon: Icon(Icons.task_alt_rounded),
      label: 'Tasks',
    ),
    const BottomNavigationBarItem(
      icon: Icon(Icons.auto_awesome_rounded),
      label: 'Routines',
    ),
  ];

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
    if (state == AppLifecycleState.resumed && _selectedIndex != 2) {
      setState(() {
        _selectedIndex = 2;
      });
    }
  }

  void _onItemTapped(int index) {
    if (index != _selectedIndex) {
      _animationController.forward().then((_) {
        setState(() {
          _selectedIndex = index;
        });
        _animationController.reverse();
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
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          items: _navItems,
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          elevation: 0,
        ),
      ),
    );
  }
}