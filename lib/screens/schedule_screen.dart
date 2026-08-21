import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/schedule_service.dart';
import '../models/class_schedule_model.dart';
import '../config/colors.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  final ScheduleService _scheduleService = ScheduleService();
  final User _currentUser = FirebaseAuth.instance.currentUser!;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<List<ClassSchedule>>(
        stream: _scheduleService.getClassesStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No classes scheduled'));
          }

          List<ClassSchedule> allClasses = snapshot.data!;

          // Group classes by day
          Map<String, List<ClassSchedule>> classesByDay = {};
          for (var classSchedule in allClasses) {
            if (!classesByDay.containsKey(classSchedule.day)) {
              classesByDay[classSchedule.day] = [];
            }
            classesByDay[classSchedule.day]!.add(classSchedule);
          }

          // Sort days of week
          List<String> dayOrder = [
            'Sunday',
            'Monday',
            'Tuesday',
            'Wednesday',
            'Thursday',
            'Friday',
            'Saturday'
          ];
          List<String> sortedDays = dayOrder
              .where((day) => classesByDay.containsKey(day))
              .toList();

          return ListView.builder(
            itemCount: sortedDays.length,
            itemBuilder: (context, index) {
              String day = sortedDays[index];
              List<ClassSchedule> dayClasses = classesByDay[day]!;

              // Sort classes by start time
              dayClasses.sort((a, b) {
                return _timeToMinutes(a.startTime)
                    .compareTo(_timeToMinutes(b.startTime));
              });

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Day Header
                  Padding(
                    padding:
                    const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text(
                      day,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  // Classes for this day
                  ...dayClasses.map((classSchedule) =>
                      _buildClassCard(classSchedule)),

                  const Divider(height: 24),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildClassCard(ClassSchedule classSchedule) {
    bool isAttending =
    classSchedule.attendees.contains(_currentUser.uid);
    Color classColor = _getClassColor(classSchedule.classType);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            // Left color bar
            Container(
              width: 4,
              height: 80,
              color: classColor,
            ),
            const SizedBox(width: 12),

            // Class info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    classSchedule.className,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    '${classSchedule.startTime} - ${classSchedule.endTime}',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                  Text(
                    'Instructor: ${classSchedule.instructor}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  Text(
                    'Attendees: ${classSchedule.attendees.length}/${classSchedule.capacity}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),

            // Attend button
            GestureDetector(
              onTap: () => _scheduleService.toggleAttendance(
                classSchedule.classId,
                _currentUser.uid,
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isAttending
                      ? AppColors.primary
                      : Colors.grey.shade700,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isAttending ? 'Attending' : 'Join',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getClassColor(String classType) {
    switch (classType) {
      case 'Gi All Levels':
        return AppColors.primary; // Red
      case 'Gi Fundamentals':
        return const Color(0xFFFFA500); // Orange
      case 'Gi Kids':
        return const Color(0xFF2196F3); // Blue
      case 'No Gi':
      case 'Open Mat':
        return const Color(0xFF4CAF50); // Green
      case 'Women Only':
        return const Color(0xFF9C27B0); // Purple
      default:
        return Colors.grey;
    }
  }

  int _timeToMinutes(String time) {
    // Convert "6:00 AM" to minutes since midnight
    final parts = time.split(':');
    int hour = int.parse(parts[0]);
    int minute = int.parse(parts[1].split(' ')[0]);
    String period = time.contains('PM') ? 'PM' : 'AM';

    if (period == 'PM' && hour != 12) {
      hour += 12;
    } else if (period == 'AM' && hour == 12) {
      hour = 0;
    }

    return hour * 60 + minute;
  }
}