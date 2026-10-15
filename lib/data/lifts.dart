// Lifting maths and history: rep targets, estimated 1RM, what was lifted
// before, next-time hints, warm-ups, weekly muscle volume and challenges.

import 'dart:math' as math;

import '../core/format.dart';
import 'models/exercise.dart';
import 'models/people.dart';
import 'models/session.dart';
import 'models/visit.dart';
import 'seed/exercises.dart';
import 'seed/muscles.dart';

/// Top of a rep target: `6-8` is 8, `10/leg` is 10. Null for time or
/// distance targets like `45 s`.
int? targetReps(String reps) {
  final m = RegExp(r'^(\d+)(?:-(\d+))?(?:/\w+)?$').firstMatch(reps.trim());
  return m == null ? null : int.parse(m[2] ?? m[1]!);
}

/// Kilograms in a planned load like `70 kg`. Null for `BW`, `2×28 kg`,
/// `+80 kg` and the like.
double? loadKg(String load) {
  final m = RegExp(r'^(\d+(?:\.\d+)?)\s?kg$').firstMatch(load.trim());
  return m == null ? null : double.parse(m[1]!);
}

/// Estimated one-rep max (Epley), from sets of 1 to 12 reps.
double? e1rm(SetLog s) {
  final kg = s.kg, reps = s.reps;
  if (kg == null || reps == null || reps < 1 || reps > 12) return null;
  return reps == 1 ? kg : kg * (1 + reps / 30);
}

/// Rounds to the nearest 2.5 kg.
double plates(double kg) => (kg / 2.5).round() * 2.5;

/// One exercise in one finished workout.
class LiftDay {
  LiftDay(this.date, this.sets);

  final String date;
  final List<SetLog> sets;

  double? get best => sets.map(e1rm).whereType<double>().fold<double?>(null, (a, b) => a == null || b > a ? b : a);
  double? get topKg =>
      sets.map((s) => s.kg).whereType<double>().fold<double?>(null, (a, b) => a == null || b > a ? b : a);
  int? get topReps => sets.map((s) => s.reps).whereType<int>().fold<int?>(null, (a, b) => a == null || b > a ? b : a);

  /// Kilograms moved: weight × reps over every set.
  double get volume => sets.fold(0.0, (a, s) => a + (s.kg ?? 0) * (s.reps ?? 0));
}

/// Every finished workout with logged sets of [name], oldest first. Only
/// days before [before] when given.
List<LiftDay> liftHistory(Map<String, Session> plan, String name, {String? before}) {
  final out = <LiftDay>[];
  for (final k in plan.keys.toList()..sort()) {
    if (before != null && k.compareTo(before) >= 0) continue;
    final s = plan[k]!;
    if (s.status != SessionStatus.done) continue;
    final sets = [
      for (final e in s.ex)
        if (e.name == name) ...e.logged,
    ];
    if (sets.isNotEmpty) out.add(LiftDay(k, sets));
  }
  return out;
}

/// Names of every exercise with logged sets, most recent first.
List<String> loggedLifts(Map<String, Session> plan) {
  final seen = <String>{};
  for (final k in plan.keys.toList()..sort((a, b) => b.compareTo(a))) {
    final s = plan[k]!;
    if (s.status != SessionStatus.done) continue;
    for (final e in s.ex) {
      if (e.logged.isNotEmpty) seen.add(e.name);
    }
  }
  return seen.toList();
}

/// What happened last time and what to try now.
class LiftHint {
  const LiftHint({required this.last, required this.nextKg, required this.up});

  final LiftDay last;

  /// Weight to use this time; null for bodyweight work.
  final double? nextKg;

  /// Every rep was hit last time, so the weight goes up.
  final bool up;
}

/// Lower-body compound lifts move up 5 kg at a time, everything else 2.5.
double _step(String name) {
  final e = kExerciseByName[name];
  return e != null && e.compound && const {'quads', 'hamstrings', 'glutes', 'back'}.contains(e.muscle) ? 5 : 2.5;
}

/// Progressive overload: the same weight until every set reaches the top
/// of the rep target, then a step up.
LiftHint? hintFor(Map<String, Session> plan, Exercise e, String today) {
  final h = liftHistory(plan, e.name, before: today);
  if (h.isEmpty) return null;
  final last = h.last;
  final top = last.topKg;
  final target = targetReps(e.reps);
  if (top == null) return LiftHint(last: last, nextKg: null, up: false);
  final working = last.sets.where((s) => s.kg == top).toList();
  final up = target != null && working.isNotEmpty && working.every((s) => (s.reps ?? 0) >= target);
  return LiftHint(last: last, nextKg: up ? top + _step(e.name) : top, up: up);
}

/// "8, 8, 7" reps of a lift day.
String repsText(LiftDay d) => d.sets.map((s) => s.reps?.toString() ?? '-').join(', ');

/// Ramp-up sets before a working weight of [kg]: 40 % × 10, 60 % × 5 and
/// 80 % × 3, never below the empty bar. None under 30 kg.
List<SetLog> warmups(double kg) {
  if (kg < 30) return const [];
  return [
    for (final (p, r) in const [(.4, 10), (.6, 5), (.8, 3)]) SetLog(kg: math.max(20, plates(kg * p)), reps: r),
  ];
}

