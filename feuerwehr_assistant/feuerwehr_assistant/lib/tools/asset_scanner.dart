// tools/asset_scanner.dart
// Dieses Tool hilft dabei, alle SVG-Dateien zu scannen und den Code zu generieren

import 'dart:io';

void main() async {
  final assetsPath = 'assets/Taktische Zeichen gesamt/SVG';
  final baseDir = Directory(assetsPath);
  
  if (!await baseDir.exists()) {
    print('Verzeichnis nicht gefunden: $assetsPath');
    print('Bitte stellen Sie sicher, dass der Pfad korrekt ist.');
    return;
  }

  print('Scanne Verzeichnis: $assetsPath');
  print('');
  
  final assetEntries = <String>[];
  
  await for (FileSystemEntity entity in baseDir.list(recursive: true)) {
    if (entity is File && entity.path.toLowerCase().endsWith('.svg')) {
      final relativePath = entity.path.replaceAll('\\', '/');
      final parts = relativePath.split('/');
      
      if (parts.length >= 2) {
        final fileName = parts.last.replaceAll('.svg', '');
        final category = parts[parts.length - 2];
        
        final entry = """      {
        'path': '$relativePath',
        'fileName': '$fileName',
        'category': '$category'
      },""";
        
        assetEntries.add(entry);
        print('Gefunden: $category/$fileName');
      }
    }
  }
  
  print('');
  print('=== GENERIERTER CODE FÜR _getAllAssetSymbols() ===');
  print('');
  print('Future<List<Map<String, String>>> _getAllAssetSymbols() async {');
  print('  return [');
  
  for (final entry in assetEntries) {
    print(entry);
  }
  
  print('  ];');
  print('}');
  
  print('');
  print('=== PUBSPEC.YAML ASSETS SECTION ===');
  print('');
  print('flutter:');
  print('  assets:');
  
  final directories = <String>{};
  for (final entry in assetEntries) {
    final pathMatch = RegExp(r"'path': '([^']+)'").firstMatch(entry);
    if (pathMatch != null) {
      final fullPath = pathMatch.group(1)!;
      final directory = fullPath.substring(0, fullPath.lastIndexOf('/') + 1);
      directories.add(directory);
    }
  }
  
  for (final dir in directories) {
    print('    - $dir');
  }
  
  print('');
  print('Gefunden: ${assetEntries.length} SVG-Dateien in ${directories.length} Verzeichnissen');
}