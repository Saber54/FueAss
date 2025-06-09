import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.light;

  ThemeMode get themeMode => _themeMode;

  // Initialisierung
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _themeMode = prefs.getBool('isDarkMode') == true 
        ? ThemeMode.dark 
        : ThemeMode.light;
    notifyListeners();
  }

  // Theme umschalten
  Future<void> toggleTheme(bool isDark) async {
    _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', isDark);
    
    notifyListeners();
  }
}