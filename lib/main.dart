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
import 'services/gym_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Must be registered before runApp
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  // Initialize notifications
  await NotificationService().initialize();
  NotificationService().listenForTokenRefresh();

  // Save the FCM token whenever a user logs in (including on app start)
  FirebaseAuth.instance.authStateChanges().listen((user) {
    if (user != null) {
      NotificationService().saveCurrentToken();
    }
  });

  // Load the signed-in user's gym and role, and keep them up to date
  GymService.instance.start();

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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationService().handleInitialMessage();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Wrap app with Provider to make ThemeProvider available app-wide
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _themeProvider),
        ChangeNotifierProvider.value(value: GymService.instance),
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
                if (snapshot.connectionState != ConnectionState.active) {
                  return const _LoadingScreen();
                }
                if (snapshot.data == null) {
                  return const LoginScreen();
                }
                // Signed in: wait for the gym before showing the app,
                // so every screen can rely on GymService being ready.
                return const _GymGate(child: MainHomeScreen());
              },
            ),
          );
        },
      ),
    );
  }
}

/// Shows [child] once the user's gym has loaded.
/// Shows a spinner while loading, and an error with a sign-out button
/// if the gym could not be loaded.
class _GymGate extends StatelessWidget {
  final Widget child;
  const _GymGate({required this.child});

  @override
  Widget build(BuildContext context) {
    final gymService = context.watch<GymService>();

    if (!gymService.isLoaded) {
      return const _LoadingScreen();
    }

    if (gymService.error != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48),
                const SizedBox(height: 16),
                Text(
                  gymService.error!,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                TextButton(
                  onPressed: () => FirebaseAuth.instance.signOut(),
                  child: const Text('Sign out'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return child;
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}