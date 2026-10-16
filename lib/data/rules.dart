import 'dart:math' as math;

import '../core/format.dart';
import 'models/exercise.dart';
import 'models/people.dart';
import 'models/session.dart';
import 'models/visit.dart';
import 'seed/badges.dart';
import 'seed/exercises.dart';
import 'seed/muscles.dart';
import 'seed/splits.dart';
import 'seed/templates.dart';

/// Converts kg loads for display when the user prefers lb.
String unitLoad(String load, {required bool kg}) {
  if (kg || load.isEmpty) return load;
  return load.replaceAllMapped(RegExp(r'([\d.]+)\s?kg'), (m) => '${(double.parse(m[1]!) * 2.2046).round()} lb');
}

/// An exercise is flagged when it loads an area with an active injury and
/// has not been swapped yet.
bool isFlagged(Trainee? t, Exercise e) =>
    t != null && e.area != null && !e.swapped && t.injuries.any((i) => i.area == e.area);

/// Swaps to the safer alternative and remembers the original.
void swapExercise(Exercise e) {
  final alt = e.alt;
  if (alt == null) return;
  e.orig = e.name;
  e.name = alt;
  e.alt = null;
  e.swapped = true;
}

/// Other exercises for [e]'s muscle, the same kind (compound or isolation)
/// first, leaving out ones that load an injured area of [t].
List<ExInfo> swapOptions(Exercise e, Trainee? t) {
  final x = kExerciseByName[e.name];
  if (x == null) return const [];
  final hurt = {for (final i in t?.injuries ?? const <Injury>[]) i.area};
  return kExercises.where((o) => o.muscle == x.muscle && o.name != x.name && !hurt.contains(o.area)).toList()
    ..sort((a, b) => (a.compound == x.compound ? 0 : 1) - (b.compound == x.compound ? 0 : 1));
}

/// Template for an empty day [k]: the one after the most recent earlier
/// session in the split rotation, or the first one. A split without days
/// falls back to full body.
String nextInRotation(Map<String, Session> plan, Split split, String k) {
  final seq = split.sequence;
  if (seq.isEmpty) return 'full';
  final prev = plan.keys.where((x) => x.compareTo(k) < 0 && seq.contains(plan[x]!.tpl)).toList()..sort();
  if (prev.isEmpty) return seq.first;
  return seq[(seq.indexOf(plan[prev.last]!.tpl) + 1) % seq.length];
}

/// Badge ids whose goal [after] reaches and [before] did not.
List<String> newlyUnlocked(TraineeStats before, TraineeStats after) => [
  for (final b in kBadges)
    if (before.value(b.key) < b.goal && after.value(b.key) >= b.goal) b.id,
];

/// Whether every week after Monday [last] and before Monday [wk] was
/// marked away, so a streak carries across them.
bool awayBridge(TraineeStats s, String last, String wk) {
  for (var m = addDays(pk(last), 7); dk(m).compareTo(wk) < 0; m = addDays(m, 7)) {
    if (!s.away.contains(dk(m))) return false;
  }
  return true;
}

/// Streak as it stands today: it breaks once a whole week passes without
/// a perfect week, unless that week was marked away.
int currentStreak(TraineeStats s, DateTime now) {
  final last = s.lastPerfectWeek;
  if (last == null) return s.streak;
  return awayBridge(s, last, dk(monday(now))) ? s.streak : 0;
}

/// Stats as shown on badges, with the streak brought up to date.
TraineeStats displayStats(TraineeStats s, DateTime now) => s.copy()..streak = currentStreak(s, now);

/// Share of [b]'s goal reached, 0 to 1.
double badgeProgress(BadgeDef b, TraineeStats s) => (s.value(b.key) / b.goal).clamp(0.0, 1.0);

bool badgeEarned(BadgeDef b, TraineeStats s) => s.value(b.key) >= b.goal;

/// Locked badges, closest first; ties keep list order, like the prototype's
/// stable sort.
List<BadgeDef> lockedByCloseness(TraineeStats s) {
  final locked = kBadges.where((b) => !badgeEarned(b, s)).toList();
  final order = {for (final (i, b) in locked.indexed) b: i};
  return locked..sort((a, b) {
    final c = badgeProgress(b, s).compareTo(badgeProgress(a, s));
    return c != 0 ? c : order[a]!.compareTo(order[b]!);
  });
}

