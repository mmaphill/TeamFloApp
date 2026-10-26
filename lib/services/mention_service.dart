import '../utils/log.dart';
import 'gym_scope.dart';

class MentionService {
  /// Search this gym's members by name (case-insensitive, matches anywhere
  /// in the name). Returns a list of {uid, name}.
  ///
  /// PHASE 1 STEP 3: searches GymScope.members(), so once the gym is
  /// scoped you can only @mention people in your own gym.
  Future<List<Map<String, dynamic>>> searchUsersByName(String query) async {
    if (query.isEmpty) return [];

    try {
      final queryLower = query.toLowerCase();
      final snapshot = await GymScope.members().get();

      final results = <Map<String, dynamic>>[];
      for (final doc in snapshot.docs) {
        // data()['name'] instead of doc['name']: doc['name'] throws if a
        // user document has no name field.
        final String name = (doc.data()['name'] ?? '').toString();
        if (name.toLowerCase().contains(queryLower)) {
          results.add({
            'uid': doc.id,
            'name': name,
          });
        }
      }

      log('[MentionService] "$query": ${results.length} of ${snapshot.docs.length} members match');
      return results;
    } catch (e) {
      log('[MentionService] Search error: $e');
      return [];
    }
  }
}