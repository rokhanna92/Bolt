import 'dart:math' as math;

import '../core/format.dart';
import 'models/exercise.dart';
import 'models/people.dart';
import 'models/session.dart';
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

/// Streak as it stands today: it breaks once a whole week passes without
/// a perfect week.
int currentStreak(TraineeStats s, DateTime now) {
  final last = s.lastPerfectWeek;
  if (last == null) return s.streak;
  return last.compareTo(dk(addDays(monday(now), -7))) >= 0 ? s.streak : 0;
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
  return '${plural(r, kBadgeUnits[b.key]!)} to go';
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
