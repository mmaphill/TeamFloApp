import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/painting.dart' show Color;
import '../config/colors.dart';

/// Plan names. Each plan turns on a set of modules (see defaultModulesFor).
class GymPlans {
  static const String community = 'community';
  static const String academy = 'academy';
  static const String branded = 'branded';
}

/// Module keys. These match the "Feature modules" table in the plan doc.
class GymModules {
  static const String community = 'community';     // feed, posts, comments
  static const String profiles = 'profiles';       // member profiles, belts
  static const String journal = 'journal';         // journal, techniques, stats
  static const String schedule = 'schedule';       // schedule, sign-ups, attendance
  static const String staffPortal = 'staffPortal'; // check-in, promotions, notes
  static const String dashboard = 'dashboard';     // business dashboard (web)
  static const String instagram = 'instagram';     // Instagram card on home screen
}

/// One gym's settings, stored at gyms/{gymId}.
class GymModel {
  final String id;
  final String name;
  final String plan;
  final Map<String, bool> modules;
  final String? logoUrl;
  final String? primaryColor; // hex, e.g. '#1E88E5'
  final String? accentColor;  // hex
  final String? instagramHandle;
  final String? ownerUid;
  final DateTime? createdAt;

  /// True once this gym's posts, classes and attendance live under
  /// gyms/{gymId}/. New gyms start with true. Team Flo stays false
  /// until the step 7 migration copies its data, then it's flipped on.
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

  /// Modules each plan turns on. A gym document can override any of these
  /// in its own 'modules' map (for example, to trial a module).
  static Map<String, bool> defaultModulesFor(String plan) {
    final bool academyOrUp = plan == GymPlans.academy || plan == GymPlans.branded;
    return {
      GymModules.community: true,
      GymModules.profiles: true,
      GymModules.journal: true,
      GymModules.instagram: true,
      GymModules.schedule: academyOrUp,
      GymModules.staffPortal: academyOrUp,
      GymModules.dashboard: academyOrUp,
    };
  }

  /// True if this gym has [module] turned on.
  bool hasModule(String module) => modules[module] ?? false;

  // ---------- Branding (PHASE 1 STEP 6) ----------

  /// The gym's main color, or null if not set (the app then uses Team Flo red).
  Color? get primaryColorValue => parseHexColor(primaryColor);

  /// The gym's accent color, or null if not set.
  Color? get accentColorValue => parseHexColor(accentColor);

  /// '#1E88E5' or '1E88E5' -> Color. Returns null for anything unreadable,
  /// so a typo in the gym document falls back to the default instead of crashing.
  static Color? parseHexColor(String? hex) {
    if (hex == null) return null;
    final cleaned = hex.trim().replaceFirst('#', '');
    if (cleaned.length != 6) return null;
    final value = int.tryParse(cleaned, radix: 16);
    if (value == null) return null;
    return AppColors.fromRgb(value);
  }

  factory GymModel.fromMap(String id, Map<String, dynamic> map) {
    final String plan = (map['plan'] as String?) ?? GymPlans.community;

    // Start from the plan's defaults, then apply any overrides saved on the gym.
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