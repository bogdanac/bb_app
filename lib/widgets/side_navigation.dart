import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class SideNavItem {
  final IconData icon;
  final String label;
  final Color color;

  const SideNavItem({
    required this.icon,
    required this.label,
    required this.color,
  });
}

/// Side navigation bar for desktop/tablet layouts
class SideNavigation extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onItemTapped;
  final List<SideNavItem> items;

  const SideNavigation({
    super.key,
    required this.selectedIndex,
    required this.onItemTapped,
    required this.items,
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
          ...items.asMap().entries.map((entry) => Padding(
            padding: EdgeInsets.only(bottom: entry.key < items.length - 1 ? 12 : 0),
            child: _buildNavItem(
              icon: entry.value.icon,
              label: entry.value.label,
              index: entry.key,
              color: entry.value.color,
            ),
          )),
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
