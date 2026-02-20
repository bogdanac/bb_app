import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_colors.dart';
import '../Notifications/centralized_notification_manager.dart';

/// Central service for managing all app customization preferences:
/// - Module toggles (tab visibility)
/// - Home card visibility and ordering
/// - Navigation bar position
class AppCustomizationService {
  static final AppCustomizationService _instance =
      AppCustomizationService._internal();
  factory AppCustomizationService() => _instance;
  AppCustomizationService._internal();

  // ============= Module Keys =============
  static const String moduleFasting = 'module_fasting_enabled';
  static const String moduleMenstrual = 'module_menstrual_enabled';
  static const String moduleFriends = 'module_friends_enabled';
  static const String moduleTasks = 'module_tasks_enabled';
  static const String moduleRoutines = 'module_routines_enabled';
  static const String moduleHabits = 'module_habits_enabled';
  static const String moduleTimers = 'module_timers_enabled';
  static const String moduleEnergy = 'module_energy_enabled';
  static const String moduleWater = 'module_water_enabled';
  static const String moduleFood = 'module_food_enabled';
  static const String moduleChores = 'module_chores_enabled';
  static const String moduleCalendar = 'module_calendar_enabled';

  // ============= Card Keys =============
  static const String cardMenstrual = 'card_menstrual_visible';
  static const String cardBatteryFlow = 'card_battery_flow_visible';
  static const String cardCalendar = 'card_calendar_visible';
  static const String cardFasting = 'card_fasting_visible';
  static const String cardFoodTracking = 'card_food_tracking_visible';
  static const String cardWaterTracking = 'card_water_tracking_visible';
  static const String cardHabits = 'card_habits_visible';
  static const String cardRoutines = 'card_routines_visible';
  static const String cardDailyTasks = 'card_daily_tasks_visible';
  static const String cardActivities = 'card_activities_visible';
  static const String cardProductivity = 'card_productivity_visible';
  static const String cardEndOfDayReview = 'card_end_of_day_review_visible';
  static const String cardChores = 'card_chores_visible';

  // ============= Productivity Card Schedule Keys =============
  static const String _productivityDaysKey = 'productivity_card_days';
  static const String _productivityStartHourKey = 'productivity_card_start_hour';
  static const String _productivityEndHourKey = 'productivity_card_end_hour';

  // ============= End of Day Review Keys =============
  static const String endOfDayReviewEnabled = 'end_of_day_review_enabled';
  static const String endOfDayReviewHour = 'end_of_day_review_hour';
  static const String endOfDayReviewMinute = 'end_of_day_review_minute';
  static const String endOfDayReviewEveningStart = 'end_of_day_review_evening_start';

  // ============= Other Keys =============
  static const String cardOrderKey = 'home_card_order';
  static const String primaryTabsKey = 'primary_tabs_list';
  static const String secondaryTabsKey = 'secondary_tabs_list';

  // Deprecated (kept for reference, no longer used)
  // static const String navPositionKey = 'nav_position';

  // ============= Constants =============
  static const int maxPrimaryTabs = 5; // Including Home tab

  // Legacy key for backward compatibility
  static const String legacyTimersKey = 'timers_module_enabled';
  static const String legacyMenstrualNotificationsKey =
      'menstrual_tracking_enabled';

  // ============= Card-to-Module Dependencies =============
  static const Map<String, String?> cardModuleDependency = {
    cardMenstrual: moduleMenstrual,
    cardFasting: moduleFasting,
    cardHabits: moduleHabits,
    cardRoutines: moduleRoutines,
    cardDailyTasks: moduleTasks,
    cardActivities: moduleTimers,
    cardProductivity: moduleTimers,
    cardBatteryFlow: moduleEnergy,
    cardCalendar: null,
    cardFoodTracking: moduleFood,
    cardWaterTracking: moduleWater,
    cardEndOfDayReview: null, // No module dependency - controlled by its own settings
    cardChores: moduleChores,
  };

