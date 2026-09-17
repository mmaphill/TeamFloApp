import 'package:cloud_firestore/cloud_firestore.dart';

class CompetitionStats {
  final DateTime compDate;
  final String compName;
  final String format; // 'Gi' or 'No Gi'
  final String rank; // For Gi: belt rank, For No Gi: Beginner, Intermediate, Advanced
  final String place; // overall competition placement
  final int submissionWins;
  final int pointWins;
  final int refDecisionWins;
  final int submissionLosses;
  final int pointLosses;
  final int refDecisionLosses;
  final int draws;

  CompetitionStats({
    required this.compDate,
    required this.compName,
    required this.format,
    required this.rank,
    this.place = '',
    this.submissionWins = 0,
    this.pointWins = 0,
    this.refDecisionWins = 0,
    this.submissionLosses = 0,
    this.pointLosses = 0,
    this.refDecisionLosses = 0,
    this.draws = 0,
  });

  factory CompetitionStats.fromMap(Map<String, dynamic> map) {
    // DateTime parsing
    DateTime parsedDate;
    if(map['compDate'] == null) {
      parsedDate = DateTime.now();
    } else if (map['compDate'] is DateTime) {
      parsedDate = map['compDate'];
    } else if (map['compDate'] is String) {
      try {
        parsedDate = DateTime.parse(map['compDate']);
      } catch (e) {
        parsedDate = DateTime.now();
      }
    } else {
      parsedDate = DateTime.now();
    }
    
    return CompetitionStats(
      compDate: (map['compDate'] is Timestamp)
          ? (map['compDate'] as Timestamp).toDate()
          : parsedDate,  // ← Use the safely-parsed date instead
      compName: map['compName'] ?? 'Unknown',
      format: map['format'] ?? 'Gi',
      rank: map['rank'] ?? '',
      place: map['place'] ?? '',
      submissionWins: map['submissionWins'] ?? 0,
      pointWins: map['pointWins'] ?? 0,
      refDecisionWins: map['refDecisionWins'] ?? 0,
      submissionLosses: map['submissionLosses'] ?? 0,
      pointLosses: map['pointLosses'] ?? 0,
      refDecisionLosses: map['refDecisionLosses'] ?? 0,
      draws: map['draws'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'compDate': compDate,
      'compName': compName,
      'format': format,
      'rank': rank,
      'place': place,
      'submissionWins': submissionWins,
      'pointWins': pointWins,
      'refDecisionWins': refDecisionWins,
      'submissionLosses': submissionLosses,
      'pointLosses': pointLosses,
      'refDecisionLosses': refDecisionLosses,
      'draws': draws,
    };
  }

  // set up something for team points based on competitions
  int get totalWins => submissionWins + pointWins + refDecisionWins;
  int get totalLosses => submissionLosses + pointLosses + refDecisionLosses;
}