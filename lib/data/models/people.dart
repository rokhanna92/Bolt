import '../../l10n/l10n.dart';

/// One day's weigh-in and tape measurements, stored metric.
class BodyEntry {
  BodyEntry({required this.date, this.weightKg, Map<String, double>? cm}) : cm = cm ?? {};

  /// Day key.
  final String date;
  double? weightKg;

  /// Circumferences by part key, in cm.
  final Map<String, double> cm;

  /// `weight` or a part key.
  double? value(String key) => key == 'weight' ? weightKg : cm[key];

  bool get isEmpty => weightKg == null && cm.isEmpty;

  Map<String, dynamic> toJson() => {'date': date, 'weightKg': weightKg, 'cm': cm};

  factory BodyEntry.fromJson(Map<String, dynamic> j) => BodyEntry(
    date: j['date'] as String,
    weightKg: (j['weightKg'] as num?)?.toDouble(),
    cm: (j['cm'] as Map<String, dynamic>? ?? {}).map((k, v) => MapEntry(k, (v as num).toDouble())),
  );
}

/// Body weight, height and tape measurements: the latest values plus a
/// dated history for progress charts. Stored metric (kg, cm) and converted
/// for display.
class Body {
  Body({
    this.weightKg,
    this.heightCm,
    Map<String, double>? cm,
    this.updated,
    this.sex,
    List<BodyEntry>? history,
    Map<String, double>? goals,
  }) : cm = cm ?? {},
       history = history ?? [],
       goals = goals ?? {};

  /// Measured parts, in display order.
  static const parts = {
    'chest': 'Chest',
    'waist': 'Waist',
    'hips': 'Hips',
    'arm': 'Arm',
    'thigh': 'Thigh',
    'neck': 'Neck',
  };

  /// Everything with a history: weight, then the parts.
  static const tracked = {'weight': 'Weight', ...parts};

  double? weightKg;
  double? heightCm;

  /// `m`, `f` or null when not set. Body types and strength differ, so tips
  /// and healthy ranges follow it.
  String? sex;

  /// Circumferences by part key, in cm.
  final Map<String, double> cm;

  /// Day key of the last change.
  String? updated;

  /// One entry per day, oldest first.
  final List<BodyEntry> history;

  /// Targets by `weight` or part key, metric.
  final Map<String, double> goals;

  bool get isEmpty => weightKg == null && heightCm == null && sex == null && cm.isEmpty;

  /// The latest values without the history.
  Body clone() =>
      Body(weightKg: weightKg, heightCm: heightCm, cm: {...cm}, updated: updated, sex: sex, goals: {...goals});

  /// Records the latest weight and measurements as [date]'s entry.
  void logCurrent(String date) {
    history.removeWhere((e) => e.date == date);
    final e = BodyEntry(date: date, weightKg: weightKg, cm: {...cm});
    if (!e.isEmpty) history.add(e);
    history.sort((a, b) => a.date.compareTo(b.date));
  }

  /// Latest values from the history after an entry is removed; height stays.
  void recomputeLatest() {
    double? last(String key) {
      for (final e in history.reversed) {
        if (e.value(key) != null) return e.value(key);
      }
      return null;
    }

    weightKg = last('weight');
    cm.clear();
    for (final k in parts.keys) {
      if (last(k) case final double v) cm[k] = v;
    }
  }

  /// Adds [other]'s entries for days this history does not have.
  void mergeHistory(List<BodyEntry> other) {
    final have = {for (final e in history) e.date};
    history
      ..addAll(other.where((e) => !have.contains(e.date)))
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  /// [last] keeps only the newest entries, for shared updates.
  Map<String, dynamic> toJson({int? last}) => {
    'weightKg': weightKg,
    'heightCm': heightCm,
    'sex': sex,
    'cm': cm,
    'updated': updated,
    'goals': goals,
    'history': [
      for (final e in last == null || history.length <= last ? history : history.sublist(history.length - last))
        e.toJson(),
    ],
  };

  factory Body.fromJson(Map<String, dynamic>? j) {
    if (j == null) return Body();
    final b = Body(
      weightKg: (j['weightKg'] as num?)?.toDouble(),
      heightCm: (j['heightCm'] as num?)?.toDouble(),
      sex: j['sex'] as String?,
      cm: (j['cm'] as Map<String, dynamic>? ?? {}).map((k, v) => MapEntry(k, (v as num).toDouble())),
      updated: j['updated'] as String?,
      history: [for (final e in j['history'] as List? ?? const []) BodyEntry.fromJson(e as Map<String, dynamic>)],
      goals: (j['goals'] as Map<String, dynamic>? ?? {}).map((k, v) => MapEntry(k, (v as num).toDouble())),
    );
    // Saved before history existed: the latest values become the first entry.
    if (b.history.isEmpty && b.updated != null) b.logCurrent(b.updated!);
    return b;
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
    this.workouts = 0,
    this.sets = 0,
    this.lastPerfectWeek,
    this.bestStreak = 0,
    this.weekend = 0,
    this.long = 0,
    this.built = 0,
    this.diary = 0,
    this.full = 0,
    Set<String>? kinds,
    Map<String, int>? muscles,
    Set<String>? away,
    Set<String>? rest,
  }) : kinds = kinds ?? {},
       muscles = muscles ?? {},
       away = away ?? {},
       rest = rest ?? {};

