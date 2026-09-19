class Mention {
  final String userId;
  final String userName;
  final int startIndex;
  final int endIndex;

  Mention({
    required this.userId,
    required this.userName,
    required this.startIndex,
    required this.endIndex,
  });

  factory Mention.fromMap(Map<String, dynamic> map) {
    return Mention(
      userId: map['userId'] ?? '',
      userName: map['userName'] ?? '',
      startIndex: map['startIndex'] ?? 0,
      endIndex: map['endIndex'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userName': userName,
      'startIndex': startIndex,
      'endIndex': endIndex,
    };
  }
}