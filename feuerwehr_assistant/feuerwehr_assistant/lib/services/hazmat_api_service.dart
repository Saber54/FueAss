// ignore_for_file: unused_field

import 'package:dio/dio.dart';
import '../models/hazmat.dart';

class HazmatApiService {
  final Dio _dio;
  final String _baseUrl;

  HazmatApiService({required String baseUrl})
      : _baseUrl = baseUrl,
        _dio = Dio(BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 5),
        ));

  Future<List<Hazmat>> fetchHazmats() async {
    try {
      final response = await _dio.get('/api/hazmats');
      return (response.data as List)
          .map((json) => Hazmat.fromJson(json))
          .toList();
    } catch (e) {
      print('Fehler beim Laden der Gefahrgut-Daten: $e');
      return [];
    }
  }

  Future<bool> updateHazmat(Hazmat hazmat) async {
    try {
      await _dio.put(
        '/api/hazmats/${hazmat.id}',
        data: hazmat.toJson(),
      );
      return true;
    } catch (e) {
      print('Fehler beim Aktualisieren des Gefahrguts: $e');
      return false;
    }
  }

  Future<bool> deleteHazmat(String id) async {
    try {
      await _dio.delete('/api/hazmats/$id');
      return true;
    } catch (e) {
      print('Fehler beim Löschen des Gefahrguts: $e');
      return false;
    }
  }

  Future<bool> addHazmat(Hazmat hazmat) async {
    try {
      await _dio.post(
        '/api/hazmats',
        data: hazmat.toJson(),
      );
      return true;
    } catch (e) {
      print('Fehler beim Hinzufügen des Gefahrguts: $e');
      return false;
    }
  }
}