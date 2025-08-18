// fasting_notifier.dart - Sistem de notificare pentru sincronizare
import 'package:flutter/foundation.dart';

class FastingNotifier extends ChangeNotifier {
  static final FastingNotifier _instance = FastingNotifier._internal();
  factory FastingNotifier() => _instance;
  FastingNotifier._internal();

  void notifyFastingStateChanged() {
    notifyListeners();
  }
}