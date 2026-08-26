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
  });

  factory ClassSchedule.fromMap(Map<String, dynamic> map, String classId) {
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
    };
  }
}