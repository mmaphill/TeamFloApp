import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/journal_service.dart';
import '../models/journal_entry_model.dart';
import '../config/colors.dart ';
import '../widgets/belt_rank_badge.dart';
import 'journal_entry_screen.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({Key? key}) : super(key: key);

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  final JournalService _journalService = JournalService();
  final User _currentUser = FirebaseAuth.instance.currentUser!;

  late DateTime _selectedMonth;
  late Map<DateTime, JournalEntry?> _entriesByDate;

  @override
  void initState() {
    super.initState();
    _selectedMonth = DateTime.now();
    _entriesByDate = {};
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Training Journal'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _openJournalEntry(DateTime.now()),
          ),
        ],
      ),
      body: Column(
        children: [
          // Month/Year header with navigation
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () {
                    setState(() {
                      _selectedMonth =
                          DateTime(_selectedMonth.year, _selectedMonth.month - 1);
                    });
                  },
                ),
                Text(
                  DateFormat('MMMM yyyy').format(_selectedMonth),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () {
                    setState(() {
                      _selectedMonth =
                          DateTime(_selectedMonth.year, _selectedMonth.month + 1);
                    });
                  },
                ),
              ],
            ),
          ),

          // Calendar grid
          Expanded(
            child: StreamBuilder<List<JournalEntry>>(
              stream: _journalService.getUserJournalStream(_currentUser.uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                // Build map of entries by date
                Map<DateTime, JournalEntry> entriesMap = {};
                if (snapshot.hasData) {
                  for (var entry in snapshot.data!) {
                    DateTime dateKey =
                    DateTime(entry.date.year, entry.date.month, entry.date.day);
                    entriesMap[dateKey] = entry;
                  }
                }

                return _buildCalendar(entriesMap);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendar(Map<DateTime, JournalEntry> entries) {
    int firstDay = DateTime(_selectedMonth.year, _selectedMonth.month, 1).weekday;
    int daysInMonth =
        DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0).day;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Column(
        children: [
          // Day headers
          Row(
            children: ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
                .map((day) => Expanded(
              child: Text(
                day,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ))
                .toList(),
          ),
          const SizedBox(height: 8),

          // Calendar days
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                childAspectRatio: 1,
              ),
              itemCount: firstDay + daysInMonth,
              itemBuilder: (context, index) {
                if (index < firstDay) {
                  return const SizedBox(); // Empty cell
                }

                int day = index - firstDay + 1;
                DateTime cellDate =
                DateTime(_selectedMonth.year, _selectedMonth.month, day);
                DateTime dateKey =
                DateTime(cellDate.year, cellDate.month, cellDate.day);

                bool hasEntry = entries.containsKey(dateKey);
                bool isToday = DateTime.now().difference(dateKey).inDays == 0;

                return GestureDetector(
                  onTap: () => _openJournalEntry(cellDate),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isToday
                          ? AppColors.primary.withOpacity(0.2)
                          : hasEntry
                          ? Colors.grey.shade800
                          : Colors.transparent,
                      border: isToday
                          ? Border.all(color: AppColors.primary, width: 2)
                          : null,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Day number
                        Text(
                          day.toString(),
                          style: TextStyle(
                            fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                            fontSize: 16,
                          ),
                        ),

                        // Entry indicator dot
                        if (hasEntry)
                          Positioned(
                            bottom: 4,
                            child: Container(
                              width: 4,
                              height: 4,
                              decoration: const BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _openJournalEntry(DateTime date) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => JournalEntryScreen(
          userId: _currentUser.uid,
          date: date,
        ),
      ),
    );
  }
}