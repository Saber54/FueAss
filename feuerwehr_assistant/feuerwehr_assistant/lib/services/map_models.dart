// services/map_models.dart
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
      lat: json['lat']?.toDouble() ?? 0.0,
      lon: json['lon']?.toDouble() ?? 0.0,
      tags: json['tags'] ?? {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'lat': lat,
      'lon': lon,
      'tags': tags,
    };
  }

  @override
  String toString() {
    return 'HydrantData(lat: $lat, lon: $lon, tags: $tags)';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HydrantData &&
          runtimeType == other.runtimeType &&
          lat == other.lat &&
          lon == other.lon &&
          _mapsEqual(tags, other.tags);

  @override
  int get hashCode => lat.hashCode ^ lon.hashCode ^ tags.hashCode;

  bool _mapsEqual(Map<String, dynamic> map1, Map<String, dynamic> map2) {
    if (map1.length != map2.length) return false;
    for (var key in map1.keys) {
      if (!map2.containsKey(key) || map1[key] != map2[key]) {
        return false;
      }
    }
    return true;
  }
}

class TacticalMarker {
  final double lat;
  final double lon;
  final String type;
  final String? label;
  final DateTime timestamp;

  TacticalMarker({
    required this.lat,
    required this.lon,
    required this.type,
    this.label,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  factory TacticalMarker.fromJson(Map<String, dynamic> json) {
    return TacticalMarker(
      lat: json['lat']?.toDouble() ?? 0.0,
      lon: json['lon']?.toDouble() ?? 0.0,
      type: json['type'] ?? '',
      label: json['label'],
      timestamp: json['timestamp'] != null 
          ? DateTime.parse(json['timestamp']) 
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'lat': lat,
      'lon': lon,
      'type': type,
      if (label != null) 'label': label,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  @override
  String toString() {
    return 'TacticalMarker(lat: $lat, lon: $lon, type: $type, label: $label, timestamp: $timestamp)';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TacticalMarker &&
          runtimeType == other.runtimeType &&
          lat == other.lat &&
          lon == other.lon &&
          type == other.type &&
          label == other.label &&
          timestamp == other.timestamp;

  @override
  int get hashCode =>
      lat.hashCode ^
      lon.hashCode ^
      type.hashCode ^
      label.hashCode ^
      timestamp.hashCode;
}