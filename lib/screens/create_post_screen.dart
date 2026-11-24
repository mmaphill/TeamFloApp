import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import '../services/chat_service.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';
import '../widgets/mention_autocomplete_widget.dart';
import '../models/mention_model.dart';
import '../config/colors.dart';

/// POST MEDIA: one picked photo or video, waiting to be uploaded.
class _PickedMedia {
  final File file;
  final String type; // 'image' or 'video'
  _PickedMedia(this.file, this.type);
}

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  /// POST MEDIA: limits per post
  static const int _maxMedia = 4;
  static const int _maxVideoBytes = 200 * 1024 * 1024; // 200 MB

  final TextEditingController _postController = TextEditingController();
  final ChatService _chatService = ChatService();
  final AuthService _authService = AuthService();
  final StorageService _storageService = StorageService(); // POST MEDIA
  final ImagePicker _picker = ImagePicker(); // POST MEDIA
  bool _isLoading = false;
  final List<Mention> _mentions = [];
  String? _currentUserName;
  // POST MEDIA: picked items, in the order they'll show in the post
  final List<_PickedMedia> _media = [];
  // "Uploading ..." while posting
  String? _uploadStatus;

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

  // -------------- POST MEDIA ---------------
  bool get _canAddMore => _media.length < _maxMedia;

  Future<void> _pickImage() async {
    if (!_canAddMore) {
      _showMessage('You can add up to $_maxMedia photos or videos');
      return;
    }

    // MULTI-SELECT: pick several photos at once, up to the spots left.
    // pickMultiImage needs a limit of at least 2, so with one spot left
    // it falls back to picking a single photo.
    final int spotsLeft = _maxMedia - _media.length;
    final List<XFile> picked;
    if (spotsLeft >= 2) {
      picked = await _picker.pickMultiImage(
        limit: spotsLeft,
        maxWidth: 1920,
        imageQuality: 85, // keeps uploads small without visible loss
      );
    } else {
      final single = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        imageQuality: 85,
      );
      picked = single == null ? [] : [single];
    }
    if (picked.isEmpty) return;

    // Some Android galleries ignore the limit, so trim to the spots left
    final kept = picked.take(spotsLeft).toList();
    setState(() {
      _media.addAll(kept.map((x) => _PickedMedia(File(x.path), 'image')));
    });
    if (picked.length > kept.length) {
      _showMessage('Only the first $spotsLeft were added (max $_maxMedia per post)');
    }
  }

  Future<void> _pickVideo() async {
    if (!_canAddMore) {
      _showMessage('You can add up to $_maxMedia photos or videos');
      return;
    }

    final picked = await _picker.pickVideo(source: ImageSource.gallery, maxDuration: const Duration(minutes: 3),);
    if (picked == null) return;

    final file = File(picked.path);
    if (await file.length() > _maxVideoBytes) {
      _showMessage('That video is too large (max 200 MB). Try a shorter clip.');
      return;
    }
    setState(() => _media.add(_PickedMedia(file, 'video')));
  }

  void _removeMedia(int index) {
    setState(() => _media.removeAt(index));
  }

  Future<void> _submitPost() async {
    final postContent = _postController.text.trim();
    if (postContent.isEmpty && _media.isEmpty) {
      _showMessage('Write something or add a photo or video');
      return;
    }

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      _showMessage('User not logged in');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // POST MEDIA: upload each item first, so the post never points at a
      // missing file. Uses the existing posts/{userId}/ Storage folder.
      final List<String> mediaUrls = [];
      final List<String> mediaTypes = [];
      for (int i = 0; i < _media.length; i++) {
        if (_media.length > 1) {
          setState(() => _uploadStatus = 'Uploading ${i + 1} of ${_media.length}...');
        } else {
          setState(() => _uploadStatus = 'Uploading...');
        }

        final item = _media[i];
        final String? url = item.type == 'video'
            ? await _storageService.uploadVideo(item.file, currentUser.uid)
            : await _storageService.uploadImage(item.file, currentUser.uid);

        if (url == null) {
          throw Exception('Upload failed for ${item.type == 'video' ? 'a video' : 'a photo'}. Check your connection and try again.');
        }
        mediaUrls.add(url);
        mediaTypes.add(item.type);
      }

      if (mounted) setState(() => _uploadStatus = 'Posting...');

      // FIX: createPost returns an error message instead of throwing, and
      // that was ignored, so a failed post still showed "Post created!".
      final String? error = await _chatService.createPost(
        userId: currentUser.uid,
        userName: _currentUserName ?? 'Anonymous',
        content: postContent,
        mediaUrls: mediaUrls,
        mediaTypes: mediaTypes,
        mentions: _mentions,
      );
      if (error != null) throw Exception(error);

      if (!mounted) return;
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Post created!')),
      );
    } catch (e) {
      _showMessage('Error: ${e.toString().replaceFirst('Exception: ', '')}');
    } finally {
      // FIX: checked mounted, because after a successful post this screen
      // is already closed and setState would throw.
      if (mounted) {
        setState(() {
          _isLoading = false;
          _uploadStatus = null;
        });
      }
    }
  }

  void _showMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _isLoading ? null : () => Navigator.pop(context),
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
                    borderSide: BorderSide(
                      color: context.colors.primary,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: context.colors.primary,
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

              // POST MEDIA: previews of what's been picked
              if (_media.isNotEmpty) ...[
                _mediaPreviewRow(),
                const SizedBox(height: 12),
              ],

              // Image/Video buttons
              // POST MEDIA: these now open the gallery (were empty onPressed)
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: _isLoading || !_canAddMore ? null : _pickImage,
                    icon: const Icon(Icons.image),
                    label: const Text('Image'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: _isLoading || !_canAddMore ? null : _pickVideo,
                    icon: const Icon(Icons.videocam),
                    label: const Text('Video'),
                  ),
                  const Spacer(),
                  if (_media.isNotEmpty)
                    Text(
                      '${_media.length}/$_maxMedia',
                      style: TextStyle(color: context.colors.textMuted),
                    ),
                ],
              ),

              const SizedBox(height: 16),

              // Post button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.colors.primary,
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
                        AppColors.onPrimary,
                      ),
                    ),
                  )
                      : const Text(
                    'Post',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.onPrimary,
                    ),
                  ),
                ),
              ),

              // POST MEDIA: upload progress
              if (_uploadStatus != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(_uploadStatus!, textAlign: TextAlign.center),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// POST MEDIA: small square previews with an ✕ to remove each one.
  Widget _mediaPreviewRow() {
    const double size = 90;

    return SizedBox(
      height: size,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _media.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final item = _media[index];
          return Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: item.type == 'image'
                    ? Image.file(item.file, width: size, height: size, fit: BoxFit.cover)
                    : Container(
                  width: size,
                  height: size,
                  color: context.colors.surfaceHigh,
                  child: const Icon(Icons.play_circle_outline, size: 36),
                ),
              ),
              Positioned(
                top: 2,
                right: 2,
                child: GestureDetector(
                  onTap: _isLoading ? null : () => _removeMedia(index),
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close, size: 16, color: Colors.white),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}