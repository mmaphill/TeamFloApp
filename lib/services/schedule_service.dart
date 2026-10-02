import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';import '../models/class_history_model.dart';

import '../models/class_schedule_model.dart';
import '../utils/log.dart';

class ScheduleService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get all classes
  Stream<List<ClassSchedule>> getClassesStream() {
    return _firestore
        .collection('classes')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => ClassSchedule.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  // Toggle attendance for the current session
  Future<String?> toggleAttendance(String classId, String userId) {
    return _changeAttendance(classId, userId, join: null);
  }

  // Join the current session
  Future<String?> joinClass(String classId, String userId) {
    return _changeAttendance(classId, userId, join: true);
  }

  // Remove attendance for the current session
  Future<String?> removeAttendance(String classId, String userId) {
    return _changeAttendance(classId, userId, join: false);
  }

  Future<String?> unmarkAttendance(String classId, String userId) {
    return _changeAttendance(classId, userId, join: false);
  }

  Future<String?> _changeAttendance(String classId, String userId, {bool? join}) async {
    try {
      final classRef = _firestore.collection('classes').doc(classId);

      await _firestore.runTransaction((transaction) async {
        // --- All reads first (Firestore transaction rule) ---
        final classSnap = await transaction.get(classRef);
        final data = classSnap.data();
        if (data == null) {
          throw Exception('Class not found');
        }

        // fromMap drops sign-ups from past sessions
        final classSchedule = ClassSchedule.fromMap(data, classSnap.id);

        final historyRef = _firestore.collection('classHistory').doc(
          ClassHistoryRecord.buildId(classId, classSchedule.sessionDate, userId),
        );
        final historySnap = await transaction.get(historyRef);

        // --- Decide what to do ---
        final bool isAttending = classSchedule.attendees.contains(userId);
        final bool shouldJoin = join ?? !isAttending;
        if (shouldJoin == isAttending) return; // Nothing to change

        final updated = List<String>.from(classSchedule.attendees);

        if (shouldJoin) {
          updated.add(userId);
          // Only create the record if one doesn't exist
          // (an instructor may have already added them as a walk-in)
          if (!historySnap.exists) {
            transaction.set(
              historyRef,
              ClassHistoryRecord.newSignUpData(classSchedule, userId),
            );
          }
        } else {
          // Block leaving once an instructor has confirmed attendance
          final historyData = historySnap.data();
          if (historyData != null &&
              historyData['status'] != AttendanceStatus.signedUp) {
            throw Exception('Your attendance was already confirmed by an instructor');
          }
          updated.remove(userId);
          if (historySnap.exists) {
            transaction.delete(historyRef);
          }
        }

        // --- Writes ---
        transaction.update(classRef, {
          'attendees': updated,
          'sessionDate': classSchedule.sessionDate,
        });
      });
      return null; // Success
    } catch (e) {
      return e.toString().replaceFirst('Exception: ', '');
    }
  }

  // A member's full class history, newest first
  Stream<List<ClassHistoryRecord>> getUserHistoryStream(String userId) {
    return _firestore
        .collection('classHistory')
        .where('userId', isEqualTo: userId)
        .orderBy('sessionDate', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => ClassHistoryRecord.fromMap(doc.data(), doc.id))
        .toList());
  }

  // Get attendee details for a class (current session only)
  Future<List<Map<String, String>>> getClassAttendees(String classId) async {
    try {
      final doc = await _firestore.collection('classes').doc(classId).get();
      final data = doc.data();
      if (data == null) return [];

      final classSchedule = ClassSchedule.fromMap(data, doc.id);

      List<Map<String, String>> attendees = [];
      for (String userId in classSchedule.attendees) {
        final userDoc = await _firestore.collection('users').doc(userId).get();
        final userData = userDoc.data();
        if (userData != null) {
          attendees.add({
            'name': userData['name'] ?? 'Unknown',
          });
        }
      }
      return attendees;
    } catch (e) {
      return [];
    }
  }

  // Create Class - Instructor version
  Future<void> createClass({
    required String className,
    required String day,
    required String startTime,
    required String endTime,
    required String classType,
    required String instructor,
  }) async {
    try {
      await _firestore.collection('classes').add({
        'className': className,
        'day': day,
        'startTime': startTime,
        'endTime': endTime,
        'classType': classType,
        'instructor': instructor,
        'capacity': 30,
        'attendees': [],
        'createdBy': FirebaseAuth.instance.currentUser!.uid,
      });
    } catch (e) {
      log('Error creating class: $e');
      rethrow;
    }
  }

  // Get next 5 upcoming classes
  Stream<List<ClassSchedule>> getUpcomingClassesStream() {
    return getClassesStream().map((allClasses) {
      DateTime now = DateTime.now();

      // Calculate next occurrence for each class
      List<MapEntry<ClassSchedule, DateTime>> classesWithTime = [];

      for (var classSchedule in allClasses) {
        DateTime nextOccurrence = _getNextClassDateTime(classSchedule.day, classSchedule.startTime);

        // Only include if it's in the future
        if (nextOccurrence.isAfter(now)) {
          classesWithTime.add(MapEntry(classSchedule, nextOccurrence));
        }
      }

      // Sort by date/time
      classesWithTime.sort((a, b) => a.value.compareTo(b.value));

      // Take only next 5
      return classesWithTime
          .take(5)
          .map((entry) => entry.key)
          .toList();
    });
  }

  // Calculate next occurrence of a class
  DateTime _getNextClassDateTime(String day, String startTime) {
    final days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    int classIndex = days.indexOf(day);
    if (classIndex == -1) classIndex = 0; // Default to Monday

    int todayIndex = DateTime.now().weekday - 1; // 0 = Monday
    DateTime now = DateTime.now();

    // Parse the start time
    DateTime classTime = _parseTime(startTime);

    // Calculate days until next occurrence
    int daysUntilClass = (classIndex - todayIndex) % 7;
    if (daysUntilClass == 0) {
      // It's today - check if time has passed
      if (classTime.hour < now.hour ||
          (classTime.hour == now.hour && classTime.minute <= now.minute)) {
        daysUntilClass = 7; // Next week
      }
    }

    return now.add(Duration(days: daysUntilClass))
        .copyWith(hour: classTime.hour, minute: classTime.minute, second: 0, millisecond: 0);
  }

  // Parse time string like "7:00 PM" to DateTime
  DateTime _parseTime(String timeStr) {
    final parts = timeStr.trim().split(' ');
    if (parts.length < 2) {
      return DateTime.now(); // Fallback
    }

    final timeParts = parts[0].split(':');
    int hour = int.parse(timeParts[0]);
    int minute = int.parse(timeParts[1]);

    if (parts[1].toUpperCase() == 'PM' && hour != 12) hour += 12;
    if (parts[1].toUpperCase() == 'AM' && hour == 12) hour = 0;

    DateTime now = DateTime.now();
    return DateTime(now.year, now.month, now.day, hour, minute);
  }

  // Clear all classes and seed fresh data
  Future<void> clearAndSeedSchedule() async {
    try {
      // Delete all existing classes
      QuerySnapshot existing = await _firestore.collection('classes').get();
      for (var doc in existing.docs) {
        await doc.reference.delete();
      }

      final classes = [
        // Sunday
        {'className': 'No Gi Open Mat', 'day': 'Sunday', 'startTime': '10:00 AM', 'endTime': '11:30 AM', 'classType': 'Open Mat', 'instructor': 'Coach'},

        // Monday
        {'className': 'Gi All Levels', 'day': 'Monday', 'startTime': '6:00 AM', 'endTime': '7:00 AM', 'classType': 'Gi All Levels', 'instructor': 'Coach'},
        {'className': 'Gi All Levels', 'day': 'Monday', 'startTime': '12:00 PM', 'endTime': '1:00 PM', 'classType': 'Gi All Levels', 'instructor': 'Coach'},
        {'className': 'Gi Kids', 'day': 'Monday', 'startTime': '6:00 PM', 'endTime': '7:00 PM', 'classType': 'Gi Kids', 'instructor': 'Coach'},
        {'className': 'Gi Adult Fundamentals', 'day': 'Monday', 'startTime': '6:30 PM', 'endTime': '7:30 PM', 'classType': 'Gi Fundamentals', 'instructor': 'Coach'},
        {'className': 'Gi All Levels', 'day': 'Monday', 'startTime': '7:30 PM', 'endTime': '8:45 PM', 'classType': 'Gi All Levels', 'instructor': 'Coach'},

        // Tuesday
        {'className': 'Adult All Levels - No Gi', 'day': 'Tuesday', 'startTime': '6:00 PM', 'endTime': '7:00 PM', 'classType': 'No Gi', 'instructor': 'Coach'},
        {'className': 'Gi Women Only', 'day': 'Tuesday', 'startTime': '7:00 PM', 'endTime': '8:00 PM', 'classType': 'Women Only', 'instructor': 'Coach'},

        // Wednesday
        {'className': 'Gi All Levels', 'day': 'Wednesday', 'startTime': '6:00 AM', 'endTime': '7:00 AM', 'classType': 'Gi All Levels', 'instructor': 'Coach'},
        {'className': 'Gi Kids', 'day': 'Wednesday', 'startTime': '6:00 PM', 'endTime': '7:00 PM', 'classType': 'Gi Kids', 'instructor': 'Coach'},
        {'className': 'Gi All Levels', 'day': 'Wednesday', 'startTime': '7:00 PM', 'endTime': '8:00 PM', 'classType': 'Gi All Levels', 'instructor': 'Coach'},

        // Thursday
        {'className': 'No Gi All Levels', 'day': 'Thursday', 'startTime': '10:00 AM', 'endTime': '11:30 AM', 'classType': 'No Gi', 'instructor': 'Coach'},
        {'className': 'Adult All Levels - No Gi', 'day': 'Thursday', 'startTime': '6:00 PM', 'endTime': '7:00 PM', 'classType': 'No Gi', 'instructor': 'Coach'},

        // Friday
        {'className': 'No Gi Rounds', 'day': 'Friday', 'startTime': '10:00 AM', 'endTime': '11:00 AM', 'classType': 'No Gi', 'instructor': 'Coach'},
        {'className': 'Open Mat', 'day': 'Friday', 'startTime': '6:00 PM', 'endTime': '7:00 PM', 'classType': 'Open Mat', 'instructor': 'Coach'},

        // Saturday
        {'className': 'Gi Fundamentals', 'day': 'Saturday', 'startTime': '11:00 AM', 'endTime': '12:15 PM', 'classType': 'Gi Fundamentals', 'instructor': 'Coach'},
      ];

      // Add all classes
      for (var classData in classes) {
        await _firestore.collection('classes').add({
          ...classData,
          'capacity': 30,
          'attendees': [],
          'instructorUid': FirebaseAuth.instance.currentUser!.uid,
        });
      }

      log('Schedule seeded with ${classes.length} classes');
    } catch (e) {
      log('Error seeding schedule: $e');
    }
  }

  // Keep the original for future use
  Future<void> seedInitialSchedule() async {
    QuerySnapshot existing = await _firestore.collection('classes').get();
    if (existing.docs.isNotEmpty) {
      return;
    }
    await clearAndSeedSchedule();
  }
}