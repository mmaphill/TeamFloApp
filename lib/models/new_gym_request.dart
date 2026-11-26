import 'gym_model.dart';

/// PLATFORM ADMIN (Milestone 1): everything needed to create a new gym.
class NewGymRequest {
  final String gymId;
  final String name;
  final String plan;
  final String ownerEmail;
  final String? primaryColor;
  final String? instagramHandle;

  const NewGymRequest({
    required this.gymId,
    required this.name,
    required this.plan,
    required this.ownerEmail,
    this.primaryColor,
    this.instagramHandle,
  });

  Map<String, dynamic> toMap() {
    final color = primaryColor?.trim();
    final handle = instagramHandle?.trim();
    return {
      'gymId': gymId.trim(),
      'name': name.trim(),
      'plan': plan.trim(),
      'ownerEmail': ownerEmail.trim().toLowerCase(),
      if (color != null && color.isNotEmpty) 'primaryColor': color,
      if (handle != null && handle.isNotEmpty) 'instagramHandle': handle,
    };
  }

  /// The gym's ID becomes its Firestore document ID: gyms/{gymId}.
  static String? validateGymId(String? value) {
    if (value == null || value.isEmpty) return 'Enter GymId';
    if (value.length < 3 || value.length > 30) return 'Use 3 to 30 characters';
    if (!RegExp(r'^[a-z0-9]+(-[a-z0-9]+)*$').hasMatch(value)) return 'Use lowercase letters, numbers, and single hyphens';
    return null;
  }

  /// The gym's display name, e.g. "Team Flo BJJ".
  static String? validateName(String? value) {
    final name = value?.trim() ?? '';
    if (name.isEmpty) return 'Enter gym name';
    if (name.length > 60) return 'No more than 60 characters';
    return null;
  }

  /// The email the owner's invite goes to.
  static String? validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'Enter the owner\'s email';
    if (!RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$').hasMatch(email)) return 'Enter a valid email';
    return null;
  }

  /// Optional brand color, like "#1E88E5".
  static String? validateHexColor(String? value) {
    final color = value?.trim() ?? '';
    if (color.isEmpty) return null;
    if (GymModel.parseHexColor(color) == null) return 'Use a 6-digit hex color, like #1E88E5';
    return null;
  }

  static String suggestGymId(String name) {
    return name
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), '')
        .replaceAll(RegExp(r'\s+'), '-');
  }
}
