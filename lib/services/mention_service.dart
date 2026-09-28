import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/log.dart';

class MentionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Search users by name prefix (case-insensitive)
  /// Returns list of {uid, name}
  Future<List<Map<String, dynamic>>> searchUsersByName(String query) async {
    if (query.isEmpty) return [];

    try {
      log('🔄 [MentionService.searchUsersByName] STARTED');
      log('   Query: "$query"');

      final queryLower = query.toLowerCase();
      log('   📋 Fetching ALL users from collection...');

      // Fetch all users
      final snapshot = await _firestore.collection('users').get();
      log('   √ Fetch succeeded');

      final users = snapshot.docs;
      log('   📊 Got ${users.length} total users');

      // Display all users for debugging
      log('   👥 All users in collection:');
      for (var doc in users) {
        final name = doc['name'] ?? 'Unknown';
        final uid = doc.id;
        log('      - $name (uid: $uid)');
      }

      // Filter client-side: name contains query
      log('   🔎 Filtering for name containing: "$query"');
      final results = <Map<String, dynamic>>[];

      for (var doc in users) {
        final name = doc['name'] ?? '';
        if (name.toLowerCase().contains(queryLower)) {
          log('      √ "$name" matches (lowercase: "${name.toLowerCase()}")');
          results.add({
            'uid': doc.id,
            'name': name,
          });
        }
      }

      log('   ✅ Search returned ${results.length} results');
      return results;
    } catch (e) {
      log('   ❌ Search error: $e');
      return [];
    }
  }
}