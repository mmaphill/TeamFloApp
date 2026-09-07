import 'package:flutter/material.dart';

class SubmissionCounterWidget extends StatefulWidget {
  final int initialSuccessful;
  final int initialAttempted;
  final int initialTimesSubmitted;
  final Function(int submissions, int submissionAttempts, int timesSubmitted) onChanged;

  const SubmissionCounterWidget({
    super.key,
    required this.initialSuccessful,
    required this.initialAttempted,
    required this.initialTimesSubmitted,
    required this.onChanged,
  });

  @override
  State<SubmissionCounterWidget> createState() => _SubmissionCounterWidgetState();
}

class _SubmissionCounterWidgetState extends State<SubmissionCounterWidget> {
  late int submissions;
  late int attempted;
  late int timesSubmitted;

  @override
  void initState() {
    super.initState();
    submissions = widget.initialSuccessful;
    attempted = widget.initialAttempted;
    timesSubmitted = widget.initialTimesSubmitted;
  }

  void _updateParent() {
    widget.onChanged(submissions, attempted, timesSubmitted);
  }

  void _incrementSubmissions() {
    setState(() {
      submissions++;
      _updateParent();
    });
  }

  void _decrementSubmissions() {
    setState(() {
      if (submissions > 0) submissions--;
      _updateParent();
    });
  }

  void _incrementTimesSubmitted() {
    setState(() {
      timesSubmitted++;
      _updateParent();
    });
  }

  void _decrementTimesSubmitted() {
    setState(() {
      if (timesSubmitted > 0) timesSubmitted--;
      _updateParent();
    });
  }

  void _incrementAttempted() {
    setState(() {
      attempted++;
      _updateParent();
    });
  }

  void _decrementAttempted() {
    setState(() {
      attempted--;
      _updateParent();
    });
  }

  Widget _buildCounter({
    required String label,
    required String description,
    required int value,
    required VoidCallback onIncrement,
    required VoidCallback onDecrement,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          description,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.6),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Theme.of(context).dividerColor),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.remove),
                onPressed: onDecrement,
                iconSize: 20,
              ),
              SizedBox(
                width: 50,
                child: Center(
                  child: Text(
                    '$value',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: onIncrement,
                iconSize: 20,
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Submissions',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),

        // Successful Submissions
        _buildCounter(label: 'Submissions', description: 'Successful Submissions', value: submissions, onIncrement: _incrementSubmissions, onDecrement: _decrementSubmissions),
        const SizedBox(height: 16),

        // Attempted Sumbissions
        _buildCounter(label: 'Attempted', description: 'Total Attempted Submissions', value: attempted, onIncrement: _incrementAttempted, onDecrement: _decrementAttempted),
        const SizedBox(height: 16),

        // Times Submitted
        _buildCounter(label: 'Submitted', description: 'Times Submitted by Opponent', value: timesSubmitted, onIncrement: _incrementTimesSubmitted, onDecrement: _decrementTimesSubmitted),
        const SizedBox(height: 16),
      ],
    );
  }
}