import 'exercise.dart';

/// A reusable workout used by auto-fill and the rotation.
class WorkoutTemplate {
  WorkoutTemplate({
    required this.id,
    required this.name,
    required this.code,
    required this.focus,
    required this.mins,
    required this.ex,
    this.custom = false,
  });

  final String id;
  String name;

  /// Four-letter calendar code (PUSH, PULL, ...).
  String code;
  String focus;
  int mins;
  List<Exercise> ex;
  bool custom;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'code': code,
    'focus': focus,
    'mins': mins,
    'ex': ex.map((e) => e.toJson()).toList(),
    'custom': custom,
  };

  factory WorkoutTemplate.fromJson(Map<String, dynamic> j) => WorkoutTemplate(
    id: j['id'] as String,
    name: j['name'] as String,
    code: j['code'] as String,
    focus: j['focus'] as String,
    mins: j['mins'] as int,
    ex: (j['ex'] as List).map((e) => Exercise.fromJson(e as Map<String, dynamic>)).toList(),
    custom: j['custom'] as bool? ?? false,
  );
}
