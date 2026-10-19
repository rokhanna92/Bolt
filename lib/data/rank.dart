// Rank: how strong you are for your bodyweight, as tiers with divisions
// like competitive games. Everyone starts at Bodyweight and is placed by the
// main lifts. Levels (XP) count what you do; rank counts what you can lift.

import 'dart:math' as math;

import 'lifts.dart';
import 'models/exercise.dart';
import 'models/people.dart';
import 'models/session.dart';
import 'strength.dart';

/// From the start to the top. Bodyweight and Olympia have no divisions.
const kTiers = [
  'Bodyweight',
  'Plastic',
  'Bronze',
  'Iron',
  'Steel',
  'Silver',
  'Gold',
  'Platinum',
  'Diamond',
  'Immortal',
  'Olympia',
];

/// Steps on the ladder: Bodyweight, Plastic I to Immortal III, Olympia.
const kRankSteps = 1 + 27 + 1;

/// One lift's place: 0 to 5 across Beginner, Novice, Intermediate, Advanced
/// and Elite, and as wide again past Elite.
class RankedLift {
  const RankedLift(this.name, this.maxKg, this.pos);

  final String name;
  final double maxKg;
  final double pos;
}

class Rank {
  const Rank({required this.step, required this.into, required this.lifts, required this.score});

  /// 0 is Bodyweight, 1 to 27 Plastic I to Immortal III, 28 Olympia.
  final int step;

  /// How far into this step, 0 to 1: the bar to the next division.
  final double into;

  /// The lifts that count, best first (up to three).
  final List<RankedLift> lifts;

  /// The mean place of [lifts], 0 to 5.
  final double score;

  bool get placed => lifts.isNotEmpty;
  int get tier => tierOf(step);
  String get name => rankName(step);
}

int tierOf(int step) => step == 0 ? 0 : (step >= kRankSteps - 1 ? kTiers.length - 1 : 1 + (step - 1) ~/ 3);

/// 1, 2 or 3 inside a tier; 0 for Bodyweight and Olympia.
int divisionOf(int step) => step == 0 || step >= kRankSteps - 1 ? 0 : 1 + (step - 1) % 3;

/// "Gold II", "Bodyweight", "Olympia". English; translate the tier with tx.
String rankName(int step) {
  final d = divisionOf(step);
  return d == 0 ? kTiers[tierOf(step)] : '${kTiers[tierOf(step)]} ${const ['I', 'II', 'III'][d - 1]}';
}

/// Where [ratio] (max ÷ bodyweight) sits on [t], the multiples where Novice,
/// Intermediate, Advanced and Elite start.
double placeOf(double ratio, List<double> t) {
  if (ratio < t[0]) return ratio / t[0];
  for (var l = 1; l < 4; l++) {
    if (ratio < t[l]) return l + (ratio - t[l - 1]) / (t[l] - t[l - 1]);
  }
  return math.min(5, 4 + (ratio - t[3]) / (t[3] - t[2]));
}

/// The max ratio that puts a lift at [pos]; the inverse of [placeOf].
double ratioAt(double pos, List<double> t) {
  if (pos <= 1) return pos * t[0];
  if (pos <= 4) {
    final l = pos.floor().clamp(1, 3);
    return t[l - 1] + (pos - l) * (t[l] - t[l - 1]);
  }
  return t[3] + (pos - 4) * (t[3] - t[2]);
}

/// The best estimated max of [name] from days logged as done without
/// ticking sets, a past day from the diary or a gym day filled in later:
/// their planned weight and reps count as what was lifted, the bottom of a
/// rep range (8-10 is 8).
double? plannedMax(Map<String, Session> plan, String name) {
  double? best;
  for (final s in plan.values) {
    if (s.status != SessionStatus.done) continue;
    for (final e in s.ex) {
      if (e.name != name || e.logged.isNotEmpty) continue;
      for (var j = 0; j < e.sets; j++) {
        final est = e1rm(SetLog(kg: loadKg(e.loadFor(j)), reps: lowReps(e.repsFor(j))));
        if (est != null && (best == null || est > best)) best = est;
      }
    }
  }
  return best;
}

/// The rank of [t]: the mean place of their best three lifts with strength
/// standards, from a max set by hand, else the best of logged sets and days
/// logged as done. Unplaced (Bodyweight) without a bodyweight, sex or any
/// such lift.
Rank rankOf(Trainee t, Map<String, Session> plan) {
  final lifts = <RankedLift>[];
  final bw = t.body.weightKg;
  if (bw != null && bw > 0 && t.body.sex != null) {
    for (final name in kStandardLifts) {
      final set = maxFor(t, plan, name);
      final planned = t.maxes[name] == null ? plannedMax(plan, name) : null;
      final max = set == null || (planned != null && planned > set) ? planned : set;
      final s = standardsFor(name, t.body);
      if (max == null || max <= 0 || s == null) continue;
      lifts.add(RankedLift(name, max, placeOf(max / bw, s)));
    }
  }
  lifts.sort((a, b) => b.pos.compareTo(a.pos));
  final top = lifts.take(3).toList();
  if (top.isEmpty) return const Rank(step: 0, into: 0, lifts: [], score: 0);
  final score = top.fold(0.0, (a, l) => a + l.pos) / top.length;
  if (score >= 5) return Rank(step: kRankSteps - 1, into: 1, lifts: top, score: score);
  final x = score / 5 * 27;
  return Rank(step: 1 + x.floor(), into: x - x.floor(), lifts: top, score: score);
}

/// The smallest gain on one counted lift that reaches the next division:
/// the lift and the kilograms to add, rounded up to 2.5. Null at Olympia or
/// unplaced.
(String, double)? nextStep(Rank r, Body body) {
  if (!r.placed || r.step >= kRankSteps - 1) return null;
  final bw = body.weightKg!;
  final n = r.lifts.length;
  // The score that starts the next step, a hair over so rounding lands in it.
  final target = r.step >= kRankSteps - 2 ? 5.0 : (r.step / 27 * 5) + 1e-6;
  (String, double)? best;
  for (final l in r.lifts) {
    final pos = l.pos + (target - r.score) * n;
    if (pos > 5 + 1e-9) continue;
    final s = standardsFor(l.name, body)!;
    final kg = ((ratioAt(pos, s) * bw - l.maxKg) / 2.5).ceil() * 2.5;
    if (best == null || kg < best.$2) best = (l.name, math.max(2.5, kg));
  }
  return best;
}
