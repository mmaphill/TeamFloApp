import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:team_flo_app/services/analytics_service.dart';
import 'package:team_flo_app/widgets/submission_counter_widget.dart';
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
  final AnalyticsService _analyticsService = AnalyticsService();
  final User _currentUser = FirebaseAuth.instance.currentUser!;
  final JournalService _journalService = JournalService();
  final ScheduleService _scheduleService = ScheduleService();
  final StorageService _storageService = StorageService();
  final ImagePicker _picker = ImagePicker();

  late JournalEntry _entry;
  late UserModel _userData;
  late List<String> _allTechniques = [];
  File? _selectedPhoto;
  bool _isLoading = true;
  String? _notesError;
  String? _contentError;

  late TextEditingController _techniqueController;
  late TextEditingController _submissionsController;
  late TextEditingController _submissionAttemptsController;
  late TextEditingController _timesSubmittedController;
  late TextEditingController _notesController;

  final List<String> positions = [
    'Closed Guard',
    'Spider Guard',
    'Lasso Guard',
    'Open Guard',
    'Half Guard',
    'De La Riva',
    'X Guard',
    'Single-leg X',
    'Side Control',
    'Mount',
    'Back Control',
    'Back Mount',
    '3/4 Mount',
    'Knee on Belly',
    'North-South',
  ];

  final List<String> types = ['Pass', 'Escape', 'Retention', 'Sweep', 'Submission',];

  Map<String, List<String>> _techniques = {}; // {'Pass': ['Knee Slice'], etc}

  @override
  void initState() {
    super.initState();
    _techniqueController = TextEditingController();
    _submissionsController = TextEditingController();
    _submissionAttemptsController = TextEditingController();
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
    _loadGymTechniques();
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
        _techniqueController.text = existing.techniques.toString();
        _submissionsController.text = existing.submissions.toString();
        _submissionAttemptsController.text = existing.submissionAttempts.toString();
        _timesSubmittedController.text = existing.timesSubmitted.toString();
        _notesController.text = existing.generalNotes;
      } else {
        _entry = JournalEntry(
          entryId: '',
          userId: widget.userId,
          date: widget.date,
          createdAt: DateTime.now(),
        );
        _techniqueController.text = '';
        _submissionsController.text = '0';
        _submissionAttemptsController.text = '0';
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

  Future<void> _takePhoto() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.camera);
    if (image != null) {
      setState(() => _selectedPhoto = File(image.path));
    }
  }

  Future<void> _saveEntry() async {
    setState(() => _isLoading = true);

    String? photoUrl = _entry.photoUrl;

    // Upload photo if selected
    if (_selectedPhoto != null) {
      photoUrl = await _storageService.uploadJournalImage(_selectedPhoto!, widget.userId);
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
      types: _entry.types,
      techniques: _techniques,  // ← ADD THIS LINE
      submissions: _entry.submissions,
      submissionAttempts: _entry.submissionAttempts,
      timesSubmitted: _entry.timesSubmitted,
      generalNotes: ValidationService.sanitizeContent(_entry.generalNotes),
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

  void _addTechnique(String typeSelected, String techniqueName) {
    if (techniqueName.isEmpty) return;

    final normalized = techniqueName.trim().toLowerCase();

    setState(() {
      if (!_techniques.containsKey(typeSelected)) {
        _techniques[typeSelected] = [];
      }
      if (!_techniques[typeSelected]!.contains(normalized)) {
        _techniques[typeSelected]!.add(normalized);
      }
      _techniqueController.clear();
    });
  }

  void _removeTechnique(String typeSelected, String techniqueName) {
    setState(() {
      _techniques[typeSelected]?.remove(techniqueName);
      if (_techniques[typeSelected]?.isEmpty ?? false) {
        _techniques.remove(typeSelected);
      }
    });
  }

  Future<void> _loadGymTechniques() async {
    try {
      final techniques = await _analyticsService.getAllTechniquesFromGym();
      print('Loaded ${techniques.length} gym techniques');
      print('Techniques: $techniques');
      setState(() {
        _allTechniques = techniques;
      });
    } catch (e) {
      print('Error loading gym techniques: $e');
    }
  }

  @override
  void dispose() {
    _submissionsController.dispose();
    _submissionAttemptsController.dispose();
    _timesSubmittedController.dispose();
    _notesController.dispose();
    _techniqueController.dispose();
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
          if (_entry.entryId.isNotEmpty)  // Only show if entry is saved
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () => _showDeleteDialog(),
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
                    onPressed: _takePhoto,
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

            // Energy slider
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
                types: _entry.types,
                submissions: _entry.submissions,
                timesSubmitted: _entry.timesSubmitted,
                generalNotes: _entry.generalNotes,
                createdAt: _entry.createdAt,
              ));
            }),

            // Sleep Slider
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
                types: _entry.types,
                submissions: _entry.submissions,
                timesSubmitted: _entry.timesSubmitted,
                generalNotes: _entry.generalNotes,
                createdAt: _entry.createdAt,
              ));
            }),

            // Water Slider
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
                types: _entry.types,
                submissions: _entry.submissions,
                timesSubmitted: _entry.timesSubmitted,
                generalNotes: _entry.generalNotes,
                createdAt: _entry.createdAt,
              ));
            }),

            // Food Slider
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
                types: _entry.types,
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
                  types: _entry.types,
                  submissions: _entry.submissions,
                  timesSubmitted: _entry.timesSubmitted,
                  generalNotes: _entry.generalNotes,
                  createdAt: _entry.createdAt,
                ));
              },
            ),
            const SizedBox(height: 12),

            // Type dropdown
            const Text('Type', style: TextStyle(fontWeight: FontWeight.bold)),
            DropdownButtonFormField<String>(
              initialValue: _entry.types,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              items: types
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
                  types: val,
                  submissions: _entry.submissions,
                  timesSubmitted: _entry.timesSubmitted,
                  generalNotes: _entry.generalNotes,
                  createdAt: _entry.createdAt,
                ));
              },
            ),
            const SizedBox(height: 12),

            // Technique input with autocomplete
            const Text('Add Techniques', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Autocomplete<String>(
                    optionsBuilder: (TextEditingValue textEditingValue) {
                      return _analyticsService.suggestTechniques(
                        _allTechniques,
                        textEditingValue.text,
                      );
                    },
                    onSelected: (String selection) {
                      _addTechnique(_entry.types!, selection);
                    },
                    fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                      _techniqueController = textEditingController;
                      return TextField(
                        controller: textEditingController,
                        focusNode: focusNode,
                        decoration: InputDecoration(
                          hintText: 'e.g., Armbar, Knee Slice',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _entry.types != null
                      ? () => _addTechnique(_entry.types!, _techniqueController.text)
                      : null,
                  child: const Text('Add'),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Display techniques by type
            if (_techniques.isNotEmpty)
              ..._techniques.entries.map((entry) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(entry.key, style: Theme.of(context).textTheme.labelSmall),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 8,
                        children: entry.value.map((technique) {
                          return Chip(
                            label: Text(technique),
                            onDeleted: () => _removeTechnique(entry.key, technique),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                );
              }).toList(),

            // Submission Counter Widget
            SubmissionCounterWidget(
              initialSuccessful: _entry.submissions,
              initialAttempted: _entry.submissionAttempts,
              initialTimesSubmitted: _entry.timesSubmitted,
              onChanged: (successful, submissionAttempts, timesSubmitted) {
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
                  types: _entry.types,
                  submissions: successful,
                  submissionAttempts: submissionAttempts,
                  timesSubmitted: timesSubmitted,
                  generalNotes: _entry.generalNotes,
                  createdAt: _entry.createdAt,
                ));
              },
            ),

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
                    types: _entry.types,
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
                    types: _entry.types,
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

  void _showDeleteDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Entry?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _deleteEntry();
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteEntry() async {
    setState(() => _isLoading = true);

    String? error = await _journalService.deleteJournalEntry(
      widget.userId,
      _entry.entryId,
    );

    setState(() => _isLoading = false);

    if (error == null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Entry deleted')),
      );
      Navigator.pop(context);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $error')),
      );
    }
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<UserModel>('_userData', _userData));
  }
}