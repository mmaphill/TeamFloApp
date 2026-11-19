import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/class_history_model.dart';
import '../models/class_schedule_model.dart';
import 'attendance_stats_service.dart';
import 'gym_scope.dart';

/// STAFF ANALYTICS (Phase 1, Step 1): gym-wide attendance numbers for
/// owners and managers. Reads the last 8 weeks of class history once
/// (no live listener, so it doesn't keep costing reads while open).
///
/// Uses the same "counts as attended" rule as the member Stats screen:
/// confirmed attendance, or a past sign-up nobody marked as a no-show.
class StaffAnalyticsService {
  /// How many weeks to look back, including the current week.
  static const int weeksShown = 8;

  CollectionReference<Map<String, dynamic>> get _history => GymScope.col('classHistory');
  CollectionReference<Map<String, dynamic>> get _classes => GymScope.col('classes');

  Future<StaffAnalytics> load() async {
    final DateTime now = DateTime.now();
    final DateTime from = StaffAnalytics.firstWeekStart(now);

    // sessionDate is stored as 'yyyy-MM-dd', so comparing the text works
    // like comparing dates. One range filter on one field: no extra index.
    final results = await Future.wait([
      _history.where('sessionDate', isGreaterThanOrEqualTo: dateKey(from)).get(),
      _classes.get(),
    ]);

    final records = results[0]
        .docs
        .map((doc) => ClassHistoryRecord.fromMap(doc.data(), doc.id))
        .toList();
    final classes = results[1]
        .docs
        .map((doc) => ClassSchedule.fromMap(doc.data(), doc.id))
        .toList();

    return StaffAnalytics.compute(records, classes, now: now);
  }

  /// MEMBER LISTS: names and photos for a set of user IDs.
  /// Users live in the top-level 'users' collection. Each doc is opened on
  /// its own (the rules allow opening anyone in your gym), all at once.
  /// A member who deleted their account shows as "Former member".
  Future<Map<String, MemberSummary>> loadMembers(Set<String> userIds) async {
    final users = FirebaseFirestore.instance.collection('users');
    final entries = await Future.wait(userIds.map((id) async {
      try {
        final data = (await users.doc(id).get()).data();
        return MapEntry(
          id,
          MemberSummary(
            name: (data?['name'] as String?)?.trim().isNotEmpty == true
                ? data!['name'] as String
                : 'Former member',
            photoUrl: data?['photoUrl'] as String?,
          ),
        );
      } catch (_) {
        return MapEntry(id, const MemberSummary(name: 'Unknown member'));
      }
    }));
    return Map.fromEntries(entries);
  }

  /// DateTime -> 'yyyy-MM-dd'
  static String dateKey(DateTime d) {
    final m = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '${d.year}-$m-$dd';
  }
}

/// MEMBER LISTS: what the lists show for each person.
class MemberSummary {
  final String name;
  final String? photoUrl;
  const MemberSummary({required this.name, this.photoUrl});
}

/// One class (by its classId) over the 8 weeks.
class ClassPerformance {
  final String classId;
  final String className;
  final String day;
  final String startTime;
  final int sessions; // sessions with at least one record
  final int attended;
  final int noShows;
  final int capacity;

  ClassPerformance({
    required this.classId,
    required this.className,
    required this.day,
    required this.startTime,
    required this.sessions,
    required this.attended,
    required this.noShows,
    required this.capacity,
  });

  double get avgPerSession => sessions == 0 ? 0 : attended / sessions;

  /// Average attendance compared to capacity (0.0 to 1.0+)
  double get fillRate => capacity <= 0 ? 0 : avgPerSession / capacity;

  double get noShowRate {
    final reviewed = attended + noShows;
    return reviewed == 0 ? 0 : noShows / reviewed;
  }
}

/// Every number the staff analytics screen shows.
class StaffAnalytics {
  final List<DateTime> weekStarts; // oldest first
  final List<int> weeklyTotals;    // same order as weekStarts
  final int thisWeek;
  final int lastWeek;
  final int thisMonth;
  final int membersThisWeek;       // different people who trained
  final int membersThisMonth;
  final double noShowRate;         // 0.0 to 1.0
  final int unreviewed;            // past sign-ups no instructor has checked
  final List<double> avgByWeekday; // Mon..Sun, average check-ins per week
  final List<ClassPerformance> classes; // busiest first
  final List<ClassSchedule> emptyClasses; // on the schedule, nobody came

  // MEMBER LISTS: the check-ins behind the "This week" and "This month"
  // tiles, newest first, so tapping a tile can show who they were.
  final List<ClassHistoryRecord> thisWeekRecords;
  final List<ClassHistoryRecord> thisMonthRecords;

  StaffAnalytics._({
    required this.thisWeekRecords,
    required this.thisMonthRecords,
    required this.weekStarts,
    required this.weeklyTotals,
    required this.thisWeek,
    required this.lastWeek,
    required this.thisMonth,
    required this.membersThisWeek,
    required this.membersThisMonth,
    required this.noShowRate,
    required this.unreviewed,
    required this.avgByWeekday,
    required this.classes,
    required this.emptyClasses,
  });

