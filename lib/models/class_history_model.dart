import 'package:cloud_firestore/cloud_firestore.dart';
import 'class_schedule_model.dart';

/// The possible states of an attendance record.
class AttendanceStatus {
  static const String signedUp = 'signedUp'; // Member tapped Join
  static const String attended = 'attended'; // Instructor confirmed they came
  static const String noShow = 'noShow';     // Instructor marked them absent
}

/// One member's record for one class session.
/// Doc ID format: {classId}_{sessionDate}_{userId}
class ClassHistoryRecord {
  final String id;
  final String userId;
  final String classId;
  final String sessionDate; // yyyy-MM-dd
  final String className;
  final String classType;
  final String day;
  final String startTime;
  final String endTime;
  final int durationMinutes;
  final String status;
  final bool walkIn; // True if an instructor added them without a sign-up
  final DateTime? joinedAt;
  final String? confirmedBy; // UID of instructor/admin who confirmed
  final DateTime? confirmedAt;

  ClassHistoryRecord({
    required this.id,
    required this.userId,
    required this.classId,
    required this.sessionDate,
    required this.className,
    required this.classType,
    required this.day,
    required this.startTime,
    required this.endTime,
    required this.durationMinutes,
    required this.status,
    required this.walkIn,
    this.joinedAt,
    this.confirmedBy,
    this.confirmedAt,
  });

  /// Builds the doc ID so the same member can't have two records for one session.
  static String buildId(String classId, String sessionDate, String userId) {
    return '${classId}_${sessionDate}_$userId';
  }

  /// Data for a brand new sign-up. Copies class details so history still
  /// reads correctly if the class is renamed or deleted later.
  static Map<String, dynamic> newSignUpData(ClassSchedule classSchedule, String userId) {
    return {
      'userId': userId,
      'classId': classSchedule.classId,
      'sessionDate': classSchedule.sessionDate,
      'className': classSchedule.className,
      'classType': classSchedule.classType,
      'day': classSchedule.day,
      'startTime': classSchedule.startTime,
      'endTime': classSchedule.endTime,
      'durationMinutes': calculateDuration(classSchedule.startTime, classSchedule.endTime),
      'status': AttendanceStatus.signedUp,
      'walkIn': false,
      'joinedAt': FieldValue.serverTimestamp(),
    };
  }

  factory ClassHistoryRecord.fromMap(Map<String, dynamic> map, String id) {
    return ClassHistoryRecord(
      id: id,
      userId: map['userId'] ?? '',
      classId: map['classId'] ?? '',
      sessionDate: map['sessionDate'] ?? '',
      className: map['className'] ?? '',
      classType: map['classType'] ?? '',
      day: map['day'] ?? '',
      startTime: map['startTime'] ?? '',
      endTime: map['endTime'] ?? '',
      durationMinutes: map['durationMinutes'] ?? 60,
      status: map['status'] ?? AttendanceStatus.signedUp,
      walkIn: map['walkIn'] ?? false,
      joinedAt: _toDateTime(map['joinedAt']),
      confirmedBy: map['confirmedBy'],
      confirmedAt: _toDateTime(map['confirmedAt']),
    );
  }

  // ---------- Helpers used by stats and the home screen ----------

  /// When this session ends, in local time. Null if the data can't be read.
  DateTime? get sessionEnd {
    final parts = sessionDate.split('-');
    if (parts.length != 3) return null;
    final int? year = int.tryParse(parts[0]);
    final int? month = int.tryParse(parts[1]);
    final int? dayOfMonth = int.tryParse(parts[2]);
    final int? endMinutes = ClassSchedule.parseTimeToMinutes(endTime);
    if (year == null || month == null || dayOfMonth == null || endMinutes == null) {
      return null;
    }
    return DateTime(year, month, dayOfMonth, endMinutes ~/ 60, endMinutes % 60);
  }

  /// The session's calendar date (no time), handy for grouping by week/month.
  DateTime? get sessionDay {
    final end = sessionEnd;
    if (end == null) return null;
    return DateTime(end.year, end.month, end.day);
  }

  /// True once the class has ended.
  bool get isPast {
    final end = sessionEnd;
    return end != null && DateTime.now().isAfter(end);
  }

  /// True if an instructor has reviewed this record.
  bool get isConfirmed =>
      status == AttendanceStatus.attended || status == AttendanceStatus.noShow;

  /// Counts toward stats: confirmed attendance, or a past sign-up
  /// that no instructor marked as a no-show.
  bool get countsAsAttended =>
      status == AttendanceStatus.attended ||
          (status == AttendanceStatus.signedUp && isPast);

  /// A sign-up for a class that hasn't ended yet.
  bool get isUpcoming => status == AttendanceStatus.signedUp && !isPast;

  double get hours => durationMinutes / 60.0;

  /// Minutes between two times like "6:00 PM" and "7:30 PM". Defaults to 60.
  static int calculateDuration(String startTime, String endTime) {
    final int? start = ClassSchedule.parseTimeToMinutes(startTime);
    final int? end = ClassSchedule.parseTimeToMinutes(endTime);
    if (start == null || end == null) return 60;
    int minutes = end - start;
    if (minutes <= 0) minutes += 24 * 60; // Class crosses midnight
    return minutes;
  }

  static DateTime? _toDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }
}