import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/app_roles.dart';
import '../models/class_history_model.dart';
import '../models/class_schedule_model.dart';
import '../models/user_model.dart';
import '../utils/log.dart';
import 'attendance_stats_service.dart';
import 'gym_scope.dart';
import 'gym_service.dart';

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

    // All three loads start at once, then we wait for each.
    // sessionDate is stored as 'yyyy-MM-dd', so comparing the text works
    // like comparing dates. One range filter on one field: no extra index.
    final historyFuture =
    _history.where('sessionDate', isGreaterThanOrEqualTo: dateKey(from)).get();
    final classesFuture = _classes.get();
    final membersFuture = _loadGymMembers(); // STEP 2

    final records = (await historyFuture)
        .docs
        .map((doc) => ClassHistoryRecord.fromMap(doc.data(), doc.id))
        .toList();
    final classes = (await classesFuture)
        .docs
        .map((doc) => ClassSchedule.fromMap(doc.data(), doc.id))
        .toList();
    final members = await membersFuture;

    return StaffAnalytics.compute(records, classes, members: members, now: now);
  }

  /// STEP 2: everyone in this gym (members and staff), one read per person.
  /// The users rule only allows listing when the query filters by your own
  /// gymId, so the filter here is required, not just tidy.
  /// A user doc that can't be read is skipped and logged instead of
  /// breaking the whole screen (same lesson as the grey screen bug).
  Future<List<MemberInfo>> _loadGymMembers() async {
    final String? gymId = GymService.instance.gymId;
    if (gymId == null) return [];

    final snap = await FirebaseFirestore.instance
        .collection('users')
        .where('gymId', isEqualTo: gymId)
        .get();

    final List<MemberInfo> list = [];
    for (final doc in snap.docs) {
      try {
        final data = doc.data();
        final user = UserModel.fromMap(data);

        // Current belt = the most recent promotion
        String? belt;
        if (user.beltRankHistory.isNotEmpty) {
          final sorted = List.of(user.beltRankHistory)
            ..sort((a, b) => b.promotionDate.compareTo(a.promotionDate));
          belt = sorted.first.rank;
        }

        // Read createdAt from the raw doc, not the model: if the field is
        // missing, the model may fill in "now", which would make old
        // accounts look like brand new members.
        final rawCreated = data['createdAt'];
        final DateTime? joined = rawCreated is Timestamp ? rawCreated.toDate() : null;

        list.add(MemberInfo(
          id: doc.id,
          name: user.name.trim().isEmpty ? 'Unnamed member' : user.name,
          photoUrl: user.photoUrl,
          role: AppRoles.normalize(user.role),
          joined: joined,
          belt: (belt == null || belt.trim().isEmpty) ? null : belt,
        ));
      } catch (e) {
        log('Staff analytics: skipped user ${doc.id}: $e');
      }
    }
    return list;
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

/// STEP 2: one person in the gym, as the analytics screen needs them.
class MemberInfo {
  final String id;
  final String name;
  final String? photoUrl;
  final String role;     // normalized: owner, manager, ..., member
  final DateTime? joined; // null if the account has no createdAt
  final String? belt;     // most recent belt, null if none recorded

  const MemberInfo({
    required this.id,
    required this.name,
    this.photoUrl,
    required this.role,
    this.joined,
    this.belt,
  });
}

/// STEP 2: a member and the last class they came to (inside the 8 weeks).
class MemberActivity {
  final MemberInfo member;
  final DateTime? lastClass; // null = no classes in the 8 weeks

  const MemberActivity(this.member, this.lastClass);
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

  // ---------- STEP 2: member activity and growth ----------
  /// A member counts as active if they trained within this many days.
  static const int activeDays = 14;
  /// How many months the "new members" chart shows, including this one.
  static const int monthsShown = 6;

  final int memberCount;  // role 'member' only
  final int staffCount;   // owner, manager, instructor, front desk
  /// Check-ins in the last 14 days by members (the "Active" tile's list)
  final List<ClassHistoryRecord> activeRecords;
  final int activeCount;
  /// Members who haven't trained in 14+ days. Most recently lapsed first
  /// (easiest to win back), then members with no classes in 8 weeks.
  final List<MemberActivity> watchList;
  final List<DateTime> monthStarts;   // oldest first
  final List<int> newMembersByMonth;  // same order as monthStarts
  final int newThisMonth;
  final int unknownJoinDate;          // members with no createdAt
  /// Belt -> number of members, most common first. 'No belt' if none.
  final List<MapEntry<String, int>> beltCounts;

  StaffAnalytics._({
    required this.memberCount,
    required this.staffCount,
    required this.activeRecords,
    required this.activeCount,
    required this.watchList,
    required this.monthStarts,
    required this.newMembersByMonth,
    required this.newThisMonth,
    required this.unknownJoinDate,
    required this.beltCounts,
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
        List<MemberInfo> members = const [],
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

    // ---------- STEP 2: member activity ----------
    // Staff train too, but these numbers are about paying members.
    final gymMembers = members.where((m) => m.role == AppRoles.member).toList();
    final memberIds = gymMembers.map((m) => m.id).toSet();

    // Last class per person, from the check-ins already loaded
    final Map<String, DateTime> lastClass = {};
    for (final r in attended) {
      final day = r.sessionDay!;
      final prev = lastClass[r.userId];
      if (prev == null || day.isAfter(prev)) lastClass[r.userId] = day;
    }

    final DateTime activeCutoff = DateTime(today.year, today.month, today.day - activeDays);

    final activeRecords = attended
        .where((r) => memberIds.contains(r.userId) && !r.sessionDay!.isBefore(activeCutoff))
        .toList()
      ..sort(newestFirst);
    final int activeCount = activeRecords.map((r) => r.userId).toSet().length;

    final watchList = gymMembers
        .where((m) {
      final last = lastClass[m.id];
      return last == null || last.isBefore(activeCutoff);
    })
        .map((m) => MemberActivity(m, lastClass[m.id]))
        .toList()
      ..sort((a, b) {
        // Members with a last class come first, most recent first.
        if (a.lastClass != null && b.lastClass != null) {
          return b.lastClass!.compareTo(a.lastClass!);
        }
        if (a.lastClass != null) return -1;
        if (b.lastClass != null) return 1;
        return a.member.name.toLowerCase().compareTo(b.member.name.toLowerCase());
      });

    // ---------- STEP 2: growth ----------
    final List<DateTime> monthStarts = [];
    final List<int> newByMonth = [];
    for (int i = monthsShown - 1; i >= 0; i--) {
      final start = DateTime(today.year, today.month - i, 1);
      monthStarts.add(start);
      newByMonth.add(gymMembers
          .where((m) =>
      m.joined != null &&
          m.joined!.year == start.year &&
          m.joined!.month == start.month)
          .length);
    }

    final Map<String, int> belts = {};
    for (final m in gymMembers) {
      final key = m.belt ?? 'No belt';
      belts[key] = (belts[key] ?? 0) + 1;
    }
    final beltCounts = belts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return StaffAnalytics._(
      memberCount: gymMembers.length,
      staffCount: members.length - gymMembers.length,
      activeRecords: activeRecords,
      activeCount: activeCount,
      watchList: watchList,
      monthStarts: monthStarts,
      newMembersByMonth: newByMonth,
      newThisMonth: newByMonth.last,
      unknownJoinDate: gymMembers.where((m) => m.joined == null).length,
      beltCounts: beltCounts,
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