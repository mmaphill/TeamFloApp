class CompetitionStats {
  final String format; // 'Gi' or 'No Gi'
  final String rank; // For Gi: belt rank, For No Gi: Beginner, Intermediate, Advanced
  final int submissionWins;
  final int pointWins;
  final int refDecisionWins;
  final int submissionLosses;
  final int pointLosses;
  final int refDecisionLosses;

  CompetitionStats({
    required this.format,
    required this.rank,
    this.submissionWins = 0,
    this.pointWins = 0,
    this.refDecisionWins = 0,
    this.submissionLosses = 0,
    this.pointLosses = 0,
    this.refDecisionLosses = 0,
  });

  factory CompetitionStats.fromMap(Map<String, dynamic> map) {
    return CompetitionStats(
      format: map['format'] ?? 'Gi',
      rank: map['rank'] ?? '',
      submissionWins: map['submissionWins'] ?? 0,
      pointWins: map['pointWins'] ?? 0,
      refDecisionWins: map['refDecisionWins'] ?? 0,
      submissionLosses: map['submissionLosses'] ?? 0,
      pointLosses: map['pointLosses'] ?? 0,
      refDecisionLosses: map['refDecisionLosses'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'format': format,
      'rank': rank,
      'submissionWins': submissionWins,
      'pointWins': pointWins,
      'refDecisionWins': refDecisionWins,
      'submissionLosses': submissionLosses,
      'pointLosses': pointLosses,
      'refDecisionLosses': refDecisionLosses,
    };
  }

  int get totalWins => submissionWins + pointWins + refDecisionWins;
  int get totalLosses => submissionLosses + pointLosses + refDecisionLosses;
}