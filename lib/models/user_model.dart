import 'belt_rank_model.dart';
import 'competition_stats_model.dart';

class UserModel {
  final String uid;
  final String email;
  final String name;
  final String role;
  final DateTime createdAt;
  final List<BeltRank> beltRankHistory;
  final String goals;
  final List<CompetitionStats> competitionStats;
  final String? photoUrl;
  final String avatarColor;
  final String? currentBelt;

  UserModel({
    required this.uid,
    required this.email,
    required this.name,
    required this.role,
    required this.createdAt,
    this.beltRankHistory = const [],
    this.goals = '',
    this.competitionStats = const [],
    this.photoUrl,
    this.avatarColor = '#2196F3',
    this.currentBelt,
  });

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] ?? '',
      email: map['email'] ?? '',
      name: map['name'] ?? '',
      role: map['role'] ?? 'member',
      createdAt: (map['createdAt'] as dynamic)?.toDate() ?? DateTime.now(),
      beltRankHistory: (map['beltRankHistory'] as List?)
        ?.map((item) => BeltRank.fromMap(item as Map<String, dynamic>))
        .toList() ?? [],
      goals: map['goals'] ?? '',
      competitionStats: (map['competitionStats'] as List?)
        ?.map((item) => CompetitionStats.fromMap(item as Map<String, dynamic>))
        .toList() ?? [],
      photoUrl: map['photoUrl'],
      avatarColor: map['avatarColor'] ?? '#2196F3',
      currentBelt: map['currentBelt'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'name': name,
      'role': role,
      'createdAt': createdAt,
      'beltRankHistory': beltRankHistory.map((b) => b.toMap()).toList(),
      'goals': goals,
      'competitionStats': competitionStats.map((c) => c.toMap()).toList(),
      'photoUrl': photoUrl,
      'avatarColor': avatarColor,
      'currentBelt': currentBelt,
    };
  }
}