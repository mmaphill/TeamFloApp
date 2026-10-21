import 'app_roles.dart';
import 'belt_rank_model.dart';
import 'competition_stats_model.dart';
import 'photo_crop_model.dart';

class UserModel {
  final String uid;
  final String email;
  final String name;
  final String role;
  final String? gymId;
  final DateTime createdAt;
  final DateTime? dob;
  final List<BeltRank> beltRankHistory;
  final String goals;
  final List<CompetitionStats> competitionStats;
  final String? photoUrl;
  final PhotoCropData? photoCropData;
  final String avatarColor;
  final String? currentBelt;
  final String? themeMode;
  final bool notificationsEnabled;
  final String? fcmToken;
  final bool showAge;
  final bool showCompStats;

  UserModel({
    required this.uid,
    required this.email,
    required this.name,
    required this.role,
    this.gymId,
    required this.createdAt,
    this.dob,
    this.beltRankHistory = const [],
    this.goals = '',
    this.competitionStats = const [],
    this.photoUrl,
    this.photoCropData,
    this.avatarColor = '#2196F3',
    this.currentBelt,
    this.themeMode,
    this.notificationsEnabled = false,
    this.fcmToken,
    this.showAge = true,
    this.showCompStats = false,
  });

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] ?? '',
      email: map['email'] ?? '',
      name: map['name'] ?? '',
      role: map['role'] ?? 'member',
      gymId: map['gymId'],
      dob: (map['dob'] as dynamic)?.toDate(),
      createdAt: (map['createdAt'] as dynamic)?.toDate() ?? DateTime.now(),
      beltRankHistory: (map['beltRankHistory'] as List?)
        ?.map((item) => BeltRank.fromMap(item as Map<String, dynamic>))
        .toList() ?? [],
      goals: map['goals'] ?? '',
      competitionStats: (map['competitionStats'] as List?)
        ?.map((item) => CompetitionStats.fromMap(item as Map<String, dynamic>))
        .toList() ?? [],
      photoUrl: map['photoUrl'],
      photoCropData: map['photoCropData'] != null ? PhotoCropData.fromMap(map['photoCropData'] as Map<String, dynamic>) : null,
      avatarColor: map['avatarColor'] ?? '#2196F3',
      currentBelt: map['currentBelt'],
      themeMode: map['themeMode'],
      notificationsEnabled: map['notificationsEnabled'] ?? false,
      fcmToken: map['fcmToken'],
      showAge: map['showAge'] ?? true,
      showCompStats: map['showCompStats'] ?? false,
    );
  }

  /// Returns a copy of this user with only the given fields changed.
  /// Every field you don't pass keeps its current value.
  UserModel copyWith({
    String? uid,
    String? email,
    String? name,
    String? role,
    String? gymId,
    DateTime? createdAt,
    DateTime? dob,
    List<BeltRank>? beltRankHistory,
    String? goals,
    List<CompetitionStats>? competitionStats,
    String? photoUrl,
    PhotoCropData? photoCropData,
    String? avatarColor,
    String? currentBelt,
    String? themeMode,
    bool? notificationsEnabled,
    String? fcmToken,
    bool? showAge,
    bool? showCompStats,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      name: name ?? this.name,
      role: role ?? this.role,
      gymId: gymId ?? this.gymId,
      createdAt: createdAt ?? this.createdAt,
      dob: dob ?? this.dob,
      beltRankHistory: beltRankHistory ?? this.beltRankHistory,
      goals: goals ?? this.goals,
      competitionStats: competitionStats ?? this.competitionStats,
      photoUrl: photoUrl ?? this.photoUrl,
      photoCropData: photoCropData ?? this.photoCropData,
      avatarColor: avatarColor ?? this.avatarColor,
      currentBelt: currentBelt ?? this.currentBelt,
      themeMode: themeMode ?? this.themeMode,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      fcmToken: fcmToken ?? this.fcmToken,
      showAge: showAge ?? this.showAge,
      showCompStats: showCompStats ?? this.showCompStats,
    );
  }

  String get normalizedRole => AppRoles.normalize(role);

  bool get isStaff => AppRoles.isStaff(role);

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'name': name,
      'role': role,
      if (gymId != null) 'gymId': gymId,
      'dob': dob,
      'createdAt': createdAt,
      'beltRankHistory': beltRankHistory.map((b) => b.toMap()).toList(),
      'goals': goals,
      'competitionStats': competitionStats.map((c) => c.toMap()).toList(),
      'photoUrl': photoUrl,
      'photoCropData': photoCropData?.toMap(),
      'avatarColor': avatarColor,
      'currentBelt': currentBelt,
      'themeMode': themeMode,
      'notificationsEnabled': notificationsEnabled,
      'fcmToken': fcmToken,
      'showAge': showAge,
      'showCompStats': showCompStats,
    };
  }
}