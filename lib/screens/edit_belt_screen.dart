import 'package:flutter/material.dart';

class EditBeltDialog extends StatefulWidget {
  final String rank;
  final DateTime promotionDate;
  final String notes;
  final List<String> availableBelts; // e.g., ['White', 'Blue', 'Purple', ...]

  const EditBeltDialog({
    required this.rank,
    required this.promotionDate,
    required this.notes,
    required this.availableBelts,
  });

  @override
  State<EditBeltDialog> createState() => _EditBeltDialogState();
}

class _EditBeltDialogState extends State<EditBeltDialog> {
  late String selectedRank;
  late DateTime selectedDate;
  late TextEditingController notesController;

  @override
  void initState() {
    super.initState();
    selectedRank = widget.rank;
    selectedDate = widget.promotionDate;
    notesController = TextEditingController(text: widget.notes);
  }

  @override
  void dispose() {
    notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Belt Rank'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Belt Level Dropdown
            DropdownButtonFormField<String>(
              value: selectedRank,
              items: widget.availableBelts
                  .map((belt) => DropdownMenuItem(
                value: belt,
                child: Text(belt),
              ))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  selectedRank = value ?? selectedRank;
                });
              },
              decoration: const InputDecoration(
                labelText: 'Belt Level',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // Promotion Date Picker
            ListTile(
              title: const Text('Promotion Date'),
              subtitle: Text(
                '${selectedDate.month}/${selectedDate.day}/${selectedDate.year}',
              ),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final pickedDate = await showDatePicker(
                  context: context,
                  initialDate: selectedDate,
                  firstDate: DateTime(2000),
                  lastDate: DateTime.now(),
                );
                if (pickedDate != null) {
                  setState(() {
                    selectedDate = pickedDate;
                  });
                }
              },
            ),
            const SizedBox(height: 16),

            // Notes Text Field
            TextField(
              controller: notesController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                border: OutlineInputBorder(),
                hintText: 'Add any notes about this promotion...',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context, {
              'rank': selectedRank,
              'promotionDate': selectedDate,
              'notes': notesController.text,
            });
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}