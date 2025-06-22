import 'package:flutter/material.dart';
import 'hazmat_screen.dart';
import 'map_screen.dart';
import 'log_screen.dart';
import 'radio_sketch_screen.dart';
import 'vehicles_screen.dart';
import 'weather_screen.dart'; // Neuer Import für Weather
import 'settings_screen.dart';

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
    _tabController = TabController(length: 7, vsync: this); // Auf 7 Tabs erhöht
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
            Tab(
              icon: Icon(Icons.wb_sunny),
              text: 'Wetter',
            ), // Neuer Weather Tab
            Tab(icon: Icon(Icons.settings), text: 'Einstellungen'),
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
          WeatherScreen(), // Neuer Weather Screen
          SettingsScreen(),
        ],
      ),
    );
  }
}
