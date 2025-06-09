#!/usr/bin/env dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:logging/logging.dart';

void main(List<String> args) async {
  // Logger konfigurieren
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    print('${record.level.name}: ${record.time}: ${record.message}');
  });

  // Datenbank öffnen
  final db = sqlite3.open('feuerwehr.db');

  // Tabellen erstellen
  db.execute('''
    CREATE TABLE IF NOT EXISTS users (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      username TEXT UNIQUE NOT NULL,
      password TEXT NOT NULL,
      is_admin BOOLEAN DEFAULT FALSE
    )
  ''');

  db.execute('''
    CREATE TABLE IF NOT EXISTS einsaetze (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      ort TEXT NOT NULL,
      beginn TEXT NOT NULL,
      ende TEXT,
      leiter TEXT NOT NULL
    )
  ''');

  // Testdaten einfügen
  db.execute('''
    INSERT OR IGNORE INTO users (username, password, is_admin)
    VALUES ('admin', 'geheim', TRUE)
  ''');

  // Router erstellen
  final router = Router();

  // Helper-Funktion für SQLite-ResultSet zu List<Map>
  List<Map<String, dynamic>> _resultToMapList(ResultSet result) {
    return [
      for (final row in result.rows)
        {
          for (var i = 0; i < result.columnNames.length; i++)
            result.columnNames[i]: row[i]
        }
    ];
  }

  // Login-Endpoint
  router.post('/login', (Request req) async {
    try {
      final body = await req.readAsString();
      final data = jsonDecode(body);
      
      final result = db.select('''
        SELECT * FROM users 
        WHERE username = ? AND password = ?
      ''', [data['username'], data['password']]);

      final users = _resultToMapList(result);
      
      if (users.isNotEmpty) {
        return Response.ok(
          jsonEncode({
            'token': 'dummy_token',
            'is_admin': users.first['is_admin'] == 1
          }),
          headers: {'Content-Type': 'application/json'},
        );
      } else {
        return Response.forbidden(
          jsonEncode({'error': 'Ungültige Anmeldedaten'}),
          headers: {'Content-Type': 'application/json'},
        );
      }
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'error': 'Serverfehler: $e'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  });

  // Export-Endpoint
  router.get('/export', (Request req) async {
    try {
      final format = req.url.queryParameters['format'] ?? 'json';
      final result = db.select('SELECT * FROM einsaetze');
      final einsaetze = _resultToMapList(result);
      
      return Response.ok(
        jsonEncode({
          'format': format,
          'data': einsaetze
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'error': 'Export fehlgeschlagen: $e'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  });

  // Server starten
  final server = await serve(
    Pipeline()
      .addMiddleware(logRequests())
      .addHandler(router),
    InternetAddress.anyIPv4,
    8080,
  );
  
  print('Server läuft auf http://${server.address.host}:${server.port}');
}