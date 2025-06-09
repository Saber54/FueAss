import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ConfigLoader {
  static Future<Map<String, dynamic>> loadAppConfig() async {
    try {
      // 1. Lokale Konfiguration laden
      final configString = await rootBundle.loadString('assets/config.json');
      final config = jsonDecode(configString) as Map<String, dynamic>;

      // 2. Benutzereinstellungen mergen
      final prefs = await SharedPreferences.getInstance();
      if (prefs.containsKey('serverIp')) {
        config['serverIp'] = prefs.getString('serverIp');
      }

      return config;
    } catch (e) {
      return _getDefaultConfig();
    }
  }

  static Map<String, dynamic> _getDefaultConfig() {
    return {
      'serverIp': '192.168.1.1',
      'darkMode': false,
      'hazmatCategories': ['Chemikalien', 'Explosiv', 'Radioaktiv'],
    };
  }
}