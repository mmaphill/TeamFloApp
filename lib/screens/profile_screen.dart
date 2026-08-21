import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../services/auth_service.dart';
import '../models/user_model.dart';
import '../models/belt_rank_model.dart';
import '../models/competition_stats_model.dart';
import '../config/colors.dart';
import '../services/storage_service.dart';
import '../widgets/belt_rank_badge.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _authService = AuthService();
  final User _currentUser = FirebaseAuth.instance.currentUser!;

  late UserModel _userData;
  bool _isEditing = false;
  bool _isSaving = false;
  bool _isLoading = false;
  String? _errorMessage;

  // Controllers
  late TextEditingController _nameController;
  late TextEditingController _goalsController;
  late ImagePicker _picker;
  late StorageService _storageService;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _goalsController = TextEditingController();
    _picker = ImagePicker();
    _storageService = StorageService();

    _userData = UserModel(
      uid: '',
      email: '',
      name: '',
      role: '',
      createdAt: DateTime.now(),
    );

    _loadUserData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _goalsController.dispose();
    super.dispose();
  }

  Future<void> _pickAvatarPhoto() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() => _isLoading = true);
      String? photoUrl = await _storageService.uploadImage(
        File(image.path),
        _currentUser.uid,
      );
      setState(() {
        if (photoUrl != null) {
          _userData = UserModel(
            uid: _userData.uid,
            email: _userData.email,
            name: _userData.name,
            role: _userData.role,
            createdAt: _userData.createdAt,
            beltRankHistory: _userData.beltRankHistory,
            goals: _userData.goals,
            competitionStats: _userData.competitionStats,
            photoUrl: photoUrl,
            avatarColor: _userData.avatarColor,
            currentBelt: _userData.currentBelt,
          );
        }
        _isLoading = false;
      });
    }
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
        _nameController.text = _userData!.name;
        _goalsController.text = _userData!.goals;
      });
    }
  }

  Future<void> _saveProfile() async {
    if (_nameController.text.isEmpty) {
      setState(() => _errorMessage = 'Name cannot be empty');
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    // Get current belt from history
    String? currentBelt;
    if (_userData!.beltRankHistory.isNotEmpty) {
      List<BeltRank> sorted = List.from(_userData!.beltRankHistory);
      sorted.sort((a, b) => b.promotionDate.compareTo(a.promotionDate));
      currentBelt = sorted.first.rank;
    }

    String? error = await _authService.updateUserProfile(
      uid: _currentUser.uid,
      name: _nameController.text,
      goals: _goalsController.text,
      beltRankHistory: _userData!.beltRankHistory,
      competitionStats: _userData!.competitionStats,
      photoUrl: _userData!.photoUrl,
      avatarColor: _userData!.avatarColor,
      currentBelt: currentBelt,
    );

    setState(() => _isSaving = false);

    if (error == null) {
      await _loadUserData();
      setState(() => _isEditing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully!')),
        );
      }
    } else {
      setState(() => _errorMessage = error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          if (_userData != null)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: BeltRankBadge(beltRank: _userData.currentBelt, width: 180, height: 180,),
            ),
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => setState(() => _isEditing = true),
            ),
          if (_isEditing)
            TextButton(
              onPressed: _isSaving ? null : _saveProfile,
              child: _isSaving
                  ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
                  : const Text(
                'Save',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      body: _userData == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Error Message
            if (_errorMessage != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _errorMessage!,
                  style: TextStyle(color: Colors.red.shade700),
                ),
              ),
            if (_errorMessage != null) const SizedBox(height: 16),

            // Profile Avatar with Edit Option
            GestureDetector(
              onTap: _isEditing ? () => _showAvatarOptions() : null,
              child: Center(
                child: Stack(
                  children: [
                    if (_userData.photoUrl != null &&
                        _userData.photoUrl!.isNotEmpty)
                    // Photo avatar
                      CircleAvatar(
                        radius: 50,
                        backgroundImage:
                        NetworkImage(_userData.photoUrl!),
                      )
                    else
                    // Color avatar with initial
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: Color(int.parse(
                          _userData.avatarColor
                              .replaceFirst('#', '0xff'),
                        )),
                        child: Text(
                          _userData.name.isNotEmpty
                              ? _userData.name[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            fontSize: 40,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    if (_isEditing)
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.blue,
                            shape: BoxShape.circle,
                            border:
                            Border.all(color: Colors.white, width: 2),
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.edit,
                                color: Colors.white, size: 18),
                            onPressed: () => _showAvatarOptions(),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Name Field
            const Text(
              'Full Name',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              enabled: _isEditing,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Email (Read-only)
            const Text(
              'Email',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(_userData.email),
            ),
            const SizedBox(height: 24),

            // Role (Read-only)
            const Text(
              'Role',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _userData.role.toUpperCase(),
                style: TextStyle(
                  color: _userData.role == 'admin'
                      ? Colors.red
                      : Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Belt Rank History
            const Text(
              'Belt Rank History',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            if (_userData.beltRankHistory.isEmpty)
              const Text('No belt promotions yet')
            else
              Column(
                children: _userData.beltRankHistory
                    .asMap()
                    .entries
                    .map((entry) {
                  int index = entry.key;
                  BeltRank rank = entry.value;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment:
                      MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment:
                          CrossAxisAlignment.start,
                          children: [
                            Text(
                              rank.rank,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              DateFormat('MMM d, yyyy')
                                  .format(rank.promotionDate),
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                        if (_isEditing)
                          IconButton(
                            icon: const Icon(Icons.delete, size: 18),
                            onPressed: () {
                              setState(() {
                                _userData.beltRankHistory
                                    .removeAt(index);
                              });
                            },
                          ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            if (_isEditing)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('Add Belt Rank'),
                  onPressed: () => _showAddBeltRankDialog(),
                ),
              ),
            const SizedBox(height: 24),

            // Goals Section
            const Text(
              'Goals',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _goalsController,
              enabled: _isEditing,
              maxLines: 4,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                hintText: 'Enter your training goals...',
              ),
            ),
            const SizedBox(height: 24),

            // Competition Stats
            const Text(
              'Competition Stats',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            if (_userData.competitionStats.isEmpty)
              const Text('No competition records yet')
            else
              Column(
                children: _userData.competitionStats
                    .asMap()
                    .entries
                    .map((entry) {
                  int index = entry.key;
                  CompetitionStats stats = entry.value;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment:
                              CrossAxisAlignment.start,
                              children: [
                                Text(
                                  stats.format,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                Text(
                                  stats.rank,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                            if (_isEditing)
                              IconButton(
                                icon: const Icon(Icons.delete, size: 18),
                                onPressed: () {
                                  setState(() {
                                    _userData.competitionStats
                                        .removeAt(index);
                                  });
                                },
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment:
                          MainAxisAlignment.spaceAround,
                          children: [
                            Column(
                              children: [
                                const Text('Wins',
                                    style: TextStyle(fontSize: 12)),
                                Text(
                                  '${stats.totalWins}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            Column(
                              children: [
                                const Text('Losses',
                                    style: TextStyle(fontSize: 12)),
                                Text(
                                  '${stats.totalLosses}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            Column(
                              children: [
                                const Text('Win Rate',
                                    style: TextStyle(fontSize: 12)),
                                Text(
                                  stats.totalWins +
                                      stats.totalLosses ==
                                      0
                                      ? '0%'
                                      : '${((stats.totalWins / (stats.totalWins + stats.totalLosses)) * 100).toStringAsFixed(1)}%',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'By: Sub ${stats.submissionWins}W/${stats.submissionLosses}L | Pts ${stats.pointWins}W/${stats.pointLosses}L | Ref ${stats.refDecisionWins}W/${stats.refDecisionLosses}L',
                          style: const TextStyle(fontSize: 11),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            if (_isEditing)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('Add Competition Record'),
                  onPressed: () =>
                      _showAddCompetitionStatsDialog(),
                ),
              ),
            if (_isEditing) ...[
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveProfile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                      ),
                      child: _isSaving
                          ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                          AlwaysStoppedAnimation<Color>(
                              Colors.white),
                        ),
                      )
                          : const Text(
                        'Save',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () =>
                          setState(() => _isEditing = false),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey.shade700,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showAddBeltRankDialog() {
    String? selectedRank;
    DateTime selectedDate = DateTime.now();

    final belts = [
      'White',
      'Blue',
      'Purple',
      'Brown',
      'Black',
      'Coral Belt',
      'Red-Coral Belt',
      'Red Belt'
    ];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Add Belt Rank'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: selectedRank,
                decoration: const InputDecoration(labelText: 'Belt Rank'),
                items: belts
                    .map((b) => DropdownMenuItem(value: b, child: Text(b)))
                    .toList(),
                onChanged: (val) => setState(() => selectedRank = val),
              ),
              const SizedBox(height: 16),
              ListTile(
                title: const Text('Promotion Date'),
                subtitle: Text(DateFormat('MMM d, yyyy').format(selectedDate)),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: selectedDate,
                    firstDate: DateTime(2000),
                    lastDate: DateTime.now(),
                  );
                  if (date != null) {
                    setState(() => selectedDate = date);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: selectedRank == null
                  ? null
                  : () {
                this.setState(() {
                  _userData.beltRankHistory.add(
                    BeltRank(
                      rank: selectedRank!,
                      promotionDate: selectedDate,
                    ),
                  );
                });
                Navigator.pop(context);
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddCompetitionStatsDialog() {
    String? selectedFormat = 'Gi';
    String? selectedRank;
    int submissionWins = 0;
    int submissionLosses = 0;
    int pointWins = 0;
    int pointLosses = 0;
    int refWins = 0;
    int refLosses = 0;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Add Competition Record'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: selectedFormat,
                  decoration: const InputDecoration(labelText: 'Format'),
                  items: ['Gi', 'No Gi']
                      .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                      .toList(),
                  onChanged: (val) =>
                      setState(() => selectedFormat = val ?? 'Gi'),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedRank,
                  decoration: const InputDecoration(labelText: 'Rank'),
                  items: (selectedFormat == 'Gi'
                      ? [
                    'White',
                    'Blue',
                    'Purple',
                    'Brown',
                    'Black'
                  ]
                      : ['Beginner', 'Intermediate', 'Advanced'])
                      .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                      .toList(),
                  onChanged: (val) => setState(() => selectedRank = val),
                ),
                const SizedBox(height: 16),
                const Text('Wins by Type',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                _buildNumberField('Submission Wins', submissionWins,
                        (val) => setState(() => submissionWins = val)),
                _buildNumberField('Point Wins', pointWins,
                        (val) => setState(() => pointWins = val)),
                _buildNumberField('Ref Decision Wins', refWins,
                        (val) => setState(() => refWins = val)),
                const SizedBox(height: 16),
                const Text('Losses by Type',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                _buildNumberField('Submission Losses', submissionLosses,
                        (val) => setState(() => submissionLosses = val)),
                _buildNumberField('Point Losses', pointLosses,
                        (val) => setState(() => pointLosses = val)),
                _buildNumberField('Ref Decision Losses', refLosses,
                        (val) => setState(() => refLosses = val)),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: selectedRank == null
                  ? null
                  : () {
                this.setState(() {
                  _userData.competitionStats.add(
                    CompetitionStats(
                      format: selectedFormat!,
                      rank: selectedRank!,
                      submissionWins: submissionWins,
                      submissionLosses: submissionLosses,
                      pointWins: pointWins,
                      pointLosses: pointLosses,
                      refDecisionWins: refWins,
                      refDecisionLosses: refLosses,
                    ),
                  );
                });
                Navigator.pop(context);
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAvatarOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.image),
              title: const Text('Upload Photo'),
              onTap: () {
                Navigator.pop(context);
                _pickAvatarPhoto();
              },
            ),
            ListTile(
              leading: const Icon(Icons.palette),
              title: const Text('Change Color'),
              onTap: () {
                Navigator.pop(context);
                _showColorPicker();
              },
            ),
            if (_userData.photoUrl != null)
              ListTile(
                leading: const Icon(Icons.delete),
                title: const Text('Remove Photo'),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _userData = UserModel(
                      uid: _userData.uid,
                      email: _userData.email,
                      name: _userData.name,
                      role: _userData.role,
                      createdAt: _userData.createdAt,
                      beltRankHistory: _userData.beltRankHistory,
                      goals: _userData.goals,
                      competitionStats: _userData.competitionStats,
                      photoUrl: null,
                      avatarColor: _userData.avatarColor,
                      currentBelt: _userData.currentBelt,
                    );
                  });
                },
              ),
          ],
        ),
      ),
    );
  }

  void _showColorPicker() {
    final colors = [
      '#2196F3', // Blue
      '#F44336', // Red
      '#4CAF50', // Green
      '#FF9800', // Orange
      '#9C27B0', // Purple
      '#00BCD4', // Cyan
      '#FFC107', // Amber
      '#E91E63', // Pink
    ];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choose Avatar Color'),
        content: GridView.count(
          crossAxisCount: 4,
          shrinkWrap: true,
          children: colors.map((color) {
            return GestureDetector(
              onTap: () {
                setState(() {
                  _userData = UserModel(
                    uid: _userData.uid,
                    email: _userData.email,
                    name: _userData.name,
                    role: _userData.role,
                    createdAt: _userData.createdAt,
                    beltRankHistory: _userData.beltRankHistory,
                    goals: _userData.goals,
                    competitionStats: _userData.competitionStats,
                    photoUrl: _userData.photoUrl,
                    avatarColor: color,
                    currentBelt: _userData.currentBelt,
                  );
                });
                Navigator.pop(context);
              },
              child: Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Color(int.parse(color.replaceFirst('#', '0xff'))),
                  shape: BoxShape.circle,
                  border: _userData.avatarColor == color
                      ? Border.all(color: Colors.white, width: 3)
                      : null,
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildNumberField(
      String label, int value, Function(int) onChanged) {
    return Row(
      children: [
        Expanded(child: Text(label)),
        IconButton(
          icon: const Icon(Icons.remove),
          onPressed: value > 0 ? () => onChanged(value - 1) : null,
        ),
        Text(value.toString()),
        IconButton(
          icon: const Icon(Icons.add),
          onPressed: () => onChanged(value + 1),
        ),
      ],
    );
  }
}