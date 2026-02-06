import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_styles.dart';

/// Productivity assistant states
enum AssistantState {
  idle,
  working,
  celebrating,
  resting,
  encouraging,
  inFlow, // User is in the zone - exceeded focus time and still going!
}

/// A cute owl productivity assistant (inspired by classic desktop assistants)
class ProductivityAssistant extends StatefulWidget {
  final AssistantState state;
  final String? message;
  final double size;

  const ProductivityAssistant({
    super.key,
    this.state = AssistantState.idle,
    this.message,
    this.size = 80,
  });

  @override
  State<ProductivityAssistant> createState() => _ProductivityAssistantState();
}

class _ProductivityAssistantState extends State<ProductivityAssistant>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _bounceAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _bounceAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );

    if (widget.state == AssistantState.celebrating || widget.state == AssistantState.inFlow) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(ProductivityAssistant oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.state == AssistantState.celebrating || widget.state == AssistantState.inFlow) {
      _controller.repeat(reverse: true);
    } else {
      _controller.stop();
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
    final isAnimated = widget.state == AssistantState.celebrating ||
                       widget.state == AssistantState.inFlow;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: _bounceAnimation,
          builder: (context, child) {
            final bounce = isAnimated
                ? sin(_bounceAnimation.value * pi * 2) * 8
                : 0.0;
            return Transform.translate(
              offset: Offset(0, -bounce),
              child: child,
            );
          },
          child: _buildOwl(),
        ),
        if (widget.message != null) ...[
          const SizedBox(height: 8),
          _buildSpeechBubble(),
        ],
      ],
    );
  }

  Widget _buildOwl() {
    final size = widget.size;
    final eyeState = _getEyeState();

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Body
          Container(
            width: size * 0.85,
            height: size * 0.9,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.purple.withValues(alpha: 0.9),
                  AppColors.purple,
                ],
              ),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(size * 0.45),
                topRight: Radius.circular(size * 0.45),
                bottomLeft: Radius.circular(size * 0.35),
                bottomRight: Radius.circular(size * 0.35),
              ),
            ),
          ),
          // Belly
          Positioned(
            bottom: size * 0.1,
            child: Container(
              width: size * 0.5,
              height: size * 0.4,
              decoration: BoxDecoration(
                color: AppColors.lightPink.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(size * 0.25),
              ),
            ),
          ),
          // Left ear
          Positioned(
            top: 0,
            left: size * 0.12,
            child: Transform.rotate(
              angle: -0.3,
              child: Container(
                width: size * 0.18,
                height: size * 0.25,
                decoration: BoxDecoration(
                  color: AppColors.purple,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(size * 0.1),
                    topRight: Radius.circular(size * 0.1),
                  ),
                ),
              ),
            ),
          ),
          // Right ear
          Positioned(
            top: 0,
            right: size * 0.12,
            child: Transform.rotate(
              angle: 0.3,
              child: Container(
                width: size * 0.18,
                height: size * 0.25,
                decoration: BoxDecoration(
                  color: AppColors.purple,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(size * 0.1),
                    topRight: Radius.circular(size * 0.1),
                  ),
                ),
              ),
            ),
          ),
          // Face area
          Positioned(
            top: size * 0.22,
            child: Container(
              width: size * 0.7,
              height: size * 0.45,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(size * 0.35),
              ),
            ),
          ),
          // Left eye
          Positioned(
            top: size * 0.3,
            left: size * 0.18,
            child: _buildEye(size * 0.22, eyeState),
          ),
          // Right eye
          Positioned(
            top: size * 0.3,
            right: size * 0.18,
            child: _buildEye(size * 0.22, eyeState),
          ),
          // Beak
          Positioned(
            top: size * 0.48,
            child: Container(
              width: size * 0.12,
              height: size * 0.1,
              decoration: BoxDecoration(
                color: AppColors.orange,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(size * 0.06),
                  bottomRight: Radius.circular(size * 0.06),
                ),
              ),
            ),
          ),
          // Blush (when celebrating or in flow)
          if (widget.state == AssistantState.celebrating ||
              widget.state == AssistantState.inFlow) ...[
            Positioned(
              top: size * 0.45,
              left: size * 0.1,
              child: Container(
                width: size * 0.12,
                height: size * 0.08,
                decoration: BoxDecoration(
                  color: widget.state == AssistantState.inFlow
                      ? AppColors.yellow.withValues(alpha: 0.7)
                      : AppColors.lightPink.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(size * 0.04),
                ),
              ),
            ),
            Positioned(
              top: size * 0.45,
              right: size * 0.1,
              child: Container(
                width: size * 0.12,
                height: size * 0.08,
                decoration: BoxDecoration(
                  color: widget.state == AssistantState.inFlow
                      ? AppColors.yellow.withValues(alpha: 0.7)
                      : AppColors.lightPink.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(size * 0.04),
                ),
              ),
            ),
          ],
          // Graduation cap (when working)
          if (widget.state == AssistantState.working)
            Positioned(
              top: -size * 0.05,
              child: _buildGraduationCap(size * 0.4),
            ),
          // Star/sparkle effect (when in flow)
          if (widget.state == AssistantState.inFlow) ...[
            Positioned(
              top: -size * 0.08,
              left: size * 0.05,
              child: Icon(
                Icons.auto_awesome,
                color: AppColors.yellow,
                size: size * 0.2,
              ),
            ),
            Positioned(
              top: -size * 0.05,
              right: size * 0.08,
              child: Icon(
                Icons.auto_awesome,
                color: AppColors.orange,
                size: size * 0.15,
              ),
            ),
          ],
          // Sleep Zs (when resting)
          if (widget.state == AssistantState.resting)
            Positioned(
              top: size * 0.1,
              right: 0,
              child: Text(
                'z z z',
                style: TextStyle(
                  color: AppColors.purple.withValues(alpha: 0.6),
                  fontSize: size * 0.15,
                  fontWeight: FontWeight.bold,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEye(double size, _EyeState state) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(
          color: AppColors.purple.withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      child: Center(
        child: state == _EyeState.closed
            ? Container(
                width: size * 0.6,
                height: 3,
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(2),
                ),
              )
            : Container(
                width: size * 0.5,
                height: size * 0.5,
                decoration: const BoxDecoration(
                  color: Colors.black87,
                  shape: BoxShape.circle,
                ),
                child: Align(
                  alignment: const Alignment(0.3, -0.3),
                  child: Container(
                    width: size * 0.15,
                    height: size * 0.15,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildGraduationCap(double size) {
    return SizedBox(
      width: size,
      height: size * 0.6,
      child: Stack(
        children: [
          // Cap top
          Positioned(
            top: 0,
            left: size * 0.1,
            child: Transform.rotate(
              angle: 0.1,
              child: Container(
                width: size * 0.8,
                height: size * 0.25,
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
          // Cap base
          Positioned(
            top: size * 0.2,
            left: size * 0.25,
            child: Container(
              width: size * 0.5,
              height: size * 0.35,
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          // Tassel
          Positioned(
            top: size * 0.1,
            right: size * 0.15,
            child: Container(
              width: 3,
              height: size * 0.4,
              decoration: BoxDecoration(
                color: AppColors.yellow,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ],
      ),
    );
  }

  _EyeState _getEyeState() {
    switch (widget.state) {
      case AssistantState.resting:
        return _EyeState.closed;
      case AssistantState.celebrating:
      case AssistantState.inFlow:
        return _EyeState.happy;
      default:
        return _EyeState.open;
    }
  }

  Widget _buildSpeechBubble() {
    return Container(
      constraints: const BoxConstraints(maxWidth: 200),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppStyles.borderRadiusMedium,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        widget.message!,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 13,
          color: AppColors.grey700,
          height: 1.3,
        ),
      ),
    );
  }
}

enum _EyeState { open, closed, happy }

/// Dialog shown when a pomodoro session completes
class PomodoroCompleteDialog extends StatelessWidget {
  final int completedPomodoros;
  final Duration totalWorkTime;
  final VoidCallback onTakeBreak;
  final VoidCallback onContinueFocus;
  final VoidCallback onStop;

  const PomodoroCompleteDialog({
    super.key,
    required this.completedPomodoros,
    required this.totalWorkTime,
    required this.onTakeBreak,
    required this.onContinueFocus,
    required this.onStop,
  });

  String _getEncouragingMessage() {
    final messages = [
      "Great focus session!",
      "You're doing amazing!",
      "Fantastic work!",
      "Keep up the momentum!",
      "You're on fire!",
      "Crushing it!",
    ];
    return messages[DateTime.now().millisecond % messages.length];
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.dialogBackground,
      contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ProductivityAssistant(
            state: AssistantState.celebrating,
            message: _getEncouragingMessage(),
            size: 100,
          ),
          const SizedBox(height: 16),
          Text(
            'Focus Session Complete!',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.purple,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildStatChip(
                icon: Icons.local_fire_department_rounded,
                value: '$completedPomodoros',
                label: 'sessions',
                color: AppColors.orange,
              ),
              const SizedBox(width: 16),
              _buildStatChip(
                icon: Icons.timer_rounded,
                value: _formatDuration(totalWorkTime),
                label: 'focused',
                color: AppColors.purple,
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            'What would you like to do?',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.greyText,
            ),
          ),
        ],
      ),
      actionsAlignment: MainAxisAlignment.center,
      actionsPadding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      actions: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Continue Focus - Primary action
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                onContinueFocus();
              },
              icon: const Icon(Icons.bolt_rounded),
              label: const Text('Continue Focus'),
              style: AppStyles.elevatedButtonStyle(
                backgroundColor: AppColors.purple,
              ),
            ),
            const SizedBox(height: 8),
            // Take Break - Secondary action
            OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                onTakeBreak();
              },
              icon: Icon(Icons.coffee_rounded, color: AppColors.lime),
              label: Text(
                'Take a Break',
                style: TextStyle(color: AppColors.lime),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: AppColors.lime),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
            const SizedBox(height: 8),
            // Stop - Tertiary action
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                onStop();
              },
              style: AppStyles.textButtonStyle(),
              child: Text(
                'Stop for now',
                style: TextStyle(color: AppColors.greyText),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatChip({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: AppStyles.borderRadiusSmall,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: color.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Dialog shown when user reaches a flow milestone
class FlowMilestoneDialog extends StatelessWidget {
  final String title;
  final String message;
  final int minutes;
  final int excitementLevel; // 1-3 scale
  final VoidCallback onContinue;

  const FlowMilestoneDialog({
    super.key,
    required this.title,
    required this.message,
    required this.minutes,
    required this.excitementLevel,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.dialogBackground,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Sparkle effects based on excitement
          Stack(
            alignment: Alignment.center,
            children: [
              // Background glow
              Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.yellow.withValues(alpha: 0.3),
                      AppColors.orange.withValues(alpha: 0.1),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
              const ProductivityAssistant(
                state: AssistantState.inFlow,
                size: 100,
              ),
              // Extra sparkles for higher excitement
              if (excitementLevel >= 2) ...[
                Positioned(
                  top: 0,
                  left: 10,
                  child: Icon(Icons.auto_awesome, color: AppColors.yellow, size: 24),
                ),
                Positioned(
                  top: 10,
                  right: 5,
                  child: Icon(Icons.auto_awesome, color: AppColors.orange, size: 20),
                ),
              ],
              if (excitementLevel >= 3) ...[
                Positioned(
                  bottom: 20,
                  left: 0,
                  child: Icon(Icons.auto_awesome, color: AppColors.yellow, size: 18),
                ),
                Positioned(
                  bottom: 10,
                  right: 0,
                  child: Icon(Icons.auto_awesome, color: AppColors.orange, size: 22),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          // Fire icon row for milestone level
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              excitementLevel,
              (i) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Icon(
                  Icons.local_fire_department_rounded,
                  color: AppColors.orange,
                  size: 24,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.orange,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.greyText,
              height: 1.4,
            ),
          ),
        ],
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        ElevatedButton.icon(
          onPressed: onContinue,
          icon: const Icon(Icons.bolt_rounded),
          label: const Text('Keep Going!'),
          style: AppStyles.elevatedButtonStyle(
            backgroundColor: AppColors.orange,
          ),
        ),
      ],
    );
  }
}

/// Small assistant widget for inline display
class MiniProductivityAssistant extends StatelessWidget {
  final AssistantState state;
  final String? tip;

  const MiniProductivityAssistant({
    super.key,
    this.state = AssistantState.idle,
    this.tip,
  });

  static const List<String> _focusTips = [
    "Stay hydrated!",
    "You've got this!",
    "One step at a time.",
    "Focus on progress, not perfection.",
    "Small wins add up!",
    "Take deep breaths.",
  ];

  static const List<String> _breakTips = [
    "Stretch your body!",
    "Rest your eyes.",
    "Take a short walk.",
    "Grab some water.",
    "Relax and recharge.",
  ];

  static const List<String> _flowTips = [
    "You're in the zone!",
    "Incredible focus!",
    "Flow state achieved!",
    "On fire today!",
    "Unstoppable!",
    "Peak performance!",
  ];

  String _getTip() {
    if (tip != null) return tip!;
    final List<String> tips;
    if (state == AssistantState.inFlow) {
      tips = _flowTips;
    } else if (state == AssistantState.resting) {
      tips = _breakTips;
    } else {
      tips = _focusTips;
    }
    return tips[DateTime.now().second % tips.length];
  }

  @override
  Widget build(BuildContext context) {
    final isInFlow = state == AssistantState.inFlow;
    final bgColor = isInFlow
        ? AppColors.yellow.withValues(alpha: 0.15)
        : AppColors.purple.withValues(alpha: 0.1);
    final borderColor = isInFlow
        ? AppColors.yellow.withValues(alpha: 0.4)
        : AppColors.purple.withValues(alpha: 0.2);
    final textColor = isInFlow ? AppColors.orange : AppColors.purple;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: AppStyles.borderRadiusMedium,
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          ProductivityAssistant(
            state: state,
            size: 50,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isInFlow)
                  Row(
                    children: [
                      Icon(Icons.local_fire_department_rounded,
                          color: AppColors.orange, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        'FLOW STATE',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppColors.orange,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                Text(
                  _getTip(),
                  style: TextStyle(
                    fontSize: 13,
                    color: textColor,
                    fontStyle: FontStyle.italic,
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
