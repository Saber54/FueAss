import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';

class NetworkUtils {
  static Future<bool> hasInternetConnection() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    return connectivityResult != ConnectivityResult.none;
  }

  static Dio createDioInstance({String? baseUrl}) {
    return Dio(BaseOptions(
      baseUrl: baseUrl ?? '',
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ))
      ..interceptors.add(LogInterceptor(
        requestBody: true,
        responseBody: true,
      ));
  }

  static String getErrorMessage(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout) {
      return 'Verbindung zeitüberschritten';
    } else if (e.response?.statusCode == 404) {
      return 'Ressource nicht gefunden';
    } else {
      return 'Netzwerkfehler: ${e.message}';
    }
  }
}