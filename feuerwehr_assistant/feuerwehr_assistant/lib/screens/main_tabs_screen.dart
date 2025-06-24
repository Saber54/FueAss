import 'package:flutter/material.dart';
import 'hazmat_screen.dart';
import 'map_screen.dart';
import 'log_screen.dart';
import 'radio_sketch_screen.dart';
import 'vehicles_screen.dart';
import 'weather_screen.dart';
import 'notes_screen.dart'; // Neuer Import für Notizen
import 'settings_screen.dart';
import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class MainTabsScreen extends StatefulWidget {
  const MainTabsScreen({super.key});

  @override
  State<MainTabsScreen> createState() => _MainTabsScreenState();
}

class _MainTabsScreenState extends State<MainTabsScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late AnimationController _blinkController;
  bool _hasActiveReminders = false;
  Timer? _reminderTimer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 8, vsync: this); // Auf 8 Tabs erhöht
    _blinkController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _startReminderTimer();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _blinkController.dispose();
    _reminderTimer?.cancel();
    super.dispose();
  }

  void _startReminderTimer() {
    _reminderTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _checkReminders();
    });
  }

  Future<void> _checkReminders() async {
    final prefs = await SharedPreferences.getInstance();
    final notesJson = prefs.getStringList('notes') ?? [];
    final now = DateTime.now();
    bool hasActive = false;

    for (final str in notesJson) {
      final map = jsonDecode(str);
      final isReminderActive = map['isReminderActive'] ?? false;
      final hasNotifiedReminder = map['hasNotifiedReminder'] ?? false;
      if (!isReminderActive || hasNotifiedReminder) continue;

      if (map['reminderDateTime'] != null) {
        if (now.isAfter(DateTime.parse(map['reminderDateTime']))) {
          hasActive = true;
          break;
        }
      } else if (map['reminderDuration'] != null) {
        final createdAt = DateTime.parse(map['createdAt']);
        final duration = Duration(seconds: map['reminderDuration']);
        if (now.isAfter(createdAt.add(duration))) {
          hasActive = true;
          break;
        }
      }
    }

    if (mounted) {
      setState(() {
        _hasActiveReminders = hasActive;
      });
      if (hasActive) {
        if (!_blinkController.isAnimating) {
          _blinkController.repeat(reverse: true);
        }
      } else {
        if (_blinkController.isAnimating) {
          _blinkController.stop();
          _blinkController.reset();
        }
      }
    }
  }

  void _onReminderStatusChanged(bool hasActiveReminders) {
    setState(() {
      _hasActiveReminders = hasActiveReminders;
    });

    if (hasActiveReminders) {
      _blinkController.repeat(reverse: true);
    } else {
      _blinkController.stop();
      _blinkController.reset();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Feuerwehr-Assistent'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: [
            const Tab(icon: Icon(Icons.map), text: 'Karte'),
            const Tab(icon: Icon(Icons.book), text: 'Tagebuch'),
            const Tab(icon: Icon(Icons.radio), text: 'Funkskizze'),
            const Tab(icon: Icon(Icons.local_shipping), text: 'Fahrzeuge'),
            const Tab(icon: Icon(Icons.dangerous), text: 'Gefahrgut'),
            Tab(
              icon:
                  _hasActiveReminders
                      ? AnimatedBuilder(
                        animation: _blinkController,
                        builder: (context, child) {
                          return Container(
                            decoration: BoxDecoration(
                              color: Color.lerp(
                                Colors.red,
                                Colors.red.withOpacity(0.3),
                                _blinkController.value,
                              ),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            padding: const EdgeInsets.all(4),
                            child: const Icon(
                              Icons.note_alt,
                              color: Colors.white,
                            ),
                          );
                        },
                      )
                      : const Icon(Icons.note_alt),
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
