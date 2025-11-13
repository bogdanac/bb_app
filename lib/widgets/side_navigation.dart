import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Side navigation bar for desktop/tablet layouts
class SideNavigation extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onItemTapped;

  const SideNavigation({
    super.key,
    required this.selectedIndex,
    required this.onItemTapped,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
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
          const SizedBox(height: 60),
          // Navigation items
          _buildNavItem(
            icon: Icons.restaurant,
            label: 'Fasting',
            index: 0,
            color: AppColors.yellow,
          ),
          const SizedBox(height: 12),
          _buildNavItem(
            icon: Icons.favorite,
            label: 'Cycle',
            index: 1,
            color: AppColors.red,
          ),
          const SizedBox(height: 12),
          _buildNavItem(
            icon: Icons.home,
            label: 'Home',
            index: 2,
            color: AppColors.pink,
          ),
          const SizedBox(height: 12),
          _buildNavItem(
            icon: Icons.check_circle,
            label: 'Tasks',
            index: 3,
            color: AppColors.coral,
          ),
          const SizedBox(height: 12),
          _buildNavItem(
            icon: Icons.repeat,
            label: 'Routines',
            index: 4,
            color: AppColors.orange,
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required int index,
    required Color color,
  }) {
    final bool isSelected = selectedIndex == index;

    return InkWell(
      onTap: () => onItemTapped(index),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected ? color.withAlpha(51) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: isSelected
              ? Border.all(color: color, width: 2)
              : null,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? color : AppColors.grey200,
              size: 24,
            ),
            const SizedBox(width: 16),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? AppColors.white : AppColors.grey200,
                fontSize: 16,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
