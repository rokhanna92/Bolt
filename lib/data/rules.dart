import '../core/format.dart';
import 'models/exercise.dart';
import 'models/people.dart';
import 'models/session.dart';
import 'seed/badges.dart';
import 'seed/splits.dart';

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
/// session in the split rotation, or the first one.
String nextInRotation(Map<String, Session> plan, String split, String k) {
  final seq = kSplits[split]!.sequence;
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

/// "3 sessions to go".
String badgeLeftText(BadgeDef b, TraineeStats s) {
  final r = b.goal - s.value(b.key);
  return '${plural(r, kBadgeUnits[b.key]!)} to go';
}
