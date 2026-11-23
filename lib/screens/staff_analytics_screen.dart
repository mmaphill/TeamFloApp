import 'package:flutter/material.dart';
import '../config/colors.dart';
import '../models/app_roles.dart';
import '../models/class_history_model.dart';
import '../services/attendance_stats_service.dart';
import '../services/gym_service.dart';
import '../services/staff_analytics_service.dart';
import 'member_profile_screen.dart';
import 'staff_member_list_screen.dart';

/// STAFF ANALYTICS (Phase 1): attendance overview and class performance
/// (Step 1), member activity and membership growth (Step 2), for owners
/// and managers. Opened from the Staff Portal.
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

  // STEP 2: the most recent loaded data, for buttons outside the builder
  StaffAnalytics? _latest;

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
          _latest = snapshot.data;
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
          'Pull down to refresh',
          style: theme.textTheme.bodySmall?.copyWith(color: context.colors.textMuted),
        ),
        const SizedBox(height: 16),

        // ---------- STEP 2: Members ----------
        _sectionHeader('Members'),
        Row(
          children: [
            _statTile('Total members', '${a.memberCount}',
                '+ ${a.staffCount} staff'),
            _statTile('Active', '${a.activeCount}',
                'trained in last ${StaffAnalytics.activeDays} days',
                onTap: () => _openList(
                    'Active members', a.activeRecords, byMember: true)),
          ],
        ),
        Row(
          children: [
            _statTile('Watch list', '${a.watchList.length}',
                'no class in ${StaffAnalytics.activeDays}+ days',
                onTap: _openWatchList),
            _statTile('New this month', '${a.newThisMonth}', 'joined the gym'),
          ],
        ),
        const SizedBox(height: 16),

        // Watch list preview: the 5 most recently lapsed
        if (a.watchList.isNotEmpty) ...[
          _subHeader('Watch list'),
          ...a.watchList.take(5).map((w) => _watchTile(w)),
          if (a.watchList.length > 5)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: _openWatchList,
                child: Text('See all ${a.watchList.length}'),
              ),
            ),
          const SizedBox(height: 24),
        ],

        _subHeader('New members per month'),
        _columnBars(
          a.newMembersByMonth,
          a.monthStarts.map(_monthLabel).toList(),
        ),
        if (a.unknownJoinDate > 0) ...[
          const SizedBox(height: 4),
          Text(
            '${a.unknownJoinDate} ${a.unknownJoinDate == 1 ? 'member has' : 'members have'} no join date recorded and ${a.unknownJoinDate == 1 ? 'isn\'t' : 'aren\'t'} counted here.',
            style: theme.textTheme.bodySmall?.copyWith(color: context.colors.textMuted),
          ),
        ],
        const SizedBox(height: 24),

        _subHeader('Belt ranks'),
        if (a.beltCounts.isEmpty)
          const Text('No members yet.')
        else
          _beltBars(a.beltCounts),
        const SizedBox(height: 32),

        // ---------- Attendance overview ----------
        _sectionHeader('Attendance'),
        Text(
          'Last ${StaffAnalyticsService.weeksShown} weeks',
          style: theme.textTheme.bodySmall?.copyWith(color: context.colors.textMuted),
        ),
        const SizedBox(height: 16),
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

  /// One bar per week, oldest on the left.
  Widget _weeklyBars(StaffAnalytics a) {
    return _columnBars(
      a.weeklyTotals,
      a.weekStarts.map(AttendanceStats.monthDay).toList(),
    );
  }

  static const List<String> _monthNames = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];

  String _monthLabel(DateTime d) => _monthNames[d.month - 1];

  /// STEP 2: simple vertical bar chart (was only for weeks, now shared with
  /// the new members chart). The last bar is lighter because that week or
  /// month is still in progress.
  Widget _columnBars(List<int> values, List<String> labels) {
    const double maxBarHeight = 120;
    final int maxValue = values.fold(0, (m, v) => v > m ? v : m);
    final theme = Theme.of(context);

    return SizedBox(
      height: maxBarHeight + 44,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (int i = 0; i < values.length; i++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text('${values[i]}', style: theme.textTheme.labelSmall),
                    const SizedBox(height: 4),
                    Container(
                      height: maxValue == 0
                          ? 2.0
                          : (values[i] / maxValue * maxBarHeight).clamp(2.0, maxBarHeight),
                      decoration: BoxDecoration(
                        color: i == values.length - 1
                            ? context.colors.primary.withValues(alpha: 0.4)
                            : context.colors.primary,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 4),
                    FittedBox(
                      child: Text(
                        labels[i],
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

  /// STEP 2: horizontal bars, one per belt, most common first.
  Widget _beltBars(List<MapEntry<String, int>> counts) {
    final int maxValue = counts.fold(0, (m, e) => e.value > m ? e.value : m);
    final theme = Theme.of(context);

    return Column(
      children: [
        for (final e in counts)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                SizedBox(
                  width: 90,
                  child: Text(e.key, overflow: TextOverflow.ellipsis),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: maxValue == 0 ? 0 : e.value / maxValue,
                      minHeight: 18,
                      backgroundColor: theme.dividerColor,
                      valueColor: AlwaysStoppedAnimation<Color>(context.colors.primary),
                    ),
                  ),
                ),
                SizedBox(
                  width: 44,
                  child: Text('${e.value}', textAlign: TextAlign.right, style: theme.textTheme.bodySmall),
                ),
              ],
            ),
          ),
      ],
    );
  }

  // ---------- STEP 2: watch list ----------

  void _openWatchList() {
    final data = _latest;
    if (data == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => _WatchListScreen(watchList: data.watchList)),
    );
  }

  Widget _watchTile(MemberActivity w) => _WatchListScreen.tile(context, w);

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

