import 'package:flutter/material.dart';
import 'app_customization_service.dart';
import 'home_cards_screen.dart';
import '../Data/backup_screen.dart';
import '../Routines/widget_color_settings_screen.dart';
import '../shared/error_logs_screen.dart';
import '../Notifications/motion_alert_quick_setup.dart';
import '../WaterTracking/water_settings_screen.dart';
import '../FoodTracking/food_tracking_settings_screen.dart';
import '../Energy/energy_settings_screen.dart';
import '../theme/app_colors.dart';
import '../theme/app_styles.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  List<String> _primaryTabs = [];
  List<String> _secondaryTabs = [];
  Map<String, bool> _moduleStates = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final primaryTabs = await AppCustomizationService.loadPrimaryTabs();
    final secondaryOrder = await AppCustomizationService.loadSecondaryTabsOrder();
    final moduleStates = await AppCustomizationService.loadAllModuleStates();

    // Build secondary tabs list from enabled modules not in primary
    final allModules = AppCustomizationService.allModules;
    final secondaryTabs = <String>[];

    // First add from saved order
    for (final moduleKey in secondaryOrder) {
      if (moduleStates[moduleKey] == true && !primaryTabs.contains(moduleKey)) {
        secondaryTabs.add(moduleKey);
      }
    }

    // Then add any enabled modules not in either list
    for (final module in allModules) {
      if (moduleStates[module.key] == true &&
          !primaryTabs.contains(module.key) &&
          !secondaryTabs.contains(module.key)) {
        secondaryTabs.add(module.key);
      }
    }

    if (mounted) {
      setState(() {
        _primaryTabs = primaryTabs;
        _secondaryTabs = secondaryTabs;
        _moduleStates = moduleStates;
        _isLoading = false;
      });
    }
  }

  Future<void> _savePrimaryTabs() async {
    await AppCustomizationService.savePrimaryTabs(_primaryTabs);
  }

  Future<void> _saveSecondaryTabsOrder() async {
    await AppCustomizationService.saveSecondaryTabsOrder(_secondaryTabs);
  }

  void _toggleModule(String moduleKey, bool enabled) async {
    // Desktop: Simple toggle, no primary/secondary restrictions
    if (_isDesktop(context)) {
      await AppCustomizationService.setModuleEnabled(moduleKey, enabled);
      setState(() {
        _moduleStates[moduleKey] = enabled;
      });
      return;
    }

    // Mobile: Enforce 4-module primary restriction
    // If disabling a module in Primary and would go below 4, prevent it
    if (!enabled && _primaryTabs.contains(moduleKey) && _primaryTabs.length <= 4) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cannot disable: Primary features must have exactly 4 modules. Move to Secondary first.'),
            duration: Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    await AppCustomizationService.setModuleEnabled(moduleKey, enabled);

    setState(() {
      _moduleStates[moduleKey] = enabled;

      if (!enabled) {
        // Remove from both lists if disabled
        final wasInPrimary = _primaryTabs.remove(moduleKey);
        _secondaryTabs.remove(moduleKey);

        // If removed from Primary and now below 4, move first Secondary to Primary
        if (wasInPrimary && _primaryTabs.length < 4 && _secondaryTabs.isNotEmpty) {
          final firstSecondary = _secondaryTabs.removeAt(0);
          if (_moduleStates[firstSecondary] == true) {
            _primaryTabs.add(firstSecondary);
          }
        }
      } else {
        // Add to appropriate list when enabled
        if (_primaryTabs.length < 4) {
          _primaryTabs.add(moduleKey);
        } else if (!_primaryTabs.contains(moduleKey) && !_secondaryTabs.contains(moduleKey)) {
          _secondaryTabs.add(moduleKey);
        }
      }
    });

    await _savePrimaryTabs();
    await _saveSecondaryTabsOrder();
  }

  ModuleInfo? _getModuleInfo(String key) {
    return AppCustomizationService.allModules.firstWhere(
      (m) => m.key == key,
      orElse: () => ModuleInfo(
        key: key,
        label: key,
        icon: Icons.circle,
        color: AppColors.grey300,
        description: '',
        canBeDisabled: true,
      ),
    );
  }

  bool _isDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= 1024;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final isDesktop = _isDesktop(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Settings',
          style: TextStyle(
            fontSize: isDesktop ? 24 : 20,
            fontWeight: FontWeight.w600,
            letterSpacing: isDesktop ? 0.5 : 0,
          ),
        ),
        backgroundColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(isDesktop ? 32 : 16),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: isDesktop ? 1000 : 800),
            child: isDesktop ? _buildDesktopLayout() : _buildMobileLayout(),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileLayout() {
    // Build unified list: primary tabs + secondary tabs
    final allModules = [..._primaryTabs, ..._secondaryTabs];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
                // Section 1: App Features (unified list)
                _buildSectionHeader('App Features', ''),
                const SizedBox(height: 12),
                _buildUnifiedModuleList(allModules),

                const SizedBox(height: 32),

                // Section 2: Home Page Cards
                _buildSectionHeader('Home Page', ''),
                const SizedBox(height: 12),
                _buildNavigationCard(
                  icon: Icons.dashboard_customize_rounded,
                  iconColor: AppColors.pink,
                  title: 'Home Page Cards',
                  subtitle: 'Choose which cards appear and their order',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const HomeCardsScreen(),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 32),

                // Section 3: App & Data
                _buildSectionHeader('App & Data', ''),
                const SizedBox(height: 12),
                _buildNavigationCard(
                  icon: Icons.backup_rounded,
                  iconColor: AppColors.successGreen,
                  title: 'Backup & Restore',
                  subtitle: 'Export/import all your app data safely',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const BackupScreen(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
                _buildNavigationCard(
                  icon: Icons.palette_rounded,
                  iconColor: AppColors.coral,
                  title: 'Widget Colors',
                  subtitle: 'Customize widget backgrounds',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const WidgetColorSettingsScreen(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
                _buildNavigationCard(
                  icon: Icons.bug_report_rounded,
                  iconColor: AppColors.error,
                  title: 'Error Logs',
                  subtitle: 'View app error logs for debugging',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ErrorLogsScreen(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
                _buildNavigationCard(
                  icon: Icons.security_rounded,
                  iconColor: AppColors.yellow,
                  title: 'Motion Alert Setup',
                  subtitle: 'Night mode or 24/7 vacation mode',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const MotionAlertQuickSetup(),
                      ),
                    );
                  },
                ),
              ],
    );
  }

  Widget _buildDesktopLayout() {
    // Desktop: Reorderable list of all modules
    // Combine primary + secondary for display and reordering
    final allEnabledModules = [
      ..._primaryTabs,
      ..._secondaryTabs,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('App Features', 'Drag to reorder • Toggle to enable/disable'),
        const SizedBox(height: 20),

        // All modules list (reorderable)
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: AppStyles.borderRadiusLarge,
            border: Border.all(color: AppColors.normalCardBackground),
          ),
          child: Column(
            children: [
              // Home (always first, not movable)
              Container(
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: AppColors.normalCardBackground, width: 0.5),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const SizedBox(width: 32), // Space for drag handle
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.grey300.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.home_rounded, color: AppColors.grey300, size: 20),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Home',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: AppColors.grey300,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.grey300.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'Always First',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.grey300,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(width: 72), // Space for toggle + settings
                    ],
                  ),
                ),
              ),

              // Reorderable module list
              if (allEnabledModules.isNotEmpty)
                ReorderableListView(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  onReorder: (oldIndex, newIndex) {
                    setState(() {
                      if (oldIndex < newIndex) {
                        newIndex -= 1;
                      }
                      final module = allEnabledModules.removeAt(oldIndex);
                      allEnabledModules.insert(newIndex, module);

                      // Split back into primary (first 4) and secondary (rest)
                      _primaryTabs = allEnabledModules.take(4).toList();
                      _secondaryTabs = allEnabledModules.skip(4).toList();
                    });
                    _savePrimaryTabs();
                    _saveSecondaryTabsOrder();
                  },
                  children: allEnabledModules.asMap().entries.map((entry) {
                    final index = entry.key;
                    final moduleKey = entry.value;
                    final module = _getModuleInfo(moduleKey);
                    final isEnabled = _moduleStates[moduleKey] ?? false;
                    return _buildDesktopModuleItem(
                      key: ValueKey(moduleKey),
                      index: index,
                      module: module!,
                      isEnabled: isEnabled,
                      onToggle: (val) => _toggleModule(moduleKey, val),
                    );
                  }).toList(),
                ),

              // Disabled modules (not reorderable, shown at bottom)
              ...AppCustomizationService.allModules.where((m) {
                final isDisabled = _moduleStates[m.key] != true;
                return m.canBeDisabled && isDisabled;
              }).map((module) {
                return Container(
                  key: ValueKey('disabled_${module.key}'),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: AppColors.normalCardBackground, width: 0.5),
                    ),
                  ),
                  child: Opacity(
                    opacity: 0.5,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          const SizedBox(width: 32), // Space for drag handle
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: module.color.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(module.icon, color: module.color, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  module.label,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                if (module.description.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    module.description,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: AppColors.greyText,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          Switch(
                            value: false,
                            onChanged: (val) {
                              _toggleModule(module.key, val);
                              // Add to end of list when enabled
                              if (val && mounted) {
                                setState(() {
                                  _secondaryTabs.add(module.key);
                                });
                                _saveSecondaryTabsOrder();
                              }
                            },
                            activeTrackColor: module.color.withValues(alpha: 0.5),
                            thumbColor: WidgetStateProperty.resolveWith((states) {
                              if (states.contains(WidgetState.selected)) {
                                return module.color;
                              }
                              return null;
                            }),
                          ),
                          if (_hasSettings(module.key))
                            IconButton(
                              icon: const Icon(Icons.settings_outlined, size: 20),
                              color: AppColors.grey300,
                              onPressed: () => _openModuleSettings(module.key),
                            )
                          else
                            const SizedBox(width: 48), // Space for settings button
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),

        const SizedBox(height: 48),

        // App & Data section
        _buildSectionHeader('App & Data', 'Backup, colors, and logs'),
        const SizedBox(height: 20),
        _buildNavigationCard(
          icon: Icons.backup_rounded,
          iconColor: AppColors.successGreen,
          title: 'Backup & Restore',
          subtitle: 'Export/import all your app data safely',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const BackupScreen(),
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        _buildNavigationCard(
          icon: Icons.dashboard_customize_rounded,
          iconColor: AppColors.pink,
          title: 'Home Page Cards',
          subtitle: 'Choose which cards appear and their order',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const HomeCardsScreen(),
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        _buildNavigationCard(
          icon: Icons.palette_rounded,
          iconColor: AppColors.coral,
          title: 'Widget Colors',
          subtitle: 'Customize widget backgrounds',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const WidgetColorSettingsScreen(),
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        _buildNavigationCard(
          icon: Icons.bug_report_rounded,
          iconColor: AppColors.error,
          title: 'Error Logs',
          subtitle: 'View app error logs for debugging',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const ErrorLogsScreen(),
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        _buildNavigationCard(
          icon: Icons.security_rounded,
          iconColor: AppColors.yellow,
          title: 'Motion Alert Setup',
          subtitle: 'Night mode or 24/7 vacation mode',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const MotionAlertQuickSetup(),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildDesktopModuleItem({
    required Key key,
    required int index,
    required ModuleInfo module,
    required bool isEnabled,
    required Function(bool) onToggle,
  }) {
    return MouseRegion(
      cursor: SystemMouseCursors.grab,
      child: Container(
        key: key,
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: AppColors.normalCardBackground, width: 0.5),
          ),
        ),
        child: InkWell(
          hoverColor: module.color.withValues(alpha: 0.03),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                // Drag handle
                ReorderableDragStartListener(
                  index: index,
                  child: Icon(
                    Icons.drag_handle_rounded,
                    color: AppColors.grey300,
                    size: 20,
                  ),
                ),
            const SizedBox(width: 12),

            // Module icon
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: module.color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(module.icon, color: module.color, size: 20),
            ),
            const SizedBox(width: 12),

            // Module info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    module.label,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (module.description.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      module.description,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.greyText,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Toggle switch
            Switch(
              value: isEnabled,
              onChanged: onToggle,
              activeTrackColor: module.color.withValues(alpha: 0.5),
              thumbColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return module.color;
                }
                return null;
              }),
            ),

            // Settings button
            if (_hasSettings(module.key))
              IconButton(
                icon: const Icon(Icons.settings_outlined, size: 20),
                color: AppColors.grey300,
                onPressed: () => _openModuleSettings(module.key),
              )
            else
              const SizedBox(width: 48),
          ],
        ),
      ),
    ),
    ),
    );
  }

  Widget _buildSectionHeader(String title, String subtitle) {
    final isDesktop = _isDesktop(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: isDesktop ? 24 : 20,
            fontWeight: FontWeight.bold,
            color: AppColors.white,
            letterSpacing: isDesktop ? 0.5 : 0,
          ),
        ),
        if (subtitle.isNotEmpty) ...[
          SizedBox(height: isDesktop ? 8 : 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: isDesktop ? 15 : 14,
              color: AppColors.greyText,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildUnifiedModuleList(List<String> allModules) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: AppStyles.borderRadiusLarge,
        border: Border.all(color: AppColors.normalCardBackground),
      ),
      child: Column(
        children: [
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            onReorder: (oldIndex, newIndex) {
              setState(() {
                if (oldIndex < newIndex) newIndex -= 1;
                // Account for Home row at position (midpoint of primary + secondary)
                // Home is inserted visually but isn't in allModules
                final item = allModules.removeAt(oldIndex);
                allModules.insert(newIndex, item);

                // Split: first 4 = primary, rest = secondary
                _primaryTabs = allModules.take(4).toList();
                _secondaryTabs = allModules.skip(4).toList();
              });
              _savePrimaryTabs();
              _saveSecondaryTabsOrder();
            },
            itemCount: allModules.length,
            proxyDecorator: (child, index, animation) {
              return AnimatedBuilder(
                animation: animation,
                builder: (context, child) {
                  return Material(
                    color: Colors.transparent,
                    elevation: 4,
                    shadowColor: AppColors.black.withValues(alpha: 0.3),
                    borderRadius: AppStyles.borderRadiusLarge,
                    child: child,
                  );
                },
                child: child,
              );
            },
            itemBuilder: (context, index) {
              final moduleKey = allModules[index];
              final module = _getModuleInfo(moduleKey);
              if (module == null) return SizedBox.shrink(key: ValueKey(moduleKey));

              final isEnabled = _moduleStates[moduleKey] ?? false;
              final isPrimary = index < 4;

              return _buildUnifiedModuleItem(
                key: ValueKey(moduleKey),
                module: module,
                isEnabled: isEnabled,
                isPrimary: isPrimary,
                onToggle: (val) => _toggleModule(moduleKey, val),
                index: index,
              );
            },
          ),
          // Disabled modules at the bottom
          ...AppCustomizationService.allModules.where((m) {
            final isDisabled = _moduleStates[m.key] != true;
            return m.canBeDisabled && isDisabled && !allModules.contains(m.key);
          }).map((module) {
            return Container(
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: AppColors.normalCardBackground, width: 0.5),
                ),
              ),
              child: Opacity(
                opacity: 0.5,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: module.color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(module.icon, color: module.color, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          module.label,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Switch(
                        value: false,
                        onChanged: (val) => _toggleModule(module.key, val),
                        activeTrackColor: module.color.withValues(alpha: 0.5),
                        thumbColor: WidgetStateProperty.resolveWith((states) {
                          if (states.contains(WidgetState.selected)) {
                            return module.color;
                          }
                          return null;
                        }),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildUnifiedModuleItem({
    required Key key,
    required ModuleInfo module,
    required bool isEnabled,
    required bool isPrimary,
    required ValueChanged<bool> onToggle,
    required int index,
  }) {
    return Container(
      key: key,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.normalCardBackground, width: 0.5),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Show divider label between primary (index 3) and secondary (index 4)
          if (index == 4)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              color: AppColors.normalCardBackground.withValues(alpha: 0.3),
              child: const Text(
                'MENU',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.greyText,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1,
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              children: [
                // Drag handle
                ReorderableDragStartListener(
                  index: index,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Icon(
                      Icons.drag_handle_rounded,
                      color: AppColors.grey300,
                      size: 20,
                    ),
                  ),
                ),
                // Module icon
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: module.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(module.icon, color: module.color, size: 20),
                ),
                const SizedBox(width: 12),

                // Module name + location indicator
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        module.label,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        isPrimary ? 'Bottom bar' : 'Menu',
                        style: TextStyle(
                          fontSize: 11,
                          color: isPrimary ? module.color.withValues(alpha: 0.7) : AppColors.greyText,
                        ),
                      ),
                    ],
                  ),
                ),

                // Toggle switch
                Switch(
                  value: isEnabled,
                  onChanged: onToggle,
                  activeTrackColor: module.color.withValues(alpha: 0.5),
                  thumbColor: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.selected)) {
                      return module.color;
                    }
                    return null;
                  }),
                ),

                // Settings button (if module has settings)
                if (_hasSettings(module.key))
                  IconButton(
                    icon: const Icon(Icons.settings_outlined, size: 20),
                    color: AppColors.grey300,
                    onPressed: () => _openModuleSettings(module.key),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: AppStyles.borderRadiusLarge,
        border: Border.all(color: AppColors.normalCardBackground),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: AppStyles.borderRadiusLarge,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: AppStyles.borderRadiusSmall,
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.greyText,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.greyText),
            ],
          ),
        ),
      ),
    );
  }

  bool _hasSettings(String moduleKey) {
    // Define which modules have settings pages
    return const [
      'module_water_tracking',  // Water settings
      'module_food_tracking',   // Food settings
      'module_energy_tracking', // Energy settings
    ].contains(moduleKey);
  }

  void _openModuleSettings(String moduleKey) {
    Widget? settingsScreen;

    switch (moduleKey) {
      case 'module_water_tracking':
        settingsScreen = const WaterSettingsScreen();
        break;
      case 'module_food_tracking':
        settingsScreen = const FoodTrackingSettingsScreen();
        break;
      case 'module_energy_tracking':
        settingsScreen = const EnergySettingsScreen();
        break;
    }

    if (settingsScreen != null) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => settingsScreen!),
      );
    }
  }
}
