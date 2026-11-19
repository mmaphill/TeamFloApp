import 'package:flutter/material.dart';
import '../config/colors.dart';
import '../models/class_history_model.dart';
import '../services/attendance_stats_service.dart';
import '../services/staff_analytics_service.dart';
import 'member_profile_screen.dart';

/// MEMBER LISTS: opened by tapping a tile on the staff Analytics screen.
///
/// Two layouts:
///  - byMember: true  -> one row per person, with how many classes they came to
///                       (the "Members this week/month" tiles)
///  - byMember: false -> one row per check-in, newest first
///                       (the "This week/month" check-in tiles)
/// Tapping a person opens their member profile.
class StaffMemberListScreen extends StatefulWidget {
  final String title;
  final List<ClassHistoryRecord> records;
  final bool byMember;

  const StaffMemberListScreen({
    super.key,
    required this.title,
    required this.records,
    required this.byMember,
  });

  @override
  State<StaffMemberListScreen> createState() => _StaffMemberListScreenState();
}

class _StaffMemberListScreenState extends State<StaffMemberListScreen> {
  final StaffAnalyticsService _service = StaffAnalyticsService();
  late final Future<Map<String, MemberSummary>> _membersFuture;

  @override
  void initState() {
    super.initState();
    _membersFuture = _service.loadMembers(widget.records.map((r) => r.userId).toSet());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: context.colors.appBar,
      ),
      body: widget.records.isEmpty
          ? const Center(child: Text('No check-ins in this period yet.'))
          : FutureBuilder<Map<String, MemberSummary>>(
        future: _membersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Could not load members.\n${snapshot.error}'));
          }
          final members = snapshot.data ?? {};
          return widget.byMember ? _memberList(members) : _checkInList(members);
        },
      ),
    );
  }

  // ---------- One row per person ----------

  Widget _memberList(Map<String, MemberSummary> members) {
    // Group check-ins by person
    final Map<String, List<ClassHistoryRecord>> byUser = {};
    for (final r in widget.records) {
      byUser.putIfAbsent(r.userId, () => []).add(r);
    }

    // Most classes first, then by name
    final userIds = byUser.keys.toList()
      ..sort((a, b) {
        final byCount = byUser[b]!.length.compareTo(byUser[a]!.length);
        if (byCount != 0) return byCount;
        return _nameOf(members, a).toLowerCase().compareTo(_nameOf(members, b).toLowerCase());
      });

    return ListView.separated(
      itemCount: userIds.length + 1,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        if (index == 0) return _countHeader('${userIds.length} ${userIds.length == 1 ? 'member' : 'members'}');

        final userId = userIds[index - 1];
        final records = byUser[userId]!; // already newest first
        final count = records.length;

        return ListTile(
          leading: _avatar(members[userId]),
          title: Text(_nameOf(members, userId)),
          subtitle: Text('Last class: ${_shortDate(records.first)}'),
          trailing: Text(
            '$count ${count == 1 ? 'class' : 'classes'}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          onTap: () => MemberProfileScreen.open(context, userId),
        );
      },
    );
  }

  // ---------- One row per check-in ----------

  Widget _checkInList(Map<String, MemberSummary> members) {
    final records = widget.records; // already newest first

    return ListView.separated(
      itemCount: records.length + 1,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        if (index == 0) return _countHeader('${records.length} ${records.length == 1 ? 'check-in' : 'check-ins'}');

        final r = records[index - 1];
        return ListTile(
          leading: _avatar(members[r.userId]),
          title: Text(_nameOf(members, r.userId)),
          subtitle: Text('${r.className} · ${_shortDate(r)} ${r.startTime}'),
          trailing: _statusIcon(r),
          onTap: () => MemberProfileScreen.open(context, r.userId),
        );
      },
    );
  }

  // ---------- Helpers ----------

  String _nameOf(Map<String, MemberSummary> members, String userId) =>
      members[userId]?.name ?? 'Unknown member';

  String _shortDate(ClassHistoryRecord r) {
    final day = r.sessionDay;
    return day == null ? r.sessionDate : AttendanceStats.shortDate(day);
  }

  Widget _countHeader(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(color: context.colors.textMuted),
      ),
    );
  }

  Widget _avatar(MemberSummary? member) {
    final String name = member?.name ?? '?';
    final String? photo = member?.photoUrl;
    final bool hasPhoto = photo != null && photo.isNotEmpty;

    return CircleAvatar(
      backgroundImage: hasPhoto ? NetworkImage(photo) : null,
      backgroundColor: hasPhoto ? null : AppColors.neutral,
      child: hasPhoto
          ? null
          : Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: const TextStyle(color: AppColors.onPrimary, fontWeight: FontWeight.bold),
      ),
    );
  }

  /// Green check: an instructor confirmed it.
  /// Clock: a past sign-up nobody has reviewed yet (still counted).
  Widget _statusIcon(ClassHistoryRecord r) {
    if (r.status == AttendanceStatus.attended) {
      return const Icon(Icons.check_circle, color: AppColors.success);
    }
    return const Tooltip(
      message: 'Not reviewed yet',
      child: Icon(Icons.schedule, color: AppColors.warning),
    );
  }
}