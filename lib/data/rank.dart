// Rank: how strong you are for your bodyweight, as tiers with divisions
// like competitive games. Everyone starts at Bodyweight and is placed by the
// main lifts. Levels (XP) count what you do; rank counts what you can lift.

import 'dart:math' as math;

import 'lifts.dart';
import 'models/exercise.dart';
import 'models/people.dart';
import 'models/session.dart';
import 'strength.dart';

/// From the start to the top. Bodyweight, Olympia and Atlas have no
/// divisions.
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
  'Atlas',
];

/// Steps on the ladder: Bodyweight (0), Plastic I to Immortal III (1 to
/// 27), Olympia and Atlas.
const kOlympia = 28;
const kAtlas = 29;

/// Olympia is the greatest lifters there have been: every main lift well
/// past Elite. Atlas, a titan, maybe once in a thousand years: two bands
/// past Elite on all three, world-record strength in each at once.
const kOlympiaScore = 5.0;
const kAtlasScore = 6.0;

/// The score where each tier from Plastic to Immortal starts, then Olympia.
/// Rank is meant to be climbed: Intermediate on every lift is already
/// Platinum, while the strength levels themselves stay the honest standards.
const _tierStart = [0.0, .25, .5, .8, 1.1, 1.5, 2.0, 2.6, 3.4, kOlympiaScore];

/// One lift's place: 0 to 5 across Beginner, Novice, Intermediate, Advanced
/// and Elite, then up to 6 for a second band as wide past Elite.
class RankedLift {
  const RankedLift(this.name, this.maxKg, this.pos, {this.reps});

  final String name;
  final double maxKg;
  final double pos;

  /// Best set of a bodyweight lift, which has no [maxKg].
  final int? reps;
}

class Rank {
  const Rank({required this.step, required this.into, required this.lifts, required this.score});

  /// 0 is Bodyweight, 1 to 27 Plastic I to Immortal III, then [kOlympia]
  /// and [kAtlas].
  final int step;

  /// How far into this step, 0 to 1: the bar to the next division.
  final double into;

  /// The lifts that count, best first (up to three).
  final List<RankedLift> lifts;

  /// The mean place of [lifts], 0 to 6.
  final double score;

  bool get placed => lifts.isNotEmpty;
  int get tier => tierOf(step);
  String get name => rankName(step);
}

int tierOf(int step) =>
    step == 0 ? 0 : (step >= kOlympia ? kTiers.length - 1 - (kAtlas - step).clamp(0, 1) : 1 + (step - 1) ~/ 3);

/// 1, 2 or 3 inside a tier; 0 for Bodyweight, Olympia and Atlas.
int divisionOf(int step) => step == 0 || step >= kOlympia ? 0 : 1 + (step - 1) % 3;

/// The step a place of [score] lands on.
int stepOf(double score) {
  if (score >= kAtlasScore) return kAtlas;
  if (score >= kOlympiaScore) return kOlympia;
  var tier = _tierStart.length - 2;
  while (score < _tierStart[tier]) {
    tier--;
  }
  final division = (score - _tierStart[tier]) / (_tierStart[tier + 1] - _tierStart[tier]) * 3;
  return 1 + tier * 3 + math.min(2, (division + 1e-9).floor());
}

/// The score where [step] starts.
double scoreAt(int step) {
  if (step >= kAtlas) return kAtlasScore;
  if (step >= kOlympia) return kOlympiaScore;
  final tier = (step - 1) ~/ 3;
  return _tierStart[tier] + (step - 1) % 3 * (_tierStart[tier + 1] - _tierStart[tier]) / 3;
}

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
  return math.min(kAtlasScore, 4 + (ratio - t[3]) / (t[3] - t[2]));
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

/// The most reps of [name] in one set, from logged sets and days logged as
/// done without ticking sets.
int? bestReps(Map<String, Session> plan, String name) {
  int? best;
  for (final s in plan.values) {
    if (s.status != SessionStatus.done) continue;
    for (final e in s.ex) {
      if (e.name != name) continue;
      final reps = e.logged.isNotEmpty
          ? e.logged.map((l) => l.reps)
          : [for (var j = 0; j < e.sets; j++) lowReps(e.repsFor(j))];
      for (final r in reps) {
        if (r != null && r > 0 && (best == null || r > best)) best = r;
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
    for (final name in kRepLifts) {
      final reps = bestReps(plan, name);
      if (reps != null) {
        lifts.add(RankedLift(name, 0, placeOf(reps.toDouble(), repStandardsFor(name, t.body)!), reps: reps));
      }
    }
  }
  lifts.sort((a, b) => b.pos.compareTo(a.pos));
  final top = lifts.take(3).toList();
  if (top.isEmpty) return const Rank(step: 0, into: 0, lifts: [], score: 0);
  final score = top.fold(0.0, (a, l) => a + l.pos) / top.length;
  final step = stepOf(score);
  final into = step >= kAtlas ? 1.0 : ((score - scoreAt(step)) / (scoreAt(step + 1) - scoreAt(step))).clamp(0.0, 1.0);
  return Rank(step: step, into: into, lifts: top, score: score);
}

/// What reaches the next step from one counted lift alone: each lift and
/// the kilograms to add (rounded up to 2.5), or reps for a bodyweight lift,
/// smallest first. Empty at
/// Atlas, unplaced, or when no single lift can get there.
List<(String, double)> nextOptions(Rank r, Body body) {
  if (!r.placed || r.step >= kAtlas) return const [];
  final bw = body.weightKg!;
  final n = r.lifts.length;
  // A hair over the start of the next step so rounding lands inside it.
  final target = scoreAt(r.step + 1) + 1e-6;
  final out = <(String, double)>[];
  for (final l in r.lifts) {
    final pos = l.pos + (target - r.score) * n;
    if (pos > kAtlasScore + 1e-9) continue;
    if (l.reps != null) {
      final more = (ratioAt(pos, repStandardsFor(l.name, body)!) - l.reps!).ceil();
      out.add((l.name, math.max(1, more).toDouble()));
      continue;
    }
    final s = standardsFor(l.name, body)!;
    final kg = ((ratioAt(pos, s) * bw - l.maxKg) / 2.5).ceil() * 2.5;
    out.add((l.name, math.max(2.5, kg)));
  }
  // Smallest first; a tie keeps the stronger lift first.
  int at(String lift) => r.lifts.indexWhere((l) => l.name == lift);
  return out..sort((a, b) => a.$2 != b.$2 ? a.$2.compareTo(b.$2) : at(a.$1).compareTo(at(b.$1)));
}

/// The smallest single-lift gain to the next step, or null.
(String, double)? nextStep(Rank r, Body body) => nextOptions(r, body).firstOrNull;
