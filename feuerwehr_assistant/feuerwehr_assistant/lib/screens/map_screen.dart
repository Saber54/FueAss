import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart' as xml;
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
    if (_mapController.bounds == null) return;
    
    // Nur neu laden wenn sich die Bounds signifikant geändert haben
    if (_lastLoadedBounds == null || 
        !_lastLoadedBounds!.containsBounds(_mapController.bounds!)) {
      _loadHydrants(_mapController.bounds!);
      _lastLoadedBounds = _mapController.bounds;
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
                  width: 12,
                  height: 12,
                  point: LatLng(lat, lon),
                  builder: (ctx) => Container(
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

  void _handleMapTap(LatLng latlng) {
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
          builder: (ctx) => const Icon(
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
          builder: (ctx) => const Icon(
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

    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              center: const LatLng(51.1657, 10.4515),
              zoom: 12,
              onTap: (_, latlng) => _handleMapTap(latlng),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                subdomains: const ['a', 'b', 'c'],
              ),
              MarkerLayer(markers: _tacticalMarkers),
              if (_showHydrants) MarkerLayer(markers: _hydrantMarkers),
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
                      ? const CircularProgressIndicator(strokeWidth: 2)
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
                        if (value && _mapController.bounds != null) {
                          _loadHydrants(_mapController.bounds!);
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