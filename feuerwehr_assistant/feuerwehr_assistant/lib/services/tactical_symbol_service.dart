// services/tactical_symbol_service.dart
import 'dart:io';
import 'package:flutter/material.dart';
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

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Lade Symbole aus Assets-Ordner
      await _loadSymbolsFromAssets();
      
      // Lade zusätzliche Symbole aus Dokumenten-Ordner falls vorhanden
      await _loadSymbolsFromDocuments();
      
      _isInitialized = true;
      debugPrint('TacticalSymbolService initialized with ${_symbols.length} symbols');
    } catch (e) {
      debugPrint('Error initializing TacticalSymbolService: $e');
      _isInitialized = true; // Setze trotzdem auf true, um Endlosschleifen zu vermeiden
    }
  }

  Future<void> _loadSymbolsFromAssets() async {
    try {
      // Lade die Symbol-Konfiguration aus einem JSON oder direkt hier definiert
      _symbols.addAll(_getDefaultSymbols());
    } catch (e) {
      debugPrint('Error loading symbols from assets: $e');
    }
  }

  Future<void> _loadSymbolsFromDocuments() async {
    try {
      final documentsDir = await getApplicationDocumentsDirectory();
      final tacticalSymbolsDir = Directory('${documentsDir.path}/tactical_symbols');
      
      if (!await tacticalSymbolsDir.exists()) {
        return;
      }

      final categories = ['vehicle', 'hazard', 'equipment', 'personnel', 'infrastructure'];
      
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
              description: 'Benutzerdefiniertes ${category.name} Symbol',
            );
            
            _symbols.add(symbol);
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading symbols from directory ${dir.path}: $e');
    }
  }

  List<TacticalSymbol> _getDefaultSymbols() {
    return [
      // Fahrzeuge
      const TacticalSymbol(
        id: 'vehicle_fire_truck',
        name: 'Löschfahrzeug',
        assetPath: 'assets/tactical_symbols/vehicles/fire_truck.png',
        category: TacticalSymbolCategory.vehicle,
        description: 'Löschfahrzeug für Brandbekämpfung',
        backgroundColor: Colors.red,
      ),
      const TacticalSymbol(
        id: 'vehicle_ambulance',
        name: 'Rettungswagen',
        assetPath: 'assets/tactical_symbols/vehicles/ambulance.png',
        category: TacticalSymbolCategory.vehicle,
        description: 'Rettungswagen für medizinische Notfälle',
        backgroundColor: Colors.white,
      ),
      const TacticalSymbol(
        id: 'vehicle_police',
        name: 'Polizeifahrzeug',
        assetPath: 'assets/tactical_symbols/vehicles/police_car.png',
        category: TacticalSymbolCategory.vehicle,
        description: 'Polizeifahrzeug',
        backgroundColor: Colors.blue,
      ),
      const TacticalSymbol(
        id: 'vehicle_command',
        name: 'Einsatzleitwagen',
        assetPath: 'assets/tactical_symbols/vehicles/command_vehicle.png',
        category: TacticalSymbolCategory.vehicle,
        description: 'Einsatzleitwagen',
        backgroundColor: Colors.yellow,
      ),

      // Gefahren
      const TacticalSymbol(
        id: 'hazard_fire',
        name: 'Brand',
        assetPath: 'assets/tactical_symbols/hazards/fire.png',
        category: TacticalSymbolCategory.hazard,
        description: 'Brandstelle',
        backgroundColor: Colors.red,
      ),
      const TacticalSymbol(
        id: 'hazard_chemical',
        name: 'Chemische Gefahr',
        assetPath: 'assets/tactical_symbols/hazards/chemical.png',
        category: TacticalSymbolCategory.hazard,
        description: 'Chemische Gefahrenquelle',
        backgroundColor: Colors.orange,
      ),
      const TacticalSymbol(
        id: 'hazard_explosion',
        name: 'Explosionsgefahr',
        assetPath: 'assets/tactical_symbols/hazards/explosion.png',
        category: TacticalSymbolCategory.hazard,
        description: 'Explosionsgefahr',
        backgroundColor: Colors.deepOrange,
      ),
      const TacticalSymbol(
        id: 'hazard_gas',
        name: 'Gasleck',
        assetPath: 'assets/tactical_symbols/hazards/gas_leak.png',
        category: TacticalSymbolCategory.hazard,
        description: 'Gasleck',
        backgroundColor: Colors.yellow,
      ),

      // Ausrüstung
      const TacticalSymbol(
        id: 'equipment_hydrant',
        name: 'Hydrant',
        assetPath: 'assets/tactical_symbols/equipment/hydrant.png',
        category: TacticalSymbolCategory.equipment,
        description: 'Wasserhydrant',
        backgroundColor: Colors.blue,
      ),
      const TacticalSymbol(
        id: 'equipment_ladder',
        name: 'Leiter',
        assetPath: 'assets/tactical_symbols/equipment/ladder.png',
        category: TacticalSymbolCategory.equipment,
        description: 'Leiterposition',
        backgroundColor: Colors.grey,
      ),

      // Personal
      const TacticalSymbol(
        id: 'personnel_commander',
        name: 'Einsatzleiter',
        assetPath: 'assets/tactical_symbols/personnel/commander.png',
        category: TacticalSymbolCategory.personnel,
        description: 'Einsatzleiter Position',
        backgroundColor: Color(0xFFFFD700),
      ),
      const TacticalSymbol(
        id: 'personnel_medic',
        name: 'Sanitäter',
        assetPath: 'assets/tactical_symbols/personnel/medic.png',
        category: TacticalSymbolCategory.personnel,
        description: 'Sanitäter Position',
        backgroundColor: Colors.white,
      ),

      // Infrastruktur
      const TacticalSymbol(
        id: 'infrastructure_building',
        name: 'Gebäude',
        assetPath: 'assets/tactical_symbols/infrastructure/building.png',
        category: TacticalSymbolCategory.infrastructure,
        description: 'Wichtiges Gebäude',
        backgroundColor: Colors.brown,
      ),
      const TacticalSymbol(
        id: 'infrastructure_hospital',
        name: 'Krankenhaus',
        assetPath: 'assets/tactical_symbols/infrastructure/hospital.png',
        category: TacticalSymbolCategory.infrastructure,
        description: 'Krankenhaus',
        backgroundColor: Colors.white,
      ),
    ];
  }

  TacticalSymbolCategory _getCategoryFromString(String categoryName) {
    switch (categoryName.toLowerCase()) {
      case 'vehicle':
      case 'vehicles':
        return TacticalSymbolCategory.vehicle;
      case 'hazard':
      case 'hazards':
        return TacticalSymbolCategory.hazard;
      case 'equipment':
        return TacticalSymbolCategory.equipment;
      case 'personnel':
        return TacticalSymbolCategory.personnel;
      case 'infrastructure':
        return TacticalSymbolCategory.infrastructure;
      default:
        return TacticalSymbolCategory.equipment;
    }
  }

  String _formatSymbolName(String fileName) {
    return fileName
        .replaceAll('_', ' ')
        .split(' ')
        .map((word) => word.isNotEmpty ? word[0].toUpperCase() + word.substring(1) : '')
        .join(' ');
  }

  Future<void> refreshSymbols() async {
    _symbols.clear();
    _isInitialized = false;
    await initialize();
  }
}