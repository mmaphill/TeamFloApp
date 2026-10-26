import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/log.dart';

/// Wins or losses split by how the match ended
typedef MethodBreakdown = ({int submissions, int points, int refDecisions});

/// Total wins and losses for a group (format, rank, etc.)
typedef WinLoss = ({int wins, int losses});

/// Journal submission totals across all entries
typedef SubmissionTotals = ({
int totalSubmissions,
int submissionAttempts,
int timesSubmitted,
});

/// Average journal metrics across all entries
typedef AverageMetrics = ({
double avgEnergy,
double avgSleep,
double avgWater,
double avgFood,
});

/// One item in a ranked list (technique, submission, etc.)
typedef RankedItem = ({String name, int count});

class AnalyticsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Firestore field names for submission lists.
  // These MUST match the keys used in JournalEntry.toMap().
  static const String _madeSubmissionsKey = 'madeSubmissions';
  static const String _caughtSubmissionsKey = 'caughtSubmissions';

  // ===========================================================================
  // Reading helpers — safe ways to pull values out of Firestore maps
  // ===========================================================================

  /// Reads a number safely. Missing or wrong type returns 0.
  static int _int(Map<String, dynamic> map, String key) {
    return (map[key] as num?)?.toInt() ?? 0;
  }

  /// Reads the entry date safely. Returns null if missing.
  static DateTime? _dateOf(Map<String, dynamic> entry) {
    final raw = entry['date'];
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    return null;
  }

  /// Reads a list of names. Handles a List, the old Map format,
  /// or a single String, so older entries don't break anything.
  static List<String> _readStringList(dynamic data) {
    if (data is List) {
      return data.whereType<String>().toList();
    }
    if (data is Map) {
      return data.values
          .whereType<List>()
          .expand((list) => list)
          .whereType<String>()
          .toList();
    }
    if (data is String) {
      return [data];
    }
    return [];
  }

  /// Cleans a name so "Armbar", "armbar " and "ARMBAR" count as one.
  static String _normalize(String value) => value.trim().toLowerCase();

  // ===========================================================================
  // Counting helpers — reusable for any list of names
  // ===========================================================================

  /// Counts how many times each name shows up. Blank names are skipped.
  static Map<String, int> _countFrequency(Iterable<String> items) {
    final counts = <String, int>{};
    for (final raw in items) {
      final item = _normalize(raw);
      if (item.isEmpty) continue;
      counts[item] = (counts[item] ?? 0) + 1;
    }
    return counts;
  }

  /// Sorts any frequency map from most to least common and keeps the top N.
  /// Ties are sorted alphabetically so the order stays stable.
  List<RankedItem> topN(Map<String, int> frequency, {int limit = 5}) {
    final sorted = frequency.entries.toList()
      ..sort((a, b) {
        final byCount = b.value.compareTo(a.value);
        return byCount != 0 ? byCount : a.key.compareTo(b.key);
      });

    return sorted
        .take(limit)
        .map((e) => (name: e.key, count: e.value))
        .toList();
  }

  // ===========================================================================
  // Firestore reads
  // ===========================================================================

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
      log('Error fetching journal entries: $e');
      return [];
    }
  }

  // Fetch user profile for competition stats
  Future<Map<String, dynamic>?> getUserProfile(String uid) async {
    try {
      final snapshot = await _firestore.collection('users').doc(uid).get();
      return snapshot.data();
    } catch (e) {
      log('Error fetching user profile: $e');
      return null;
    }
  }

  // ===========================================================================
  // Journal analytics
  // ===========================================================================

  // Count journal entries this month
  int getClassesThisMonth(List<Map<String, dynamic>> entries) {
    final now = DateTime.now();
    return entries.where((e) {
      final date = _dateOf(e);
      return date != null && date.year == now.year && date.month == now.month;
    }).length;
  }

  // Count how often each type (Pass, Sweep, etc.) was logged
  Map<String, int> aggregateTypes(List<Map<String, dynamic>> entries) {
    final types = {
      'Pass': 0,
      'Escape': 0,
      'Retention': 0,
      'Sweep': 0,
      'Submission': 0,
    };

    for (final entry in entries) {
      // Model saves this field as 'types', not 'type'
      final type = entry['types'] as String?;
      if (type != null && types.containsKey(type)) {
        types[type] = types[type]! + 1;
      }
    }

    return types;
  }

  // Total submissions, attempts, and times submitted across all entries
  SubmissionTotals aggregateSubmissions(List<Map<String, dynamic>> entries) {
    int totalSubmissions = 0;
    int submissionAttempts = 0;
    int timesSubmitted = 0;

    for (final entry in entries) {
      totalSubmissions += _int(entry, 'submissions');
      submissionAttempts += _int(entry, 'submissionAttempts');
      timesSubmitted += _int(entry, 'timesSubmitted');
    }

    return (
    totalSubmissions: totalSubmissions,
    submissionAttempts: submissionAttempts,
    timesSubmitted: timesSubmitted,
    );
  }

  double calculateSubmissionSuccessRate(SubmissionTotals submissions) {
    if (submissions.submissionAttempts == 0) return 0.0;
    return submissions.totalSubmissions / submissions.submissionAttempts;
  }

  // How often each position was logged
  Map<String, int> getPositionFrequency(List<Map<String, dynamic>> entries) {
    final positions = entries
        .map((e) => e['position'])
        .whereType<String>();
    return _countFrequency(positions);
  }

  // How often each submission was landed on training partners
  Map<String, int> getSubmissionFrequency(List<Map<String, dynamic>> entries) {
    final names = entries.expand((e) => _readStringList(e[_madeSubmissionsKey]));
    return _countFrequency(names);
  }

  // How often each submission caught the user
  Map<String, int> getSubmittedFrequency(List<Map<String, dynamic>> entries) {
    final names = entries.expand((e) => _readStringList(e[_caughtSubmissionsKey]));
    return _countFrequency(names);
  }

  // Top N submissions landed
  List<RankedItem> getTopSubmissions(
      List<Map<String, dynamic>> entries, {
        int limit = 5,
      }) {
    return topN(getSubmissionFrequency(entries), limit: limit);
  }

  // Top N submissions the user got caught with
  List<RankedItem> getTopCaughtWith(
      List<Map<String, dynamic>> entries, {
        int limit = 5,
      }) {
    return topN(getSubmittedFrequency(entries), limit: limit);
  }

  // Get attendance trend (entries per week over last N weeks)
  List<({int weekNumber, int classCount})> getAttendanceTrend(
      List<Map<String, dynamic>> entries, {
        int weeksBack = 8,
      }) {
    final now = DateTime.now();
    final weekData = List<int>.filled(weeksBack, 0);

    for (final entry in entries) {
      final date = _dateOf(entry);
      if (date == null) continue;

      final weekNumber = now.difference(date).inDays ~/ 7;
      if (weekNumber >= 0 && weekNumber < weeksBack) {
        weekData[weekNumber]++;
      }
    }

    // Oldest week first for the chart
    return List.generate(
      weeksBack,
          (i) => (weekNumber: i, classCount: weekData[i]),
    ).reversed.toList();
  }

  // Average daily metrics. A value of 0 means "not set", so it's skipped.
  AverageMetrics getAverageMetrics(List<Map<String, dynamic>> entries) {
    double averageOf(String key) {
      final values = entries.map((e) => _int(e, key)).where((v) => v > 0);
      if (values.isEmpty) return 0;
      return values.reduce((a, b) => a + b) / values.length;
    }

    return (
    avgEnergy: averageOf('energy'),
    avgSleep: averageOf('sleep'),
    avgWater: averageOf('water'),
    avgFood: averageOf('food'),
    );
  }

  // ===========================================================================
  // Competition analytics
  // ===========================================================================

  /// Reads the three win counts from one competition record.
  static MethodBreakdown _winsOf(Map<String, dynamic> stats) => (
  submissions: _int(stats, 'submissionWins'),
  points: _int(stats, 'pointWins'),
  refDecisions: _int(stats, 'refDecisionWins'),
  );

  /// Reads the three loss counts from one competition record.
  static MethodBreakdown _lossesOf(Map<String, dynamic> stats) => (
  submissions: _int(stats, 'submissionLosses'),
  points: _int(stats, 'pointLosses'),
  refDecisions: _int(stats, 'refDecisionLosses'),
  );

  static int _totalOf(MethodBreakdown b) =>
      b.submissions + b.points + b.refDecisions;

  static MethodBreakdown _addBreakdowns(MethodBreakdown a, MethodBreakdown b) => (
  submissions: a.submissions + b.submissions,
  points: a.points + b.points,
  refDecisions: a.refDecisions + b.refDecisions,
  );

  static const MethodBreakdown _emptyBreakdown =
  (submissions: 0, points: 0, refDecisions: 0);

  /// Groups wins and losses by any field (format, rank, etc.)
  static Map<String, WinLoss> _groupWinLoss(
      List<Map<String, dynamic>> competitionStats,
      String groupKey,
      String fallback,
      ) {
    final grouped = <String, WinLoss>{};

    for (final stats in competitionStats) {
      final group = stats[groupKey] as String? ?? fallback;
      final wins = _totalOf(_winsOf(stats));
      final losses = _totalOf(_lossesOf(stats));

      final current = grouped[group] ?? (wins: 0, losses: 0);
      grouped[group] = (
      wins: current.wins + wins,
      losses: current.losses + losses,
      );
    }

    return grouped;
  }

  // Parse competition stats from user profile
  List<Map<String, dynamic>> parseCompetitionStats(
      Map<String, dynamic>? userProfile,
      ) {
    if (userProfile == null) return [];

    final competitionStats = userProfile['competitionStats'] as List? ?? [];
    return competitionStats.cast<Map<String, dynamic>>();
  }

  // Overall win rate across all formats and ranks
  double calculateOverallWinRate(List<Map<String, dynamic>> competitionStats) {
    final totalMatches = getTotalMatches(competitionStats);
    if (totalMatches == 0) return 0.0;

    final totalWins = _totalOf(getWinBreakdown(competitionStats));
    return totalWins / totalMatches;
  }

  // Total number of competition matches
  int getTotalMatches(List<Map<String, dynamic>> competitionStats) {
    return _totalOf(getWinBreakdown(competitionStats)) +
        _totalOf(getLossBreakdown(competitionStats));
  }

  // Wins split by method (submission, points, ref decision)
  MethodBreakdown getWinBreakdown(List<Map<String, dynamic>> competitionStats) {
    return competitionStats
        .map(_winsOf)
        .fold(_emptyBreakdown, _addBreakdowns);
  }

  // Losses split by method
  MethodBreakdown getLossBreakdown(List<Map<String, dynamic>> competitionStats) {
    return competitionStats
        .map(_lossesOf)
        .fold(_emptyBreakdown, _addBreakdowns);
  }

  // Wins/losses by format (Gi vs No Gi)
  Map<String, WinLoss> getStatsByFormat(
      List<Map<String, dynamic>> competitionStats,
      ) {
    return _groupWinLoss(competitionStats, 'format', 'Gi');
  }

  // Wins/losses by rank (belt level)
  Map<String, WinLoss> getStatsByRank(
      List<Map<String, dynamic>> competitionStats,
      ) {
    return _groupWinLoss(competitionStats, 'rank', 'Unknown');
  }

  // ===========================================================================
  // Display formatting
  // ===========================================================================

  String formatPercentage(double value) {
    return '${(value * 100).toStringAsFixed(0)}%';
  }

  String formatNumber(int value) {
    return value.toString();
  }

  // ===========================================================================
  // Summary preferences
  // ===========================================================================

  static const List<String> _defaultSummary = [
    'Classes',
    'Submissions',
    'SubmissionSuccessRate',
  ];

  Future<void> saveSummaryPreference(String uid, List<String> selectedStats) async {
    try {
      await _firestore.collection('users').doc(uid).update({
        'summaryPreference': selectedStats,
      });
    } catch (e) {
      log('Error saving summary preference: $e');
    }
  }

  Future<List<String>> getSummaryPreference(String uid) async {
    try {
      final snapshot = await _firestore.collection('users').doc(uid).get();
      final preference = snapshot.data()?['summaryPreference'] as List?;
      return preference?.cast<String>() ?? _defaultSummary;
    } catch (e) {
      log('Error fetching summary preference: $e');
      return _defaultSummary;
    }
  }

  // ===========================================================================
  // Technique analytics
  // ===========================================================================

  ({
  Map<String, Map<String, int>> techniquesByType,
  Map<String, int> techniqueFrequency,
  String? mostUsedTechnique,
  double techniqueDiversity,
  }) aggregateTechniques(List<Map<String, dynamic>> entries) {
    final techniquesByType = <String, Map<String, int>>{};
    final allTechniques = <String>[];

    for (final entry in entries) {
      final techniques = entry['techniques'];
      if (techniques is! Map) continue;

      techniques.forEach((type, value) {
        final list = _readStringList(value);
        allTechniques.addAll(list);

        final typeCounts = _countFrequency(list);
        final existing = techniquesByType.putIfAbsent(type.toString(), () => {});
        typeCounts.forEach((name, count) {
          existing[name] = (existing[name] ?? 0) + count;
        });
      });
    }

    final techniqueFrequency = _countFrequency(allTechniques);
    final top = topN(techniqueFrequency, limit: 1);

    // Diversity = unique techniques / total techniques logged
    final totalLogged = techniqueFrequency.values.fold<int>(0, (sum, v) => sum + v);
    final diversity = totalLogged > 0 ? techniqueFrequency.length / totalLogged : 0.0;

    return (
    techniquesByType: techniquesByType,
    techniqueFrequency: techniqueFrequency,
    mostUsedTechnique: top.isEmpty ? null : top.first.name,
    techniqueDiversity: diversity,
    );
  }

  // Techniques for a specific type
  Map<String, int> getTechniquesByType(
      List<Map<String, dynamic>> entries,
      String typeFilter,
      ) {
    return aggregateTechniques(entries).techniquesByType[typeFilter] ?? {};
  }

  // Top N techniques (kept in the old map format so existing UI still works)
  List<Map<String, dynamic>> getTopTechniques(
      List<Map<String, dynamic>> entries, {
        int limit = 5,
      }) {
    final frequency = aggregateTechniques(entries).techniqueFrequency;
    return topN(frequency, limit: limit)
        .map((item) => {'technique': item.name, 'count': item.count})
        .toList();
  }

  // All unique techniques from the entire gym
  Future<List<String>> getAllTechniquesFromGym() async {
    try {
      final snapshot = await _firestore.collectionGroup('journal').get();

      final all = <String>{};
      for (final doc in snapshot.docs) {
        final techniques = doc.data()['techniques'];
        if (techniques is! Map) continue;

        for (final value in techniques.values) {
          all.addAll(_readStringList(value).map(_normalize));
        }
      }

      all.remove('');
      return all.toList()..sort();
    } catch (e) {
      log('Error fetching gym techniques: $e');
      return [];
    }
  }

  // Suggest techniques from gym-wide data
  List<String> suggestTechniques(List<String> allTechniques, String input) {
    if (input.isEmpty) return [];

    final normalized = _normalize(input);

    return allTechniques.where((tech) {
      final techNorm = tech.toLowerCase();
      return techNorm.startsWith(normalized) ||
          _levenshteinDistance(techNorm, normalized) <= 2;
    }).toList();
  }

  int _levenshteinDistance(String s1, String s2) {
    if (s1.isEmpty) return s2.length;
    if (s2.isEmpty) return s1.length;

    final matrix = List.generate(
      s1.length + 1,
          (i) => List.generate(s2.length + 1, (j) => 0),
    );

    for (int i = 0; i <= s1.length; i++) {
      matrix[i][0] = i;
    }
    for (int j = 0; j <= s2.length; j++) {
      matrix[0][j] = j;
    }

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