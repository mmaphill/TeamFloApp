import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/app_roles.dart';
import '../models/post_model.dart';
import '../models/mention_model.dart';
import '../utils/log.dart';
import 'gym_scope.dart';
import 'gym_service.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // PHASE 1 STEP 3: posts belong to a gym. GymScope decides whether that's
  // the shared 'posts' collection or gyms/{gymId}/posts.
  CollectionReference<Map<String, dynamic>> get _posts => GymScope.col('posts');

  // PHASE 1 STEP 3: owners and managers can remove anyone's post or comment
  // (was: role == 'admin' only, which missed the new roles).
  bool get _canModerate => AppRoles.canManageMembers(GymService.instance.role);

  // Create a new post
  Future<String?> createPost({
    required String userId,
    required String userName,
    required String content,
    List<String> mediaUrls = const [],
    List<String> mediaTypes = const [],
    List<Mention> mentions =const [],
  }) async {
    try {
      log('🔥 createPost called with:');
      log('  content: $content');
      log('  mediaUrls: ${mediaUrls.length} items → $mediaUrls');
      log('  mediaTypes: ${mediaTypes.length} items → $mediaTypes');
      log('  mentions: ${mentions.length} items');

      await _posts.add({
        'userId': userId,
        'userName': userName,
        'content': content,
        'mediaUrls': mediaUrls,
        'mediaTypes': mediaTypes,
        'createdAt': DateTime.now(),
        'likedBy': [],
        'commentCount': 0,
        'mentions': mentions.map((m) => m.toMap()).toList(),
      });
      log('✓ Post created successfully');
      return null; // Success
    } catch (e) {
      log('✗ ERROR creating post: $e');
      return e.toString();
    }
  }

  // Get user profile data (name, photoUrl)
  Future<Map<String, dynamic>> getUserProfile(String userId) async {
    try {
      final docSnapshot = await _firestore.collection('users').doc(userId).get();
      if (docSnapshot.exists && docSnapshot.data() != null) {
        return {
          'name': docSnapshot['name'] ?? 'Unknown User',
          'photoUrl': docSnapshot['photoUrl'],
        };
      }
      return {'name': 'Unknown User', 'photoUrl': null};
    } catch (e) {
      log('Error fetching user profile: $e');
      return {'name': 'Unknown User', 'photoUrl': null};
    }
  }

  // Get user name by ID
  Future<String> getUserName(String userId) async {
    try {
      final docSnapshot = await _firestore.collection('users').doc(userId).get();

      if (docSnapshot.exists && docSnapshot.data() != null) {
        final name = docSnapshot['name'] ?? 'Unknown User';
        return name;
      }
      return 'Unknown User';
    } catch (e) {
      return 'Unknown User';
    }
  }

  // Get all posts as a stream (real-time updates)
  Stream<List<PostModel>> getPostsStream() {
    return _posts
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => PostModel.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  // Toggle likes for a post
  Future<String?> likePost(String postId, String userId) async {
    try {
      DocumentSnapshot doc = await _posts.doc(postId).get();
      List<String> likedBy = List<String>.from(doc['likedBy'] ?? []);

      if (likedBy.contains(userId)) {
        // Unlike
        likedBy.remove(userId);
      } else {
        // Like
        likedBy.add(userId);
      }

      await _posts.doc(postId).update({
        'likedBy': likedBy,
      });
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  // Delete a post (only author can delete)
  Future<String?> deletePost(String postId, String userId) async {
    try {
      DocumentSnapshot doc = await _posts
          .doc(postId)
          .get();

      if (doc['userId'] != userId && !_canModerate) {
        return 'Would you like to report this post?';
      }

      await _posts.doc(postId).delete();

      return null;
    } catch (e) {
      return e.toString();
    }
  }

  // Add a comment
  Future<String?> addComment({
    required String postId,
    required String userId,
    required String userName,
    required String content,
    List<Mention> mentions = const [],
  }) async {
    try {
      await _posts
          .doc(postId)
          .collection('comments')
          .add({
        'userId': userId,
        'userName': userName,
        'content': content,
        'createdAt': DateTime.now(),
        'likedBy': [],
        'mentions': mentions.map((m) => m.toMap()).toList(),
      });

      // Increase comment count
      await _posts.doc(postId).update({
        'commentCount': FieldValue.increment(1),
      });

      return null;
    } catch(e) {
      return e.toString();
    }
  }

  // Get comments for a post
  Stream<List<Map<String, dynamic>>> getCommentStream(String postId) {
    return _posts
        .doc(postId)
        .collection('comments')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => {...doc.data(), 'commentId': doc.id})
          .toList();
    });
  }

  // Delete a comment (author or admin can delete)
  Future<String?> deleteComment(String postId, String commentId, String userId) async {
    try {
      DocumentSnapshot doc = await _posts
          .doc(postId)
          .collection('comments')
          .doc(commentId)
          .get();

      // Allow if user is the author, an owner or a manager
      if (doc['userId'] != userId && !_canModerate) {
        return 'Would you like to report this comment?';
      }

      await _posts
          .doc(postId)
          .collection('comments')
          .doc(commentId)
          .delete();

      // Decrease comment count
      await _posts.doc(postId).update({
        'commentCount': FieldValue.increment(-1),
      });

      return null;
    } catch (e) {
      return e.toString();
    }
  }

  // Like/unlike a comment
  Future<String?> likeComment(String postId, String commentId, String userId) async {
    try {
      log('Liking comment: $commentId');
      DocumentSnapshot doc = await _posts
          .doc(postId)
          .collection('comments')
          .doc(commentId)
          .get();

      // Handle case where likedBy field doesn't exist (old comments)
      List<String> likedBy = [];
      if (doc.exists && doc.data() is Map) {
        final data = doc.data() as Map<String, dynamic>;
        likedBy = List<String>.from(data['likedBy'] ?? []);
      }

      log('Current likedBy: $likedBy, userId: $userId');

      if (likedBy.contains(userId)) {
        // Unlike
        likedBy.remove(userId);
        log('Unliked comment');
      } else {
        // Like
        likedBy.add(userId);
        log('Liked comment');
      }

      await _posts
          .doc(postId)
          .collection('comments')
          .doc(commentId)
          .update({
        'likedBy': likedBy,
      });
      log('✓ Comment like updated successfully');
      return null;
    } catch (e) {
      log('✗ ERROR liking comment: $e');
      return e.toString();
    }
  }
}