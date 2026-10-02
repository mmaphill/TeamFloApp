import 'package:flutter/material.dart';
import '../models/class_history_model.dart';
import '../screens/journal_entry_screen.dart';
import '../services/attendance_stats_service.dart';

class AttendanceStatsSection extends StatelessWidget {
  final AttendanceStats stats;
  final String userId;

  const AttendanceStatsSection({
    super.key,
    required this.stats,
    required this.userId,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Text(
            'Attendance',
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 16),

        // Top tiles
        Row(
          children: [
            Expanded(
              child: _statTile(
                context,
                'Streak',
                '${stats.streakWeeks}',
                stats.streakWeeks == 1 ? 'week' : 'weeks',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _statTile(
                context,
                'Mat Hours',
                stats.matHoursThisMonth.toStringAsFixed(1),
                'this month',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _statTile(
                context,
                'All-Time',
                '${stats.totalClasses}',
                '${stats.matHoursTotal.toStringAsFixed(0)} hrs',
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        _buildMilestones(context),
        const SizedBox(height: 24),

        _buildWeeklyChart(context),
        const SizedBox(height: 24),

        if (stats.totalClasses > 0) ...[
          _buildStyleSplit(context),
          const SizedBox(height: 24),
        ],

        if (stats.favoriteSlot != null) ...[
          _buildFavorite(context),
          const SizedBox(height: 24),
        ],

        _buildRecentClasses(context),
      ],
    );
  }

  // ---------- Tiles ----------

  Widget _statTile(BuildContext context, String label, String value, String subtitle) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.labelMedium),
          const SizedBox(height: 8),
          Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(BuildContext context, String text) {
    return Text(
      text,
      style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
    );
  }

  // ---------- Milestones ----------

  Widget _buildMilestones(BuildContext context) {
    final theme = Theme.of(context);
    final int? next = stats.nextMilestone;
    final int previous = stats.lastMilestone;
    final reached = stats.reachedMilestones;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel(context, 'Milestones'),
        const SizedBox(height: 12),
        if (next != null) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${stats.totalClasses} classes',
                style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              Text('Next: $next', style: theme.textTheme.bodySmall),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: ((stats.totalClasses - previous) / (next - previous)).clamp(0.0, 1.0),
              minHeight: 10,
              backgroundColor: theme.dividerColor,
              valueColor: AlwaysStoppedAnimation<Color>(theme.primaryColor),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${next - stats.totalClasses} to go',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6),
            ),
          ),
        ] else
          Text('Every milestone reached. Legend.', style: theme.textTheme.bodyMedium),
        if (reached.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: reached.map((m) {
              return Chip(
                avatar: const Icon(Icons.emoji_events, size: 18, color: Colors.amber),
                label: Text('$m classes'),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  // ---------- Weekly chart ----------

  Widget _buildWeeklyChart(BuildContext context) {
    final theme = Theme.of(context);
    final weeks = stats.lastEightWeeks;
    final int maxCount = weeks.fold<int>(0, (m, w) => w.total > m ? w.total : m);
    const double maxBarHeight = 80;
    final double scale = maxCount == 0 ? 0 : maxBarHeight / maxCount;
    final Color solid = theme.primaryColor;
    final Color light = theme.primaryColor.withValues(alpha: 0.35);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel(context, 'Classes per Week (Last 8 weeks)'),
        const SizedBox(height: 4),
        Text(
          'Tap a week to see its classes',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 130,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: weeks.map((week) {
              return Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _showWeek(context, week),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text('${week.total}', style: theme.textTheme.labelSmall),
                      const SizedBox(height: 4),
                      // Unconfirmed on top (lighter)
                      if (week.unconfirmed > 0)
                        Container(
                          width: 22,
                          height: week.unconfirmed * scale,
                          decoration: BoxDecoration(
                            color: light,
                            borderRadius: week.confirmed == 0
                                ? BorderRadius.circular(4)
                                : const BorderRadius.vertical(top: Radius.circular(4)),
                          ),
                        ),
                      // Confirmed on the bottom (solid)
                      if (week.confirmed > 0)
                        Container(
                          width: 22,
                          height: week.confirmed * scale,
                          decoration: BoxDecoration(
                            color: solid,
                            borderRadius: week.unconfirmed == 0
                                ? BorderRadius.circular(4)
                                : const BorderRadius.vertical(bottom: Radius.circular(4)),
                          ),
                        ),
                      if (week.total == 0)
                        Container(width: 22, height: 2, color: theme.dividerColor),
                      const SizedBox(height: 8),
                      Text(
                        AttendanceStats.monthDay(week.weekStart),
                        style: theme.textTheme.labelSmall?.copyWith(fontSize: 9),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _legendDot(context, solid, 'Confirmed'),
            const SizedBox(width: 16),
            _legendDot(context, light, 'Unconfirmed'),
          ],
        ),
      ],
    );
  }

  void _showWeek(BuildContext context, WeekAttendance week) {
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Week of ${AttendanceStats.monthDay(week.weekStart)}',
                  style: Theme.of(sheetContext).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                if (week.records.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text('No classes this week'),
                  )
                else
                  ...week.records.map((r) => _recordTile(sheetContext, r)),
              ],
            ),
          ),
        );
      },
    );
  }

