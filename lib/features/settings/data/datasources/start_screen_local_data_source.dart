import 'package:shared_preferences/shared_preferences.dart';

/// Stores the start screen in local preferences on the device (never sent to
/// the backend).
class StartScreenLocalDataSource {
  const StartScreenLocalDataSource();

  static const _key = 'start_screen_v1';

  Future<String?> read() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key);
  }

  Future<void> write(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, name);
  }
}
