import 'package:postgres/postgres.dart';
import '../../models/geo_point.dart';
import '../../models/fahrzeug.dart';

class FahrzeugRepository {
  final PostgreSQLConnection _db;

  FahrzeugRepository(this._db);

  Future<List<Fahrzeug>> getInRadius(GeoPoint center, double radiusKm) async {
    const query = '''
      SELECT id, funkrufname, typ, ST_X(position::geometry) as lon, 
             ST_Y(position::geometry) as lat, letzte_aktualisierung
      FROM fahrzeuge
      WHERE ST_DWithin(
        position, 
        ST_SetSRID(ST_MakePoint(@lon, @lat), 4326),
        @radius * 1000
      )
      ORDER BY letzte_aktualisierung DESC
    ''';

    final results = await _db.query(
      query,
      substitutionValues: {
        'lon': center.longitude,
        'lat': center.latitude,
        'radius': radiusKm,
      },
    );

    return results.map((row) => Fahrzeug(
      id: row[0] as String,
      funkrufname: row[1] as String,
      typ: row[2] as String,
      position: GeoPoint(
        latitude: row[4] as double,
        longitude: row[3] as double,
      ),
      lastUpdate: row[5] as DateTime,
    )).toList();
  }

  Future<void> updatePosition(String fahrzeugId, GeoPoint position) async {
    await _db.execute('''
      UPDATE fahrzeuge
      SET position = ST_SetSRID(ST_MakePoint(@lon, @lat), 4326),
          letzte_aktualisierung = NOW()
      WHERE id = @id
    ''', substitutionValues: {
      'lon': position.longitude,
      'lat': position.latitude,
      'id': fahrzeugId,
    });
  }
}