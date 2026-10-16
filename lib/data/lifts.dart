// Lifting maths and history: rep targets, estimated 1RM, what was lifted
// before, next-time hints, warm-ups, weekly muscle volume and challenges.

import 'dart:math' as math;

import '../core/format.dart';
import '../core/units.dart';
import 'rules.dart' show unitLoad;
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
  const LiftHint({required this.last, required this.nextKg, required this.up, this.easy = false});

  final LiftDay last;

  /// Weight to use this time; null for bodyweight work.
  final double? nextKg;

  /// Every rep was hit last time, so the weight goes up.
  final bool up;

  /// Every rep was hit with 3 or more left in the tank: a double step.
  final bool easy;
}

/// Lower-body compound lifts move up 5 kg at a time, everything else 2.5.
double _step(String name) {
  final e = kExerciseByName[name];
  return e != null && e.compound && const {'quads', 'hamstrings', 'glutes', 'back'}.contains(e.muscle) ? 5 : 2.5;
}

/// Progressive overload: the same weight until every set reaches the top
/// of the rep target, then a step up, or two when every working set had 3
/// or more reps in reserve.
LiftHint? hintFor(Map<String, Session> plan, Exercise e, String today) {
  final h = liftHistory(plan, e.name, before: today);
  if (h.isEmpty) return null;
  final last = h.last;
  final top = last.topKg;
  final target = targetReps(e.reps);
  if (top == null) return LiftHint(last: last, nextKg: null, up: false);
  final working = last.sets.where((s) => s.kg == top).toList();
  final up = target != null && working.isNotEmpty && working.every((s) => (s.reps ?? 0) >= target);
  final easy = up && working.every((s) => (s.rir ?? 0) >= 3);
  return LiftHint(last: last, nextKg: up ? top + _step(e.name) * (easy ? 2 : 1) : top, up: up, easy: easy);
}

/// A record set in the workout in progress: a heavier weight than ever, or
/// else a better estimated max.
class LivePr {
  const LivePr({required this.heavier, required this.was, required this.now});

  final bool heavier;
  final double was;
  final double now;
}

/// Whether [log] of [name] on day [k] beats every earlier workout. Null when
/// there is no history to beat.
LivePr? livePr(Map<String, Session> plan, String name, String k, SetLog log) {
  final prev = liftHistory(plan, name, before: k);
  double? most(double? Function(LiftDay) f) =>
      prev.map(f).whereType<double>().fold<double?>(null, (a, b) => a == null || b > a ? b : a);
  final top = most((d) => d.topKg), best = most((d) => d.best);
  if (log.kg != null && top != null && log.kg! > top) return LivePr(heavier: true, was: top, now: log.kg!);
  final e = e1rm(log);
  if (e != null && best != null && e > best + .01) return LivePr(heavier: false, was: best, now: e);
  return null;
}

/// What [sets] moved: weight × reps, and the reps for bodyweight work.
(double kg, int reps) workOf(Iterable<SetLog> sets) =>
    sets.fold((0.0, 0), (a, s) => (a.$1 + (s.kg ?? 0) * (s.reps ?? 0), a.$2 + (s.reps ?? 0)));

/// Day key of the last finished workout before [k] with the same template
/// or title as [s] and logged sets: the session to race.
String? lastSame(Map<String, Session> plan, Session s, String k) {
  final keys = plan.keys.where((x) => x.compareTo(k) < 0).toList()..sort((a, b) => b.compareTo(a));
  for (final x in keys) {
    final p = plan[x]!;
    if (p.status != SessionStatus.done || (p.tpl != s.tpl && p.title != s.title)) continue;
    if (p.ex.any((e) => e.logged.isNotEmpty)) return x;
  }
  return null;
}

/// How [now] stands against [last]: by weight moved when the last session
/// had weights, otherwise by reps. Returns (done, target, by weight).
(double, double, bool) race((double, int) now, (double, int) last) =>
    last.$1 > 0 ? (now.$1, last.$1, true) : (now.$2.toDouble(), last.$2.toDouble(), false);

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
      return loadKg(e.load) != null || percentLoad(e.load) != null ? e : null;
    }
  }
  return null;
}

/// The forearms hold the weight in most upper-body lifts: each set of curls
/// counts as half a forearm set, each set of pulling or pressing as a
/// quarter.
const _forearmShare = {'biceps': .5, 'back': .25, 'traps': .25, 'chest': .25, 'shoulders': .25, 'triceps': .25};

/// Sets per muscle in finished workouts from [from] to [to] (day keys,
/// [to] excluded). Logged sets count when there are any, otherwise the
/// planned sets. Forearms also get their share of upper-body sets, rounded.
/// Cardio and mobility are left out.
Map<String, int> muscleSets(Map<String, Session> plan, String from, String to) {
  final out = <String, int>{};
  var forearms = 0.0;
  plan.forEach((k, s) {
    if (s.status != SessionStatus.done || k.compareTo(from) < 0 || k.compareTo(to) >= 0) return;
    for (final e in s.ex) {
      final m = kExerciseByName[e.name]?.muscle;
      if (m == null || m == 'cardio' || m == 'mobility') continue;
      final n = e.logged.isNotEmpty ? e.logged.length : e.sets;
      out[m] = (out[m] ?? 0) + n;
      forearms += n * (_forearmShare[m] ?? 0);
    }
  });
  if (forearms.round() case final f when f > 0) out['forearms'] = (out['forearms'] ?? 0) + f;
  return out;
}

