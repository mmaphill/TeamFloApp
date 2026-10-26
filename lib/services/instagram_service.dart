import 'package:team_flo_app/models/instagram_post.dart';
import 'gym_scope.dart';

class InstagramService {
  /// The gym's latest Instagram post.
  ///
  /// PHASE 1 STEP 6: each gym has its own. GymScope picks the location:
  ///   instagram/latestPost                (Team Flo, before migration)
  ///   gyms/{gymId}/instagram/latestPost   (scoped gyms)
  Stream<InstagramPost?> getLatestPostStream() {
    return GymScope.col('instagram')
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