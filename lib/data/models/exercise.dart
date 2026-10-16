/// One logged set: the weight (kg, null for bodyweight), reps done and how
/// many more reps were left in the tank.
class SetLog {
  SetLog({this.kg, this.reps, this.rir});

  double? kg;
  int? reps;

  /// Reps in reserve, 0 (failure) to 4 (4 or more); null when not given.
  int? rir;

  Map<String, dynamic> toJson() => {'kg': kg, 'reps': reps, if (rir != null) 'rir': rir};

  factory SetLog.fromJson(Map<String, dynamic> j) =>
      SetLog(kg: (j['kg'] as num?)?.toDouble(), reps: j['reps'] as int?, rir: j['rir'] as int?);
}

/// One exercise line in a template or a planned session.
class Exercise {
  Exercise({
    required this.id,
    required this.name,
    required this.sets,
    required this.reps,
    required this.load,
    this.area,
    this.alt,
    this.swapped = false,
    this.orig = '',
    this.group,
    this.drop = false,
    this.fullSets,
    this.rest,
    List<SetLog>? logged,
    List<String>? setReps,
    List<String>? setLoads,
  }) : logged = logged ?? [],
       setReps = setReps ?? [],
       setLoads = setLoads ?? [];

  final String id;
  String name;
  int sets;
  String reps;
  String load;

  /// Injury area this exercise loads (`knee`, `back`, ...), if any.
  String? area;

  /// Safer alternative offered when [area] is flagged.
  String? alt;
  bool swapped;

  /// Name before a swap.
  String orig;

  /// Superset letter: exercises sharing one are done back to back.
  String? group;

  /// The last set is a drop set.
  bool drop;

  /// Sets before a deload week halved them.
  int? fullSets;

  /// Rest after each set in seconds; null picks it from the exercise type.
  int? rest;

  /// Sets done in a finished workout, in order.
  final List<SetLog> logged;

  /// Reps and load planned for each set from the second on, like 70, 75,
  /// 80 kg; an empty or missing entry means the same as [reps] and [load].
  final List<String> setReps;
  final List<String> setLoads;

  String? _own(List<String> l, int i) => i < l.length && l[i].trim().isNotEmpty ? l[i].trim() : null;

  /// Set [i]'s own reps or load, when it has one.
  String? ownReps(int i) => _own(setReps, i);
  String? ownLoad(int i) => _own(setLoads, i);

  String repsFor(int i) => ownReps(i) ?? reps;
  String loadFor(int i) => ownLoad(i) ?? load;

  /// Some set has its own reps or load.
  bool get perSet => [for (var i = 1; i < sets; i++) i].any((i) => ownReps(i) != null || ownLoad(i) != null);

  /// Sets set [i]'s own reps or load; empty goes back to the default.
  void planSet(int i, {String? reps, String? load}) {
    for (final (l, v) in [(setReps, reps), (setLoads, load)]) {
      if (v == null) continue;
      while (l.length <= i) {
        l.add('');
      }
      l[i] = v;
    }
  }

  Exercise copyWith({required String id}) => Exercise(
    id: id,
    name: name,
    sets: sets,
    reps: reps,
    load: load,
    area: area,
    alt: alt,
    swapped: swapped,
    orig: orig,
    group: group,
    drop: drop,
    rest: rest,
    setReps: [...setReps],
    setLoads: [...setLoads],
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'sets': sets,
    'reps': reps,
    'load': load,
    'area': area,
    'alt': alt,
    'swapped': swapped,
    'orig': orig,
    'group': group,
    'drop': drop,
    'fullSets': fullSets,
    'rest': rest,
    if (logged.isNotEmpty) 'logged': logged.map((x) => x.toJson()).toList(),
    if (setReps.any((x) => x.isNotEmpty)) 'setReps': setReps,
    if (setLoads.any((x) => x.isNotEmpty)) 'setLoads': setLoads,
  };

  factory Exercise.fromJson(Map<String, dynamic> j) => Exercise(
    id: j['id'] as String,
    name: j['name'] as String,
    sets: j['sets'] as int,
    reps: j['reps'] as String,
    load: j['load'] as String,
    area: j['area'] as String?,
    alt: j['alt'] as String?,
    swapped: j['swapped'] as bool? ?? false,
    orig: j['orig'] as String? ?? '',
    group: j['group'] as String?,
    drop: j['drop'] as bool? ?? false,
    fullSets: j['fullSets'] as int?,
    rest: j['rest'] as int?,
    logged: [for (final x in j['logged'] as List? ?? const []) SetLog.fromJson(x as Map<String, dynamic>)],
    setReps: [for (final x in j['setReps'] as List? ?? const []) x as String],
    setLoads: [for (final x in j['setLoads'] as List? ?? const []) x as String],
  );
}
