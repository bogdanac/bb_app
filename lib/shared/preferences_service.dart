import 'package:shared_preferences/shared_preferences.dart';

/// Centralized SharedPreferences service for easier access and testing
///
/// This is a thin wrapper around SharedPreferences that provides:
/// - Singleton pattern for easy access
/// - Consistent initialization
/// - Optional convenience methods
///
/// IMPORTANT: This is optional to use. Existing code can continue using
/// SharedPreferences.getInstance() directly without breaking anything.
class PreferencesService {
  static final PreferencesService _instance = PreferencesService._internal();
  factory PreferencesService() => _instance;
  PreferencesService._internal();

  SharedPreferences? _prefs;

  /// Initialize the preferences service
  /// Call this once at app startup in main()
  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  /// Get the SharedPreferences instance
  /// This will automatically initialize if not already done
  Future<SharedPreferences> get prefs async {
    if (_prefs == null) {
      await init();
    }
    return _prefs!;
  }

  /// Quick access methods (optional - use if convenient)

  Future<String?> getString(String key) async {
    final p = await prefs;
    return p.getString(key);
  }

  Future<bool> setString(String key, String value) async {
    final p = await prefs;
    return p.setString(key, value);
  }

  Future<int?> getInt(String key) async {
    final p = await prefs;
    return p.getInt(key);
  }

  Future<bool> setInt(String key, int value) async {
    final p = await prefs;
    return p.setInt(key, value);
  }

  Future<bool?> getBool(String key) async {
    final p = await prefs;
    return p.getBool(key);
  }

  Future<bool> setBool(String key, bool value) async {
    final p = await prefs;
    return p.setBool(key, value);
  }

  Future<double?> getDouble(String key) async {
    final p = await prefs;
    return p.getDouble(key);
  }

  Future<bool> setDouble(String key, double value) async {
    final p = await prefs;
    return p.setDouble(key, value);
  }

  Future<List<String>?> getStringList(String key) async {
    final p = await prefs;
    return p.getStringList(key);
  }

  Future<bool> setStringList(String key, List<String> value) async {
    final p = await prefs;
    return p.setStringList(key, value);
  }

  Future<bool> remove(String key) async {
    final p = await prefs;
    return p.remove(key);
  }

  Future<bool> clear() async {
    final p = await prefs;
    return p.clear();
  }

  Future<bool> containsKey(String key) async {
    final p = await prefs;
    return p.containsKey(key);
  }

  Future<Set<String>> getKeys() async {
    final p = await prefs;
    return p.getKeys();
  }
}
