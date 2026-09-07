import 'package:cloud_firestore/cloud_firestore.dart';

class AnalyticsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Fetch all journal entries for a user
  Future<List<Map<String, dynamic>>> getJournalEntries(String uid) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(uid)
          .collection('journalEntries')
          .orderBy('date', descending: true)
          .get();

      return snapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      print('Error fetching journal entries: $e');
      return [];
    }
  }

  // Fetch user profile for competition stats
  Future<Map<String, dynamic>?> getUserProfile(String uid) async {
    try {
      final snapshot = await _firestore.collection('users').doc(uid).get();
      return snapshot.data();
    } catch (e) {
      print('Error fetching user profile: $e');
      return null;
    }
  }

  // Count classes this month
  int getClassesThisMonth(List<Map<String, dynamic>> entries) {
    final now = DateTime.now();
    return entries
        .where((e) {
      final date = (e['date'] as Timestamp).toDate();
      return date.year == now.year && date.month == now.month;
    })
        .length;
  }

  // Aggregate all technique counts across entries
  Map<String, int> aggregateTechniques(List<Map<String, dynamic>> entries) {
    final techniques = {
      'Pass': 0,
      'Escape': 0,
      'Retention': 0,
      'Sweep': 0,
      'Submission': 0,
    };

    for (final entry in entries) {
      final technique = entry['technique'] as String?;
      if (technique != null && techniques.containsKey(technique)) {
        techniques[technique] = (techniques[technique] ?? 0) + 1;
      }
    }

    return techniques;
  }

  // Aggregate submission counts (total submitted + times submitted)
  ({int totalSubmissions, int timesSubmitted}) aggregateSubmissions(
      List<Map<String, dynamic>> entries,
      ) {
    int totalSubmissions = 0;
    int timesSubmitted = 0;

    for (final entry in entries) {
      totalSubmissions += entry['submissions'] as int? ?? 0;
      timesSubmitted += entry['timesSubmitted'] as int? ?? 0;
    }

    return (totalSubmissions: totalSubmissions, timesSubmitted: timesSubmitted);
  }

  // Get position frequency
  Map<String, int> getPositionFrequency(List<Map<String, dynamic>> entries) {
    final positionCounts = <String, int>{};

    for (final entry in entries) {
      final position = entry['position'] as String?;
      if (position != null && position.isNotEmpty) {
        positionCounts[position] = (positionCounts[position] ?? 0) + 1;
      }
    }

    return positionCounts;
  }

  // Get attendance trend (classes per week over last N weeks)
  List<({int weekNumber, int classCount})> getAttendanceTrend(
      List<Map<String, dynamic>> entries, {
        int weeksBack = 8,
      }) {
    final now = DateTime.now();
    final weekData = <int, int>{};

    for (int i = 0; i < weeksBack; i++) {
      weekData[i] = 0;
    }

    for (final entry in entries) {
      final date = (entry['date'] as Timestamp).toDate();
      final daysDiff = now.difference(date).inDays;
      final weekNumber = daysDiff ~/ 7;

      if (weekNumber < weeksBack) {
        weekData[weekNumber] = (weekData[weekNumber] ?? 0) + 1;
      }
    }

    // Convert to sorted list (oldest week first for chart)
    return List.generate(
      weeksBack,
          (i) => (weekNumber: i, classCount: weekData[i] ?? 0),
    ).reversed.toList();
  }

  // Calculate average metrics (energy, sleep, water, food)
  ({
  double avgEnergy,
  double avgSleep,
  double avgWater,
  double avgFood,
  }) getAverageMetrics(List<Map<String, dynamic>> entries) {
    if (entries.isEmpty) {
      return (avgEnergy: 0, avgSleep: 0, avgWater: 0, avgFood: 0);
    }

    double totalEnergy = 0;
    double totalSleep = 0;
    double totalWater = 0;
    double totalFood = 0;

    for (final entry in entries) {
      totalEnergy += entry['energy'] as int? ?? 0;
      totalSleep += entry['sleep'] as int? ?? 0;
      totalWater += entry['water'] as int? ?? 0;
      totalFood += entry['food'] as int? ?? 0;
    }

    return (
    avgEnergy: totalEnergy / entries.length,
    avgSleep: totalSleep / entries.length,
    avgWater: totalWater / entries.length,
    avgFood: totalFood / entries.length,
    );
  }

  // Parse competition stats from user profile
  List<Map<String, dynamic>> parseCompetitionStats(
      Map<String, dynamic>? userProfile,
      ) {
    if (userProfile == null) return [];

    final competitionStats = userProfile['competitionStats'] as List? ?? [];
    return competitionStats.cast<Map<String, dynamic>>();
  }

  // Calculate overall win rate across all formats and ranks
  double calculateOverallWinRate(List<Map<String, dynamic>> competitionStats) {
    if (competitionStats.isEmpty) return 0.0;

    int totalWins = 0;
    int totalMatches = 0;

    for (final stats in competitionStats) {
      final submissionWins = stats['submissionWins'] as int? ?? 0;
      final pointWins = stats['pointWins'] as int? ?? 0;
      final refDecisionWins = stats['refDecisionWins'] as int? ?? 0;
      final submissionLosses = stats['submissionLosses'] as int? ?? 0;
      final pointLosses = stats['pointLosses'] as int? ?? 0;
      final refDecisionLosses = stats['refDecisionLosses'] as int? ?? 0;

      totalWins += submissionWins + pointWins + refDecisionWins;
      totalMatches +=
          submissionWins +
              pointWins +
              refDecisionWins +
              submissionLosses +
              pointLosses +
              refDecisionLosses;
    }

    if (totalMatches == 0) return 0.0;
    return totalWins / totalMatches;
  }

  // Get total competition count
  int getTotalCompetitions(List<Map<String, dynamic>> competitionStats) {
    int total = 0;
    for (final stats in competitionStats) {
      final submissionWins = stats['submissionWins'] as int? ?? 0;
      final pointWins = stats['pointWins'] as int? ?? 0;
      final refDecisionWins = stats['refDecisionWins'] as int? ?? 0;
      final submissionLosses = stats['submissionLosses'] as int? ?? 0;
      final pointLosses = stats['pointLosses'] as int? ?? 0;
      final refDecisionLosses = stats['refDecisionLosses'] as int? ?? 0;

      total +=
          submissionWins +
              pointWins +
              refDecisionWins +
              submissionLosses +
              pointLosses +
              refDecisionLosses;
    }
    return total;
  }

  // Get win breakdown by method (submission, points, ref decision)
  ({int submissions, int points, int refDecisions}) getWinBreakdown(
      List<Map<String, dynamic>> competitionStats,
      ) {
    int submissions = 0;
    int points = 0;
    int refDecisions = 0;

    for (final stats in competitionStats) {
      submissions += stats['submissionWins'] as int? ?? 0;
      points += stats['pointWins'] as int? ?? 0;
      refDecisions += stats['refDecisionWins'] as int? ?? 0;
    }

    return (submissions: submissions, points: points, refDecisions: refDecisions);
  }

  // Get loss breakdown by method
  ({int submissions, int points, int refDecisions}) getLossBreakdown(
      List<Map<String, dynamic>> competitionStats,
      ) {
    int submissions = 0;
    int points = 0;
    int refDecisions = 0;

    for (final stats in competitionStats) {
      submissions += stats['submissionLosses'] as int? ?? 0;
      points += stats['pointLosses'] as int? ?? 0;
      refDecisions += stats['refDecisionLosses'] as int? ?? 0;
    }

    return (submissions: submissions, points: points, refDecisions: refDecisions);
  }

  // Get stats by format (Gi vs No Gi)
  Map<String, ({int wins, int losses})> getStatsByFormat(
      List<Map<String, dynamic>> competitionStats,
      ) {
    final formatStats = <String, ({int wins, int losses})>{};

    for (final stats in competitionStats) {
      final format = stats['format'] as String? ?? 'Gi';
      final submissionWins = stats['submissionWins'] as int? ?? 0;
      final pointWins = stats['pointWins'] as int? ?? 0;
      final refDecisionWins = stats['refDecisionWins'] as int? ?? 0;
      final submissionLosses = stats['submissionLosses'] as int? ?? 0;
      final pointLosses = stats['pointLosses'] as int? ?? 0;
      final refDecisionLosses = stats['refDecisionLosses'] as int? ?? 0;

      final wins = submissionWins + pointWins + refDecisionWins;
      final losses = submissionLosses + pointLosses + refDecisionLosses;

      if (formatStats.containsKey(format)) {
        final current = formatStats[format]!;
        formatStats[format] = (
        wins: current.wins + wins,
        losses: current.losses + losses,
        );
      } else {
        formatStats[format] = (wins: wins, losses: losses);
      }
    }

    return formatStats;
  }

  // Get stats by rank (belt level)
  Map<String, ({int wins, int losses})> getStatsByRank(
      List<Map<String, dynamic>> competitionStats,
      ) {
    final rankStats = <String, ({int wins, int losses})>{};

    for (final stats in competitionStats) {
      final rank = stats['rank'] as String? ?? 'Unknown';
      final submissionWins = stats['submissionWins'] as int? ?? 0;
      final pointWins = stats['pointWins'] as int? ?? 0;
      final refDecisionWins = stats['refDecisionWins'] as int? ?? 0;
      final submissionLosses = stats['submissionLosses'] as int? ?? 0;
      final pointLosses = stats['pointLosses'] as int? ?? 0;
      final refDecisionLosses = stats['refDecisionLosses'] as int? ?? 0;

      final wins = submissionWins + pointWins + refDecisionWins;
      final losses = submissionLosses + pointLosses + refDecisionLosses;

      if (rankStats.containsKey(rank)) {
        final current = rankStats[rank]!;
        rankStats[rank] = (
        wins: current.wins + wins,
        losses: current.losses + losses,
        );
      } else {
        rankStats[rank] = (wins: wins, losses: losses);
      }
    }

    return rankStats;
  }

  // Format percentage for display
  String formatPercentage(double value) {
    return '${(value * 100).toStringAsFixed(0)}%';
  }

  // Format number for display
  String formatNumber(int value) {
    return value.toString();
  }
}