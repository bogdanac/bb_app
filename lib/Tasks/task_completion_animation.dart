import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// A simpler, more robust completion animation wrapper
class TaskCompletionAnimation extends StatefulWidget {
  final Widget child;
  final bool isCompleting;
  final VoidCallback? onAnimationComplete;
  
  const TaskCompletionAnimation({
    super.key,
    required this.child,
    required this.isCompleting,
    this.onAnimationComplete,
  });

  @override
  State<TaskCompletionAnimation> createState() => _TaskCompletionAnimationState();
}

class _TaskCompletionAnimationState extends State<TaskCompletionAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  late Animation<Color?> _colorAnimation;

  @override
  void initState() {
    super.initState();
    
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
    ));

    _opacityAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.6, 1.0, curve: Curves.easeIn),
    ));

    _colorAnimation = ColorTween(
      begin: Colors.transparent,
      end: AppColors.successGreen.withValues(alpha: 0.3),
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
    ));

    // Listen for animation completion
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onAnimationComplete?.call();
      }
    });
  }

  @override
  void didUpdateWidget(TaskCompletionAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (widget.isCompleting && !oldWidget.isCompleting) {
      // Start animation when completing becomes true
      _controller.forward();
    } else if (!widget.isCompleting && oldWidget.isCompleting) {
      // Reset animation when completing becomes false
      _controller.reset();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isCompleting) {
      return widget.child;
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: _colorAnimation.value,
              borderRadius: BorderRadius.circular(12),
            ),
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 100),
              opacity: _opacityAnimation.value,
              child: widget.child,
            ),
          ),
        );
      },
    );
  }
}