import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/log.dart';
import 'gym_scope.dart';

/// A member the current user has blocked.
class BlockedMember {
  final String uid;
  final String name;

  BlockedMember({required this.uid, required this.name});
}

/// Status values stored on a report.
class ReportStatus {
  static const String open = 'open';           // waiting for an owner or manager
  static const String dismissed = 'dismissed'; // reviewed, content kept
  static const String removed = 'removed';     // reviewed, content deleted
}

/// One report of a post or comment, as shown in Staff Portal > Reports.
class ContentReport {
  final String id;
  final String type; // 'post' or 'comment'
  final String targetId;
  final String postId;
  final String? commentId;
  final String contentAuthorId;
  final String contentAuthorName;
  final String contentText;
  final int mediaCount;
  final String reportedByName;
  final String reason;
  final String details;
  final String status;
  final DateTime? createdAt;

  ContentReport({
    required this.id,
    required this.type,
    required this.targetId,
    required this.postId,
    this.commentId,
    required this.contentAuthorId,
    required this.contentAuthorName,
    required this.contentText,
    required this.mediaCount,
    required this.reportedByName,
    required this.reason,
    required this.details,
    required this.status,
    this.createdAt,
  });

  bool get isComment => type == 'comment';

  factory ContentReport.fromMap(String id, Map<String, dynamic> data) {
    final created = data['createdAt'];
    return ContentReport(
      id: id,
      type: (data['type'] ?? 'post').toString(),
      targetId: (data['targetId'] ?? '').toString(),
      postId: (data['postId'] ?? '').toString(),
      commentId: data['commentId'] as String?,
      contentAuthorId: (data['contentAuthorId'] ?? '').toString(),
      contentAuthorName: (data['contentAuthorName'] ?? 'Unknown').toString(),
      contentText: (data['contentText'] ?? '').toString(),
      mediaCount: (data['mediaCount'] as num?)?.toInt() ?? 0,
      reportedByName: (data['reportedByName'] ?? 'A member').toString(),
      reason: (data['reason'] ?? '').toString(),
      details: (data['details'] ?? '').toString(),
      status: (data['status'] ?? ReportStatus.open).toString(),
      createdAt: created is Timestamp ? created.toDate() : null,
    );
  }
}

