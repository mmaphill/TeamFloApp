class BeltRank {
  final String rank;
  final DateTime promotionDate;

  BeltRank({
    required this.rank,
    required this.promotionDate,
  });

  factory BeltRank.fromMap(Map<String, dynamic> map) {
    return BeltRank(
      rank: map['rank'] ?? '',
      promotionDate: (map['promotionDate'] as dynamic)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'rank': rank,
      'promotionDate': promotionDate,
    };
  }
}