import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'Fasting/fasting_screen.dart';
import 'MenstrualCycle/menstrual_cycle_screen.dart';
import 'MenstrualCycle/friends_screen.dart';
import 'Routines/routines_screen.dart';
import 'Habits/habits_screen.dart';
import 'Settings/app_customization_service.dart';
import 'Tasks/todo_screen.dart';
import 'Tasks/task_widget_service.dart';
import 'home.dart';
import 'Notifications/centralized_notification_manager.dart';
import 'Notifications/notification_listener_service.dart';
import 'Data/backup_service.dart';
import 'Services/firebase_backup_service.dart';
import 'Services/realtime_sync_service.dart';
import 'FoodTracking/food_tracking_service.dart';
import 'theme/app_colors.dart';
import 'theme/app_styles.dart';
import 'Auth/auth_wrapper.dart';
import 'Auth/login_screen.dart';
import 'shared/error_logger.dart';
import 'Routines/routine_recovery_helper.dart';
import 'Timers/timers_screen.dart';
import 'Chores/chores_screen.dart';
import 'Settings/settings_screen.dart';
import 'dart:io';
import 'dart:math';
import 'dart:async';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase first (other services depend on it)
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e, stackTrace) {
    ErrorLogger.logError(
      source: 'main.initializeFirebase',
      error: 'Firebase initialization failed (app will continue without cloud backup): $e',
      stackTrace: stackTrace.toString(),
    );
  }

  // Reset notification service on hot reload in debug mode
  if (kDebugMode) {
    NotificationListenerService.reset();
  }

  // Launch UI immediately - remaining services initialize in parallel in background
  runApp(const BBetterApp());

  // Run remaining initializations in parallel (non-blocking, after UI is up)
  Future.wait([
    // Firebase Backup Service
    FirebaseBackupService().initialize().catchError((e, stackTrace) {
      ErrorLogger.logError(
        source: 'main.initializeFirebaseBackupService',
        error: 'Firebase Backup Service initialization failed: $e',
        stackTrace: stackTrace.toString(),
      );
    }),
    // Real-time Sync Service
    RealtimeSyncService().initialize().catchError((e, stackTrace) {
      ErrorLogger.logError(
        source: 'main.initializeRealtimeSyncService',
        error: 'Real-time Sync Service initialization failed: $e',
        stackTrace: stackTrace.toString(),
      );
    }),
    // Routine recovery check
    RoutineRecoveryHelper.areRoutinesCorrupted().then((isCorrupted) async {
      if (isCorrupted) {
        final recovered = await RoutineRecoveryHelper.recoverRoutinesFromFirestore();
        ErrorLogger.logError(
          source: 'main.routineRecoveryCheck',
          error: recovered
              ? 'Routines successfully recovered from Firestore!'
              : 'Routine recovery failed - no backup found in Firestore',
          stackTrace: '',
        );
      }
    }).catchError((e, stackTrace) {
      ErrorLogger.logError(
        source: 'main.routineRecoveryCheck',
        error: 'Routine recovery check failed: $e',
        stackTrace: stackTrace.toString(),
      );
    }),
  ]);
}

/// Global navigator key for navigation from notification service
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class BBetterApp extends StatelessWidget {
  const BBetterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'BB',
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en', 'US'), // English
        Locale('ro', 'RO'), // Romanian
      ],
      builder: (BuildContext context, Widget? child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        );
      },
      theme: AppTheme.theme,
      // On web: skip launcher. On mobile: check auth first
      home: kIsWeb ? AuthWrapper(authenticatedHome: const MainScreen()) : const InitialScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

// Initial screen that checks auth and decides: launcher (if logged in) or login (if not)
class InitialScreen extends StatelessWidget {
  const InitialScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Check if Firebase is initialized before using FirebaseAuth
    try {
      Firebase.app();
    } catch (e) {
      // Firebase not initialized - go directly to main screen without auth
      if (kDebugMode) {
        debugPrint('Firebase not initialized, skipping auth check: $e');
      }
      return const LauncherScreen();
    }

    // Firebase is already initialized in main(), just check auth state
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        ErrorLogger.logError(
          source: 'MyApp.build',
          error: 'InitialScreen - ConnectionState: ${snapshot.connectionState}, Has data: ${snapshot.hasData}, Data: ${snapshot.data}, Error: ${snapshot.error}',
          stackTrace: '',
        );

