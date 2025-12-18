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
  late List<_ConfettiParticle> _particles;
  final Random _random = Random();

  @override
  void initState() {
    super.initState();

    // Main confetti animation
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    // Checkmark animation
    _checkController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    // Generate confetti particles
    _particles = List.generate(20, (index) => _ConfettiParticle(
      color: _getRandomColor(),
      angle: _random.nextDouble() * 2 * pi,
      speed: 100 + _random.nextDouble() * 150,
      rotationSpeed: _random.nextDouble() * 4 - 2,
      size: 6 + _random.nextDouble() * 6,
    ));

    _controller.forward();
    _checkController.forward();

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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final checkColor = widget.checkColor ?? AppColors.successGreen;
    final checkIcon = widget.checkIcon ?? Icons.check_rounded;

    return AnimatedBuilder(
      animation: Listenable.merge([_controller, _checkController]),
      builder: (context, child) {
        return Stack(
          children: [
            // Confetti particles
            ..._particles.map((particle) {
              final progress = _controller.value;
              final dx = cos(particle.angle) * particle.speed * progress;
              final dy = sin(particle.angle) * particle.speed * progress -
                         (50 * progress) + // Initial upward burst
                         (200 * progress * progress); // Gravity effect
              final opacity = (1 - progress).clamp(0.0, 1.0);
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
              left: widget.position.dx - 24,
              top: widget.position.dy - 24,
              child: ScaleTransition(
                scale: CurvedAnimation(
                  parent: _checkController,
                  curve: Curves.elasticOut,
                ),
                child: FadeTransition(
                  opacity: Tween<double>(begin: 1.0, end: 0.0).animate(
                    CurvedAnimation(
                      parent: _controller,
                      curve: const Interval(0.5, 1.0),
                    ),
                  ),
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: checkColor,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: checkColor.withValues(alpha: 0.5),
                          blurRadius: 12,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Icon(
                      checkIcon,
                      color: Colors.white,
                      size: 28,
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
