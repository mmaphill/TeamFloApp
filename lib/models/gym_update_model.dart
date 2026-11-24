import 'package:cloud_firestore/cloud_firestore.dart';

/// GYM UPDATES: one news post or event from the gym, shown on the Home
/// screen. Stored at gyms/{gymId}/updates/{updateId}.
///
/// Posted by owners, managers and front desk. Can have one picture or
/// video. An update with an eventDate hides itself the day after that date;
/// one without stays until someone deletes it.
class GymUpdate {
  static const String typeImage = 'image';
  static const String typeVideo = 'video';

  final String id;
  final String title;
  final String description;
  final String? mediaUrl;
  final String? mediaType; // 'image', 'video' or null
  final String? mediaPath; // Storage path, used to delete the file later
  final DateTime? eventDate; // the day only (midnight), or null
  final bool notify;
  final String createdBy;
  final String createdByName;
  final DateTime createdAt;

  GymUpdate({
    required this.id,
    required this.title,
    required this.description,
    this.mediaUrl,
    this.mediaType,
    this.mediaPath,
    this.eventDate,
    required this.notify,
    required this.createdBy,
    required this.createdByName,
    required this.createdAt,
  });

  bool get hasMedia => mediaUrl != null && mediaUrl!.isNotEmpty;
  bool get isVideo => mediaType == typeVideo;

  /// Members see an update until the day after its event date.
  bool isVisibleOn(DateTime now) {
    if (eventDate == null) return true;
    final today = DateTime(now.year, now.month, now.day);
    return !eventDate!.isBefore(today);
  }

  factory GymUpdate.fromMap(String id, Map<String, dynamic> map) {
    final event = _toDate(map['eventDate']);
    return GymUpdate(
      id: id,
      title: (map['title'] as String?) ?? '',
      description: (map['description'] as String?) ?? '',
      mediaUrl: map['mediaUrl'] as String?,
      mediaType: map['mediaType'] as String?,
      mediaPath: map['mediaPath'] as String?,
      eventDate: event == null ? null : DateTime(event.year, event.month, event.day),
      notify: map['notify'] == true,
      createdBy: (map['createdBy'] as String?) ?? '',
      createdByName: (map['createdByName'] as String?) ?? '',
      // A brand new update has no server time yet for a split second
      createdAt: _toDate(map['createdAt']) ?? DateTime.now(),
    );
  }

  /// Order for the Home feed: dated events first (soonest first), then
  /// everything else (newest first).
  static List<GymUpdate> sortForFeed(Iterable<GymUpdate> updates) {
    final dated = updates.where((u) => u.eventDate != null).toList()
      ..sort((a, b) => a.eventDate!.compareTo(b.eventDate!));
    final undated = updates.where((u) => u.eventDate == null).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return [...dated, ...undated];
  }

  static DateTime? _toDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }
}
