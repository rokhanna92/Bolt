/// One logged set: the weight (kg, null for bodyweight) and reps done.
class SetLog {
  SetLog({this.kg, this.reps});

  double? kg;
  int? reps;

  Map<String, dynamic> toJson() => {'kg': kg, 'reps': reps};

  factory SetLog.fromJson(Map<String, dynamic> j) => SetLog(kg: (j['kg'] as num?)?.toDouble(), reps: j['reps'] as int?);
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
    List<SetLog>? logged,
  }) : logged = logged ?? [];

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

  /// Sets done in a finished workout, in order.
  final List<SetLog> logged;

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
    if (logged.isNotEmpty) 'logged': logged.map((x) => x.toJson()).toList(),
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
    logged: [for (final x in j['logged'] as List? ?? const []) SetLog.fromJson(x as Map<String, dynamic>)],
  );
}
