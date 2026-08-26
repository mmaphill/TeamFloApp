import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:team_flo_app/services/auth_service.dart';
import '../models/post_model.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Create a new post
  Future<String?> createPost({
    required String userId,
    required String userName,
    required String content,
    List<String> mediaUrls = const [],
    List<String> mediaTypes = const [],
  }) async {
    try {
      await _firestore.collection('posts').add({
        'userId': userId,
        'userName': userName,
        'content': content,
        'mediaUrls': mediaUrls,
        'mediaTypes': mediaTypes,
        'createdAt': DateTime.now(),
        'likedBy': [],
        'commentCount': 0,
      });
      return null; // Success
    } catch (e) {
      return e.toString();
    }
  }

  // Get all posts as a stream (real-time updates)
  Stream<List<PostModel>> getPostsStream() {
    return _firestore
        .collection('posts')
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
      DocumentSnapshot doc = await _firestore.collection('posts').doc(postId).get();
      List<String> likedBy = List<String>.from(doc['likedBy'] ?? []);

      if (likedBy.contains(userId)) {
        // Unlike
        likedBy.remove(userId);
      } else {
        // Like
        likedBy.add(userId);
      }

      await _firestore.collection('posts').doc(postId).update({
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
      DocumentSnapshot doc = await _firestore
          .collection('posts')
          .doc(postId)
          .get();

      final authService = AuthService();
      final currentUserRole = await authService.getUserRole(
          FirebaseAuth.instance.currentUser!.uid);

      if (doc['userId'] != userId && currentUserRole != 'admin') {
        return 'Would you like to report this post?';
      }

      await _firestore
          .collection('posts')
          .doc(postId)
          .delete();

      await _firestore.collection('posts').doc(postId).delete();

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
  }) async {
    try {
      await _firestore
          .collection('posts')
          .doc(postId)
          .collection('comments')
          .add({
        'userId': userId,
        'userName': userName,
        'content': content,
        'createdAt': DateTime.now(),
      });

      // Increase comment count
      await _firestore.collection('posts').doc(postId).update({
        'commentCount': FieldValue.increment(1),
      });

      return null;
    } catch(e) {
      return e.toString();
    }
  }

  // Get comments for a post
  Stream<List<Map<String, dynamic>>> getCommentStream(String postId) {
    return _firestore
        .collection('posts')
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
      DocumentSnapshot doc = await _firestore
          .collection('posts')
          .doc(postId)
          .collection('comments')
          .doc(commentId)
          .get();

      // Get current user's role
      final authService = AuthService();
      final currentUserRole = await authService.getUserRole(FirebaseAuth.instance.currentUser!.uid);

      // Allow if user is the author OR admin
      if(doc['userId'] != userId && currentUserRole != 'admin') {
        return 'Would you like to report this comment?';
      }

      await _firestore
          .collection('posts')
          .doc(postId)
          .collection('comments')
          .doc(commentId)
          .delete();

      // Decrease comment count
      await _firestore.collection('posts').doc(postId).update({
        'commentCount': FieldValue.increment(-1),
      });

      return null;
    } catch (e) {
      return e.toString();
    }
  }
}