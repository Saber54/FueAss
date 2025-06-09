import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ConnectionService extends ChangeNotifier {
  final Dio _dio = Dio();
  bool _isConnected = false;
  bool _isServerMode = false;
  String? _serverIp;

  bool get isConnected => _isConnected;
  bool get isServerMode => _isServerMode;
  String? get serverIp => _serverIp;

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _isServerMode = prefs.getBool('isServer') ?? false;
    _serverIp = prefs.getString('serverIp');
    
    if (_isServerMode) {
      await _startLocalServer();
    }
  }

  Future<void> _startLocalServer() async {
    try {
      // Dart-Server starten (shelf)
      Process.run('dart', ['run', 'server/local_server.dart']);
      _isConnected = true;
      notifyListeners();
    } catch (e) {
      if (kDebugMode) print('Server start failed: $e');
    }
  }

  Future<bool> connectToServer(String ip) async {
    try {
      final response = await _dio.get('http://$ip:8080/status');
      if (response.statusCode == 200) {
        _serverIp = ip;
        _isConnected = true;
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('serverIp', ip);
        
        notifyListeners();
        return true;
      }
    } catch (e) {
      if (kDebugMode) print('Connection error: $e');
    }
    return false;
  }

  Future<void> disconnect() async {
    _isConnected = false;
    notifyListeners();
  }
}