import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/post_model.dart';
import '../models/mention_model.dart';
import '../services/chat_service.dart';
import '../services/auth_service.dart';
import '../config/colors.dart';
import '../widgets/mention_autocomplete_widget.dart';
import '../config/mention_text_renderer.dart';

class CommentsBottomSheet extends StatefulWidget {
  final String postId;
  final String currentUserId;
  final PostModel post;

  const CommentsBottomSheet({
    super.key,
    required this.postId,
    required this.currentUserId,
    required this.post,
  });

  @override
  State<CommentsBottomSheet> createState() => _CommentsBottomSheetState();
}

class _CommentsBottomSheetState extends State<CommentsBottomSheet> {
  final ChatService _chatService = ChatService();
  final AuthService _authService = AuthService();
  final TextEditingController _commentController = TextEditingController();

  String? _currentUserName;
  bool _isSubmitting = false;

  final List<Mention> _mentions = [];
  bool _showMentionSuggestions = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentUserName();
  }

  Future<void> _loadCurrentUserName() async {
    final data = await _authService.getUserData(widget.currentUserId);
    if (data != null) {
      setState(() => _currentUserName = data['name'] ?? 'Anonymous');
    }
  }

  // Helper to convert comment mentions data to Mention objects
  List<Mention> _parseMentionsFromComment(Map<String, dynamic> comment) {
    try {
      final mentionsData = comment['mentions'] as List<dynamic>?;
      if (mentionsData == null || mentionsData.isEmpty) {
        return [];
      }

      return mentionsData
          .cast<Map<String, dynamic>>()
          .map((m) => Mention.fromMap(m))
          .toList();
    } catch (e) {
      print('Error parsing comment mentions: $e');
      return [];
    }
  }

  void _onMentionSelected(String userId, String userName) {
    final text = _commentController.text;
    final mentionText = '@$userName';

    // Find where the mention is in the text
    int startIndex = text.lastIndexOf(mentionText);
    if (startIndex != -1) {
      int endIndex = startIndex + mentionText.length;

      final mention = Mention(
        userId: userId,
        userName: userName,
        startIndex: startIndex,
        endIndex: endIndex,
      );

      // Avoid duplicates
      final exists = _mentions.any(
            (m) => m.userId == userId && m.startIndex == startIndex,
      );

      if (!exists) {
        setState(() {
          _mentions.add(mention);
        });
      }

      print('✓ Mention added to comment: @$userName ($userId)');
    }
  }

  Future<void> _submitComment() async {
    if (_commentController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Comment cannot be empty')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final error = await _chatService.addComment(
      postId: widget.postId,
      userId: widget.currentUserId,
      userName: _currentUserName ?? 'Anonymous',
      content: _commentController.text,
      mentions: _mentions,
    );

    setState(() => _isSubmitting = false);

    if (error == null) {
      _commentController.clear();
      _mentions.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Comment posted!')),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $error')),
        );
      }
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.black87,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Colors.grey, width: 0.5),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Comments',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              // Comments List
              Expanded(
                child: StreamBuilder<List<Map<String, dynamic>>>(
                  stream: _chatService.getCommentStream(widget.postId),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}'));
                    }

                    final comments = snapshot.data ?? [];

                    if (comments.isEmpty) {
                      return const Center(
                        child: Text(
                          'No comments yet',
                          style: TextStyle(color: Colors.grey),
                        ),
                      );
                    }

                    return ListView.builder(
                      controller: scrollController,
                      itemCount: comments.length,
                      itemBuilder: (context, index) {
                        final comment = comments[index];
                        return _buildCommentTile(comment);
                      },
                    );
                  },
                ),
              ),

              // Comment Input Section
              Container(
                decoration: const BoxDecoration(
                  border: Border(
                    top: BorderSide(color: Colors.grey, width: 0.5),
                  ),
                ),
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Comment input field
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _commentController,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              hintText: 'Add a comment... (@ to mention)',
                              hintStyle: const TextStyle(color: Colors.grey),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(color: Colors.grey),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                            maxLines: null,
                            minLines: 1,
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: _isSubmitting
                              ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.blue,
                              ),
                            ),
                          )
                              : const Icon(Icons.send, color: Colors.blue),
                          onPressed: _isSubmitting ? null : _submitComment,
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    // Mention autocomplete dropdown
                    MentionAutocomplete(
                      textController: _commentController,
                      onMentionSelected: _onMentionSelected,
                      onShowSuggestions: (visible) {
                        setState(() {
                          _showMentionSuggestions = visible;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCommentTile(Map<String, dynamic> comment) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: Colors.grey[600],
                child: Text(
                  (comment['userName'] as String).isNotEmpty
                      ? (comment['userName'] as String)[0].toUpperCase()
                      : '?',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      comment['userName'] ?? 'Anonymous',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      _formatTime(
                        (comment['createdAt'] as dynamic)?.toDate() ??
                            DateTime.now(),
                      ),
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 56.0),
            child: MentionTextRenderer.buildMentionText(
              comment['content'] ?? '',
              _parseMentionsFromComment(comment),
              baseStyle: const TextStyle(
                color: Colors.white,
                fontSize: 14,
              ),
              mentionStyle: const TextStyle(
                color: AppColors.mention,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}