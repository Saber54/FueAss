class HydrantData {
  final double lat;
  final double lon;
  final Map<String, dynamic> tags;

  HydrantData({
    required this.lat,
    required this.lon,
    required this.tags,
  });

  factory HydrantData.fromJson(Map<String, dynamic> json) {
    return HydrantData(
      lat: (json['lat'] as num).toDouble(),
      lon: (json['lon'] as num).toDouble(),
      tags: Map<String, dynamic>.from(json['tags'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'lat': lat,
      'lon': lon,
      'tags': tags,
    };
  }

  // Helper getters für häufige Hydrant-Eigenschaften
  String get hydrantType => tags['fire_hydrant:type'] ?? 'unknown';
  String get operator => tags['operator'] ?? 'unknown';
  String get waterSource => tags['water_source'] ?? 'unknown';
  String get pressure => tags['fire_hydrant:pressure'] ?? 'unknown';
  String get diameter => tags['fire_hydrant:diameter'] ?? 'unknown';
  
  @override
  String toString() {
    return 'HydrantData(lat: $lat, lon: $lon, type: $hydrantType)';
  }
}