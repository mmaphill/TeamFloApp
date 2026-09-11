import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/analytics_service.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({Key? key}) : super(key: key);

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  late Future<Map<String, dynamic>> statsFuture;

  @override
  void initState() {
    super.initState();
    statsFuture = _loadStats();
  }

  Future<Map<String, dynamic>> _loadStats() async {
    final analyticsService = AnalyticsService();
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      throw Exception('User not authenticated');
    }

    final journalEntries = await analyticsService.getJournalEntries(uid);
    final userProfile = await analyticsService.getUserProfile(uid);

    final classesThisMonth = analyticsService.getClassesThisMonth(journalEntries);
    final techniques = analyticsService.aggregateTechniques(journalEntries);
    final submissions = analyticsService.aggregateSubmissions(journalEntries);
    final positions = analyticsService.getPositionFrequency(journalEntries);
    final attendanceTrend = analyticsService.getAttendanceTrend(journalEntries);
    final metrics = analyticsService.getAverageMetrics(journalEntries);

    final competitionStats = analyticsService.parseCompetitionStats(userProfile);
    final overallWinRate = analyticsService.calculateOverallWinRate(competitionStats);
    final totalMatches = analyticsService.getTotalMatches(competitionStats);
    final winBreakdown = analyticsService.getWinBreakdown(competitionStats);
    final lossBreakdown = analyticsService.getLossBreakdown(competitionStats);
    final statsByFormat = analyticsService.getStatsByFormat(competitionStats);
    final statsByRank = analyticsService.getStatsByRank(competitionStats);

    return {
      'journalEntries': journalEntries,
      'classesThisMonth': classesThisMonth,
      'techniques': techniques,
      'submissions': (
        totalSubmissions: submissions.totalSubmissions,
        submissionAttempts: submissions.submissionAttempts,
        timesSubmitted: submissions.timesSubmitted,
      ),
      'positions': positions,
      'attendanceTrend': attendanceTrend,
      'metrics': metrics,
      'competitionStats': competitionStats,
      'overallWinRate': overallWinRate,
      'totalMatches': totalMatches,
      'winBreakdown': winBreakdown,
      'lossBreakdown': lossBreakdown,
      'statsByFormat': statsByFormat,
      'statsByRank': statsByRank,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Stats'),
        centerTitle: true,
        elevation: 0,
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: statsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Error loading stats: ${snapshot.error}'),
            );
          }

          final stats = snapshot.data!;
          final classesThisMonth = stats['classesThisMonth'] as int;
          final techniques = stats['techniques'] as Map<String, int>;
          final submissions = stats['submissions'] as ({int totalSubmissions, int submissionAttempts, int timesSubmitted});
          final positions = stats['positions'] as Map<String, int>;
          final attendanceTrend = stats['attendanceTrend'] as List<dynamic>;
          final metrics = stats['metrics'];
          final overallWinRate = stats['overallWinRate'] as double;
          final totalMatches = stats['totalMatches'] as int;
          final winBreakdown = stats['winBreakdown'];
          final lossBreakdown = stats['lossBreakdown'];
          final statsByFormat = stats['statsByFormat'] as Map<String, ({int wins, int losses})>;
          final statsByRank = stats['statsByRank'] as Map<String, ({int wins, int losses})>;

          return RefreshIndicator(
            onRefresh: () async {
              setState(() {
                statsFuture = _loadStats();
              });
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header summary cards
                    _buildSummaryCard(
                      'Classes',
                      '$classesThisMonth',
                      'this month',
                    ),
                    const SizedBox(height: 12),
                    _buildSummaryCard(
                      'Submissions',
                      '${submissions.totalSubmissions}',
                      '${submissions.submissionAttempts} attempted',
                    ),
                    const SizedBox(height: 12),
                    if (totalMatches > 0)
                      _buildSummaryCard(
                        'Win Rate',
                        '${(overallWinRate * 100).toStringAsFixed(0)}%',
                        '($totalMatches matches)',
                      ),
                    const SizedBox(height: 32),

                    // Training Analytics
                    Text(
                      'Training Analytics',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Attendance chart
                    if (attendanceTrend.isNotEmpty)
                      _buildAttendanceChart(attendanceTrend),
                    const SizedBox(height: 24),

                    // Technique breakdown
                    if (techniques.isNotEmpty)
                      _buildTechniqueBreakdown(techniques),
                    const SizedBox(height: 24),

                    // Top positions
                    if (positions.isNotEmpty)
                      _buildTopPositions(positions),
                    const SizedBox(height: 24),

                    // Average metrics
                    _buildAverageMetrics(metrics),
                    const SizedBox(height: 32),

                    // Competition Analytics
                    if (totalMatches > 0) ...[
                      Text(
                        'Competition Analytics',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Win breakdown
                      _buildWinBreakdown(winBreakdown),
                      const SizedBox(height: 24),

                      // Loss breakdown
                      _buildLossBreakdown(lossBreakdown),
                      const SizedBox(height: 24),

                      // Stats by format
                      if (statsByFormat.isNotEmpty)
                        _buildStatsByFormat(statsByFormat),
                      const SizedBox(height: 24),

                      // Stats by rank
                      if (statsByRank.isNotEmpty)
                        _buildStatsByRank(statsByRank),
                    ] else
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 32.0),
                        child: Center(
                          child: Text(
                            'No competition data yet',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, String subtitle) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Theme.of(context).dividerColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.labelMedium,
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

  Widget _buildAttendanceChart(List<dynamic> data) {
    final maxClasses = data.fold<int>(0, (max, item) => item.classCount > max ? item.classCount : max);
    if (maxClasses == 0) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Classes per Week (Last 8 weeks)',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 120,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: data.map((item) {
              final classCount = item.classCount as int;
              final heightFraction = classCount / maxClasses.clamp(1, double.infinity);
              return Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    '${item.classCount}',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: 24,
                    height: 80 * heightFraction.toDouble(),
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'W${data.indexOf(item) + 1}',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontSize: 10,
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildTechniqueBreakdown(Map<String, int> techniques) {
    final total = techniques.values.fold<int>(0, (sum, v) => sum + v);
    if (total == 0) return const SizedBox.shrink();

    // Sort by count descending
    final sorted = techniques.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Techniques Logged',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        ...sorted.map((entry) {
          final label = entry.key;
          final count = entry.value;
          final percentage = total > 0 ? (count / total) : 0.0;

          return Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: Row(
              children: [
                SizedBox(
                  width: 80,
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: percentage,
                      minHeight: 24,
                      backgroundColor: Theme.of(context).dividerColor,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Theme.of(context).primaryColor,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 40,
                  child: Text(
                    '$count',
                    style: Theme.of(context).textTheme.bodySmall,
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ],
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

  Widget _buildAverageMetrics(metrics) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Average Session Metrics',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _buildMetricCard('Energy', metrics.avgEnergy.toStringAsFixed(1)),
            _buildMetricCard('Sleep', metrics.avgSleep.toStringAsFixed(1)),
            _buildMetricCard('Water', metrics.avgWater.toStringAsFixed(1)),
            _buildMetricCard('Food', metrics.avgFood.toStringAsFixed(1)),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricCard(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall,
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWinBreakdown(winBreakdown) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Wins by Method',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildMethodCard('Submission', winBreakdown.submissions, Colors.green),
            _buildMethodCard('Points', winBreakdown.points, Colors.blue),
            _buildMethodCard('Ref Decision', winBreakdown.refDecisions, Colors.orange),
          ],
        ),
      ],
    );
  }

  Widget _buildLossBreakdown(lossBreakdown) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Losses by Method',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildMethodCard('Submission', lossBreakdown.submissions, Colors.red),
            _buildMethodCard('Points', lossBreakdown.points, Colors.blueGrey),
            _buildMethodCard('Ref Decision', lossBreakdown.refDecisions, Colors.deepOrange),
          ],
        ),
      ],
    );
  }

  Widget _buildMethodCard(String label, int count, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Column(
            children: [
              Text(
                '$count',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatsByFormat(Map<String, ({int wins, int losses})> statsByFormat) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Stats by Format',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        ...statsByFormat.entries.map((entry) {
          final format = entry.key;
          final wins = entry.value.wins;
          final losses = entry.value.losses;
          final total = wins + losses;
          final winRate = total > 0 ? (wins / total) : 0.0;

          return Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: Theme.of(context).dividerColor),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      format,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '$wins-$losses',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${(winRate * 100).toStringAsFixed(0)}%',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).primaryColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildStatsByRank(Map<String, ({int wins, int losses})> statsByRank) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Stats by Rank',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        ...statsByRank.entries.map((entry) {
          final rank = entry.key;
          final wins = entry.value.wins;
          final losses = entry.value.losses;
          final total = wins + losses;
          final winRate = total > 0 ? (wins / total) : 0.0;

          return Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: Theme.of(context).dividerColor),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      rank,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '$wins-$losses',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${(winRate * 100).toStringAsFixed(0)}%',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).primaryColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ],
    );
  }
}