/// STEP 2: the full watch list. Members who haven't trained in 14+ days,
/// most recently lapsed first, then those with no classes in 8 weeks.
/// Tap a member to open their profile.
class _WatchListScreen extends StatelessWidget {
  final List<MemberActivity> watchList;

  const _WatchListScreen({required this.watchList});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Watch list'),
        backgroundColor: context.colors.appBar,
      ),
      body: watchList.isEmpty
          ? const Center(child: Text('Everyone has trained recently.'))
          : ListView.separated(
        itemCount: watchList.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) => tile(context, watchList[index]),
      ),
    );
  }

  /// One row. Also used for the 5-row preview on the Analytics screen.
  static Widget tile(BuildContext context, MemberActivity w) {
    final m = w.member;
    final bool hasPhoto = m.photoUrl != null && m.photoUrl!.isNotEmpty;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: CircleAvatar(
        backgroundImage: hasPhoto ? NetworkImage(m.photoUrl!) : null,
        backgroundColor: hasPhoto ? null : AppColors.neutral,
        child: hasPhoto
            ? null
            : Text(
          m.name.isNotEmpty ? m.name[0].toUpperCase() : '?',
          style: const TextStyle(color: AppColors.onPrimary, fontWeight: FontWeight.bold),
        ),
      ),
      title: Text(m.name),
      subtitle: Text(_description(w)),
      trailing: m.belt == null ? null : Text(m.belt!, style: Theme.of(context).textTheme.bodySmall),
      onTap: () => MemberProfileScreen.open(context, m.id),
    );
  }

  static String _description(MemberActivity w) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (w.lastClass != null) {
      final days = today.difference(w.lastClass!).inDays;
      return 'Last class ${AttendanceStats.shortDate(w.lastClass!)} · $days days ago';
    }

    // No classes in the 8 weeks. Say so differently for brand-new members.
    final joined = w.member.joined;
    if (joined != null) {
      final joinedDay = DateTime(joined.year, joined.month, joined.day);
      final firstWeek = StaffAnalytics.firstWeekStart(now);
      if (!joinedDay.isBefore(firstWeek)) {
        return 'Joined ${AttendanceStats.monthDay(joinedDay)} · no classes yet';
      }
    }
    return 'No classes in ${StaffAnalyticsService.weeksShown}+ weeks';
  }
}