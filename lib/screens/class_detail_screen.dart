import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/class_schedule_model.dart';
import '../services/schedule_service.dart';
import '../config/colors.dart';
import '../utils/log.dart';

class ClassDetailScreen extends StatefulWidget {
  final ClassSchedule classSchedule;

  const ClassDetailScreen({super.key, required this.classSchedule});

  @override
  State<ClassDetailScreen> createState() => _ClassDetailScreenState();
}

class _ClassDetailScreenState extends State<ClassDetailScreen> {
  final ScheduleService _scheduleService = ScheduleService();
  final User _currentUser = FirebaseAuth.instance.currentUser!;
  List<Map<String, String>> _attendees = [];
  String _sessionLabel = '';
  bool _isAttending = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadClassDetails();
  }

  Future<void> _loadClassDetails() async {
    try {
      // Read fresh data from Firestore instead of using widget.classSchedule
      final classDoc = await FirebaseFirestore.instance
          .collection('classes')
          .doc(widget.classSchedule.classId)
          .get();

      final data = classDoc.data();
      if (data == null) {
        if (!mounted) return;
        setState(() {
          _attendees = [];
          _isAttending = false;
          _isLoading = false;
        });
        return;
      }

      // fromMap drops sign-ups from past sessions
      final freshClass = ClassSchedule.fromMap(data, classDoc.id);
      final List<String> attendeeIds = freshClass.attendees;
      List<Map<String, String>> attendees = [];

      for (String userId in attendeeIds) {
        try {
          DocumentSnapshot userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .get();

          if (userDoc.exists && userDoc.data() != null) {
            final userData = userDoc.data() as Map<String, dynamic>;
            String name = userData['name'] ?? userData['email'] ?? 'Unknown User';
            attendees.add({'name': name, 'userId': userId});
          }
        } catch (e) {
          log('Error fetching attendee $userId: $e');
        }
      }

      if (!mounted) return;
      setState(() {
        _attendees = attendees;
        _isAttending = attendeeIds.contains(_currentUser.uid);
        _sessionLabel = freshClass.sessionDateLabel;
        _isLoading = false;
      });
    } catch (e) {
      log('Error loading class details: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleAttendance() async {
    setState(() => _isLoading = true);

    final error = await _scheduleService.toggleAttendance(
      widget.classSchedule.classId,
      _currentUser.uid,
    );

    if (error != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update attendance: $error')),
      );
    }

    await _loadClassDetails();
  }

  @override
  Widget build(BuildContext context) {
    final String dayText = _sessionLabel.isEmpty
        ? widget.classSchedule.day
        : '${widget.classSchedule.day}, $_sessionLabel';

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
                          dayText,
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