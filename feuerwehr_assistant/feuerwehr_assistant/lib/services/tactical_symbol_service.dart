// services/tactical_symbol_service.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import '../models/tactical_symbol.dart';

class TacticalSymbolService {
  static final TacticalSymbolService _instance = TacticalSymbolService._internal();
  factory TacticalSymbolService() => _instance;
  TacticalSymbolService._internal();

  List<TacticalSymbol> _symbols = [];
  bool _isInitialized = false;

  List<TacticalSymbol> get symbols => List.unmodifiable(_symbols);
  bool get isInitialized => _isInitialized;

  List<TacticalSymbol> getSymbolsByCategory(TacticalSymbolCategory category) {
    return _symbols.where((symbol) => symbol.category == category).toList();
  }

  // Durchsuchung nach Namen
  List<TacticalSymbol> searchSymbols(String query) {
    if (query.isEmpty) return symbols;
    
    final lowerQuery = query.toLowerCase();
    return _symbols.where((symbol) => 
      symbol.name.toLowerCase().contains(lowerQuery) ||
      symbol.description.toLowerCase().contains(lowerQuery)
    ).toList();
  }

  // Durchsuchung nach Namen und Kategorie
  List<TacticalSymbol> searchSymbolsInCategory(String query, TacticalSymbolCategory category) {
    if (query.isEmpty) return getSymbolsByCategory(category);
    
    final lowerQuery = query.toLowerCase();
    return _symbols.where((symbol) => 
      symbol.category == category &&
      (symbol.name.toLowerCase().contains(lowerQuery) ||
       symbol.description.toLowerCase().contains(lowerQuery))
    ).toList();
  }

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Lade alle SVG Symbole aus Assets
      await _loadSVGSymbolsFromAssets();
      
      // Lade zusätzliche Symbole aus Dokumenten-Ordner falls vorhanden
      await _loadSymbolsFromDocuments();
      
