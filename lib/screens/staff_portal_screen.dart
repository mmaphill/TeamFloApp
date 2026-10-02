import 'dart:async';
import 'package:flutter/material.dart';
import '../config/colors.dart';
import '../models/class_history_model.dart';
import '../models/class_schedule_model.dart';
import '../services/attendance_stats_service.dart';
import '../services/schedule_service.dart';
import '../services/staff_service.dart';
import '../utils/log.dart';
import 'session_roster_screen.dart';

class StaffPortalScreen extends StatefulWidget {
  const StaffPortalScreen({super.key});

  @override
  State<StaffPortalScreen> createState() => _StaffPortalScreenState();
}

class _StaffPortalScreenState extends State<StaffPortalScreen> {
  static const int _daysBack = 6; // Today + the past 6 days = one week

  final ScheduleService _scheduleService = ScheduleService();
  final StaffService _staffService = StaffService();

  StreamSubscription<List<ClassSchedule>>? _classesSubscription;
  StreamSubscription<List<ClassHistoryRecord>>? _recordsSubscription;

  List<ClassSchedule>? _classes;
  Map<String, List<ClassHistoryRecord>> _recordsBySession = {};
  bool _hasError = false;

  @override
  void initState() {
    super.initState();

    _classesSubscription = _scheduleService.getClassesStream().listen((classes) {
      if (!mounted) return;
      setState(() => _classes = classes);
    }, onError: _onError);

    final now = DateTime.now();
    final from = DateTime(now.year, now.month, now.day - _daysBack);

    _recordsSubscription = _staffService.recordsSinceStream(from).listen((records) {
      if (!mounted) return;
      final Map<String, List<ClassHistoryRecord>> grouped = {};
      for (final r in records) {
        grouped.putIfAbsent('${r.classId}_${r.sessionDate}', () => []).add(r);
      }
      setState(() => _recordsBySession = grouped);
    }, onError: _onError);
  }

  void _onError(Object e) {
    log('Staff portal error: $e');
    if (!mounted) return;
    setState(() => _hasError = true);
  }

  @override
  void dispose() {
    _classesSubscription?.cancel();
    _recordsSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Staff Portal'),
        backgroundColor: AppColors.dark,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_hasError) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Could not load the staff portal. Check that your account has the instructor or admin role.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    if (_classes == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final sessions = StaffService.buildSessions(_classes!, daysBack: _daysBack);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final todaySessions = sessions.where((s) => s.date == today).toList();
    final pastSessions = sessions.where((s) => s.date != today).toList();

    // Unchecked members in classes that have already ended
    int toReview = 0;
    for (final s in sessions) {
      if (!s.hasEnded) continue;
      toReview += _recordsFor(s).where((r) => r.status == AttendanceStatus.signedUp).length;
    }

    // Build the past list with a date header whenever the date changes
    final List<Widget> pastWidgets = [];
    DateTime? currentDate;
    for (final s in pastSessions) {
      if (s.date != currentDate) {
        currentDate = s.date;
        pastWidgets.add(_dateHeader(AttendanceStats.shortDate(s.date)));
      }
      pastWidgets.add(_sessionTile(s));
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (toReview > 0) _reviewBanner(toReview),
        _sectionHeader('Today'),
        if (todaySessions.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('No classes today'),
          )
        else
          ...todaySessions.map(_sessionTile),
        const SizedBox(height: 24),
        _sectionHeader('Past 6 Days'),
        ...pastWidgets,
      ],
    );
  }

  List<ClassHistoryRecord> _recordsFor(PortalSession s) => _recordsBySession[s.key] ?? [];

  // ---------- Widgets ----------

  Widget _reviewBanner(int count) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.15),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.pending_actions, color: Colors.orange),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'You have $count ${count == 1 ? 'member' : 'members'} to review',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _dateHeader(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 8),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w600,
          color: Theme.of(context).textTheme.labelLarge?.color?.withValues(alpha: 0.7),
        ),
      ),
    );
  }

  Widget _sessionTile(PortalSession session) {
    final theme = Theme.of(context);
    final records = _recordsFor(session);
    final present = records.where((r) => r.status == AttendanceStatus.attended).length;
    final pending = records.where((r) => r.status == AttendanceStatus.signedUp).length;
    final c = session.classSchedule;

    final String summary = records.isEmpty
        ? 'No one on the roster'
        : '${records.length} on roster · $present present';

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => SessionRosterScreen(session: session)),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
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
                    c.className,
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text('${c.startTime} – ${c.endTime}', style: theme.textTheme.bodySmall),
                  const SizedBox(height: 2),
                  Text(
                    summary,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _sessionBadge(session, records.isNotEmpty, pending),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }

  Widget _sessionBadge(PortalSession session, bool hasRecords, int pending) {
    if (!session.hasEnded) {
      return _chip(
        session.hasStarted ? 'In progress' : 'Starts ${session.classSchedule.startTime}',
        Colors.grey,
      );
    }
    if (pending > 0) {
      return _chip('$pending to review', Colors.orange);
    }
    if (hasRecords) {
      return const Padding(
        padding: EdgeInsets.only(right: 4),
        child: Icon(Icons.check_circle, color: Colors.green),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _chip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }
}