class JournalEntry {
  final String entryId;
  final String userId;
  final DateTime date;
  final String? photoUrl; // Optional photo

  // Classes attended
  final List<String> classesAttended; // Class IDs

  // Metrics (1-5 scale)
  final int energy; // 1-5
  final int sleep; // 1-5
  final int water; // 1-5
  final int food; // 1-5

  // Training data
  final String? position; // Closed Guard, Open Guard, etc.
  final String? types; // Pass, Sweep, Submit
  final Map<String, List<String>> techniques; // User entered field
  final int rounds; // Number of rounds training
  final int submissions; // Number of submissions
  final List<String> madeSubmissions; // One optional entry per submission (e.g. "Armbar", "RNC")
  final int submissionAttempts; // Total number of submissions attempted
  final int timesSubmitted; // Number of times submitted
  final String generalNotes; // Notes about training

  // Metadata
  final DateTime createdAt;
  final DateTime? updatedAt;

  JournalEntry({
    required this.entryId,
    required this.userId,
    required this.date,
    this.photoUrl,
    this.classesAttended = const [],
    this.energy = 0,
    this.sleep = 0,
    this.water = 0,
    this.food = 0,
    this.position,
    this.types,
    this.techniques = const {},
    this.rounds = 0,
    this.submissions = 0,
    this.madeSubmissions = const [],
    this.submissionAttempts = 0,
    this.timesSubmitted = 0,
    this.generalNotes = '',
    required this.createdAt,
    this.updatedAt,
  });

  /// Returns a copy of this entry with only the given fields changed.
  /// Any field you don't pass keeps its current value.
  JournalEntry copyWith({
    String? entryId,
    String? userId,
    DateTime? date,
    String? photoUrl,
    List<String>? classesAttended,
    int? energy,
    int? sleep,
    int? water,
    int? food,
    String? position,
    String? types,
    Map<String, List<String>>? techniques,
    int? rounds,
    int? submissions,
    List<String>? madeSubmissions,
    int? submissionAttempts,
    int? timesSubmitted,
    String? generalNotes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return JournalEntry(
      entryId: entryId ?? this.entryId,
      userId: userId ?? this.userId,
      date: date ?? this.date,
      photoUrl: photoUrl ?? this.photoUrl,
      classesAttended: classesAttended ?? this.classesAttended,
      energy: energy ?? this.energy,
      sleep: sleep ?? this.sleep,
      water: water ?? this.water,
      food: food ?? this.food,
      position: position ?? this.position,
      types: types ?? this.types,
      techniques: techniques ?? this.techniques,
      rounds: rounds ?? this.rounds,
      submissions: submissions ?? this.submissions,
      madeSubmissions: madeSubmissions ?? this.madeSubmissions,
      submissionAttempts: submissionAttempts ?? this.submissionAttempts,
      timesSubmitted: timesSubmitted ?? this.timesSubmitted,
      generalNotes: generalNotes ?? this.generalNotes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory JournalEntry.fromMap(Map<String, dynamic> map, String entryId) {
    return JournalEntry(
      entryId: entryId,
      userId: map['userId'] ?? '',
      date: (map['date'] as dynamic)?.toDate() ?? DateTime.now(),
      photoUrl: map['photoUrl'],
      classesAttended: List<String>.from(map['classesAttended'] ?? []),
      energy: map['energy'] ?? 0,
      sleep: map['sleep'] ?? 0,
      water: map['water'] ?? 0,
      food: map['food'] ?? 0,
      position: map['position'],
      types: map['types'],
      techniques: _parseTechniques(map['techniques']),
      rounds: map['rounds'] ?? 0,
      submissions: map['submissions'] ?? 0,
      madeSubmissions: _parseSubmissions(map['madeSubmissions']),
      submissionAttempts: map['submissionAttempts'] ?? 0,
      timesSubmitted: map['timesSubmitted'] ?? 0,
      generalNotes: map['generalNotes'] ?? '',
      createdAt: (map['createdAt'] as dynamic)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as dynamic)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    // Drop blank boxes and never store more entries than the submission count
    final cleanedSubmissions = madeSubmissions
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .take(submissions)
        .toList();

    return {
      'userId': userId,
      'date': date,
      'photoUrl': photoUrl,
      'classesAttended': classesAttended,
      'energy': energy,
      'sleep': sleep,
      'water': water,
      'food': food,
      'position': position,
      'types': types,
      'techniques': techniques.isEmpty ? null : techniques,
      'rounds': rounds,
      'submissions': submissions,
      'madeSubmissions': cleanedSubmissions.isEmpty ? null : cleanedSubmissions,
      'submissionAttempts': submissionAttempts,
      'timesSubmitted': timesSubmitted,
      'generalNotes': generalNotes,
      'createdAt': createdAt,
      'updatedAt': updatedAt ?? DateTime.now(),
    };
  }

  /// Reads madeSubmissions as a flat list.
  /// Also accepts the old Map<String, List<String>> format so older
  /// entries still load (their values get flattened into one list).
  static List<String> _parseSubmissions(dynamic data) {
    if (data == null) return [];

    if (data is List) {
      return data.map((e) => e?.toString() ?? '').toList();
    }

    if (data is Map) {
      return data.values
          .whereType<List>()
          .expand((list) => list)
          .map((e) => e?.toString() ?? '')
          .toList();
    }

    return [];
  }

  static Map<String, List<String>> _parseTechniques(dynamic data) {
    if (data == null) return {};
    if (data is! Map) return {};

    return Map<String, List<String>>.from(
      (data as Map<String, dynamic>).map(
            (key, value) => MapEntry(
          key,
          List<String>.from(value as List? ?? []),
        ),
      ),
    );
  }
}