  // ---------- Gi vs No Gi ----------

  Widget _buildStyleSplit(BuildContext context) {
    final int total = stats.giCount + stats.noGiCount + stats.otherCount;
    final segments = [
      ('Gi', stats.giCount, Theme.of(context).primaryColor),
      ('No Gi', stats.noGiCount, Colors.blueGrey),
      ('Open Mat / Other', stats.otherCount, Colors.grey),
    ].where((s) => s.$2 > 0).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel(context, 'Gi vs No Gi'),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            height: 18,
            child: Row(
              children: segments
                  .map((s) => Expanded(flex: s.$2, child: Container(color: s.$3)))
                  .toList(),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 16,
          runSpacing: 4,
          children: segments
              .map((s) => _legendDot(
            context,
            s.$3,
            '${s.$1} ${(s.$2 * 100 / total).round()}%',
          ))
              .toList(),
        ),
      ],
    );
  }

  // ---------- Favorite time ----------

  Widget _buildFavorite(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(Icons.schedule, color: theme.primaryColor),
        const SizedBox(width: 8),
        Expanded(
          child: Text.rich(
            TextSpan(
              text: 'You train most on ',
              style: theme.textTheme.bodyMedium,
              children: [
                TextSpan(
                  text: stats.favoriteSlot,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ---------- Recent classes ----------

  Widget _buildRecentClasses(BuildContext context) {
    final recent = stats.recent.take(10).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel(context, 'Recent Classes'),
        const SizedBox(height: 8),
        if (recent.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text('No past classes yet. Join one from the Schedule tab.'),
          )
        else
          ...recent.map((r) => _recordTile(context, r)),
      ],
    );
  }

  Widget _recordTile(BuildContext context, ClassHistoryRecord record) {
    final theme = Theme.of(context);

    IconData icon;
    Color color;
    String statusText;

    if (record.status == AttendanceStatus.attended) {
      icon = Icons.check_circle;
      color = Colors.green;
      statusText = record.walkIn ? 'Confirmed · walk-in' : 'Confirmed';
    } else if (record.status == AttendanceStatus.noShow) {
      icon = Icons.cancel;
      color = Colors.red;
      statusText = 'Marked absent';
    } else if (record.isPast) {
      icon = Icons.schedule;
      color = Colors.grey;
      statusText = 'Awaiting confirmation';
    } else {
      icon = Icons.event;
      color = theme.primaryColor;
      statusText = 'Upcoming';
    }

    final DateTime? day = record.sessionDay;
    final String dateText = day == null ? record.day : AttendanceStats.shortDate(day);

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: color),
      title: Text(record.className),
      subtitle: Text('$dateText · ${record.startTime}\n$statusText'),
      isThreeLine: true,
      trailing: (record.countsAsAttended && day != null)
          ? IconButton(
        icon: const Icon(Icons.edit_note),
        tooltip: 'Log this class',
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => JournalEntryScreen(userId: userId, date: day),
            ),
          );
        },
      )
          : null,
    );
  }

  Widget _legendDot(BuildContext context, Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}