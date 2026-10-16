// The warm-up before a workout, from what it trains.

import '../core/format.dart';
import 'lifts.dart';
import 'models/session.dart';
import 'rules.dart';

/// Minutes and steps to warm up for [s]: easy cardio, moves for the muscles
/// it trains and ramp-up sets of the first big lift.
(int, List<String>) warmupPlan(Session s) {
  final g = sessionGroups(s);
  if (g.isEmpty || g.every((x) => x == 'cond')) {
    return (10, [tx('5 minutes easy, then build the pace over 5 more.')]);
  }
  final parts = [
    if (g.contains('legs')) tx('Legs: 10 leg swings each way, 10 bodyweight squats, 10 hip circles.'),
    if (g.contains('chest') || g.contains('shoulders'))
      tx('Shoulders: 15 arm circles, 15 band pull-aparts, 10 push-ups.'),
    if (g.contains('back')) tx('Back: 10 cat-cows, 8 scapula pull-ups, 10 light band rows.'),
    if (g.contains('arms') && !g.contains('chest') && !g.contains('back'))
      tx('Elbows: one light set of 15 curls and 15 pushdowns.'),
  ];
  final first = warmupFor(s.ex);
  return (
    (5 + 3 * parts.length).clamp(8, 14),
    [
      tx('5 minutes easy cardio: bike, rower or incline walk.'),
      ...parts,
      if (first != null) tx('Then 2-3 lighter ramp-up sets of {name}.', {'name': tx(first.name)}),
    ],
  );
}
