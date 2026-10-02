class ClassSchedule {
  final String classId;
  final String className;
  final String day; // Monday, Tuesday, etc.
  final String startTime; // 6:00 AM
  final String endTime; // 7:00 AM
  final String classType; // Gi All Levels, Gi Kids, etc.
  final int capacity; // Max attendees
  final List<String> attendees; // List of user IDs attending
  final String instructor; // Instructor name
  final String instructorUid;
  final String sessionDate;

  ClassSchedule({
    required this.classId,
    required this.className,
    required this.day,
    required this.startTime,
    required this.endTime,
    required this.classType,
    required this.capacity,
    required this.attendees,
    required this.instructor,
    required this.instructorUid,
    required this.sessionDate,
  });

  factory ClassSchedule.fromMap(Map<String, dynamic> map, String classId) {
    final String day = map['day'] ?? '';
    final String endTime = map['endTime'] ?? '';

    final String currentSession = currentSessionDate(day, endTime);

    final String storedSession = map['storedSession'] ?? '';
    final List<String> storedAttendees = List<String>.from(map['attendees'] ?? []);

    return ClassSchedule(
      classId: classId,
      className: map['className'] ?? '',
      day: map['day'] ?? '',
      startTime: map['startTime'] ?? '',
      endTime: map['endTime'] ?? '',
      classType: map['classType'] ?? '',
      capacity: map['capacity'] ?? 30,
      attendees: List<String>.from(map['attendees'] ?? []),
      instructor: map['instructor'] ?? 'Coach',
      instructorUid: map['instructorUid'] ?? '',
      sessionDate: currentSession,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'className': className,
      'day': day,
      'startTime': startTime,
      'endTime': endTime,
      'classType': classType,
      'capacity': capacity,
      'attendees': attendees,
      'instructor': instructor,
      'instructorUid': instructorUid,
      'sessionDate': sessionDate,
    };
  }

  static const List<String> _days = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
  ];

  static const List<String> _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];

  /**
   * Returns the date (yyyy-MM-dd) of the session that sign-ups currently
   * apply to. A session stays "current" until its end time passes,
   * then it rolls over to the same day next week
   */
  static String currentSessionDate(String day, String endTime, {DateTime? now}) {
    final DateTime current = now ?? DateTime.now();

    int dayIndex = _days.indexOf(day);
    if (dayIndex == -1) dayIndex = 0; // Default to Monday

    // If the end time can't be read, treat the class as lasting all day.
    final int endMinutes = parseTimeToMinutes(endTime) ?? (23 * 60 + 59);
    final int endHour = endMinutes ~/ 60;
    final int endMinute = endMinutes % 60;

    final int daysUntil = (dayIndex - (current.weekday - 1)) % 7;

    DateTime sessionEnd = DateTime(
      current.year,
      current.month,
      current.day + daysUntil,
      endHour,
      endMinute,
    );

    // Today's session already ended, so move to next week
    if (!sessionEnd.isAfter(current)) {
      sessionEnd = DateTime(
        sessionEnd.year,
        sessionEnd.month,
        sessionEnd.day + 7,
        endHour,
        endMinute,
      );
    }

    return _formatDate(sessionEnd);
  }

  // Turns "7:30 PM" into minutes since midnight (1170). returns null if invalid
  static int? parseTimeToMinutes(String timeStr) {
    final parts = timeStr.trim().split(' ');
    if (parts.length < 2) return null;

    final hm = parts[0].split(':');
    if (hm.length < 2) return null;

    int? hour = int.tryParse(hm[0]);
    final int? minute = int.tryParse(hm[1]);
    if (hour == null || minute == null) return null;

    final period = parts[1].toUpperCase();
    if (period == 'PM' && hour != 12) hour += 12;
    if (period == 'AM' && hour == 12) hour = 0;

    return hour * 60 + minute;
  }

  static String _formatDate(DateTime d) {
    final m = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '${d.year}-$m-$dd';
  }

  String get sessionDateLabel{
    final parts = sessionDate.split('-');
    if (parts.length != 3) return '';
    final int? month = int.tryParse(parts[1]);
    final int? dayOfMonth = int.tryParse(parts[2]);
    if (month == null || dayOfMonth == null || month < 1 || month > 12) return '';
    return '${_months[month - 1]} $dayOfMonth';
  }
}