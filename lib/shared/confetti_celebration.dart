import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Shows a confetti celebration overlay at the given position
class ConfettiCelebration {
  static OverlayEntry? _currentOverlay;

  /// Show confetti celebration at the tap position
  static void show(BuildContext context, Offset position) {
    // Remove any existing overlay
    _currentOverlay?.remove();
    _currentOverlay = null;

    _currentOverlay = OverlayEntry(
      builder: (context) => ConfettiOverlay(
        position: position,
        onComplete: () {
          _currentOverlay?.remove();
          _currentOverlay = null;
        },
      ),
    );

    Overlay.of(context).insert(_currentOverlay!);
  }

  /// Dispose of any active overlay
  static void dispose() {
    _currentOverlay?.remove();
    _currentOverlay = null;
  }
}

/// Confetti overlay animation widget
class ConfettiOverlay extends StatefulWidget {
  final Offset position;
  final VoidCallback onComplete;
  final Color? checkColor;
  final IconData? checkIcon;

  const ConfettiOverlay({
    super.key,
    required this.position,
    required this.onComplete,
    this.checkColor,
    this.checkIcon,
  });

  @override
  State<ConfettiOverlay> createState() => _ConfettiOverlayState();
}

class _ConfettiOverlayState extends State<ConfettiOverlay>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late AnimationController _checkController;
  late AnimationController _burstController;
  late List<_ConfettiParticle> _particles;
  final Random _random = Random();

  @override
  void initState() {
    super.initState();

    // Main confetti animation - longer duration for better effect
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1800),
      vsync: this,
    );

    // Checkmark animation
    _checkController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    // Burst effect animation
    _burstController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    // Generate more confetti particles with wider spread
    _particles = List.generate(30, (index) => _ConfettiParticle(
      color: _getRandomColor(),
      angle: _random.nextDouble() * 2 * pi,
      speed: 150 + _random.nextDouble() * 250, // Faster and wider spread
      rotationSpeed: _random.nextDouble() * 6 - 3,
      size: 6 + _random.nextDouble() * 8,
    ));

    _controller.forward();
    _checkController.forward();
    _burstController.forward();

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onComplete();
      }
    });
  }

  Color _getRandomColor() {
    final colors = [
      AppColors.orange,
      AppColors.yellow,
      AppColors.successGreen,
      AppColors.coral,
      AppColors.purple,
      Colors.pink,
      Colors.cyan,
    ];
    return colors[_random.nextInt(colors.length)];
  }

  @override
  void dispose() {
    _controller.dispose();
    _checkController.dispose();
    _burstController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final checkColor = widget.checkColor ?? AppColors.successGreen;
    final checkIcon = widget.checkIcon ?? Icons.check_rounded;

    return AnimatedBuilder(
      animation: Listenable.merge([_controller, _checkController, _burstController]),
      builder: (context, child) {
        return Stack(
          children: [
            // Central burst effect
            if (_burstController.value < 1.0)
              Positioned(
                left: widget.position.dx - 60,
                top: widget.position.dy - 60,
                child: Transform.scale(
                  scale: _burstController.value * 2.5,
                  child: Opacity(
                    opacity: (1 - _burstController.value).clamp(0.0, 1.0),
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            checkColor.withValues(alpha: 0.6),
                            checkColor.withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

            // Confetti particles
            ..._particles.map((particle) {
              final progress = _controller.value;
              final dx = cos(particle.angle) * particle.speed * progress;
              final dy = sin(particle.angle) * particle.speed * progress -
                         (80 * progress) + // Stronger initial upward burst
                         (300 * progress * progress); // Gravity effect
              // Fade out slower - only start fading at 60%
              final opacity = progress < 0.6
                  ? 1.0
                  : ((1 - progress) / 0.4).clamp(0.0, 1.0);
              final rotation = particle.rotationSpeed * progress * 2 * pi;

              return Positioned(
                left: widget.position.dx + dx - particle.size / 2,
                top: widget.position.dy + dy - particle.size / 2,
                child: Opacity(
                  opacity: opacity,
                  child: Transform.rotate(
                    angle: rotation,
                    child: Container(
                      width: particle.size,
                      height: particle.size,
                      decoration: BoxDecoration(
                        color: particle.color,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
              );
            }),

            // Animated checkmark
            Positioned(
              left: widget.position.dx - 28,
              top: widget.position.dy - 28,
              child: ScaleTransition(
                scale: CurvedAnimation(
                  parent: _checkController,
                  curve: Curves.elasticOut,
                ),
                child: FadeTransition(
                  opacity: Tween<double>(begin: 1.0, end: 0.0).animate(
                    CurvedAnimation(
                      parent: _controller,
                      curve: const Interval(0.6, 1.0), // Fade later
                    ),
                  ),
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: checkColor,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: checkColor.withValues(alpha: 0.6),
                          blurRadius: 16,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: Icon(
                      checkIcon,
                      color: Colors.white,
                      size: 32,
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

/// Data class for confetti particle properties
class _ConfettiParticle {
  final Color color;
  final double angle;
  final double speed;
  final double rotationSpeed;
  final double size;

  _ConfettiParticle({
    required this.color,
    required this.angle,
    required this.speed,
    required this.rotationSpeed,
    required this.size,
  });
}
