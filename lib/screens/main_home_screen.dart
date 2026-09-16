import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:team_flo_app/screens/privacy_policy_screen.dart';
import 'package:team_flo_app/screens/stats_screen.dart';
import 'package:team_flo_app/widgets/belt_rank_badge.dart';
import '../config/colors.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import 'create_post_screen.dart';
import 'chat_screen.dart';
import 'calendar_screen.dart';
import 'home_screen.dart';
import 'journal_entry_screen.dart';
import 'schedule_screen.dart';
import 'profile_screen.dart';

class MainHomeScreen extends StatefulWidget {
  const MainHomeScreen({super.key});

  @override
  State<MainHomeScreen> createState() => _MainHomeScreenState();
}

class _MainHomeScreenState extends State<MainHomeScreen> {
  final AuthService _authService = AuthService();
  final User _currentUser = FirebaseAuth.instance.currentUser!;
  int _selectedIndex = 0;
  UserModel? _userData;

  late UserModel _originalUserData;

  final List<Widget> _screens = [
    const HomeScreen(),
    const ChatScreen(),
    const CalendarScreen(),
    const ScheduleScreen(),
    const StatsScreen(),
  ];

  final List<String> _titles = [
    'Team Flo BJJ',
    'Community Chat',
    'Training Journal',
    'Class Schedule',
    'Stats',
  ];

  @override
  void initState() {
    super.initState();
    _checkPrivacyPolicy();

    // Initialize with default/empty value
    _userData = UserModel(
      uid: '',
      email: '',
      name: '',
      role: 'member',
      createdAt: DateTime.now(),
    );
  }

  Future<void> _checkPrivacyPolicy() async {
    final userData = await _authService.getUserData(
      FirebaseAuth.instance.currentUser!.uid,
    );

    if (mounted && userData != null && userData['privacyPolicyAcknowledged'] != true) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const PrivacyPolicyScreen(isFirstLogin: true),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, dynamic>?>(
      stream: _getUserDataStream(),  // ← Real-time stream
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error})'));
        }
        if (snapshot.hasData && snapshot.data != null) {
          _userData = UserModel.fromMap(snapshot.data!);
        }

        return Scaffold(
          appBar: AppBar(
            leading: Padding(
              padding: const EdgeInsets.all(8.0),
              child: GestureDetector(
                onTap: () {
                  setState(() => _selectedIndex = 0);  // Always go to home
                },
                child: CircleAvatar(
                  backgroundImage: AssetImage('lib/assets/images/TeamFlo.png'),
                  radius: 20,
                ),
              )
            ),
            backgroundColor: AppColors.dark,
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: BeltRankBadge(
                  beltRank: _userData?.currentBelt,
                  width: 160,
                  height: 160,
                ),
              ),
              // Custom actions based on selected screen
              if (_selectedIndex == 1) // ChatScreen
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const CreatePostScreen()),
                    );
                  },
                ),
              if (_selectedIndex == 2) // CalendarScreen
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () => _openJournalEntry(DateTime.now()),
                ),
              // Profile dropdown menu (all screens)
              PopupMenuButton<String>(
                child: CircleAvatar(
                  backgroundImage: _userData?.photoUrl != null ? NetworkImage(_userData!.photoUrl!) : null,
                  child: _userData?.photoUrl == null ? const Icon(Icons.person) : null,
                  radius: 18,
                ),
                onSelected: (value) {
                  if (value == 'profile') {
                    _openProfileScreen();
                  } else if (value == 'logout') {
                    _logout();
                  }
                },
                itemBuilder: (BuildContext context) => [
                  const PopupMenuItem(
                    value: 'profile',
                    child: Row(
                      children: [
                        Icon(Icons.person, size: 20),
                        SizedBox(width: 8),
                        Text('View/Edit Profile'),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                    value: 'logout',
                    child: Row(
                      children: [
                        Icon(Icons.logout, size: 20, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Logout', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          body: _screens[_selectedIndex],
          bottomNavigationBar: BottomNavigationBar(
            backgroundColor: const Color(0xFF3A3A3A),
            selectedItemColor: const Color(0xFFFFB2B3),
            unselectedItemColor: AppColors.light,
            elevation: 16.0,
            currentIndex: _selectedIndex,
            onTap: (index) async {
              setState(() => _selectedIndex = index);
            },
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
              BottomNavigationBarItem(icon: Icon(Icons.feed), label: 'Chat'),
              BottomNavigationBarItem(
                  icon: Icon(Icons.calendar_today), label: 'Calendar'),
              BottomNavigationBarItem(
                  icon: Icon(Icons.schedule), label: 'Schedule'),
              BottomNavigationBarItem(
                  icon: Icon(Icons.bar_chart), label: 'Stats'),
            ],
          ),
        );
      }
    );
  }

  Future<void> _logout() async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout?'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Logout', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _authService.logout();
    }
  }

  Stream<Map<String, dynamic>?> _getUserDataStream() {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(_currentUser.uid)
        .snapshots()
        .timeout(
          Duration(seconds: 5),
          onTimeout: (sink) {
            sink.close();
          },
        )
        .map((doc) => doc.data())
        .handleError((error, stackTrace) {
          print('Error fetching user data: $error');
          return null;
        });
  }

  void _openProfileScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProfileScreen(key: ProfileScreen.profileKey),
      ),
    );
  }

  void _openJournalEntry(DateTime date) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => JournalEntryScreen(
          userId: FirebaseAuth.instance.currentUser!.uid,
          date: date,
        ),
      ),
    );
  }
}