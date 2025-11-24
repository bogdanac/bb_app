import 'package:flutter/services.dart';

/// Method channel for Battery & Flow widget integration
class BatteryFlowWidgetChannel {
  static const MethodChannel _channel =
      MethodChannel('com.bb.bb_app/battery_flow_widget');

  /// Update the Battery & Flow widget display
  /// Call this whenever battery or flow points change
  static Future<void> updateWidget() async {
    try {
      await _channel.invokeMethod('updateBatteryFlowWidget');
    } catch (e) {
      print('Error updating Battery & Flow widget: $e');
    }
  }
}
