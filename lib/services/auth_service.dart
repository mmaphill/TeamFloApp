import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/belt_rank_model.dart';
import '../models/competition_stats_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Stream to listen to auth state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Sign up with email and password
  Future<String?> signup({
    required String email,
    required String password,
    required String name,
    required String role, // 'member' or 'admin'
  }) async {
    try {
      // Create user in Firebase Auth
      UserCredential userCredential = await _auth
          .createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Save user data to Firestore
      await _firestore.collection('users').doc(userCredential.user!.uid).set({
        'uid': userCredential.user!.uid,
        'email': email,
        'name': name,
        'role': role,
        'createdAt': DateTime.now(),
        'privacyPolicyAcknowledged': false,
      });

      return null; // Success
    } on FirebaseAuthException catch (e) {
      return e.message; // Return error message
    }
  }

  // Login with email and password
  Future<String?> login({
    required String email,
    required String password,
  }) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return null; // Success
    } on FirebaseAuthException catch (e) {
      return e.message; // Return error message
    }
  }

  // Logout
  Future<void> logout() async {
    await _auth.signOut();
  }

  // Get user role from Firestore
  Future<String?> getUserRole(String uid) async {
    try {
      DocumentSnapshot doc = await _firestore.collection('users').doc(uid).get();
      return doc['role'] as String?;
    } catch (e) {
      return null;
    }
  }

  // Get user data from Firestore
  Future<Map<String, dynamic>?> getUserData(String uid) async {
    try {
      DocumentSnapshot doc = await _firestore.collection('users').doc(uid).get();
      return doc.data() as Map<String, dynamic>?;
    } catch (e) {
      return null;
    }
  }

  // Update user profile with new data
  Future<String?> updateUserProfile({
    required String uid,
    required String name,
    required String goals,
    required List<BeltRank> beltRankHistory,
    required List<CompetitionStats> competitionStats,
    String? photoUrl,
    required String avatarColor,
    String? currentBelt,
  }) async {
    try {
      await _firestore.collection('users').doc(uid).update({
        'name': name,
        'goals': goals,
        'beltRankHistory': beltRankHistory.map((b) => b.toMap()).toList(),
        'competitionStats': competitionStats.map((c) => c.toMap()).toList(),
        'photoUrl': photoUrl,
        'avatarColor': avatarColor,
        'currentBelt': currentBelt,
      });
      return null; // Success
    } catch (e) {
      return e.toString();
    }
  }

  // Update another user's profile (admin only)
  Future<String?> updateUserProfileAsAdmin({
    required String targetUid,
    required String name,
    required String goals,
    required List<BeltRank> beltRankHistory,
    required List<CompetitionStats> competitionStats,
  }) async {
    try {
      // Check if current user is admin
      String? currentRole = await getUserRole(_auth.currentUser!.uid);
      if (currentRole != 'admin') {
        return 'Only admins can edit other users';
      }

      await _firestore.collection('users').doc(targetUid).update({
        'name': name,
        'goals': goals,
        'beltRankHistory': beltRankHistory.map((b) => b.toMap()).toList(),
        'competitionStats': competitionStats.map((c) => c.toMap()).toList(),
      });
      return null; // Success
    } catch (e) {
      return e.toString();
    }
  }

  // Privacy Policy Acknowledgement
  Future<String?> acknowledgePrivacyPolicy(String uid) async {
    try {
      await _firestore.collection('users').doc(uid).update({
        'privacyPolicyAcknowledged': true,
      });
      return null;
    } catch (e) {
      return e.toString();
    }
  }
}