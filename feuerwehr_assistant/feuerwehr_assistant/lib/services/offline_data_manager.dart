import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'hydrant_data.dart'; // Import der gemeinsamen HydrantData Klasse

class OfflineDataManager {
  String? _offlineDataPath;
  FMTCStore? _mapStore;
  DateTime? _lastMapUpdate;
  List<HydrantData> _offlineHydrants = [];
  
  bool get isOfflineMode => _offlineDataPath != null && _mapStore != null;
  List<HydrantData> get offlineHydrants => _offlineHydrants;
  DateTime? get lastMapUpdate => _lastMapUpdate;
  FMTCStore? get mapStore => _mapStore;

  bool hasOfflineData() {
  return isOfflineMode && _offlineHydrants.isNotEmpty && _lastMapUpdate != null;
}

  Future<void> initialize() async {
    try {
      await FMTCObjectBoxBackend().initialise();
      _mapStore = FMTCStore('mapCache');
      
      final appDir = await getApplicationDocumentsDirectory();
      _offlineDataPath = '${appDir.path}/map_data';
      
      final mapDataDir = Directory(_offlineDataPath!);
      final hydrantFile = File('${_offlineDataPath!}/hydrants.json');
      final metaFile = File('${_offlineDataPath!}/meta.json');
      
      if (await mapDataDir.exists() && await hydrantFile.exists() && await metaFile.exists()) {
        await _loadOfflineData();
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
        final List<dynamic> hydrantList = jsonDecode(hydrantData);
        _offlineHydrants = hydrantList.map((json) => HydrantData.fromJson(json)).toList();
      }
      
      if (await metaFile.exists()) {
        final metaData = await metaFile.readAsString();
        final meta = jsonDecode(metaData);
        _lastMapUpdate = DateTime.parse(meta['lastUpdate']);
      }
      
      if (_mapStore != null && !await _mapStore!.manage.ready) {
        await _mapStore!.manage.create();
      }
      
      debugPrint('Offline data loaded successfully');
    } catch (e) {
      debugPrint('Error loading offline data: $e');
    }
  }

  bool shouldUpdate() {
    if (_lastMapUpdate == null) return true;
    return DateTime.now().difference(_lastMapUpdate!).inDays > 30;
  }

  Future<void> downloadOfflineData({
    required Function(double) onProgress,
    required Function(String) onError,
  }) async {
    try {
      final mapDataDir = Directory(_offlineDataPath!);
      if (!await mapDataDir.exists()) {
        await mapDataDir.create(recursive: true);
      }
      
      onProgress(0.1);
      await _downloadHydrantData();
      
      onProgress(0.3);
      await _downloadMapTiles(onProgress);
      
      onProgress(0.9);
      await _saveMetadata();
      
      onProgress(1.0);
      await _loadOfflineData();
      
    } catch (e) {
      onError(e.toString());
    }
  }

  Future<void> _downloadHydrantData() async {
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
      
      final hydrants = elements.where((element) => element['type'] == 'node').map((node) => 
        HydrantData.fromJson({
          'lat': node['lat'],
          'lon': node['lon'],
          'tags': node['tags'] ?? {},
        })
      ).toList();
      
      final hydrantFile = File('${_offlineDataPath!}/hydrants.json');
      await hydrantFile.writeAsString(jsonEncode(hydrants.map((h) => h.toJson()).toList()));
      
      debugPrint('Downloaded ${hydrants.length} hydrants for Germany');
    }
  }

  Future<void> _downloadMapTiles(Function(double) onProgress) async {
    if (_mapStore == null) return;
    
    try {
      if (!await _mapStore!.manage.ready) {
        await _mapStore!.manage.create();
      }
      
      final region = RectangleRegion(
        LatLngBounds(
          const LatLng(55.1, 5.8),
          const LatLng(47.2, 15.1),
        ),
      );
      
      final downloadable = region.toDownloadable(
        minZoom: 6,
        maxZoom: 14,
        options: TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.firefighter_app',
        ),
      );

      final download = _mapStore!.download.startForeground(region: downloadable);

      await for (final progress in download.downloadProgress) {
        onProgress(0.3 + (progress.percentageProgress / 100) * 0.4);
        if (progress.percentageProgress >= 100) break;
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
}