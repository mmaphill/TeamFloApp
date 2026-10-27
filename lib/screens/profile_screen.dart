import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:team_flo_app/screens/privacy_policy_screen.dart';
import '../models/photo_crop_model.dart';
import '../services/auth_service.dart';
import '../models/user_model.dart';
import '../models/belt_rank_model.dart';
import '../models/competition_stats_model.dart';
import '../config/colors.dart';
import '../services/storage_service.dart';
import '../services/validation_service.dart';
import 'crop_photo_screen.dart';
import '../config/theme_provider.dart';
import 'package:provider/provider.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _authService = AuthService();
  final User _currentUser = FirebaseAuth.instance.currentUser!;

  late UserModel _userData;
  bool _isLoading = false;
  String? _errorMessage;

  // Controllers
  late ImagePicker _picker;
  late StorageService _storageService;

  @override
  void initState() {
    super.initState();
    _picker = ImagePicker();
    _storageService = StorageService();
    _errorMessage = null;

    // Initialize with default
    _userData = UserModel(
      uid: '',
      email: '',
      name: '',
      role: 'member',
      createdAt: DateTime.now(),
    );

    _loadUserData();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _pickAvatarPhoto() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      if (mounted) {
        // Navigate to crop screen
        final result = await Navigator.push<Map<String, dynamic>>(
          context,
          MaterialPageRoute(
            builder: (context) => CropPhotoScreen(
              imageFile: File(image.path),
            ),
          ),
        );

        if (result != null) {
          setState(() => _isLoading = true);

          // Upload the cropped image (not the original)
          String? photoUrl = await _storageService.uploadProfileImage(
            result['croppedFile'] as File,
            _currentUser.uid,
          );

          setState(() {
            if (photoUrl != null) {
              _userData = _userData.copyWith(
                photoUrl: photoUrl,
                photoCropData: PhotoCropData(),
              );
            }
            _isLoading = false;
          });
        }
      }
    }
  }

  Future<void> _loadUserData() async {
    try {
      final data = await _authService.getUserData(_currentUser.uid);

      if (data == null) {
        debugPrint('PROFILE: no user document found for ${_currentUser.uid}');
        if (mounted) {
          setState(() => _errorMessage = 'Could not load your profile.');
        }
        return;
      }

      final user = UserModel.fromMap(data);
      debugPrint('PROFILE: loaded uid="${user.uid}", name="${user.name}"');

      // Set currentBelt to the most recent belt rank
      String? currentBelt;
      if (user.beltRankHistory.isNotEmpty) {
        final sorted = List<BeltRank>.from(user.beltRankHistory);
        sorted.sort((a, b) => b.promotionDate.compareTo(a.promotionDate));
        currentBelt = sorted.first.rank;
      }

      if (!mounted) return;
      setState(() {
        _userData = user.copyWith(currentBelt: currentBelt);
      });
    } catch (e, stack) {
      debugPrint('PROFILE: error loading user data: $e\n$stack');
      if (mounted) {
        setState(() => _errorMessage = 'Error loading profile: $e');
      }
    }
  }

  // ============ Edit Name Dialog ============
  void _showEditNameDialog() {
    final controller = TextEditingController(text: _userData.name);
    String? error;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit Name'),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: 'Enter your name',
              errorText: error,
              border: OutlineInputBorder(),
            ),
            onChanged: (value) {
              setDialogState(() {
                error = null;
              });
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (controller.text.isEmpty) {
                  setDialogState(() {
                    error = 'Name cannot be empty';
                  });
                  return;
                }

                Navigator.pop(context);
                await _saveName(controller.text);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveName(String newName) async {
    setState(() => _isLoading = true);

    String? currentBelt;
    if (_userData.beltRankHistory.isNotEmpty) {
      List<BeltRank> sorted = List.from(_userData.beltRankHistory);
      sorted.sort((a, b) => b.promotionDate.compareTo(a.promotionDate));
      currentBelt = sorted.first.rank;
    }

    String? error = await _authService.updateUserProfile(
      uid: _currentUser.uid,
      name: ValidationService.sanitizeName(newName),
      goals: _userData.goals,
      beltRankHistory: _userData.beltRankHistory,
      competitionStats: _userData.competitionStats,
      photoUrl: _userData.photoUrl,
      avatarColor: _userData.avatarColor,
      currentBelt: currentBelt,
    );

    setState(() => _isLoading = false);

    if (error == null) {
      await _loadUserData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Name updated!')),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $error')),
        );
      }
    }
  }

  // ============ Edit Date of Birth ===========
  Future<void> _showEditDobDialog() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _userData.dob ?? DateTime(2000, 1, 1),
      firstDate: DateTime(1930),
      lastDate: DateTime.now(),
      helpText: 'Select your date of birth',
    );

    if (picked == null) return; // user cancelled

    setState(() => _isLoading = true);

    String? error = await _authService.updateProfileFields(
      _currentUser.uid,
      {'dob': picked},
    );

    if (!mounted) return;

    if (error == null) {
      setState(() {
        _userData = _userData.copyWith(dob: picked);
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Date of birth updated')),
      );
    } else {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $error')),
      );
    }
  }
  
  // ============ Show Age Toggle ============
  Future<void> _setShowAge(bool value) async {
    final previous = _userData.showAge;

    // Flip the switch right away so it feels instant
    setState(() {
      _userData = _userData.copyWith(showAge: value);
      _isLoading = true;
    });

    String? error = await _authService.updateProfileFields(
      _currentUser.uid,
      {'showAge': value},
    );

    if (!mounted) return;

    setState(() {
      _isLoading = false;
      if (error != null) {
        // Save failed, so put the switch back
        _userData = _userData.copyWith(showAge: previous);
      }
    });

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $error')),
      );
    }
  }

  // ============ Edit Email Dialog ============
  void _showEditEmailDialog() {
    final controller = TextEditingController(text: _userData.email);
    String? error;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit Email'),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: 'Enter your email',
              errorText: error,
              border: OutlineInputBorder(),
            ),
            onChanged: (value) {
              setDialogState(() {
                error = null;
              });
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (controller.text.isEmpty) {
                  setDialogState(() {
                    error = 'Email cannot be empty';
                  });
                  return;
                }

                Navigator.pop(context);
                await _saveEmail(controller.text);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveEmail(String newEmail) async {
    setState(() => _isLoading = true);

    String? currentBelt;
    if (_userData.beltRankHistory.isNotEmpty) {
      List<BeltRank> sorted = List.from(_userData.beltRankHistory);
      sorted.sort((a, b) => b.promotionDate.compareTo(a.promotionDate));
      currentBelt = sorted.first.rank;
    }

    String? error = await _authService.updateUserProfile(
      uid: _currentUser.uid,
      name: _userData.name,
      goals: _userData.goals,
      beltRankHistory: _userData.beltRankHistory,
      competitionStats: _userData.competitionStats,
      photoUrl: _userData.photoUrl,
      avatarColor: _userData.avatarColor,
      currentBelt: currentBelt,
    );

    setState(() => _isLoading = false);

    if (error == null) {
      // Update Firebase Auth email
      try {
        await _currentUser.verifyBeforeUpdateEmail(newEmail);
        await _loadUserData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Email updated! Check for verification link.')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error updating email: $e')),
          );
        }
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $error')),
        );
      }
    }
  }

  // ============ Edit Goals Dialog ============
  void _showEditGoalsDialog() {
    final controller = TextEditingController(text: _userData.goals);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Goals'),
        content: TextField(
          controller: controller,
          maxLines: 4,
          decoration: InputDecoration(
            hintText: 'Enter your goals',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _saveGoals(controller.text);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveGoals(String newGoals) async {
    setState(() => _isLoading = true);

    String? currentBelt;
    if (_userData.beltRankHistory.isNotEmpty) {
      List<BeltRank> sorted = List.from(_userData.beltRankHistory);
      sorted.sort((a, b) => b.promotionDate.compareTo(a.promotionDate));
      currentBelt = sorted.first.rank;
    }

    String? error = await _authService.updateUserProfile(
      uid: _currentUser.uid,
      name: _userData.name,
      goals: ValidationService.sanitizeContent(newGoals),
      beltRankHistory: _userData.beltRankHistory,
      competitionStats: _userData.competitionStats,
      photoUrl: _userData.photoUrl,
      avatarColor: _userData.avatarColor,
      currentBelt: currentBelt,
    );

    setState(() => _isLoading = false);

    if (error == null) {
      await _loadUserData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Goals updated!')),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $error')),
        );
      }
    }
  }

  // ============ Add Belt Rank Dialog ============
  void _showAddBeltDialog() {
    final rankController = TextEditingController();
    DateTime selectedDate = DateTime.now();
    final notesController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add Belt Rank'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Belt Level Dropdown
                DropdownButtonFormField<String>(
                  initialValue: rankController.text.isEmpty ? 'White' : rankController.text,
                  items: ['White', 'Blue', 'Purple', 'Brown', 'Black']
                      .map((belt) => DropdownMenuItem(
                    value: belt,
                    child: Text(belt),
                  ))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      rankController.text = value;
                    }
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
                    DateFormat('MMM d, yyyy').format(selectedDate),
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
                      setDialogState(() {
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
              onPressed: () async {
                Navigator.pop(context);
                await _addBeltRank(
                  rankController.text,
                  selectedDate,
                  notesController.text,
                );
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addBeltRank(
      String newRank,
      DateTime promotionDate,
      String notes,
      ) async {
    setState(() => _isLoading = true);

    // Create new belt entry
    List<BeltRank> updatedBelts = List.from(_userData.beltRankHistory);
    updatedBelts.add(BeltRank(
      rank: newRank,
      promotionDate: promotionDate,
      notes: notes.isEmpty ? null : notes,
    ));

    String? currentBelt;
    if (updatedBelts.isNotEmpty) {
      List<BeltRank> sorted = List.from(updatedBelts);
      sorted.sort((a, b) => b.promotionDate.compareTo(a.promotionDate));
      currentBelt = sorted.first.rank;
    }

    String? error = await _authService.updateUserProfile(
      uid: _currentUser.uid,
      name: _userData.name,
      goals: _userData.goals,
      beltRankHistory: updatedBelts,
      competitionStats: _userData.competitionStats,
      photoUrl: _userData.photoUrl,
      avatarColor: _userData.avatarColor,
      currentBelt: currentBelt,
    );

    setState(() => _isLoading = false);

    if (error == null) {
      await _loadUserData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Belt rank added!')),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $error')),
        );
      }
    }
  }

  // ============ Edit Belt Rank Dialog ============
  void _showEditBeltDialog(int beltIndex) {
    if (beltIndex < 0 || beltIndex >= _userData.beltRankHistory.length) {
      return;
    }

    final belt = _userData.beltRankHistory[beltIndex];
    final rankController = TextEditingController(text: belt.rank);
    DateTime selectedDate = belt.promotionDate;
    final notesController = TextEditingController(text: belt.notes ?? '');

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit Belt Rank'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Belt Level Dropdown
                DropdownButtonFormField<String>(
                  initialValue: rankController.text,
                  items: ['White', 'Blue', 'Purple', 'Brown', 'Black']
                      .map((belt) => DropdownMenuItem(
                    value: belt,
                    child: Text(belt),
                  ))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      rankController.text = value;
                    }
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
                    DateFormat('MMM d, yyyy').format(selectedDate),
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
                      setDialogState(() {
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
              onPressed: () async {
                Navigator.pop(context);
                await _saveBeltRank(
                  beltIndex,
                  rankController.text,
                  selectedDate,
                  notesController.text,
                );
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveBeltRank(
      int beltIndex,
      String newRank,
      DateTime newPromotionDate,
      String notes,
      ) async {
    setState(() => _isLoading = true);

    String? error = await _authService.updateBeltRank(
      _currentUser.uid,
      beltIndex,
      newRank,
      newPromotionDate,
      notes,
    );

    setState(() => _isLoading = false);

    if (error == null) {
      await _loadUserData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Belt rank updated!')),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error)),
        );
      }
    }
  }

  // ============ Edit Competition Stats Dialog ============
  void _showEditCompStatsDialog(int statsIndex) {
    if (statsIndex < 0 || statsIndex >= _userData.competitionStats.length) {
      return;
    }

    final stat = _userData.competitionStats[statsIndex];
    final compNameController = TextEditingController(text: stat.compName);
    String format = stat.format;
    const placeOptions = ['1st', '2nd', '3rd', 'N/A'];
    String place = placeOptions.contains(stat.place) ? stat.place : 'N/A';
    final rankOptions = format == 'Gi'
      ? ['White', 'Blue', 'Purple', 'Brown', 'Black']
      : ['Beginner', 'Intermediate', 'Advanced'];
    String rank = rankOptions.contains(stat.place) ? stat.place : 'N/A';
    int submissionWins = stat.submissionWins;
    int submissionLosses = stat.submissionLosses;
    int pointWins = stat.pointWins;
    int pointLosses = stat.pointLosses;
    int refDecisionWins = stat.refDecisionWins;
    int refDecisionLosses = stat.refDecisionLosses;
    int draws = stat.draws;
    DateTime selectedDate = stat.compDate;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit Competition Stats'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: compNameController,
                  decoration: const InputDecoration(
                    labelText: 'Competition Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                // Format dropdown
                DropdownButtonFormField<String>(
                  initialValue: format,
                  decoration: const InputDecoration(
                    labelText: 'Format',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Gi', child: Text('Gi')),
                    DropdownMenuItem(value: 'No-Gi', child: Text('No-Gi')),
                  ],
                  onChanged: (value) {
                    setDialogState(() {
                      format = value ?? 'Gi';
                      // Reset rank to valid option for new format
                      rank = format == 'Gi' ? 'White' : 'Beginner';
                    });
                  },
                ),
                const SizedBox(height: 12),
                // Rank dropdown (conditional)
                DropdownButtonFormField<String>(
                  initialValue: rank,
                  decoration: const InputDecoration(
                    labelText: 'Rank',
                    border: OutlineInputBorder(),
                  ),
                  items: (format == 'Gi'
                      ? ['White', 'Blue', 'Purple', 'Brown', 'Black']
                      : ['Beginner', 'Intermediate', 'Advanced'])
                      .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                      .toList(),
                  onChanged: (value) {
                    setDialogState(() => rank = value ?? rank);
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: place,
                  decoration: const InputDecoration(
                    labelText: 'Place',
                    border: OutlineInputBorder(),
                  ),
                  items: placeOptions
                    .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                    .toList(),
                  onChanged: (value) {
                    setDialogState(() => place = value ?? 'NA');
                  },
                ),
                const SizedBox(height: 16),
                // Date Picker
                ListTile(
                  title: const Text('Competition Date'),
                  subtitle: Text(
                    DateFormat('MMM d, yyyy').format(selectedDate),
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
                      setDialogState(() {
                        selectedDate = pickedDate;
                      });
                    }
                  },
                ),
                const SizedBox(height: 16),
                _buildNumberField('Submission Wins', submissionWins, (val) {
                  setDialogState(() => submissionWins = val);
                }),
                _buildNumberField('Submission Losses', submissionLosses, (val) {
                  setDialogState(() => submissionLosses = val);
                }),
                _buildNumberField('Point Wins', pointWins, (val) {
                  setDialogState(() => pointWins = val);
                }),
                _buildNumberField('Point Losses', pointLosses, (val) {
                  setDialogState(() => pointLosses = val);
                }),
                _buildNumberField('Ref Decision Wins', refDecisionWins, (val) {
                  setDialogState(() => refDecisionWins = val);
                }),
                _buildNumberField('Ref Decision Losses', refDecisionLosses, (val) {
                  setDialogState(() => refDecisionLosses = val);
                }),
                _buildNumberField('Draws', draws, (val) {
                  setDialogState(() => draws = val);
                }),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (compNameController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Competition name required')),
                  );
                  return;
                }
                Navigator.pop(context);
                await _updateCompStats(
                  statsIndex,
                  compNameController.text,
                  format,
                  rank,
                  place,
                  selectedDate,
                  submissionWins,
                  submissionLosses,
                  pointWins,
                  pointLosses,
                  refDecisionWins,
                  refDecisionLosses,
                  draws,
                );
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _updateCompStats(
      int statsIndex,
      String compName,
      String format,
      String rank,
      String place,
      DateTime compDate,
      int submissionWins,
      int submissionLosses,
      int pointWins,
      int pointLosses,
      int refDecisionWins,
      int refDecisionLosses,
      int draws,
      ) async {
    setState(() => _isLoading = true);

    List<CompetitionStats> updatedStats = List.from(_userData.competitionStats);
    updatedStats[statsIndex] = CompetitionStats(
      compName: compName,
      format: format,
      rank: rank,
      place: place,
      compDate: compDate,
      submissionWins: submissionWins,
      submissionLosses: submissionLosses,
      pointWins: pointWins,
      pointLosses: pointLosses,
      refDecisionWins: refDecisionWins,
      refDecisionLosses: refDecisionLosses,
      draws: draws,
    );

    String? currentBelt;
    if (_userData.beltRankHistory.isNotEmpty) {
      List<BeltRank> sorted = List.from(_userData.beltRankHistory);
      sorted.sort((a, b) => b.promotionDate.compareTo(a.promotionDate));
      currentBelt = sorted.first.rank;
    }

    String? error = await _authService.updateUserProfile(
      uid: _currentUser.uid,
      name: _userData.name,
      goals: _userData.goals,
      beltRankHistory: _userData.beltRankHistory,
      competitionStats: updatedStats,
      photoUrl: _userData.photoUrl,
      avatarColor: _userData.avatarColor,
      currentBelt: currentBelt,
    );

    setState(() => _isLoading = false);

    if (error == null) {
      await _loadUserData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Competition updated!')),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $error')),
        );
      }
    }
  }

  // ============ Build Widgets ============
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: context.colors.appBar,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text('Profile'),
          bottom: _isLoading
            ? const PreferredSize(
            preferredSize: Size.fromHeight(2),
            child: LinearProgressIndicator(minHeight: 2),
          )
              : null,
        ),
        body: _userData.uid.isEmpty // Add this check
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
                    color: context.colors.errorContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(color: context.colors.onErrorContainer),
                  ),
                ),
              const SizedBox(height: 20),

              // Profile Photo Section
              Center(
                child: GestureDetector(
                  onTap: _pickAvatarPhoto,
                  child: CircleAvatar(
                    radius: 60,
                    backgroundColor: Color(int.parse(
                      _userData.avatarColor.replaceFirst('#', '0xff'),
                    )),
                    backgroundImage: _userData.photoUrl != null
                        ? NetworkImage(_userData.photoUrl!)
                        : null,
                    child: _userData.photoUrl == null
                        ? const Icon(Icons.camera_alt,
                        size: 40, color: AppColors.onPrimary)
                        : null,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: GestureDetector(
                  onTap: _showAvatarColorPicker,
                  child: Text(
                    'Tap avatar to change photo, tap text to change avatar color',
                    textAlign: TextAlign.center,
                    style:
                    TextStyle(fontSize: 12, color: context.colors.textMuted),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Name Section
              _buildEditableField(
                label: 'Name',
                value: _userData.name,
                onTap: _showEditNameDialog,
              ),
              const SizedBox(height: 16),

              // Email Section (editable)
              _buildEditableField(
                label: 'Email',
                value: _userData.email,
                onTap: _showEditEmailDialog,
              ),
              const SizedBox(height: 16),

              // Date of Birth Section (editable)
              _buildEditableField(
                label: 'Date of Birth',
                value: _userData.dob != null
                  ? DateFormat('MMM d, yyyy').format(_userData.dob!)
                  : '(No date of birth set)',
                onTap: _showEditDobDialog,
              ),
              const SizedBox(height: 16),
              
              // Show Age Toggle
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.cake_outlined,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Show my age',
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
                              color: Theme.of(context).textTheme.bodyMedium?.color,
                            ),
                          ),
                          Text(
                            'Other members see your age on your profile',
                            style: TextStyle(fontSize: 12, color: context.colors.textMuted),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _userData.showAge,
                      onChanged: _isLoading ? null : _setShowAge,
                      activeThumbColor: Theme.of(context).colorScheme.primary,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Goals Section
              _buildEditableField(
                label: 'Goals',
                value: _userData.goals.isEmpty ? '(No goals set)' : _userData.goals,
                onTap: _showEditGoalsDialog,
                isMultiline: true,
              ),
              const SizedBox(height: 24),

              // Belt Rank History Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Belt Rank History',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: _showAddBeltDialog,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_userData.beltRankHistory.isEmpty)
                const Text('No belt ranks recorded')
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _userData.beltRankHistory.length,
                  itemBuilder: (context, index) {
                    final belt = _userData.beltRankHistory[index];
                    return GestureDetector(
                      onTap: () => _showEditBeltDialog(index),
                      child: Card(
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        child: ListTile(
                          title: Text(
                            belt.rank,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Text(
                            'Promoted: ${DateFormat('MMM d, yyyy').format(belt.promotionDate)}',
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: AppColors.error),
                            onPressed: () => _deleteBeltRank(index),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              const SizedBox(height: 24),

              // Competition Stats Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Competition Stats',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: _showAddCompStatsDialog,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_userData.competitionStats.isEmpty)
                const Text('No competition stats recorded')
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _userData.competitionStats.length,
                  itemBuilder: (context, index) {
                    final stat = _userData.competitionStats[index];
                    return GestureDetector(
                      onTap: () => _showEditCompStatsDialog(index),
                      child: Card(
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        child: ListTile(
                          title: Text(
                            stat.compName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment:
                            CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${stat.format} • ${stat.rank}',
                              ),
                              Text(
                                'W: ${stat.submissionWins + stat.pointWins + stat.refDecisionWins} | L: ${stat.submissionLosses + stat.pointLosses + stat.refDecisionLosses} | D: ${stat.draws}',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                          trailing: PopupMenuButton(
                            itemBuilder: (context) => [
                              PopupMenuItem(
                                child: const Text('Edit'),
                                onTap: () => _showEditCompStatsDialog(index),
                              ),
                              PopupMenuItem(
                                child: const Text('Delete', style: TextStyle(color: AppColors.error)),
                                onTap: () => _deleteCompStats(index),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              const SizedBox(height: 24),

              // Theme Toggle
              const SizedBox(height: 12),
              Consumer<ThemeProvider>(
                builder: (context, themeProvider, child) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              themeProvider.isDarkMode ? Icons.dark_mode : Icons.light_mode,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              themeProvider.isDarkMode ? 'Dark Mode' : 'Light Mode',
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                fontSize: 14,
                                color: Theme.of(context).textTheme.bodyMedium?.color,
                              ),
                            ),
                          ],
                        ),
                        Switch(
                          value: themeProvider.isDarkMode,
                          onChanged: (value) {
                            themeProvider.setThemeMode(value ? ThemeMode.dark : ThemeMode.light);
                          },
                          activeThumbColor: Theme.of(context).colorScheme.primary,
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),

              // Notifications Toggle
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.notifications_active,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Notifications',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                            color: Theme.of(context).textTheme.bodyMedium?.color,
                          ),
                        ),
                      ],
                    ),
                    Switch(
                      value: _userData.notificationsEnabled,
                      onChanged: (value) async {
                        setState(() => _isLoading = true);

                        await FirebaseFirestore.instance
                            .collection('users')
                            .doc(_currentUser.uid)
                            .update({'notificationsEnabled': value});

                        await _loadUserData();

                        setState(() => _isLoading = false);
                      },
                      activeThumbColor: Theme.of(context).colorScheme.primary,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Privacy Policy
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                      const PrivacyPolicyScreen(),
                    ),
                  );
                },
                child: const Text('Privacy Policy'),
              ),
              const SizedBox(height: 8),

              // Delete Account
              TextButton(
                onPressed: _showDeleteAccountDialog,
                child: const Text(
                  'Delete Account',
                  style: TextStyle(color: AppColors.error),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEditableField({
    required String label,
    required String value,
    required VoidCallback onTap,
    bool isMultiline = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: context.colors.textMuted,
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: context.colors.border),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: 16,
                      color: value.isEmpty || value == '(No goals set)'
                          ? context.colors.textMuted
                          : context.colors.text,
                    ),
                    maxLines: isMultiline ? 3 : 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.edit, size: 18, color: context.colors.textMuted),
              ],
            ),
          ),
        ),
      ],
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

  void _showAvatarColorPicker() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choose Avatar Color'),
        content: SingleChildScrollView(
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              '#2196F3',
              '#FF5722',
              '#4CAF50',
              '#9C27B0',
              '#FF9800',
              '#00BCD4',
              '#E91E63',
              '#795548',
            ]
                .map(
                  (color) => GestureDetector(
                onTap: () {
                  setState(() {
                    _userData = _userData.copyWith(avatarColor: color);
                  });
                  Navigator.pop(context);
                  _saveAvatarColor(color);
                },
                child: Container(
                  margin: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Color(int.parse(color.replaceFirst('#', '0xff'))),
                    shape: BoxShape.circle,
                    border: _userData.avatarColor == color
                        ? Border.all(color: context.colors.text, width: 3)
                        : null,
                  ),
                  width: 50,
                  height: 50,
                ),
              ),
            )
                .toList(),
          ),
        ),
      ),
    );
  }

  void _showAddCompStatsDialog() {
    final compNameController = TextEditingController();
    DateTime selectedDate = DateTime.now();
    String format = 'Gi';
    String? rank = 'White';
    String? place = 'N/A';
    int submissionWins = 0;
    int submissionLosses = 0;
    int pointWins = 0;
    int pointLosses = 0;
    int refDecisionWins = 0;
    int refDecisionLosses = 0;
    int draws = 0;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add Competition'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: compNameController,
                  decoration: const InputDecoration(
                    labelText: 'Competition Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                // Format dropdown
                DropdownButtonFormField<String>(
                  initialValue: format,
                  decoration: const InputDecoration(
                    labelText: 'Format',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Gi', child: Text('Gi')),
                    DropdownMenuItem(value: 'No-Gi', child: Text('No-Gi')),
                  ],
                  onChanged: (value) {
                    setDialogState(() {
                      format = value ?? 'Gi';
                      rank = null; // Reset rank when format changes
                    });
                  },
                ),
                const SizedBox(height: 12),
                // Rank dropdown (changes based on format)
                DropdownButtonFormField<String>(
                  initialValue: rank,
                  decoration: const InputDecoration(
                    labelText: 'Rank',
                    border: OutlineInputBorder(),
                  ),
                  items: (format == 'Gi'
                      ? ['White', 'Blue', 'Purple', 'Brown', 'Black']
                      : ['Beginner', 'Intermediate', 'Advanced'])
                      .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                      .toList(),
                  onChanged: (value) {
                    setDialogState(() {
                      format = value ?? 'Gi';
                      rank = format == 'Gi' ? 'White' : 'Beginner';
                    });
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: place,
                  decoration: const InputDecoration(
                    labelText: 'Place',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: '1st', child: Text('1st')),
                    DropdownMenuItem(value: '2nd', child: Text('2nd')),
                    DropdownMenuItem(value: '3rd', child: Text('3rd')),
                    DropdownMenuItem(value: 'N/A', child: Text('N/A')),
                  ],
                  onChanged: (value) {
                    setDialogState(() {
                      place = value ?? '';
                    });
                  }
                ),
                // Date Picker
                ListTile(
                  title: const Text('Competition Date'),
                  subtitle: Text(
                    DateFormat('MMM d, yyyy').format(selectedDate),
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
                      setDialogState(() {
                        selectedDate = pickedDate;
                      });
                    }
                  },
                ),
                const SizedBox(height: 16),
                _buildNumberField('Submission Wins', submissionWins, (val) {
                  setDialogState(() => submissionWins = val);
                }),
                _buildNumberField('Submission Losses', submissionLosses, (val) {
                  setDialogState(() => submissionLosses = val);
                }),
                _buildNumberField('Point Wins', pointWins, (val) {
                  setDialogState(() => pointWins = val);
                }),
                _buildNumberField('Point Losses', pointLosses, (val) {
                  setDialogState(() => pointLosses = val);
                }),
                _buildNumberField('Ref Decision Wins', refDecisionWins, (val) {
                  setDialogState(() => refDecisionWins = val);
                }),
                _buildNumberField('Ref Decision Losses', refDecisionLosses, (val) {
                  setDialogState(() => refDecisionLosses = val);
                }),
                _buildNumberField('Draws', draws, (val) {
                  setDialogState(() => draws = val);
                }),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (compNameController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Competition name required')),
                  );
                  return;
                }
                Navigator.pop(context);
                await _addCompStats(
                  compNameController.text,
                  format,
                  rank!,
                  place!,
                  selectedDate,
                  submissionWins,
                  submissionLosses,
                  pointWins,
                  pointLosses,
                  refDecisionWins,
                  refDecisionLosses,
                  draws,
                );
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addCompStats(
      String compName,
      String format,
      String rank,
      String place,
      DateTime compDate,
      int submissionWins,
      int submissionLosses,
      int pointWins,
      int pointLosses,
      int refDecisionWins,
      int refDecisionLosses,
      int draws,
      ) async {
    setState(() => _isLoading = true);

    // Create new stats list with the new entry
    List<CompetitionStats> updatedStats = List.from(_userData.competitionStats);

    updatedStats.add(CompetitionStats(
      compName: compName,
      format: format,
      rank: rank,
      place: place,
      compDate: compDate,
      submissionWins: submissionWins,
      submissionLosses: submissionLosses,
      pointWins: pointWins,
      pointLosses: pointLosses,
      refDecisionWins: refDecisionWins,
      refDecisionLosses: refDecisionLosses,
      draws: draws,
    ));

    String? currentBelt;
    if (_userData.beltRankHistory.isNotEmpty) {
      List<BeltRank> sorted = List.from(_userData.beltRankHistory);
      sorted.sort((a, b) => b.promotionDate.compareTo(a.promotionDate));
      currentBelt = sorted.first.rank;
    }

    String? error = await _authService.updateUserProfile(
      uid: _currentUser.uid,
      name: _userData.name,
      goals: _userData.goals,
      beltRankHistory: _userData.beltRankHistory,
      competitionStats: updatedStats,
      photoUrl: _userData.photoUrl,
      avatarColor: _userData.avatarColor,
      currentBelt: currentBelt,
    );

    setState(() => _isLoading = false);

    if (error == null) {
      await _loadUserData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Competition added!')),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $error')),
        );
      }
    }
  }

  Future<void> _saveAvatarColor(String color) async {
    setState(() => _isLoading = true);

    String? currentBelt;
    if (_userData.beltRankHistory.isNotEmpty) {
      List<BeltRank> sorted = List.from(_userData.beltRankHistory);
      sorted.sort((a, b) => b.promotionDate.compareTo(a.promotionDate));
      currentBelt = sorted.first.rank;
    }

    String? error = await _authService.updateUserProfile(
      uid: _currentUser.uid,
      name: _userData.name,
      goals: _userData.goals,
      beltRankHistory: _userData.beltRankHistory,
      competitionStats: _userData.competitionStats,
      photoUrl: _userData.photoUrl,
      avatarColor: _userData.avatarColor,
      currentBelt: currentBelt,
    );

    setState(() => _isLoading = false);

    if (error != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $error')),
      );
    }
  }

  // Delete a competition stat
  Future<void> _deleteCompStats(int statsIndex) async {
    // Confirm deletion
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Competition?'),
        content: Text(
          'Delete "${_userData.competitionStats[statsIndex].compName}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);

    List<CompetitionStats> updatedStats = List.from(_userData.competitionStats);
    updatedStats.removeAt(statsIndex);

    String? currentBelt;
    if (_userData.beltRankHistory.isNotEmpty) {
      List<BeltRank> sorted = List.from(_userData.beltRankHistory);
      sorted.sort((a, b) => b.promotionDate.compareTo(a.promotionDate));
      currentBelt = sorted.first.rank;
    }

    String? error = await _authService.updateUserProfile(
      uid: _currentUser.uid,
      name: _userData.name,
      goals: _userData.goals,
      beltRankHistory: _userData.beltRankHistory,
      competitionStats: updatedStats,
      photoUrl: _userData.photoUrl,
      avatarColor: _userData.avatarColor,
      currentBelt: currentBelt,
    );

    setState(() => _isLoading = false);

    if (error == null) {
      await _loadUserData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Competition deleted')),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $error')),
        );
      }
    }
  }

