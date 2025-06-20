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
import '../services/search_result.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  late final MapController _mapController;
  final GlobalKey _mapKey = GlobalKey();
  final TextEditingController _searchController = TextEditingController();

  final offline.OfflineDataManager _offlineManager = offline.OfflineDataManager();
  final search.SearchService _searchService = search.SearchService();
  final hydrant.HydrantService _hydrantService = hydrant.HydrantService();
  final PdfExportService _pdfService = PdfExportService();
  final TacticalMarkerManager _tacticalManager = TacticalMarkerManager();

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

  static const double _minZoomForHydrants = 12.0;
  static const double _boundsExpandFactor = 0.2;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _mapController.mapEventStream.listen((event) {
      if (_showHydrants && _isInitialized) {
        _handleMapMovement();
      }
    });
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
      final shouldPromptDownload = !_offlineManager.hasOfflineData();
      if (_offlineManager.isOfflineMode && _offlineManager.shouldUpdate()) {
        await _promptForUpdate();
      } else if (shouldPromptDownload) {
        await _promptForOfflineDownload();
      }
      setState(() => _isInitialized = true);
    } catch (e) {
      debugPrint('Error initializing offline data: $e');
      setState(() => _isInitialized = true);
    }
  }

  Future<void> _promptForOfflineDownload() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Offline-Karten herunterladen'),
        content: const Text('Möchten Sie die Kartendaten für Deutschland offline speichern?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Nein')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Ja')),
        ],
      ),
    );
    if (result == true) await _downloadOfflineData();
  }

  Future<void> _promptForUpdate() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Kartendaten aktualisieren'),
        content: Text('Kartendaten sind älter als 30 Tage. Jetzt aktualisieren?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Später')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Aktualisieren')),
        ],
      ),
    );
    if (result == true) await _downloadOfflineData();
  }

  Future<void> _downloadOfflineData() async {
    if (_isDownloading) return;
    setState(() => _isDownloading = true);
    try {
      await _offlineManager.downloadOfflineData(
        onProgress: (p) => setState(() => _downloadProgress = p),
        onError: (e) => debugPrint('Download error: $e'),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Offline-Daten erfolgreich geladen.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  void _handleMapMovement() {
    final zoom = _mapController.camera.zoom;
    final bounds = _mapController.camera.visibleBounds;
    if (zoom < _minZoomForHydrants) {
      if (_hydrantMarkers.isNotEmpty) setState(() => _hydrantMarkers.clear());
      return;
    }
    final shouldReload = _lastLoadedBounds == null ||
      _lastLoadedZoom != zoom ||
      !_lastLoadedBounds!.containsBounds(bounds);
    if (shouldReload) {
      final expanded = _expandBounds(bounds, _boundsExpandFactor);
      _loadHydrants(expanded);
      _lastLoadedBounds = expanded;
      _lastLoadedZoom = zoom;
    }
  }

  LatLngBounds _expandBounds(LatLngBounds b, double f) {
    final latDiff = b.north - b.south;
    final lngDiff = b.east - b.west;
    return LatLngBounds(
      LatLng(b.north + latDiff * f, b.west - lngDiff * f),
      LatLng(b.south - latDiff * f, b.east + lngDiff * f),
    );
  }

  Future<void> _loadHydrants(LatLngBounds bounds) async {
    if (!_showHydrants || !_isInitialized) return;
    try {
      final markers = _offlineManager.isOfflineMode
          ? _hydrantService.loadOfflineHydrants(_offlineManager.offlineHydrants, bounds)
          : await _hydrantService.loadOnlineHydrants(bounds);
      if (mounted) {
        setState(() {
          _hydrantMarkers.clear();
          _hydrantMarkers.addAll(markers);
        });
      }
    } catch (e) {
      debugPrint('Hydrant load error: $e');
    }
  }

  void _handleMapTap(TapPosition _, LatLng pos) => setState(() => _lastTapPosition = pos);
  void _addVehicle() => _lastTapPosition != null ? setState(() => _tacticalManager.addVehicle(_lastTapPosition!)) : null;
  void _addHazard() => _lastTapPosition != null ? setState(() => _tacticalManager.addHazard(_lastTapPosition!)) : null;

  Future<void> _searchLocation(String query) async {
    if (query.isEmpty) return;
    setState(() => _isSearching = true);
    final results = await _searchService.searchLocation(query);
    setState(() {
      _searchResults = results;
      _isSearching = false;
    });
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
    } finally {
      if (mounted) setState(() => _isCapturing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMaster = Provider.of<AuthProvider>(context).isMaster;
    return Scaffold(
      body: Stack(
        children: [
          RepaintBoundary(
            key: _mapKey,
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: const LatLng(51.1657, 10.4515),
                initialZoom: 6,
                onTap: _handleMapTap,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  tileProvider: (_offlineManager.isOfflineMode && _offlineManager.mapStore != null)
                      ? _offlineManager.mapStore!.getTileProvider()
                      : null,
                ),
                if (_hydrantMarkers.isNotEmpty) MarkerLayer(markers: _hydrantMarkers),
                if (_tacticalManager.markers.isNotEmpty)
                  MarkerClusterLayerWidget(
                    options: MarkerClusterLayerOptions(
                      maxClusterRadius: 60,
                      size: const Size(40, 40),
                      markers: _tacticalManager.markers,
                      builder: (context, markers) => markers.length == 1
                          ? markers.first.child
                          : CircleAvatar(
                              backgroundColor: Colors.blue,
                              child: Text('${markers.length}', style: const TextStyle(color: Colors.white)),
                            ),
                    ),
                  ),
              ],
            ),
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
                      ? const Padding(
                          padding: EdgeInsets.all(10),
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : null,
                  border: InputBorder.none,
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
                      title: Text(result.displayName),
                      onTap: () {
                        _mapController.move(
                          LatLng(result.latitude, result.longitude),
                          14.5,
                        );
                        setState(() {
                          _searchResults.clear();
                          _searchController.clear();
                        });
                      },
                    );
                  },
                ),
              ),
            ),
          Positioned(
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
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.picture_as_pdf),
            ),
          ),
          if (_isDownloading)
            Center(
              child: CircularProgressIndicator(value: _downloadProgress),
            ),
          Positioned(
            left: 10,
            bottom: 10,
            child: Card(
              child: Row(
                children: [
                  const Text('Hydranten'),
                  Switch(
                    value: _showHydrants,
                    onChanged: (value) {
                      setState(() {
                        _showHydrants = value;
                        _hydrantMarkers.clear();
                        _lastLoadedBounds = null;
                        _lastLoadedZoom = 0.0;
                      });
                      if (value && _isInitialized) {
                        final bounds = _mapController.camera.visibleBounds;
                        _loadHydrants(bounds);
                      }
                    },
                  ),
                ],
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
                  onPressed: _addVehicle,
                  child: const Icon(Icons.directions_car),
                ),
                const SizedBox(height: 10),
                FloatingActionButton(
                  onPressed: _addHazard,
                  child: const Icon(Icons.warning),
                ),
              ],
            )
          : null,
    );
  }
}
