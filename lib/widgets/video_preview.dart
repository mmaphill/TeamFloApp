import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../utils/log.dart';

class VideoPreview extends StatefulWidget {
  final String videoUrl;
  final VoidCallback onTap;

  const VideoPreview({super.key, 
    required this.videoUrl,
    required this.onTap,
  });

  @override
  State<VideoPreview> createState() => _VideoPreviewState();
}

class _VideoPreviewState extends State<VideoPreview> with SingleTickerProviderStateMixin {
  late VideoPlayerController _controller;
  late AnimationController _fadeController;

  @override
  void initState() {
    super.initState();
    log('🎬 VideoPreview: Initializing video for URL: ${widget.videoUrl}');

    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));

    _controller.initialize().then((_) {
      log('✓ VideoPreview: Video initialized successfully');
      log('✓ Is initialized: ${_controller.value.isInitialized}');
      log('✓ Aspect ratio: ${_controller.value.aspectRatio}');
      setState(() {});
    }).catchError((error) {
      log('✗ VideoPreview: Error initializing video: $error');
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        color: Colors.black,
        child: Stack(
          fit: StackFit.expand,
          alignment: Alignment.center,
          children: [
            if (_controller.value.isInitialized)
              Positioned.fill(
                child: VideoPlayer(_controller),
              )
            else
              const Center(
                child: CircularProgressIndicator(),
              ),
            // Static play icon - no fade
            const Icon(
              Icons.play_circle_outline,
              size: 80,
              color: Colors.white,
            ),
          ],
        ),
      ),
    );
  }
}