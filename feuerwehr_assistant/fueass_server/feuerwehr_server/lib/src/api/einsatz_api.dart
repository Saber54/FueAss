import 'package:shelf_router/shelf_router.dart';
import 'package:shelf/shelf.dart';
import '../../models/einsatz.dart';
import '../../database/repositories/einsatz_repository.dart';

class EinsatzApi {
  final EinsatzRepository _repository;

  EinsatzApi(this._repository);

  Router get router {
    final router = Router();

    router.get('/aktive', _getActiveEinsaetze);
    router.post('/neu', _createEinsatz);
    router.put('/<einsatzId>/fahrzeug', _addFahrzeugToEinsatz);
    router.get('/<einsatzId>/protokoll', _getProtokoll);

    return router;
  }

  Future<Response> _getActiveEinsaetze(Request request) async {
    final einsaetze = await _repository.getActive();
    return Response.ok(
      jsonEncode(einsaetze.map((e) => e.toJson()).toList()),
      headers: {'Content-Type': 'application/json'},
    );
  }

  Future<Response> _createEinsatz(Request request) async {
    final body = await request.readAsString();
    final data = jsonDecode(body) as Map<String, dynamic>;
    
    final einsatz = await _repository.create(
      leiter: data['leiter'] as String,
      position: GeoPoint.fromJson(data['position'] as Map<String, dynamic>),
      beschreibung: data['beschreibung'] as String,
    );

    return Response.created(
      '/einsaetze/${einsatz.id}',
      jsonEncode(einsatz.toJson()),
    );
  }
}