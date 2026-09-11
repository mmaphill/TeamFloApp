import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/chat_service.dart';
import '../models/post_model.dart';
import '../widgets/video_player_widget.dart';
import '../widgets/video_player_modal.dart';
import '../widgets/video_preview.dart';
import 'comments_bottom_sheet.dart';
import 'likers_popup.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ChatService _chatService = ChatService();
  final User _currentUser = FirebaseAuth.instance.currentUser!;
  final Map<String, Map<String, dynamic>> _userProfileCache = {};

  late UserModel _userData;
  String? _userRole;

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
        _userRole = data['role'];
      });
    }
  }

  // Fetch user profile with caching
  Future<Map<String, dynamic>> _getUserProfile(String userId) async {
    if (_userProfileCache.containsKey(userId)) {
      return _userProfileCache[userId]!;
    }

    final profile = await _chatService.getUserProfile(userId);
    _userProfileCache[userId] = profile;
    return profile;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<List<PostModel>>(
        stream: _chatService.getPostsStream(),
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
    _debugPrintPost(post);
    bool isLikedByCurrentUser = post.likedBy.contains(_currentUser.uid);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Post Header (Author name + avatar + timestamp)
            FutureBuilder<Map<String, dynamic>>(
              future: _getUserProfile(post.userId),
              builder: (context, snapshot) {
                final profile = snapshot.data ?? {'name': post.userName, 'photoUrl': null};

                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Avatar + Name + Timestamp
                    Expanded(
                      child: Row(
                        children: [
                          // Avatar
                          CircleAvatar(
                            radius: 24,
                            backgroundImage: (profile['photoUrl'] != null &&
                                profile['photoUrl'].isNotEmpty)
                                ? NetworkImage(profile['photoUrl'])
                                : null,
                            backgroundColor: profile['photoUrl'] == null ||
                                profile['photoUrl'].isEmpty
                                ? Colors.grey[400]
                                : null,
                            child: (profile['photoUrl'] == null ||
                                profile['photoUrl'].isEmpty)
                                ? Text(
                              post.userName.isNotEmpty
                                  ? post.userName[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            )
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  profile['name'] ?? post.userName,
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
                        ],
                      ),
                    ),
                    // Delete menu
                    if (post.userId == _currentUser.uid || _userRole == 'admin')
                      PopupMenuButton(
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            child: const Text('Delete'),
                            onTap: () => _deletePost(post.postId),
                          ),
                        ],
                      ),
                  ],
                );
              },
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
                          : VideoPreview(
                        videoUrl: url,
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (context) => VideoPlayerModal(videoUrl: url),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
            if (post.mediaUrls.isNotEmpty) const SizedBox(height: 12),

            // Post Actions (Likes)
            Row(
              children: [
                // Like Button with Long Press
                GestureDetector(
                  onLongPress: () {
                    if (post.likedBy.isNotEmpty) {
                      _showLikersPopup(post.likedBy, context);
                    }
                  },
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(
                          isLikedByCurrentUser ? Icons.favorite : Icons.favorite_border,
                          color: isLikedByCurrentUser ? const Color(0xFFEA2327) : Colors.grey,
                        ),
                        onPressed: () => _chatService.likePost(post.postId, _currentUser.uid),
                      ),
                      GestureDetector(
                        onLongPress: () {
                          if (post.likedBy.isNotEmpty) {
                            _showLikersPopup(post.likedBy, context);
                          }
                        },
                        child: Text('${post.likedBy.length}'),
                      ),
                    ],
                  ),
                ),

                // Dislike Button
                // IconButton(
                //   icon: Icon(
                //     isThumbsDown ? Icons.thumb_down : Icons.thumb_down_outlined,
                //     color: isThumbsDown ? const Color(0xFFEA2327) : Colors.grey,
                //   ),
                //   onPressed: () => _chatService.thumbDown(post.postId, _currentUser.uid),
                // )
                // Text('${post.DownBy.length}')
                // const SizedBox(width: 16),

                // Comment Button
                IconButton(
                  icon: const Icon(Icons.comment),
                  onPressed: () => _showCommentsBottomSheet(post.postId, post),
                ),
                Text('${post.commentCount}'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoPlayer(String videoUrl) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: VideoPlayerWidget(videoUrl: videoUrl),
    );
  }

  void _showLikersPopup(List<String> likedBy, BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => LikersPopup(likedBy: likedBy),
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
              _chatService.deletePost(postId, _currentUser.uid);
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

  void _debugPrintPost(PostModel post) {
    print('=== POST DEBUG ===');
    print('Post ID: ${post.postId}');
    print('User: ${post.userName}');
    print('Content: ${post.content}');
    print('Media URLs: ${post.mediaUrls.length} items');
    for (int i = 0; i < post.mediaUrls.length; i++) {
      print('  [$i] ${post.mediaTypes[i]}: ${post.mediaUrls[i]}');
    }
    print('=================');
  }

  void _showCommentsBottomSheet(String postId, PostModel post) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => CommentsBottomSheet(
        postId: postId,
        currentUserId: _currentUser.uid,
        post: post,
      ),
    );
  }
}