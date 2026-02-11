import 'package:flutter/material.dart';

/// A wrapper that previously added collapse/expand functionality to cards on desktop.
/// Now simply passes through the child widget.
class CollapsibleCardWrapper extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return child;
  }
}
