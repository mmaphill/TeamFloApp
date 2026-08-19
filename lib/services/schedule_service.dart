import 'package:cloud_firestore/cloud_firestore.dart';
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
      DocumentSnapshot doc = await _firestore.collection('classes').doc(classId).get();
      List<String> attendees = List<String>.from(doc['attendees'] ?? []);

      if (!attendees.contains(userId)) {
        attendees.add(userId);
        await _firestore.collection('classes').doc(classId).update({
          'attendees': attendees,
        });
      }
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