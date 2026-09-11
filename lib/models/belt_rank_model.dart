import 'package:cloud_firestore/cloud_firestore.dart';

class BeltRank {
  final String rank;
  final DateTime promotionDate;
  final String? notes;

  BeltRank({
    required this.rank,
    required this.promotionDate,
    this.notes,
  });

  factory BeltRank.fromMap(Map<String, dynamic> map) {
    return BeltRank(
      rank: map['rank'] ?? '',
      promotionDate: (map['promotionDate'] is Timestamp)
          ? (map['promotionDate'] as Timestamp).toDate()
          : map['promotionDate'] as DateTime,
      notes: map['notes'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'rank': rank,
      'promotionDate': promotionDate,
    };
  }
}