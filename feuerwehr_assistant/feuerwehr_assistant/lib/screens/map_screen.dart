import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart' as xml;
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import 'package:flutter_map_marker_cluster_plus/flutter_map_marker_cluster_plus.dart';
import '../providers/auth_provider.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  late final MapController _mapController;
  final List<Marker> _tacticalMarkers = [];
  final List<Marker> _hydrantMarkers = [];
  LatLng? _lastTapPosition;
  bool _showHydrants = false;
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  List<Map<String, dynamic>> _searchResults = [];
  LatLngBounds? _lastLoadedBounds;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _mapController.mapEventStream.listen((event) {
      if (event is MapEventMove && _showHydrants) {
        _handleMapMovement();
      }
    });
  }

  void _handleMapMovement() {
    // Aktuelle Kamera Position und Zoom abrufen
    final camera = _mapController.camera;
    final bounds = camera.visibleBounds;
    
    if (_lastLoadedBounds == null || 
        !_lastLoadedBounds!.containsBounds(bounds)) {
      _loadHydrants(bounds);
      _lastLoadedBounds = bounds;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _searchLocation(String query) async {
    if (query.isEmpty) {
      setState(() => _searchResults = []);
      return;
    }

    setState(() => _isSearching = true);

    try {
      final response = await http.get(
        Uri.parse('https://nominatim.openstreetmap.org/search?format=json&q=${Uri.encodeQueryComponent(query)}&limit=5'),
        headers: {'User-Agent': 'FirefighterApp/1.0'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List;
        setState(() {
          _searchResults = data.map((item) => {
            'displayName': item['display_name'],
            'lat': double.parse(item['lat'].toString()),
            'lon': double.parse(item['lon'].toString()),
          }).toList();
        });
      }
    } catch (e) {
      debugPrint('Search error: $e');
    } finally {
      setState(() => _isSearching = false);
    }
  }

  void _zoomToLocation(LatLng location) {
    const zoomLevelFor2km = 14.5;
    _mapController.move(location, zoomLevelFor2km);
    setState(() {
      _searchResults = [];
      _searchController.clear();
    });
  }

  Future<void> _loadHydrants(LatLngBounds bounds) async {
    if (!_showHydrants) return;

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

        setState(() {
          _hydrantMarkers.clear();
          for (final node in nodes) {
            final lat = double.tryParse(node.getAttribute('lat') ?? '');
            final lon = double.tryParse(node.getAttribute('lon') ?? '');
            if (lat != null && lon != null) {
              _hydrantMarkers.add(
                Marker(
                  width: 40,
                  height: 40,
                  point: LatLng(lat, lon),
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
              );
            }
          }
        });
      }
    } catch (e) {
      debugPrint('Hydrant load error: $e');
    }
  }

  void _handleMapTap(TapPosition tapPosition, LatLng latlng) {
    setState(() {
      _lastTapPosition = latlng;
    });
  }

  void _addVehicle() {
    if (_lastTapPosition == null) return;
    setState(() {
      _tacticalMarkers.add(
        Marker(
          width: 40,
          height: 40,
          point: _lastTapPosition!,
          child: const Icon(
            Icons.directions_car,
            color: Colors.blue,
            size: 40,
          ),
        ),
      );
    });
  }

  void _addHazard() {
    if (_lastTapPosition == null) return;
    setState(() {
      _tacticalMarkers.add(
        Marker(
          width: 40,
          height: 40,
          point: _lastTapPosition!,
          child: const Icon(
            Icons.warning,
            color: Colors.red,
            size: 40,
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final isMaster = Provider.of<AuthProvider>(context).isMaster;
    final allMarkers = [..._tacticalMarkers, if (_showHydrants) ..._hydrantMarkers];

    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: const LatLng(51.1657, 10.4515),
              initialZoom: 12,
              onTap: _handleMapTap,
            ),
            children: [
              // Tile layer ohne Subdomains und ohne Caching
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.firefighter_app',
              ),
              
              // Marker cluster layer
              MarkerClusterLayerWidget(
                options: MarkerClusterLayerOptions(
                  maxClusterRadius: 60,
                  size: const Size(40, 40),
                  alignment: Alignment.center,
                  markers: allMarkers,
                  builder: (context, markers) {
                    if (markers.length == 1) {
                      return markers.first.child;
                    }
                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Center(
                        child: Text(
                          markers.length.toString(),
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 20,
            right: 20,
            child: Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(8),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Ort suchen...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _isSearching 
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2)
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                ),
                onSubmitted: _searchLocation,
              ),
            ),
          ),
          if (_searchResults.isNotEmpty)
            Positioned(
              top: MediaQuery.of(context).padding.top + 60,
              left: 20,
              right: 20,
              child: Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(8),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _searchResults.length,
                  itemBuilder: (context, index) {
                    final result = _searchResults[index];
                    return ListTile(
                      title: Text(result['displayName']),
                      onTap: () => _zoomToLocation(LatLng(result['lat'], result['lon'])),
                    );
                  },
                ),
              ),
            ),
          Positioned(
            left: 10,
            bottom: 10,
            child: Card(
              color: Colors.white.withOpacity(0.9),
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  children: [
                    const Text('Hydranten'),
                    Switch(
                      value: _showHydrants,
                      onChanged: (value) {
                        setState(() => _showHydrants = value);
                        if (value) {
                          final camera = _mapController.camera;
                          final bounds = camera.visibleBounds;
                          _loadHydrants(bounds);
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: isMaster
          ? Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                FloatingActionButton(
                  heroTag: 'add_vehicle',
                  onPressed: _addVehicle,
                  child: const Icon(Icons.directions_car),
                ),
                const SizedBox(height: 10),
                FloatingActionButton(
                  heroTag: 'add_hazard',
                  onPressed: _addHazard,
                  child: const Icon(Icons.warning),
                ),
              ],
            )
          : null,
    );
  }
}