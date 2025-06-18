import 'package:flutter/material.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Einstellungen',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          ListTile(
            leading: const Icon(Icons.map),
            title: const Text('Karteneinstellungen'),
            onTap: () {
              // Navigiere zu Karteneinstellungen
            },
          ),
          ListTile(
            leading: const Icon(Icons.notifications),
            title: const Text('Benachrichtigungen'),
            onTap: () {
              // Navigiere zu Benachrichtigungseinstellungen
            },
          ),
          ListTile(
            leading: const Icon(Icons.security),
            title: const Text('Datenschutz'),
            onTap: () {
              // Navigiere zu Datenschutzeinstellungen
            },
          ),
          ListTile(
            leading: const Icon(Icons.info),
            title: const Text('Über die App'),
            onTap: () {
              // Navigiere zu Info-Seite
            },
          ),
          const Divider(),
          SwitchListTile(
            title: const Text('Dunkelmodus'),
            value: false,
            onChanged: (value) {
              // Dunkelmodus-Logik
            },
          ),
        ],
      ),
    );
  }
}