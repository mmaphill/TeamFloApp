import 'package:flutter/material.dart';

class SubmissionListInput extends StatefulWidget {
  final int count;
  final List<String> initialValues;
  final ValueChanged<List<String>> onChanged;

  const SubmissionListInput({
    super.key,
    required this.count,
    required this.onChanged,
    this.initialValues = const [],
  });

  @override
  State<SubmissionListInput> createState() => _SubmissionListInputState();
}

class _SubmissionListInputState extends State<SubmissionListInput> {
  final List<TextEditingController> _controllers = [];

  @override
  void initState() {
    super.initState();
    _syncControllers(widget.count, widget.initialValues);
  }

  @override
  void didUpdateWidget(covariant SubmissionListInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.count != widget.count) {
      _syncControllers(widget.count, const []);
      WidgetsBinding.instance.addPostFrameCallback((_) => _notify());
    }
  }

  void _syncControllers(int count, List<String> seed) {
    final target = count < 0 ? 0 : count;

    while (_controllers.length < target) {
      final index = _controllers.length;
      final text = index < seed.length ? seed[index] : '';
      _controllers.add(TextEditingController(text: text));
    }

    while (_controllers.length > target) {
      _controllers.removeLast().dispose();
    }
  }

  void _notify() {
    widget.onChanged(_controllers.map((c) => c.text).toList());
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controllers.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Successful Submission (optional)',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        for (int i = 0; i < _controllers.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: TextField(
              controller: _controllers[i],
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: 'Submission ${i + 1}',
                hintText: 'e.g. Armbar',
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (_) => _notify(),
            ),
          ),
      ],
    );
  }
}