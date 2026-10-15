// When the owner trains fastest: minutes per set by weekday and time of
// day, from gym visits that logged a workout. Fewer minutes per set means
// less waiting for kit and fewer interruptions.

import '../core/format.dart';
import 'models/session.dart';
import 'models/visit.dart';

class GymSlot {
  const GymSlot(this.weekday, this.hour, this.visits, this.minPerSet);

  /// 1 = Monday.
  final int weekday;

  /// Start of the two-hour block, e.g. 18 for 18:00-20:00.
  final int hour;
  final int visits;
  final double minPerSet;
}

/// Slots with at least two visits, fastest first.
List<GymSlot> gymSlots(List<Visit> visits, Map<String, Session> plan) {
  final groups = <(int, int), List<double>>{};
  for (final v in visits) {
    final s = plan[v.date];
    if (s == null || s.status != SessionStatus.done || v.auto) continue;
    final sets = s.ex.fold(0, (a, e) => a + (e.logged.isNotEmpty ? e.logged.length : e.sets));
    if (sets == 0) continue;
    final key = (pk(v.date).weekday, toMin(v.inT) ~/ 120 * 2);
    groups.putIfAbsent(key, () => []).add(v.mins / sets);
  }
  return [
    for (final e in groups.entries)
      if (e.value.length >= 2)
        GymSlot(e.key.$1, e.key.$2, e.value.length, e.value.reduce((a, b) => a + b) / e.value.length),
  ]..sort((a, b) => a.minPerSet.compareTo(b.minPerSet));
}