  int sessions;
  int mins;
  int early;
  int late;
  int prs;

  /// Consecutive weeks with every planned session done.
  int streak;
  int perfect;

  /// Workouts logged and the sets checked off in them.
  int workouts;
  int sets;

  /// Monday key of the last week where every planned session was done.
  String? lastPerfectWeek;

  /// Longest streak of perfect weeks.
  int bestStreak;

  /// Workouts logged on a Saturday or Sunday.
  int weekend;

  /// Gym visits of 90 minutes or more.
  int long;

  /// Workouts logged that were built from muscles or a custom template.
  int built;

  /// Past days logged from the diary.
  int diary;

  /// Workouts finished with every set checked off.
  int full;

  /// Distinct workout titles logged.
  final Set<String> kinds;

  /// Workouts logged per muscle group (`chest`, `back`, `legs`, ...).
  final Map<String, int> muscles;

  /// Monday keys of weeks marked away (holiday, sick): they never break the
  /// streak.
  final Set<String> away;

  /// Day keys marked as rest days.
  final Set<String> rest;

  TraineeStats copy() => TraineeStats(
    sessions: sessions,
    mins: mins,
    early: early,
    late: late,
    prs: prs,
    streak: streak,
    perfect: perfect,
    workouts: workouts,
    sets: sets,
    lastPerfectWeek: lastPerfectWeek,
    bestStreak: bestStreak,
    weekend: weekend,
    long: long,
    built: built,
    diary: diary,
    full: full,
    kinds: {...kinds},
    muscles: {...muscles},
    away: {...away},
    rest: {...rest},
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
    'workouts' => workouts,
    'sets' => sets,
    'weekend' => weekend,
    'long' => long,
    'built' => built,
    'diary' => diary,
    'full' => full,
    'kinds' => kinds.length,
    _ when key.startsWith('m_') => muscles[key.substring(2)] ?? 0,
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
    'workouts': workouts,
    'sets': sets,
    'lastPerfectWeek': lastPerfectWeek,
    'bestStreak': bestStreak,
    'weekend': weekend,
    'long': long,
    'built': built,
    'diary': diary,
    'full': full,
    'kinds': kinds.toList(),
    'muscles': muscles,
    'away': away.toList(),
    'rest': rest.toList(),
  };

