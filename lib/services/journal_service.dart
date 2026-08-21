import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/journal_entry_model.dart';

class JournalService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Create or update journal entry
  Future<String?> saveJournalEntry(JournalEntry entry) async {
    try {
      if (entry.entryId.isEmpty) {
        // New entry
        DocumentReference docRef = await _firestore
            .collection('users')
            .doc(entry.userId)
            .collection('journal')
            .add(entry.toMap());
        return null; // Success
      } else {
        // Update existing
        await _firestore
            .collection('users')
            .doc(entry.userId)
            .collection('journal')
            .doc(entry.entryId)
            .update(entry.toMap());
        return null; // Success
      }
    } catch (e) {
      return e.toString();
    }
  }

  // Get journal entry for a specific date
  Future<JournalEntry?> getJournalEntry(String userId, DateTime date) async {
    try {
      DateTime startOfDay = DateTime(date.year, date.month, date.day);
      DateTime endOfDay =
      DateTime(date.year, date.month, date.day, 23, 59, 59);

      QuerySnapshot snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('journal')
          .where('date', isGreaterThanOrEqualTo: startOfDay)
          .where('date', isLessThanOrEqualTo: endOfDay)
          .get();

      if (snapshot.docs.isEmpty) {
        return null;
      }

      return JournalEntry.fromMap(
        snapshot.docs.first.data() as Map<String, dynamic>,
        snapshot.docs.first.id,
      );
    } catch (e) {
      return null;
    }
  }

  // Get all journal entries for a user (for analytics)
  Stream<List<JournalEntry>> getUserJournalStream(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('journal')
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) =>
          JournalEntry.fromMap(doc.data() as Map<String, dynamic>, doc.id))
          .toList();
    });
  }

  // Delete journal entry
  Future<String?> deleteJournalEntry(String userId, String entryId) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('journal')
          .doc(entryId)
          .delete();
      return null; // Success
    } catch (e) {
      return e.toString();
    }
  }

  // Get entries for date range (for analytics)
  Future<List<JournalEntry>> getEntriesInRange(
      String userId,
      DateTime startDate,
      DateTime endDate,
      ) async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('journal')
          .where('date', isGreaterThanOrEqualTo: startDate)
          .where('date', isLessThanOrEqualTo: endDate)
          .orderBy('date', descending: true)
          .get();

      return snapshot.docs
          .map((doc) =>
          JournalEntry.fromMap(doc.data() as Map<String, dynamic>, doc.id))
          .toList();
    } catch (e) {
      return [];
    }
  }
}