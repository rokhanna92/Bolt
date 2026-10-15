// Weekly splits. The first four are ported verbatim from `SPLITS` in Bolt
// UI.html. Weekday numbers: 1 = Monday ... 7 = Sunday.

import '../models/bolt_data.dart';

class SplitDay {
  const SplitDay(this.weekday, this.tpl);

  final int weekday;
  final String tpl;
}

class Split {
  const Split({required this.name, required this.short, required this.days, this.custom = false});

  final String name;
  final String short;
  final List<SplitDay> days;

  /// Built by the user on this phone.
  final bool custom;

  /// Template ids in rotation order.
  List<String> get sequence => [for (final d in days) d.tpl];
}

const kSplits = <String, Split>{
  'ppl': Split(
    name: '3-day Push / Pull / Legs',
    short: 'PPL',
    days: [SplitDay(1, 'push'), SplitDay(3, 'pull'), SplitDay(5, 'legs')],
  ),
  'ppl6': Split(
    name: '6-day Push / Pull / Legs',
    short: 'PPL x2',
    days: [
      SplitDay(1, 'push'),
      SplitDay(2, 'pull'),
      SplitDay(3, 'legs'),
      SplitDay(4, 'push'),
      SplitDay(5, 'pull'),
      SplitDay(6, 'legs'),
    ],
  ),
  'ul': Split(
    name: '4-day Upper / Lower',
    short: 'Upper/Lower',
    days: [SplitDay(1, 'upper'), SplitDay(2, 'legs'), SplitDay(4, 'upper'), SplitDay(5, 'cond')],
  ),
  'fb': Split(
    name: '3-day Full Body',
    short: 'Full body',
    days: [SplitDay(1, 'full'), SplitDay(3, 'full'), SplitDay(5, 'cond')],
  ),
  'old4': Split(
    name: '4-day Old School',
    short: 'Old school',
    days: [SplitDay(1, 'chtri'), SplitDay(2, 'bish'), SplitDay(4, 'legs'), SplitDay(5, 'back')],
  ),
  'classic4': Split(
    name: '4-day Back & Bi / Chest & Tri',
    short: 'Bro pairs',
    days: [SplitDay(1, 'chtri'), SplitDay(2, 'backbi'), SplitDay(4, 'shoul'), SplitDay(5, 'legs')],
  ),
  'bro5': Split(
    name: '5-day Bro Split',
    short: 'Bro split',
    days: [SplitDay(1, 'chest'), SplitDay(2, 'back'), SplitDay(3, 'shoul'), SplitDay(4, 'arms'), SplitDay(5, 'legs')],
  ),
  'arnold': Split(
    name: '6-day Arnold Split',
    short: 'Arnold',
    days: [
      SplitDay(1, 'chback'),
      SplitDay(2, 'sharm'),
      SplitDay(3, 'legs'),
      SplitDay(4, 'chback'),
      SplitDay(5, 'sharm'),
      SplitDay(6, 'legs'),
    ],
  ),
  'hit2': Split(name: '2-day Heavy Duty', short: 'Heavy Duty', days: [SplitDay(1, 'hit'), SplitDay(4, 'hit')]),
  'str3': Split(
    name: '3-day Strength 5×5',
    short: '5×5',
    days: [SplitDay(1, 'str5a'), SplitDay(3, 'str5b'), SplitDay(5, 'str5a')],
  ),
  'glute4': Split(
    name: '4-day Glute Focus',
    short: 'Glutes',
    days: [SplitDay(1, 'glutes'), SplitDay(2, 'upper'), SplitDay(4, 'legs'), SplitDay(5, 'glutes')],
  ),
  'hybrid': Split(
    name: '5-day Hybrid (lift + engine)',
    short: 'Hybrid',
    days: [SplitDay(1, 'upper'), SplitDay(2, 'zone2'), SplitDay(3, 'legs'), SplitDay(4, 'hiit'), SplitDay(6, 'full')],
  ),
  'calis3': Split(
    name: '3-day Calisthenics',
    short: 'Bodyweight',
    days: [SplitDay(1, 'calis'), SplitDay(3, 'hiit'), SplitDay(5, 'calis')],
  ),
  'home3': Split(
    name: '3-day Home Dumbbell',
    short: 'Home',
    days: [SplitDay(1, 'home'), SplitDay(3, 'hiit'), SplitDay(5, 'home')],
  ),
  'rehab': Split(name: '2-day Rehab', short: 'Rehab', days: [SplitDay(2, 'full'), SplitDay(4, 'mob')]),
};

final List<String> kSplitOrder = kSplits.keys.toList();

/// Weekdays in display order, Monday to Sunday.
const kWeekOrder = [1, 2, 3, 4, 5, 6, 7];

/// A built-in split or one of the user's own; an unknown id (a deleted
/// custom split) falls back to Push / Pull / Legs.
Split splitOf(BoltData d, String id) => kSplits[id] ?? d.splits[id]?.toSplit() ?? kSplits['ppl']!;

/// Every split id: built-in first, then the user's own.
List<String> splitIds(BoltData d) => [...kSplitOrder, ...d.splits.keys];
