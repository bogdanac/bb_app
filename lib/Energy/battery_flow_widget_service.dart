import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Service for Battery & Flow widget integration
class BatteryFlowWidgetService {
  static const MethodChannel _channel =
      MethodChannel('com.bb.bb_app/battery_flow_widget');

  /// Update the Battery & Flow widget display
  /// Call this whenever battery or flow points change
  static Future<void> updateWidget() async {
    // Skip on web - widgets are only available on mobile platforms
    if (kIsWeb) return;

    try {
      await _channel.invokeMethod('updateBatteryFlowWidget');
    } catch (e) {
      debugPrint('Error updating Battery & Flow widget: $e');
    }
  }

  /// Refresh widget after color/settings change
  static Future<void> refreshWidgetColor() async {
    // Skip on web - widgets are only available on mobile platforms
    if (kIsWeb) return;

    try {
      await _channel.invokeMethod('updateBatteryFlowWidget');
    } catch (e) {
      debugPrint('Error refreshing Battery & Flow widget: $e');
    }
  }
}
