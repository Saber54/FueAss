import 'package:flutter/material.dart';
import 'package:provider/provider.dart';


// Provider
import 'providers/theme_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/hazmat_provider.dart';

// Screens
import 'screens/install_mode_screen.dart';
import 'screens/main_tabs_screen.dart';

// Utils
import 'utils/config_loader.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Konfiguration laden
  final config = await ConfigLoader.loadAppConfig();
  
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()..initialize()),
        ChangeNotifierProvider(create: (_) => AuthProvider()..initialize()),
        ChangeNotifierProvider(create: (_) => HazmatProvider()..loadHazmats()),
      ],
      child: MaterialApp(
        theme: ThemeData.light(),
        darkTheme: ThemeData.dark(),
        initialRoute: config['isConfigured'] == true ? '/home' : '/install',
        routes: {
          '/install': (_) => const InstallModeScreen(),
          '/home': (_) => const MainTabsScreen(),
        },
      ),
    ),
  );
}