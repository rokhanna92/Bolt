// What happened between two days: the numbers behind the wrap and the
// passport, counted the same way for both.

import 'lifts.dart';
import 'models/session.dart';
import 'models/visit.dart';

class PeriodStats {
  const PeriodStats({
    required this.workouts,
    required this.visits,
    required this.mins,
    required this.sets,
    required this.volume,
    required this.prs,
    required this.top,
    required this.muscles,
  });

  final int workouts;
  final int visits;
  final int mins;
  final int sets;

  /// Weight × reps over every logged set, in kg.
  final double volume;
  final int prs;

  /// The best estimated max and its lift.
  final (String, double)? top;

  /// Hard sets per muscle, most first.
  final List<MapEntry<String, int>> muscles;

  bool get isEmpty => workouts == 0 && visits == 0;
}

/// Finished workouts and gym visits from [from] up to, not including, [to].
PeriodStats periodStats(Map<String, Session> plan, List<Visit> visits, String from, String to) {
  bool inRange(String k) => k.compareTo(from) >= 0 && k.compareTo(to) < 0;
  final done = [
    for (final e in plan.entries)
      if (e.value.status == SessionStatus.done && inRange(e.key)) e.value,
  ];
  final seen = visits.where((v) => inRange(v.date)).toList();
  var sets = 0, prs = 0;
  var volume = 0.0;
  (String, double)? top;
  for (final s in done) {
    prs += s.prs.length;
    for (final x in s.ex) {
      sets += x.logged.isNotEmpty ? x.logged.length : x.sets;
      for (final l in x.logged) {
        volume += (l.kg ?? 0) * (l.reps ?? 0);
        final m = e1rm(l);
        if (m != null && (top == null || m > top.$2)) top = (x.name, m);
      }
    }
  }
  return PeriodStats(
    workouts: done.length,
    visits: seen.length,
    mins: seen.fold(0, (a, v) => a + v.mins),
    sets: sets,
    volume: volume,
    prs: prs,
    top: top,
    muscles: muscleSets(plan, from, to).entries.toList()..sort((x, y) => y.value - x.value),
  );
}
