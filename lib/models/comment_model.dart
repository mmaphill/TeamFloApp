import 'mention_model.dart';

class CommentModel {
  final String commentId;
  final String userId;
  final String userName;
  final String content;
  final DateTime createdAt;
  final List<Mention> mentions;

  CommentModel({
    required this.commentId,
    required this.userId,
    required this.userName,
    required this.content,
    required this.createdAt,
    this.mentions = const [],
  });

  factory CommentModel.fromMap(Map<String, dynamic> map, String commentId) {
    return CommentModel(
      commentId: commentId,
      userId: map['userId'] ?? '',
      userName: map['userName'] ?? 'Unknown',
      content: map['content'] ?? '',
      createdAt: (map['createdAt'] as dynamic)?.toDate() ?? DateTime.now(),
      mentions: (map['mentions'] as List?)
        ?.map((item) => Mention.fromMap(item as Map<String, dynamic>))
        .toList() ?? [],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userName': userName,
      'content': content,
      'createdAt': createdAt,
      'mentions': mentions.map((m) => m.toMap()).toList(),
    };
  }
}