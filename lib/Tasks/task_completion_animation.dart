import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../theme/app_colors.dart';
import '../theme/app_styles.dart';

class ConfettiParticle {
  double x;
  double y;
  final double initialX;
  final double initialY;
  final double velocityX;
  final double velocityY;
  final Color color;
  final double size;
  final double rotation;
  final double rotationSpeed;
  double opacity;

  ConfettiParticle({
    required this.initialX,
    required this.initialY,
    required this.velocityX,
    required this.velocityY,
    required this.color,
    required this.size,
    required this.rotation,
    required this.rotationSpeed,
    this.opacity = 1.0,
  }) : x = initialX, y = initialY;

  void update(double progress) {
    x = initialX + velocityX * progress;
    y = initialY + velocityY * progress + 200 * progress * progress; // Gravity effect
    opacity = (1.0 - progress).clamp(0.0, 1.0);
  }
}

/// Enhanced completion animation with confetti particles
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
  final List<ConfettiParticle> _particles = [];

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
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

  void _createConfetti() {
    final random = math.Random();
    _particles.clear();

    // Create colorful confetti particles
    final colors = [
      AppColors.successGreen,
      AppColors.coral,
      AppColors.waterBlue,
      AppColors.yellow,
      AppColors.orange,
      Colors.purple,
      Colors.pink,
    ];

    // Create 25 particles from the center of the card
    for (int i = 0; i < 25; i++) {
      _particles.add(ConfettiParticle(
        initialX: 0,
        initialY: 0,
        velocityX: (random.nextDouble() - 0.5) * 400, // Random horizontal velocity
        velocityY: -random.nextDouble() * 200 - 50, // Upward initial velocity
        color: colors[random.nextInt(colors.length)],
        size: random.nextDouble() * 8 + 4, // Size between 4-12
        rotation: random.nextDouble() * 2 * math.pi,
        rotationSpeed: (random.nextDouble() - 0.5) * 10,
      ));
    }
  }

  @override
  void didUpdateWidget(TaskCompletionAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.isCompleting && !oldWidget.isCompleting) {
      // Create confetti and start animation when completing becomes true
      _createConfetti();
      _controller.forward();
    } else if (!widget.isCompleting && oldWidget.isCompleting) {
      // Reset animation when completing becomes false
      _controller.reset();
      _particles.clear();
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
        // Update particle positions
        for (var particle in _particles) {
          particle.update(_controller.value);
        }

        return Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            // Main card with celebration effects
            Transform.scale(
              scale: _scaleAnimation.value,
              child: Container(
                decoration: BoxDecoration(
                  color: _colorAnimation.value,
                  borderRadius: AppStyles.borderRadiusMedium,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.successGreen.withValues(alpha: 0.4),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Opacity(
                  opacity: _opacityAnimation.value,
                  child: widget.child,
                ),
              ),
            ),
            // Confetti particles overlay
            ..._particles.map((particle) => Positioned(
              left: particle.x,
              top: particle.y,
              child: Opacity(
                opacity: particle.opacity,
                child: Transform.rotate(
                  angle: particle.rotation + (_controller.value * particle.rotationSpeed),
                  child: Container(
                    width: particle.size,
                    height: particle.size,
                    decoration: BoxDecoration(
                      color: particle.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            )),
            // Central celebration burst effect
            if (_controller.value < 0.3)
              Positioned(
                child: Transform.scale(
                  scale: _controller.value * 3,
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          AppColors.successGreen.withValues(alpha: 0.6),
                          AppColors.successGreen.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}