  /// Monday of the oldest week shown.
  static DateTime firstWeekStart(DateTime now) {
    final thisWeek = AttendanceStats.weekStartOf(now);
    return DateTime(thisWeek.year, thisWeek.month,
        thisWeek.day - 7 * (StaffAnalyticsService.weeksShown - 1));
  }

  factory StaffAnalytics.compute(
      List<ClassHistoryRecord> records,
      List<ClassSchedule> schedule, {
        DateTime? now,
      }) {
    final DateTime today = now ?? DateTime.now();
    final DateTime thisWeekStart = AttendanceStats.weekStartOf(today);
    final DateTime lastWeekStart =
    DateTime(thisWeekStart.year, thisWeekStart.month, thisWeekStart.day - 7);
    final DateTime firstWeek = firstWeekStart(today);

    // Only classes that have already ended, inside the 8 weeks
    final past = records
        .where((r) => r.sessionDay != null && r.isPast && !r.sessionDay!.isBefore(firstWeek))
        .toList();
    final attended = past.where((r) => r.countsAsAttended).toList();
    final int noShowCount = past.where((r) => r.status == AttendanceStatus.noShow).length;
    final int unreviewed = past.where((r) => r.status == AttendanceStatus.signedUp).length;

    // ----- Weekly totals -----
    final Map<DateTime, int> byWeek = {};
    for (final r in attended) {
      final week = AttendanceStats.weekStartOf(r.sessionDay!);
      byWeek[week] = (byWeek[week] ?? 0) + 1;
    }
    final List<DateTime> weekStarts = [];
    final List<int> weeklyTotals = [];
    for (int i = StaffAnalyticsService.weeksShown - 1; i >= 0; i--) {
      final start = DateTime(thisWeekStart.year, thisWeekStart.month, thisWeekStart.day - 7 * i);
      weekStarts.add(start);
      weeklyTotals.add(byWeek[start] ?? 0);
    }

    // ----- This week / this month -----
    final thisWeekRecords =
    attended.where((r) => !r.sessionDay!.isBefore(thisWeekStart)).toList();
    final thisMonthRecords = attended
        .where((r) => r.sessionDay!.year == today.year && r.sessionDay!.month == today.month)
        .toList();

    // ----- Busiest days (full weeks only, so this week doesn't drag it down) -----
    const int fullWeeks = StaffAnalyticsService.weeksShown - 1;
    final List<int> weekdayCounts = List.filled(7, 0);
    for (final r in attended) {
      if (r.sessionDay!.isBefore(thisWeekStart)) {
        weekdayCounts[r.sessionDay!.weekday - 1]++;
      }
    }
    final avgByWeekday = weekdayCounts.map((c) => c / fullWeeks).toList();

    // ----- Per class -----
    final Map<String, ClassSchedule> scheduleById = {
      for (final c in schedule) c.classId: c,
    };
    final Map<String, List<ClassHistoryRecord>> byClass = {};
    for (final r in past) {
      byClass.putIfAbsent(r.classId, () => []).add(r);
    }

    final List<ClassPerformance> classes = [];
    byClass.forEach((classId, list) {
      final current = scheduleById[classId];
      final sample = list.first; // fallback details if the class was deleted
      classes.add(ClassPerformance(
        classId: classId,
        className: current?.className ?? sample.className,
        day: current?.day ?? sample.day,
        startTime: current?.startTime ?? sample.startTime,
        sessions: list.map((r) => r.sessionDate).toSet().length,
        attended: list.where((r) => r.countsAsAttended).length,
        noShows: list.where((r) => r.status == AttendanceStatus.noShow).length,
        capacity: current?.capacity ?? 30,
      ));
    });
    classes.sort((a, b) => b.avgPerSession.compareTo(a.avgPerSession));

    final emptyClasses =
    schedule.where((c) => !byClass.containsKey(c.classId)).toList();

    final int reviewed = attended.where((r) => r.status == AttendanceStatus.attended).length +
        noShowCount;

    // Newest first for the member lists
    int newestFirst(ClassHistoryRecord a, ClassHistoryRecord b) =>
        b.sessionEnd!.compareTo(a.sessionEnd!);
    thisWeekRecords.sort(newestFirst);
    thisMonthRecords.sort(newestFirst);

    return StaffAnalytics._(
      thisWeekRecords: thisWeekRecords,
      thisMonthRecords: thisMonthRecords,
      weekStarts: weekStarts,
      weeklyTotals: weeklyTotals,
      thisWeek: thisWeekRecords.length,
      lastWeek: byWeek[lastWeekStart] ?? 0,
      thisMonth: thisMonthRecords.length,
      membersThisWeek: thisWeekRecords.map((r) => r.userId).toSet().length,
      membersThisMonth: thisMonthRecords.map((r) => r.userId).toSet().length,
      noShowRate: reviewed == 0 ? 0 : noShowCount / reviewed,
      unreviewed: unreviewed,
      avgByWeekday: avgByWeekday,
      classes: classes,
      emptyClasses: emptyClasses,
    );
  }
}