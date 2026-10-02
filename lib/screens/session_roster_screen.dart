import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../config/colors.dart';
import '../models/class_history_model.dart';
import '../services/attendance_stats_service.dart';
import '../services/staff_service.dart';
import '../utils/log.dart';

class SessionRosterScreen extends StatefulWidget {
  final PortalSession session;

  const SessionRosterScreen({super.key, required this.session});

  @override
  State<SessionRosterScreen> createState() => _SessionRosterScreenState();
}

class _SessionRosterScreenState extends State<SessionRosterScreen> {
  final StaffService _staffService = StaffService();
  final String _staffUid = FirebaseAuth.instance.currentUser!.uid;

  StreamSubscription<List<ClassHistoryRecord>>? _rosterSubscription;
  List<ClassHistoryRecord>? _records;
  Map<String, StaffMember> _members = {};
  bool _membersLoaded = false;
  bool _isBusy = false;

  @override
  void initState() {
    super.initState();

    _rosterSubscription = _staffService
        .sessionRosterStream(widget.session.classSchedule.classId, widget.session.sessionDate)
        .listen((records) {
      if (!mounted) return;
      setState(() => _records = records);
    }, onError: (e) {
      log('Roster error: $e');
      if (!mounted) return;
      setState(() => _records = []);
    });

    _loadMembers();
  }

  Future<void> _loadMembers() async {
    try {
      final list = await _staffService.loadMembers();
      if (!mounted) return;
      setState(() {
        _members = {for (final m in list) m.uid: m};
        _membersLoaded = true;
      });
    } catch (e) {
      log('Error loading members: $e');
      if (!mounted) return;
      setState(() => _membersLoaded = true);
    }
  }

  @override
  void dispose() {
    _rosterSubscription?.cancel();
    super.dispose();
  }

  String _nameFor(String uid) {
    final member = _members[uid];
    if (member != null) return member.name;
    return _membersLoaded ? 'Former member' : 'Loading…';
  }

  // ---------- Actions ----------

  Future<void> _runAction(Future<String?> Function() action, {String? successMessage}) async {
    setState(() => _isBusy = true);
    final error = await action();
    if (!mounted) return;
    setState(() => _isBusy = false);

    final message = error ?? successMessage;
    if (message != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  void _setStatus(ClassHistoryRecord record, String status) {
    _runAction(() => _staffService.setStatus(record.id, status, _staffUid));
  }

  void _markAllPresent() {
    final records = _records ?? [];
    _runAction(
          () => _staffService.markAllPresent(records, _staffUid),
      successMessage: 'Everyone marked present',
    );
  }

  Future<void> _removeWalkIn(ClassHistoryRecord record) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove walk-in?'),
        content: Text('${_nameFor(record.userId)} will be removed from this class.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    _runAction(() => _staffService.removeRecord(record.id));
  }

  Future<void> _addWalkIn() async {
    if (!_membersLoaded) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Still loading members, try again in a moment')),
      );
      return;
    }

    // Hide people who are already on the roster
    final onRoster = (_records ?? []).map((r) => r.userId).toSet();
    final available = _members.values.where((m) => !onRoster.contains(m.uid)).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    final picked = await showModalBottomSheet<StaffMember>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _WalkInPicker(members: available),
    );
    if (picked == null) return;

