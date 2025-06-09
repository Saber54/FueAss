import 'package:flutter/material.dart';

class TacticalSymbol {
  final String id;
  final String type; // z.B. "Fahrzeug", "Gefahrenzone"
  final String svgPath; // Pfad zur SVG-Datei
  final Color defaultColor;

  TacticalSymbol({
    required this.id,
    required this.type,
    required this.svgPath,
    this.defaultColor = Colors.red,
  });

  // Standard-Symbole
  static List<TacticalSymbol> defaults = [
    TacticalSymbol(
      id: 'vehicle',
      type: 'Fahrzeug',
      svgPath: 'assets/tactical/vehicle.svg',
    ),
    TacticalSymbol(
      id: 'hazard',
      type: 'Gefahrenzone',
      svgPath: 'assets/tactical/hazard.svg',
      defaultColor: Colors.yellow,
    ),
  ];
}