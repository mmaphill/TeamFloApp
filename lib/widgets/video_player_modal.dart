import 'dart:async';

import 'package:flutter/material.dart';
import '../config/colors.dart';
import 'package:video_player/video_player.dart';

class VideoPlayerModal extends StatefulWidget {
  final String videoUrl;

  const VideoPlayerModal({super.key, required this.videoUrl});

  @override
  State<VideoPlayerModal> createState() => _VideoPlayerModalState();
}

class _VideoPlayerModalState extends State<VideoPlayerModal> with SingleTickerProviderStateMixin {
  late VideoPlayerController _controller;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late Future<void> _initializeVideoPlayerFuture;

  Timer? _fadeTimer; // time for fading play/pause button
  double _dragDistance = 0; // track finger drag for closing when swiping

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
    _initializeVideoPlayerFuture = _controller.initialize();
    _controller.play();

    // Setup fade animation for play button
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );

    _scheduleFadeOut();
  }

  @override
  void dispose() {
    _fadeTimer?.cancel();
    _controller.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  void _scheduleFadeOut() {
    _fadeTimer?.cancel();
    _fadeTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) {
        _fadeController.forward();
      }
    });
  }

  void _handleTap() {
    setState((){
      if (_controller.value.isPlaying) {
        _controller.pause();
      } else {
        _controller.play();
      }
    });
    _fadeController.reverse();
    _scheduleFadeOut();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.mediaBackground,
      insetPadding: const EdgeInsets.all(0),
      child: GestureDetector(
        onTap: () => Navigator.pop(context),
        onVerticalDragStart: (_) {
          _dragDistance = 0;
        },
        onVerticalDragUpdate: (details) {
          _dragDistance += details.delta.dy;
        },
        onVerticalDragEnd: (details) {
          final speed = details.primaryVelocity ?? 0;
          if (_dragDistance > 120 || speed > 1200) {
            Navigator.pop(context);
          }
          _dragDistance = 0;
        },
        child: Stack(
          alignment: Alignment.center,
          children: [
            FutureBuilder<void>(
              future: _initializeVideoPlayerFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.done) {
                  return AspectRatio(
                    aspectRatio: _controller.value.aspectRatio,
                    child: VideoPlayer(_controller),
                  );
                } else {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }
              },
            ),
            // Close Button (top-right corner)
            Positioned(
              top: 16,
              right: 16,
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.mediaButtonBg,
                    shape: BoxShape.circle,
                  ),
                  padding: const EdgeInsets.all(8),
                  child: const Icon(
                    Icons.close,
                    color: AppColors.mediaForeground,
                    size: 28,
                  ),
                ),
              ),
            ),
            // Play/Pause Button with Fade (center)
            Positioned(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: GestureDetector(
                  onTap: _handleTap,
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.mediaButtonBg,
                      shape: BoxShape.circle,
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Icon(
                      _controller.value.isPlaying
                          ? Icons.pause
                          : Icons.play_arrow,
                      color: AppColors.mediaForeground,
                      size: 40,
                    ),
                  ),
                ),
              ),
            ),
            // Progress Bar (bottom)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: VideoProgressIndicator(
                _controller,
                allowScrubbing: true,
              ),
            ),
          ],
        ),
      ),
    );
  }
}