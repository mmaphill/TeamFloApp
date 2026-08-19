import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Upload image
  Future<String?> uploadImage(File imageFile, String userId) async {
    try {
      String fileName = 'posts/$userId/${const Uuid().v4()}.jpg';
      Reference ref = _storage.ref().child(fileName);
      await ref.putFile(imageFile);
      String downloadUrl = await ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      return null;
    }
  }

  // Upload video
  Future<String?> uploadVideo(File videoFile, String userId) async {
    try {
      String fileName = 'posts/$userId/${const Uuid().v4()}.mp4';
      Reference ref = _storage.ref().child(fileName);
      await ref.putFile(videoFile);
      String downloadUrl = await ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      return null;
    }
  }
}