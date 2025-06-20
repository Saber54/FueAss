import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:xml/xml.dart' as xml;
import 'package:http/http.dart' as http;
import 'hydrant_data.dart'; // Import der gemeinsamen HydrantData Klasse

class HydrantService {
  Future<List<Marker>> loadOnlineHydrants(LatLngBounds bounds) async {
    try {
      final overpassQuery = '''
        [out:xml];
        (
          node["emergency"="fire_hydrant"](${bounds.south},${bounds.west},${bounds.north},${bounds.east});
          way["emergency"="fire_hydrant"](${bounds.south},${bounds.west},${bounds.north},${bounds.east});
        );
        out body;
      ''';

      final response = await http.get(
        Uri.parse('https://overpass-api.de/api/interpreter?data=${Uri.encodeComponent(overpassQuery)}'),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final document = xml.XmlDocument.parse(response.body);
        final nodes = document.findAllElements('node');

        return _createHydrantMarkers(nodes);
      }
    } catch (e) {
      debugPrint('Hydrant load error: $e');
    }
    
    return [];
  }

  List<Marker> loadOfflineHydrants(List<HydrantData> hydrants, LatLngBounds bounds) {
    final markers = <Marker>[];
    
    for (final hydrant in hydrants) {
      final point = LatLng(hydrant.lat, hydrant.lon);
      if (bounds.contains(point)) {
        markers.add(_createHydrantMarker(point));
      }
    }
    
    return markers;
  }

  List<Marker> _createHydrantMarkers(Iterable<xml.XmlElement> nodes) {
    final markers = <Marker>[];
    
    for (final node in nodes) {
      final lat = double.tryParse(node.getAttribute('lat') ?? '');
      final lon = double.tryParse(node.getAttribute('lon') ?? '');
      if (lat != null && lon != null) {
        markers.add(_createHydrantMarker(LatLng(lat, lon)));
      }
    }
    
    return markers;
  }

  Marker _createHydrantMarker(LatLng point) {
    return Marker(
      width: 20,
      height: 20,
      point: point,
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: Colors.red,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 1),
        ),
      ),
    );
  }
}