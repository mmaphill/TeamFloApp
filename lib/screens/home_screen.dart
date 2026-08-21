import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/belt_rank_model.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../widgets/belt_rank_badge.dart';
import 'profile_screen.dart';
import '../config/colors.dart';
import 'feed_screen.dart';
import 'schedule_screen.dart';
import 'calendar_screen.dart';

class HomeScreen extends StatefulWidget {
  final String userId;

  const HomeScreen({super.key, required this.userId});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AuthService _authService = AuthService();
  final User _currentUser = FirebaseAuth.instance.currentUser!;
  int _selectedIndex = 0;

  late UserModel _userData;

  late TextEditingController _nameController;
  late TextEditingController _goalsController;

  @override
  void initState() {
    super.initState();

    _userData = UserModel(
      uid: '',
      email: '',
      name: '',
      role: '',
      createdAt: DateTime.now(),
    );

    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final data = await _authService.getUserData(_currentUser.uid);
    if (data != null) {
      UserModel user = UserModel.fromMap(data);

      // Set currentBelt to the most recent belt rank
      String? currentBelt;
      if (user.beltRankHistory.isNotEmpty) {
        // Sort by date and get the latest
        List<BeltRank> sorted = List.from(user.beltRankHistory);
        sorted.sort((a, b) => b.promotionDate.compareTo(a.promotionDate));
        currentBelt = sorted.first.rank;
      }

      setState(() {
        _userData = UserModel(
          uid: user.uid,
          email: user.email,
          name: user.name,
          role: user.role,
          createdAt: user.createdAt,
          beltRankHistory: user.beltRankHistory,
          goals: user.goals,
          competitionStats: user.competitionStats,
          photoUrl: user.photoUrl,
          avatarColor: user.avatarColor,
          currentBelt: currentBelt,
        );
        _nameController.text = _userData!.name;
        _goalsController.text = _userData!.goals;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Team Flo BJJ'),
        actions: [
          if (_userData != null)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: BeltRankBadge(beltRank: _userData.currentBelt, width: 180, height: 180,),
            ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Welcome to TeamFlo!',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Text('User ID: ${widget.userId}'),
            const SizedBox(height: 20),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        type: BottomNavigationBarType.fixed,
        backgroundColor: AppColors.primary,
        selectedItemColor: AppColors.light,
        unselectedItemColor: AppColors.dark,
        onTap: (index) {
          setState(() => _selectedIndex = index);
          if (index == 0) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const FeedScreen()),
            );
          }
          if (index == 1) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const CalendarScreen()),
            );
          }
          if (index == 2) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ScheduleScreen()),
            );
          }
          if (index == 3) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ProfileScreen()),
            );
          }
        },
        items: const [
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
}