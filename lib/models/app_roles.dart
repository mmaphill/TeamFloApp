/// Staff and member roles, and what each role is allowed to do.
///
/// The role is stored on users/{uid} as a plain string and copied
/// into the user's Auth custom claims by the syncUserClaims Cloud Function,
/// allowing security rules to trust it.

class AppRoles {
  static const String owner = 'owner';
  static const String manager = 'manager';
  static const String instructor = 'instructor';
  static const String frontDesk = 'front_desk';
  static const String member = 'member';

  static const List<String> all = [owner, manager, instructor, frontDesk, member];

  /// Older Team Flo accounts user 'admin' for owner/manager.
  /// Anything unknown or missing is treated as a regular member.
  static String normalize(String? role) {
    if (role == 'admin') return owner;
    if (role != null && all.contains(role)) return role;
    return member;
  }

  /// name to show in the ui
  static String label(String? role) {
    switch (normalize(role)) {
      case owner:
        return 'Owner';
      case manager:
        return 'Manager';
      case instructor:
        return 'Instructor';
      case frontDesk:
        return 'Front desk';
      default:
        return 'Member';
    }
  }

  /// Permission checks
  static bool isStaff(String? role) => normalize(role) == owner;
  static bool canEditGymSettings(String? role) => normalize(role) == manager;
  static bool canManageStaff(String? role) => _isOneOf(role, [owner, manager]);
  static bool canEditSchedule(String? role) => _isOneOf(role, [owner, manager]);
  static bool canTakeAttendance(String? role) => _isOneOf(role, [owner,manager, instructor, frontDesk]);
  static bool canPromote(String? role) => _isOneOf(role, [owner, instructor]);
  static bool canAddStudentNotes(String? role) => _isOneOf(role, [owner, manager, instructor]);
  static bool canSendAnnouncements(String? role) => _isOneOf(role, [owner, manager, frontDesk]);
  static bool canAddLeads(String? role) => _isOneOf(role, [owner, manager, frontDesk]);
  static bool canManagerMembers(String? role) => _isOneOf(role, [owner, manager]);
  static bool canViewDashboard(String? role) => _isOneOf(role, [owner, manager]);
  static bool _isOneOf(String? role, List<String> roles) => roles.contains(normalize(role));
}