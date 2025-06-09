import 'package:flutter/foundation.dart';
import '../models/hazmat.dart';

class HazmatProvider extends ChangeNotifier {
  List<Hazmat> _hazmats = [];
  bool _isLoading = false;
  String? _searchQuery;

  // Getter
  List<Hazmat> get hazmats => _searchQuery != null
      ? _hazmats.where((h) => 
          h.name.toLowerCase().contains(_searchQuery!.toLowerCase()) || 
          h.unNumber.contains(_searchQuery!))
        .toList()
      : _hazmats;

  bool get isLoading => _isLoading;

  // Gefahrgut-Daten laden
  Future<void> loadHazmats() async {
    _isLoading = true;
    notifyListeners();

    try {
      // Mock: Simuliere Netzwerklatenz
      await Future.delayed(const Duration(seconds: 1));
      
      // Initial mit Beispieldaten füllen
      _hazmats = Hazmat.samples;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Suche durchführen
  void search(String query) {
    _searchQuery = query.isNotEmpty ? query : null;
    notifyListeners();
  }

  // Neuen Eintrag hinzufügen
  Future<void> addHazmat(Hazmat hazmat) async {
    _hazmats = [..._hazmats, hazmat];
    notifyListeners();
  }

  // Eintrag aktualisieren
  Future<void> updateHazmat(Hazmat updatedHazmat) async {
    _hazmats = _hazmats.map((h) => 
      h.id == updatedHazmat.id ? updatedHazmat : h
    ).toList();
    notifyListeners();
  }

  // Eintrag löschen (nur für Master)
  Future<void> deleteHazmat(String id) async {
    _hazmats.removeWhere((h) => h.id == id);
    notifyListeners();
  }
}