class Einsatz {
  final String id;
  final DateTime beginn;
  final DateTime? ende;
  final GeoPoint position;
  final List<Fahrzeug> fahrzeuge;
  final String leiter;

  bool get isAktiv => ende == null;

  Map<String, dynamic> toJson() => {
    'id': id,
    'beginn': beginn.toIso8601String(),
    'ende': ende?.toIso8601String(),
    'position': position.toGeoJson(),
    'fahrzeuge': fahrzeuge.map((f) => f.toJson()).toList(),
    'leiter': leiter
  };
}