  factory TraineeStats.fromJson(Map<String, dynamic> j) => TraineeStats(
    sessions: j['sessions'] as int? ?? 0,
    mins: j['mins'] as int? ?? 0,
    early: j['early'] as int? ?? 0,
    late: j['late'] as int? ?? 0,
    prs: j['prs'] as int? ?? 0,
    streak: j['streak'] as int? ?? 0,
    perfect: j['perfect'] as int? ?? 0,
    workouts: j['workouts'] as int? ?? 0,
    sets: j['sets'] as int? ?? 0,
    lastPerfectWeek: j['lastPerfectWeek'] as String?,
    bestStreak: j['bestStreak'] as int? ?? (j['streak'] as int? ?? 0),
    weekend: j['weekend'] as int? ?? 0,
    long: j['long'] as int? ?? 0,
    built: j['built'] as int? ?? 0,
    diary: j['diary'] as int? ?? 0,
    full: j['full'] as int? ?? 0,
    kinds: {for (final k in j['kinds'] as List? ?? const []) k as String},
    muscles: (j['muscles'] as Map<String, dynamic>? ?? {}).map((k, v) => MapEntry(k, v as int)),
    away: {for (final k in j['away'] as List? ?? const []) k as String},
    rest: {for (final k in j['rest'] as List? ?? const []) k as String},
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
    this.challenge,
    Map<String, double>? maxes,
    List<String>? periods,
    Map<String, List<int>>? readiness,
    this.program,
    this.programStart,
    Map<String, (double, String)>? liftGoals,
  }) : liftGoals = liftGoals ?? {},
       body = body ?? Body(),
       maxes = maxes ?? {},
       periods = periods ?? [],
       readiness = readiness ?? {};

  final String id;
  String name;

  /// Coach id, when the coach is on this phone.
  String coach;

  /// The coach's name when the coach is on another phone (the phone owner's
  /// own profile as a trainee).
  String? coachName;
  String goal;

  /// Split id: a built-in one (`ppl`, `old4`, ...) or a custom split.
  String split;

  /// "Mar 2026".
  String since;
  List<Injury> injuries;
  TraineeStats stats;
  Body body;

  /// A goal for a date range, set by the coach or by a solo user.
  Challenge? challenge;

  /// One-rep maxes set by hand, kg by exercise name. Percentage loads use
  /// these, else the best estimated max from logged sets.
  final Map<String, double> maxes;

  /// Days a period started, for cycle tracking. Private: never sent in
  /// updates to the coach.
  final List<String> periods;

  /// Check-ins by day: sleep, energy and soreness, each 1 (bad) to 3 (good).
  final Map<String, List<int>> readiness;

  /// Program id from `kPrograms` and the Monday it started.
  String? program;
  String? programStart;

  /// One-rep max targets by exercise name: kg and the day to reach it by.
  final Map<String, (double, String)> liftGoals;

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
    'challenge': challenge?.toJson(),
    'maxes': maxes,
    'periods': periods,
    'readiness': readiness,
    'program': program,
    'programStart': programStart,
    'liftGoals': liftGoalsToJson(liftGoals),
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
    challenge: j['challenge'] == null ? null : Challenge.fromJson(j['challenge'] as Map<String, dynamic>),
    maxes: (j['maxes'] as Map<String, dynamic>? ?? {}).map((k, v) => MapEntry(k, (v as num).toDouble())),
    periods: [for (final x in j['periods'] as List? ?? const []) x as String],
    readiness: readinessFromJson(j['readiness']),
    program: j['program'] as String?,
    programStart: j['programStart'] as String?,
    liftGoals: liftGoalsFromJson(j['liftGoals']),
  );
}

Map<String, Object> liftGoalsToJson(Map<String, (double, String)> g) =>
    g.map((k, v) => MapEntry(k, {'kg': v.$1, 'by': v.$2}));

Map<String, (double, String)> liftGoalsFromJson(Object? j) => (j as Map<String, dynamic>? ?? {}).map(
  (k, v) => MapEntry(k, (((v as Map<String, dynamic>)['kg'] as num).toDouble(), v['by'] as String)),
);

Map<String, List<int>> readinessFromJson(Object? j) =>
    (j as Map<String, dynamic>? ?? {}).map((k, v) => MapEntry(k, [for (final x in v as List) x as int]));

/// A readiness check-in summed up: `ready` (8-9), `normal` (6-7) or `low`.
String readinessLevel(List<int> r) {
  final sum = r.fold(0, (a, b) => a + b);
  return sum >= 8 ? 'ready' : (sum >= 6 ? 'normal' : 'low');
}

/// A target to reach between two days: workouts logged, gym visits or gym
/// hours.
class Challenge {
  Challenge({required this.kind, required this.target, required this.from, required this.to, this.by, this.progress});

  /// Kinds and their unit words.
  static const kinds = {'workouts': 'workout', 'visits': 'gym visit', 'hours': 'gym hour'};

  /// `workouts`, `visits` or `hours`.
  final String kind;
  final int target;

  /// Day keys, both included.
  final String from;
  final String to;

  /// Coach who set it; null when you set it yourself.
  final String? by;

  /// Progress as last reported by the trainee, on the coach's phone.
  int? progress;

  String get title => plural(target, kinds[kind]!);

  Map<String, dynamic> toJson() => {
    'kind': kind,
    'target': target,
    'from': from,
    'to': to,
    'by': by,
    'progress': progress,
  };

  factory Challenge.fromJson(Map<String, dynamic> j) => Challenge(
    kind: j['kind'] as String,
    target: j['target'] as int,
    from: j['from'] as String,
    to: j['to'] as String,
    by: j['by'] as String?,
    progress: j['progress'] as int?,
  );
}
