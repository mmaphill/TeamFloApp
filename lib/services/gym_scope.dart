import 'package:cloud_firestore/cloud_firestore.dart';
import 'gym_service.dart';

class GymScope {
  GymScope._();

  static FirebaseFirestore get _db => FirebaseFirestore.instance;

  static String get gymId => GymService.instance.gymId ?? GymService.legacyGymId;

  static bool get isScoped => GymService.instance.dataScoped;

  static CollectionReference<Map<String, dynamic>> col(String name) {
    if (isScoped) {
      return _db.collection('gyms').doc(gymId).collection(name);
    }
    return _db.collection(name);
  }

  static Query<Map<String, dynamic>> members() {
    final users = _db.collection('users');
    if (isScoped) {
      return users.where('gymId', isEqualTo: gymId);
    }
    return users;
  }
}