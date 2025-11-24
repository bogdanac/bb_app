import 'package:flutter/services.dart';

class BatteryFlowWidgetService {
  static const platform = MethodChannel('com.bb.bb_app/widget');

  /// Update the widget display (called from Flutter when data changes)
  static Future<void> updateWidget() async {
    try {
      await platform.invokeMethod('updateBatteryFlowWidget');
    } catch (e) {
      print('Error updating battery flow widget: $e');
    }
  }

  /// Refresh widget color after color change
  static Future<void> refreshWidgetColor() async {
    try {
      await platform.invokeMethod('updateBatteryFlowWidget');
    } catch (e) {
      print('Error refreshing battery flow widget color: $e');
    }
  }
}
