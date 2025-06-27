// models/search_result.dart
class SearchResult {
  final String displayName;
  final double latitude;
  final double longitude;
  final String type;
  final String? icon;
  final String? county;
  final String? postcode; // NEU

  SearchResult({
    required this.displayName,
    required this.latitude,
    required this.longitude,
    required this.type,
    this.icon,
    this.county,
    this.postcode, // NEU
  });

  // Factory constructor for Nominatim API response
  factory SearchResult.fromNominatimJson(Map<String, dynamic> json) {
    return SearchResult(
      displayName: json['display_name'] ?? '',
      latitude: double.tryParse(json['lat']?.toString() ?? '') ?? 0.0,
      longitude: double.tryParse(json['lon']?.toString() ?? '') ?? 0.0,
      type: json['type'] ?? '',
      icon: json['icon'],
      county: json['address']?['county'],
      postcode: json['address']?['postcode'], // NEU
    );
  }

  // Factory constructor for generic JSON (backward compatibility)
  factory SearchResult.fromJson(Map<String, dynamic> json) {
    return SearchResult(
      displayName: json['display_name'] ?? json['displayName'] ?? '',
      latitude:
          json['lat'] != null
              ? double.tryParse(json['lat'].toString()) ?? 0.0
              : json['latitude']?.toDouble() ?? 0.0,
      longitude:
          json['lon'] != null
              ? double.tryParse(json['lon'].toString()) ?? 0.0
              : json['longitude']?.toDouble() ?? 0.0,
      type: json['type'] ?? '',
      icon: json['icon'],
      county: json['county'] ?? json['address']?['county'],
      postcode: json['postcode'] ?? json['address']?['postcode'], // NEU
    );
  }

  // Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'display_name': displayName,
      'latitude': latitude,
      'longitude': longitude,
      'type': type,
      if (icon != null) 'icon': icon,
      if (county != null) 'county': county,
      if (postcode != null) 'postcode': postcode, // NEU
    };
  }

  @override
  String toString() {
    return 'SearchResult(displayName: $displayName, lat: $latitude, lon: $longitude, type: $type)';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SearchResult &&
          runtimeType == other.runtimeType &&
          displayName == other.displayName &&
          latitude == other.latitude &&
          longitude == other.longitude &&
          type == other.type &&
          icon == other.icon;

  @override
  int get hashCode =>
      displayName.hashCode ^
      latitude.hashCode ^
      longitude.hashCode ^
      type.hashCode ^
      icon.hashCode;
}
