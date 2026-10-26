import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../models/app_roles.dart';
import '../models/belt_rank_model.dart';
import '../models/competition_stats_model.dart';
import 'gym_scope.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Stream to listen to auth state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Sign up with email and password.
  // Every new account starts as a member. Staff roles are given later by
  // an owner or manager through the setUserRole Cloud Function, so the app
  // can never be used to sign yourself up as staff.
  Future<String?> signup({
    required String email,
    required String password,
    required String name,
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
        'role': AppRoles.member,
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
      // Only owners and managers may edit other members.
      // ('admin' on older Team Flo accounts counts as owner.)
      String? currentRole = await getUserRole(_auth.currentUser!.uid);
      if (!AppRoles.canManageMembers(currentRole)) {
        return 'Only owners and managers can edit other members';
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

  // Delete user account and all associated data
  Future<String?> deleteAccount(String uid) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        return 'No user logged in';
      }

      // PHASE 1 STEP 4: the user document is now deleted LAST (below).
      // The security rules read it to know which gym the user is in, so
      // the posts and journal cleanup must happen while it still exists.

      // Delete user's posts
      // PHASE 1 STEP 3: from this gym's posts (GymScope).
      final postsQuery = await GymScope.col('posts')
          .where('userId', isEqualTo: uid)
          .get();
      for (var doc in postsQuery.docs) {
        await doc.reference.delete();
      }

      // Delete user's journal entries
      final journalQuery = await _firestore
          .collection('users')
          .doc(uid)
          .collection('journal')
          .get();
      for (var doc in journalQuery.docs) {
        await doc.reference.delete();
      }

      // Delete user document from Firestore (last, see note above)
      await _firestore.collection('users').doc(uid).delete();

      // Delete user files from Storage
      final profilePath = 'profiles/$uid';
      final postsPath = 'posts/$uid';
      final journalPath = 'journals/$uid';

      try {
        final profileList = await _storage.ref(profilePath).listAll();
        for (var file in profileList.items) {
          await file.delete();
        }
      } catch (e) {
        // Directory might not exist
      }

      try {
        final postsList = await _storage.ref(postsPath).listAll();
        for (var file in postsList.items) {
          await file.delete();
        }
      } catch (e) {
        // Directory might not exist
      }

      try {
        final journalList = await _storage.ref(journalPath).listAll();
        for (var file in journalList.items) {
          await file.delete();
        }
      } catch (e) {
        // Directory might not exist
      }

      // Delete Firebase Auth user
      await user.delete();

      return null; // Success
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> updateBeltRank(
      String uid,
      int beltIndex,
      String newRank,
      DateTime newPromotionDate,
      String notes,
      ) async {
    try {
      // Fetch current belt history
      final userDoc = await _firestore.collection('users').doc(uid).get();
      final List<dynamic> beltRankHistory = userDoc['beltRankHistory'] ?? [];

      // Update the specific belt entry
      if (beltIndex >= 0 && beltIndex < beltRankHistory.length) {
        beltRankHistory[beltIndex] = {
          'rank': newRank,
          'promotionDate': newPromotionDate,
          'notes': notes,
        };

        // Write back to Firestore
        await _firestore.collection('users').doc(uid).update({
          'beltRankHistory': beltRankHistory,
        });

        return null; // No error
      } else {
        return 'Invalid belt index';
      }
    } catch (e) {
      return 'Error updating belt rank: $e';
    }
  }

  Future<String?> updateProfileFields(
      String uid,
      Map<String, dynamic> fields,
      ) async {
    try {
      await _firestore.collection('users').doc(uid).update(fields);
      return null; // successful update
    } catch (e) {
      return e.toString();
    }
  }
}