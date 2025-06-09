import 'geo_point.dart';

class Fahrzeug {
  final String id;
  final String funkrufname;
  final String typ;
  final GeoPoint position;
  final DateTime lastUpdate;
  final List<String> besonderheiten;
  final String? einsatzId;

  Fahrzeug({
    required this.id,
    required this.funkrufname,
    required this.typ,
    required this.position,
    required this.lastUpdate,
    this.besonderheiten = const [],
    this.einsatzId,
  });

  factory Fahrzeug.fromJson(Map<String, dynamic> json) {
    return Fahrzeug(
      id: json['id'] as String,
      funkrufname: json['funkrufname'] as String,
      typ: json['typ'] as String,
      position: GeoPoint.fromJson(json['position'] as Map<String, dynamic>),
      lastUpdate: DateTime.parse(json['lastUpdate'] as String),
      besonderheiten: List<String>.from(json['besonderheiten'] ?? []),
      einsatzId: json['einsatzId'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'funkrufname': funkrufname,
      'typ': typ,
      'position': position.toGeoJson(),
      'lastUpdate': lastUpdate.toIso8601String(),
      'besonderheiten': besonderheiten,
      if (einsatzId != null) 'einsatzId': einsatzId,
    };
  }

  bool get istEinsatzbereit => einsatzId == null;

  String get displayName => '$funkrufname ($typ)';
}