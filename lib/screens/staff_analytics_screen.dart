import 'package:flutter/material.dart';
import '../config/colors.dart';
import '../models/app_roles.dart';
import '../models/class_history_model.dart';
import '../services/attendance_stats_service.dart';
import '../services/gym_service.dart';
import '../services/staff_analytics_service.dart';
import 'staff_member_list_screen.dart';

/// STAFF ANALYTICS (Phase 1, Step 1): attendance overview and class
/// performance for owners and managers. Opened from the Staff Portal.
class StaffAnalyticsScreen extends StatefulWidget {
  const StaffAnalyticsScreen({super.key});

  @override
  State<StaffAnalyticsScreen> createState() => _StaffAnalyticsScreenState();
}

class _StaffAnalyticsScreenState extends State<StaffAnalyticsScreen> {
  final StaffAnalyticsService _service = StaffAnalyticsService();

  // Created once here, not in build(), so it loads once (and again on
  // pull-to-refresh), not every time the screen rebuilds.
  late Future<StaffAnalytics> _future;

  static const List<String> _weekdayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  void initState() {
    super.initState();
    _future = _service.load();
  }

  Future<void> _refresh() async {
    final next = _service.load();
    setState(() => _future = next);
    await next;
  }

  @override
  Widget build(BuildContext context) {
    // The Staff Portal hides the button for other roles. This is a second
    // check in case the screen is ever opened another way.
    final bool allowed = AppRoles.canViewDashboard(GymService.instance.role);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics'),
        backgroundColor: context.colors.appBar,
      ),
      body: !allowed
          ? const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Analytics are for owners and managers.',
            textAlign: TextAlign.center,
          ),
        ),
      )
          : FutureBuilder<StaffAnalytics>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _message('Could not load analytics.\n${snapshot.error}');
          }
          return RefreshIndicator(
            onRefresh: _refresh,
            child: _buildContent(snapshot.data!),
          );
        },
      ),
    );
  }

  Widget _message(String text) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(text, textAlign: TextAlign.center),
      ),
    );
  }

  Widget _buildContent(StaffAnalytics a) {
    final theme = Theme.of(context);

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Last ${StaffAnalyticsService.weeksShown} weeks · pull down to refresh',
          style: theme.textTheme.bodySmall?.copyWith(color: context.colors.textMuted),
        ),
        const SizedBox(height: 16),

        // ---------- Attendance overview ----------
        _sectionHeader('Attendance'),
        // MEMBER LISTS: tap a tile to see who's behind the number
        Row(
          children: [
            _statTile('This week', '${a.thisWeek}', _weekChange(a.thisWeek, a.lastWeek),
                onTap: () => _openList('Check-ins this week', a.thisWeekRecords, byMember: false)),
            _statTile('This month', '${a.thisMonth}', 'check-ins',
                onTap: () => _openList('Check-ins this month', a.thisMonthRecords, byMember: false)),
          ],
        ),
        Row(
          children: [
            _statTile('Members this week', '${a.membersThisWeek}', 'trained at least once',
                onTap: () => _openList('Members this week', a.thisWeekRecords, byMember: true)),
            _statTile('Members this month', '${a.membersThisMonth}', 'trained at least once',
                onTap: () => _openList('Members this month', a.thisMonthRecords, byMember: true)),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'No-show rate: ${(a.noShowRate * 100).toStringAsFixed(0)}% of reviewed sign-ups',
          style: theme.textTheme.bodyMedium,
        ),
        if (a.unreviewed > 0) ...[
          const SizedBox(height: 4),
          Text(
            '${a.unreviewed} past ${a.unreviewed == 1 ? 'sign-up hasn\'t' : 'sign-ups haven\'t'} been reviewed yet. They count as attended until marked.',
            style: theme.textTheme.bodySmall?.copyWith(color: AppColors.warning),
          ),
        ],
        const SizedBox(height: 24),

        _subHeader('Check-ins per week'),
        _weeklyBars(a),
        const SizedBox(height: 24),

        _subHeader('Busiest days (average per week)'),
        _weekdayBars(a.avgByWeekday),
        const SizedBox(height: 32),

        // ---------- Class performance ----------
        _sectionHeader('Classes'),
        Text(
          'Busiest first. Average is per session that had sign-ups.',
          style: theme.textTheme.bodySmall?.copyWith(color: context.colors.textMuted),
        ),
        const SizedBox(height: 12),
        if (a.classes.isEmpty)
          const Text('No class attendance in this period yet.')
        else
          ...a.classes.map(_classCard),
        if (a.emptyClasses.isNotEmpty) ...[
          const SizedBox(height: 16),
          _subHeader('No attendance in ${StaffAnalyticsService.weeksShown} weeks'),
          ...a.emptyClasses.map((c) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text('• ${c.className} – ${c.day} ${c.startTime}'),
          )),
        ],
        const SizedBox(height: 24),
      ],
    );
  }

  /// "+5 vs last week", "-3 vs last week", "same as last week"
  String _weekChange(int thisWeek, int lastWeek) {
    final diff = thisWeek - lastWeek;
    if (diff == 0) return 'same as last week ($lastWeek)';
    final sign = diff > 0 ? '+' : '';
    return '$sign$diff vs last week ($lastWeek)';
  }

  // ---------- Widgets ----------

  Widget _sectionHeader(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _subHeader(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }

  void _openList(String title, List<ClassHistoryRecord> records, {required bool byMember}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StaffMemberListScreen(title: title, records: records, byMember: byMember),
      ),
    );
  }

  /// Half-width card that shares the row evenly. MEMBER LISTS: tappable
  /// when [onTap] is given, with a small arrow so it looks tappable.
  Widget _statTile(String title, String value, String subtitle, {VoidCallback? onTap}) {
    final theme = Theme.of(context);
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                border: Border.all(color: theme.dividerColor),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(title, style: theme.textTheme.labelMedium)),
                      if (onTap != null)
                        Icon(Icons.chevron_right, size: 18, color: context.colors.textMuted),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    value,
                    style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(color: context.colors.textMuted),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Simple vertical bar chart: one bar per week, oldest on the left.
  Widget _weeklyBars(StaffAnalytics a) {
    const double maxBarHeight = 120;
    final int maxValue = a.weeklyTotals.fold(0, (m, v) => v > m ? v : m);
    final theme = Theme.of(context);

    return SizedBox(
      height: maxBarHeight + 44,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (int i = 0; i < a.weeklyTotals.length; i++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text('${a.weeklyTotals[i]}', style: theme.textTheme.labelSmall),
                    const SizedBox(height: 4),
                    Container(
                      height: maxValue == 0
                          ? 2.0
                          : (a.weeklyTotals[i] / maxValue * maxBarHeight).clamp(2.0, maxBarHeight),
                      decoration: BoxDecoration(
                        // The current week is still in progress, so it's lighter
                        color: i == a.weeklyTotals.length - 1
                            ? context.colors.primary.withValues(alpha: 0.4)
                            : context.colors.primary,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 4),
                    FittedBox(
                      child: Text(
                        AttendanceStats.monthDay(a.weekStarts[i]),
                        style: theme.textTheme.labelSmall?.copyWith(color: context.colors.textMuted),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Horizontal bars, Monday to Sunday.
  Widget _weekdayBars(List<double> averages) {
    final double maxValue = averages.fold(0.0, (m, v) => v > m ? v : m);
    final theme = Theme.of(context);

    return Column(
      children: [
        for (int i = 0; i < 7; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                SizedBox(width: 40, child: Text(_weekdayNames[i])),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: maxValue == 0 ? 0 : averages[i] / maxValue,
                      minHeight: 18,
                      backgroundColor: theme.dividerColor,
                      valueColor: AlwaysStoppedAnimation<Color>(context.colors.primary),
                    ),
                  ),
                ),
                SizedBox(
                  width: 44,
                  child: Text(
                    averages[i].toStringAsFixed(1),
                    textAlign: TextAlign.right,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _classCard(ClassPerformance c) {
    final theme = Theme.of(context);
    final double fill = c.fillRate.clamp(0.0, 1.0);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  c.className,
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              Text(
                '${c.avgPerSession.toStringAsFixed(1)} avg',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: context.colors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text('${c.day} ${c.startTime}', style: theme.textTheme.bodySmall),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: fill,
              minHeight: 8,
              backgroundColor: theme.dividerColor,
              valueColor: AlwaysStoppedAnimation<Color>(context.colors.primary),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${(c.fillRate * 100).toStringAsFixed(0)}% full (cap ${c.capacity}) · '
                '${c.sessions} ${c.sessions == 1 ? 'session' : 'sessions'} · '
                '${(c.noShowRate * 100).toStringAsFixed(0)}% no-shows',
            style: theme.textTheme.bodySmall?.copyWith(color: context.colors.textMuted),
          ),
        ],
      ),
    );
  }
}