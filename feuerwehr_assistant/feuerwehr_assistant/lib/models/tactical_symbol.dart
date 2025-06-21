// models/tactical_symbol.dart
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

enum TacticalSymbolCategory {
  vehicle,
  hazard,
  equipment,
  personnel,
  infrastructure
}

class TacticalSymbol {
  final String id;
  final String name;
  final String assetPath;
  final TacticalSymbolCategory category;
  final String description;
  final Color? backgroundColor;
  final double size;

  const TacticalSymbol({
    required this.id,
    required this.name,
    required this.assetPath,
    required this.category,
    required this.description,
    this.backgroundColor,
    this.size = 40.0,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TacticalSymbol &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

class PlacedTacticalSymbol {
  final String id;
  final TacticalSymbol symbol;
  final LatLng position;
  final DateTime placedAt;
  final String? label;

  PlacedTacticalSymbol({
    required this.id,
    required this.symbol,
    required this.position,
    required this.placedAt,
    this.label,
  });

  PlacedTacticalSymbol copyWith({
    String? id,
    TacticalSymbol? symbol,
    LatLng? position,
    DateTime? placedAt,
    String? label,
  }) {
    return PlacedTacticalSymbol(
      id: id ?? this.id,
      symbol: symbol ?? this.symbol,
      position: position ?? this.position,
      placedAt: placedAt ?? this.placedAt,
      label: label ?? this.label,
    );
  }
}