  // ============= Default Card Order =============
  static const List<String> defaultCardOrder = [
    cardEndOfDayReview,
    cardProductivity,
    cardMenstrual,
    cardBatteryFlow,
    cardCalendar,
    cardFasting,
    cardFoodTracking,
    cardWaterTracking,
    cardHabits,
    cardRoutines,
    cardDailyTasks,
    cardChores,
    cardActivities,
  ];

  // ============= Module Metadata =============
  static const List<ModuleInfo> allModules = [
    ModuleInfo(
      key: moduleFasting,
      label: 'Fasting',
      description: 'Track fasts with cycle-based scheduling',
      icon: Icons.local_fire_department,
      color: AppColors.yellow,
      canBeDisabled: true,
    ),
    ModuleInfo(
      key: moduleMenstrual,
      label: 'Menstrual Cycle',
      description: 'Period tracking, ovulation, and cycle insights',
      icon: Icons.local_florist_rounded,
      color: AppColors.red,
      canBeDisabled: true,
    ),
    ModuleInfo(
      key: moduleFriends,
      label: 'Social',
      description: 'Circle of friends with friendship battery tracking',
      icon: Icons.people_rounded,
      color: AppColors.successGreen,
      canBeDisabled: true,
    ),
    ModuleInfo(
      key: moduleTasks,
      label: 'Tasks',
      description: 'Daily task management with categories',
      icon: Icons.task_alt_rounded,
      color: AppColors.coral,
      canBeDisabled: true,
    ),
    ModuleInfo(
      key: moduleRoutines,
      label: 'Routines',
      description: 'Multi-step routines with progress tracking',
      icon: Icons.auto_awesome_rounded,
      color: AppColors.orange,
      canBeDisabled: true,
    ),
    ModuleInfo(
      key: moduleHabits,
      label: 'Habits',
      description: 'Cycle-based habit tracking with streaks',
      icon: Icons.track_changes_rounded,
      color: AppColors.pastelGreen,
      canBeDisabled: true,
    ),
    ModuleInfo(
      key: moduleTimers,
      label: 'Timers',
      description: 'Countdown, Pomodoro & activity time tracking',
      icon: Icons.timer_rounded,
      color: AppColors.purple,
      canBeDisabled: true,
    ),
    ModuleInfo(
      key: moduleEnergy,
      label: 'Energy Tracking',
      description: 'Battery & flow tracking with daily goals',
      icon: Icons.bolt_rounded,
      color: AppColors.coral,
      canBeDisabled: true,
      showInNavigation: false, // Home feature only - no dedicated tab
    ),
    ModuleInfo(
      key: moduleWater,
      label: 'Water Tracking',
      description: 'Daily water intake goals',
      icon: Icons.water_drop_rounded,
      color: AppColors.waterBlue,
      canBeDisabled: true,
      showInNavigation: false, // Feature only - accessible via Home card and Settings
    ),
    ModuleInfo(
      key: moduleCalendar,
      label: 'Calendar Events',
      description: 'Upcoming events on Home card',
      icon: Icons.event_rounded,
      color: AppColors.lightPink,
      canBeDisabled: true,
      showInNavigation: false, // Feature only - accessible via Home card
    ),
    ModuleInfo(
      key: moduleFood,
      label: 'Food Tracking',
      description: 'Healthy vs processed food tracking',
      icon: Icons.restaurant_rounded,
      color: AppColors.pastelGreen,
      canBeDisabled: true,
      showInNavigation: false, // Home feature only - no dedicated tab
    ),
    ModuleInfo(
      key: moduleChores,
      label: 'Chores',
      description: 'Household chores with condition decay tracking',
      icon: Icons.checklist_rounded,
      color: AppColors.waterBlue,
      canBeDisabled: true,
    ),
  ];

