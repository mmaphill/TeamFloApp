import 'package:cloud_firestore/cloud_firestore.dart';

class AnalyticsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Fetch all journal entries for a user
  Future<List<Map<String, dynamic>>> getJournalEntries(String uid) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(uid)
          .collection('journal')
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

  // Aggregate all type counts across entries
  Map<String, int> aggregateTypes(List<Map<String, dynamic>> entries) {
    final types = {
      'Pass': 0,
      'Escape': 0,
      'Retention': 0,
      'Sweep': 0,
      'Submission': 0,
    };

    for (final entry in entries) {
      final type = entry['type'] as String?;
      if (type != null && types.containsKey(type)) {
        types[type] = (types[type] ?? 0) + 1;
      }
    }

    return types;
  }

  // Aggregate submission counts (total submitted + times submitted)
  ({int totalSubmissions, int submissionAttempts, int timesSubmitted}) aggregateSubmissions(
      List<Map<String, dynamic>> entries,
      ) {
    int totalSubmissions = 0;
    int submissionAttempts = 0;
    int timesSubmitted = 0;

    for (final entry in entries) {
      totalSubmissions += entry['submissions'] as int? ?? 0;
      submissionAttempts += entry['submissionAttempts'] as int? ?? 0;
      timesSubmitted += entry['timesSubmitted'] as int? ?? 0;
    }

    return (totalSubmissions: totalSubmissions, submissionAttempts: submissionAttempts, timesSubmitted: timesSubmitted);
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
  int getTotalMatches(List<Map<String, dynamic>> competitionStats) {
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

  double calculateSubmissionSuccessRate(
    ({int totalSubmissions, int submissionAttempts, int timesSubmitted}) submissions,
  ){
    if (submissions.submissionAttempts == 0) return 0.0;
    return submissions.totalSubmissions / submissions.submissionAttempts;
  }

  // Format percentage for display
  String formatPercentage(double value) {
    return '${(value * 100).toStringAsFixed(0)}%';
  }

  // Format number for display
  String formatNumber(int value) {
    return value.toString();
  }

  // Save user's preferred summary stats
  Future<void> saveSummaryPreference(String uid, List<String> selectedStats) async {
    try {
      await _firestore.collection('users').doc(uid).update({
        'summaryPreference': selectedStats,
      });
    } catch (e) {
      print('Error saving summary preference: $e');
    }
  }

  // Get user's preferred summary stats (default to all three)
  Future<List<String>> getSummaryPreference(String uid) async {
    try {
      final snapshot = await _firestore.collection('users').doc(uid).get();
      final preference = snapshot.data()?['summaryPreference'] as List?;
      return preference?.cast<String>() ?? ['Classes', 'Submissions', 'SubmissionSuccessRate'];
    } catch (e) {
      print('Error fetching summary preference: $e');
      return ['Classes', 'Submissions', 'Submission Success Rate'];
    }
  }

  // Aggregate techniques by type with metrics
  ({
    Map<String, Map<String, int>> techniquesByType,
    Map<String, int> techniqueFrequency,
    String? mostUsedTechnique,
    double techniqueDiversity,
  }) aggregateTechniques(List<Map<String, dynamic>> entries) {

    final techniquesByType = <String, Map<String, int>>{};
    final techniqueFrequency = <String, int>{};

    for (final entry in entries) {
      final techniques = entry['techniques'] as Map<String, dynamic>? ?? {};

      for (final typeEntry in techniques.entries) {
        final type = typeEntry.key as String;
        final techniqueList = (typeEntry.value as List?)?.cast<String>() ?? [];

        if (!techniquesByType.containsKey(type)) {
          techniquesByType[type] = {};
        }

        for (final technique in techniqueList) {
          techniquesByType[type]![technique] = (techniquesByType[type]![technique] ?? 0) + 1;

          techniqueFrequency[technique] = (techniqueFrequency[technique] ?? 0) + 1;
        }
      }
    }

    // Get most used technique
    String? mostUsed;
    int maxCount = 0;
    techniqueFrequency.forEach((technique, count) {
      if (count > maxCount) {
        maxCount = count;
        mostUsed = technique;
      }
    });

    // Calculate diversity (unique techniques / total entries with techniques)
    final uniqueCount = techniqueFrequency.length;
    final totalTechniquesLogged = techniqueFrequency.values.fold<int>(0, (sum, v) => sum + v);
    final diversity = totalTechniquesLogged > 0 ? uniqueCount / totalTechniquesLogged : 0.0;

    return (
    techniquesByType: techniquesByType,
    techniqueFrequency: techniqueFrequency,
    mostUsedTechnique: mostUsed,
    techniqueDiversity: diversity,
    );
  }

  // Get techniques for a specific type
  Map<String, int> getTechniquesByType(
      List<Map<String, dynamic>> entries,
      String typeFilter,
      ) {
    final aggregated = aggregateTechniques(entries);
    return aggregated.techniquesByType[typeFilter] ?? {};
  }

  // Get top N techniques
  List<Map<String, dynamic>> getTopTechniques(
      List<Map<String, dynamic>> entries, {
        int limit = 5,
      }) {
    final aggregated = aggregateTechniques(entries);
    final sorted = aggregated.techniqueFrequency.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sorted.take(limit).map((e) => {
      'technique': e.key,
      'count': e.value,
    }).toList();
  }

  // Get all unique techniques from the entire gym
  Future<List<String>> getAllTechniquesFromGym() async {
    try {
      final snapshot = await _firestore
          .collectionGroup('journal')
          .get();

      final all = <String>{};
      for (final doc in snapshot.docs) {
        try {
          // Safely access techniques field with null check
          final techniques = doc.data()['techniques'] as Map<String, dynamic>? ?? {};

          for (final techniqueList in techniques.values) {
            final list = (techniqueList as List?)?.cast<String>() ?? [];
            all.addAll(list);
          }
        } catch (e) {
          // Skip documents that don't have techniques or have parsing errors
          print('Skipping entry: $e');
          continue;
        }
      }

      return all.toList()..sort();
    } catch (e) {
      print('Error fetching gym techniques: $e');
      return [];
    }
  }

// Suggest techniques from gym-wide data
  List<String> suggestTechniques(List<String> allTechniques, String input) {
    if (input.isEmpty) return [];

    final normalized = input.toLowerCase();

    return allTechniques.where((tech) {
      final techNorm = tech.toLowerCase();
      return techNorm.startsWith(normalized) ||
          _levenshteinDistance(techNorm, normalized) <= 2;
    }).toList();
  }

  int _levenshteinDistance(String s1, String s2) {
    if (s1.isEmpty) return s2.length;
    if (s2.isEmpty) return s1.length;

    final matrix = List.generate(s1.length + 1, (i) => List.generate(s2.length + 1, (j) => 0));

    for (int i = 0; i <= s1.length; i++) matrix[i][0] = i;
    for (int j = 0; j <= s2.length; j++) matrix[0][j] = j;

    for (int i = 1; i <= s1.length; i++) {
      for (int j = 1; j <= s2.length; j++) {
        final cost = s1[i - 1] == s2[j - 1] ? 0 : 1;
        matrix[i][j] = [
          matrix[i - 1][j] + 1,
          matrix[i][j - 1] + 1,
          matrix[i - 1][j - 1] + cost,
        ].reduce((a, b) => a < b ? a : b);
      }
    }

    return matrix[s1.length][s2.length];
  }
}