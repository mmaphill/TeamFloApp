import 'package:cloud_firestore/cloud_firestore.dart';

class MentionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Search users by name prefix (case-insensitive)
  /// Returns list of {uid, name}
  Future<List<Map<String, dynamic>>> searchUsersByName(String query) async {
    if (query.isEmpty) return [];

    try {
      print('🔄 [MentionService.searchUsersByName] STARTED');
      print('   Query: "$query"');

      final queryLower = query.toLowerCase();
      print('   📋 Fetching ALL users from collection...');

      // Fetch all users
      final snapshot = await _firestore.collection('users').get();
      print('   √ Fetch succeeded');

      final users = snapshot.docs;
      print('   📊 Got ${users.length} total users');

      // Display all users for debugging
      print('   👥 All users in collection:');
      for (var doc in users) {
        final name = doc['name'] ?? 'Unknown';
        final uid = doc.id;
        print('      - $name (uid: $uid)');
      }

      // Filter client-side: name contains query
      print('   🔎 Filtering for name containing: "$query"');
      final results = <Map<String, dynamic>>[];

      for (var doc in users) {
        final name = doc['name'] ?? '';
        if (name.toLowerCase().contains(queryLower)) {
          print('      √ "$name" matches (lowercase: "${name.toLowerCase()}")');
          results.add({
            'uid': doc.id,
            'name': name,
          });
        }
      }

      print('   ✅ Search returned ${results.length} results');
      return results;
    } catch (e) {
      print('   ❌ Search error: $e');
      return [];
    }
  }
}