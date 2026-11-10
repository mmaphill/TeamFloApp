import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/app_roles.dart';
import '../utils/log.dart';
import 'gym_scope.dart';

/// A gym member as shown on Staff Portal > Members.
class GymMember {
  final String uid;
  final String name;
  final String email;
  final String role;
  final String? photoUrl;

  GymMember({
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
    this.photoUrl,
  });
}

/// Who is in the gym, removing people, and joining with an invite.
/// The actual changes run in Cloud Functions, which check permissions
/// on the server.
class MembershipService {
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  /// Everyone in this gym, sorted by name. Live: updates when someone
  /// joins or is removed.
  Stream<List<GymMember>> membersStream() {
    return GymScope.members().snapshots().map((snapshot) {
      final members = snapshot.docs.map((doc) {
        final data = doc.data();
        final email = (data['email'] ?? '').toString();
        final name = (data['name'] ?? '').toString().trim();
        return GymMember(
          uid: doc.id,
          name: name.isNotEmpty ? name : (email.isNotEmpty ? email : 'Unknown'),
          email: email,
          role: AppRoles.normalize(data['role'] as String?),
          photoUrl: data['photoUrl'] as String?,
        );
      }).toList();
      members.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return members;
    });
  }

  /// Remove someone from the gym. Returns null on success, or a message
  /// to show. The server checks the caller's rank.
  Future<String?> removeFromGym(String targetUid) async {
    try {
      await _functions.httpsCallable('removeFromGym').call({'targetUid': targetUid});
      return null;
    } on FirebaseFunctionsException catch (e) {
      log('removeFromGym failed: ${e.code} ${e.message}');
      return e.message ?? 'Could not remove this member';
    } catch (e) {
      log('removeFromGym failed: $e');
      return 'Could not remove this member';
    }
  }

  /// Join a gym with a pending invite for this account's (verified) email.
  /// Returns true if the account joined. Safe to call any time: does
  /// nothing if there's no invite.
  ///
  /// Refreshes the ID token first, because the server reads the
  /// "email verified" flag from the token, and an old token still says
  /// "not verified" right after the user clicks the link.
  Future<bool> claimMyInvite() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || !user.emailVerified) return false;

    try {
      await user.getIdToken(true);
      final result = await _functions.httpsCallable('claimMyInvite').call();
      final data = result.data;
      return data is Map && data['joined'] == true;
    } catch (e) {
      log('claimMyInvite failed: $e');
      return false;
    }
  }
}