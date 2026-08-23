import 'package:flutter/material.dart';
import '../models/class_schedule_model.dart';
import '../services/schedule_service.dart';
import '../config/colors.dart';
import 'class_detail_screen.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  final ScheduleService _scheduleService = ScheduleService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<List<ClassSchedule>>(
        stream: _scheduleService.getUpcomingClassesStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No upcoming classes'));
          }

          List<ClassSchedule> upcomingClasses = snapshot.data!;

          // Group by day
          Map<String, List<ClassSchedule>> groupedByDay = {};
          for (var classSchedule in upcomingClasses) {
            if (!groupedByDay.containsKey(classSchedule.day)) {
              groupedByDay[classSchedule.day] = [];
            }
            groupedByDay[classSchedule.day]!.add(classSchedule);
          }

          return ListView(
            padding: const EdgeInsets.all(16.0),
            children: groupedByDay.entries.map((entry) {
              String day = entry.key;
              List<ClassSchedule> dayClasses = entry.value;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    day,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...dayClasses.map((classSchedule) =>
                      _buildClassCard(classSchedule)),
                  const SizedBox(height: 24),
                ],
              );
            }).toList(),
          );
        },
      ),
    );
  }

  Widget _buildClassCard(ClassSchedule classSchedule) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                ClassDetailScreen(classSchedule: classSchedule),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              classSchedule.className,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${classSchedule.startTime} - ${classSchedule.endTime}',
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${classSchedule.attendees.length}/${classSchedule.capacity}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}