  // ============= Card Metadata =============
  static const List<CardInfo> allCards = [
    CardInfo(
      key: cardMenstrual,
      label: 'Menstrual Cycle',
      description: 'Current cycle phase and predictions',
      icon: Icons.local_florist_rounded,
      color: AppColors.red,
      dependsOnModule: moduleMenstrual,
    ),
    CardInfo(
      key: cardBatteryFlow,
      label: 'Battery & Flow',
      description: 'Energy and flow tracking',
      icon: Icons.bolt_rounded,
      color: AppColors.coral,
      dependsOnModule: moduleEnergy,
    ),
    CardInfo(
      key: cardCalendar,
      label: 'Calendar Events',
      description: 'Upcoming calendar events',
      icon: Icons.event_rounded,
      color: AppColors.lightPink,
      dependsOnModule: moduleCalendar,
    ),
    CardInfo(
      key: cardFasting,
      label: 'Fasting',
      description: 'Active or scheduled fasts',
      icon: Icons.local_fire_department,
      color: AppColors.yellow,
      dependsOnModule: moduleFasting,
    ),
    CardInfo(
      key: cardFoodTracking,
      label: 'Food Tracking',
      description: 'Daily food log and target percentage',
      icon: Icons.restaurant_rounded,
      color: AppColors.pastelGreen,
      dependsOnModule: moduleFood,
    ),
    CardInfo(
      key: cardWaterTracking,
      label: 'Water Tracking',
      description: 'Daily water intake goal',
      icon: Icons.water_drop_rounded,
      color: AppColors.waterBlue,
      dependsOnModule: moduleWater,
    ),
    CardInfo(
      key: cardHabits,
      label: 'Habits',
      description: 'Uncompleted habits for today',
      icon: Icons.track_changes_rounded,
      color: AppColors.pastelGreen,
      dependsOnModule: moduleHabits,
    ),
    CardInfo(
      key: cardRoutines,
      label: 'Routines',
      description: 'Scheduled routines for today',
      icon: Icons.auto_awesome_rounded,
      color: AppColors.orange,
      dependsOnModule: moduleRoutines,
    ),
    CardInfo(
      key: cardDailyTasks,
      label: 'Daily Tasks',
      description: 'Your task list',
      icon: Icons.task_alt_rounded,
      color: AppColors.coral,
      dependsOnModule: moduleTasks,
    ),
    CardInfo(
      key: cardChores,
      label: 'Chores',
      description: 'Today\'s household chores',
      icon: Icons.checklist_rounded,
      color: AppColors.waterBlue,
      dependsOnModule: moduleChores,
    ),
    CardInfo(
      key: cardActivities,
      label: 'Activities',
      description: 'Quick start activity timers',
      icon: Icons.timer_rounded,
      color: AppColors.purple,
      dependsOnModule: moduleTimers,
    ),
    CardInfo(
      key: cardProductivity,
      label: 'Productivity',
      description: 'Quick pomodoro/countdown timer',
      icon: Icons.psychology_rounded,
      color: AppColors.purple,
      dependsOnModule: moduleTimers,
    ),
    CardInfo(
      key: cardEndOfDayReview,
      label: 'Daily Summary',
      description: 'End of day review (evening only)',
      icon: Icons.summarize_rounded,
      color: AppColors.purple,
      dependsOnModule: null,
    ),
  ];

  // ============= Migration =============

  /// Migrate from legacy keys to new standardized keys
  static Future<void> migrateFromLegacyKeys() async {
    final prefs = await SharedPreferences.getInstance();

    // Migrate timers_module_enabled -> module_timers_enabled
    if (prefs.containsKey(legacyTimersKey) &&
        !prefs.containsKey(moduleTimers)) {
      final value = prefs.getBool(legacyTimersKey) ?? false;
      await prefs.setBool(moduleTimers, value);
    }
  }

  // ============= Module Management =============

  // Modules that default to OFF on fresh install (MOBILE ONLY)
  // On desktop/web, all modules default to ON
  static const Set<String> _modulesDefaultOffMobile = {
    moduleFood,
    moduleEnergy,
    moduleMenstrual,
    moduleFriends,
    moduleChores,
  };

