import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_colors.dart';

/// A wrapper that adds collapse/expand functionality to cards on desktop only.
/// On mobile, the card is always shown in full.
class CollapsibleCardWrapper extends StatefulWidget {
  final String cardKey;
  final String title;
  final IconData icon;
  final Color iconColor;
  final Widget child;
  final VoidCallback? onTap;
  final Widget? trailing;

  const CollapsibleCardWrapper({
    super.key,
    required this.cardKey,
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.child,
    this.onTap,
    this.trailing,
  });

  @override
  State<CollapsibleCardWrapper> createState() => _CollapsibleCardWrapperState();
}

class _CollapsibleCardWrapperState extends State<CollapsibleCardWrapper> {
  bool _isCollapsed = false;
  static const String _collapsedCardsKey = 'desktop_collapsed_cards';

  @override
  void initState() {
    super.initState();
    _loadCollapsedState();
  }

  Future<void> _loadCollapsedState() async {
    final prefs = await SharedPreferences.getInstance();
    final collapsedCards = prefs.getStringList(_collapsedCardsKey) ?? [];
    if (mounted) {
      setState(() {
        _isCollapsed = collapsedCards.contains(widget.cardKey);
      });
    }
  }

  Future<void> _toggleCollapsed() async {
    HapticFeedback.selectionClick();
    final prefs = await SharedPreferences.getInstance();
    final collapsedCards = prefs.getStringList(_collapsedCardsKey) ?? [];

    if (_isCollapsed) {
      collapsedCards.remove(widget.cardKey);
    } else {
      collapsedCards.add(widget.cardKey);
    }

    await prefs.setStringList(_collapsedCardsKey, collapsedCards);
    if (mounted) {
      setState(() {
        _isCollapsed = !_isCollapsed;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 1024;

    // On mobile, just return the child as-is
    if (!isDesktop) {
      return widget.child;
    }

    // On desktop, wrap with collapsible header
    if (_isCollapsed) {
      return _buildCollapsedCard();
    }

    return _buildExpandedCard();
  }

  Widget _buildCollapsedCard() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.normalCardBackground,
        ),
      ),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(
                widget.icon,
                color: widget.iconColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (widget.trailing != null) ...[
                widget.trailing!,
                const SizedBox(width: 8),
              ],
              // Expand button
              GestureDetector(
                onTap: _toggleCollapsed,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    Icons.expand_more_rounded,
                    color: AppColors.grey300,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExpandedCard() {
    return Stack(
      children: [
        widget.child,
        // Collapse button positioned in top-right
        Positioned(
          top: 8,
          right: 8,
          child: GestureDetector(
            onTap: _toggleCollapsed,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.grey300.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Icon(
                Icons.expand_less_rounded,
                color: AppColors.grey300,
                size: 18,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
