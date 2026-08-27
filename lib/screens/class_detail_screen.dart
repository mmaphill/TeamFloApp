import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/class_schedule_model.dart';
import '../services/schedule_service.dart';
import '../config/colors.dart';

class ClassDetailScreen extends StatefulWidget {
  final ClassSchedule classSchedule;

  const ClassDetailScreen({super.key, required this.classSchedule});

  @override
  State<ClassDetailScreen> createState() => _ClassDetailScreenState();
}

class _ClassDetailScreenState extends State<ClassDetailScreen> {
  final ScheduleService _scheduleService = ScheduleService();
  final User _currentUser = FirebaseAuth.instance.currentUser!;
  late List<Map<String, String>> _attendees;
  bool _isAttending = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadClassDetails();
  }

  Future<void> _loadClassDetails() async {
    // Read fresh data from Firestore instead of using widget.classSchedule
    DocumentSnapshot classDoc = await FirebaseFirestore.instance
        .collection('classes')
        .doc(widget.classSchedule.classId)
        .get();

    List<String> attendeeIds = List<String>.from(classDoc['attendees'] ?? []);
    List<Map<String, String>> attendees = [];

    for (String userId in attendeeIds) {
      try {
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .get();

        if (userDoc.exists && userDoc.data() != null) {
          final data = userDoc.data() as Map<String, dynamic>;
          String name = data['name'] ?? data['email'] ?? 'Unknown User';
          attendees.add({'name': name, 'userId': userId});
        }
      } catch (e) {
        print('Error fetching attendee $userId: $e');
      }
    }

    final isAttending = attendeeIds.contains(_currentUser.uid);

    setState(() {
      _attendees = attendees;
      _isAttending = isAttending;
      _isLoading = false;
    });
  }

  Future<void> _toggleAttendance() async {
    setState(() => _isLoading = true);
    await _scheduleService.toggleAttendance(
      widget.classSchedule.classId,
      _currentUser.uid,
    );

    await _loadClassDetails();
  }

  Future<List<String>> _getAttendeeNames() async {
    List<String> names = [];

    for (String userId in widget.classSchedule.attendees) {
      try {
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .get();

        if (userDoc.exists) {
          final data = userDoc.data() as Map<String, dynamic>;
          String name = data['name'] ?? data['email'] ?? 'Unknown';
          names.add(name);
        }
      } catch (e) {
        names.add('Unknown');
      }
    }

    return names;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.dark,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Class Name
            Text(
              widget.classSchedule.className,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),

            // Instructor
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Instructor',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.classSchedule.instructor,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Time & Day
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Day',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.classSchedule.day,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Time',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${widget.classSchedule.startTime} - ${widget.classSchedule.endTime}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Attendees
            const Text(
              'Attendees',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_attendees.length}/${widget.classSchedule.capacity} Attending',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_attendees.isEmpty)
                    const Text('No one has joined yet')
                  else
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: _attendees
                          .map((attendee) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text('• ${attendee['name']}'),
                      )).toList(),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Join/Leave Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _toggleAttendance,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isAttending
                      ? Colors.red
                      : AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: Text(
                  _isAttending ? 'Leave Class' : 'Join Class',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}