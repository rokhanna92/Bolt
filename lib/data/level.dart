// Athlete level: XP from what Bolt already counts, and levels that take a
// bit more each time. Rank (rank.dart) is separate: it comes from strength.

import 'models/people.dart';

/// XP from sets, workouts, gym visits, PRs and perfect weeks.
int xpOf(TraineeStats s) => s.sets * 10 + s.workouts * 50 + s.sessions * 30 + s.prs * 100 + s.perfect * 200;

/// XP rusting from 3 days off, 25 a day; training wins it all back. It only
/// drains the bar, never a level.
int rustOf(int daysOff) => daysOff < 3 ? 0 : (daysOff - 2) * 25;

/// XP from level [l] to the next: 200, 300, 400, ...
int xpToNext(int l) => 100 + 100 * l;

class Level {
  const Level(this.level, this.into, this.need);

  final int level;

  /// XP into this level, and what the level takes.
  final int into;
  final int need;
}

Level levelOf(int xp) {
  var l = 1, left = xp;
  while (left >= xpToNext(l)) {
    left -= xpToNext(l);
    l++;
  }
  return Level(l, left, xpToNext(l));
}
