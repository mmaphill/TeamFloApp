import 'package:cloud_firestore/cloud_firestore.dart';

/// Plan names. Each plan turns on a set of modules
class GymPlans{
  static const String community = 'community';
  static const String academy = 'academy';
  static const String branded = 'branded';
}

/// Module keys.
class GymModels {
  static const String community = 'community'; // feed, posts, comments
  static const String profiles = 'profiles'; // member profiles, belts
  static const String journal = 'journal'; // journal , techniques, stats
  static const String schedule = 'schedule'; // schedule, sign-ups, attendance
  static const String staffPortal = 'staffPortal'; // check-in, promotions, notes
  static const String dashboard = 'dashboard'; // business dashboard (web interface)
  static const String instagram = 'instagram'; // Instagram card on home screen
}

class GymModel {
  final String id;
  final String name;
  final String plan;
  final Map<String, bool> modules;
  final String? logoUrl;
  final String? primaryColor;
  final String? accentColor;
  final String? instagramHandle;
  final String? ownerUid;
  final DateTime? createdAt;
  final bool dataScoped;

  GymModel({
    required this.id,
    required this.name,
    required this.plan,
    required this.modules,
    this.logoUrl,
    this.primaryColor,
    this.accentColor,
    this.instagramHandle,
    this.ownerUid,
    this.createdAt,
    this.dataScoped = false,
  });

  static Map<String, bool> defaultModulesFor(String plan) {
    final bool academyOrUp = plan == GymPlans.academy || plan == GymPlans.branded;
    return {
      GymModels.community: true,
      GymModels.profiles: true,
      GymModels.journal: true,
      GymModels.instagram: true,
      GymModels.schedule: academyOrUp,
      GymModels.staffPortal: academyOrUp,
      GymModels.dashboard: academyOrUp,
    };
  }

  bool hasModule(String module) => modules[module] ?? false;

  factory GymModel.fromMap(String id, Map<String, dynamic> map) {
    final String plan = (map['plan'] as String?) ?? GymPlans.community;

    final Map<String, bool> modules = defaultModulesFor(plan);
    final saved = map['modules'];
    if (saved is Map) {
      saved.forEach((key, value) {
        if (key is String && value is bool) modules[key] = value;
      });
    }

    final created = map['createdAt'];

    return GymModel(
      id: id,
      name: (map['name'] as String?) ?? 'My Gym',
      plan: plan,
      modules: modules,
      logoUrl: map['logoUrl'] as String?,
      primaryColor: map['primaryColor'] as String?,
      accentColor: map['accentColor'] as String?,
      instagramHandle: map['instagramHandle'] as String?,
      ownerUid: map['ownerUid'] as String?,
      createdAt: created is Timestamp ? created.toDate() : null,
      dataScoped: map['dataScoped'] == true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'plan': plan,
      'modules': modules,
      'logoUrl': logoUrl,
      'primaryColor': primaryColor,
      'accentColor': accentColor,
      'instagramHandle': instagramHandle,
      'ownerUid': ownerUid,
      'createdAt': createdAt,
      'dataScoped': dataScoped,
    };
  }
}