import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final themeProvider = NotifierProvider<ThemeController, bool>(() {
  return ThemeController();
});

class ThemeController extends Notifier<bool> {
  @override
  bool build() {
    _load();
    return false;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool('factreel_dark') ?? false;
  }

  Future<void> setDark(bool dark) async {
    state = dark;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('factreel_dark', dark);
  }
}
