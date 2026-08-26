import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/class_schedule_model.dart';

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

  // Add attendance for a user
  Future<String?> markAttendance(String classId, String userId) async {
    try {
      await _firestore
          .collection('classes')
          .doc(classId)
          .collection('attendance')
          .add({
        'userId': userId,
        'classId': classId,
        'timestamp': FieldValue.serverTimestamp(),
      });
      return null; // Success
    } catch (e) {
      return e.toString();
    }
  }

  // Remove attendance for a user
  Future<String?> unmarkAttendance(String classId, String userId) async {
    try {
      DocumentSnapshot doc = await _firestore.collection('classes').doc(classId).get();
      List<String> attendees = List<String>.from(doc['attendees'] ?? []);

      if (attendees.contains(userId)) {
        attendees.remove(userId);
        await _firestore.collection('classes').doc(classId).update({
          'attendees': attendees,
        });
      }
      return null; // Success
    } catch (e) {
      return e.toString();
    }
  }

  // Toggle attendance
  Future<String?> toggleAttendance(String classId, String userId) async {
    try {
      DocumentSnapshot doc = await _firestore.collection('classes').doc(classId).get();
      List<String> attendees = List<String>.from(doc['attendees'] ?? []);

      if (attendees.contains(userId)) {
        attendees.remove(userId);
      } else {
        attendees.add(userId);
      }

      await _firestore.collection('classes').doc(classId).update({
        'attendees': attendees,
      });
      return null; // Success
    } catch (e) {
      return e.toString();
    }
  }

  // Get Attendees details for a class
  Future<List<Map<String, String>>> getClassAttendees(String classId) async {
    try {
      DocumentSnapshot doc = await _firestore.collection('classes').doc(classId).get();
      List<String> attendeeIds = List<String>.from(doc['attendees'] ?? []);

      List<Map<String, String>> attendees = [];
      for (String userId in attendeeIds) {
        DocumentSnapshot userDoc = await _firestore.collection('users').doc(userId).get();
        if (userDoc.exists) {
          attendees.add({
            'name': userDoc['name'] ?? 'Unknown',
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
      print('Error creating class: $e');
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

      print('Schedule seeded with ${classes.length} classes');
    } catch (e) {
      print('Error seeding schedule: $e');
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