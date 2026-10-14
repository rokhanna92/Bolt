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
  });

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
      );
}