    _runAction(
          () => _staffService.addWalkIn(widget.session, picked.uid, _staffUid),
      successMessage: 'Added ${picked.name}',
    );
  }

  // ---------- UI ----------

  @override
  Widget build(BuildContext context) {
    final c = widget.session.classSchedule;

    return Scaffold(
      appBar: AppBar(
        title: Text(c.className),
        backgroundColor: AppColors.dark,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isBusy ? null : _addWalkIn,
        icon: const Icon(Icons.person_add),
        label: const Text('Add walk-in'),
      ),
      body: _records == null
          ? const Center(child: CircularProgressIndicator())
          : _buildRoster(),
    );
  }

  Widget _buildRoster() {
    final theme = Theme.of(context);
    final c = widget.session.classSchedule;
    final records = List<ClassHistoryRecord>.from(_records!)
      ..sort((a, b) => _nameFor(a.userId).toLowerCase().compareTo(_nameFor(b.userId).toLowerCase()));

    final present = records.where((r) => r.status == AttendanceStatus.attended).length;
    final absent = records.where((r) => r.status == AttendanceStatus.noShow).length;
    final pending = records.where((r) => r.status == AttendanceStatus.signedUp).length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96), // Room for the button
      children: [
        Text(
          '${AttendanceStats.shortDate(widget.session.date)} · ${c.startTime} – ${c.endTime}',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),

        Row(
          children: [
            Expanded(child: _countTile('Present', present, Colors.green)),
            const SizedBox(width: 8),
            Expanded(child: _countTile('Absent', absent, Colors.red)),
            const SizedBox(width: 8),
            Expanded(child: _countTile('Not checked', pending, Colors.orange)),
          ],
        ),
        const SizedBox(height: 16),

        if (pending > 0) ...[
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _isBusy ? null : _markAllPresent,
              icon: const Icon(Icons.done_all),
              label: Text('Mark all $pending present'),
            ),
          ),
          const SizedBox(height: 16),
        ],

        if (records.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Text(
              'No one signed up for this class. Use "Add walk-in" to record who came.',
              textAlign: TextAlign.center,
            ),
          )
        else
          ...records.map(_rosterRow),
      ],
    );
  }

  Widget _countTile(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(
            '$count',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color),
          ),
          Text(label, style: TextStyle(fontSize: 12, color: color)),
        ],
      ),
    );
  }

  Widget _rosterRow(ClassHistoryRecord record) {
    final theme = Theme.of(context);
    final member = _members[record.userId];
    final name = _nameFor(record.userId);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundImage: member?.photoUrl != null ? NetworkImage(member!.photoUrl!) : null,
            child: member?.photoUrl == null
                ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?')
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                if (record.walkIn)
                  Text(
                    'Walk-in · Present',
                    style: theme.textTheme.bodySmall?.copyWith(color: Colors.green),
                  ),
              ],
            ),
          ),
          if (record.walkIn)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Remove walk-in',
              onPressed: _isBusy ? null : () => _removeWalkIn(record),
            )
          else ...[
            _statusChip(record, AttendanceStatus.attended, 'Present', Icons.check, Colors.green),
            const SizedBox(width: 6),
            _statusChip(record, AttendanceStatus.noShow, 'Absent', Icons.close, Colors.red),
          ],
        ],
      ),
    );
  }

  /// Tapping the selected chip again clears it back to "not checked".
  Widget _statusChip(
      ClassHistoryRecord record,
      String status,
      String label,
      IconData icon,
      Color color,
      ) {
    final bool selected = record.status == status;
    return ChoiceChip(
      showCheckmark: false,
      avatar: Icon(icon, size: 16, color: selected ? Colors.white : color),
      label: Text(label),
      labelStyle: TextStyle(color: selected ? Colors.white : null, fontSize: 12),
      selected: selected,
      selectedColor: color,
      onSelected: _isBusy
          ? null
          : (_) => _setStatus(record, selected ? AttendanceStatus.signedUp : status),
    );
  }
}

/// Bottom sheet with a search box for picking a walk-in member.
class _WalkInPicker extends StatefulWidget {
  final List<StaffMember> members;

  const _WalkInPicker({required this.members});

  @override
  State<_WalkInPicker> createState() => _WalkInPickerState();
}

class _WalkInPickerState extends State<_WalkInPicker> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final filtered = _query.isEmpty
        ? widget.members
        : widget.members
        .where((m) => m.name.toLowerCase().contains(_query.toLowerCase()))
        .toList();

    return Padding(
      // Keeps the list above the keyboard
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Add walk-in',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search members',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) => setState(() => _query = value.trim()),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: filtered.isEmpty
                  ? const Center(child: Text('No members found'))
                  : ListView.builder(
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final m = filtered[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundImage:
                      m.photoUrl != null ? NetworkImage(m.photoUrl!) : null,
                      child: m.photoUrl == null
                          ? Text(m.name.isNotEmpty ? m.name[0].toUpperCase() : '?')
                          : null,
                    ),
                    title: Text(m.name),
                    onTap: () => Navigator.pop(context, m),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}