  /// Load all module states
  /// On desktop/web, all modules default to ON
  /// On mobile, some modules default to OFF (defined in _modulesDefaultOffMobile)
  static Future<Map<String, bool>> loadAllModuleStates() async {
    final prefs = await SharedPreferences.getInstance();
    // On web/desktop, all modules default to ON
    final isDesktop = _isDesktopPlatform();
    return {
      for (var module in allModules)
        module.key: prefs.getBool(module.key) ?? (isDesktop ? true : !_modulesDefaultOffMobile.contains(module.key)),
    };
  }

  /// Check if running on desktop platform (web, Windows, macOS, Linux)
  static bool _isDesktopPlatform() {
    if (kIsWeb) return true;
    try {
      return Platform.isWindows || Platform.isMacOS || Platform.isLinux;
    } catch (_) {
      return false;
    }
  }

  /// Check if a specific module is enabled
  static Future<bool> isModuleEnabled(String moduleKey) async {
    final prefs = await SharedPreferences.getInstance();
    // On web/desktop, all modules default to ON
    // On mobile, modules in _modulesDefaultOffMobile default to false
    final isDesktop = _isDesktopPlatform();
    return prefs.getBool(moduleKey) ?? (isDesktop ? true : !_modulesDefaultOffMobile.contains(moduleKey));
  }

  /// Enable or disable a module
  static Future<void> setModuleEnabled(String moduleKey, bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(moduleKey, enabled);

    // Backward compatibility: menstrual module toggle also controls notifications
    if (moduleKey == moduleMenstrual) {
      await prefs.setBool(legacyMenstrualNotificationsKey, enabled);
      // Reschedule notifications
      final notificationManager = CentralizedNotificationManager();
      await notificationManager.forceRescheduleAll();
    }
  }

  // ============= Card Visibility Management =============

  /// Get platform-specific key for card settings (web stores separately from mobile)
  static String _cardKey(String cardKey) {
    return kIsWeb ? 'web_$cardKey' : cardKey;
  }

  /// Get platform-specific card order key
  static String get _platformCardOrderKey {
    return kIsWeb ? 'web_$cardOrderKey' : cardOrderKey;
  }

