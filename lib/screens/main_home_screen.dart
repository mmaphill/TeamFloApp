import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:team_flo_app/widgets/belt_rank_badge.dart';
import '../config/colors.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import 'create_post_screen.dart';
import 'feed_screen.dart';
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
  int _selectedIndex = 0;
  UserModel? _userData;

  final List<Widget> _screens = [
    const HomeScreen(),
    const FeedScreen(),
    const CalendarScreen(),
    const ScheduleScreen(),
    const ProfileScreen(),
  ];

  final List<String> _titles = [
    'Team Flo BJJ',
    'Community Feed',
    'Training Journal',
    'Class Schedule',
    'Profile',
  ];

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final data = await _authService.getUserData(
      FirebaseAuth.instance.currentUser!.uid,
    );
    if (data != null) {
      setState(() {
        _userData = UserModel.fromMap(data);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_selectedIndex]),
        backgroundColor: AppColors.primary,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: BeltRankBadge(beltRank: _userData!.currentBelt, width: 160, height: 160,),
          ),
          // Custom actions based on selected screen
          if (_selectedIndex == 0) // Home Screen
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: _logout,
            ),
          if (_selectedIndex == 1) // FeedScreen
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const CreatePostScreen()),
                );
              },
            ),
          if (_selectedIndex == 2) // CalendarScreen
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => _openJournalEntry(DateTime.now()),
            ),
        ],
      ),
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: AppColors.primary,
        selectedItemColor: AppColors.light,
        unselectedItemColor: AppColors.dark,
        elevation: 16.0,
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() => _selectedIndex = index);
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.feed), label: 'Feed'),
          BottomNavigationBarItem(icon: Icon(Icons.calendar_today), label: 'Calendar'),
          BottomNavigationBarItem(icon: Icon(Icons.schedule), label: 'Schedule'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }

  Future<void> _logout() async {
    await _authService.logout();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Logged out')),
      );
    }
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