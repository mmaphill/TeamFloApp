import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:team_flo_app/models/instagram_post.dart';
import 'package:team_flo_app/services/instagram_service.dart';
import 'package:team_flo_app/config/theme_provider.dart';

class InstagramFeedWidget extends StatelessWidget {
  const InstagramFeedWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final instagramService = InstagramService();
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;

    return StreamBuilder<InstagramPost?>(
      stream: instagramService.getLatestPostStream(),
      builder: (context, snapshot) {
        // Loading state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingCard(context, isDarkMode);
        }

        // Error state
        if (snapshot.hasError) {
          return _buildErrorCard(context, isDarkMode);
        }

        // No data
        if (!snapshot.hasData || snapshot.data == null) {
          return _buildEmptyCard(context, isDarkMode);
        }

        final post = snapshot.data!;

        return GestureDetector(
          onTap: () => _openInstagramPost(post.postLink),
          child: Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image with Instagram indicator
                Stack(
                  children: [
                    AspectRatio(
                      aspectRatio: 1 / 1,  // Square
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(12),
                            topRight: Radius.circular(12),
                          ),
                          color: Colors.grey[300],
                        ),
                        child: Image.network(
                          post.imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Center(
                              child: Icon(
                                Icons.image_not_supported,
                                color: Colors.grey[400],
                                size: 48,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    // Instagram logo badge - this must be outside AspectRatio, as a Stack child
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.camera_alt,
                          color: Color(0xFFE4405F), // Instagram pink
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
                // Caption
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Latest from Instagram',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        post.caption,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tap to view on Instagram →',
                        style: TextStyle(
                          fontSize: 11,
                          color: const Color(0xFFE4405F),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLoadingCard(BuildContext context, bool isDarkMode) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        height: 300,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: isDarkMode ? const Color(0xFF1E1E1E) : const Color(0xFFF5F0F5),
        ),
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      ),
    );
  }

  Widget _buildErrorCard(BuildContext context, bool isDarkMode) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        height: 150,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: isDarkMode ? const Color(0xFF1E1E1E) : const Color(0xFFF5F0F5),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, color: Colors.red[400]),
              const SizedBox(height: 8),
              const Text('Error loading Instagram feed'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyCard(BuildContext context, bool isDarkMode) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        height: 150,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: isDarkMode ? const Color(0xFF1E1E1E) : const Color(0xFFF5F0F5),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.camera_alt, color: Color(0xFFE4405F)),
              const SizedBox(height: 8),
              const Text('No Instagram posts yet'),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openInstagramPost(String url) async {
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
    }
  }
}