  /// Load all card visibility states
  static Future<Map<String, bool>> loadAllCardStates() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      for (var card in allCards)
        card.key: prefs.getBool(_cardKey(card.key)) ?? true,
    };
  }

  /// Check if a specific card is set to visible (ignores module dependency)
  static Future<bool> isCardVisible(String cardKey) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_cardKey(cardKey)) ?? true;
  }

  /// Set card visibility
  static Future<void> setCardVisible(String cardKey, bool visible) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_cardKey(cardKey), visible);
  }

  /// Check if a card should be shown (considers both toggle AND module dependency)
  static Future<bool> isCardEffectivelyVisible(String cardKey) async {
    final cardVisible = await isCardVisible(cardKey);
    if (!cardVisible) return false;

    // Check module dependency
    final moduleKey = cardModuleDependency[cardKey];
    if (moduleKey == null) return true;

    return await isModuleEnabled(moduleKey);
  }

  // ============= Card Ordering =============

  /// Load card display order
  static Future<List<String>> loadCardOrder() async {
    final prefs = await SharedPreferences.getInstance();
    final orderList = prefs.getStringList(_platformCardOrderKey);
    if (orderList == null || orderList.isEmpty) {
      return List.from(defaultCardOrder);
    }

    // Merge with default order to handle new cards
    final result = List<String>.from(orderList);
    for (var cardKey in defaultCardOrder) {
      if (!result.contains(cardKey)) {
        result.add(cardKey);
      }
    }
    return result;
  }

  /// Save card display order
  static Future<void> saveCardOrder(List<String> order) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_platformCardOrderKey, order);
  }

  // ============= Primary Tabs Management =============

  /// Load primary tabs list (module keys that appear on bottom nav)
  /// Returns list of module keys. Home is always primary but not in this list.
  static Future<List<String>> loadPrimaryTabs() async {
    final prefs = await SharedPreferences.getInstance();
    final savedList = prefs.getStringList(primaryTabsKey);

    if (savedList != null && savedList.isNotEmpty) {
      return savedList;
    }

    // Default: first 4 enabled modules are primary (to leave room for Home + 4 = 5 total)
    final enabledModules = await getEnabledModuleKeys();
    return enabledModules.take(maxPrimaryTabs - 1).toList();
  }

  /// Save primary tabs list
  static Future<void> savePrimaryTabs(List<String> moduleKeys) async {
    if (moduleKeys.length > maxPrimaryTabs - 1) {
      throw ArgumentError('Cannot have more than ${maxPrimaryTabs - 1} primary tabs (Home is always primary)');
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(primaryTabsKey, moduleKeys);
  }

  /// Check if a module is marked as primary
  static Future<bool> isModulePrimary(String moduleKey) async {
    final primaryTabs = await loadPrimaryTabs();
    return primaryTabs.contains(moduleKey);
  }

  /// Get modules that should appear in drawer (enabled but not primary)
  static Future<List<String>> getSecondaryModuleKeys() async {
    final enabledModules = await getEnabledModuleKeys();
    final primaryTabs = await loadPrimaryTabs();
    return enabledModules.where((key) => !primaryTabs.contains(key)).toList();
  }

  // ============= Secondary Tabs Management =============

  /// Load secondary tabs order (module keys that appear in drawer)
  /// Returns ordered list of secondary module keys
  static Future<List<String>> loadSecondaryTabsOrder() async {
    final prefs = await SharedPreferences.getInstance();
    final savedList = prefs.getStringList(secondaryTabsKey);

    // Get actual secondary modules (enabled but not primary)
    final secondaryModules = await getSecondaryModuleKeys();

    if (savedList != null && savedList.isNotEmpty) {
      // Merge saved order with current secondary modules
      final result = <String>[];

      // Add saved items that are still secondary
      for (final key in savedList) {
        if (secondaryModules.contains(key)) {
          result.add(key);
        }
      }

      // Add any new secondary modules not in saved order
      for (final key in secondaryModules) {
        if (!result.contains(key)) {
          result.add(key);
        }
      }

      return result;
    }

    // Default: return secondary modules in default order
    return secondaryModules;
  }

  /// Save secondary tabs order
  static Future<void> saveSecondaryTabsOrder(List<String> moduleKeys) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(secondaryTabsKey, moduleKeys);
  }

  // ============= Bulk Operations =============

  /// Get list of enabled module keys
  static Future<List<String>> getEnabledModuleKeys() async {
    final states = await loadAllModuleStates();
    return states.entries
        .where((entry) => entry.value)
        .map((entry) => entry.key)
        .toList();
  }

  // ============= Productivity Card Schedule =============

  /// Get days when productivity card should be visible (1=Monday, 7=Sunday)
  static Future<Set<int>> getProductivityDays() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_productivityDaysKey) ?? ['1', '2', '3', '4', '5', '6', '7'];
    return list.map((s) => int.parse(s)).toSet();
  }

  /// Set days when productivity card should be visible
  static Future<void> setProductivityDays(Set<int> days) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_productivityDaysKey, days.map((d) => d.toString()).toList());
  }

  /// Get start and end hours for productivity card visibility (0-23, 1-24)
  static Future<(int, int)> getProductivityHours() async {
    final prefs = await SharedPreferences.getInstance();
    final start = prefs.getInt(_productivityStartHourKey) ?? 0;
    final end = prefs.getInt(_productivityEndHourKey) ?? 24;
    return (start, end);
  }

  /// Set start and end hours for productivity card visibility
  static Future<void> setProductivityHours(int start, int end) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_productivityStartHourKey, start);
    await prefs.setInt(_productivityEndHourKey, end);
  }

  /// Check if productivity card should be visible based on current day/time
  static Future<bool> isProductivityCardScheduledNow() async {
    final now = DateTime.now();
    final days = await getProductivityDays();
    if (!days.contains(now.weekday)) return false;

    final (start, end) = await getProductivityHours();
    final hour = now.hour;
    return hour >= start && hour < end;
  }

  // ============= End of Day Review Settings =============

  /// Check if end of day review is enabled
  static Future<bool> isEndOfDayReviewEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(endOfDayReviewEnabled) ?? true; // Default ON
  }

  /// Enable or disable end of day review
  static Future<void> setEndOfDayReviewEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(endOfDayReviewEnabled, enabled);
    // Trigger notification reschedule
    final notificationManager = CentralizedNotificationManager();
    await notificationManager.forceRescheduleAll();
  }

  /// Get end of day review notification time (hour, minute)
  static Future<(int, int)> getEndOfDayReviewTime() async {
    final prefs = await SharedPreferences.getInstance();
    final hour = prefs.getInt(endOfDayReviewHour) ?? 21; // Default 9 PM
    final minute = prefs.getInt(endOfDayReviewMinute) ?? 0;
    return (hour, minute);
  }

  /// Set end of day review notification time
  static Future<void> setEndOfDayReviewTime(int hour, int minute) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(endOfDayReviewHour, hour);
    await prefs.setInt(endOfDayReviewMinute, minute);
    // Trigger notification reschedule
    final notificationManager = CentralizedNotificationManager();
    await notificationManager.forceRescheduleAll();
  }

  /// Get evening start hour (when card becomes visible)
  static Future<int> getEveningStartHour() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(endOfDayReviewEveningStart) ?? 20; // Default 8 PM
  }

  /// Set evening start hour
  static Future<void> setEveningStartHour(int hour) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(endOfDayReviewEveningStart, hour);
  }

  /// Check if it's currently evening time (for card/button visibility)
  static Future<bool> isEveningTime() async {
    final eveningStart = await getEveningStartHour();
    final now = DateTime.now();
    return now.hour >= eveningStart;
  }

  // ============= Calendar Settings =============
  static const String _calendarFirstDayOfWeek = 'calendar_first_day_of_week';

  /// Get the first day of week for calendars
  /// Returns 1 for Monday (default), 7 for Sunday
  static Future<int> getCalendarFirstDayOfWeek() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_calendarFirstDayOfWeek) ?? 1; // Default Monday
  }

  /// Set the first day of week for calendars
  /// Use 1 for Monday, 7 for Sunday
  static Future<void> setCalendarFirstDayOfWeek(int day) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_calendarFirstDayOfWeek, day);
  }

  /// Check if calendar starts on Monday
  static Future<bool> isCalendarMondayFirst() async {
    final firstDay = await getCalendarFirstDayOfWeek();
    return firstDay == 1;
  }
}

// ============= Data Classes =============

/// Metadata for a toggleable module/feature
class ModuleInfo {
  final String key;
  final String label;
  final String description;
  final IconData icon;
  final Color color;
  final bool canBeDisabled;
  final bool showInNavigation; // Whether this module appears as a tab option

  const ModuleInfo({
    required this.key,
    required this.label,
    required this.description,
    required this.icon,
    required this.color,
    required this.canBeDisabled,
    this.showInNavigation = true, // Default to true for backward compatibility
  });
}

/// Metadata for a home page card
class CardInfo {
  final String key;
  final String label;
  final String description;
  final IconData icon;
  final Color color;
  final String? dependsOnModule;

  const CardInfo({
    required this.key,
    required this.label,
    required this.description,
    required this.icon,
    required this.color,
    required this.dependsOnModule,
  });

  /// Whether this card requires a module to be enabled
  bool get hasModuleDependency => dependsOnModule != null;
}
