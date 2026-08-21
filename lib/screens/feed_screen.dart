import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/feed_service.dart';
import '../models/post_model.dart';
import 'comments_bottom_sheet.dart';
import 'create_post_screen.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final FeedService _feedService = FeedService();
  final User _currentUser = FirebaseAuth.instance.currentUser!;

  late UserModel _userData;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final authService = AuthService();
    final data = await authService.getUserData(FirebaseAuth.instance.currentUser!.uid);
    if (data != null) {
      setState(() {
        _userData = UserModel.fromMap(data);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<List<PostModel>>(
        stream: _feedService.getPostsStream(),
        builder: (context, snapshot) {
          // Loading state
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // Error state
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          // No posts
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text('No posts yet. Be the first to share!'),
            );
          }

          // Display posts
          List<PostModel> posts = snapshot.data!;
          return ListView.builder(
            itemCount: posts.length,
            itemBuilder: (context, index) {
              PostModel post = posts[index];
              return _buildPostCard(post);
            },
          );
        },
      ),
    );
  }

  Widget _buildPostCard(PostModel post) {
    bool isLikedByCurrentUser = post.likedBy.contains(_currentUser.uid);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Post Header (Author name + timestamp)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.userName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        _formatTime(post.createdAt),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                if (post.userId == _currentUser.uid)
                  PopupMenuButton(
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        child: const Text('Delete'),
                        onTap: () => _deletePost(post.postId),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // Post Content
            Text(post.content),
            const SizedBox(height: 12),

            // Media Display
            if (post.mediaUrls.isNotEmpty)
              SizedBox(
                height: 200,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: post.mediaUrls.length,
                  itemBuilder: (context, index) {
                    String url = post.mediaUrls[index];
                    String type = post.mediaTypes[index];

                    return Container(
                      margin: const EdgeInsets.only(right: 8),
                      child: type == 'image'
                          ? Image.network(url, fit: BoxFit.cover)
                          : Container(
                        color: Colors.black26,
                        child: const Center(
                          child: Icon(Icons.play_circle_outline),
                        ),
                      ),
                    );
                  },
                ),
              ),
            if (post.mediaUrls.isNotEmpty) const SizedBox(height: 12),

            // Post Actions (Likes)
            Row(
              children: [
                // Like Button
                IconButton(
                  icon: Icon(
                    isLikedByCurrentUser ? Icons.favorite : Icons.favorite_border,
                    color: isLikedByCurrentUser ? const Color(0xFFEA2327) : Colors.grey,
                  ),
                  onPressed: () => _feedService.likePost(post.postId, _currentUser.uid),
                ),
                Text('${post.likedBy.length}'),
                const SizedBox(width: 16),

                // Comment Button
                IconButton(
                  icon: const Icon(Icons.comment),
                  onPressed: () => _showCommentsBottomSheet(post.postId),
                ),
                Text('${post.commentCount}'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _deletePost(String postId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Post'),
        content: const Text('Are you sure you want to delete this post?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              _feedService.deletePost(postId, _currentUser.uid);
              Navigator.pop(context);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime date) {
    Duration diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  void _showCommentsBottomSheet(String postId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => CommentsBottomSheet(
        postId: postId,
        currentUserId: _currentUser.uid,
      ),
    );
  }
}