import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class DatabaseManager {
  static Database? _db;

  Future<Database> get db async {
    if (_db != null) return _db!;
    sqfliteFfiInit();
    _db = await databaseFactoryFfi.openDatabase(
      'feuerwehr.db',
      options: OpenDatabaseOptions(
        onCreate: _onCreate,
        version: 1,
      ),
    );
    return _db!;
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE fahrzeuge (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        funkrufname TEXT UNIQUE NOT NULL,
        typ TEXT NOT NULL,
        lon REAL NOT NULL,
        lat REAL NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE einsaetze (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        beginn TEXT NOT NULL,
        ende TEXT,
        leiter TEXT NOT NULL
      )
    ''');
  }
}