import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart' as xml;
import 'package:path_provider/path_provider.dart';
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
  
  // Offline/Caching Variablen
  bool _isOfflineMode = false;
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  String? _offlineDataPath;
  List<Map<String, dynamic>> _offlineHydrants = [];
  DateTime? _lastMapUpdate;
  FMTCStore? _mapStore;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _mapController.mapEventStream.listen((event) {
      if (event is MapEventMove && _showHydrants) {
        _handleMapMovement();
      }
    });
    _initializeOfflineData();
  }

  Future<void> _initializeOfflineData() async {
    try {
      // Initialisiere FMTC
     await FMTCObjectBoxBackend().initialise();
      _mapStore = FMTCStore('mapCache');
      
      final appDir = await getApplicationDocumentsDirectory();
      _offlineDataPath = '${appDir.path}/map_data';
      
      final mapDataDir = Directory(_offlineDataPath!);
      final hydrantFile = File('${_offlineDataPath!}/hydrants.json');
      final metaFile = File('${_offlineDataPath!}/meta.json');
      
      if (await mapDataDir.exists() && await hydrantFile.exists() && await metaFile.exists()) {
        // Lade Offline-Daten
        await _loadOfflineData();
        
        // Prüfe auf Updates
        await _checkForUpdates();
      } else {
        // Frage nach Download
        await _promptForOfflineDownload();
      }
    } catch (e) {
      debugPrint('Offline data initialization error: $e');
    }
  }

  Future<void> _loadOfflineData() async {
    try {
      final hydrantFile = File('${_offlineDataPath!}/hydrants.json');
      final metaFile = File('${_offlineDataPath!}/meta.json');
      
      if (await hydrantFile.exists()) {
        final hydrantData = await hydrantFile.readAsString();
        _offlineHydrants = List<Map<String, dynamic>>.from(jsonDecode(hydrantData));
      }
      
      if (await metaFile.exists()) {
        final metaData = await metaFile.readAsString();
        final meta = jsonDecode(metaData);
        _lastMapUpdate = DateTime.parse(meta['lastUpdate']);
      }
      
      setState(() {
        _isOfflineMode = true;
      });
      
      // Erstelle Store falls nicht vorhanden
      if (_mapStore != null && !await _mapStore!.manage.ready) {
        await _mapStore!.manage.create();
      }
      
      debugPrint('Offline data loaded successfully');
    } catch (e) {
      debugPrint('Error loading offline data: $e');
    }
  }

  Future<void> _checkForUpdates() async {
    if (_lastMapUpdate == null) return;
    
    final daysSinceUpdate = DateTime.now().difference(_lastMapUpdate!).inDays;
    
    if (daysSinceUpdate > 30) { // Prüfe monatlich
      await _promptForUpdate();
    }
  }

  Future<void> _promptForOfflineDownload() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Offline-Karten herunterladen'),
        content: const Text(
          'Möchten Sie die Kartendaten und Hydranten-Informationen für Deutschland für die Offline-Nutzung herunterladen? '
          'Dies ermöglicht die Nutzung ohne Internetverbindung.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Nein, online verwenden'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Ja, herunterladen'),
          ),
        ],
      ),
    );
    
    if (result == true) {
      await _downloadOfflineData();
    }
  }

  Future<void> _promptForUpdate() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Kartendaten aktualisieren'),
        content: Text(
          'Die Kartendaten sind ${DateTime.now().difference(_lastMapUpdate!).inDays} Tage alt. '
          'Möchten Sie sie aktualisieren?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Später'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Aktualisieren'),
          ),
        ],
      ),
    );
    
    if (result == true) {
      await _downloadOfflineData();
    }
  }

  Future<void> _downloadOfflineData() async {
    if (_isDownloading) return;
    
    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
    });
    
    try {
      // Erstelle Verzeichnis
      final mapDataDir = Directory(_offlineDataPath!);
      if (!await mapDataDir.exists()) {
        await mapDataDir.create(recursive: true);
      }
      
      // Download Hydranten-Daten (Deutschland)
      setState(() => _downloadProgress = 0.1);
      await _downloadHydrantData();
      
      // Download Karten-Tiles für Deutschland
      setState(() => _downloadProgress = 0.3);
      await _downloadMapTiles();
      
      // Speichere Metadaten
      setState(() => _downloadProgress = 0.9);
      await _saveMetadata();
      
      setState(() {
        _downloadProgress = 1.0;
        _isOfflineMode = true;
      });
      
      await _loadOfflineData();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Offline-Daten für Deutschland erfolgreich heruntergeladen!')),
        );
      }
      
    } catch (e) {
      debugPrint('Download error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler beim Download: $e')),
        );
      }
    } finally {
      setState(() {
        _isDownloading = false;
        _downloadProgress = 0.0;
      });
    }
  }

  Future<void> _downloadHydrantData() async {
    // Deutschland Bounding Box (erweitert für komplette Abdeckung)
    const double north = 55.1;
    const double south = 47.2;
    const double east = 15.1;
    const double west = 5.8;
    
    final overpassQuery = '''
      [out:json][timeout:600];
      (
        node["emergency"="fire_hydrant"]($south,$west,$north,$east);
        way["emergency"="fire_hydrant"]($south,$west,$north,$east);
      );
      out body;
    ''';
    
    final response = await http.get(
      Uri.parse('https://overpass-api.de/api/interpreter?data=${Uri.encodeComponent(overpassQuery)}'),
    ).timeout(const Duration(minutes: 15));
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final elements = data['elements'] as List;
      
      final hydrants = elements.where((element) => element['type'] == 'node').map((node) => {
        'lat': node['lat'],
        'lon': node['lon'],
        'tags': node['tags'] ?? {},
      }).toList();
      
      final hydrantFile = File('${_offlineDataPath!}/hydrants.json');
      await hydrantFile.writeAsString(jsonEncode(hydrants));
      
      debugPrint('Downloaded ${hydrants.length} hydrants for Germany');
      setState(() => _downloadProgress = 0.7);
    }
  }

  Future<void> _downloadMapTiles() async {
    if (_mapStore == null) return;
    
    try {
      // Erstelle Store falls nicht vorhanden
      if (!await _mapStore!.manage.ready) {
        await _mapStore!.manage.create();
      }
      
      // Deutschland Bounding Box
      final region = RectangleRegion(
        LatLngBounds(
          const LatLng(55.1, 5.8),  // Nord-West
          const LatLng(47.2, 15.1), // Süd-Ost
        ),
      );
      
      final downloadable = region.toDownloadable(
        minZoom: 6,
        maxZoom: 14, // Reduziert für schnelleren Download
        options: TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.firefighter_app',
        ),
      );
      
      // Download mit Progress-Tracking
      final downloadProgress = _mapStore!.download.startForeground(
        region: downloadable,
      );
      
      final download = _mapStore!.download.startForeground(
  region: downloadable,
);

await for (final progress in download.downloadProgress) {
  setState(() {
    _downloadProgress = 0.3 + (progress.percentageProgress / 100) * 0.4;
  });

 if (progress.percentageProgress >= 100) {
  break;
}

}
      
      debugPrint('Map tiles download completed for Germany');
    } catch (e) {
      debugPrint('Map tiles download error: $e');
      throw e;
    }
  }

  Future<void> _saveMetadata() async {
    final metaFile = File('${_offlineDataPath!}/meta.json');
    final metadata = {
      'lastUpdate': DateTime.now().toIso8601String(),
      'version': '1.0',
      'region': 'Germany',
    };
    await metaFile.writeAsString(jsonEncode(metadata));
  }

  void _handleMapMovement() {
    final camera = _mapController.camera;
    final bounds = camera.visibleBounds;
    
    if (_lastLoadedBounds == null || 
        !_lastLoadedBounds!.containsBounds(bounds)) {
      if (_isOfflineMode) {
        _loadOfflineHydrants(bounds);
      } else {
        _loadHydrants(bounds);
      }
      _lastLoadedBounds = bounds;
    }
  }

  void _loadOfflineHydrants(LatLngBounds bounds) {
    setState(() {
      _hydrantMarkers.clear();
      for (final hydrant in _offlineHydrants) {
        final lat = hydrant['lat'] as double;
        final lon = hydrant['lon'] as double;
        final point = LatLng(lat, lon);
        
        if (bounds.contains(point)) {
          _hydrantMarkers.add(
            Marker(
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
            ),
          );
        }
      }
    });
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
      // Beschränke Suche auf Deutschland
      final response = await http.get(
        Uri.parse('https://nominatim.openstreetmap.org/search?format=json&q=${Uri.encodeQueryComponent(query)}&countrycodes=de&limit=5'),
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
                  width: 20,
                  height: 20,
                  point: LatLng(lat, lon),
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1),
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
    
    // Separate Marker-Listen für Clustering
    final clusterMarkers = [..._tacticalMarkers]; // Nur taktische Marker clustern

    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              // Deutschland Zentrum
              initialCenter: const LatLng(51.1657, 10.4515),
              initialZoom: 6,
              // Begrenze auf Deutschland
              cameraConstraint: CameraConstraint.contain(
                bounds: LatLngBounds(
                  const LatLng(55.1, 5.8),  // Nord-West
                  const LatLng(47.2, 15.1), // Süd-Ost
                ),
              ),
              onTap: _handleMapTap,
            ),
            children: [
              // Tile layer
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.firefighter_app',
                tileProvider: (_isOfflineMode && _mapStore != null) 
                    ? _mapStore!.getTileProvider()
                    : null,
              ),
              
              // Hydranten-Marker (nicht geclustert)
              if (_showHydrants)
                MarkerLayer(markers: _hydrantMarkers),
              
              // Taktische Marker (geclustert)
              if (clusterMarkers.isNotEmpty)
                MarkerClusterLayerWidget(
                  options: MarkerClusterLayerOptions(
                    maxClusterRadius: 60,
                    size: const Size(40, 40),
                    alignment: Alignment.center,
                    markers: clusterMarkers,
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
          
          // Download Progress Overlay
          if (_isDownloading)
            Container(
              color: Colors.black54,
              child: Center(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Lade Deutschland-Karten herunter...',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),
                        LinearProgressIndicator(value: _downloadProgress),
                        const SizedBox(height: 8),
                        Text('${(_downloadProgress * 100).toInt()}%'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          
          // Suchfeld
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
                  hintText: 'Ort in Deutschland suchen...',
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
          
          // Suchergebnisse
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
          
          // Steuerungspanel
          Positioned(
            left: 10,
            bottom: 10,
            child: Card(
              color: Colors.white.withOpacity(0.9),
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const Text('Hydranten'),
                        Switch(
                          value: _showHydrants,
                          onChanged: (value) {
                            setState(() => _showHydrants = value);
                            if (value) {
                              final camera = _mapController.camera;
                              final bounds = camera.visibleBounds;
                              if (_isOfflineMode) {
                                _loadOfflineHydrants(bounds);
                              } else {
                                _loadHydrants(bounds);
                              }
                            }
                          },
                        ),
                      ],
                    ),
                    if (_isOfflineMode)
                      const Row(
                        children: [
                          Icon(Icons.offline_bolt, size: 16, color: Colors.green),
                          SizedBox(width: 4),
                          Text('Deutschland Offline', style: TextStyle(fontSize: 12)),
                        ],
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