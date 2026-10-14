class Coach {
  Coach({required this.id, required this.name, required this.role});

  final String id;
  String name;

  /// Specialty, e.g. "Strength & Hypertrophy".
  String role;

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'role': role};

  factory Coach.fromJson(Map<String, dynamic> j) =>
      Coach(id: j['id'] as String, name: j['name'] as String, role: j['role'] as String);
}

class Injury {
  Injury({required this.area, required this.note, required this.by, this.fresh = false});

  String area;
  String note;

  /// "Added by Marko · 9 Oct" / "Reported by Ana · 14 Oct".
  String by;

  /// Reported by the trainee and not yet reviewed by the coach.
  bool fresh;

  Map<String, dynamic> toJson() => {'area': area, 'note': note, 'by': by, 'fresh': fresh};

  factory Injury.fromJson(Map<String, dynamic> j) => Injury(
        area: j['area'] as String,
        note: j['note'] as String,
        by: j['by'] as String,
        fresh: j['fresh'] as bool? ?? false,
      );
}

/// Counters that drive badges.
class TraineeStats {
  TraineeStats({
    this.sessions = 0,
    this.mins = 0,
    this.early = 0,
    this.late = 0,
    this.prs = 0,
    this.streak = 0,
    this.perfect = 0,
    this.lastPerfectWeek,
  });

  int sessions;
  int mins;
  int early;
  int late;
  int prs;

  /// Consecutive weeks with every planned session done.
  int streak;
  int perfect;

  /// Monday key of the last week where every planned session was done.
  String? lastPerfectWeek;

  TraineeStats copy() => TraineeStats(
        sessions: sessions,
        mins: mins,
        early: early,
        late: late,
        prs: prs,
        streak: streak,
        perfect: perfect,
        lastPerfectWeek: lastPerfectWeek,
      );

  /// Badge counter by key, hours derived from minutes.
  int value(String key) => switch (key) {
        'sessions' => sessions,
        'hours' => mins ~/ 60,
        'streak' => streak,
        'early' => early,
        'late' => late,
        'prs' => prs,
        'perfect' => perfect,
        _ => 0,
      };

  Map<String, dynamic> toJson() => {
        'sessions': sessions,
        'mins': mins,
        'early': early,
        'late': late,
        'prs': prs,
        'streak': streak,
        'perfect': perfect,
        'lastPerfectWeek': lastPerfectWeek,
      };

  factory TraineeStats.fromJson(Map<String, dynamic> j) => TraineeStats(
        sessions: j['sessions'] as int? ?? 0,
        mins: j['mins'] as int? ?? 0,
        early: j['early'] as int? ?? 0,
        late: j['late'] as int? ?? 0,
        prs: j['prs'] as int? ?? 0,
        streak: j['streak'] as int? ?? 0,
        perfect: j['perfect'] as int? ?? 0,
        lastPerfectWeek: j['lastPerfectWeek'] as String?,
      );
}

class Trainee {
  Trainee({
    required this.id,
    required this.name,
    required this.coach,
    required this.goal,
    required this.split,
    required this.since,
    required this.injuries,
    required this.stats,
  });

  final String id;
  String name;

  /// Coach id.
  String coach;
  String goal;

  /// Split id (`ppl`, `ul`, `fb`, `rehab`).
  String split;

  /// "Mar 2026".
  String since;
  List<Injury> injuries;
  TraineeStats stats;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'coach': coach,
        'goal': goal,
        'split': split,
        'since': since,
        'injuries': injuries.map((i) => i.toJson()).toList(),
        'stats': stats.toJson(),
      };

  factory Trainee.fromJson(Map<String, dynamic> j) => Trainee(
        id: j['id'] as String,
        name: j['name'] as String,
        coach: j['coach'] as String,
        goal: j['goal'] as String,
        split: j['split'] as String,
        since: j['since'] as String,
        injuries: (j['injuries'] as List).map((e) => Injury.fromJson(e as Map<String, dynamic>)).toList(),
        stats: TraineeStats.fromJson(j['stats'] as Map<String, dynamic>),
      );
}
