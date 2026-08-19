class PostModel {
  final String postId;
  final String userId;
  final String userName;
  final String content;
  final DateTime createdAt;
  final List<String> likedBy;
  final int commentCount;
  final List<String> mediaUrls;
  final List<String> mediaTypes;

  PostModel ({
    required this.postId,
    required this.userId,
    required this.userName,
    required this.content,
    required this.createdAt,
    this.likedBy = const [],
    this.commentCount = 0,
    this.mediaUrls = const [],
    this.mediaTypes = const [],
  });

  factory PostModel.fromMap(Map<String, dynamic> map, String postId) {
    return PostModel(
      postId: postId,
      userId: map['userId'] ?? '',
      userName: map['userName'] ?? 'Unknown',
      content: map['content'] ?? '',
      createdAt: (map['createdAt'] as dynamic)?.toDate() ?? DateTime.now(),
      likedBy: List<String>.from(map['likedBy'] ?? []),
      commentCount: map['commentCount'] ?? 0,
      mediaUrls: List<String>.from(map['mediaUrls'] ?? []),
      mediaTypes: List<String>.from(map['mediaTypes'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userName': userName,
      'content': content,
      'createdAt': createdAt,
      'likedBy': likedBy,
      'commentCount': commentCount,
      'mediaUrls': mediaUrls,
      'mediaTypes': mediaTypes,
    };
  }
}