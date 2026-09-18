import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/analytics_service.dart';

class StatsHighlightsWidget extends StatefulWidget {
  const StatsHighlightsWidget({super.key});

  @override
  State<StatsHighlightsWidget> createState() => _StatsHighlightsWidgetState();
}

class _StatsHighlightsWidgetState extends State<StatsHighlightsWidget> {
  late Future<Map<String, dynamic>> statsFuture;

  @override
  void initState() {
    super.initState();
    statsFuture = _loadStats();
  }

  Future<Map<String, dynamic>> _loadStats() async {
    try {
      return await _loadStatsInternal().timeout(
        Duration(seconds: 3),
        onTimeout: () {
          print('⏱Stats loading timed out after 3 seconds');
          return _emptyStats();
        },
      );
    } catch (e) {
      print('Error loading stats: $e');
      return _emptyStats();
    }
  }

  Future<Map<String, dynamic>> _loadStatsInternal() async {
    final analyticsService = AnalyticsService();
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      throw Exception('User not authenticated');
    }

    final journalEntries = await analyticsService.getJournalEntries(uid);
    final userProfile = await analyticsService.getUserProfile(uid);
    final positions = await analyticsService.getPositionFrequency(journalEntries);
    final classesThisMonth = analyticsService.getClassesThisMonth(journalEntries);
    final submissions = analyticsService.aggregateSubmissions(journalEntries);
    final types = analyticsService.aggregateTypes(journalEntries);
    final competitionStats = analyticsService.parseCompetitionStats(userProfile);
    final overallWinRate = analyticsService.calculateOverallWinRate(competitionStats);
    final totalMatches = analyticsService.getTotalMatches(competitionStats);

    return {
      'classesThisMonth': classesThisMonth,
      'submissions': (
      totalSubmissions: submissions.totalSubmissions,
      submissionAttempts: submissions.submissionAttempts,
      timesSubmitted: submissions.timesSubmitted,
      ),
      'types': types,
      'positions': positions,
      'overallWinRate': overallWinRate,
      'totalMatches': totalMatches,
    };
  }

  Map<String, dynamic> _emptyStats() {
    return {
      'classesThisMonth': 0,
      'submissions': (
      totalSubmissions: 0,
      submissionAttempts: 0,
      timesSubmitted: 0,
      ),
      'types': <String, int>{},
      'positions': <String, int>{},
      'overallWinRate': 0.0,
      'totalMatches': 0,
    };
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: statsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              height: 200,
              child: Center(
                child: CircularProgressIndicator(),
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          return SizedBox.shrink(); // Silently fail, don't disrupt homepage
        }

        if (!snapshot.hasData) {
          return SizedBox.shrink();
        }

        final stats = snapshot.data!;
        final classesThisMonth = stats['classesThisMonth'] as int;
        final submissions = stats['submissions'] as ({int totalSubmissions, int submissionAttempts, int timesSubmitted});
        final types = stats['types'] as Map<String, int>;
        final positions = stats['positions'] as Map<String, int>;
        final overallWinRate = stats['overallWinRate'] as double;
        final totalMatches = stats['totalMatches'] as int;

        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Text(
                'Training Stats',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),

              // Summary Cards Row
              Row(
                children: [
                  Expanded(
                    child: _buildSummaryCard(
                      context,
                      'Classes',
                      '$classesThisMonth',
                      'this month',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildSummaryCard(
                      context,
                      'Submissions',
                      '${submissions.totalSubmissions}',
                      '${submissions.submissionAttempts} attempted',
                    ),
                  ),
                  const SizedBox(width: 12),
                  if (totalMatches > 0)
                    Expanded(
                      child: _buildSummaryCard(
                        context,
                        'Win Rate',
                        '${(overallWinRate * 100).toStringAsFixed(0)}%',
                        '$totalMatches matches',
                      ),
                    )
                  else
                    Expanded(
                      child: _buildSummaryCard(
                        context,
                        'Logged',
                        '${types.values.fold<int>(0, (sum, v) => sum + v)}',
                        'types',
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 24),

              // Top positions
              if (positions.isNotEmpty)
                _buildTopPositions(positions),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSummaryCard(
      BuildContext context,
      String title,
      String value,
      String subtitle,
      ) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Theme.of(context).dividerColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.labelSmall,
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopPositions(Map<String, int> positions) {
    // Get top 5 positions
    final sorted = positions.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final top5 = sorted.take(5).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Top Positions',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: top5.map((entry) {
            return Chip(
              label: Text('${entry.key} (${entry.value})'),
              backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
            );
          }).toList(),
        ),
      ],
    );
  }
}