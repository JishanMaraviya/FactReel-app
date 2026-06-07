import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeController extends ValueNotifier<bool> {
  ThemeController._(bool value) : super(value);

  static final ThemeController instance = ThemeController._(false);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    value = prefs.getBool('factreel_dark') ?? false;
  }

  Future<void> setDark(bool dark) async {
    value = dark;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('factreel_dark', dark);
  }
}
