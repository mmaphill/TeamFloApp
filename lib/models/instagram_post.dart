import 'package:cloud_firestore/cloud_firestore.dart';

class InstagramPost {
  final String imageUrl;
  final String postLink;
  final String caption;
  final DateTime timestamp;

  InstagramPost({
    required this.imageUrl,
    required this.postLink,
    required this.caption,
    required this.timestamp,
  });

  factory InstagramPost.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return InstagramPost(
      imageUrl: data['imageUrl'] ?? '',
      postLink: data['postLink'] ?? '',
      caption: data['caption'] ?? '',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}