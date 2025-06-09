import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class InstallModeScreen extends StatelessWidget {
  const InstallModeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Installationsmodus wählen:', 
              style: TextStyle(fontSize: 18)),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () async {
                await authProvider.enableServerMode();
                await authProvider.setMasterRole(true);
                Navigator.pushReplacementNamed(context, '/home');
              },
              child: const Text('Als Server + Master-Gerät'),
            ),
            const SizedBox(height: 15),
            ElevatedButton(
              onPressed: () {
                Navigator.pushReplacementNamed(context, '/home');
              },
              child: const Text('Nur als Client'),
            ),
          ],
        ),
      ),
    );
  }
}