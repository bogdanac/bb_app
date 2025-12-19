import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_styles.dart';
import 'fasting_prep_checklist.dart';
import 'fasting_utils.dart';

class ExtendedFastGuideScreen extends StatelessWidget {
  final String? fastType;
  final DateTime? fastStartDate;

  const ExtendedFastGuideScreen({super.key, this.fastType, this.fastStartDate});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.dialogBackground,
      appBar: AppBar(
        backgroundColor: AppColors.dialogBackground,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('72h Fast Guide'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header card
            _buildHeaderCard(),
            const SizedBox(height: 20),

            // Preparation Checklist
            FastingPrepChecklist(
              fastType: fastType ?? FastingUtils.waterFast,
              fastStartDate: fastStartDate,
              isPreFast: true,
            ),

            // What is Autophagy
            _buildSection(
              title: 'What is Autophagy?',
              icon: Icons.auto_awesome,
              color: AppColors.purple,
              content: 'Autophagy = cellular cleanup\n\n'
                  'During extended fasting, your cells start recycling damaged proteins, '
                  'dysfunctional mitochondria, and even early-stage cancer cells.\n\n'
                  'Your body finally gets the chance to take out the accumulated trash '
                  'that\'s been causing inflammation and disease.',
            ),
            const SizedBox(height: 16),

            // Before You Start
            _buildSection(
              title: 'Before You Start (2-3 Days Before)',
              icon: Icons.calendar_today_rounded,
              color: AppColors.successGreen,
              content: null,
              customContent: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildBulletPoint(
                    'Begin intermittent fasting (16:8 method) at least 3 days before your extended fast.',
                  ),
                  _buildBulletPoint(
                    'Eat during an 8-hour window and fast for 16 hours.',
                  ),
                  _buildBulletPoint(
                    'This gradually shifts your metabolism to fat-burning mode.',
                  ),
                  const SizedBox(height: 12),
                  _buildBulletPoint(
                    'Reduce carbohydrates and increase healthy fats in the days before.',
                  ),
                  _buildBulletPoint(
                    'This starts shifting your body toward ketosis before you begin.',
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.successGreen.withValues(alpha: 0.1),
                      borderRadius: AppStyles.borderRadiusSmall,
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.restaurant, color: AppColors.successGreen, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Good fats: avocados, olive oil, grass-fed butter, MCT oil',
                            style: TextStyle(
                              color: AppColors.successGreen,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Timeline phases
            _buildPhaseCard(
              hours: '24-48',
              title: 'The Transition Phase',
              color: AppColors.orange,
              points: [
                'Around 36 hours, many report increased mental clarity and energy',
                'Ketones now fuel your brain',
                'Growth hormone rises 300%, preserving muscle',
                'Fat loss accelerates dramatically',
              ],
            ),
            const SizedBox(height: 16),

            _buildPhaseCard(
              hours: '48-72',
              title: 'The Healing Phase',
              color: AppColors.pink,
              points: [
                'The final 24 hours are where the most profound healing occurs',
                'Chronic joint pain can disappear',
                'Brain fog lifts as inflammation recedes',
                'Deep cellular repair and regeneration',
              ],
            ),
            const SizedBox(height: 16),

            // What you can consume
            _buildSection(
              title: 'What You Can Consume',
              icon: Icons.local_drink_rounded,
              color: AppColors.waterBlue,
              content: null,
              customContent: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildAllowedItem(Icons.water_drop, 'Pure water (flat or sparkling)', true),
                  _buildAllowedItem(Icons.coffee, 'Black coffee (no cream or sugar)', true),
                  _buildAllowedItem(Icons.emoji_food_beverage, 'Plain tea (herbal or regular)', true),
                  _buildAllowedItem(Icons.bolt, 'Electrolytes (sodium, potassium, magnesium)', true),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.waterBlue.withValues(alpha: 0.1),
                      borderRadius: AppStyles.borderRadiusSmall,
                      border: Border.all(color: AppColors.waterBlue.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: AppColors.waterBlue, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Purists only drink water. The above are acceptable for most.',
                            style: TextStyle(fontSize: 12, color: AppColors.white70),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Last meal before fasting
            _buildSection(
              title: 'Your Last Meal Before Fasting',
              icon: Icons.dinner_dining,
              color: AppColors.orange,
              content: null,
              customContent: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Timing is everything. Have your last meal the evening before you start fasting.',
                    style: TextStyle(fontSize: 14, color: AppColors.white70, height: 1.5),
                  ),
                  const SizedBox(height: 12),
                  _buildBulletPoint('Eat dinner by 6-7 PM the night before'),
                  _buildBulletPoint('Focus on healthy fats and moderate protein'),
                  _buildBulletPoint('Avoid heavy carbs - they spike insulin and make fasting harder'),
                  _buildBulletPoint('Include fiber-rich vegetables to feel satiated'),
                  const SizedBox(height: 12),
                  Container(
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
                          '• Salmon or fatty fish with olive oil\n'
                          '• Large salad with avocado\n'
                          '• Roasted vegetables\n'
                          '• Bone broth as a starter',
                          style: TextStyle(fontSize: 13, color: AppColors.white70, height: 1.5),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Breaking the fast
            _buildSection(
              title: 'How to Break Your Fast',
              icon: Icons.restaurant_menu,
              color: AppColors.coral,
              content: null,
              customContent: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.coral.withValues(alpha: 0.1),
                      borderRadius: AppStyles.borderRadiusSmall,
                    ),
                    child: Column(
                      children: [
                        Text(
                          'THE MOST IMPORTANT PART',
                          style: TextStyle(
                            color: AppColors.coral,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildStepItem(1, 'Start with bone broth', 'Warm, soothing, easy to digest'),
                  _buildStepItem(2, 'Wait 1 hour', 'Then have 1-2 scrambled eggs with avocado'),
                  _buildStepItem(3, 'Wait another hour', 'Have a small meal with protein and healthy fats'),
                  const SizedBox(height: 12),
                  Container(
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
                            'Avoid all carbs, sugar, and processed foods for at least 24 hours after',
                            style: TextStyle(fontSize: 13, color: AppColors.red),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Recovery Checklist
            FastingPrepChecklist(
              fastType: fastType ?? FastingUtils.waterFast,
              fastStartDate: fastStartDate,
              isPreFast: false,
            ),

            // Encouragement
            _buildSection(
              title: 'It Gets Easier',
              icon: Icons.trending_up,
              color: AppColors.yellow,
              content: 'Not eating for 72 hours is not easy.\n\n'
                  'The first time is the hardest. The second time is challenging but manageable. '
                  'By the third time, you\'ll be amazed at how easy it becomes.\n\n'
                  'Your body learns and adapts, making each subsequent fast more comfortable.\n\n'
                  'The benefits compound.',
            ),
            const SizedBox(height: 24),

            // Bottom call to action
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.pink.withValues(alpha: 0.2),
                    AppColors.purple.withValues(alpha: 0.2),
                  ],
                ),
                borderRadius: AppStyles.borderRadiusMedium,
                border: Border.all(color: AppColors.pink.withValues(alpha: 0.3)),
              ),
              child: Column(
                children: [
                  Icon(Icons.favorite_rounded, color: AppColors.pink, size: 32),
                  const SizedBox(height: 12),
                  Text(
                    'Fasting for 72 hours is the best medicine on earth',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'It triggers your body to "eat up" tumors, inflammation, and toxins.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.white70,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.pink.withValues(alpha: 0.3),
            AppColors.purple.withValues(alpha: 0.3),
          ],
        ),
        borderRadius: AppStyles.borderRadiusMedium,
      ),
      child: Column(
        children: [
          Icon(Icons.self_improvement, color: AppColors.pink, size: 48),
          const SizedBox(height: 12),
          Text(
            '3-Day Water Fast',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Biannual Immune Reset',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.white70,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildStatChip('72', 'hours'),
              const SizedBox(width: 24),
              _buildStatChip('2x', 'per year'),
              const SizedBox(width: 24),
              _buildStatChip('Day 7', 'of cycle'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.pink,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: AppColors.white54,
          ),
        ),
      ],
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required Color color,
    String? content,
    Widget? customContent,
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
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (content != null)
            Text(
              content,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.white70,
                height: 1.5,
              ),
            ),
          if (customContent != null) customContent,
        ],
      ),
    );
  }

  Widget _buildPhaseCard({
    required String hours,
    required String title,
    required Color color,
    required List<String> points,
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Hours $hours',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...points.map((point) => _buildBulletPoint(point)),
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
                  style: TextStyle(
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
