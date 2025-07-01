// lib/services/tactical_symbols_loader.dart
import 'dart:convert';
import 'package:flutter/services.dart';

class TacticalSymbol {
  final String name;
  final String assetPath;
  final String category;

  TacticalSymbol({
    required this.name,
    required this.assetPath,
    required this.category,
  });
}

class TacticalSymbolsLoader {
  static final TacticalSymbolsLoader _instance =
      TacticalSymbolsLoader._internal();
  factory TacticalSymbolsLoader() => _instance;
  TacticalSymbolsLoader._internal();

  final Map<String, List<TacticalSymbol>> _categorizedSymbols = {};
  bool _isLoaded = false;

  // Verfügbare Kategorien basierend auf Ordnerstruktur
  static const Map<String, String> categoryDisplayNames = {
    'Bergrettung_Einheiten': 'Bergrettung Einheiten',
    'Bergrettung_Einrichtungen': 'Bergrettung Einrichtungen',
    'Bergrettung_Fahrzeuge': 'Bergrettung Fahrzeuge',
    'Bergrettung_Personen': 'Bergrettung Personen',
    'Bundeswehr_Einheiten': 'Bundeswehr Einheiten',
    'Bundeswehr_Fahrzeuge': 'Bundeswehr Fahrzeuge',
    'Bundeswehr_Personen': 'Bundeswehr Personen',
    'Einheiten': 'Einheiten',
    'Einrichtungen': 'Einrichtungen',
    'Fachdienste Einheiten HiOrg': 'Fachdienste HiOrg',
    'Fahrzeuge': 'Fahrzeuge',
    'Fernmeldewesen': 'Fernmeldewesen',
    'Feuerwehr_Einheiten': 'Feuerwehr Einheiten',
    'Feuerwehr_Einrichtungen': 'Feuerwehr Einrichtungen',
    'Feuerwehr_Fahrzeuge': 'Feuerwehr Fahrzeuge',
    'Feuerwehr_Gebäude': 'Feuerwehr Gebäude',
    'Feuerwehr_Personen': 'Feuerwehr Personen',
    'Führung Bayern': 'Führung Bayern',
    'Führung_Einheiten': 'Führung Einheiten',
    'Führung_Leitstellen': 'Führung Leitstellen',
    'Führung_Personen': 'Führung Personen',
    'Führung_Stellen': 'Führung Stellen',
    'Hilfeleistungskontingent Bayern': 'Hilfeleistungskontingent Bayern',
    'Maßnahmen': 'Maßnahmen',
    'Polizei_Einrichtungen': 'Polizei Einrichtungen',
    'Polizei_Personen': 'Polizei Personen',
    'Rettungswesen_Einrichtungen': 'Rettungswesen Einrichtungen',
  };

  Future<void> loadSymbols() async {
    if (_isLoaded) return;

    try {
      // Lade Asset Manifest
      final manifestContent = await rootBundle.loadString('AssetManifest.json');
      final Map<String, dynamic> manifestMap = json.decode(manifestContent);

      // Filtere TaktischeZeichen Assets
      final tacticalAssets =
          manifestMap.keys
              .where(
                (key) =>
                    key.startsWith('assets/TaktischeZeichen/') &&
                    key.endsWith('.svg'),
              )
              .toList();

      // Gruppiere nach Kategorien
      for (final assetPath in tacticalAssets) {
        final pathParts = assetPath.split('/');
        if (pathParts.length >= 3) {
          final category = pathParts[2]; // Der Ordnername
          final fileName = pathParts.last;
          final symbolName = fileName
              .replaceAll('.svg', '')
              .replaceAll('.lnk', '');

          // Ignoriere .lnk Dateien - die scheinen Verknüpfungen zu sein
          if (fileName.endsWith('.lnk')) continue;

          final symbol = TacticalSymbol(
            name: symbolName,
            assetPath: assetPath,
            category: category,
          );

          _categorizedSymbols.putIfAbsent(category, () => []).add(symbol);
        }
      }

      // Sortiere Symbole in jeder Kategorie
      for (final symbols in _categorizedSymbols.values) {
        symbols.sort((a, b) => a.name.compareTo(b.name));
      }

      _isLoaded = true;
    } catch (e) {
      print('Fehler beim Laden der taktischen Zeichen: $e');
    }
  }

  Map<String, List<TacticalSymbol>> get categorizedSymbols =>
      _categorizedSymbols;

  List<String> get categories => _categorizedSymbols.keys.toList()..sort();

  String getCategoryDisplayName(String category) {
    return categoryDisplayNames[category] ?? category;
  }

  List<TacticalSymbol> getSymbolsForCategory(String category) {
    return _categorizedSymbols[category] ?? [];
  }
}
