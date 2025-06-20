// services/search_service.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'search_result.dart';

class SearchService {
  static const String _nominatimBaseUrl = 'https://nominatim.openstreetmap.org/search';
  static const String _userAgent = 'FirefighterApp/1.0';

  /// Search for locations in Germany using Nominatim API
  Future<List<SearchResult>> searchLocation(String query) async {
    if (query.isEmpty) return [];

    try {
      final uri = Uri.parse(_nominatimBaseUrl).replace(queryParameters: {
        'format': 'json',
        'q': query,
        'countrycodes': 'de', // Restrict to Germany
        'limit': '5',
        'addressdetails': '1',
      });

      final response = await http.get(
        uri,
        headers: {'User-Agent': _userAgent},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List;
        return data
            .map((item) => SearchResult.fromNominatimJson(item as Map<String, dynamic>))
            .toList();
      } else {
        debugPrint('Search API error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      debugPrint('Search error: $e');
    }
    
    return [];
  }

  /// Search for locations with custom parameters
  Future<List<SearchResult>> searchLocationWithParams({
    required String query,
    String? countryCode,
    int limit = 5,
    bool includeAddressDetails = true,
  }) async {
    if (query.isEmpty) return [];

    try {
      final queryParams = <String, String>{
        'format': 'json',
        'q': query,
        'limit': limit.toString(),
      };

      if (countryCode != null) {
        queryParams['countrycodes'] = countryCode;
      }

      if (includeAddressDetails) {
        queryParams['addressdetails'] = '1';
      }

      final uri = Uri.parse(_nominatimBaseUrl).replace(queryParameters: queryParams);

      final response = await http.get(
        uri,
        headers: {'User-Agent': _userAgent},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List;
        return data
            .map((item) => SearchResult.fromNominatimJson(item as Map<String, dynamic>))
            .toList();
      } else {
        debugPrint('Search API error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      debugPrint('Search error: $e');
    }
    
    return [];
  }
}