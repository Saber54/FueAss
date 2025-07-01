import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class TacticalMarkerManager {
  final List<Marker> _markers = [];

  void addVehicle(LatLng position) {
    _markers.add(
      Marker(
        width: 40,
        height: 40,
        point: position,
        child: const Icon(Icons.directions_car, color: Colors.blue, size: 40),
      ),
    );
  }

  void addHazard(LatLng position) {
    _markers.add(
      Marker(
        width: 40,
        height: 40,
        point: position,
        child: const Icon(Icons.warning, color: Colors.red, size: 40),
      ),
    );
  }

  void addCustomMarker(Marker marker) {
    _markers.add(marker);
  }

  List<Marker> get markers => List.unmodifiable(_markers);

  int get count => _markers.length;

  void clearAll() {
    _markers.clear();
  }

  void removeMarker(Marker marker) {
    _markers.remove(marker);
  }
}
