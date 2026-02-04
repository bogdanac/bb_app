import 'package:flutter/material.dart';
import 'app_customization_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_styles.dart';

class NavPositionScreen extends StatefulWidget {
  const NavPositionScreen({super.key});

  @override
  State<NavPositionScreen> createState() => _NavPositionScreenState();
}

class _NavPositionScreenState extends State<NavPositionScreen> {
  String _position = 'bottom';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPosition();
  }

  Future<void> _loadPosition() async {
    final position = await AppCustomizationService.getNavPosition();
    if (mounted) {
      setState(() {
        _position = position;
        _isLoading = false;
      });
    }
  }

  Future<void> _setPosition(String position) async {
    await AppCustomizationService.setNavPosition(position);
    setState(() {
      _position = position;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Navigation Style'),
        backgroundColor: Colors.transparent,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(bottom: 16),
                    child: Text(
                      'Choose where the navigation bar appears',
                      style: TextStyle(
                        color: AppColors.greyText,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  _buildPositionOption(
                    value: 'bottom',
                    label: 'Bottom',
                    description: 'Traditional bottom navigation bar',
                    icon: Icons.border_bottom_rounded,
                  ),
                  const SizedBox(height: 12),
                  _buildPositionOption(
                    value: 'left',
                    label: 'Left Side',
                    description: 'Vertical navigation on the left',
                    icon: Icons.border_left_rounded,
                  ),
                  const SizedBox(height: 12),
                  _buildPositionOption(
                    value: 'right',
                    label: 'Right Side',
                    description: 'Vertical navigation on the right',
                    icon: Icons.border_right_rounded,
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.purple.withValues(alpha: 0.05),
                      borderRadius: AppStyles.borderRadiusLarge,
                      border: Border.all(
                        color: AppColors.purple.withValues(alpha: 0.15),
                      ),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.lightbulb_outline_rounded,
                          color: AppColors.purple,
                          size: 20,
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Tip: Bottom navigation works best with an odd number of tabs — Home sits in the center.',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.greyText,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildPositionOption({
    required String value,
    required String label,
    required String description,
    required IconData icon,
  }) {
    final isSelected = _position == value;

    return GestureDetector(
      onTap: () => _setPosition(value),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: AppStyles.borderRadiusLarge,
          border: Border.all(
            color: isSelected
                ? AppColors.purple.withValues(alpha: 0.6)
                : AppColors.normalCardBackground,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.purple.withValues(alpha: 0.15)
                      : AppColors.purple.withValues(alpha: 0.05),
                  borderRadius: AppStyles.borderRadiusSmall,
                ),
                child: Icon(
                  icon,
                  color: isSelected
                      ? AppColors.purple
                      : AppColors.greyText,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: isSelected ? AppColors.white : null,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.greyText,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                const Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.purple,
                  size: 24,
                )
              else
                Icon(
                  Icons.circle_outlined,
                  color: AppColors.greyText.withValues(alpha: 0.5),
                  size: 24,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
