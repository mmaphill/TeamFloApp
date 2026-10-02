import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/class_history_model.dart';
import '../models/class_schedule_model.dart';
import '../services/attendance_stats_service.dart';
import '../services/schedule_service.dart';
import '../utils/log.dart';

class HomeAttendanceCard extends StatefulWidget {
  const HomeAttendanceCard({super.key});

  @override
  State<HomeAttendanceCard> createState() => _HomeAttendanceCardState();
}

class _HomeAttendanceCardState extends State<HomeAttendanceCard> {
  final ScheduleService _scheduleService = ScheduleService();
  final User _currentUser = FirebaseAuth.instance.currentUser!;

  StreamSubscription<List<ClassHistoryRecord>>? _historySubscription;
  StreamSubscription<List<ClassSchedule>>? _classesSubscription;

  AttendanceStats? _stats;
  ClassSchedule? _nextGymClass;
  bool _isBusy = false;

  @override
  void initState() {
    super.initState();

    // Member's own history (streak, hours, next class)
    _historySubscription = _scheduleService
        .getUserHistoryStream(_currentUser.uid)
        .listen((records) {
      if (!mounted) return;
      setState(() => _stats = AttendanceStats.fromRecords(records));
    }, onError: (e) {
      log('Home: error loading attendance history: $e');
    });

    // Next class at the gym (shown when the member isn't signed up for anything)
    _classesSubscription = _scheduleService.getUpcomingClassesStream().listen((classes) {
      if (!mounted) return;
      final adultClasses =
      classes.where((c) => !c.classType.toLowerCase().contains('kids')).toList();
      setState(() => _nextGymClass = adultClasses.isEmpty ? null : adultClasses.first);
    }, onError: (e) {
      log('Home: error loading upcoming classes: $e');
    });
  }

  @override
  void dispose() {
    _historySubscription?.cancel();
    _classesSubscription?.cancel();
    super.dispose();
  }

  // ---------- Actions ----------

  Future<void> _leave(ClassHistoryRecord record) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Leave class?'),
        content: Text('You will be removed from ${record.className}.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Leave', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _isBusy = true);
    final error = await _scheduleService.unmarkAttendance(record.classId, _currentUser.uid);
    if (!mounted) return;
    setState(() => _isBusy = false);

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  Future<void> _join(ClassSchedule classSchedule) async {
    setState(() => _isBusy = true);
    final error = await _scheduleService.joinClass(classSchedule.classId, _currentUser.uid);
    if (!mounted) return;
    setState(() => _isBusy = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error ?? "You're in! See you ${classSchedule.day}."),
      ),
    );
  }

  // ---------- UI ----------

  @override
  Widget build(BuildContext context) {
    final stats = _stats;
    if (stats == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStreakRow(stats),
          const SizedBox(height: 12),
          if (stats.upcoming.isNotEmpty)
            _buildMyNextClass(stats.upcoming.first)
          else if (_nextGymClass != null)
            _buildSuggestedClass(_nextGymClass!),
        ],
      ),
    );
  }

  Widget _buildStreakRow(AttendanceStats stats) {
    final bool hasStreak = stats.streakWeeks > 0;
    return Row(
      children: [
        Expanded(
          child: _pill(
            icon: Icons.local_fire_department,
            iconColor: Colors.orange,
            title: hasStreak ? '${stats.streakWeeks}-week streak' : 'Start a streak',
            subtitle: hasStreak ? 'keep it going' : 'train this week',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _pill(
            icon: Icons.timer_outlined,
            iconColor: Theme.of(context).primaryColor,
            title: '${stats.matHoursThisMonth.toStringAsFixed(1)} mat hrs',
            subtitle: 'this month',
          ),
        ),
      ],
    );
  }

  Widget _pill({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        border: Border.all(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMyNextClass(ClassHistoryRecord record) {
    final DateTime? day = record.sessionDay;
    final String dateText = day == null ? record.day : AttendanceStats.shortDate(day);

    return _classCard(
      label: 'Your next class',
      title: record.className,
      details: '$dateText · ${record.startTime} – ${record.endTime}',
      action: OutlinedButton(
        onPressed: _isBusy ? null : () => _leave(record),
        child: const Text('Leave'),
      ),
    );
  }

  Widget _buildSuggestedClass(ClassSchedule classSchedule) {
    final theme = Theme.of(context);
    return _classCard(
      label: 'Next at the gym',
      title: classSchedule.className,
      details:
      '${classSchedule.day}, ${classSchedule.sessionDateLabel} · ${classSchedule.startTime} – ${classSchedule.endTime}',
      action: ElevatedButton(
        onPressed: _isBusy ? null : () => _join(classSchedule),
        style: ElevatedButton.styleFrom(
          backgroundColor: theme.primaryColor,
          foregroundColor: Colors.white,
        ),
        child: const Text('Join'),
      ),
    );
  }

  Widget _classCard({
    required String label,
    required String title,
    required String details,
    required Widget action,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        border: Border.all(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: theme.textTheme.labelSmall?.copyWith(
                    letterSpacing: 1,
                    color: theme.textTheme.labelSmall?.color?.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(details, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          const SizedBox(width: 12),
          action,
        ],
      ),
    );
  }
}