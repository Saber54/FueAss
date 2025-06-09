import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/log_entry.dart';
import '../models/hazmat.dart';

class SyncService {
  final Dio _dio = Dio();
  final String _syncEndpoint = '/api/sync';

  Future<bool> syncLogs(List<LogEntry> logs) async {
    final prefs = await SharedPreferences.getInstance();
    final serverIp = prefs.getString('serverIp');
    
    try {
      await _dio.post(
        'http://$serverIp$_syncEndpoint/logs',
        data: logs.map((log) => log.toJson()).toList(),
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> syncHazmats(List<Hazmat> hazmats) async {
    final prefs = await SharedPreferences.getInstance();
    final serverIp = prefs.getString('serverIp');

    try {
      await _dio.post(
        'http://$serverIp$_syncEndpoint/hazmats',
        data: hazmats.map((h) => h.toJson()).toList(),
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> autoSync() async {
    // Wird alle 5 Minuten aufgerufen
    // Implementierung je nach Datenquelle
  }
}