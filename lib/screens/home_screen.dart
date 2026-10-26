import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:team_flo_app/widgets/home_attendance_card.dart';
import 'package:team_flo_app/widgets/instagram_feed_widget.dart';
import '../models/belt_rank_model.dart';
import '../models/gym_model.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/gym_service.dart';
import '../widgets/stats_highlights.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AuthService _authService = AuthService();
  final User _currentUser = FirebaseAuth.instance.currentUser!;

  late UserModel _userData;

  late TextEditingController _goalsController;

  @override
  void initState() {
    super.initState();

    _goalsController = TextEditingController();

    _userData = UserModel(
      uid: '',
      email: '',
      name: '',
      role: '',
      createdAt: DateTime.now(),
    );

    _loadUserData();
  }

  @override
  void dispose() {
    _goalsController.dispose();
    super.dispose();
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

      if (!mounted) return;
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
        _goalsController.text = _userData.goals;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final gym = context.watch<GymService>();

    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Welcome Content
            // PHASE 1 STEP 6: the gym's name from its gym document
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                gym.gym?.name ?? 'Team Flo BJJ',
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 20),

            // instagram feed
            // PHASE 1 STEP 5: only if the gym's plan includes it
            if (gym.hasModule(GymModules.instagram)) InstagramFeedWidget(),

            // attendance feed
            // PHASE 1 STEP 5: attendance needs the class schedule module
            if (gym.hasModule(GymModules.schedule)) const HomeAttendanceCard(),

            // Stats widget
            const StatsHighlightsWidget(),
          ],
        ),
      ),
    );
  }
}