import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;

void main() => runApp(FeuerwehrApp());

class FeuerwehrApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Feuerwehr System',
      theme: ThemeData(primarySwatch: Colors.red),
      initialRoute: '/login',
      routes: {
        '/login': (ctx) => LoginScreen(),
        '/admin': (ctx) => AdminScreen(),
        '/export': (ctx) => ExportScreen(),
      },
    );
  }
}