import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin-Einstellungen'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SwitchListTile(
            title: const Text('Master-Modus'),
            value: authProvider.isMaster,
            onChanged: authProvider.isServer
                ? null // Server kann Master nicht deaktivieren
                : (value) => authProvider.setMasterRole(value),
          ),
          const Divider(),
          ListTile(
            title: const Text('Geräte verwalten'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.pushNamed(context, '/device-management'),
          ),
        ],
      ),
    );
  }
}