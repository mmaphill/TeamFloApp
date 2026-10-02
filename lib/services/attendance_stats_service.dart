import '../models/class_history_model.dart';
import '../models/class_schedule_model.dart';

/// One week of attended classes. Weeks start on Monday.
class WeekAttendance {
  final DateTime weekStart;
  final List<ClassHistoryRecord> records;

  WeekAttendance(this.weekStart, this.records);

  int get total => records.length;
  int get confirmed =>
      records.where((r) => r.status == AttendanceStatus.attended).length;
  int get unconfirmed => total - confirmed;
}

/// All attendance numbers for one member, worked out from their history.
/// Used by both the Stats and Home screens so they always agree.
class AttendanceStats {
  static const List<int> milestoneSteps = [10, 25, 50, 100, 250, 500, 1000];

  final List<ClassHistoryRecord> attended;     // Counts toward stats, newest first
  final List<ClassHistoryRecord> upcoming;     // Future sign-ups, soonest first
  final List<ClassHistoryRecord> recent;       // Past records incl. no-shows, newest first
  final List<WeekAttendance> lastEightWeeks;   // Oldest week first
  final int classesThisMonth;
  final double matHoursThisMonth;
  final double matHoursTotal;
  final int streakWeeks;
  final int giCount;
  final int noGiCount;
  final int otherCount;
  final String? favoriteSlot; // e.g. "Monday evenings"

  AttendanceStats._({
    required this.attended,
    required this.upcoming,
    required this.recent,
    required this.lastEightWeeks,
    required this.classesThisMonth,
    required this.matHoursThisMonth,
    required this.matHoursTotal,
    required this.streakWeeks,
    required this.giCount,
    required this.noGiCount,
    required this.otherCount,
    required this.favoriteSlot,
  });

  factory AttendanceStats.fromRecords(List<ClassHistoryRecord> records, {DateTime? now}) {
    final DateTime today = now ?? DateTime.now();

    // Ignore any record whose date can't be read, then sort newest first
    final dated = records.where((r) => r.sessionEnd != null).toList()
      ..sort((a, b) => b.sessionEnd!.compareTo(a.sessionEnd!));

    final attended = dated.where((r) => r.countsAsAttended).toList();
    final upcoming = dated.where((r) => r.isUpcoming).toList().reversed.toList();
    final recent = dated.where((r) => r.isPast).toList();

    double sumHours(Iterable<ClassHistoryRecord> list) =>
        list.fold(0.0, (sum, r) => sum + r.hours);

    // ----- This month -----
    final thisMonth = attended.where((r) =>
    r.sessionDay!.year == today.year && r.sessionDay!.month == today.month);

    // ----- Group attended classes by week -----
    final Map<DateTime, List<ClassHistoryRecord>> byWeek = {};
    for (final r in attended) {
      byWeek.putIfAbsent(weekStartOf(r.sessionDay!), () => []).add(r);
    }

    final DateTime thisWeek = weekStartOf(today);
    final List<WeekAttendance> lastEight = [];
    for (int i = 7; i >= 0; i--) {
      final start = DateTime(thisWeek.year, thisWeek.month, thisWeek.day - 7 * i);
      lastEight.add(WeekAttendance(start, byWeek[start] ?? []));
    }

    // ----- Streak: weeks in a row with at least one class -----
    // If nothing yet this week, start counting from last week
    // so the streak doesn't "break" on a Monday morning.
    DateTime week = thisWeek;
    if (!byWeek.containsKey(week)) {
      week = DateTime(week.year, week.month, week.day - 7);
    }
    int streak = 0;
    while (byWeek.containsKey(week)) {
      streak++;
      week = DateTime(week.year, week.month, week.day - 7);
    }

    // ----- Gi vs No Gi -----
    int gi = 0, noGi = 0, other = 0;
    for (final r in attended) {
      final style = styleOf(r);
      if (style == 'gi') {
        gi++;
      } else if (style == 'noGi') {
        noGi++;
      } else {
        other++;
      }
    }

    // ----- Favorite day and time (needs a few classes to mean anything) -----
    String? favorite;
    if (attended.length >= 3) {
      final Map<String, int> counts = {};
      for (final r in attended) {
        final key = '${r.day} ${_timeOfDay(r.startTime)}'.trim();
        counts[key] = (counts[key] ?? 0) + 1;
      }
      favorite = counts.entries.reduce((a, b) => b.value > a.value ? b : a).key;
    }

    return AttendanceStats._(
      attended: attended,
      upcoming: upcoming,
      recent: recent,
      lastEightWeeks: lastEight,
      classesThisMonth: thisMonth.length,
      matHoursThisMonth: sumHours(thisMonth),
      matHoursTotal: sumHours(attended),
      streakWeeks: streak,
      giCount: gi,
      noGiCount: noGi,
      otherCount: other,
      favoriteSlot: favorite,
    );
  }

  // ----- Milestones -----

  int get totalClasses => attended.length;

  int? get nextMilestone {
    for (final m in milestoneSteps) {
      if (m > totalClasses) return m;
    }
    return null; // Every milestone reached
  }

  int get lastMilestone {
    int last = 0;
    for (final m in milestoneSteps) {
      if (m <= totalClasses) last = m;
    }
    return last;
  }

  List<int> get reachedMilestones =>
      milestoneSteps.where((m) => m <= totalClasses).toList();

  // ----- Helpers -----

  /// 'gi', 'noGi' or 'other' based on the class type and name.
  static String styleOf(ClassHistoryRecord r) {
    final text = '${r.classType} ${r.className}'.toLowerCase();
    if (text.contains('no gi') || text.contains('no-gi') || text.contains('nogi')) {
      return 'noGi';
    }
    if (RegExp(r'\bgi\b').hasMatch(text)) return 'gi';
    return 'other';
  }

  static String _timeOfDay(String startTime) {
    final minutes = ClassSchedule.parseTimeToMinutes(startTime);
    if (minutes == null) return '';
    if (minutes < 12 * 60) return 'mornings';
    if (minutes < 17 * 60) return 'afternoons';
    return 'evenings';
  }

  /// Monday of the week containing [d], at midnight.
  static DateTime weekStartOf(DateTime d) =>
      DateTime(d.year, d.month, d.day - (d.weekday - 1));

  static const List<String> _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];
  static const List<String> _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  /// "Oct 5"
  static String monthDay(DateTime d) => '${_months[d.month - 1]} ${d.day}';

  /// "Mon, Oct 5"
  static String shortDate(DateTime d) => '${_weekdays[d.weekday - 1]}, ${monthDay(d)}';
}