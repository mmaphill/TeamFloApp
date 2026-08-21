import 'dart:ffi';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../services/feed_service.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final FeedService _feedService = FeedService();
  final AuthService _authService = AuthService();
  final StorageService _storageService = StorageService();
  final ImagePicker _picker = ImagePicker();
  final _contentController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;
  late User _currentUser;
  String? _userName;
  List<File> _selectedMedia = [];
  List<String> _mediaTypes = [];

  @override
  void initState() {
    super.initState();
    _currentUser = FirebaseAuth.instance.currentUser!;
    _loadUserName();
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _loadUserName() async {
    final data = await _authService.getUserData(_currentUser.uid);
    if (data != null) {
      setState(() => _userName = data['name'] ?? 'Anonymous');
    }
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _selectedMedia.add(File(image.path));
        _mediaTypes.add('image');
      });
    }
  }

  Future<void> _pickVideo() async {
    final XFile? video = await _picker.pickVideo(source: ImageSource. gallery);
    if (video != null) {
      setState(() {
        _selectedMedia.add(File(video.path));
        _mediaTypes.add('video');
      });
    }
  }

  void _removeMedia(int index) {
    setState(() {
      _selectedMedia.removeAt(index);
      _mediaTypes.removeAt(index);
    });
  }

  Future<void> _createPost() async {
    if (_contentController.text.isEmpty) {
      setState(() => _errorMessage = 'Post cannot be empty');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    List<String> mediaUrls = [];
    List<String> uploadedMediaTypes = [];

    for (int i = 0; i < _selectedMedia.length; i++) {
      String? url;
      if (_mediaTypes[i] == 'image') {
        url = await _storageService.uploadImage(_selectedMedia[i], _currentUser.uid);
      } else {
        url = await _storageService.uploadVideo(_selectedMedia[i], _currentUser.uid);
      }

      if (url != null) {
        mediaUrls.add(url);
        uploadedMediaTypes.add(_mediaTypes[i]);
      }
    }

    String? error = await _feedService.createPost(
      userId: _currentUser.uid,
      userName: _userName ?? 'Anonymous',
      content: _contentController.text,
    );

    setState(() => _isLoading = false);

    if (error == null) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Post created successfully!')),
        );
      }
    } else {
      setState(() => _errorMessage = error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Post'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Error Message
            if (_errorMessage != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _errorMessage!,
                  style: TextStyle(color: Colors.red.shade700),
                ),
              ),
            if (_errorMessage != null) const SizedBox(height: 16),

            // Post Content TextField
            Expanded(
              child: TextField(
                controller: _contentController,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                decoration: InputDecoration(
                  hintText: 'Share your thoughts with the community...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Selected Media Preview
            if (_selectedMedia.isNotEmpty)
              SizedBox(
                height: 100,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _selectedMedia.length,
                  itemBuilder: (context, index) {
                    return Stack(
                      children: [
                        Container(
                          margin: const EdgeInsets.only(right: 8),
                          width: 100,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            image: _mediaTypes[index] == 'image'
                                ? DecorationImage(
                              image: FileImage(_selectedMedia[index]),
                              fit: BoxFit.cover,
                            )
                                : null,
                            color: _mediaTypes[index] == 'video'
                                ? Colors.black26
                                : null,
                          ),
                          child: _mediaTypes[index] == 'video'
                              ? const Center(
                            child: Icon(Icons.play_circle_outline),
                          )
                              : null,
                        ),
                        Positioned(
                          top: 0,
                          right: 8,
                          child: IconButton(
                            icon: const Icon(Icons.close,
                                color: Colors.white),
                            onPressed: () => _removeMedia(index),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            if (_selectedMedia.isNotEmpty) const SizedBox(height: 12),

            // Media Buttons
            Row(
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.image),
                  label: const Text('Image'),
                  onPressed: _pickImage,
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  icon: const Icon(Icons.videocam),
                  label: const Text('Video'),
                  onPressed: _pickVideo,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Post Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _createPost,
                child: _isLoading
                    ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                    : const Text('Post'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}