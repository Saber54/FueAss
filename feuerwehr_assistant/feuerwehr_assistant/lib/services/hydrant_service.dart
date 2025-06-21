import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:xml/xml.dart' as xml;
import 'package:http/http.dart' as http;
import 'hydrant_data.dart';

class HydrantService {
  Future<List<Marker>> loadOnlineHydrants(LatLngBounds bounds) async {
    try {
      debugPrint('Loading online hydrants for bounds: $bounds');
      
      final overpassQuery = '''
        [out:xml][timeout:25];
        (
          node["emergency"="fire_hydrant"](${bounds.south},${bounds.west},${bounds.north},${bounds.east});
          way["emergency"="fire_hydrant"](${bounds.south},${bounds.west},${bounds.north},${bounds.east});
        );
        out body;
      ''';

      debugPrint('Overpass query: $overpassQuery');

      final response = await http.get(
        Uri.parse('https://overpass-api.de/api/interpreter?data=${Uri.encodeComponent(overpassQuery)}'),
        headers: {
          'User-Agent': 'FireApp/1.0 (Contact: your-email@example.com)',
        },
      ).timeout(const Duration(seconds: 30));

      debugPrint('Response status: ${response.statusCode}');
      debugPrint('Response body length: ${response.body.length}');

      if (response.statusCode == 200) {
        final document = xml.XmlDocument.parse(response.body);
        final nodes = document.findAllElements('node');
        final ways = document.findAllElements('way');

        debugPrint('Found ${nodes.length} node elements and ${ways.length} way elements');

        final markers = _createHydrantMarkers(nodes);
        debugPrint('Created ${markers.length} hydrant markers');
        
        return markers;
      } else {
        debugPrint('HTTP Error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      debugPrint('Hydrant load error: $e');
      debugPrint('Stack trace: ${StackTrace.current}');
    }
    
    return [];
  }

  List<Marker> loadOfflineHydrants(List<HydrantData> hydrants, LatLngBounds bounds) {
    debugPrint('Loading offline hydrants. Total hydrants: ${hydrants.length}');
    final markers = <Marker>[];
    
    for (final hydrant in hydrants) {
      final point = LatLng(hydrant.lat, hydrant.lon);
      if (bounds.contains(point)) {
        markers.add(_createHydrantMarker(point));
      }
    }
    
    debugPrint('Created ${markers.length} offline hydrant markers for bounds');
    return markers;
  }

  List<Marker> _createHydrantMarkers(Iterable<xml.XmlElement> nodes) {
    final markers = <Marker>[];
    
    for (final node in nodes) {
      try {
        final lat = double.tryParse(node.getAttribute('lat') ?? '');
        final lon = double.tryParse(node.getAttribute('lon') ?? '');
        
        if (lat != null && lon != null) {
          final point = LatLng(lat, lon);
          markers.add(_createHydrantMarker(point));
          debugPrint('Added hydrant marker at: $lat, $lon');
        } else {
          debugPrint('Invalid coordinates for node: lat=$lat, lon=$lon');
        }
      } catch (e) {
        debugPrint('Error processing node: $e');
      }
    }
    
    return markers;
  }

  Marker _createHydrantMarker(LatLng point) {
    return Marker(
      width: 24.0, // Größer für bessere Sichtbarkeit
      height: 24.0,
      point: point,
      child: Container(
        width: 24.0,
        height: 24.0,
        decoration: BoxDecoration(
          color: Colors.red,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Icon(
          Icons.water_drop,
          color: Colors.white,
          size: 12,
        ),
      ),
    );
  }
}