/// "3 sessions to go".
String badgeLeftText(BadgeDef b, TraineeStats s) {
  final r = b.goal - s.value(b.key);
  return tx('{n} to go', {'n': plural(r, kBadgeUnits[b.key]!)});
}

/// Muscle groups a session trains, from its exercises' main muscles.
Set<String> sessionGroups(Session s) => {
  for (final e in s.ex)
    if (kMuscles[kExerciseByName[e.name]?.muscle]?.group case final String g) g,
};

/// A workout for [muscles]: a few exercises per muscle, compound lifts first.
/// One muscle gets five exercises, two get three each, three or four get two
/// each and five or more one each.
List<ExSeed> workoutForMuscles(List<String> muscles, math.Random rnd) {
  final n = muscles.length;
  final per = n == 1 ? 5 : (n == 2 ? 3 : (n <= 4 ? 2 : 1));
  final picked = <ExInfo>[];
  for (final m in muscles) {
    final pool = kExercises.where((e) => e.muscle == m && !picked.contains(e)).toList()..shuffle(rnd);
    // A compound lift leads when the muscle has one.
    pool.sort((a, b) => (b.compound ? 1 : 0) - (a.compound ? 1 : 0));
    final first = pool.take(1).toList();
    final rest = pool.skip(1).toList()..shuffle(rnd);
    picked.addAll([...first, ...rest].take(per));
  }
  final ordered = [...picked.where((e) => e.compound), ...picked.where((e) => !e.compound)];
  return [for (final e in ordered) ExSeed(e.name, e.sets, e.reps, e.load, e.area, e.alt)];
}

/// Days with no logged workout and no gym visit, from the first active day
/// up to yesterday.
int restDays(Map<String, Session> plan, List<Visit> visits, DateTime now) {
  final active = {
    for (final e in plan.entries)
      if (e.value.status == SessionStatus.done) e.key,
    for (final v in visits) v.date,
  };
  if (active.isEmpty) return 0;
  final today = DateTime(now.year, now.month, now.day);
  var n = 0;
  for (var d = pk(active.reduce((a, b) => a.compareTo(b) < 0 ? a : b)); d.isBefore(today); d = addDays(d, 1)) {
    if (!active.contains(dk(d))) n++;
  }
  return n;
}

/// Days in a row without a logged workout or gym visit: yesterday back to
/// the last active day, plus today once it is marked as a rest day.
int daysOff(Map<String, Session> plan, List<Visit> visits, Set<String> rest, DateTime now) {
  final active = {
    for (final e in plan.entries)
      if (e.value.status == SessionStatus.done) e.key,
    for (final v in visits) v.date,
  };
  final today = dk(now);
  final known = {...active, ...rest};
  if (active.contains(today) || known.isEmpty) return 0;
  final first = known.reduce((a, b) => a.compareTo(b) < 0 ? a : b);
  var n = rest.contains(today) ? 1 : 0;
  for (var d = addDays(pk(today), -1); dk(d).compareTo(first) >= 0 && !active.contains(dk(d)); d = addDays(d, -1)) {
    n++;
  }
  return n;
}

/// Total gym time, short: `42m`, `3h 05m`, then whole hours from 10 h.
String totalTime(int mins) => mins < 600 ? dur(mins) : '${mins ~/ 60}h';

/// A stored workout log ("6/6 sets · 1h 12m in the gym") in the app language.
String logText(String? log) {
  if (log == null) return '';
  return log
      .replaceAll(' in the gym', ' ${tx('in the gym')}')
      .replaceAllMapped(RegExp(r'(\d+)/(\d+) sets'), (m) => tx('{done}/{total} sets', {'done': m[1], 'total': m[2]}));
}

/// A stored injury byline ("Reported by Ana · 9 Oct") in the app language.
String byLine(String by) {
  final m = RegExp(r'^(Reported|Added) by (.+?) · (\d+) (\w+)$').firstMatch(by);
  if (m == null) return by;
  const en = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  final i = en.indexOf(m[4]!);
  final day = i < 0 ? '${m[3]} ${m[4]}' : (isSerbian ? '${m[3]}. ${monthsShort[i]}' : '${m[3]} ${monthsShort[i]}');
  return tx(m[1] == 'Reported' ? 'Reported by {name} · {day}' : 'Added by {name} · {day}', {'name': m[2], 'day': day});
}
