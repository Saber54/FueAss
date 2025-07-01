// screens/map_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster_plus/flutter_map_marker_cluster_plus.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/services.dart';

import '../providers/auth_provider.dart';
import '../services/offline_data_manager.dart' as offline;
import '../services/search_service.dart' as search;
import '../services/hydrant_service.dart' as hydrant;
import '../services/pdf_export_service.dart';
import '../services/tactical_marker_manager.dart';
import '../services/search_result.dart';
import '../services/tactical_symbol_service.dart';
import '../services/tactical_symbols_loader.dart' as loader;
import '../widgets/tactical_symbol_selector.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with TickerProviderStateMixin {
  late final MapController _mapController;
  final GlobalKey _mapKey = GlobalKey();
  final TextEditingController _searchController = TextEditingController();
  late AnimationController _fabAnimationController;
  late AnimationController _searchAnimationController;

  final offline.OfflineDataManager _offlineManager =
      offline.OfflineDataManager();
  final search.SearchService _searchService = search.SearchService();
  final hydrant.HydrantService _hydrantService = hydrant.HydrantService();
  final PdfExportService _pdfService = PdfExportService();
  final TacticalMarkerManager _tacticalManager = TacticalMarkerManager();
  final TacticalSymbolService _tacticalSymbolService = TacticalSymbolService();
  final loader.TacticalSymbolsLoader _tacticalSymbolsLoader =
      loader.TacticalSymbolsLoader();

  final List<Marker> _hydrantMarkers = [];
  final List<DraggableMarkerData> _draggableMarkers = [];
  int _nextMarkerId = 1;

  LatLng? _lastTapPosition;
  bool _showHydrants = false;
  bool _isSearching = false;
  bool _isCapturing = false;
  bool _isDownloading = false;
  bool _isInitialized = false;
  bool _showControls = true;
  bool _showTacticalMenu = false;
  bool _isMapReady = false; // HINZUGEFÜGT: Flag für Map-Bereitschaft
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
    _fabAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _searchAnimationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    // KORRIGIERT: Warten bis Map gerendert ist
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeServices();
      // Verzögerung für Map-Initialisierung
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          setState(() => _isMapReady = true);

          // KORRIGIERT: Event Stream erst nach Map-Bereitschaft
          _mapController.mapEventStream.listen((event) {
            if (_showHydrants && _isInitialized && _isMapReady) {
              _handleMapMovement();
            }
          });
        }
      });
    });

    // Lade taktische Zeichen
    _tacticalSymbolsLoader.loadSymbols();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _mapController.dispose();
    _fabAnimationController.dispose();
    _searchAnimationController.dispose();
    super.dispose();
  }

  Future<void> _initializeServices() async {
    if (!mounted) return;
    try {
      await _tacticalSymbolService.initialize();
      await _offlineManager.initialize();

      final shouldPromptDownload = !_offlineManager.hasOfflineData();
      if (_offlineManager.isOfflineMode && _offlineManager.shouldUpdate()) {
        await _promptForUpdate();
      } else if (shouldPromptDownload) {
        await _promptForOfflineDownload();
      }

      setState(() => _isInitialized = true);

      if (_showHydrants && _isMapReady) {
        _handleMapMovement();
      }
    } catch (e) {
      debugPrint('Error initializing services: $e');
      setState(() => _isInitialized = true);
    }
  }

  Future<void> _promptForOfflineDownload() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.cloud_download_outlined,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
                const SizedBox(width: 12),
                const Text('Offline-Karten'),
              ],
            ),
            content: const Text(
              'Möchten Sie die Kartendaten für Deutschland offline speichern? Dies ermöglicht die Nutzung ohne Internetverbindung.',
              style: TextStyle(fontSize: 16),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Später'),
              ),
              ElevatedButton.icon(
                onPressed: () => Navigator.pop(context, true),
                icon: const Icon(Icons.download),
                label: const Text('Herunterladen'),
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
    );
    if (result == true) await _downloadOfflineData();
  }

  Future<void> _promptForUpdate() async {
    final result = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.update, color: Colors.orange),
                ),
                const SizedBox(width: 12),
                const Text('Update verfügbar'),
              ],
            ),
            content: const Text(
              'Kartendaten sind älter als 30 Tage. Möchten Sie diese jetzt aktualisieren?',
              style: TextStyle(fontSize: 16),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Später'),
              ),
              ElevatedButton.icon(
                onPressed: () => Navigator.pop(context, true),
                icon: const Icon(Icons.refresh),
                label: const Text('Aktualisieren'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
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
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Offline-Daten erfolgreich geladen'),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  void _handleMapMovement() {
    // KORRIGIERT: Prüfung auf Map-Bereitschaft
    if (!_isMapReady) return;

    try {
      final zoom = _mapController.camera.zoom;
      final bounds = _mapController.camera.visibleBounds;

      if (zoom < _minZoomForHydrants) {
        if (_hydrantMarkers.isNotEmpty) {
          setState(() => _hydrantMarkers.clear());
        }
        return;
      }

      final shouldReload =
          _lastLoadedBounds == null ||
          _lastLoadedZoom != zoom ||
          !_lastLoadedBounds!.containsBounds(bounds);

      if (shouldReload) {
        final expanded = _expandBounds(bounds, _boundsExpandFactor);
        _loadHydrants(expanded);
        _lastLoadedBounds = expanded;
        _lastLoadedZoom = zoom;
      }
    } catch (e) {
      debugPrint('Error in _handleMapMovement: $e');
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
      List<Marker> markers;

      if (_offlineManager.isOfflineMode && _offlineManager.hasOfflineData()) {
        markers = _hydrantService.loadOfflineHydrants(
          _offlineManager.offlineHydrants,
          bounds,
        );
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
      debugPrint('Hydrant load error: $e');
      if (_offlineManager.isOfflineMode) {
        try {
          final markers = await _hydrantService.loadOnlineHydrants(bounds);
          if (mounted) {
            setState(() {
              _hydrantMarkers.clear();
              _hydrantMarkers.addAll(markers);
            });
          }
        } catch (fallbackError) {
          debugPrint('Fallback also failed: $fallbackError');
        }
      }
    }
  }

  void _handleMapTap(TapPosition _, LatLng pos) {
    setState(() => _lastTapPosition = pos);
    if (_showControls) {
      setState(() => _showControls = false);
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) setState(() => _showControls = true);
      });
    }
    if (_showTacticalMenu) {
      setState(() => _showTacticalMenu = false);
    }
  }

  Future<void> _searchLocation(String query) async {
    if (query.trim().isEmpty) return;

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
        setState(() {
          _isSearching = false;
          _searchResults = [];
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                Text('Suchfehler: ${e.toString()}'),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    }
  }

  void _showTacticalSymbolSelector() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) =>
              TacticalSymbolSelector(onSymbolSelected: _addTacticalSymbol),
    );
  }

  void _addTacticalSymbol(loader.TacticalSymbol symbol) {
    LatLng targetPosition;

    if (_lastTapPosition == null) {
      // KORRIGIERT: Sichere Prüfung auf Map-Bereitschaft
      if (_isMapReady) {
        try {
          targetPosition = _mapController.camera.center;
        } catch (e) {
          targetPosition = const LatLng(51.1657, 10.4515);
        }
      } else {
        targetPosition = const LatLng(51.1657, 10.4515);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.info, color: Colors.white),
              SizedBox(width: 8),
              Text('Symbol in Kartenmitte hinzugefügt'),
            ],
          ),
          backgroundColor: Colors.blue,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          duration: const Duration(seconds: 2),
        ),
      );
    } else {
      targetPosition = _lastTapPosition!;
    }

    final markerData = DraggableMarkerData(
      id: 'marker_${_nextMarkerId++}',
      symbol: symbol,
      position: targetPosition,
    );

    setState(() {
      _draggableMarkers.add(markerData);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Text('${symbol.name} hinzugefügt (ziehen zum Verschieben)'),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _moveMarker(String markerId, LatLng newPosition) {
    setState(() {
      final markerIndex = _draggableMarkers.indexWhere((m) => m.id == markerId);
      if (markerIndex != -1) {
        _draggableMarkers[markerIndex].position = newPosition;
      }
    });
  }

  void _removeMarker(String markerId) {
    setState(() {
      _draggableMarkers.removeWhere((m) => m.id == markerId);
    });
  }

  void _showSymbolInfo(loader.TacticalSymbol symbol, [String? markerId]) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(symbol.name),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SvgPicture.asset(
                  symbol.assetPath,
                  width: 100,
                  height: 100,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(
                      Icons.image_not_supported,
                      color: Colors.red,
                      size: 100,
                    );
                  },
                ),
                const SizedBox(height: 16),
                Text(
                  'Kategorie: ${_tacticalSymbolsLoader.getCategoryDisplayName(symbol.category)}',
                ),
                if (markerId != null) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Lange drücken und ziehen zum Verschieben',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ],
            ),
            actions: [
              if (markerId != null)
                TextButton(
                  onPressed: () {
                    _removeMarker(markerId);
                    Navigator.pop(context);
                  },
                  child: const Text(
                    'Löschen',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Schließen'),
              ),
            ],
          ),
    );
  }

  Future<void> _captureAndPrintMap() async {
    setState(() => _isCapturing = true);

    try {
      await _pdfService.captureAndPrintMap(_mapKey);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Karte erfolgreich exportiert'),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                Text('Export-Fehler: ${e.toString()}'),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCapturing = false);
      }
    }
  }

  double _getMarkerSizeForZoom(double zoom) {
    const baseSize = 40.0;
    const baseZoom = 14.0;
    final scaleFactor = (zoom / baseZoom).clamp(0.5, 1.5);
    return baseSize * scaleFactor;
  }

  Widget _buildSearchBar() {
    return AnimatedOpacity(
      opacity: _showControls ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 300),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          elevation: 0,
          borderRadius: BorderRadius.circular(16),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Ort suchen...',
              hintStyle: TextStyle(color: Colors.grey[600]),
              prefixIcon: Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.search,
                  color: Theme.of(context).primaryColor,
                ),
              ),
              suffixIcon:
                  _isSearching
                      ? Container(
                        padding: const EdgeInsets.all(12),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Theme.of(context).primaryColor,
                            ),
                          ),
                        ),
                      )
                      : _searchController.text.isNotEmpty
                      ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchResults.clear());
                        },
                      )
                      : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                vertical: 16,
                horizontal: 8,
              ),
            ),
            onSubmitted: _searchLocation,
            onChanged: (value) {
              if (value.isEmpty) {
                setState(() => _searchResults.clear());
              }
            },
          ),
        ),
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_searchResults.isEmpty) return const SizedBox.shrink();

    return Positioned(
      top: MediaQuery.of(context).padding.top + 80,
      left: 16,
      right: 16,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.4,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          elevation: 0,
          borderRadius: BorderRadius.circular(16),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const ClampingScrollPhysics(),
            itemCount: _searchResults.length,
            separatorBuilder:
                (context, index) => Divider(height: 1, color: Colors.grey[300]),
            itemBuilder: (context, index) {
              final result = _searchResults[index];
              return ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.place,
                    color: Theme.of(context).primaryColor,
                    size: 20,
                  ),
                ),
                title: Text(
                  result.displayName,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
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
    );
  }

  Widget _buildHydrantControl() {
    return AnimatedOpacity(
      opacity: _showControls ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 300),
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: IntrinsicWidth(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color:
                      _showHydrants
                          ? Theme.of(context).primaryColor.withOpacity(0.1)
                          : Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.water_drop,
                  color:
                      _showHydrants
                          ? Theme.of(context).primaryColor
                          : Colors.grey[600],
                  size: 20,
                ),
              ),
              const SizedBox(width: 8),
              const Flexible(
                child: Text(
                  'Hydranten',
                  style: TextStyle(fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Switch(
                value: _showHydrants,
                onChanged: (value) {
                  setState(() {
                    _showHydrants = value;
                    _hydrantMarkers.clear();
                    _lastLoadedBounds = null;
                    _lastLoadedZoom = 0.0;
                  });

                  if (value && _isInitialized && _isMapReady) {
                    Future.delayed(const Duration(milliseconds: 100), () {
                      _handleMapMovement();
                    });
                  }
                },
                activeColor: Theme.of(context).primaryColor,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTacticalFAB() {
    return AnimatedOpacity(
      opacity: _showControls ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 300),
      child: FloatingActionButton(
        heroTag: 'tactical_symbols',
        onPressed: _showTacticalSymbolSelector,
        backgroundColor: Theme.of(context).primaryColor,
        child: const Icon(Icons.add_location_alt, color: Colors.white),
      ),
    );
  }

  Widget _buildDownloadProgress() {
    return Container(
      color: Colors.black.withOpacity(0.7),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                value: _downloadProgress,
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(
                  Theme.of(context).primaryColor,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Lade Offline-Daten...',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[800],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${(_downloadProgress * 100).toInt()}%',
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
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

    // KORRIGIERT: Sichere Zoom-Berechnung
    double currentZoom = 14.0; // Fallback
    if (_isMapReady) {
      try {
        currentZoom = _mapController.camera.zoom;
      } catch (e) {
        // Fallback verwenden
      }
    }
    final markerSize = _getMarkerSizeForZoom(currentZoom);

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
                onMapReady: () {
                  // HINZUGEFÜGT: Callback für Map-Bereitschaft
                  setState(() => _isMapReady = true);
                },
                onPositionChanged: (position, hasGesture) {
                  if (hasGesture && mounted && _isMapReady) {
                    setState(() {});
                  }
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  tileProvider:
                      (_offlineManager.isOfflineMode &&
                              _offlineManager.mapStore != null)
                          ? _offlineManager.mapStore!.getTileProvider()
                          : null,
                ),
                if (_showHydrants) MarkerLayer(markers: _hydrantMarkers),
                if (_tacticalManager.markers.isNotEmpty)
                  MarkerClusterLayerWidget(
                    options: MarkerClusterLayerOptions(
                      maxClusterRadius: 60,
                      size: const Size(40, 40),
                      markers: _tacticalManager.markers,
                      builder:
                          (context, markers) =>
                              markers.length == 1
                                  ? markers.first.child
                                  : Container(
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).primaryColor,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.2),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Center(
                                      child: Text(
                                        '${markers.length}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                    ),
                  ),
                if (_draggableMarkers.isNotEmpty)
                  MarkerLayer(
                    markers:
                        _draggableMarkers.map((markerData) {
                          return Marker(
                            point: markerData.position,
                            width: markerSize,
                            height: markerSize,
                            child: LongPressDraggable<DraggableMarkerData>(
                              data: markerData,
                              feedback: Material(
                                color: Colors.transparent,
                                child: Container(
                                  width: markerSize * 1.3,
                                  height: markerSize * 1.3,
                                  decoration: BoxDecoration(
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.4),
                                        blurRadius: 12,
                                        offset: const Offset(0, 6),
                                      ),
                                    ],
                                  ),
                                  child: SvgPicture.asset(
                                    markerData.symbol.assetPath,
                                    width: markerSize * 1.3,
                                    height: markerSize * 1.3,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ),
                              childWhenDragging: Opacity(
                                opacity: 0.3,
                                child: SvgPicture.asset(
                                  markerData.symbol.assetPath,
                                  width: markerSize,
                                  height: markerSize,
                                  fit: BoxFit.contain,
                                ),
                              ),
                              delay: const Duration(milliseconds: 100),
                              child: GestureDetector(
                                onTap:
                                    () => _showSymbolInfo(
                                      markerData.symbol,
                                      markerData.id,
                                    ),
                                child: SvgPicture.asset(
                                  markerData.symbol.assetPath,
                                  width: markerSize,
                                  height: markerSize,
                                  fit: BoxFit.contain,
                                  placeholderBuilder:
                                      (context) => Icon(
                                        Icons.place,
                                        color: Theme.of(context).primaryColor,
                                        size: markerSize,
                                      ),
                                  errorBuilder: (context, error, stackTrace) {
                                    print('SVG Fehler: $error');
                                    return Icon(
                                      Icons.place,
                                      color: Colors.red,
                                      size: markerSize,
                                    );
                                  },
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                  ),
              ],
            ),
          ),
          Positioned.fill(
            child: DragTarget<DraggableMarkerData>(
              onWillAccept: (data) => data != null,
              onAcceptWithDetails: (details) {
                final markerData = details.data;

                final RenderBox? renderBox =
                    context.findRenderObject() as RenderBox?;
                if (renderBox == null || !_isMapReady) return;

                try {
                  final localPosition = renderBox.globalToLocal(details.offset);
                  final mapSize = renderBox.size;
                  final bounds = _mapController.camera.visibleBounds;

                  final relativeX = localPosition.dx / mapSize.width;
                  final relativeY = localPosition.dy / mapSize.height;

                  final newLng =
                      bounds.west + (bounds.east - bounds.west) * relativeX;
                  final newLat =
                      bounds.north - (bounds.north - bounds.south) * relativeY;

                  final newPosition = LatLng(newLat, newLng);

                  _moveMarker(markerData.id, newPosition);
                  HapticFeedback.lightImpact();
                } catch (e) {
                  debugPrint('Error moving marker: $e');
                }
              },
              builder: (context, candidateData, rejectedData) {
                return Container(
                  decoration:
                      candidateData.isNotEmpty
                          ? BoxDecoration(
                            color: Theme.of(
                              context,
                            ).primaryColor.withOpacity(0.1),
                            border: Border.all(
                              color: Theme.of(
                                context,
                              ).primaryColor.withOpacity(0.3),
                              width: 2,
                              style: BorderStyle.solid,
                            ),
                          )
                          : null,
                );
              },
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 0,
            right: 70,
            child: _buildSearchBar(),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            right: 16,
            child: AnimatedOpacity(
              opacity: _showControls ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 300),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _isCapturing ? null : _captureAndPrintMap,
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      child:
                          _isCapturing
                              ? SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Theme.of(context).primaryColor,
                                  ),
                                ),
                              )
                              : Icon(
                                Icons.picture_as_pdf,
                                color: Theme.of(context).primaryColor,
                              ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          _buildSearchResults(),
          Positioned(left: 0, bottom: 0, child: _buildHydrantControl()),
          if (_isDownloading) _buildDownloadProgress(),
        ],
      ),
      floatingActionButton: isMaster ? _buildTacticalFAB() : null,
    );
  }
}

// DraggableMarkerData Klasse am Ende der Datei
class DraggableMarkerData {
  final String id;
  final loader.TacticalSymbol symbol;
  LatLng position;

  DraggableMarkerData({
    required this.id,
    required this.symbol,
    required this.position,
  });
}