        // Show loading while checking auth state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        // If there's an error, show login screen as fallback
        if (snapshot.hasError) {
          ErrorLogger.logError(
            source: 'MyApp.build',
            error: 'Auth stream error: ${snapshot.error}',
            context: {'action': 'showing login screen'},
          );
          return const LoginScreen();
        }

        // If logged in: show launcher screen
        if (snapshot.hasData && snapshot.data != null) {
          ErrorLogger.logError(
            source: 'MyApp.build',
            error: 'User logged in (${snapshot.data!.email}), showing launcher',
            stackTrace: '',
          );
          return const LauncherScreen();
        }

        // If not logged in: skip launcher, go directly to login
        ErrorLogger.logError(
          source: 'MyApp.build',
          error: 'User not logged in, showing login screen',
          stackTrace: '',
        );
        return const LoginScreen();
      },
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
      // Check for widget intents early to skip launcher for widget triggers
      bool hasWidgetIntent = false;
      bool hasTaskListIntent = false;
      try {
        hasWidgetIntent = await TaskWidgetService.checkForWidgetIntent();
        hasTaskListIntent = await TaskWidgetService.checkForTaskListIntent();
      } catch (e, stackTrace) {
        ErrorLogger.logError(
          source: 'LauncherScreen.checkWidgetIntent',
          error: 'Error checking widget intent: $e',
          stackTrace: stackTrace.toString(),
        );
      }

      // If any widget intent detected, skip launcher and go directly to main screen
      if ((hasWidgetIntent || hasTaskListIntent) && mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const MainScreen()),
        );
        return;
      }

      // Emergency failsafe - navigate after 8 seconds max
      _emergencyTimer = Timer(const Duration(seconds: 8), () {
        if (mounted && Navigator.of(context).canPop() == false) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const MainScreen()),
          );
        }
      });

      // Start initialization immediately (runs in parallel with animations)
      final initFuture = _initializeApp().timeout(
        const Duration(seconds: 6),
        onTimeout: () {},
      ).catchError((error, stackTrace) {
        ErrorLogger.logError(
          source: 'LauncherScreen.initializeApp',
          error: 'App initialization error: $error',
          stackTrace: stackTrace.toString(),
        );
      });

      // Run animations concurrently with initialization
      if (mounted) _backgroundController.forward();

      await Future.delayed(const Duration(milliseconds: 200));
      if (mounted) _logoController.forward();

      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) _textController.forward();

      // Wait for both: minimum display time (800ms total) AND init to complete
      await Future.wait([
        Future.delayed(const Duration(milliseconds: 600)), // remaining time (200+500+600 = 1300ms total)
        initFuture,
      ]);

      // Navigate to main screen
      if (mounted && Navigator.of(context).canPop() == false) {
        _emergencyTimer?.cancel();

        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => const MainScreen(),
            transitionDuration: const Duration(milliseconds: 500),
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
        _emergencyTimer?.cancel();
      }
    } catch (e, stackTrace) {
      ErrorLogger.logError(
        source: 'LauncherScreen.startAnimationSequence',
        error: 'Error in animation sequence: $e',
        stackTrace: stackTrace.toString(),
      );
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const MainScreen()),
        );
      }
    }
  }

  Future<void> _initializeApp() async {
    // All initialization runs in background - don't block navigation
    // This allows the app to show UI faster while services initialize

    // Notification manager - run in background, don't await
    (() async {
      final notificationManager = CentralizedNotificationManager();
      await notificationManager.initialize();
      await notificationManager.scheduleAllNotifications();
    })().timeout(Duration(seconds: 15)).catchError((error, stackTrace) async {
      await ErrorLogger.logError(
        source: 'LauncherScreen.initializeCentralizedNotificationManager',
        error: 'Centralized notification initialization error: $error',
        stackTrace: stackTrace.toString(),
      );
    });

    // Notification listener - run in background, don't await
    NotificationListenerService.initialize().timeout(Duration(seconds: 5)).catchError((error, stackTrace) async {
      await ErrorLogger.logError(
        source: 'LauncherScreen.initializeNotificationListenerService',
        error: 'WARNING: NotificationListenerService failed to initialize: $error',
        stackTrace: stackTrace.toString(),
      );
    });

    // Backup check - already non-blocking
    BackupService.checkStartupAutoBackup().timeout(Duration(seconds: 10)).catchError((error, stackTrace) async {
      await ErrorLogger.logError(
        source: 'LauncherScreen.checkStartupAutoBackup',
        error: 'Startup auto backup check error: $error',
        stackTrace: stackTrace.toString(),
      );
    });

    // Food tracking reset check - runs on app startup to handle period resets
    FoodTrackingService.checkAndPerformResetIfNeeded().timeout(Duration(seconds: 5)).catchError((error, stackTrace) async {
      await ErrorLogger.logError(
        source: 'LauncherScreen.checkFoodTrackingReset',
        error: 'Food tracking reset check error: $error',
        stackTrace: stackTrace.toString(),
      );
    });

    // Permission request - already non-blocking
    if (Platform.isAndroid) {
      Permission.notification.request().timeout(Duration(seconds: 5)).then((status) {
        if (!status.isGranted) {
          ErrorLogger.logError(
            source: 'LauncherScreen.initState',
            error: 'Notifications permission denied',
            stackTrace: '',
          );
        }
      }).catchError((error, stackTrace) async {
        await ErrorLogger.logError(
          source: 'LauncherScreen.requestNotificationPermission',
          error: 'Error requesting notification permission or timed out: $error',
          stackTrace: stackTrace.toString(),
        );
      });
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
  int _selectedIndex = 0;
  late AnimationController _animationController;
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  Map<String, bool> _moduleStates = {};
  List<String> _primaryTabs = [];
  List<String> _secondaryTabsOrder = [];

  void _openDrawer() => _scaffoldKey.currentState?.openDrawer();

  // Map of all possible module configs
  Map<String, _TabConfig> get _allModuleConfigs => {
    AppCustomizationService.moduleFasting: _TabConfig(
      screen: FastingScreen(onOpenDrawer: _openDrawer),
      icon: Icons.local_fire_department,
      label: 'Fasting',
      color: AppColors.successGreen,
      moduleKey: AppCustomizationService.moduleFasting,
    ),
    AppCustomizationService.moduleMenstrual: _TabConfig(
      screen: MenstrualCycleScreen(onOpenDrawer: _openDrawer),
      icon: Icons.local_florist_rounded,
      label: 'Cycle',
      color: AppColors.red,
      moduleKey: AppCustomizationService.moduleMenstrual,
    ),
    AppCustomizationService.moduleFriends: _TabConfig(
      screen: FriendsScreen(onOpenDrawer: _openDrawer),
      icon: Icons.people_rounded,
      label: 'Social',
      color: AppColors.lightPurple,
      moduleKey: AppCustomizationService.moduleFriends,
    ),
    AppCustomizationService.moduleTasks: _TabConfig(
      screen: TodoScreen(onOpenDrawer: _openDrawer),
      icon: Icons.task_alt_rounded,
      label: 'Tasks',
      color: AppColors.coral,
      moduleKey: AppCustomizationService.moduleTasks,
    ),
    AppCustomizationService.moduleRoutines: _TabConfig(
      screen: RoutinesScreen(onOpenDrawer: _openDrawer),
      icon: Icons.auto_awesome_rounded,
      label: 'Routines',
      color: AppColors.orange,
      moduleKey: AppCustomizationService.moduleRoutines,
    ),
    AppCustomizationService.moduleHabits: _TabConfig(
      screen: HabitsScreen(onOpenDrawer: _openDrawer),
      icon: Icons.track_changes_rounded,
      label: 'Habits',
      color: AppColors.yellow,
      moduleKey: AppCustomizationService.moduleHabits,
    ),
    AppCustomizationService.moduleTimers: _TabConfig(
      screen: TimersScreen(onOpenDrawer: _openDrawer),
      icon: Icons.timer_rounded,
      label: 'Timers',
      color: AppColors.purple,
      moduleKey: AppCustomizationService.moduleTimers,
    ),
    AppCustomizationService.moduleChores: _TabConfig(
      screen: ChoresScreen(onOpenDrawer: _openDrawer),
      icon: Icons.cleaning_services_rounded,
      label: 'Chores',
      color: AppColors.waterBlue,
      moduleKey: AppCustomizationService.moduleChores,
    ),
  };

  // Primary tabs (appear on bottom nav): ordered primary tabs + Home
  List<_TabConfig> get _primaryTabConfigs {
    final configs = <_TabConfig>[];
    final allConfigs = _allModuleConfigs;

    // Add primary tabs in order
    for (final moduleKey in _primaryTabs) {
      if (_moduleStates[moduleKey] == true && allConfigs.containsKey(moduleKey)) {
        configs.add(allConfigs[moduleKey]!);
      }
    }

    // Always add Home in the middle (after first half of primary tabs)
    final midpoint = (configs.length / 2).ceil();
    configs.insert(midpoint, _TabConfig(
      screen: HomeScreen(
        onNavigateToModule: _navigateToModule,
        onReloadSettings: reloadCustomizationSettings,
        onOpenDrawer: _openDrawer,
      ),
      icon: Icons.home_rounded,
      label: 'Home',
      color: AppColors.pink,
      isHome: true,
    ));

    return configs;
  }

  // Secondary tabs (appear in drawer): enabled but not primary
  List<_TabConfig> get _secondaryTabConfigs {
    final configs = <_TabConfig>[];
    final allConfigs = _allModuleConfigs;

    // Use saved order for secondary tabs
    for (final moduleKey in _secondaryTabsOrder) {
      if (_moduleStates[moduleKey] == true &&
          !_primaryTabs.contains(moduleKey) &&
          allConfigs.containsKey(moduleKey)) {
        configs.add(allConfigs[moduleKey]!);
      }
    }

    return configs;
  }

  // All enabled tabs (for desktop side nav): Home first, then primary + secondary
  List<_TabConfig> get _allEnabledTabConfigs {
    final configs = <_TabConfig>[];
    final allConfigs = _allModuleConfigs;

    // Add Home first
    configs.add(_TabConfig(
      screen: HomeScreen(
        onNavigateToModule: _navigateToModule,
        onReloadSettings: reloadCustomizationSettings,
        onOpenDrawer: _openDrawer,
      ),
      icon: Icons.home_rounded,
      label: 'Home',
      color: AppColors.pink,
      isHome: true,
    ));

    // Add all primary tabs in order
    for (final moduleKey in _primaryTabs) {
      if (_moduleStates[moduleKey] == true && allConfigs.containsKey(moduleKey)) {
        configs.add(allConfigs[moduleKey]!);
      }
    }

    // Add all secondary tabs
    for (final moduleKey in _secondaryTabsOrder) {
      if (_moduleStates[moduleKey] == true &&
          !_primaryTabs.contains(moduleKey) &&
          allConfigs.containsKey(moduleKey)) {
        configs.add(allConfigs[moduleKey]!);
      }
    }

    return configs;
  }

  bool _isDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= 1024;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _loadCustomizationSettings().then((_) {
      if (mounted) {
        final homeIndex = _primaryTabConfigs.indexWhere((c) => c.isHome);
        if (homeIndex >= 0 && _selectedIndex != homeIndex) {
          setState(() {
            _selectedIndex = homeIndex;
          });
        }
      }
    });
    _checkForWidgetIntent();
    _checkNotificationPermissions();
  }

  Future<void> _loadCustomizationSettings() async {
    await AppCustomizationService.migrateFromLegacyKeys();

    final moduleStates = await AppCustomizationService.loadAllModuleStates();
    final primaryTabs = await AppCustomizationService.loadPrimaryTabs();
    final secondaryTabsOrder = await AppCustomizationService.loadSecondaryTabsOrder();

    if (mounted) {
      setState(() {
        _moduleStates = moduleStates;
        _primaryTabs = primaryTabs;
        _secondaryTabsOrder = secondaryTabsOrder;

        // Clamp selected index if current tab no longer exists
        final tabs = _primaryTabConfigs;
        if (_selectedIndex >= tabs.length) {
          _selectedIndex = tabs.indexWhere((c) => c.isHome);
          if (_selectedIndex < 0) _selectedIndex = 0;
        }
      });
    }
  }

  int? _getTabIndexByModuleKey(String moduleKey) {
    // For desktop, search in all enabled tabs
    if (_isDesktop(context)) {
      final index = _allEnabledTabConfigs.indexWhere((c) => c.moduleKey == moduleKey);
      return index >= 0 ? index : null;
    }

    // For mobile, search in primary tabs
    final index = _primaryTabConfigs.indexWhere((c) => c.moduleKey == moduleKey);
    return index >= 0 ? index : null;
  }

  void _navigateToModule(String moduleKey) {
    final index = _getTabIndexByModuleKey(moduleKey);
    if (index != null) {
      _onItemTapped(index);
    }
  }

  Future<void> reloadCustomizationSettings() async {
    await _loadCustomizationSettings();
  }

  void _checkNotificationPermissions() async {
    // Give the app time to fully load before checking permissions
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      final notificationManager = CentralizedNotificationManager();
      await notificationManager.checkNotificationPermissions(context);
    }
  }

  void _checkForWidgetIntent() async {
    // Small delay to ensure the widget is ready
    await Future.delayed(const Duration(milliseconds: 100));

    if (mounted) {
      try {
        final hasWidgetIntent = await TaskWidgetService.checkForWidgetIntent();
        final hasTaskListIntent = await TaskWidgetService.checkForTaskListIntent();

        if (hasTaskListIntent && mounted) {
          // Task List Widget clicked - just navigate to tasks screen, no dialog
          final tasksIndex = _getTabIndexByModuleKey(AppCustomizationService.moduleTasks);
          if (tasksIndex != null) {
            setState(() {
              _selectedIndex = tasksIndex;
            });
          }
        } else if (hasWidgetIntent && mounted) {
          // Add Task Widget clicked - navigate to tasks screen and show dialog
          final tasksIndex = _getTabIndexByModuleKey(AppCustomizationService.moduleTasks);
          if (tasksIndex != null) {
            setState(() {
              _selectedIndex = tasksIndex;
            });
          }
          // Small delay to ensure navigation completes
          await Future.delayed(const Duration(milliseconds: 300));
          if (mounted) {
            await TaskWidgetService.showQuickTaskDialog(context);
          }
        }
      } catch (e, stackTrace) {
        await ErrorLogger.logError(
          source: 'MainScreen.checkForWidgetIntent',
          error: 'Error handling widget intent: $e',
          stackTrace: stackTrace.toString(),
        );
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
    final isDesktop = _isDesktop(context);

    if (isDesktop) {
      // Desktop: Show all enabled modules in side nav
      final allTabs = _allEnabledTabConfigs;
      if (allTabs.isEmpty) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      final safeIndex = _selectedIndex.clamp(0, allTabs.length - 1);
      return _buildDesktopLayout(allTabs, safeIndex);
    } else {
      // Mobile: Show primary tabs in bottom nav, secondary in drawer
      final primaryTabs = _primaryTabConfigs;
      final secondaryTabs = _secondaryTabConfigs;
      if (primaryTabs.isEmpty) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      final safeIndex = _selectedIndex.clamp(0, primaryTabs.length - 1);
      return _buildMobileLayout(primaryTabs, secondaryTabs, safeIndex);
    }
  }

  Widget _buildMobileLayout(List<_TabConfig> primaryTabs, List<_TabConfig> secondaryTabs, int safeIndex) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: _buildDrawer(secondaryTabs), // Always show drawer (Settings is always accessible)
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: primaryTabs[safeIndex].screen,
      ),
      bottomNavigationBar: _buildBottomNav(primaryTabs, safeIndex, hasDrawer: true), // Always show menu icon
    );
  }

  Widget _buildDesktopLayout(List<_TabConfig> allTabs, int safeIndex) {
    return Scaffold(
      body: Row(
        children: [
          // Left side navigation
          _buildSideNav(allTabs, safeIndex),
          // Main content
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: allTabs[safeIndex].screen,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSideNav(List<_TabConfig> tabs, int safeIndex) {
    return Container(
      width: 240,
      decoration: BoxDecoration(
        color: AppColors.grey900,
        border: Border(
          right: BorderSide(
            color: AppColors.grey700,
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          // App header
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    image: const DecorationImage(
                      image: AssetImage('assets/icon/ic_launcher.png'),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'bbetter',
                  style: TextStyle(
                    color: AppColors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Divider(color: AppColors.grey700, thickness: 1, height: 1),

          // Navigation items
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: tabs.length,
              itemBuilder: (context, index) {
                final tab = tabs[index];
                final isSelected = safeIndex == index;
                return _buildSideNavItem(
                  tab: tab,
                  isSelected: isSelected,
                  onTap: () => _onItemTapped(index),
                );
              },
            ),
          ),

          // Settings at bottom
          Divider(color: AppColors.grey700, thickness: 1, height: 1),
          _buildSideNavItem(
            tab: _TabConfig(
              screen: const SettingsScreen(),
              icon: Icons.settings_rounded,
              label: 'Settings',
              color: AppColors.grey300,
            ),
            isSelected: false,
            onTap: () {
              Navigator.push(context, MaterialPageRoute(
                builder: (context) => const SettingsScreen(),
              )).then((_) async {
                await reloadCustomizationSettings();
              });
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildSideNavItem({
    required _TabConfig tab,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: isSelected ? tab.color.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: isSelected
            ? Border.all(color: tab.color.withValues(alpha: 0.3), width: 1)
            : null,
          boxShadow: isSelected ? [
            BoxShadow(
              color: tab.color.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ] : null,
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          hoverColor: tab.color.withValues(alpha: 0.08),
          splashColor: tab.color.withValues(alpha: 0.15),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: tab.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    tab.icon,
                    color: tab.color,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    tab.label,
                    style: TextStyle(
                      color: isSelected ? AppColors.white : AppColors.grey200,
                      fontSize: 15,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
                if (isSelected)
                  Container(
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      color: tab.color,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDrawer(List<_TabConfig> secondaryTabs) {
    return Drawer(
      width: 260,
      backgroundColor: AppColors.grey900,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      image: const DecorationImage(
                        image: AssetImage('assets/icon/ic_launcher.png'),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'bbetter',
                    style: TextStyle(
                      color: AppColors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Divider(color: AppColors.grey700, thickness: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  // Secondary module tabs
                  if (secondaryTabs.isNotEmpty) ...[
                    const Padding(
                      padding: EdgeInsets.fromLTRB(20, 8, 20, 4),
                      child: Text(
                        'MORE MODULES',
                        style: TextStyle(
                          color: AppColors.grey300,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                    ...secondaryTabs.map((tab) => ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: tab.color.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(tab.icon, color: tab.color, size: 24),
                      ),
                      title: Text(
                        tab.label,
                        style: const TextStyle(
                          color: AppColors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(context, MaterialPageRoute(
                          builder: (context) => tab.screen,
                        ));
                      },
                    )),
                    const SizedBox(height: 8),
                    Divider(color: AppColors.grey700, thickness: 1),
                  ],
                  // Settings section
                  const Padding(
                    padding: EdgeInsets.fromLTRB(20, 8, 20, 4),
                    child: Text(
                      'SETTINGS',
                      style: TextStyle(
                        color: AppColors.grey300,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.grey300.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.settings_rounded, color: AppColors.grey300, size: 24),
                    ),
                    title: const Text(
                      'Settings',
                      style: TextStyle(
                        color: AppColors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(
                        builder: (context) => const SettingsScreen(),
                      )).then((_) async {
                        await reloadCustomizationSettings();
                      });
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNav(List<_TabConfig> tabs, int safeIndex, {required bool hasDrawer}) {
    return Container(
        height: 70 + MediaQuery.of(context).padding.bottom,
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
            children: List.generate(tabs.length, (index) {
              final tab = tabs[index];
              final isSelected = safeIndex == index;

              return GestureDetector(
                onTap: () => _onItemTapped(index),
                child: Container(
                  width: tabs.length > 5 ? 48 : 56,
                  height: tabs.length > 5 ? 48 : 56,
                  margin: const EdgeInsets.symmetric(vertical: 7),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? tab.color.withValues(alpha: 0.25)
                        : tab.color.withValues(alpha: 0.08),
                    borderRadius: AppStyles.borderRadiusXLarge,
                    border: isSelected
                      ? Border.all(color: tab.color.withValues(alpha: 0.6), width: 1.5)
                      : Border.all(color: tab.color.withValues(alpha: 0.6), width: 0.5),
                  ),
                  child: Center(
                    child: Icon(
                      tab.icon,
                      color: tab.color.withValues(alpha: 0.7),
                      size: isSelected ? (tabs.length > 5 ? 28 : 33) : (tabs.length > 5 ? 25 : 30),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
    );
  }
}

class _TabConfig {
  final Widget screen;
  final IconData icon;
  final String label;
  final Color color;
  final bool isHome;
  final String? moduleKey;

  const _TabConfig({
    required this.screen,
    required this.icon,
    required this.label,
    required this.color,
    this.isHome = false,
    this.moduleKey,
  });
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