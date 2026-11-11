import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/app_roles.dart';
import '../models/mention_model.dart';
import '../services/chat_service.dart';
import '../services/gym_service.dart';
import '../services/moderation_service.dart';
import '../models/post_model.dart';
import '../config/colors.dart';
import '../widgets/fullscreen_image_viewer.dart';
import '../widgets/report_dialog.dart';
import '../widgets/video_player_modal.dart';
import '../widgets/video_preview.dart';
import '../config/mention_text_renderer.dart';
import 'comments_bottom_sheet.dart';
import 'likers_popup.dart';
import '../utils/log.dart';
import 'member_profile_screen.dart';

class ChatScreen extends StatefulWidget {
  final String? postId;

  const ChatScreen({super.key, this.postId,});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ChatService _chatService = ChatService();
  final User _currentUser = FirebaseAuth.instance.currentUser!;
  final Map<String, Map<String, dynamic>> _userProfileCache = {};
  final ScrollController _scrollController = ScrollController();

  String? _highlightedPostId;

  // REPORT AND BLOCK: members this user has blocked. Their posts are hidden.
  StreamSubscription<Set<String>>? _blockedSubscription;
  Set<String> _blockedIds = {};

  // Created once here, not in build(), so the feed doesn't reload every
  // time the screen rebuilds (for example when the block list changes).
  late final Stream<List<PostModel>> _postsStream;

  /// Owners and managers can delete anyone's post.
  /// FIX: was `_userRole == 'admin'`, which missed the owner and manager roles.
  bool get _canModerate => AppRoles.canManageMembers(GymService.instance.role);

  @override
  void initState() {
    super.initState();
    _highlightedPostId = widget.postId;
    _postsStream = _chatService.getPostsStream();
    _blockedSubscription = ModerationService().blockedIdsStream().listen((ids) {
      if (!mounted) return;
      setState(() => _blockedIds = ids);
    }, onError: (Object e) => log('Could not load blocked members: $e'));
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

  // Helper to convert post mentions data to Mention objects
  List<Mention> _parseMentionsFromPost(PostModel post) {
    return post.mentions ?? [];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<List<PostModel>>(
        stream: _postsStream,
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

          // Display posts, without anyone this user has blocked
          List<PostModel> posts = snapshot.data!
              .where((post) => !_blockedIds.contains(post.userId))
              .toList();

          if (posts.isEmpty) {
            return const Center(child: Text('No posts to show.'));
          }

          // Scroll to highlighted post if applicable
          if (_highlightedPostId != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _scrollToPost(posts, _highlightedPostId!);
            });
          }

          return ListView.builder(
            // FIX: the controller was never attached, so opening a post from
            // a tag notification could not scroll to it.
            controller: _scrollController,
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

  void _scrollToPost(List<PostModel> posts, String postId) {
    try {
      final index = posts.indexWhere((post) => post.postId == postId);
      if (index != -1 && _scrollController.hasClients) {
        _scrollController.animateTo(
          index * 250.0,  // Approximate height of a post card
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
        // Clear highlight after 2 seconds
        Future.delayed(const Duration(seconds: 2), () {
          if (!mounted) return;
          setState(() => _highlightedPostId = null);
        });
      }
    } catch (e) {
      log('Error scrolling to post: $e');
    }
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
                        child: InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () => MemberProfileScreen.open(context, post.userId),
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
                                    ? AppColors.neutral
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
                                    color: AppColors.onPrimary,
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
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: context.colors.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        )
                    ),
                    // Post menu: Delete (your own, or any as owner/manager),
                    // Report and Block (other people's posts).
                    _buildPostMenu(post, (profile['name'] ?? post.userName).toString()),
                  ],
                );
              },
            ),
            const SizedBox(height: 12),

            // Post Content with styled mentions
            MentionTextRenderer.buildMentionText(
              context,
              post.content,
              _parseMentionsFromPost(post),
            ),
            const SizedBox(height: 12),

            // Media Display
            if (post.mediaUrls.isNotEmpty)
              SizedBox(
                height: 250,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: post.mediaUrls.length,
                  itemBuilder: (context, index) {
                    String url = post.mediaUrls[index];
                    String type = post.mediaTypes[index];

                    return Container(
                      margin: const EdgeInsets.only(right: 8),
                      child: type == 'image'
                          ? GestureDetector(
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (context) => FullscreenImageViewer(
                              imageUrls: post.mediaUrls
                                  .asMap()
                                  .entries
                                  .where((e) => post.mediaTypes[e.key] == 'image')
                                  .map((e) => e.value)
                                  .toList(),
                              initialIndex: index,
                            ),
                          );
                        },
                        child: Image.network(url, fit: BoxFit.cover),
                      )
                          : AspectRatio(
                        aspectRatio: 0.5625,
                        child: VideoPreview(
                          videoUrl: url,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => VideoPlayerModal(videoUrl: url),
                              ),
                            );
                          },
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
                          color: isLikedByCurrentUser ? context.colors.primary : context.colors.textMuted,
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


  // REPORT AND BLOCK: the three-dot menu on each post.
  Widget _buildPostMenu(PostModel post, String authorName) {
    final bool isMine = post.userId == _currentUser.uid;

    return PopupMenuButton<String>(
      onSelected: (value) {
        if (value == 'delete') {
          _deletePost(post.postId);
        } else if (value == 'report') {
          ModerationDialogs.report(
            context,
            postId: post.postId,
            authorId: post.userId,
            authorName: authorName,
            text: post.content,
            mediaCount: post.mediaUrls.length,
          );
        } else if (value == 'block') {
          ModerationDialogs.block(context, userId: post.userId, name: authorName);
        }
      },
      itemBuilder: (context) => [
        if (isMine || _canModerate)
          const PopupMenuItem(
            value: 'delete',
            child: Row(
              children: [
                Icon(Icons.delete_outline, size: 20),
                SizedBox(width: 8),
                Text('Delete'),
              ],
            ),
          ),
        if (!isMine)
          const PopupMenuItem(
            value: 'report',
            child: Row(
              children: [
                Icon(Icons.flag_outlined, size: 20),
                SizedBox(width: 8),
                Text('Report post'),
              ],
            ),
          ),
        if (!isMine)
          const PopupMenuItem(
            value: 'block',
            child: Row(
              children: [
                Icon(Icons.block, size: 20, color: AppColors.error),
                SizedBox(width: 8),
                Text('Block member', style: TextStyle(color: AppColors.error)),
              ],
            ),
          ),
      ],
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
    log('=== POST DEBUG ===');
    log('Post ID: ${post.postId}');
    log('User: ${post.userName}');
    log('Content: ${post.content}');
    log('Media URLs: ${post.mediaUrls.length} items');
    for (int i = 0; i < post.mediaUrls.length; i++) {
      log('  [$i] ${post.mediaTypes[i]}: ${post.mediaUrls[i]}');
    }
    log('=================');
  }

  void _showCommentsBottomSheet(String postId, PostModel post) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.transparent,
      builder: (context) => CommentsBottomSheet(
        postId: postId,
        currentUserId: _currentUser.uid,
        post: post,
      ),
    );
  }

  @override
  void dispose() {
    _blockedSubscription?.cancel();
    _scrollController.dispose();
    super.dispose();
  }
}