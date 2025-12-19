import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../theme/app_colors.dart';
import '../theme/app_styles.dart';
import '../Services/firebase_backup_service.dart';

/// Preparation and recovery checklist for extended fasts (48h+)
class FastingPrepChecklist extends StatefulWidget {
  final String fastType;
  final DateTime? fastStartDate;
  final bool isPreFast; // true = prep before, false = recovery after

  const FastingPrepChecklist({
    super.key,
    required this.fastType,
    this.fastStartDate,
    this.isPreFast = true,
  });

  @override
  State<FastingPrepChecklist> createState() => _FastingPrepChecklistState();
}

class _FastingPrepChecklistState extends State<FastingPrepChecklist> {
  Map<String, bool> _checklistItems = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadChecklist();
  }

  String get _checklistKey {
    final dateStr = widget.fastStartDate?.toIso8601String().split('T')[0] ?? 'current';
    final phase = widget.isPreFast ? 'prep' : 'recovery';
    return 'fasting_checklist_${phase}_$dateStr';
  }

  List<Map<String, dynamic>> get _checklistDefinition {
    if (widget.isPreFast) {
      return _getPrepChecklist();
    } else {
      return _getRecoveryChecklist();
    }
  }

  List<Map<String, dynamic>> _getPrepChecklist() {
    final is72h = widget.fastType == '3-day water fast';
    final is48h = widget.fastType == '48h quarterly fast';

    if (is72h) {
      return [
        {'id': 'if_day1', 'label': 'Day -3: Started 16:8 intermittent fasting', 'icon': Icons.schedule},
        {'id': 'if_day2', 'label': 'Day -2: Continued 16:8 fasting', 'icon': Icons.schedule},
        {'id': 'if_day3', 'label': 'Day -1: Final day of 16:8', 'icon': Icons.schedule},
        {'id': 'reduce_carbs', 'label': 'Reduced carbohydrate intake', 'icon': Icons.no_food},
        {'id': 'increase_fats', 'label': 'Increased healthy fats (avocado, olive oil, MCT)', 'icon': Icons.water_drop},
        {'id': 'stock_electrolytes', 'label': 'Stocked up on electrolytes', 'icon': Icons.bolt},
        {'id': 'bone_broth', 'label': 'Have bone broth ready for breaking fast', 'icon': Icons.soup_kitchen},
        {'id': 'clear_schedule', 'label': 'Cleared schedule of strenuous activities', 'icon': Icons.event_busy},
        {'id': 'final_dinner', 'label': 'Had low-carb, high-fat final dinner by 6-7 PM', 'icon': Icons.dinner_dining},
      ];
    } else if (is48h) {
      return [
        {'id': 'if_day1', 'label': 'Day -2: Started 16:8 intermittent fasting', 'icon': Icons.schedule},
        {'id': 'if_day2', 'label': 'Day -1: Continued 16:8 fasting', 'icon': Icons.schedule},
        {'id': 'reduce_carbs', 'label': 'Reduced carbohydrate intake', 'icon': Icons.no_food},
        {'id': 'increase_fats', 'label': 'Increased healthy fats', 'icon': Icons.water_drop},
        {'id': 'stock_electrolytes', 'label': 'Have electrolytes ready', 'icon': Icons.bolt},
        {'id': 'bone_broth', 'label': 'Have bone broth for breaking fast', 'icon': Icons.soup_kitchen},
        {'id': 'final_dinner', 'label': 'Had satisfying final dinner', 'icon': Icons.dinner_dining},
      ];
    } else {
      // 36h or shorter
      return [
        {'id': 'light_dinner', 'label': 'Had a light, low-carb dinner', 'icon': Icons.dinner_dining},
        {'id': 'hydrated', 'label': 'Well hydrated before starting', 'icon': Icons.water_drop},
        {'id': 'plan_break', 'label': 'Planned when/how to break fast', 'icon': Icons.restaurant},
      ];
    }
  }

  List<Map<String, dynamic>> _getRecoveryChecklist() {
    final is72h = widget.fastType == '3-day water fast';
    final is48h = widget.fastType == '48h quarterly fast';

    if (is72h) {
      return [
        {'id': 'bone_broth', 'label': 'Started with bone broth', 'icon': Icons.soup_kitchen},
        {'id': 'wait_1h', 'label': 'Waited 1 hour before next food', 'icon': Icons.timer},
        {'id': 'eggs_avocado', 'label': 'Had eggs with avocado', 'icon': Icons.egg},
        {'id': 'wait_1h_2', 'label': 'Waited another hour', 'icon': Icons.timer},
        {'id': 'small_meal', 'label': 'Had small meal with protein & fats', 'icon': Icons.restaurant},
        {'id': 'no_carbs_24h', 'label': 'Avoided carbs for 24 hours', 'icon': Icons.no_food},
        {'id': 'no_sugar', 'label': 'No sugar or processed foods', 'icon': Icons.block},
        {'id': 'gentle_eating', 'label': 'Eating slowly and mindfully', 'icon': Icons.self_improvement},
      ];
    } else if (is48h) {
      return [
        {'id': 'bone_broth', 'label': 'Started with bone broth or soup', 'icon': Icons.soup_kitchen},
        {'id': 'wait_30m', 'label': 'Waited 30-60 min before more food', 'icon': Icons.timer},
        {'id': 'protein', 'label': 'Had protein (eggs, fish, or chicken)', 'icon': Icons.egg},
        {'id': 'no_heavy_carbs', 'label': 'Avoided heavy carbs initially', 'icon': Icons.no_food},
        {'id': 'normal_meal', 'label': 'Returned to normal eating gradually', 'icon': Icons.restaurant},
      ];
    } else {
      return [
        {'id': 'light_break', 'label': 'Broke fast with light food', 'icon': Icons.restaurant},
        {'id': 'protein_first', 'label': 'Started with protein', 'icon': Icons.egg},
        {'id': 'no_binge', 'label': 'Avoided overeating', 'icon': Icons.self_improvement},
      ];
    }
  }

  Future<void> _loadChecklist() async {
    final prefs = await SharedPreferences.getInstance();
    final savedData = prefs.getString(_checklistKey);

    if (savedData != null) {
      _checklistItems = Map<String, bool>.from(jsonDecode(savedData));
    } else {
      // Initialize with all unchecked
      for (final item in _checklistDefinition) {
        _checklistItems[item['id']] = false;
      }
    }

    setState(() => _isLoading = false);
  }

  Future<void> _saveChecklist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_checklistKey, jsonEncode(_checklistItems));
    FirebaseBackupService.triggerBackup();
  }

  void _toggleItem(String id) {
    setState(() {
      _checklistItems[id] = !(_checklistItems[id] ?? false);
    });
    _saveChecklist();
  }

  int get _completedCount => _checklistItems.values.where((v) => v).length;
  int get _totalCount => _checklistDefinition.length;
  double get _progress => _totalCount > 0 ? _completedCount / _totalCount : 0;

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final color = widget.isPreFast ? AppColors.purple : AppColors.successGreen;
    final title = widget.isPreFast ? 'Preparation Checklist' : 'Recovery Checklist';
    final subtitle = widget.isPreFast
        ? 'Complete these before your ${widget.fastType}'
        : 'Follow these steps after your ${widget.fastType}';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.normalCardBackground,
        borderRadius: AppStyles.borderRadiusMedium,
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(
                widget.isPreFast ? Icons.checklist : Icons.healing,
                color: color,
                size: 24,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.white54,
                      ),
                    ),
                  ],
                ),
              ),
              // Progress indicator
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$_completedCount/$_totalCount',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: _progress,
              backgroundColor: color.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 6,
            ),
          ),

          const SizedBox(height: 16),

          // Checklist items
          ..._checklistDefinition.map((item) => _buildChecklistItem(
                item['id'],
                item['label'],
                item['icon'],
                color,
              )),

          // Completion message
          if (_progress == 1.0) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.successGreen.withValues(alpha: 0.15),
                borderRadius: AppStyles.borderRadiusSmall,
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: AppColors.successGreen, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    widget.isPreFast
                        ? 'You\'re ready for your fast!'
                        : 'Great job on your recovery!',
                    style: TextStyle(
                      color: AppColors.successGreen,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildChecklistItem(String id, String label, IconData icon, Color color) {
    final isChecked = _checklistItems[id] ?? false;

    return InkWell(
      onTap: () => _toggleItem(id),
      borderRadius: AppStyles.borderRadiusSmall,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: isChecked ? color : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isChecked ? color : AppColors.white54,
                  width: 2,
                ),
              ),
              child: isChecked
                  ? const Icon(Icons.check, color: Colors.white, size: 16)
                  : null,
            ),
            const SizedBox(width: 12),
            Icon(
              icon,
              size: 18,
              color: isChecked ? color : AppColors.white54,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  color: isChecked ? Colors.white : AppColors.white70,
                  decoration: isChecked ? TextDecoration.lineThrough : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Static helper to check if prep is complete for a fast
class FastingPrepHelper {
  static Future<bool> isPrepComplete(String fastType, DateTime fastDate) async {
    final prefs = await SharedPreferences.getInstance();
    final dateStr = fastDate.toIso8601String().split('T')[0];
    final key = 'fasting_checklist_prep_$dateStr';
    final savedData = prefs.getString(key);

    if (savedData == null) return false;

    final checklist = Map<String, bool>.from(jsonDecode(savedData));
    return checklist.values.every((v) => v);
  }

  static Future<double> getPrepProgress(String fastType, DateTime fastDate) async {
    final prefs = await SharedPreferences.getInstance();
    final dateStr = fastDate.toIso8601String().split('T')[0];
    final key = 'fasting_checklist_prep_$dateStr';
    final savedData = prefs.getString(key);

    if (savedData == null) return 0.0;

    final checklist = Map<String, bool>.from(jsonDecode(savedData));
    if (checklist.isEmpty) return 0.0;

    final completed = checklist.values.where((v) => v).length;
    return completed / checklist.length;
  }
}
