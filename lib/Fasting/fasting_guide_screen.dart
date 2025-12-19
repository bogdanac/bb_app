import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_styles.dart';
import 'fasting_utils.dart';
import 'fasting_prep_checklist.dart';

/// General fasting guide with dinner timing and refeed guidance for all fast types
class FastingGuideScreen extends StatelessWidget {
  final String? fastType;
  final DateTime? fastStartDate;

  const FastingGuideScreen({super.key, this.fastType, this.fastStartDate});

  bool get _showChecklists {
    // Show checklists for 48h+ fasts
    final hours = _getFastHours();
    return hours >= 48;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.dialogBackground,
      appBar: AppBar(
        backgroundColor: AppColors.dialogBackground,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(_getTitle()),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header based on fast type
            _buildHeaderCard(),
            const SizedBox(height: 20),

            // Preparation Checklist (for 48h+ fasts)
            if (_showChecklists) ...[
              FastingPrepChecklist(
                fastType: fastType ?? FastingUtils.quarterlyFast,
                fastStartDate: fastStartDate,
                isPreFast: true,
              ),
            ],

            // Pre-fast dinner guidance
            _buildDinnerSection(),
            const SizedBox(height: 16),

            // During the fast
            _buildDuringFastSection(),
            const SizedBox(height: 16),

            // Breaking the fast / Refeed
            _buildRefeedSection(),
            const SizedBox(height: 16),

            // Recovery Checklist (for 48h+ fasts)
            if (_showChecklists) ...[
              FastingPrepChecklist(
                fastType: fastType ?? FastingUtils.quarterlyFast,
                fastStartDate: fastStartDate,
                isPreFast: false,
              ),
            ],

            // Tips
            _buildTipsSection(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  String _getTitle() {
    switch (fastType) {
      case '24h weekly fast':
        return '24h Fast Guide';
      case '36h monthly fast':
        return '36h Fast Guide';
      case '48h quarterly fast':
        return '48h Fast Guide';
      case '3-day water fast':
        return '72h Fast Guide';
      case '14h short fast':
        return '14h Fast Guide';
      default:
        return 'Fasting Guide';
    }
  }

  int _getFastHours() {
    final duration = FastingUtils.getFastDuration(fastType ?? '24h weekly fast');
    return duration.inHours;
  }

  Widget _buildHeaderCard() {
    final hours = _getFastHours();
    final (title, subtitle, color) = _getHeaderInfo();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.3),
            color.withValues(alpha: 0.15),
          ],
        ),
        borderRadius: AppStyles.borderRadiusMedium,
      ),
      child: Column(
        children: [
          Icon(_getHeaderIcon(), color: color, size: 48),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.white70,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$hours hours',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  (String, String, Color) _getHeaderInfo() {
    switch (fastType) {
      case '24h weekly fast':
        return ('Weekly Fast', 'Fat burning & autophagy initiation', AppColors.coral);
      case '36h monthly fast':
        return ('Monthly Fast', 'Deep fat burning & cellular repair', AppColors.orange);
      case '48h quarterly fast':
        return ('Quarterly Fast', 'Dopamine reset & growth hormone boost', AppColors.purple);
      case '3-day water fast':
        return ('Water Fast', 'Biannual immune system reset', AppColors.pink);
      case '14h short fast':
        return ('Short Fast', 'Gentle metabolic reset', AppColors.yellow);
      default:
        return ('Fasting', 'Metabolic health', AppColors.coral);
    }
  }

  IconData _getHeaderIcon() {
    switch (fastType) {
      case '3-day water fast':
        return Icons.self_improvement;
      case '48h quarterly fast':
        return Icons.psychology;
      case '36h monthly fast':
        return Icons.local_fire_department;
      case '14h short fast':
        return Icons.spa;
      default:
        return Icons.timer;
    }
  }

  Widget _buildDinnerSection() {
    final hours = _getFastHours();
    final dinnerTips = _getDinnerTips();

    return _buildSection(
      title: 'Your Last Meal',
      icon: Icons.dinner_dining,
      color: AppColors.orange,
      children: [
        Text(
          hours >= 48
              ? 'Start preparing 2-3 days before with intermittent fasting (16:8).'
              : 'Have your last meal the evening before you start.',
          style: TextStyle(fontSize: 14, color: AppColors.white70, height: 1.5),
        ),
        const SizedBox(height: 12),
        ...dinnerTips.map((tip) => _buildBulletPoint(tip)),
        const SizedBox(height: 12),
        _buildMealSuggestion(),
      ],
    );
  }

  List<String> _getDinnerTips() {
    final hours = _getFastHours();
    if (hours >= 72) {
      return [
        'Begin 16:8 fasting 3 days before',
        'Reduce carbs and increase healthy fats',
        'Final dinner by 6 PM with low-carb, high-fat foods',
        'Avoid alcohol and sugar in the days leading up',
      ];
    } else if (hours >= 48) {
      return [
        'Start 16:8 fasting 2 days before',
        'Focus on healthy fats and moderate protein',
        'Final dinner by 6-7 PM',
        'Avoid heavy carbs - they make fasting harder',
      ];
    } else if (hours >= 36) {
      return [
        'Eat a satisfying but not heavy dinner',
        'Include healthy fats for satiety',
        'Finish eating by 7 PM',
        'Avoid sugar and refined carbs',
      ];
    } else {
      return [
        'Normal dinner, nothing special required',
        'Finish eating by 7-8 PM',
        'Include some protein and healthy fats',
        'Stay hydrated before bed',
      ];
    }
  }

  Widget _buildMealSuggestion() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.orange.withValues(alpha: 0.1),
        borderRadius: AppStyles.borderRadiusSmall,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.restaurant, color: AppColors.orange, size: 18),
              const SizedBox(width: 8),
              Text(
                'Ideal Pre-Fast Dinner',
                style: TextStyle(
                  color: AppColors.orange,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '- Salmon or fatty fish with olive oil\n'
            '- Large salad with avocado\n'
            '- Roasted vegetables\n'
            '- Bone broth as a starter',
            style: TextStyle(fontSize: 13, color: AppColors.white70, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildDuringFastSection() {
    return _buildSection(
      title: 'During Your Fast',
      icon: Icons.local_drink_rounded,
      color: AppColors.waterBlue,
      children: [
        _buildAllowedItem(Icons.water_drop, 'Pure water (flat or sparkling)', true),
        _buildAllowedItem(Icons.coffee, 'Black coffee (no cream or sugar)', true),
        _buildAllowedItem(Icons.emoji_food_beverage, 'Plain tea (herbal or regular)', true),
        _buildAllowedItem(Icons.bolt, 'Electrolytes (sodium, potassium, magnesium)', true),
        const SizedBox(height: 8),
        _buildInfoBox(
          'Stay hydrated! Aim for 2-3 liters of water daily. Add a pinch of salt if needed.',
          AppColors.waterBlue,
        ),
      ],
    );
  }

  Widget _buildRefeedSection() {
    final hours = _getFastHours();
    final refeedSteps = _getRefeedSteps();

    return _buildSection(
      title: 'Breaking Your Fast',
      icon: Icons.restaurant_menu,
      color: AppColors.coral,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.coral.withValues(alpha: 0.1),
            borderRadius: AppStyles.borderRadiusSmall,
          ),
          child: Text(
            hours >= 48
                ? 'CRITICAL: Breaking a long fast incorrectly can cause discomfort. Go slow!'
                : 'Ease back into eating - don\'t overload your digestive system.',
            style: TextStyle(
              color: AppColors.coral,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 16),
        ...refeedSteps.asMap().entries.map((entry) =>
            _buildStepItem(entry.key + 1, entry.value['title']!, entry.value['subtitle']!)),
        const SizedBox(height: 12),
        _buildWarningBox(),
      ],
    );
  }

  List<Map<String, String>> _getRefeedSteps() {
    final hours = _getFastHours();
    if (hours >= 72) {
      return [
        {'title': 'Start with bone broth', 'subtitle': 'Warm, soothing, easy to digest'},
        {'title': 'Wait 1 hour', 'subtitle': 'Then have 1-2 scrambled eggs with avocado'},
        {'title': 'Wait another hour', 'subtitle': 'Small meal with protein and healthy fats'},
        {'title': 'Avoid carbs for 24h', 'subtitle': 'Let your gut readjust gradually'},
      ];
    } else if (hours >= 48) {
      return [
        {'title': 'Start with bone broth or soup', 'subtitle': 'Light and easy to digest'},
        {'title': 'After 30-60 min', 'subtitle': 'Eggs or small portion of protein'},
        {'title': 'Next meal', 'subtitle': 'Normal portion with protein and fats'},
      ];
    } else if (hours >= 36) {
      return [
        {'title': 'Start light', 'subtitle': 'Soup, eggs, or avocado'},
        {'title': 'After 30 min', 'subtitle': 'Normal meal with protein and vegetables'},
      ];
    } else {
      return [
        {'title': 'Break with protein', 'subtitle': 'Eggs, chicken, or fish work great'},
        {'title': 'Add vegetables', 'subtitle': 'Fiber helps restart digestion'},
      ];
    }
  }

  Widget _buildWarningBox() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.red.withValues(alpha: 0.1),
        borderRadius: AppStyles.borderRadiusSmall,
        border: Border.all(color: AppColors.red.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_rounded, color: AppColors.red, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Avoid sugar, processed foods, and heavy carbs when breaking your fast.',
              style: TextStyle(fontSize: 13, color: AppColors.red),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTipsSection() {
    final tips = _getTipsForFastType();

    return _buildSection(
      title: 'Tips for Success',
      icon: Icons.lightbulb_outline,
      color: AppColors.yellow,
      children: tips.map((tip) => _buildBulletPoint(tip)).toList(),
    );
  }

  List<String> _getTipsForFastType() {
    final hours = _getFastHours();
    if (hours >= 72) {
      return [
        'The first time is hardest - it gets easier with practice',
        'Stay busy to keep your mind off food',
        'Light walking is fine, but avoid intense exercise',
        'Sleep may be lighter - this is normal',
        'Your body learns and adapts with each fast',
      ];
    } else if (hours >= 48) {
      return [
        'Keep busy with work or hobbies',
        'Hunger comes in waves - it will pass',
        'Mental clarity often increases around 36 hours',
        'Light activity is encouraged',
      ];
    } else if (hours >= 36) {
      return [
        'Plan to be done by lunch the next day',
        'Sleep through most of the fast',
        'Morning hunger is usually the strongest - push through',
      ];
    } else {
      return [
        'Finish dinner early, skip breakfast',
        'Black coffee helps suppress morning hunger',
        'Stay hydrated throughout',
      ];
    }
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required Color color,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.normalCardBackground,
        borderRadius: AppStyles.borderRadiusMedium,
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 10),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildBulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 6),
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: AppColors.white54,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.white70,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAllowedItem(IconData icon, String text, bool allowed) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(
            allowed ? Icons.check_circle : Icons.cancel,
            color: allowed ? AppColors.successGreen : AppColors.red,
            size: 20,
          ),
          const SizedBox(width: 10),
          Icon(icon, color: AppColors.white54, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.white70,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBox(String text, Color color) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: AppStyles.borderRadiusSmall,
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: color, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 12, color: AppColors.white70),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepItem(int step, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppColors.coral.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$step',
                style: TextStyle(
                  color: AppColors.coral,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
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
        ],
      ),
    );
  }
}
