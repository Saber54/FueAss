import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  final Dio _dio = Dio();
  final String _authEndpoint = '/api/auth';

  Future<bool> login(String deviceId, String pairingCode) async {
    try {
      final response = await _dio.post(
        _authEndpoint,
        data: {'deviceId': deviceId, 'code': pairingCode},
      );

      if (response.statusCode == 200) {
        final token = response.data['token'];
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('authToken', token);
        return true;
      }
    } catch (e) {
      return false;
    }
    return false;
  }

  Future<bool> validateToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('authToken');

    if (token == null) return false;

    try {
      final response = await _dio.get(
        '$_authEndpoint/validate',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}