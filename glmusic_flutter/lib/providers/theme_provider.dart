import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_theme.dart';

class ThemeProvider extends ChangeNotifier {
  static const String _key = 'glmusic_selected_theme';
  AppTheme _theme = AppTheme.sakura;

  AppTheme get currentTheme => _theme;
  Color get primaryColor => _theme.primaryColor;
  Color get secondaryColor => _theme.secondaryColor;
  Color get highlightColor => _theme.highlightColor;
  List<Color> get gradientColors => _theme.gradientColors;
  Color get tintColor => _theme.tintColor;

  ThemeProvider() {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = prefs.getString(_key);
      if (key != null) {
        _theme = AppTheme.fromKey(key);
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> setTheme(AppTheme theme) async {
    if (_theme == theme) return;
    _theme = theme;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, theme.key);
    } catch (_) {}
  }
}
