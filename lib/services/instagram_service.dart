import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:team_flo_app/models/instagram_post.dart';

class InstagramService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<InstagramPost?> getLatestPostStream() {
    return _firestore
        .collection('instagram')
        .doc('latestPost')
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists) {
        return null;
      }
      return InstagramPost.fromFirestore(snapshot);
    });
  }
}