import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class ConfigService {
  Future<Map<String, dynamic>> loadAppConfig() async {
    try {
      // Lokale Konfiguration laden
      final config = await rootBundle.loadString('assets/config.json');
      final Map<String, dynamic> json = jsonDecode(config);

      // Benutzereinstellungen mergen
      final prefs = await SharedPreferences.getInstance();
      if (prefs.containsKey('darkMode')) {
        json['darkMode'] = prefs.getBool('darkMode');
      }

      return json;
    } catch (e) {
      return {
        'darkMode': false,
        'serverIp': '192.168.1.1',
      };
    }
  }

  Future<void> saveDarkModePreference(bool isDark) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('darkMode', isDark);
  }
}