import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/class_history_model.dart';
import '../models/class_schedule_model.dart';
import '../utils/log.dart';

/// A member as shown in the staff portal.
class StaffMember {
  final String uid;
  final String name;
  final String? photoUrl;

  StaffMember({required this.uid, required this.name, this.photoUrl});
}

/// One class on one specific date.
class PortalSession {
  final ClassSchedule classSchedule;
  final DateTime date;      // Midnight, local time
  final String sessionDate; // yyyy-MM-dd

  PortalSession(this.classSchedule, this.date)
      : sessionDate = StaffService.dateKey(date);

  /// Matches the start of a classHistory doc ID: {classId}_{sessionDate}
  String get key => '${classSchedule.classId}_$sessionDate';

  DateTime? _timeOnDate(String time) {
    final minutes = ClassSchedule.parseTimeToMinutes(time);
    if (minutes == null) return null;
    return DateTime(date.year, date.month, date.day, minutes ~/ 60, minutes % 60);
  }

  DateTime? get start => _timeOnDate(classSchedule.startTime);
  DateTime? get end => _timeOnDate(classSchedule.endTime);

  bool get hasStarted {
    final s = start;
    return s != null && DateTime.now().isAfter(s);
  }

  bool get hasEnded {
    final e = end;
    return e != null && DateTime.now().isAfter(e);
  }
}

class StaffService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _history =>
      _firestore.collection('classHistory');

  static const List<String> _days = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
  ];

  /// "2026-10-05"
  static String dateKey(DateTime d) {
    final m = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '${d.year}-$m-$dd';
  }

  /// Every class session from [daysBack] days ago through today.
  /// Sorted newest day first, then by start time within a day.
  static List<PortalSession> buildSessions(List<ClassSchedule> classes, {int daysBack = 6}) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final List<PortalSession> sessions = [];

    for (int offset = 0; offset <= daysBack; offset++) {
      final date = DateTime(today.year, today.month, today.day - offset);
      final dayName = _days[date.weekday - 1];
      for (final c in classes) {
        if (c.day == dayName) sessions.add(PortalSession(c, date));
      }
    }

    sessions.sort((a, b) {
      final byDate = b.date.compareTo(a.date);
      if (byDate != 0) return byDate;
      final aStart = ClassSchedule.parseTimeToMinutes(a.classSchedule.startTime) ?? 0;
      final bStart = ClassSchedule.parseTimeToMinutes(b.classSchedule.startTime) ?? 0;
      return aStart.compareTo(bStart);
    });

    return sessions;
  }

  /// All records for sessions on or after [from]. One query for the whole portal.
  Stream<List<ClassHistoryRecord>> recordsSinceStream(DateTime from) {
    return _history
        .where('sessionDate', isGreaterThanOrEqualTo: dateKey(from))
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => ClassHistoryRecord.fromMap(doc.data(), doc.id))
        .toList());
  }

  /// Roster for one class on one date.
  Stream<List<ClassHistoryRecord>> sessionRosterStream(String classId, String sessionDate) {
    return _history
        .where('classId', isEqualTo: classId)
        .where('sessionDate', isEqualTo: sessionDate)
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => ClassHistoryRecord.fromMap(doc.data(), doc.id))
        .toList());
  }

  /// Set a member's status. Setting back to signedUp clears the confirmation.
  Future<String?> setStatus(String recordId, String status, String staffUid) async {
    try {
      if (status == AttendanceStatus.signedUp) {
        await _history.doc(recordId).update({
          'status': status,
          'confirmedBy': FieldValue.delete(),
          'confirmedAt': FieldValue.delete(),
        });
      } else {
        await _history.doc(recordId).update({
          'status': status,
          'confirmedBy': staffUid,
          'confirmedAt': FieldValue.serverTimestamp(),
        });
      }
      return null;
    } catch (e) {
      log('Error setting attendance status: $e');
      return 'Could not update attendance';
    }
  }

  /// Mark every unchecked member present in one write.
  Future<String?> markAllPresent(List<ClassHistoryRecord> records, String staffUid) async {
    final pending = records.where((r) => r.status == AttendanceStatus.signedUp).toList();
    if (pending.isEmpty) return null;

    try {
      final batch = _firestore.batch();
      for (final r in pending) {
        batch.update(_history.doc(r.id), {
          'status': AttendanceStatus.attended,
          'confirmedBy': staffUid,
          'confirmedAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
      return null;
    } catch (e) {
      log('Error marking all present: $e');
      return 'Could not mark everyone present';
    }
  }

  /// Add someone who came without signing up.
  /// If they already have a record for this session, just confirm them.
  Future<String?> addWalkIn(PortalSession session, String userId, String staffUid) async {
    final c = session.classSchedule;
    final ref = _history.doc(ClassHistoryRecord.buildId(c.classId, session.sessionDate, userId));

    try {
      final existing = await ref.get();
      if (existing.exists) {
        await ref.update({
          'status': AttendanceStatus.attended,
          'confirmedBy': staffUid,
          'confirmedAt': FieldValue.serverTimestamp(),
        });
        return null;
      }

      await ref.set({
        'userId': userId,
        'classId': c.classId,
        'sessionDate': session.sessionDate,
        'className': c.className,
        'classType': c.classType,
        'day': c.day,
        'startTime': c.startTime,
        'endTime': c.endTime,
        'durationMinutes': ClassHistoryRecord.calculateDuration(c.startTime, c.endTime),
        'status': AttendanceStatus.attended,
        'walkIn': true,
        'joinedAt': FieldValue.serverTimestamp(),
        'confirmedBy': staffUid,
        'confirmedAt': FieldValue.serverTimestamp(),
      });
      return null;
    } catch (e) {
      log('Error adding walk-in: $e');
      return 'Could not add walk-in';
    }
  }

  /// Delete a record (used for walk-ins added by mistake).
  Future<String?> removeRecord(String recordId) async {
    try {
      await _history.doc(recordId).delete();
      return null;
    } catch (e) {
      log('Error removing attendance record: $e');
      return 'Could not remove member';
    }
  }

  /// All members, sorted by name. Fine for a gym-sized member list.
  Future<List<StaffMember>> loadMembers() async {
    final snapshot = await _firestore.collection('users').get();
    final members = snapshot.docs.map((doc) {
      final data = doc.data();
      final String name = (data['name'] ?? '').toString().trim();
      return StaffMember(
        uid: doc.id,
        name: name.isNotEmpty ? name : (data['email'] ?? 'Unknown').toString(),
        photoUrl: data['photoUrl'],
      );
    }).toList();

    members.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return members;
  }
}