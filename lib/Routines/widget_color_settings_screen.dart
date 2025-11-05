import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_colors.dart';
import '../theme/app_styles.dart';
import 'routine_widget_service.dart';
import '../Tasks/task_list_widget_service.dart';
import '../shared/snackbar_utils.dart';

class WidgetColorSettingsScreen extends StatefulWidget {
  const WidgetColorSettingsScreen({super.key});

  @override
  State<WidgetColorSettingsScreen> createState() => _WidgetColorSettingsScreenState();
}

class _WidgetColorSettingsScreenState extends State<WidgetColorSettingsScreen> {
  Color _routineColor = const Color(0xB3202020); // Transparent dark grey default
  Color _taskListColor = const Color(0xB3202020); // Transparent dark grey default
  bool _isLoading = true;

  // Predefined color options
  final List<Color> _colorOptions = [
    const Color(0xB3202020), // Transparent Dark Grey (default) - 70% opacity
    const Color(0xFF8CC4E8), // Soft Blue
    const Color(0xFF6EBDBD), // Nice Teal
    const Color(0xFFBF9FCA), // Soft Purple
    const Color(0xFF94A8B8), // Soft Blue Grey
    const Color(0xFF80C4BC), // Soft Mint Teal
    const Color(0xFF9DD6C7), // Soft Mint Green
    const Color(0xFFA8D5A1), // Soft Green
  ];

  @override
  void initState() {
    super.initState();
    _loadColors();
  }

  Future<void> _loadColors() async {
    final prefs = await SharedPreferences.getInstance();
    final defaultColor = const Color(0xB3202020).toARGB32(); // Transparent dark grey default for both

    // Get stored colors, use default if not set
    final routineColor = prefs.getInt('widget_routine_color') ?? defaultColor;
    final taskListColor = prefs.getInt('widget_tasklist_color') ?? defaultColor;

    setState(() {
      _routineColor = Color(routineColor);
      _taskListColor = Color(taskListColor);
      _isLoading = false;
    });
  }

  Future<void> _saveColor(String widgetType, Color color) async {
    final prefs = await SharedPreferences.getInstance();

    String key;
    switch (widgetType) {
      case 'routine':
        key = 'widget_routine_color';
        await prefs.setInt(key, color.toARGB32());
        await prefs.setInt('widget_background_color', color.toARGB32());
        setState(() => _routineColor = color);
        await RoutineWidgetService.refreshWidgetColor();
        break;
      case 'tasklist':
        key = 'widget_tasklist_color';
        await prefs.setInt(key, color.toARGB32());
        setState(() => _taskListColor = color);
        await TaskListWidgetService.updateWidget();
        break;
    }

    if (mounted) {
      SnackBarUtils.showSuccess(context, 'Widget color updated!');
    }
  }

  Widget _buildWidgetColorSection({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color currentColor,
    required String widgetType,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: AppStyles.borderRadiusLarge,
        border: Border.all(color: AppColors.normalCardBackground),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: currentColor.withValues(alpha: 0.3),
            borderRadius: AppStyles.borderRadiusSmall,
          ),
          child: Icon(icon, color: currentColor, size: 20),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.greyText,
          ),
        ),
        children: [
          const SizedBox(height: 8),
          // Color preview
          Container(
            width: double.infinity,
            height: 60,
            decoration: BoxDecoration(
              color: currentColor,
              borderRadius: AppStyles.borderRadiusMedium,
              border: Border.all(color: AppColors.greyText, width: 2),
            ),
            child: Center(
              child: Text(
                'Preview',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.greyText,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Color grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 5,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 1,
            ),
            itemCount: _colorOptions.length,
            itemBuilder: (context, index) {
              final color = _colorOptions[index];
              final isSelected = color.toARGB32() == currentColor.toARGB32();

              return GestureDetector(
                onTap: () => _saveColor(widgetType, color),
                child: Container(
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: AppStyles.borderRadiusSmall,
                    border: Border.all(
                      color: isSelected ? AppColors.lightGreen : AppColors.greyText,
                      width: isSelected ? 3 : 1,
                    ),
                  ),
                  child: isSelected
                      ? const Icon(
                          Icons.check_rounded,
                          color: AppColors.lightGreen,
                          size: 20,
                        )
                      : null,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Widget Colors'),
          backgroundColor: Colors.transparent,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Widget Colors'),
        backgroundColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildWidgetColorSection(
              title: 'Routine Widget',
              subtitle: 'Morning/evening routine steps',
              icon: Icons.format_list_numbered_rounded,
              currentColor: _routineColor,
              widgetType: 'routine',
            ),
            _buildWidgetColorSection(
              title: 'Task List Widget',
              subtitle: 'Today\'s tasks overview',
              icon: Icons.check_box_rounded,
              currentColor: _taskListColor,
              widgetType: 'tasklist',
            ),
          ],
        ),
      ),
    );
  }
}
