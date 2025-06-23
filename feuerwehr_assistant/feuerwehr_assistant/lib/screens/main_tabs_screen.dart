import 'package:flutter/material.dart';
import 'hazmat_screen.dart';
import 'map_screen.dart';
import 'log_screen.dart';
import 'radio_sketch_screen.dart';
import 'vehicles_screen.dart';
import 'weather_screen.dart';
import 'notes_screen.dart'; // Neuer Import für Notizen
import 'settings_screen.dart';

class MainTabsScreen extends StatefulWidget {
  const MainTabsScreen({super.key});

  @override
  State<MainTabsScreen> createState() => _MainTabsScreenState();
}

class _MainTabsScreenState extends State<MainTabsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _hasActiveReminders = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 8, vsync: this); // Auf 8 Tabs erhöht
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _onReminderStatusChanged(bool hasActiveReminders) {
    setState(() {
      _hasActiveReminders = hasActiveReminders;
    });
  }

  void _onNotesTabOpened() {
    setState(() {
      _hasActiveReminders = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Feuerwehr-Assistent'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          onTap: (index) {
            // Index 5 ist der Notizen-Tab
            if (index == 5 && _hasActiveReminders) {
              _onNotesTabOpened();
            }
          },
          tabs: [
            const Tab(icon: Icon(Icons.map), text: 'Karte'),
            const Tab(icon: Icon(Icons.book), text: 'Tagebuch'),
            const Tab(icon: Icon(Icons.radio), text: 'Funkskizze'),
            const Tab(icon: Icon(Icons.local_shipping), text: 'Fahrzeuge'),
            const Tab(icon: Icon(Icons.dangerous), text: 'Gefahrgut'),
            Tab(
              icon: AnimatedContainer(
                duration: const Duration(milliseconds: 500),
                decoration: BoxDecoration(
                  color: _hasActiveReminders ? Colors.red : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: EdgeInsets.all(_hasActiveReminders ? 4 : 0),
                child: Icon(
                  Icons.note_alt,
                  color: _hasActiveReminders ? Colors.white : null,
                ),
              ),
              text: 'Notizen',
            ),
            const Tab(icon: Icon(Icons.wb_sunny), text: 'Wetter'),
            const Tab(icon: Icon(Icons.settings), text: 'Einstellungen'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          const MapScreen(),
          const LogScreen(),
          const RadioSketchScreen(),
          const VehiclesScreen(),
          const HazmatScreen(),
          NotesScreen(onReminderStatusChanged: _onReminderStatusChanged),
          const WeatherScreen(),
          const SettingsScreen(),
        ],
      ),
    );
  }
}
