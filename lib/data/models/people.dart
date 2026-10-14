/// Body weight, height and tape measurements. Stored metric (kg, cm) and
/// converted for display.
class Body {
  Body({this.weightKg, this.heightCm, Map<String, double>? cm, this.updated}) : cm = cm ?? {};

  /// Measured parts, in display order.
  static const parts = {'chest': 'Chest', 'waist': 'Waist', 'hips': 'Hips', 'arm': 'Arm', 'thigh': 'Thigh'};

  double? weightKg;
  double? heightCm;

  /// Circumferences by part key, in cm.
  final Map<String, double> cm;

  /// Day key of the last change.
  String? updated;

  bool get isEmpty => weightKg == null && heightCm == null && cm.isEmpty;

  Map<String, dynamic> toJson() => {'weightKg': weightKg, 'heightCm': heightCm, 'cm': cm, 'updated': updated};

  factory Body.fromJson(Map<String, dynamic>? j) {
    if (j == null) return Body();
    return Body(
      weightKg: (j['weightKg'] as num?)?.toDouble(),
      heightCm: (j['heightCm'] as num?)?.toDouble(),
      cm: (j['cm'] as Map<String, dynamic>? ?? {}).map((k, v) => MapEntry(k, (v as num).toDouble())),
      updated: j['updated'] as String?,
    );
  }
}

class Coach {
  Coach({required this.id, required this.name, required this.role, Body? body}) : body = body ?? Body();

  final String id;
  String name;

  /// Specialty, e.g. "Strength & Hypertrophy".
  String role;
  Body body;

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'role': role, 'body': body.toJson()};

  factory Coach.fromJson(Map<String, dynamic> j) => Coach(
    id: j['id'] as String,
    name: j['name'] as String,
    role: j['role'] as String,
    body: Body.fromJson(j['body'] as Map<String, dynamic>?),
  );
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
    Body? body,
    this.coachName,
  }) : body = body ?? Body();

  final String id;
  String name;

  /// Coach id, when the coach is on this phone.
  String coach;

  /// The coach's name when the coach is on another phone (the phone owner's
  /// own profile as a trainee).
  String? coachName;
  String goal;

  /// Split id (`ppl`, `ul`, `fb`, `rehab`).
  String split;

  /// "Mar 2026".
  String since;
  List<Injury> injuries;
  TraineeStats stats;
  Body body;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'coach': coach,
    'goal': goal,
    'split': split,
    'since': since,
    'injuries': injuries.map((i) => i.toJson()).toList(),
    'stats': stats.toJson(),
    'body': body.toJson(),
    'coachName': coachName,
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
    body: Body.fromJson(j['body'] as Map<String, dynamic>?),
    coachName: j['coachName'] as String?,
  );
}
