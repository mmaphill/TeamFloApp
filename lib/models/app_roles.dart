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

  /// Older Team Flo accounts use 'admin' for owner/manager.
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
  /// These match the Firestore rules and Cloud Functions. Hiding a button
  /// here is for tidiness; the server is what actually enforces it.

  /// FIX: was `== owner`, which hid the Staff Portal (and invites) from
  /// managers, instructors and front desk. Matches isStaff() in the rules.
  static bool isStaff(String? role) => _isOneOf(role, [owner, manager, instructor, frontDesk]);

  /// FIX: was `== manager` only, which left the owner out.
  static bool canEditGymSettings(String? role) => _isOneOf(role, [owner]);
  static bool canManageStaff(String? role) => _isOneOf(role, [owner, manager]);
  static bool canEditSchedule(String? role) => _isOneOf(role, [owner, manager]);
  static bool canTakeAttendance(String? role) => _isOneOf(role, [owner,manager, instructor, frontDesk]);
  /// FIX: added manager (the rules let owner, manager and instructor promote).
  static bool canPromote(String? role) => _isOneOf(role, [owner, manager, instructor]);
  static bool canAddStudentNotes(String? role) => _isOneOf(role, [owner, manager, instructor]);
  static bool canSendAnnouncements(String? role) => _isOneOf(role, [owner, manager, frontDesk]);
  static bool canAddLeads(String? role) => _isOneOf(role, [owner, manager, frontDesk]);
  static bool canManageMembers(String? role) => _isOneOf(role, [owner, manager]);
  static bool canViewDashboard(String? role) => _isOneOf(role, [owner, manager]);
  static bool canInvite(String? role) => isStaff(role);

  /// Can [myRole] remove someone with [theirRole] from the gym?
  /// Same rule as the removeFromGym Cloud Function: owners can remove
  /// anyone (except themselves, checked by the caller); managers can
  /// remove members, front desk and instructors only.
  static bool canRemove(String? myRole, String? theirRole) {
    final me = normalize(myRole);
    final them = normalize(theirRole);
    if (me == owner) return true;
    if (me == manager) return _isOneOf(them, [member, frontDesk, instructor]);
    return false;
  }

  static bool _isOneOf(String? role, List<String> roles) => roles.contains(normalize(role));
}