import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import '../models/belt_rank_model.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/journal_service.dart';
import '../services/schedule_service.dart';
import '../services/storage_service.dart';
import '../models/journal_entry_model.dart';
import '../models/class_schedule_model.dart';
import '../config/colors.dart';
import '../services/validation_service.dart';
import '../widgets/belt_rank_badge.dart';

class JournalEntryScreen extends StatefulWidget {
  final String userId;
  final DateTime date;

  const JournalEntryScreen({
    super.key,
    required this.userId,
    required this.date,
  });

  @override
  State<JournalEntryScreen> createState() => _JournalEntryScreenState();
}

class _JournalEntryScreenState extends State<JournalEntryScreen> {
  final AuthService _authService = AuthService();
  final User _currentUser = FirebaseAuth.instance.currentUser!;
  final JournalService _journalService = JournalService();
  final ScheduleService _scheduleService = ScheduleService();
  final StorageService _storageService = StorageService();
  final ImagePicker _picker = ImagePicker();

  late JournalEntry _entry;
  late UserModel _userData;
  File? _selectedPhoto;
  bool _isLoading = true;
  String? _notesError;
  String? _contentError;

  late TextEditingController _submissionsController;
  late TextEditingController _timesSubmittedController;
  late TextEditingController _notesController;

  final List<String> positions = [
    'Closed Guard',
    'Spider Guard',
    'Open Guard',
    'Half Guard',
    'Side Control',
    'Mount',
    'Back Control',
    'Back Mount',
    '3/4 Mount',
    'Knee on Belly',
    'North-South',
  ];

  final List<String> techniques = ['Pass', 'Escape', 'Retention', 'Sweep', 'Submit',];

  @override
  void initState() {
    super.initState();
    _submissionsController = TextEditingController();
    _timesSubmittedController = TextEditingController();
    _notesController = TextEditingController();
    _notesError = null;
    _contentError = null;

    _userData = UserModel(
      uid: '',
      email: '',
      name: '',
      role: '',
      createdAt: DateTime.now(),
    );

    _loadUserData();

    _loadEntry();
  }

  Future<void> _loadUserData() async {
    final data = await _authService.getUserData(_currentUser.uid);
    if (data != null) {
      UserModel user = UserModel.fromMap(data);

      // Set currentBelt to the most recent belt rank
      String? currentBelt;
      if (user.beltRankHistory.isNotEmpty) {
        // Sort by date and get the latest
        List<BeltRank> sorted = List.from(user.beltRankHistory);
        sorted.sort((a, b) => b.promotionDate.compareTo(a.promotionDate));
        currentBelt = sorted.first.rank;
      }

      setState(() {
        _userData = UserModel(
          uid: user.uid,
          email: user.email,
          name: user.name,
          role: user.role,
          createdAt: user.createdAt,
          beltRankHistory: user.beltRankHistory,
          goals: user.goals,
          competitionStats: user.competitionStats,
          photoUrl: user.photoUrl,
          avatarColor: user.avatarColor,
          currentBelt: currentBelt,
        );
      });
    }
  }

  Future<void> _loadEntry() async {
    final existing = await _journalService.getJournalEntry(widget.userId, widget.date);

    setState(() {
      if (existing != null) {
        _entry = existing;
        _submissionsController.text = existing.submissions.toString();
        _timesSubmittedController.text = existing.timesSubmitted.toString();
        _notesController.text = existing.generalNotes;
      } else {
        _entry = JournalEntry(
          entryId: '',
          userId: widget.userId,
          date: widget.date,
          createdAt: DateTime.now(),
        );
        _submissionsController.text = '0';
        _timesSubmittedController.text = '0';
        _notesController.text = '';
      }
      _isLoading = false;
    });
  }

