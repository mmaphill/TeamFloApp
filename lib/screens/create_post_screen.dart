import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/chat_service.dart';
import '../services/auth_service.dart';
import '../widgets/mention_autocomplete_widget.dart';
import '../models/mention_model.dart';
import '../config/colors.dart';

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final TextEditingController _postController = TextEditingController();
  final ChatService _chatService = ChatService();
  final AuthService _authService = AuthService();
  bool _isLoading = false;
  final List<Mention> _mentions = [];
  String? _currentUserName;

  @override
  void initState() {
    super.initState();
    _loadCurrentUserName();
  }

  Future<void> _loadCurrentUserName() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId != null) {
      final data = await _authService.getUserData(userId);
      if (data != null) {
        setState(() => _currentUserName = data['name'] ?? 'Anonymous');
      }
    }
  }

  @override
  void dispose() {
    _postController.dispose();
    super.dispose();
  }

  void _onMentionSelected(String userId, String userName) {
    // Find the mention in the text and store it
    final text = _postController.text;
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
    }
  }

  Future<void> _submitPost() async {
    final postContent = _postController.text.trim();
    if (postContent.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Post cannot be empty')),
      );
      return;
    }

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User not logged in')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _chatService.createPost(
        userId: currentUser.uid,
        userName: _currentUserName ?? 'Anonymous',
        content: postContent,
        mentions: _mentions,
      );

      if (!mounted) return;
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Post created!')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Create Post'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Text input with mention dropdown
              TextField(
                controller: _postController,
                maxLines: 8,
                minLines: 6,
                decoration: InputDecoration(
                  hintText: 'What\'s on your mind? (@mention teammates)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: AppColors.primary,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: AppColors.primary,
                      width: 2,
                    ),
                  ),
                  contentPadding: const EdgeInsets.all(12),
                ),
              ),
              const SizedBox(height: 12),

              // Mention autocomplete (dropdown only, no list)
              MentionAutocomplete(
                textController: _postController,
                onMentionSelected: _onMentionSelected,
              ),

              const SizedBox(height: 16),

              // Image/Video buttons
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.image),
                    label: const Text('Image'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.videocam),
                    label: const Text('Video'),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Post button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: _isLoading ? null : _submitPost,
                  child: _isLoading
                      ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Colors.white,
                      ),
                    ),
                  )
                      : const Text(
                    'Post',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}