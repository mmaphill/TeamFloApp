import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';
import '../models/gym_update_model.dart';
import '../utils/log.dart';
import 'gym_scope.dart';

/// GYM UPDATES: reads and writes gyms/{gymId}/updates, and uploads the
/// picture or video to Storage at gyms/{gymId}/updates/{random id}.
///
/// Firestore and Storage rules only let owners, managers and front desk
/// write, so the app hiding the buttons is for tidiness, not security.
class GymUpdateService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  CollectionReference<Map<String, dynamic>> get _updates =>
      _db.collection('gyms').doc(GymScope.gymId).collection('updates');

  /// Newest 50 updates, live. Members filter out past events on screen
  /// (GymUpdate.isVisibleOn); staff see past ones too.
  Stream<List<GymUpdate>> updatesStream({int limit = 50}) {
    return _updates
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.map((d) => GymUpdate.fromMap(d.id, d.data())).toList());
  }

  /// One update, or null if it was deleted (used when opened from a notification).
  Future<GymUpdate?> getUpdate(String id) async {
    final doc = await _updates.doc(id).get();
    final data = doc.data();
    return data == null ? null : GymUpdate.fromMap(doc.id, data);
  }

  Future<void> create({
    required String title,
    required String description,
    DateTime? eventDate,
    required bool notify,
    File? mediaFile,
    String? mediaType,
  }) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    // Upload first, so the update never points at a missing file
    _UploadedMedia? media;
    if (mediaFile != null && mediaType != null) {
      media = await _uploadMedia(mediaFile, mediaType);
    }

    try {
      await _updates.add({
        'title': title,
        'description': description,
        'mediaUrl': media?.url,
        'mediaType': media == null ? null : mediaType,
        'mediaPath': media?.path,
        'eventDate': eventDate == null ? null : Timestamp.fromDate(_dayOnly(eventDate)),
        // The notify function only acts on new updates, so this is read once
        'notify': notify,
        'createdBy': uid,
        'createdByName': await _myName(uid),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // The save failed, so don't leave the uploaded file behind
      if (media != null) await _deleteFile(media.path);
      rethrow;
    }
  }

  /// Saves changes to an existing update.
  /// Media: pass [newMediaFile] + [newMediaType] to replace it, or
  /// [removeMedia] to take it off. Otherwise the current media stays.
  Future<void> edit(
      GymUpdate original, {
        required String title,
        required String description,
        DateTime? eventDate,
        File? newMediaFile,
        String? newMediaType,
        bool removeMedia = false,
      }) async {
    final Map<String, dynamic> changes = {
      'title': title,
      'description': description,
      'eventDate': eventDate == null ? null : Timestamp.fromDate(_dayOnly(eventDate)),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    _UploadedMedia? uploaded;
    final bool replacing = newMediaFile != null && newMediaType != null;
    if (replacing) {
      uploaded = await _uploadMedia(newMediaFile, newMediaType);
      changes['mediaUrl'] = uploaded.url;
      changes['mediaType'] = newMediaType;
      changes['mediaPath'] = uploaded.path;
    } else if (removeMedia) {
      changes['mediaUrl'] = null;
      changes['mediaType'] = null;
      changes['mediaPath'] = null;
    }

    try {
      await _updates.doc(original.id).update(changes);
    } catch (e) {
      if (uploaded != null) await _deleteFile(uploaded.path);
      rethrow;
    }

    // Saved, so the old file is no longer used
    if ((replacing || removeMedia) && original.mediaPath != null) {
      await _deleteFile(original.mediaPath!);
    }
  }

  Future<void> delete(GymUpdate update) async {
    await _updates.doc(update.id).delete();
    if (update.mediaPath != null) await _deleteFile(update.mediaPath!);
  }

  // ---------- Helpers ----------

  Future<_UploadedMedia> _uploadMedia(File file, String mediaType) async {
    final bool isVideo = mediaType == GymUpdate.typeVideo;
    final String ext = _extensionOf(file.path, fallback: isVideo ? 'mp4' : 'jpg');

    // The Storage rules check the content type, so it must be set here
    final String contentType = isVideo
        ? (ext == 'mov' ? 'video/quicktime' : 'video/mp4')
        : (ext == 'png' ? 'image/png' : 'image/jpeg');

    final path = 'gyms/${GymScope.gymId}/updates/${const Uuid().v4()}.$ext';
    final ref = _storage.ref().child(path);
    await ref.putFile(file, SettableMetadata(contentType: contentType));
    return _UploadedMedia(await ref.getDownloadURL(), path);
  }

  /// Deleting an old file is a cleanup step. If it fails, the update is
  /// still correct, so log it and carry on.
  Future<void> _deleteFile(String path) async {
    try {
      await _storage.ref().child(path).delete();
    } catch (e) {
      log('Could not delete update media $path: $e');
    }
  }

  Future<String> _myName(String uid) async {
    try {
      final data = (await _db.collection('users').doc(uid).get()).data();
      final name = (data?['name'] as String?)?.trim();
      return (name == null || name.isEmpty) ? 'Staff' : name;
    } catch (_) {
      return 'Staff';
    }
  }

  static DateTime _dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  static String _extensionOf(String path, {required String fallback}) {
    final dot = path.lastIndexOf('.');
    if (dot == -1 || dot == path.length - 1) return fallback;
    final ext = path.substring(dot + 1).toLowerCase();
    return ext.length > 4 ? fallback : ext;
  }
}

class _UploadedMedia {
  final String url;
  final String path;
  _UploadedMedia(this.url, this.path);
}