  Future<void> _pickPhoto() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() => _selectedPhoto = File(image.path));
    }
  }

  Future<void> _saveEntry() async {
    setState(() => _isLoading = true);

    String? photoUrl = _entry.photoUrl;

    // Upload photo if selected
    if (_selectedPhoto != null) {
      photoUrl = await _storageService.uploadImage(_selectedPhoto!, widget.userId);
    }

    _entry = JournalEntry(
      entryId: _entry.entryId,
      userId: widget.userId,
      date: widget.date,
      photoUrl: photoUrl,
      classesAttended: _entry.classesAttended,
      energy: _entry.energy,
      sleep: _entry.sleep,
      water: _entry.water,
      food: _entry.food,
      position: _entry.position,
      technique: _entry.technique,
      submissions: _entry.submissions,
      timesSubmitted: _entry.timesSubmitted,
      generalNotes: _entry.generalNotes,
      createdAt: _entry.createdAt,
      updatedAt: DateTime.now(),
    );

    String? error = await _journalService.saveJournalEntry(_entry);

    setState(() => _isLoading = false);

    if (error == null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Entry saved successfully!')),
      );
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _submissionsController.dispose();
    _timesSubmittedController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Training Journal')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.dark,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: BeltRankBadge(beltRank: _userData.currentBelt, width: 180, height: 180,),
          ),
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: (_notesError != null || _contentError != null) ? null : _saveEntry,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Photo section
            const Text('Photo (Optional)',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (_selectedPhoto != null)
              Stack(
                children: [
                  Image.file(_selectedPhoto!, height: 200, fit: BoxFit.cover),
                  Positioned(
                    top: 0,
                    right: 0,
                    child: IconButton(
                      style: IconButton.styleFrom(
                        backgroundColor: const Color(0xFF3A3A3A),
                        foregroundColor: AppColors.light,
                      ),
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => setState(() => _selectedPhoto = null),
                    ),
                  ),
                ],
              )
            else if (_entry.photoUrl != null)
              Image.network(_entry.photoUrl!, height: 200, fit: BoxFit.cover)
            else
              Container(
                height: 100,
                color: Colors.grey.shade800,
                child: Center(
                  child: IconButton(
                    icon: const Icon(Icons.add_a_photo),
                    onPressed: _pickPhoto,
                  ),
                ),
              ),
            const SizedBox(height: 8),
            if (_selectedPhoto == null && _entry.photoUrl == null)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.add_photo_alternate),
                  label: const Text('Add Photo'),
                  onPressed: _pickPhoto,
                ),
              ),
            const SizedBox(height: 24),

            // Classes attended
            const Text('Classes Attended',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _buildClassSelector(),
            const SizedBox(height: 24),

            // Metrics section
            const Text('Daily Metrics',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _buildMetricSlider('Energy', _entry.energy, (val) {
              setState(() => _entry = JournalEntry(
                entryId: _entry.entryId,
                userId: _entry.userId,
                date: _entry.date,
                photoUrl: _entry.photoUrl,
                classesAttended: _entry.classesAttended,
                energy: val,
                sleep: _entry.sleep,
                water: _entry.water,
                food: _entry.food,
                position: _entry.position,
                technique: _entry.technique,
                submissions: _entry.submissions,
                timesSubmitted: _entry.timesSubmitted,
                generalNotes: _entry.generalNotes,
                createdAt: _entry.createdAt,
              ));
            }),
            _buildMetricSlider('Sleep', _entry.sleep, (val) {
              setState(() => _entry = JournalEntry(
                entryId: _entry.entryId,
                userId: _entry.userId,
                date: _entry.date,
                photoUrl: _entry.photoUrl,
                classesAttended: _entry.classesAttended,
                energy: _entry.energy,
                sleep: val,
                water: _entry.water,
                food: _entry.food,
                position: _entry.position,
                technique: _entry.technique,
                submissions: _entry.submissions,
                timesSubmitted: _entry.timesSubmitted,
                generalNotes: _entry.generalNotes,
                createdAt: _entry.createdAt,
              ));
            }),
            _buildMetricSlider('Water', _entry.water, (val) {
              setState(() => _entry = JournalEntry(
                entryId: _entry.entryId,
                userId: _entry.userId,
                date: _entry.date,
                photoUrl: _entry.photoUrl,
                classesAttended: _entry.classesAttended,
                energy: _entry.energy,
                sleep: _entry.sleep,
                water: val,
                food: _entry.food,
                position: _entry.position,
                technique: _entry.technique,
                submissions: _entry.submissions,
                timesSubmitted: _entry.timesSubmitted,
                generalNotes: _entry.generalNotes,
                createdAt: _entry.createdAt,
              ));
            }),
            _buildMetricSlider('Food', _entry.food, (val) {
              setState(() => _entry = JournalEntry(
                entryId: _entry.entryId,
                userId: _entry.userId,
                date: _entry.date,
                photoUrl: _entry.photoUrl,
                classesAttended: _entry.classesAttended,
                energy: _entry.energy,
                sleep: _entry.sleep,
                water: _entry.water,
                food: val,
                position: _entry.position,
                technique: _entry.technique,
                submissions: _entry.submissions,
                timesSubmitted: _entry.timesSubmitted,
                generalNotes: _entry.generalNotes,
                createdAt: _entry.createdAt,
              ));
            }),
            const SizedBox(height: 24),

            // Training data section
            const Text('Training Data',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),

            // Position dropdown
            const Text('Position', style: TextStyle(fontWeight: FontWeight.bold)),
            DropdownButtonFormField<String>(
              initialValue: _entry.position,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              items: positions
                  .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                  .toList(),
              onChanged: (val) {
                setState(() => _entry = JournalEntry(
                  entryId: _entry.entryId,
                  userId: _entry.userId,
                  date: _entry.date,
                  photoUrl: _entry.photoUrl,
                  classesAttended: _entry.classesAttended,
                  energy: _entry.energy,
                  sleep: _entry.sleep,
                  water: _entry.water,
                  food: _entry.food,
                  position: val,
                  technique: _entry.technique,
                  submissions: _entry.submissions,
                  timesSubmitted: _entry.timesSubmitted,
                  generalNotes: _entry.generalNotes,
                  createdAt: _entry.createdAt,
                ));
              },
            ),
            const SizedBox(height: 12),

            // Technique dropdown
            const Text('Technique', style: TextStyle(fontWeight: FontWeight.bold)),
            DropdownButtonFormField<String>(
              initialValue: _entry.technique,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              items: techniques
                  .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                  .toList(),
              onChanged: (val) {
                setState(() => _entry = JournalEntry(
                  entryId: _entry.entryId,
                  userId: _entry.userId,
                  date: _entry.date,
                  photoUrl: _entry.photoUrl,
                  classesAttended: _entry.classesAttended,
                  energy: _entry.energy,
                  sleep: _entry.sleep,
                  water: _entry.water,
                  food: _entry.food,
                  position: _entry.position,
                  technique: val,
                  submissions: _entry.submissions,
                  timesSubmitted: _entry.timesSubmitted,
                  generalNotes: _entry.generalNotes,
                  createdAt: _entry.createdAt,
                ));
              },
            ),
            const SizedBox(height: 12),

            // Submissions count
            const Text('Submissions', style: TextStyle(fontWeight: FontWeight.bold)),
            TextField(
              controller: _submissionsController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                hintText: 'Number of submissions',
              ),
              onChanged: (val) {
                setState(() => _entry = JournalEntry(
                  entryId: _entry.entryId,
                  userId: _entry.userId,
                  date: _entry.date,
                  photoUrl: _entry.photoUrl,
                  classesAttended: _entry.classesAttended,
                  energy: _entry.energy,
                  sleep: _entry.sleep,
                  water: _entry.water,
                  food: _entry.food,
                  position: _entry.position,
                  technique: _entry.technique,
                  submissions: int.tryParse(val) ?? 0,
                  timesSubmitted: _entry.timesSubmitted,
                  generalNotes: _entry.generalNotes,
                  createdAt: _entry.createdAt,
                ));
              },
            ),
            const SizedBox(height: 12),

            // Times submitted count
            const Text('Times Submitted', style: TextStyle(fontWeight: FontWeight.bold)),
            TextField(
              controller: _timesSubmittedController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                hintText: 'Number of times submitted',
              ),
              onChanged: (val) {
                setState(() => _entry = JournalEntry(
                  entryId: _entry.entryId,
                  userId: _entry.userId,
                  date: _entry.date,
                  photoUrl: _entry.photoUrl,
                  classesAttended: _entry.classesAttended,
                  energy: _entry.energy,
                  sleep: _entry.sleep,
                  water: _entry.water,
                  food: _entry.food,
                  position: _entry.position,
                  technique: _entry.technique,
                  submissions: _entry.submissions,
                  timesSubmitted: int.tryParse(val) ?? 0,
                  generalNotes: _entry.generalNotes,
                  createdAt: _entry.createdAt,
                ));
              },
            ),
            const SizedBox(height: 12),

            // General notes
            const Text('General Notes', style: TextStyle(fontWeight: FontWeight.bold)),
            TextField(
              controller: _notesController,
              textCapitalization: TextCapitalization.sentences,
              maxLines: 4,
              decoration: InputDecoration(
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                hintText: 'Notes about your training...',
              ),
              onChanged: (val) {
                setState(() {
                  _notesError = ValidationService.validateLength(val, 0, 1000, 'Notes');
                  _contentError = ValidationService.validateContent(val);
                  _entry = JournalEntry(
                    entryId: _entry.entryId,
                    userId: _entry.userId,
                    date: _entry.date,
                    photoUrl: _entry.photoUrl,
                    classesAttended: _entry.classesAttended,
                    energy: _entry.energy,
                    sleep: _entry.sleep,
                    water: _entry.water,
                    food: _entry.food,
                    position: _entry.position,
                    technique: _entry.technique,
                    submissions: _entry.submissions,
                    timesSubmitted: _entry.timesSubmitted,
                    generalNotes: val,
                    createdAt: _entry.createdAt,);
                  }
                );
              },
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricSlider(
      String label, int value, Function(int) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                value == 0 ? '-' : value.toString(),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        Slider(
          value: value.toDouble(),
          min: 0,
          max: 5,
          divisions: 5,
          label: value == 0 ? 'Not set' : value.toString(),
          onChanged: (val) => onChanged(val.toInt()),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildClassSelector() {
    return StreamBuilder<List<ClassSchedule>>(
      stream: _scheduleService.getClassesStream(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Text('Loading classes...');
        }

        List<ClassSchedule> classes = snapshot.data!;

        // Remove duplicates by classId
        final Map<String, ClassSchedule> uniqueClasses ={};
        for (var classSchedule in classes) {
          uniqueClasses[classSchedule.className] = classSchedule;
        }
        classes = uniqueClasses.values.toList();

        return Wrap(
          spacing: 8,
          children: classes.map((classSchedule) {
            bool isSelected =
            _entry.classesAttended.contains(classSchedule.classId);

            return FilterChip(
              label: Text(classSchedule.className),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  List<String> updated = List.from(_entry.classesAttended);
                  if (selected) {
                    updated.add(classSchedule.classId);
                  } else {
                    updated.remove(classSchedule.classId);
                  }
                  _entry = JournalEntry(
                    entryId: _entry.entryId,
                    userId: _entry.userId,
                    date: _entry.date,
                    photoUrl: _entry.photoUrl,
                    classesAttended: updated,
                    energy: _entry.energy,
                    sleep: _entry.sleep,
                    water: _entry.water,
                    food: _entry.food,
                    position: _entry.position,
                    technique: _entry.technique,
                    submissions: _entry.submissions,
                    timesSubmitted: _entry.timesSubmitted,
                    generalNotes: _entry.generalNotes,
                    createdAt: _entry.createdAt,
                  );
                });
              },
            );
          }).toList(),
        );
      },
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<UserModel>('_userData', _userData));
  }
}