/// REPORT AND BLOCK
///
/// Reporting: any member can report a post or comment. Reports are saved
/// under the gym (gyms/{gymId}/reports) and reviewed by owners and
/// managers in Staff Portal > Reports.
///
/// Blocking: a member can block another member. The blocked member's
/// posts and comments are hidden from the blocker, and the blocker gets
/// no tag notifications from them. The list is private, stored at
/// users/{uid}/blocked/{blockedUid}. The blocked member is not told.
class ModerationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Longest text kept on a report (the rules allow up to 1000).
  static const int _maxSnapshotLength = 500;
  static const int _maxDetailsLength = 500;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  CollectionReference<Map<String, dynamic>> get _reports => GymScope.col('reports');

  CollectionReference<Map<String, dynamic>> _blocked(String uid) =>
      _firestore.collection('users').doc(uid).collection('blocked');

  // ---------------------------------------------------------------------------
  // Blocking
  // ---------------------------------------------------------------------------

  /// IDs of everyone the current user has blocked. Live.
  Stream<Set<String>> blockedIdsStream() {
    final uid = _uid;
    if (uid == null) return Stream.value(<String>{});
    return _blocked(uid)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((d) => d.id).toSet());
  }

  /// Everyone the current user has blocked, sorted by name. Live.
  Stream<List<BlockedMember>> blockedMembersStream() {
    final uid = _uid;
    if (uid == null) return Stream.value(<BlockedMember>[]);
    return _blocked(uid).snapshots().map((snapshot) {
      final members = snapshot.docs
          .map((d) => BlockedMember(
        uid: d.id,
        name: (d.data()['name'] ?? 'Member').toString(),
      ))
          .toList();
      members.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return members;
    });
  }

  /// Block a member. Returns null on success, or a message to show.
  Future<String?> blockUser(String userId, String name) async {
    final uid = _uid;
    if (uid == null) return 'You are not signed in';
    if (userId.isEmpty || userId == uid) return 'You can\'t block yourself';

    try {
      await _blocked(uid).doc(userId).set({
        'blockedUid': userId,
        'name': name,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return null;
    } catch (e) {
      log('Error blocking user: $e');
      return 'Could not block this member';
    }
  }

  Future<String?> unblockUser(String userId) async {
    final uid = _uid;
    if (uid == null) return 'You are not signed in';
    try {
      await _blocked(uid).doc(userId).delete();
      return null;
    } catch (e) {
      log('Error unblocking user: $e');
      return 'Could not unblock this member';
    }
  }

  // ---------------------------------------------------------------------------
  // Reporting
  // ---------------------------------------------------------------------------

  /// Report a post (leave [commentId] null) or a comment.
  /// Returns null on success, or a message to show.
  Future<String?> report({
    required String postId,
    String? commentId,
    required String contentAuthorId,
    required String contentAuthorName,
    required String contentText,
    int mediaCount = 0,
    required String reason,
    String details = '',
  }) async {
    final uid = _uid;
    if (uid == null) return 'You are not signed in';

    final type = commentId == null ? 'post' : 'comment';
    final targetId = commentId ?? postId;

    String cut(String text, int max) =>
        text.length > max ? text.substring(0, max) : text;

    try {
      // One report per member per post or comment: the ID is fixed, and the
      // rules don't let a member overwrite a report.
      await _reports.doc('${type}_${targetId}_$uid').set({
        'type': type,
        'targetId': targetId,
        'postId': postId,
        if (commentId != null) 'commentId': commentId,
        'contentAuthorId': contentAuthorId,
        'contentAuthorName': contentAuthorName,
        'contentText': cut(contentText, _maxSnapshotLength),
        'mediaCount': mediaCount,
        'reportedBy': uid,
        'reportedByName': await _myName(uid),
        'reason': reason,
        'details': cut(details.trim(), _maxDetailsLength),
        'status': ReportStatus.open,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return null;
    } on FirebaseException catch (e) {
      log('Error creating report: ${e.code} ${e.message}');
      if (e.code == 'permission-denied') {
        return 'You have already reported this. Our staff will review it.';
      }
      return 'Could not send the report. Please try again.';
    } catch (e) {
      log('Error creating report: $e');
      return 'Could not send the report. Please try again.';
    }
  }

  // ---------------------------------------------------------------------------
  // Reviewing (owners and managers)
  // ---------------------------------------------------------------------------

  /// Reports waiting for review, newest first.
  Stream<List<ContentReport>> openReportsStream() {
    return _reports
        .where('status', isEqualTo: ReportStatus.open)
        .snapshots()
        .map((snapshot) {
      final reports = snapshot.docs
          .map((d) => ContentReport.fromMap(d.id, d.data()))
          .toList();
      // Sorted here instead of in the query, so no Firestore index is needed.
      reports.sort((a, b) =>
          (b.createdAt ?? DateTime(2100)).compareTo(a.createdAt ?? DateTime(2100)));
      return reports;
    });
  }

  /// Close a report and keep the content.
  Future<String?> dismiss(ContentReport report) async {
    final uid = _uid;
    if (uid == null) return 'You are not signed in';
    try {
      await _reports.doc(report.id).update(_closed(uid, ReportStatus.dismissed));
      return null;
    } catch (e) {
      log('Error dismissing report: $e');
      return 'Could not dismiss the report';
    }
  }

  /// Delete the reported post or comment, then close every open report
  /// about it. Works even if the author already deleted it.
  Future<String?> removeContent(ContentReport report) async {
    final uid = _uid;
    if (uid == null) return 'You are not signed in';

    try {
      final posts = GymScope.col('posts');
      final postRef = posts.doc(report.postId);

      if (report.isComment && report.commentId != null) {
        final commentRef = postRef.collection('comments').doc(report.commentId);
        final comment = await commentRef.get();
        if (comment.exists) {
          await commentRef.delete();
          try {
            await postRef.update({'commentCount': FieldValue.increment(-1)});
          } catch (e) {
            log('Comment removed; could not update the count: $e');
          }
        }
      } else {
        await postRef.delete();
      }

      // Close all open reports about the same post or comment
      final same = await _reports.where('targetId', isEqualTo: report.targetId).get();
      final batch = _firestore.batch();
      for (final doc in same.docs) {
        if (doc.data()['status'] == ReportStatus.open) {
          batch.update(doc.reference, _closed(uid, ReportStatus.removed));
        }
      }
      await batch.commit();
      return null;
    } catch (e) {
      log('Error removing reported content: $e');
      return 'Could not remove the content';
    }
  }

  Map<String, dynamic> _closed(String uid, String status) => {
    'status': status,
    'resolvedBy': uid,
    'resolvedAt': FieldValue.serverTimestamp(),
  };

  Future<String> _myName(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      final name = (doc.data()?['name'] ?? '').toString().trim();
      return name.isNotEmpty ? name : 'A member';
    } catch (_) {
      return 'A member';
    }
  }
}