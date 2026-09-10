import 'package:flutter/material.dart';
import '../models/post_model.dart';
import '../services/chat_service.dart';
import '../services/auth_service.dart';
import '../services/validation_service.dart';
import 'likers_popup.dart';

class CommentsBottomSheet extends StatefulWidget {
  final String postId;
  final String currentUserId;
  final PostModel? post;  // ADD THIS

  const CommentsBottomSheet({
    super.key,
    required this.postId,
    required this.currentUserId,
    this.post,  // ADD THIS
  });

  @override
  State<CommentsBottomSheet> createState() => _CommentsBottomSheetState();
}

class _CommentsBottomSheetState extends State<CommentsBottomSheet> {
  final ChatService _chatService = ChatService();
  final AuthService _authService = AuthService();
  final _commentController = TextEditingController();

  bool _isLoading = false;
  String? _userName;
  String? _contentError;
  String? _userRole;

  @override
  void initState() {
    super.initState();
    _loadUserName();
    _contentError = null;
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadUserName() async {
    final data = await _authService.getUserData(widget.currentUserId);
    if (data != null) {
      setState(() {
        _userName = data['name'] ?? 'Anonymous';
        _userRole = data['role'];
      });
    }
  }

  Future<void> _postComment() async {
    if (_commentController.text.isEmpty) return;

    setState(() => _isLoading = true);

    await _chatService.addComment(
      postId: widget.postId,
      userId: widget.currentUserId,
      userName: _userName ?? 'Anonymous',
      content: ValidationService.sanitizeContent(_commentController.text),
    );

    _commentController.clear();
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.8,
      minChildSize: 0.5,
      builder: (context, scrollController) => Column(
        children: [
          // Post Preview (if available)
          if (widget.post != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Colors.grey[300]!),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.post!.userName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.post!.content,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13),
                  ),
                ],
              ),
            ),

          // Comments Header
          Container(
            padding: const EdgeInsets.all(16),
            child: const Text(
              'Comments',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          const Divider(),

          // Comments List
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _chatService.getCommentStream(widget.postId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('No comments yet'));
                }

                List<Map<String, dynamic>> comments = snapshot.data!;
                return ListView.builder(
                  controller: scrollController,
                  itemCount: comments.length,
                  itemBuilder: (context, index) {
                    Map<String, dynamic> comment = comments[index];
                    return _buildCommentTile(comment);
                  },
                );
              },
            ),
          ),

          // Comment Input
          Container(
            padding: EdgeInsets.only(
              left: 12,
              right: 12,
              bottom: MediaQuery.of(context).viewInsets.bottom + 12,
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: 'Add a comment...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _contentError = ValidationService.validateContent(value);
                      });
                    },
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: (_isLoading || _contentError != null) ? null : _postComment,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentTile(Map<String, dynamic> comment) {
    bool isOwnComment = comment['userId'] == widget.currentUserId;
    bool isAdmin = _userRole == 'admin';
    bool isLikedByCurrentUser = (comment['likedBy'] as List?)?.contains(widget.currentUserId) ?? false;
    int likeCount = (comment['likedBy'] as List?)?.length ?? 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Comment Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                comment['userName'],
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              if (isOwnComment || isAdmin)
                IconButton(
                  icon: const Icon(Icons.delete, size: 18),
                  onPressed: () async {
                    final result = await _chatService.deleteComment(
                      widget.postId,
                      comment['commentId'],
                      widget.currentUserId,
                    );

                    if (result == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Comment deleted')),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error: $result')),
                      );
                    }
                  },
                ),
            ],
          ),

          // Comment Content
          Text(comment['content']),
          const SizedBox(height: 8),

          // Like Button
          Row(
            children: [
              // Like Button with Long Press
              GestureDetector(
                onLongPress: () {
                  if (likeCount > 0) {
                    final likedBy = (comment['likedBy'] as List<dynamic>? ?? []).cast<String>();
                    _showLikersPopup(likedBy, context);
                  }
                },
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        isLikedByCurrentUser ? Icons.favorite : Icons.favorite_border,
                        color: isLikedByCurrentUser ? const Color(0xFFEA2327) : Colors.grey,
                        size: 18,
                      ),
                      onPressed: () async {
                        final result = await _chatService.likeComment(
                          widget.postId,
                          comment['commentId'],
                          widget.currentUserId,
                        );

                        if (result != null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: $result')),
                          );
                        }
                      },
                    ),
                    GestureDetector(
                      onLongPress: () {
                        if (likeCount > 0) {
                          _showLikersPopup(comment['likedBy'] ?? [], context);
                        }
                      },
                      child: Text(
                        likeCount > 0 ? likeCount.toString() : '',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showLikersPopup(List<String> likedBy, BuildContext context) {
    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      builder: (context) => Stack(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(color: Colors.transparent),
          ),
          Center(
            child: LikersPopup(
              likedBy: likedBy,
              position: Offset.zero,
            ),
          ),
        ],
      ),
    );
  }
}