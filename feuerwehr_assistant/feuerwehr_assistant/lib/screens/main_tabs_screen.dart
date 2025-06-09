import 'package:flutter/material.dart';
import 'hazmat_screen.dart';
import 'map_screen.dart';
import 'log_screen.dart';
import 'radio_sketch_screen.dart';
import 'vehicles_screen.dart';

class MainTabsScreen extends StatelessWidget {
  const MainTabsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Feuerwehr-Assistent'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(icon: Icon(Icons.map), text: 'Karte'),
              Tab(icon: Icon(Icons.book), text: 'Tagebuch'),
              Tab(icon: Icon(Icons.radio), text: 'Funkskizze'),
              Tab(icon: Icon(Icons.local_shipping), text: 'Fahrzeuge'),
              Tab(icon: Icon(Icons.dangerous), text: 'Gefahrgut'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            MapScreen(),
            LogScreen(),
            RadioSketchScreen(),
            VehiclesScreen(),
            HazmatScreen(),
          ],
        ),
      ),
    );
  }
}