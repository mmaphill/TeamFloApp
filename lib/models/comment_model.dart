class CommentModel {
  final String commentId;
  final String userId;
  final String userName;
  final String content;
  final DateTime createdAt;

  CommentModel({
    required this.commentId,
    required this.userId,
    required this.userName,
    required this.content,
    required this.createdAt,
  });

  factory CommentModel.fromMap(Map<String, dynamic> map, String commentId) {
    return CommentModel(
      commentId: commentId,
      userId: map['userId'] ?? '',
      userName: map['userName'] ?? 'Unknown',
      content: map['content'] ?? '',
      createdAt: (map['createdAt'] as dynamic)?.toDate() ?? DateTime.now(),
    );
  }
}