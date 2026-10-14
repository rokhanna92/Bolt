// Weekly splits, ported verbatim from `SPLITS` in Bolt UI.html.
// Weekday numbers follow JS getDay(): 1 = Monday ... 5 = Friday.

class SplitDay {
  const SplitDay(this.weekday, this.tpl);

  final int weekday;
  final String tpl;
}

class Split {
  const Split({required this.name, required this.short, required this.days});

  final String name;
  final String short;
  final List<SplitDay> days;

  /// Template ids in rotation order.
  List<String> get sequence => [for (final d in days) d.tpl];
}

const kSplits = <String, Split>{
  'ppl': Split(name: '3-day Push / Pull / Legs', short: 'PPL', days: [SplitDay(1, 'push'), SplitDay(3, 'pull'), SplitDay(5, 'legs')]),
  'ul': Split(name: '4-day Upper / Lower', short: 'Upper/Lower', days: [SplitDay(1, 'upper'), SplitDay(2, 'legs'), SplitDay(4, 'upper'), SplitDay(5, 'cond')]),
  'fb': Split(name: '3-day Full Body', short: 'Full body', days: [SplitDay(1, 'full'), SplitDay(3, 'full'), SplitDay(5, 'cond')]),
  'rehab': Split(name: '2-day Rehab', short: 'Rehab', days: [SplitDay(2, 'full'), SplitDay(4, 'mob')]),
};

final List<String> kSplitOrder = kSplits.keys.toList();
