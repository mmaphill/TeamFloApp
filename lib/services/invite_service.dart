import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/log.dart';
import 'gym_service.dart';

/// Status values stored on an invite.
class InviteStatus {
  static const String pending = 'pending'; // waiting for the person to sign up
  static const String used = 'used';       // they signed up and joined the gym
  static const String revoked = 'revoked'; // staff cancelled it
}

/// One invite, as shown in the Staff Portal.
class Invite {
  final String email;
  final String status;
  final String? invitedByName;
  final DateTime? createdAt;
  final DateTime? usedAt;

  Invite({
    required this.email,
    required this.status,
    this.invitedByName,
    this.createdAt,
    this.usedAt,
  });

  factory Invite.fromMap(Map<String, dynamic> data) {
    DateTime? toDate(dynamic v) => v is Timestamp ? v.toDate() : null;
    return Invite(
      email: (data['email'] ?? '').toString(),
      status: (data['status'] ?? InviteStatus.pending).toString(),
      invitedByName: data['invitedByName'] as String?,
      createdAt: toDate(data['createdAt']),
      usedAt: toDate(data['usedAt']),
    );
  }
}

/// Invite-only access. Staff (owner, manager, instructor, front desk)
/// allow an email to join their gym. The person then signs up in the app
/// with that email, and a Cloud Function adds them to the gym.
///
/// Invites live in the top-level `invites` collection with the lowercase
/// email as the document ID, so one email can only have one invite.
class InviteService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _invites =>
      _firestore.collection('invites');

  /// Trimmed and lowercase, the same as the Cloud Function.
  static String normalize(String email) => email.trim().toLowerCase();

  /// Simple format check. Firebase Auth does the real check at signup.
  static bool isValidEmail(String email) =>
      RegExp(r'^[^@\s/]+@[^@\s/]+\.[^@\s/]+$').hasMatch(email);

  /// This gym's invites, newest first.
  Stream<List<Invite>> invitesStream() {
    final gymId = GymService.instance.gymId;
    if (gymId == null) return Stream.value(const <Invite>[]);

    return _invites
        .where('gymId', isEqualTo: gymId)
        .snapshots()
        .map((snapshot) {
      final invites = snapshot.docs.map((d) => Invite.fromMap(d.data())).toList();
      // Sorted here instead of in the query, so no Firestore index is needed.
      invites.sort((a, b) =>
          (b.createdAt ?? DateTime(2100)).compareTo(a.createdAt ?? DateTime(2100)));
      return invites;
    });
  }

  /// Invite an email to this gym. Returns null on success, or a message
  /// to show the staff member.
  Future<String?> invite(String rawEmail) async {
    final email = normalize(rawEmail);
    if (!isValidEmail(email)) return 'Enter a valid email address';

    final gymId = GymService.instance.gymId;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (gymId == null || uid == null) return 'You are not signed in to a gym';

    try {
      // Already a member of this gym?
      final members = await _firestore
          .collection('users')
          .where('gymId', isEqualTo: gymId)
          .where('email', whereIn: {email, rawEmail.trim()}.toList())
          .limit(1)
          .get();
      if (members.docs.isNotEmpty) {
        return '$email is already a member of this gym';
      }

      final ref = _invites.doc(email);
      DocumentSnapshot<Map<String, dynamic>> existing;
      try {
        existing = await ref.get();
      } on FirebaseException catch (e) {
        // The rules hide invites that belong to another gym.
        if (e.code == 'permission-denied') {
          return '$email has already been invited by another gym';
        }
        rethrow;
      }

      final staffName = await _myName(uid);

      if (!existing.exists) {
        await ref.set({
          'email': email,
          'gymId': gymId,
          'role': 'member',
          'status': InviteStatus.pending,
          'invitedBy': uid,
          'invitedByName': staffName,
          'createdAt': FieldValue.serverTimestamp(),
        });
        return null;
      }

      final status = existing.data()?['status'];
      if (status == InviteStatus.pending) {
        return '$email already has a pending invite';
      }

      // Revoked, or used by an account that was later deleted: send again.
      await _resend(ref, uid, staffName);
      return null;
    } catch (e) {
      log('Error creating invite: $e');
      return 'Could not send the invite. Please try again.';
    }
  }

  /// Cancel a pending invite. The person can no longer join with it.
  Future<String?> revoke(String email) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return 'You are not signed in';
    try {
      await _invites.doc(email).update({
        'status': InviteStatus.revoked,
        'revokedBy': uid,
        'revokedAt': FieldValue.serverTimestamp(),
      });
      return null;
    } catch (e) {
      log('Error revoking invite: $e');
      return 'Could not revoke the invite';
    }
  }

  /// Make a revoked invite pending again.
  Future<String?> resend(String email) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return 'You are not signed in';
    try {
      await _resend(_invites.doc(email), uid, await _myName(uid));
      return null;
    } catch (e) {
      log('Error re-sending invite: $e');
      return 'Could not send the invite again';
    }
  }

  Future<void> _resend(
      DocumentReference<Map<String, dynamic>> ref, String uid, String name) {
    return ref.update({
      'status': InviteStatus.pending,
      'invitedBy': uid,
      'invitedByName': name,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<String> _myName(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      final name = (doc.data()?['name'] ?? '').toString().trim();
      return name.isNotEmpty ? name : 'Staff';
    } catch (_) {
      return 'Staff';
    }
  }
}