/// The first compound lift of a workout with a weight to ramp up to.
Exercise? warmupFor(List<Exercise> ex) {
  for (final e in ex) {
    if (kExerciseByName[e.name]?.compound ?? false) {
      return loadKg(e.load) != null ? e : null;
    }
  }
  return null;
}

/// Sets per muscle in finished workouts from [from] to [to] (day keys,
/// [to] excluded). Logged sets count when there are any, otherwise the
/// planned sets. Cardio and mobility are left out.
Map<String, int> muscleSets(Map<String, Session> plan, String from, String to) {
  final out = <String, int>{};
  plan.forEach((k, s) {
    if (s.status != SessionStatus.done || k.compareTo(from) < 0 || k.compareTo(to) >= 0) return;
    for (final e in s.ex) {
      final m = kExerciseByName[e.name]?.muscle;
      if (m == null || m == 'cardio' || m == 'mobility') continue;
      out[m] = (out[m] ?? 0) + (e.logged.isNotEmpty ? e.logged.length : e.sets);
    }
  });
  return out;
}

/// Weekly set range from a muscle's Learn volume, e.g. "10-20 sets a week".
(int, int)? volumeRange(String muscle) {
  final m = RegExp(r'(\d+)-(\d+)').firstMatch(kMuscles[muscle]?.volume ?? '');
  return m == null ? null : (int.parse(m[1]!), int.parse(m[2]!));
}

/// Progress toward [c] from this phone's plan and visits.
int challengeProgress(Challenge c, Map<String, Session> plan, List<Visit> visits) {
  bool inRange(String k) => k.compareTo(c.from) >= 0 && k.compareTo(c.to) <= 0;
  return switch (c.kind) {
    'workouts' => plan.entries.where((e) => e.value.status == SessionStatus.done && inRange(e.key)).length,
    'visits' => visits.where((v) => inRange(v.date)).length,
    _ => visits.where((v) => inRange(v.date)).fold(0, (a, v) => a + v.mins) ~/ 60,
  };
}

/// Days left in a challenge, today included; 0 once it is over.
int daysLeft(Challenge c, DateTime now) {
  final end = pk(c.to);
  return math.max(0, end.difference(DateTime(now.year, now.month, now.day)).inDays + 1);
}

/// The note a deload week puts on its sessions.
const deloadNote = 'Deload week: half the sets, about 10% lighter, stop 3 or more reps before failure.';

/// One week at a glance, for the Monday recap.
class WeekRecap {
  const WeekRecap({
    required this.done,
    required this.planned,
    required this.visits,
    required this.gymMins,
    required this.sets,
    required this.weightDelta,
  });

  final int done;
  final int planned;
  final int visits;
  final int gymMins;
  final int sets;

  /// Weight change over the week in kg, when weighed before and during it.
  final double? weightDelta;

  bool get isEmpty => planned == 0 && done == 0 && visits == 0;
}

/// The week starting [mon]: workouts done of planned, gym visits and time,
/// sets and weight change.
WeekRecap weekRecap(Map<String, Session> plan, List<Visit> visits, Body body, DateTime mon) {
  final from = dk(mon), to = dk(addDays(mon, 7));
  bool inWeek(String k) => k.compareTo(from) >= 0 && k.compareTo(to) < 0;
  final week = plan.entries.where((e) => inWeek(e.key) && e.value.status != SessionStatus.draft).map((e) => e.value);
  final done = week.where((s) => s.status == SessionStatus.done).toList();
  final v = visits.where((x) => inWeek(x.date)).toList();
  double? weightAt(String before) {
    for (final e in body.history.reversed) {
      if (e.date.compareTo(before) < 0 && e.weightKg != null) return e.weightKg;
    }
    return null;
  }

  final start = weightAt(from), end = weightAt(to);
  return WeekRecap(
    done: done.length,
    planned: week.length,
    visits: v.length,
    gymMins: v.fold(0, (a, x) => a + x.mins),
    sets: done.fold(0, (a, s) => a + s.ex.fold(0, (b, e) => b + (e.logged.isNotEmpty ? e.logged.length : e.sets))),
    weightDelta: start == null || end == null || start == end ? null : end - start,
  );
}

/// Superset letters by position: each run of linked exercises gets the next
/// letter (A, B, ...); a lone exercise has none.
void normalizeGroups(List<Exercise> ex) {
  var letter = 0;
  var i = 0;
  while (i < ex.length) {
    var j = i;
    while (ex[i].group != null && j + 1 < ex.length && ex[j + 1].group == ex[i].group) {
      j++;
    }
    final g = j > i ? String.fromCharCode(65 + letter++) : null;
    for (var k = i; k <= j; k++) {
      ex[k].group = g;
    }
    i = j + 1;
  }
}

/// Links exercise [i] with the next one into a superset, or splits them.
void toggleSuperset(List<Exercise> ex, int i) {
  if (i + 1 >= ex.length) return;
  final a = ex[i], b = ex[i + 1];
  if (a.group != null && a.group == b.group) {
    // Everything after the split gets its own run.
    final old = a.group;
    for (var k = i + 1; k < ex.length && ex[k].group == old; k++) {
      ex[k].group = '_$i';
    }
  } else {
    final g = a.group ?? '_$i';
    a.group = g;
    final old = b.group;
    for (var k = i + 1; k < ex.length && (k == i + 1 || (old != null && ex[k].group == old)); k++) {
      ex[k].group = g;
    }
  }
  normalizeGroups(ex);
}
