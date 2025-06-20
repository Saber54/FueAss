import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class TacticalMarkerManager {
  final List<Marker> _tacticalMarkers = [];
  
  List<Marker> get markers => List.unmodifiable(_tacticalMarkers);
  int get count => _tacticalMarkers.length;

  void addVehicle(LatLng position) {
    _tacticalMarkers.add(
      Marker(
        width: 40,
        height: 40,
        point: position,
        child: const Icon(Icons.directions_car, color: Colors.blue, size: 40),
      ),
    );
  }

  void addHazard(LatLng position) {
    _tacticalMarkers.add(
      Marker(
        width: 40,
        height: 40,
        point: position,
        child: const Icon(Icons.warning, color: Colors.red, size: 40),
      ),
    );
  }

  void clear() {
    _tacticalMarkers.clear();
  }
}