/// Days a muscle needs between hard sessions: three for the big legs and
/// back muscles, two for the rest.
int recoveryDays(String muscle) => const {'quads', 'hamstrings', 'glutes', 'back'}.contains(muscle) ? 3 : 2;

/// Day key of the last finished workout up to [today] that trained each
/// muscle. Cardio and mobility are left out.
Map<String, String> lastTrained(Map<String, Session> plan, String today) {
  final out = <String, String>{};
  plan.forEach((k, s) {
    if (s.status != SessionStatus.done || k.compareTo(today) > 0) return;
    for (final e in s.ex) {
      final m = kExerciseByName[e.name]?.muscle;
      if (m == null || m == 'cardio' || m == 'mobility') continue;
      if ((out[m] ?? '').compareTo(k) < 0) out[m] = k;
    }
  });
  return out;
}

/// How recovered each trained muscle is on [today], 0 to 1. Muscles never
/// trained are left out.
Map<String, double> recovery(Map<String, Session> plan, String today) => {
  for (final e in lastTrained(plan, today).entries)
    e.key: ((pk(today).difference(pk(e.value)).inHours / 24).round() / recoveryDays(e.key)).clamp(0.0, 1.0),
};

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

/// The note a low-readiness day puts on its session.
const lighterNote = 'Lighter day: one set less per exercise, about 10% lighter. Readiness was low.';

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

/// Rest after a set of [e] in seconds: its own setting, else by type when
/// [auto] (3 min for big lower-body and back lifts, 2 for other compounds,
/// 75 s for isolation, 60 for cardio and mobility), else [fixed].
int restFor(Exercise e, {required bool auto, required int fixed}) {
  if (e.rest != null) return e.rest!;
  final x = kExerciseByName[e.name];
  if (!auto || x == null) return fixed;
  if (x.muscle == 'cardio' || x.muscle == 'mobility') return 60;
  if (x.compound && const {'quads', 'hamstrings', 'glutes', 'back'}.contains(x.muscle)) return 180;
  return x.compound ? 120 : 75;
}

/// A percentage load like `80%` as a fraction, else null.
double? percentLoad(String load) {
  final m = RegExp(r'^(\d+(?:\.\d+)?)\s?%$').firstMatch(load.trim());
  return m == null ? null : double.parse(m[1]!) / 100;
}

/// The one-rep max for [name]: set by hand, else the best estimated max
/// from logged sets.
double? maxFor(Trainee t, Map<String, Session> plan, String name) {
  final set = t.maxes[name];
  if (set != null) return set;
  return liftHistory(
    plan,
    name,
  ).map((d) => d.best).whereType<double>().fold<double?>(null, (a, b) => a == null || b > a ? b : a);
}

/// Where a lift goal stands: the current max, what is left and the day
/// the 8-week trend of estimated maxes would reach it (null when flat or
/// falling).
({double current, double left, String? eta})? goalPace(
  Trainee t,
  Map<String, Session> plan,
  String name,
  DateTime now,
) {
  final g = t.liftGoals[name];
  final current = maxFor(t, plan, name);
  if (g == null || current == null) return null;
  final left = g.$1 - current;
  final cut = dk(addDays(now, -56));
  final s = [
    for (final d in liftHistory(plan, name))
      if (d.best != null && d.date.compareTo(cut) >= 0) (d.date, d.best!),
  ];
  String? eta;
  if (left > 0 && s.length >= 2) {
    final days = pk(s.last.$1).difference(pk(s.first.$1)).inDays;
    final perDay = days == 0 ? 0 : (s.last.$2 - s.first.$2) / days;
    if (perDay > 0) eta = dk(addDays(now, (left / perDay).ceil()));
  }
  return (current: current, left: left, eta: eta);
}

/// Kilograms for a percentage load, rounded to plates; null when the load
/// is not a percentage or there is no max yet.
double? percentKg(Trainee t, Map<String, Session> plan, Exercise e) {
  final p = percentLoad(e.load);
  final max = p == null ? null : maxFor(t, plan, e.name);
  return max == null ? null : plates(max * p!);
}

/// Kilograms planned for set [i] of [e] when that set has its own load:
/// a weight, or a percentage of the max rounded to plates.
double? setKg(Trainee t, Map<String, Session> plan, Exercise e, int i) {
  final own = e.ownLoad(i);
  if (own == null) return null;
  final p = percentLoad(own);
  if (p == null) return loadKg(own);
  final max = maxFor(t, plan, e.name);
  return max == null ? null : plates(max * p);
}

/// A planned load for display: `80% · 76 kg` for percentages with a known
/// max, otherwise the load in the chosen unit.
String loadText(Trainee t, Map<String, Session> plan, Exercise e, {required bool metric}) {
  if (percentLoad(e.load) == null) return unitLoad(e.load, kg: metric);
  final kg = percentKg(t, plan, e);
  return kg == null ? e.load : '${e.load} · ${fmtWeight(kg, metric: metric)}';
}
