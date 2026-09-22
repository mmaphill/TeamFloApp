import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:team_flo_app/services/notification_service.dart';
import 'config/theme_provider.dart';
import 'firebase_options.dart';
import 'screens/login_screen.dart';
import 'screens/main_home_screen.dart';
import 'config/theme_data.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize notifications
  await NotificationService().initialize();
  NotificationService().listenForTokenRefresh();

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
    // Initialize theme provider and load saved preference
    _themeProvider = ThemeProvider();
    _themeProvider.loadSavedTheme();
  }

  @override
  Widget build(BuildContext context) {
    // Wrap app with Provider to make ThemeProvider available app-wide
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _themeProvider),
        // Add your other providers here in the future
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            navigatorKey: navigatorKey,
            title: 'Team Flo BJJ',
            theme: AppThemes.lightTheme,
            darkTheme: AppThemes.darkTheme,
            themeMode: themeProvider.themeMode,
            onGenerateRoute: (settings) {
              if (settings.name == '/chat') {
                final postId = settings.arguments as String?;
                return MaterialPageRoute(
                  builder: (context) => MainHomeScreen(
                    initialIndex: 1,
                    postId: postId,
                  ),
                );
              }
              if (settings.name == '/journal') {
                final classId = settings.arguments as String?;
                return MaterialPageRoute(
                  builder: (context) => MainHomeScreen(
                    initialIndex: 2,
                    classId: classId,
                  ),
                );
              }
              return null;
            },
            home: StreamBuilder<User?>(
              stream: FirebaseAuth.instance.authStateChanges(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.active) {
                  return snapshot.data != null ? const MainHomeScreen() : const LoginScreen();
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