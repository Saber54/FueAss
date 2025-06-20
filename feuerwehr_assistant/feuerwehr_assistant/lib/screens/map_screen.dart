// screens/map_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster_plus/flutter_map_marker_cluster_plus.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/offline_data_manager.dart' as offline;
import '../services/search_service.dart' as search;
import '../services/hydrant_service.dart' as hydrant;
import '../services/pdf_export_service.dart';
import '../services/tactical_marker_manager.dart';
import '../services/search_result.dart'; // Import the shared model

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  // Controllers and Keys
  late final MapController _mapController;
  final GlobalKey _mapKey = GlobalKey();
  final TextEditingController _searchController = TextEditingController();

  // Services
  final offline.OfflineDataManager _offlineManager = offline.OfflineDataManager();
  final search.SearchService _searchService = search.SearchService();
  final hydrant.HydrantService _hydrantService = hydrant.HydrantService();
  final PdfExportService _pdfService = PdfExportService();
  final TacticalMarkerManager _tacticalManager = TacticalMarkerManager();

  // State
  final List<Marker> _hydrantMarkers = [];
  LatLng? _lastTapPosition;
  bool _showHydrants = false;
  bool _isSearching = false;
  bool _isCapturing = false;
  bool _isDownloading = false;
  bool _isInitialized = false;
  double _downloadProgress = 0.0;
  List<SearchResult> _searchResults = [];
  LatLngBounds? _lastLoadedBounds;
  double _lastLoadedZoom = 0.0;

  // Konstanten für Hydranten-Loading
  static const double _minZoomForHydrants = 12.0;
  static const double _boundsExpandFactor = 0.2; // 20% Puffer um sichtbaren Bereich

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    
    // Debounced map movement handling
    _mapController.mapEventStream.listen((event) {
      if (event is MapEventMove && _showHydrants && _isInitialized) {
        _handleMapMovement();
      }
    });
    
    // Initialize after the first frame to ensure context is available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeOfflineData();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _initializeOfflineData() async {
    if (!mounted) return;
    
    try {
      await _offlineManager.initialize();
      
      // Check if we need to prompt for download regardless of current offline status
      final shouldPromptDownload = !_offlineManager.hasOfflineData();
      
      if (_offlineManager.isOfflineMode && _offlineManager.shouldUpdate()) {
        await _promptForUpdate();
      } else if (shouldPromptDownload) {
        await _promptForOfflineDownload();
      }
      
      setState(() {
        _isInitialized = true;
      });
    } catch (e) {
      debugPrint('Error initializing offline data: $e');
      setState(() {
        _isInitialized = true;
      });
    }
  }

  Future<void> _promptForOfflineDownload() async {
    if (!mounted) return;
    
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
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
    if (!mounted) return;
    
    final daysSinceUpdate = DateTime.now().difference(_offlineManager.lastMapUpdate!).inDays;
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Kartendaten aktualisieren'),
        content: Text(
          'Die Kartendaten sind $daysSinceUpdate Tage alt. '
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
    if (_isDownloading || !mounted) return;
    
    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
    });
    
    try {
      await _offlineManager.downloadOfflineData(
        onProgress: (progress) {
          if (mounted) {
            setState(() => _downloadProgress = progress);
          }
        },
        onError: (error) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Fehler beim Download: $error')),
            );
          }
        },
      );
      
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
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _downloadProgress = 0.0;
        });
      }
    }
  }

  void _handleMapMovement() {
    final camera = _mapController.camera;
    final currentZoom = camera.zoom;
    final bounds = camera.visibleBounds;
    
    // Only load hydrants if zoom level is sufficient
    if (currentZoom < _minZoomForHydrants) {
      if (_hydrantMarkers.isNotEmpty) {
        setState(() {
          _hydrantMarkers.clear();
          _lastLoadedBounds = null;
          _lastLoadedZoom = 0.0;
        });
      }
      return;
    }
    
    // Check if we need to reload hydrants
    final shouldReload = _lastLoadedBounds == null ||
        _lastLoadedZoom != currentZoom ||
        !_isWithinExpandedBounds(_lastLoadedBounds!, bounds);
    
    if (shouldReload) {
      // Expand bounds for preloading
      final expandedBounds = _expandBounds(bounds, _boundsExpandFactor);
      _loadHydrants(expandedBounds);
      _lastLoadedBounds = expandedBounds;
      _lastLoadedZoom = currentZoom;
    }
  }

  bool _isWithinExpandedBounds(LatLngBounds loadedBounds, LatLngBounds currentBounds) {
    return loadedBounds.contains(currentBounds.northEast) &&
           loadedBounds.contains(currentBounds.southWest) &&
           loadedBounds.contains(currentBounds.northWest) &&
           loadedBounds.contains(currentBounds.southEast);
  }

  LatLngBounds _expandBounds(LatLngBounds bounds, double factor) {
    final latDiff = bounds.north - bounds.south;
    final lngDiff = bounds.east - bounds.west;
    
    return LatLngBounds(
      LatLng(bounds.north + latDiff * factor, bounds.west - lngDiff * factor),
      LatLng(bounds.south - latDiff * factor, bounds.east + lngDiff * factor),
    );
  }

  Future<void> _loadHydrants(LatLngBounds bounds) async {
    if (!_showHydrants || !_isInitialized) return;

    List<Marker> markers;
    
    try {
      if (_offlineManager.isOfflineMode) {
        markers = _hydrantService.loadOfflineHydrants(_offlineManager.offlineHydrants, bounds);
      } else {
        markers = await _hydrantService.loadOnlineHydrants(bounds);
      }
      
      if (mounted) {
        setState(() {
          _hydrantMarkers.clear();
          _hydrantMarkers.addAll(markers);
        });
      }
    } catch (e) {
      debugPrint('Error loading hydrants: $e');
    }
  }

  Future<void> _searchLocation(String query) async {
    if (query.isEmpty) {
      setState(() => _searchResults = []);
      return;
    }

    setState(() => _isSearching = true);
    
    try {
      final results = await _searchService.searchLocation(query);
      
      if (mounted) {
        setState(() {
          _searchResults = results;
          _isSearching = false;
        });
      }
    } catch (e) {
      debugPrint('Search error: $e');
      if (mounted) {
        setState(() => _isSearching = false);
      }
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

  void _handleMapTap(TapPosition tapPosition, LatLng latlng) {
    setState(() => _lastTapPosition = latlng);
  }

  void _addVehicle() {
    if (_lastTapPosition == null) return;
    _tacticalManager.addVehicle(_lastTapPosition!);
    setState(() {});
  }

  void _addHazard() {
    if (_lastTapPosition == null) return;
    _tacticalManager.addHazard(_lastTapPosition!);
    setState(() {});
  }

  Future<void> _captureAndPrintMap() async {
    if (_isCapturing) return;
    
    setState(() => _isCapturing = true);
    
    try {
      final imageBytes = await _pdfService.captureMapAsImage(_mapKey);
      
      if (imageBytes != null && mounted) {
        final pdf = _pdfService.createMapPDF(
          imageBytes,
          _mapController,
          _offlineManager.isOfflineMode,
          _showHydrants,
          _hydrantMarkers.length,
          _tacticalManager.count,
        );
        
        await _pdfService.showExportDialog(context, pdf);
      }
    } catch (e) {
      debugPrint('Error capturing map: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler beim Erstellen der Karte: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCapturing = false);
      }
    }
  }

  Widget _buildDownloadProgressOverlay() {
    if (!_isDownloading) return const SizedBox.shrink();
    
    return Container(
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
    );
  }

  Widget _buildSearchField() {
    return Positioned(
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
                    child: Padding(
                      padding: EdgeInsets.all(10),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
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
    );
  }

  Widget _buildPdfButton() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 70,
      right: 20,
      child: FloatingActionButton(
        heroTag: 'pdf_export',
        onPressed: _isCapturing ? null : _captureAndPrintMap,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        child: _isCapturing 
            ? const SizedBox(
                width: 20, 
                height: 20, 
                child: CircularProgressIndicator(strokeWidth: 2)
              )
            : const Icon(Icons.picture_as_pdf),
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_searchResults.isEmpty) return const SizedBox.shrink();
    
    return Positioned(
      top: MediaQuery.of(context).padding.top + 60,
      left: 20,
      right: 20,
      child: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          constraints: const BoxConstraints(maxHeight: 200),
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _searchResults.length,
            itemBuilder: (context, index) {
              final result = _searchResults[index];
              return ListTile(
                title: Text(result.displayName),
                subtitle: result.type.isNotEmpty ? Text(result.type) : null,
                leading: result.icon != null 
                    ? Image.network(
                        result.icon!, 
                        width: 20, 
                        height: 20, 
                        errorBuilder: (_, __, ___) => const Icon(Icons.place)
                      )
                    : const Icon(Icons.place),
                onTap: () => _zoomToLocation(LatLng(result.latitude, result.longitude)),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildControlPanel() {
    return Positioned(
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
                      setState(() {
                        _showHydrants = value;
                        if (!value) {
                          _hydrantMarkers.clear();
                          _lastLoadedBounds = null;
                          _lastLoadedZoom = 0.0;
                        }
                      });
                      
                      if (value && _isInitialized) {
                        final camera = _mapController.camera;
                        if (camera.zoom >= _minZoomForHydrants) {
                          final bounds = camera.visibleBounds;
                          _loadHydrants(bounds);
                        }
                      }
                    },
                  ),
                ],
              ),
              if (_offlineManager.isOfflineMode)
                const Row(
                  children: [
                    Icon(Icons.offline_bolt, size: 16, color: Colors.green),
                    SizedBox(width: 4),
                    Text('Deutschland Offline', style: TextStyle(fontSize: 12)),
                  ],
                ),
              if (_showHydrants && _mapController.camera.zoom < _minZoomForHydrants)
                const Text(
                  'Zum Anzeigen näher zoomen',
                  style: TextStyle(fontSize: 10, color: Colors.grey),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMaster = Provider.of<AuthProvider>(context).isMaster;
    
    return Scaffold(
      body: Stack(
        children: [
          // Main Map
          RepaintBoundary(
            key: _mapKey,
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: const LatLng(51.1657, 10.4515), // Deutschland Zentrum
                initialZoom: 6,
                minZoom: 5,
                maxZoom: 18,
                // Erweiterte Grenzen für Deutschland mit mehr Spielraum
                cameraConstraint: CameraConstraint.contain(
                  bounds: LatLngBounds(
                    const LatLng(56.0, 4.0),  // Nord-West (erweitert)
                    const LatLng(46.0, 16.0), // Süd-Ost (erweitert)
                  ),
                ),
                onTap: _handleMapTap,
              ),
              children: [
                // Tile Layer
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.firefighter_app',
                  tileProvider: (_offlineManager.isOfflineMode && _offlineManager.mapStore != null) 
                      ? _offlineManager.mapStore!.getTileProvider()
                      : null,
                ),
                
                // Hydranten Marker (nicht geclustert)
                if (_showHydrants && _hydrantMarkers.isNotEmpty)
                  MarkerLayer(markers: _hydrantMarkers),
                
                // Taktische Marker (geclustert)
                if (_tacticalManager.markers.isNotEmpty)
                  MarkerClusterLayerWidget(
                    options: MarkerClusterLayerOptions(
                      maxClusterRadius: 60,
                      size: const Size(40, 40),
                      alignment: Alignment.center,
                      markers: _tacticalManager.markers,
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
          ),
          
          // Overlays
          _buildDownloadProgressOverlay(),
          _buildSearchField(),
          _buildPdfButton(),
          _buildSearchResults(),
          _buildControlPanel(),
        ],
      ),
      
      // Floating Action Buttons für Master-Benutzer
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