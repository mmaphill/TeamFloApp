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
  final String? technique; // Pass, Sweep, Submit
  final int submissions; // Number of submissions
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
    this.technique,
    this.submissions = 0,
    this.timesSubmitted = 0,
    this.generalNotes = '',
    required this.createdAt,
    this.updatedAt,
  });

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
      technique: map['technique'],
      submissions: map['submissions'] ?? 0,
      timesSubmitted: map['timesSubmitted'] ?? 0,
      generalNotes: map['generalNotes'] ?? '',
      createdAt: (map['createdAt'] as dynamic)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as dynamic)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
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
      'technique': technique,
      'submissions': submissions,
      'timesSubmitted': timesSubmitted,
      'generalNotes': generalNotes,
      'createdAt': createdAt,
      'updatedAt': updatedAt ?? DateTime.now(),
    };
  }
}