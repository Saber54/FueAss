// screens/map_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster_plus/flutter_map_marker_cluster_plus.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../providers/auth_provider.dart';
import '../services/offline_data_manager.dart' as offline;
import '../services/search_service.dart' as search;
import '../services/hydrant_service.dart' as hydrant;
import '../services/pdf_export_service.dart';
import '../services/tactical_marker_manager.dart';
import '../services/search_result.dart';
import '../services/tactical_symbol_service.dart';
import '../services/tactical_symbols_loader.dart'
    as loader; // GEÄNDERT: Prefix hinzugefügt
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
      loader.TacticalSymbolsLoader(); // GEÄNDERT: Prefix verwendet

  final List<Marker> _hydrantMarkers = [];
  LatLng? _lastTapPosition;
  bool _showHydrants = false;
  bool _isSearching = false;
  bool _isCapturing = false;
  bool _isDownloading = false;
  bool _isInitialized = false;
  bool _showControls = true;
  bool _showTacticalMenu = false;
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

    _mapController.mapEventStream.listen((event) {
      if (_showHydrants && _isInitialized) {
        _handleMapMovement();
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeServices();
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
      // Initialisiere Tactical Symbol Service
      await _tacticalSymbolService.initialize();

      // Initialisiere Offline Data Manager
      await _offlineManager.initialize();
      final shouldPromptDownload = !_offlineManager.hasOfflineData();
      if (_offlineManager.isOfflineMode && _offlineManager.shouldUpdate()) {
        await _promptForUpdate();
      } else if (shouldPromptDownload) {
        await _promptForOfflineDownload();
      }
      setState(() => _isInitialized = true);

      // Lade Hydranten nach Initialisierung, falls bereits aktiviert
      if (_showHydrants) {
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
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                const Text('Offline-Daten erfolgreich geladen'),
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
    final zoom = _mapController.camera.zoom;
    final bounds = _mapController.camera.visibleBounds;

    debugPrint(
      'Map moved - Zoom: $zoom, ShowHydrants: $_showHydrants, Initialized: $_isInitialized',
    );
    debugPrint('Current bounds: $bounds');

    if (zoom < _minZoomForHydrants) {
      if (_hydrantMarkers.isNotEmpty) {
        debugPrint(
          'Clearing hydrants - zoom too low ($zoom < $_minZoomForHydrants)',
        );
        setState(() => _hydrantMarkers.clear());
      }
      return;
    }

    final shouldReload =
        _lastLoadedBounds == null ||
        _lastLoadedZoom != zoom ||
        !_lastLoadedBounds!.containsBounds(bounds);

    if (shouldReload) {
      debugPrint('Reloading hydrants for bounds: $bounds');
      final expanded = _expandBounds(bounds, _boundsExpandFactor);
      _loadHydrants(expanded);
      _lastLoadedBounds = expanded;
      _lastLoadedZoom = zoom;
    } else {
      debugPrint('No reload needed - bounds/zoom unchanged');
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
    if (!_showHydrants || !_isInitialized) {
      debugPrint(
        'Not loading hydrants - ShowHydrants: $_showHydrants, Initialized: $_isInitialized',
      );
      return;
    }

    try {
      debugPrint('Loading hydrants for bounds: $bounds');
      debugPrint('Offline mode: ${_offlineManager.isOfflineMode}');
      debugPrint('Has offline data: ${_offlineManager.hasOfflineData()}');

      List<Marker> markers;

      // Prüfe ob Offline-Daten verfügbar sind UND ob diese auch Hydrantendaten enthalten
      if (_offlineManager.isOfflineMode && _offlineManager.hasOfflineData()) {
        markers = _hydrantService.loadOfflineHydrants(
          _offlineManager.offlineHydrants,
          bounds,
        );
        debugPrint('Loaded ${markers.length} offline hydrant markers');
      } else {
        // Verwende Online-Daten wenn keine Offline-Daten verfügbar sind
        markers = await _hydrantService.loadOnlineHydrants(bounds);
        debugPrint('Loaded ${markers.length} online hydrant markers');
      }

      if (mounted) {
        setState(() {
          _hydrantMarkers.clear();
          _hydrantMarkers.addAll(markers);
        });
        debugPrint('Updated UI with ${_hydrantMarkers.length} hydrant markers');
      }
    } catch (e) {
      debugPrint('Hydrant load error: $e');
      debugPrint('Stack trace: ${StackTrace.current}');

      // Fallback: Versuche Online-Daten zu laden wenn Offline-Laden fehlschlägt
      if (_offlineManager.isOfflineMode) {
        debugPrint('Attempting fallback to online data...');
        try {
          final markers = await _hydrantService.loadOnlineHydrants(bounds);
          if (mounted) {
            setState(() {
              _hydrantMarkers.clear();
              _hydrantMarkers.addAll(markers);
            });
            debugPrint(
              'Fallback successful: ${_hydrantMarkers.length} online hydrant markers',
            );
          }
        } catch (fallbackError) {
          debugPrint('Fallback also failed: $fallbackError');
        }
      }
    }
  }

  void _handleMapTap(TapPosition _, LatLng pos) {
    setState(() => _lastTapPosition = pos);
    // Verstecke Controls nach Tap für bessere Sicht
    if (_showControls) {
      setState(() => _showControls = false);
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) setState(() => _showControls = true);
      });
    }
    // Schließe taktisches Menü bei Kartentap
    if (_showTacticalMenu) {
      setState(() => _showTacticalMenu = false);
    }
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
          maxHeight:
              MediaQuery.of(context).size.height *
              0.4, // FIXED: Max 40% der Bildschirmhöhe
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
            physics:
                const ClampingScrollPhysics(), // FIXED: Bessere Scroll-Physik
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
                  maxLines: 2, // FIXED: Begrenze Textzeilen
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
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 8,
        ), // FIXED: Weniger Padding
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
          // FIXED: Nur so breit wie nötig
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
              const SizedBox(width: 8), // FIXED: Weniger Abstand
              Flexible(
                // FIXED: Flexible Text
                child: Text(
                  'Hydranten',
                  style: const TextStyle(fontWeight: FontWeight.w500),
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

                  if (value && _isInitialized) {
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

  // Neue Methode für Symbolauswahl:
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

  // GEÄNDERT: Parametertypänderung
  void _addTacticalSymbol(loader.TacticalSymbol symbol) {
    // GEÄNDERT: loader.TacticalSymbol verwendet
    LatLng targetPosition;

    // Wenn keine Position durch Tippen ausgewählt wurde, verwende Kartenmitte
    if (_lastTapPosition == null) {
      targetPosition = _mapController.camera.center;

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

    // Erstelle Marker mit SVG-Symbol - GRÖSSERES SYMBOL OHNE WEISSEN KREIS
    final marker = Marker(
      point: targetPosition,
      width: 60, // VERGRÖSSERT von 40 auf 60
      height: 60, // VERGRÖSSERT von 40 auf 60
      child: GestureDetector(
        onTap: () => _showSymbolInfo(symbol),
        child: Container(
          // ENTFERNT: Weißer Hintergrund und Schatten
          child: SvgPicture.asset(
            symbol.assetPath,
            width: 60, // VERGRÖSSERT von 32 auf 60
            height: 60, // VERGRÖSSERT von 32 auf 60
            fit: BoxFit.contain,
            placeholderBuilder:
                (context) => Icon(
                  Icons.place,
                  color: Theme.of(context).primaryColor,
                  size: 60, // VERGRÖSSERT von 32 auf 60
                ),
          ),
        ),
      ),
    );

    // Füge Marker zum TacticalMarkerManager hinzu
    _tacticalManager.addCustomMarker(marker);

    setState(() {});

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Text('${symbol.name} hinzugefügt'),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // GEÄNDERT: Parametertypänderung
  void _showSymbolInfo(loader.TacticalSymbol symbol) {
    // GEÄNDERT: loader.TacticalSymbol verwendet
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
                ),
                const SizedBox(height: 16),
                Text(
                  'Kategorie: ${_tacticalSymbolsLoader.getCategoryDisplayName(symbol.category)}',
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Schließen'),
              ),
            ],
          ),
    );
  }

  Future<void> _searchLocation(String query) async {
    if (query.isEmpty) return;
    setState(() => _isSearching = true);
    _searchAnimationController.forward();
    final results = await _searchService.searchLocation(query);
    setState(() {
      _searchResults = results;
      _isSearching = false;
    });
    _searchAnimationController.reverse();
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

  Widget _buildDownloadProgress() {
    if (!_isDownloading) return const SizedBox.shrink();

    return Container(
      color: Colors.black.withOpacity(0.5),
      child: SafeArea(
        // FIXED: SafeArea hinzugefügt
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(24),
            margin: const EdgeInsets.all(32),
            constraints: BoxConstraints(
              maxHeight:
                  MediaQuery.of(context).size.height * 0.3, // FIXED: Max Höhe
              maxWidth:
                  MediaQuery.of(context).size.width * 0.8, // FIXED: Max Breite
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_download, size: 48, color: Colors.blue),
                const SizedBox(height: 16),
                Text(
                  'Kartendaten werden heruntergeladen...',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2, // FIXED: Begrenze Textzeilen
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 16),
                LinearProgressIndicator(
                  value: _downloadProgress,
                  backgroundColor: Colors.grey[300],
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
                ),
                const SizedBox(height: 8),
                Text(
                  '${(_downloadProgress * 100).toInt()}%',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ],
            ),
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
                  tileProvider:
                      (_offlineManager.isOfflineMode &&
                              _offlineManager.mapStore != null)
                          ? _offlineManager.mapStore!.getTileProvider()
                          : null,
                ),
                // Hydrantenmarker - wichtig: diese müssen immer als eigenes MarkerLayer dargestellt werden
                if (_showHydrants) MarkerLayer(markers: _hydrantMarkers),
                // Taktische Marker als Cluster
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
              ],
            ),
          ),

          // Search Bar
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 0,
            right: 70,
            child: _buildSearchBar(),
          ),

          // PDF Export Button
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

          // Search Results
          _buildSearchResults(),

          // Hydrant Control
          Positioned(left: 0, bottom: 0, child: _buildHydrantControl()),

          // Download Progress
          if (_isDownloading) _buildDownloadProgress(),
        ],
      ),
      floatingActionButton: isMaster ? _buildTacticalFAB() : null,
    );
  }
}
