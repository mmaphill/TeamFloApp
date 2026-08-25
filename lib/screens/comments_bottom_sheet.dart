import 'package:flutter/material.dart';
import '../services/chat_service.dart';
import '../services/auth_service.dart';
import '../services/validation_service.dart';

class CommentsBottomSheet extends StatefulWidget {
  final String postId;
  final String currentUserId;

  const CommentsBottomSheet({
    super.key,
    required this.postId,
    required this.currentUserId,
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
      setState(() => _userName = data['name'] ?? 'Anonymous');
    }
  }

  Future<void> _postComment() async {
    if (_commentController.text.isEmpty) return;

    setState(() => _isLoading = true);

    await _chatService.addComment(
      postId: widget.postId,
      userId: widget.currentUserId,
      userName: _userName ?? 'Anonymous',
      content: _commentController.text,
    );

    _commentController.clear();
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      builder: (context, scrollController) => Column(
        children: [
          // Header
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

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                comment['userName'],
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              if (isOwnComment)
                IconButton(
                  icon: const Icon(Icons.delete, size: 18),
                  onPressed: () => _chatService.deleteComment(
                    widget.postId,
                    comment['commentId'],
                    widget.currentUserId,
                  ),
                ),
            ],
          ),
          Text(comment['content']),
        ],
      ),
    );
  }
}