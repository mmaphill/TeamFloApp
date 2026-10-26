import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:team_flo_app/screens/privacy_policy_screen.dart';
import 'package:team_flo_app/screens/stats_screen.dart';
import 'package:team_flo_app/widgets/belt_rank_badge.dart';
import '../config/colors.dart';
import '../models/app_roles.dart';
import '../models/gym_model.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/gym_service.dart';
import 'create_post_screen.dart';
import 'chat_screen.dart';
import 'calendar_screen.dart';
import 'home_screen.dart';
import 'journal_entry_screen.dart';
import 'schedule_screen.dart';
import 'profile_screen.dart';
import 'staff_portal_screen.dart';
import '../utils/log.dart';

/// The bottom navigation tabs. PHASE 1 STEP 5: which ones show depends on
/// the gym's plan (see _visibleTabs).
enum _AppTab { home, chat, calendar, schedule, stats }

class MainHomeScreen extends StatefulWidget {
  /// Tab to open first, by its position in the FULL tab list:
  /// 0 Home, 1 Chat, 2 Calendar, 3 Schedule, 4 Stats.
  /// Notifications use 1 (Chat) and 2 (Calendar). If that tab is hidden
  /// for this gym, Home opens instead.
  final int? initialIndex;
  final String? postId;
  final String? classId;

  const MainHomeScreen({
    super.key,
    this.initialIndex,
    this.postId,
    this.classId,
  });

  @override
  State<MainHomeScreen> createState() => _MainHomeScreenState();
}

class _MainHomeScreenState extends State<MainHomeScreen> {
  final AuthService _authService = AuthService();
  final User _currentUser = FirebaseAuth.instance.currentUser!;
  late _AppTab _selectedTab;
  UserModel? _userData;

  /// PHASE 1 STEP 5: owners, managers, instructors and front desk see the
  /// Staff Portal, if the gym's plan includes it. (was: instructor or admin
  /// only.) Firestore rules enforce this too; hiding the menu is for tidiness.
  bool _showStaffPortal(GymService gym) =>
      AppRoles.isStaff(_userData?.role) && gym.hasModule(GymModules.staffPortal);

  /// PHASE 1 STEP 5: tabs the gym's plan includes, in display order.
  /// Home and Stats are always there (a bottom bar needs at least two tabs).
  List<_AppTab> _visibleTabs(GymService gym) => [
    _AppTab.home,
    if (gym.hasModule(GymModules.community)) _AppTab.chat,
    if (gym.hasModule(GymModules.journal)) _AppTab.calendar,
    if (gym.hasModule(GymModules.schedule)) _AppTab.schedule,
    _AppTab.stats,
  ];

  @override
  void initState() {
    super.initState();
    _checkPrivacyPolicy();

    // Translate the old number-based index (used by notifications) to a tab
    final int start = widget.initialIndex ?? 0;
    _selectedTab = (start >= 0 && start < _AppTab.values.length)
        ? _AppTab.values[start]
        : _AppTab.home;

    // Initialize with default/empty value
    _userData = UserModel(
      uid: '',
      email: '',
      name: '',
      role: 'member',
      createdAt: DateTime.now(),
    );
  }

  Widget _screenFor(_AppTab tab) {
    switch (tab) {
      case _AppTab.home:
        return const HomeScreen();
      case _AppTab.chat:
        return ChatScreen(postId: widget.postId);
      case _AppTab.calendar:
        return const CalendarScreen();
      case _AppTab.schedule:
        return const ScheduleScreen();
      case _AppTab.stats:
        return const StatsScreen();
    }
  }

  BottomNavigationBarItem _navItemFor(_AppTab tab) {
    switch (tab) {
      case _AppTab.home:
        return const BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home');
      case _AppTab.chat:
        return const BottomNavigationBarItem(icon: Icon(Icons.feed), label: 'Chat');
      case _AppTab.calendar:
        return const BottomNavigationBarItem(icon: Icon(Icons.calendar_today), label: 'Calendar');
      case _AppTab.schedule:
        return const BottomNavigationBarItem(icon: Icon(Icons.schedule), label: 'Schedule');
      case _AppTab.stats:
        return const BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: 'Stats');
    }
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
    final gym = context.watch<GymService>();
    final tabs = _visibleTabs(gym);

    // If the selected tab isn't in this gym's plan, fall back to Home
    final _AppTab currentTab = tabs.contains(_selectedTab) ? _selectedTab : _AppTab.home;
    final String? logoUrl = gym.gym?.logoUrl;
    final Color? brandColor = gym.gym?.primaryColorValue;

    // PHASE 1 STEP 6: the gym's logo, or Team Flo's if none is set.
    // Typed as ImageProvider so Dart knows both choices are images.
    final ImageProvider logoImage;
    if (logoUrl != null) {
      logoImage = NetworkImage(logoUrl);
    } else {
      logoImage = const AssetImage('lib/assets/images/TeamFlo.png');
    }

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
                      setState(() => _selectedTab = _AppTab.home);  // Always go to home
                    },
                    // PHASE 1 STEP 6: the gym's logo, or Team Flo's if none is set
                    child: CircleAvatar(
                      backgroundImage: logoImage,
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
                if (currentTab == _AppTab.chat)
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
                if (currentTab == _AppTab.calendar)
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () => _openJournalEntry(DateTime.now()),
                  ),
                // Profile dropdown menu (all screens)
                PopupMenuButton<String>(
                  child: CircleAvatar(
                    backgroundImage: _userData?.photoUrl != null ? NetworkImage(_userData!.photoUrl!) : null,
                    radius: 18,
                    child: _userData?.photoUrl == null ? const Icon(Icons.person) : null,
                  ),
                  onSelected: (value) {
                    if (value == 'profile') {
                      _openProfileScreen();
                    } else if (value == 'staff') {
                      _openStaffPortal();
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
                    if (_showStaffPortal(gym))
                      const PopupMenuItem(
                        value: 'staff',
                        child: Row(
                          children: [
                            Icon(Icons.admin_panel_settings, size: 20),
                            SizedBox(width: 8),
                            Text('Staff Portal'),
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
            body: _screenFor(currentTab),
            bottomNavigationBar: BottomNavigationBar(
              // fixed: keeps labels and colors steady for 2 to 5 tabs
              type: BottomNavigationBarType.fixed,
              backgroundColor: const Color(0xFF3A3A3A),
              // PHASE 1 STEP 6: the gym's color, or Team Flo's pink if none is set
              selectedItemColor: brandColor ?? const Color(0xFFFFB2B3),
              unselectedItemColor: AppColors.light,
              elevation: 16.0,
              currentIndex: tabs.indexOf(currentTab),
              onTap: (index) {
                setState(() => _selectedTab = tabs[index]);
              },
              items: tabs.map(_navItemFor).toList(),
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
      log('Error fetching user data: $error');
      return null;
    });
  }

  void _openProfileScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProfileScreen(),
      ),
    );
  }

  void _openStaffPortal() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const StaffPortalScreen()),
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