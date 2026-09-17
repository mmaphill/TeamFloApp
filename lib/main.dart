import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:team_flo_app/screens/privacy_policy_screen.dart';
import 'config/theme_provider.dart';
import 'firebase_options.dart';
import 'screens/login_screen.dart';
import 'screens/main_home_screen.dart';
import 'config/colors.dart';
import 'config/theme_data.dart'; // NEW: Import theme definitions
import 'config/theme_provider.dart'; // NEW: Import ThemeProvider

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const TeamFloApp());
}

class TeamFloApp extends StatefulWidget {
  const TeamFloApp({super.key});

  @override
  State<TeamFloApp> createState() => _TeamFloAppState();
}

class _TeamFloAppState extends State<TeamFloApp> {
  late ThemeProvider _themeProvider; // NEW: Create theme provider instance

  @override
  void initState() {
    super.initState();
    // NEW: Initialize theme provider and load saved preference
    _themeProvider = ThemeProvider();
    _themeProvider.loadSavedTheme();
  }

  @override
  Widget build(BuildContext context) {
    // NEW: Wrap app with Provider to make ThemeProvider available app-wide
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _themeProvider),
        // Add your other providers here in the future
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            title: 'Team Flo BJJ',
            // NEW: Use AppThemes with dynamic theme switching
            theme: AppThemes.lightTheme,
            darkTheme: AppThemes.darkTheme,
            themeMode: themeProvider.themeMode, // NEW: Dynamic theme mode
            home: StreamBuilder<User?>(
              stream: FirebaseAuth.instance.authStateChanges(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.active) {
                  return snapshot.data != null
                      ? const MainHomeScreen()
                      : const LoginScreen();
                }
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              },
            ),
          );
        },
      ),
    );
  }
}