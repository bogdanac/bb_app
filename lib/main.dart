import 'package:flutter/material.dart';
import 'Fasting/fasting_screen.dart';
import 'MenstrualCycle/cycle_tracking_screen.dart';
import 'Routines/routines_screen.dart';
import 'Tasks/todo_screen.dart';
import 'home.dart';
import 'Notifications//notification_service.dart'; // Import notification service
import 'dart:io'; // pentru Platform.isAndroid / Platform.isIOS
import 'package:permission_handler/permission_handler.dart'; // pentru cerere permisiuni

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize notifications
  final notificationService = NotificationService();
  await notificationService.initializeNotifications();

  if (Platform.isAndroid) {
    final status = await Permission.notification.request();
    if (!status.isGranted) {
      if (kDebugMode) print("Notifications permission denied");
      return;
    }
  }

  runApp(const BBetterApp());
}

class BBetterApp extends StatelessWidget {
  const BBetterApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BBetter',
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.orange,
        scaffoldBackgroundColor: const Color(0xFF1A1A1A),
        cardColor: const Color(0xFF2D2D2D),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFFFB74D), // Pastel orange
          secondary: Color(0xFFFFF176), // Pastel yellow
          tertiary: Color(0xFFF8BBD9), // Pastel pink
          surface: Color(0xFF2D2D2D),
          background: Color(0xFF1A1A1A),
          onPrimary: Colors.black87,
          onSecondary: Colors.black87,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF2D2D2D),
          elevation: 0,
          centerTitle: true,
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Color(0xFF2D2D2D),
          selectedItemColor: Color(0xFFFFB74D),
          unselectedItemColor: Colors.grey,
          type: BottomNavigationBarType.fixed,
        ),
      ),
      home: const MainScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with TickerProviderStateMixin, WidgetsBindingObserver  {
  int _selectedIndex = 2; // Mereu începe cu Home (index 2)
  late AnimationController _animationController;
  //final AutoBackupManager _autoBackup = AutoBackupManager();

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

    // Forțează resetarea la Home când se inițializează aplicația
    _resetToHome();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    //_autoBackup.dispose();
    _animationController.dispose();
    super.dispose();
  }

  // Metodă pentru a reseta la pagina Home
  void _resetToHome() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _selectedIndex = 2;
        });
      }
    });
  }

  // Handle app lifecycle changes for backup
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    // Resetează la Home când aplicația revine în foreground
    if (state == AppLifecycleState.resumed) {
      _resetToHome();
    }

    // Trigger backup when app goes to background
    if (state == AppLifecycleState.paused) {
      //_autoBackup.performManualBackup();
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