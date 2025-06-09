import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthProvider extends ChangeNotifier {
  String? _deviceId;
  bool _isMaster = false;
  bool _isServer = false;
  String? _authToken;

  // Getter
  String? get deviceId => _deviceId;
  bool get isMaster => _isMaster;
  bool get isServer => _isServer;
  String? get authToken => _authToken;

  // Initialisierung beim App-Start
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _deviceId = prefs.getString('deviceId');
    _isMaster = prefs.getBool('isMaster') ?? false;
    _isServer = prefs.getBool('isServer') ?? false;
    _authToken = prefs.getString('authToken');
    notifyListeners();
  }

  // Gerät als Master festlegen
  Future<void> setMasterRole(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isMaster', value);
    _isMaster = value;
    notifyListeners();
  }

  // Server-Modus aktivieren
  Future<void> enableServerMode() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isServer', true);
    _isServer = true;
    notifyListeners();
  }

  // Authentifizierung durchführen
  Future<bool> authenticate(String pairingCode) async {
    try {
      // Mock: API-Call zum Server
      await Future.delayed(const Duration(seconds: 1));
      
      final prefs = await SharedPreferences.getInstance();
      _authToken = 'generated_token_$pairingCode';
      await prefs.setString('authToken', _authToken!);
      
      notifyListeners();
      return true;
    } catch (e) {
      return false;
    }
  }

  // Abmelden
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('authToken');
    _authToken = null;
    notifyListeners();
  }
}