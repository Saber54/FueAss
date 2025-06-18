import 'package:flutter/material.dart';
import 'hazmat_screen.dart';
import 'map_screen.dart';
import 'log_screen.dart';
import 'radio_sketch_screen.dart';
import 'vehicles_screen.dart';
import 'settings_screen.dart'; // Neuer Import für Settings

class MainTabsScreen extends StatefulWidget {
  const MainTabsScreen({super.key});

  @override
  State<MainTabsScreen> createState() => _MainTabsScreenState();
}

class _MainTabsScreenState extends State<MainTabsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this); // Auf 6 Tabs erhöht
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Feuerwehr-Assistent'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(icon: Icon(Icons.map), text: 'Karte'),
            Tab(icon: Icon(Icons.book), text: 'Tagebuch'),
            Tab(icon: Icon(Icons.radio), text: 'Funkskizze'),
            Tab(icon: Icon(Icons.local_shipping), text: 'Fahrzeuge'),
            Tab(icon: Icon(Icons.dangerous), text: 'Gefahrgut'),
            Tab(icon: Icon(Icons.settings), text: 'Einstellungen'), // Neuer Tab
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          MapScreen(),
          LogScreen(),
          RadioSketchScreen(),
          VehiclesScreen(),
          HazmatScreen(),
          SettingsScreen(), // Neuer Settings Screen
        ],
      ),
    );
  }
}