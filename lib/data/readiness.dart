// The daily check-in: what it asks, its score from 0 to 100 and what that
// does to the day's workout.

/// A check-in is stored per day as numbers: sleep quality, energy and
/// soreness (1 to 3, 3 the best), then sleep in half hours, mood (1 to 3),
/// grip from 0 to 10 (tenths of full strength), sore muscle groups as bits
/// of [kSoreGroups] and the score. Check-ins from before Bolt 1.24 have only
/// the first three.
const kSleepQ = 0, kEnergy = 1, kSore = 2, kHalfHours = 3, kMood = 4, kGrip = 5, kSoreAt = 6, kScore = 7;

/// Muscle groups a check-in can mark sore, in bit order.
const kSoreGroups = ['chest', 'back', 'shoulders', 'arms', 'legs', 'core'];

/// Below this the workout makes way for a rest day.
const kRestBelow = 35;

/// Below this the workout gets lighter.
const kLighterBelow = 50;

/// The sore groups in [mask].
Set<String> soreGroups(int mask) => {
  for (final (i, g) in kSoreGroups.indexed)
    if (mask & (1 << i) != 0) g,
};

/// Today's readiness from the [answers] (everything up to [kScore]):
///
/// - sleep hours 20 (4.5 h or less 0, 8 h or more full), sleep quality 10,
///   energy 20, mood 10, soreness 15;
/// - grip 25, against your own average of [grips] when there are at least
///   3 (full at your average, nothing at 80% of it), else 50% to 90%;
/// - minus 8 for each sore group that [today]'s workout trains (up to 16),
///   5 for each day trained in a row past two ([streak], up to 15) and 10
///   when the workout loads an injury ([injured]).
int readinessScore(
  List<int> answers, {
  required Set<String> today,
  required List<int> grips,
  required int streak,
  required bool injured,
}) {
  double q(int x) => (x - 1) / 2;
  final hours = answers[kHalfHours] / 2;
  final grip = answers[kGrip] * 10.0;
  final base = grips.length >= 3 ? grips.fold(0, (a, b) => a + b) * 10 / grips.length : null;
  final gripPart = base == null || base == 0
      ? ((grip - 50) / 40).clamp(0.0, 1.0)
      : ((grip / base - .8) / .2).clamp(0.0, 1.0);
  final hit = soreGroups(answers[kSoreAt]).intersection(today).length;
  final score =
      20 * ((hours - 4.5) / 3.5).clamp(0.0, 1.0) +
      10 * q(answers[kSleepQ]) +
      20 * q(answers[kEnergy]) +
      10 * q(answers[kMood]) +
      15 * q(answers[kSore]) +
      25 * gripPart -
      (8 * hit).clamp(0, 16) -
      (5 * (streak - 2)).clamp(0, 15) -
      (injured ? 10 : 0);
  return score.round().clamp(0, 100);
}
