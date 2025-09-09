import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class FastingPhases {
  /// Get fasting phase information based on elapsed time
  static Map<String, dynamic> getFastingPhaseInfo(Duration elapsedTime, bool isFasting) {
    if (!isFasting || elapsedTime == Duration.zero) {
      return {
        'phase': 'Ready to Fast',
        'message': 'Begin your transformative journey',
        'color': AppColors.grey,
        'progress': 0.0,
      };
    }

    final hoursElapsed = elapsedTime.inHours;

    if (hoursElapsed < 4) {
      return {
        'phase': 'Digestion Phase',
        'message': 'Your body has finished processing your last meal! 🍽️',
        'color': AppColors.lightGreen,
        'progress': (hoursElapsed / 4).clamp(0.0, 1.0),
      };
    } else if (hoursElapsed < 8) {
      return {
        'phase': 'Glycogen Depletion',
        'message': 'Now switching to stored energy sources! ⚡',
        'color': AppColors.yellow,
        'progress': ((hoursElapsed - 4) / 4).clamp(0.0, 1.0),
      };
    } else if (hoursElapsed < 12) {
      return {
        'phase': 'Fat Burning Begins',
        'message': 'Your body is now burning fat for fuel! 🔥',
        'color': AppColors.pastelGreen,
        'progress': ((hoursElapsed - 8) / 4).clamp(0.0, 1.0),
      };
    } else if (hoursElapsed < 16) {
      return {
        'phase': 'Ketosis Initiation',
        'message': 'Ketone production is starting! Mental clarity incoming! 🧠',
        'color': AppColors.purple,
        'progress': ((hoursElapsed - 12) / 4).clamp(0.0, 1.0),
      };
    } else if (hoursElapsed < 20) {
      return {
        'phase': 'Deep Ketosis',
        'message': 'You\'re in deep ketosis - feel that energy surge! ✨',
        'color': AppColors.pink,
        'progress': ((hoursElapsed - 16) / 4).clamp(0.0, 1.0),
      };
    } else if (hoursElapsed < 24) {
      return {
        'phase': 'Growth Hormone Peak',
        'message': 'HGH levels are significantly elevated! 💪',
        'color': AppColors.redPrimary,
        'progress': ((hoursElapsed - 20) / 4).clamp(0.0, 1.0),
      };
    } else if (hoursElapsed < 36) {
      return {
        'phase': 'Autophagy Activation',
        'message': 'Cellular repair and regeneration is in full swing! 🔄',
        'color': AppColors.successGreen,
        'progress': ((hoursElapsed - 24) / 12).clamp(0.0, 1.0),
      };
    } else if (hoursElapsed < 48) {
      return {
        'phase': 'Enhanced Autophagy',
        'message': 'Peak cellular cleanup - your body is rejuvenating! 🌟',
        'color': AppColors.lightGreen,
        'progress': ((hoursElapsed - 36) / 12).clamp(0.0, 1.0),
      };
    } else {
      return {
        'phase': 'Maximum Benefits',
        'message': 'Ultimate metabolic transformation! 🚀',
        'color': AppColors.yellow,
        'progress': 1.0,
      };
    }
  }

  /// Get current fasting phase color
  static Color getCurrentPhaseColor(Duration elapsedTime, bool isFasting) {
    return getFastingPhaseInfo(elapsedTime, isFasting)['color'];
  }
}