      _isInitialized = true;
      debugPrint('TacticalSymbolService initialized with ${_symbols.length} symbols');
    } catch (e) {
      debugPrint('Error initializing TacticalSymbolService: $e');
      _isInitialized = true; // Setze trotzdem auf true, um Endlosschleifen zu vermeiden
    }
  }

  Future<void> _loadSVGSymbolsFromAssets() async {
    try {
      // Definiere alle verfügbaren SVG-Dateien aus dem Assets-Ordner
      // Diese Liste muss manuell gepflegt werden, da Flutter keine dynamische Asset-Erkennung unterstützt
      final assetSymbols = await _getAllAssetSymbols();
      
      for (final assetInfo in assetSymbols) {
        try {
          // Prüfe ob Asset existiert
          final path = assetInfo['path'];
          final fileName = assetInfo['fileName'];
          final category = assetInfo['category'];
          
          if (path == null || fileName == null || category == null) {
            continue;
          }
          
          await rootBundle.load(path);
          
          final symbol = TacticalSymbol(
            id: 'asset_${category}_$fileName',
            name: _formatSymbolName(fileName),
            assetPath: path,
            category: _getCategoryFromString(category),
            description: 'Taktisches Zeichen: ${_formatSymbolName(fileName)}',
            backgroundColor: _getDefaultColorForCategory(_getCategoryFromString(category)),
          );
          
          _symbols.add(symbol);
        } catch (e) {
          debugPrint('Asset not found: ${assetInfo['path']}');
        }
      }
      
    } catch (e) {
      debugPrint('Error loading SVG symbols from assets: $e');
    }
  }

  // Diese Methode muss die tatsächlichen Dateien in Ihrem Assets-Ordner widerspiegeln
  Future<List<Map<String, String>>> _getAllAssetSymbols() async {
    // Hier werden alle SVG-Dateien aus dem Assets-Ordner definiert
    // Der Pfad: assets\Taktische Zeichen gesamt\SVG\Grundlage\[Kategorie]\[Datei].svg
    
    return [
      // Fahrzeuge - Beispiele (ersetzen Sie durch Ihre tatsächlichen Dateien)
      {
        'path': 'assets/Taktische Zeichen gesamt/SVG/Grundlage/Fahrzeuge/loeschfahrzeug.svg',
        'fileName': 'loeschfahrzeug',
        'category': 'Fahrzeuge'
      },
      {
        'path': 'assets/Taktische Zeichen gesamt/SVG/Grundlage/Fahrzeuge/rettungswagen.svg',
        'fileName': 'rettungswagen',
        'category': 'Fahrzeuge'
      },
      {
        'path': 'assets/Taktische Zeichen gesamt/SVG/Grundlage/Fahrzeuge/polizeiwagen.svg',
        'fileName': 'polizeiwagen',
        'category': 'Fahrzeuge'
      },
      
      // Gefahren - Beispiele
      {
        'path': 'assets/Taktische Zeichen gesamt/SVG/Grundlage/Gefahren/brand.svg',
        'fileName': 'brand',
        'category': 'Gefahren'
      },
      {
        'path': 'assets/Taktische Zeichen gesamt/SVG/Grundlage/Gefahren/explosion.svg',
        'fileName': 'explosion',
        'category': 'Gefahren'
      },
      
      // Ausrüstung - Beispiele
      {
        'path': 'assets/Taktische Zeichen gesamt/SVG/Grundlage/Ausruestung/hydrant.svg',
        'fileName': 'hydrant',
        'category': 'Ausruestung'
      },
      {
        'path': 'assets/Taktische Zeichen gesamt/SVG/Grundlage/Ausruestung/leiter.svg',
        'fileName': 'leiter',
        'category': 'Ausruestung'
      },
      
      // Personal - Beispiele
      {
        'path': 'assets/Taktische Zeichen gesamt/SVG/Grundlage/Personal/einsatzleiter.svg',
        'fileName': 'einsatzleiter',
        'category': 'Personal'
      },
      {
        'path': 'assets/Taktische Zeichen gesamt/SVG/Grundlage/Personal/sanitaeter.svg',
        'fileName': 'sanitaeter',
        'category': 'Personal'
      },
      
      // Infrastruktur - Beispiele
      {
        'path': 'assets/Taktische Zeichen gesamt/SVG/Grundlage/Infrastruktur/gebaeude.svg',
        'fileName': 'gebaeude',
        'category': 'Infrastruktur'
      },
      {
        'path': 'assets/Taktische Zeichen gesamt/SVG/Grundlage/Infrastruktur/krankenhaus.svg',
        'fileName': 'krankenhaus',
        'category': 'Infrastruktur'
      },
      
      // FÜGEN SIE HIER ALLE IHRE TATSÄCHLICHEN SVG-DATEIEN HINZU
      // Die Liste sollte alle SVG-Dateien aus Ihrem Assets-Ordner enthalten
    ];
  }

  Future<void> _loadSymbolsFromDocuments() async {
    try {
      final documentsDir = await getApplicationDocumentsDirectory();
      final tacticalSymbolsDir = Directory('${documentsDir.path}/tactical_symbols');
      
      if (!await tacticalSymbolsDir.exists()) {
        return;
      }

      final categories = ['fahrzeuge', 'gefahren', 'ausruestung', 'personal', 'infrastruktur'];
      
      for (String categoryName in categories) {
        final categoryDir = Directory('${tacticalSymbolsDir.path}/$categoryName');
        if (await categoryDir.exists()) {
          await _loadSymbolsFromDirectory(categoryDir, _getCategoryFromString(categoryName));
        }
      }
    } catch (e) {
      debugPrint('Error loading symbols from documents: $e');
    }
  }

  Future<void> _loadSymbolsFromDirectory(Directory dir, TacticalSymbolCategory category) async {
    try {
      final files = await dir.list().toList();
      
      for (FileSystemEntity file in files) {
        if (file is File) {
          final fileName = file.path.split('/').last;
          final extension = fileName.split('.').last.toLowerCase();
          
          if (['png', 'jpg', 'jpeg', 'svg'].contains(extension)) {
            final symbolName = fileName.split('.').first;
            final symbol = TacticalSymbol(
              id: 'custom_${category.name}_$symbolName',
              name: _formatSymbolName(symbolName),
              assetPath: file.path,
              category: category,
              description: 'Benutzerdefiniertes ${category.name} Symbol: ${_formatSymbolName(symbolName)}',
              backgroundColor: _getDefaultColorForCategory(category),
            );
            
            _symbols.add(symbol);
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading symbols from directory ${dir.path}: $e');
    }
  }

  TacticalSymbolCategory _getCategoryFromString(String categoryName) {
    switch (categoryName.toLowerCase()) {
      case 'vehicle':
      case 'vehicles':
      case 'fahrzeuge':
        return TacticalSymbolCategory.vehicle;
      case 'hazard':
      case 'hazards':
      case 'gefahren':
        return TacticalSymbolCategory.hazard;
      case 'equipment':
      case 'ausruestung':
      case 'ausrüstung':
        return TacticalSymbolCategory.equipment;
      case 'personnel':
      case 'personal':
        return TacticalSymbolCategory.personnel;
      case 'infrastructure':
      case 'infrastruktur':
        return TacticalSymbolCategory.infrastructure;
      default:
        return TacticalSymbolCategory.equipment;
    }
  }

  Color _getDefaultColorForCategory(TacticalSymbolCategory category) {
    switch (category) {
      case TacticalSymbolCategory.vehicle:
        return Colors.blue;
      case TacticalSymbolCategory.hazard:
        return Colors.red;
      case TacticalSymbolCategory.equipment:
        return Colors.grey;
      case TacticalSymbolCategory.personnel:
        return const Color(0xFFFFD700);
      case TacticalSymbolCategory.infrastructure:
        return Colors.brown;
    }
  }

  String _formatSymbolName(String fileName) {
    return fileName
        .replaceAll('_', ' ')
        .replaceAll('-', ' ')
        .split(' ')
        .map((word) => word.isNotEmpty ? '${word[0].toUpperCase()}${word.substring(1)}' : '')
        .join(' ');
  }

  Future<void> refreshSymbols() async {
    _symbols.clear();
    _isInitialized = false;
    await initialize();
  }

  // Hilfsmethode um alle Kategorien zu erhalten
  List<TacticalSymbolCategory> getAvailableCategories() {
    final categories = <TacticalSymbolCategory>{};
    for (final symbol in _symbols) {
      categories.add(symbol.category);
    }
    return categories.toList();
  }

  // Statistiken
  Map<TacticalSymbolCategory, int> getCategoryStats() {
    final stats = <TacticalSymbolCategory, int>{};
    for (final symbol in _symbols) {
      stats[symbol.category] = (stats[symbol.category] ?? 0) + 1;
    }
    return stats;
  }
}