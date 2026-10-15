// Suggestions on Today: small fixes for the week, worked out from the plan.

import '../core/format.dart';
import 'lifts.dart';
import 'models/people.dart';
import 'models/session.dart';
import 'seed/exercises.dart';
import 'seed/muscles.dart';
import 'seed/templates.dart';

enum HintKind { missed, volume, deload }

class Hint {
  const Hint({
    required this.id,
    required this.kind,
    required this.text,
    required this.action,
    this.day,
    this.to,
    this.add,
  });

  /// Stays the same for the same situation, so a closed hint stays closed.
  final String id;
  final HintKind kind;
  final String text;
  final String action;

  /// The session it is about: the missed day, or where to add an exercise.
  final String? day;

  /// Where a missed session moves to.
  final String? to;

  /// Exercise to add for low volume.
  final ExSeed? add;
}

/// Muscles whose weekly volume Today keeps an eye on.
const _watched = ['chest', 'back', 'shoulders', 'quads', 'hamstrings', 'glutes'];

/// Up to three suggestions for [t], skipping the ones in [seen].
List<Hint> suggestions(
  Trainee t,
  Map<String, Session> plan,
  DateTime now, {
  required DateTime weekStart,
  required List<String> seen,
}) {
  final today = dk(now);
  final out = <Hint>[];
  bool open(Session s) => s.status == SessionStatus.approved || s.status == SessionStatus.moved;
  String? freeDay() {
    for (var i = 0; i < 7; i++) {
      final k = dk(addDays(now, i));
      if (plan[k] == null) return k;
    }
    return null;
  }

  // A confirmed session in the last week that never got done.
  final missed = [
    for (var i = 1; i <= 7; i++)
      if (plan[dk(addDays(now, -i))] case final Session s when open(s)) dk(addDays(now, -i)),
  ];
  final to = freeDay();
  if (missed.isNotEmpty && to != null) {
    final k = missed.first;
    out.add(
      Hint(
        id: 'missed:$k',
        kind: HintKind.missed,
        text: tx('You missed {workout} on {day}.', {'workout': tx(plan[k]!.title), 'day': fmtDay(k)}),
        action: tx('Move to {day}', {'day': to == today ? tx('today') : fmtDay(to)}),
        day: k,
        to: to,
      ),
    );
  }

  // From Thursday on: the muscle furthest under its weekly range, added to
  // the next workout this week.
  if (now.difference(weekStart).inDays >= 3) {
    final weekEnd = dk(addDays(weekStart, 7));
    final sets = muscleSets(plan, dk(weekStart), weekEnd);
    final trained = sets.values.fold(0, (a, b) => a + b) > 0;
    final next =
        (plan.keys.where((k) => k.compareTo(today) >= 0 && k.compareTo(weekEnd) < 0 && open(plan[k]!)).toList()..sort())
            .firstOrNull;
    if (trained && next != null) {
      String? worst;
      var gap = 0;
      // Sets still planned this week count too, so a Pull day coming up
      // covers the back.
      final planned = <String, int>{};
      for (final k in plan.keys.where((k) => k.compareTo(today) >= 0 && k.compareTo(weekEnd) < 0)) {
        if (!open(plan[k]!)) continue;
        for (final e in plan[k]!.ex) {
          final m = kExerciseByName[e.name]?.muscle;
          if (m != null) planned[m] = (planned[m] ?? 0) + e.sets;
        }
      }
      for (final m in _watched) {
        final lo = volumeRange(m)?.$1 ?? 0;
        final g = lo - (sets[m] ?? 0) - (planned[m] ?? 0);
        if (g > gap) {
          gap = g;
          worst = m;
        }
      }
      final ex = worst == null ? null : kExercises.where((e) => e.muscle == worst && e.compound).firstOrNull;
      if (worst != null && ex != null && gap >= 4) {
        final (lo, hi) = volumeRange(worst)!;
        out.add(
          Hint(
            id: 'volume:${dk(weekStart)}:$worst',
            kind: HintKind.volume,
            text: tx('{muscle} has {n} of {lo}-{hi} sets this week.', {
              'muscle': tx(kMuscles[worst]!.name),
              'n': sets[worst] ?? 0,
              'lo': lo,
              'hi': hi,
            }),
            action: tx('Add {exercise} to {day}', {
              'exercise': tx(ex.name),
              'day': next == today ? tx('today') : fmtDay(next),
            }),
            day: next,
            add: ExSeed(ex.name, 3, ex.reps, ex.load, ex.area, ex.alt),
          ),
        );
      }
    }
  }

  // Six or more hard weeks in a row (3+ workouts, no deload): rest up.
  var hard = 0;
  for (var w = 1; w <= 12; w++) {
    final from = addDays(weekStart, -7 * w);
    final week = [for (var i = 0; i < 7; i++) plan[dk(addDays(from, i))]].whereType<Session>();
    if (week.any((s) => s.deload) || week.where((s) => s.status == SessionStatus.done).length < 3) break;
    hard++;
  }
  final upcoming = [for (var i = 0; i < 14; i++) plan[dk(addDays(weekStart, i))]].whereType<Session>();
  if (hard >= 6 && !upcoming.any((s) => s.deload)) {
    out.add(
      Hint(
        id: 'deload:${dk(weekStart)}',
        kind: HintKind.deload,
        text: tx('{n} hard weeks in a row. Time for a deload week?', {'n': hard}),
        action: tx('Plan a deload'),
      ),
    );
  }
  return [
    for (final h in out)
      if (!seen.contains(h.id)) h,
  ].take(3).toList();
}
