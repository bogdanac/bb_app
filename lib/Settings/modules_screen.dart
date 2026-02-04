import 'package:flutter/material.dart';
import 'app_customization_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_styles.dart';

class ModulesScreen extends StatefulWidget {
  const ModulesScreen({super.key});

  @override
  State<ModulesScreen> createState() => _ModulesScreenState();
}

class _ModulesScreenState extends State<ModulesScreen> {
  Map<String, bool> _moduleStates = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadModuleSettings();
  }

  Future<void> _loadModuleSettings() async {
    final states = await AppCustomizationService.loadAllModuleStates();
    if (mounted) {
      setState(() {
        _moduleStates = states;
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleModule(ModuleInfo module, bool enabled) async {
    // If disabling, show confirmation
    if (!enabled) {
      final dependentCards = AppCustomizationService.cardModuleDependency.entries
          .where((e) => e.value == module.key)
          .map((e) => AppCustomizationService.allCards
              .firstWhere((c) => c.key == e.key)
              .label)
          .toList();

      if (dependentCards.isNotEmpty && mounted) {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Disable ${module.label}?'),
            content: Text(
              'This will hide the ${module.label} tab and its Home cards:\n'
              '${dependentCards.map((c) => '• $c').join('\n')}\n\n'
              'You can re-enable it anytime.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(
                  'Disable',
                  style: TextStyle(color: AppColors.error),
                ),
              ),
            ],
          ),
        );
        if (confirmed != true) return;
      }
    }

    await AppCustomizationService.setModuleEnabled(module.key, enabled);
    setState(() {
      _moduleStates[module.key] = enabled;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('App Features'),
        backgroundColor: Colors.transparent,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Always-on Home
                  _buildHomeCard(),
                  const SizedBox(height: 8),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                    child: Text(
                      'Toggle features to show or hide their tabs',
                      style: TextStyle(
                        color: AppColors.greyText,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  // Toggleable modules
                  ...AppCustomizationService.allModules.map((module) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildModuleCard(module),
                    );
                  }),
                ],
              ),
            ),
    );
  }

  Widget _buildHomeCard() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: AppStyles.borderRadiusLarge,
        border: Border.all(
          color: AppColors.pink.withValues(alpha: 0.3),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.pink.withValues(alpha: 0.1),
                borderRadius: AppStyles.borderRadiusSmall,
              ),
              child: const Icon(
                Icons.home_rounded,
                color: AppColors.pink,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Home',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Always visible',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.greyText,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.lock_rounded,
              color: AppColors.greyText.withValues(alpha: 0.5),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModuleCard(ModuleInfo module) {
    final isEnabled = _moduleStates[module.key] ?? true;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: AppStyles.borderRadiusLarge,
        border: Border.all(
          color: isEnabled
              ? module.color.withValues(alpha: 0.3)
              : AppColors.normalCardBackground,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: module.color.withValues(alpha: isEnabled ? 0.1 : 0.05),
                borderRadius: AppStyles.borderRadiusSmall,
              ),
              child: Icon(
                module.icon,
                color: module.color.withValues(alpha: isEnabled ? 1.0 : 0.4),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    module.label,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: isEnabled ? null : AppColors.greyText,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    module.description,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.greyText,
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: isEnabled,
              activeThumbColor: module.color,
              onChanged: (value) => _toggleModule(module, value),
            ),
          ],
        ),
      ),
    );
  }
}
