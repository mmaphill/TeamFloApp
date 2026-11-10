import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/app_roles.dart';
import '../models/gym_model.dart';
import '../utils/log.dart';

/// Loads the signed-in user's gym and role, and keeps them up to date.
///
/// Flow: Auth user -> users/{uid} (gymId,role) -> gyms/{gymId}
///
/// Provided app-wide in main.dart Widgets read it with `context.watch<GymService()>`
/// services that have no BuildContext use `GymService.instance`.
class GymService extends ChangeNotifier {
  GymService._();
  static final GymService instance = GymService._();

  /// Fallback used by GymScope when no gym is loaded. Since the step 7
  /// migration and invite-only access, an account with no gymId is shown
  /// the "Waiting for an invite" screen, so GymScope isn't used then.
  static const String legacyGymId = 'teamflo';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  StreamSubscription<User?>? _authSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _userSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _gymSub;

  String? _gymId;
  String _role = AppRoles.member;
  GymModel? _gym;
  bool _isLoaded = false;
  String? _error;
  bool _needsInvite = false;

  /// Public Read-Only State
  String? get gymId => _gymId;
  GymModel? get gym => _gym;
  String get role => _role;
  bool get isLoaded => _isLoaded;
  String? get error => _error;

  /// INVITES: true when the signed-in account has no gym yet. The app shows
  /// the "Waiting for an invite" screen instead of the gym. Flips to false
  /// on its own when staff invite this email (a Cloud Function sets gymId).
  bool get needsInvite => _needsInvite;

  bool get isStaff => AppRoles.isStaff(_role);

  // True when this gym's data lives under gyms/{gymId}/
  bool get dataScoped => _gym?.dataScoped ?? false;

  /// True if the gym has [module] turned on and returns false until that gym has loaded
  bool hasModule(String module) => _gym?.hasModule(module) ?? false;

  /// Lifecycle

  /// Call once from main.dart. Safe to call more than once.
  void start() {
    _authSub ??= FirebaseAuth.instance.authStateChanges().listen(_onAuthChanged);
  }

  void _onAuthChanged(User? user) {
    _userSub?.cancel();
    _gymSub?.cancel();
    _userSub = null;
    _gymSub = null;

    if (user == null) {
      _reset();
      notifyListeners();
      return;
    }

    _isLoaded = false;
    notifyListeners();

    _userSub = _firestore.collection('users').doc(user.uid).snapshots().listen(
          (snapshot) => _onUserDoc(user, snapshot),
      onError: (Object e) => _fail('Could not load your account: $e'),
    );
  }

  void _onUserDoc(User user, DocumentSnapshot<Map<String, dynamic>> snapshot) {
    final data = snapshot.data();

    if (data == null) return;

    // INVITES: no gymId means this account hasn't been invited yet.
    // (was: defaulted to Team Flo)
    final String? newGymId = data['gymId'] as String?;
    final String newRole = AppRoles.normalize(data['role'] as String?);
    final bool roleChanged = newRole != _role;
    _role = newRole;

    if (newGymId == null || newGymId.isEmpty) {
      _gymSub?.cancel();
      _gymSub = null;
      _gymId = null;
      _gym = null;
      _error = null;
      _needsInvite = true;
      _isLoaded = true;
      notifyListeners();
      return;
    }
    _needsInvite = false;

    /// Role or gym changed on the server: the cloud Function updates the user's custom claim
    if (roleChanged || newGymId != _gymId) {
      user.getIdToken(true).catchError((Object e) {
        log('Token refresh failed: $e');
        return null;
      });
    }

    if (newGymId == _gymId) {
      notifyListeners(); // roles may have changed
      return;
    }

    _gymId = newGymId;
    // Show the loading screen until the new gym's settings arrive (matters
    // when a waiting account is invited and joins a gym while the app is open).
    _isLoaded = false;
    notifyListeners();
    _gymSub?.cancel();
    _gymSub = _firestore.collection('gyms').doc(newGymId).snapshots().listen(
          (gymSnap) {
        final gymData = gymSnap.data();
        if (gymData == null) {
          _fail('Gym "$newGymId" was not found');
          return;
        }
        _gym = GymModel.fromMap(gymSnap.id, gymData);
        _error = null;
        _isLoaded = true;
        notifyListeners();
      },
      onError: (Object e) => _fail('Could not load gym settings: $e'),
    );
  }

  void _fail(String message) {
    log(message);
    _error = message;
    _isLoaded = true;
    notifyListeners();
  }

  void _reset() {
    _gymId = null;
    _gym = null;
    _role = AppRoles.member;
    _isLoaded = false;
    _error = null;
    _needsInvite = false;
  }

  @override
  void dispose () {
    _authSub?.cancel();
    _userSub?.cancel();
    _gymSub?.cancel();
    super.dispose();
  }
}