// Delete a belt rank
  Future<void> _deleteBeltRank(int rankIndex) async {
    // Confirm deletion
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Belt Rank?'),
        content: Text(
          'Delete "${_userData.beltRankHistory[rankIndex].rank}" promotion?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);

    List<BeltRank> updatedRanks = List.from(_userData.beltRankHistory);
    updatedRanks.removeAt(rankIndex);

    // Get the new current belt (most recent after deletion)
    String? currentBelt;
    if (updatedRanks.isNotEmpty) {
      List<BeltRank> sorted = List.from(updatedRanks);
      sorted.sort((a, b) => b.promotionDate.compareTo(a.promotionDate));
      currentBelt = sorted.first.rank;
    }

    String? error = await _authService.updateUserProfile(
      uid: _currentUser.uid,
      name: _userData.name,
      goals: _userData.goals,
      beltRankHistory: updatedRanks,
      competitionStats: _userData.competitionStats,
      photoUrl: _userData.photoUrl,
      avatarColor: _userData.avatarColor,
      currentBelt: currentBelt,
    );

    setState(() => _isLoading = false);

    if (error == null) {
      await _loadUserData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Belt rank deleted')),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $error')),
        );
      }
    }

  }

  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account?'),
        content: const Text(
          'This will permanently delete your account and all your data '
              '(posts, comments, journal entries, photos).\n\n'
              'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _deleteAccount();
            },
            child: const Text('Delete', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAccount() async {
    setState(() => _isLoading = true);

    String? error = await _authService.deleteAccount(_currentUser.uid);

    setState(() => _isLoading = false);

    if (error == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Account deleted successfully')),
        );
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/login',
              (route) => false,
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $error')),
        );
      }
    }
  }
}
