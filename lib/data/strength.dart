// Strength levels: a lift's one-rep max against bodyweight, by sex.

import '../l10n/l10n.dart';
import 'models/people.dart';

/// Levels from first steps to elite.
const kStrengthLevels = ['Beginner', 'Novice', 'Intermediate', 'Advanced', 'Elite'];

/// Bodyweight multiples where Novice, Intermediate, Advanced and Elite
/// start, for men then women. Rounded from common strength standards.
const _standards = <String, (List<double>, List<double>)>{
  'Bench Press': ([.75, 1, 1.5, 2], [.4, .6, .85, 1.1]),
  'Incline Bench Press': ([.6, .85, 1.25, 1.65], [.35, .5, .7, .95]),
  'Back Squat': ([1, 1.5, 2, 2.5], [.75, 1, 1.5, 1.9]),
  'Front Squat': ([.8, 1.2, 1.6, 2], [.6, .85, 1.2, 1.5]),
  'Deadlift': ([1.25, 1.75, 2.25, 3], [.9, 1.25, 1.75, 2.25]),
  'Sumo Deadlift': ([1.25, 1.75, 2.25, 3], [.9, 1.25, 1.75, 2.25]),
  'Trap Bar Deadlift': ([1.35, 1.85, 2.4, 3.1], [1, 1.35, 1.85, 2.4]),
  'Romanian Deadlift': ([.9, 1.3, 1.7, 2.2], [.65, .95, 1.3, 1.7]),
  'Overhead Press': ([.5, .7, .9, 1.2], [.3, .45, .6, .8]),
  'Barbell Row': ([.6, .9, 1.2, 1.5], [.35, .55, .75, 1]),
  'Hip Thrust': ([1, 1.5, 2.25, 3], [.9, 1.4, 2, 2.75]),
};

/// Lifts with strength standards, in table order.
List<String> get kStandardLifts => _standards.keys.toList();

/// Whether [lift] has strength standards.
bool hasStandards(String lift) => _standards.containsKey(lift);

/// The multiples for [lift] for [body]'s sex; null without standards or a
/// sex set.
List<double>? standardsFor(String lift, Body body) {
  final s = _standards[lift];
  if (s == null || body.sex == null) return null;
  return body.sex == 'f' ? s.$2 : s.$1;
}

class StrengthLevel {
  const StrengthLevel(this.level, this.ratio, this.nextKg);

  /// Index into [kStrengthLevels].
  final int level;

  /// Max divided by bodyweight.
  final double ratio;

  /// Max where the next level starts; null at Elite.
  final double? nextKg;
}

/// [maxKg] on [lift] for [body]. Null without standards for the lift, a
/// bodyweight or male / female.
StrengthLevel? strengthLevel(String lift, double maxKg, Body body) {
  final s = _standards[lift];
  final bw = body.weightKg;
  if (s == null || bw == null || bw <= 0 || body.sex == null) return null;
  final t = body.sex == 'f' ? s.$2 : s.$1;
  final ratio = maxKg / bw;
  var level = 0;
  while (level < t.length && ratio >= t[level]) {
    level++;
  }
  return StrengthLevel(level, ratio, level < t.length ? t[level] * bw : null);
}

/// " · Intermediate" for a list row, or empty without a level.
String levelSuffix(String lift, double? maxKg, Body body) {
  final l = maxKg == null ? null : strengthLevel(lift, maxKg, body);
  return l == null ? '' : ' · ${tx(kStrengthLevels[l.level])}';
}
