// Loading a barbell: which plates go on each side for a weight.

/// Lifts done with a standard 20 kg bar, where the plates are shown.
const kBarbellLifts = {
  'Bench Press',
  'Incline Bench Press',
  'Decline Bench Press',
  'Close-grip Bench Press',
  'Floor Press',
  'Back Squat',
  'Front Squat',
  'Box Squat',
  'Deadlift',
  'Sumo Deadlift',
  'Romanian Deadlift',
  'Stiff-leg Deadlift',
  'Rack Pull',
  'Good Morning',
  'Barbell Row',
  'Pendlay Row',
  'Overhead Press',
  'Push Press',
  'Hip Thrust',
  'Barbell Shrug',
  'Barbell Curl',
};

/// Plates in a gym, heaviest first: kg, or lb.
const kPlatesKg = [25.0, 20.0, 15.0, 10.0, 5.0, 2.5, 1.25];
const kPlatesLb = [45.0, 35.0, 25.0, 10.0, 5.0, 2.5];

/// Bars: Olympic men's, women's and a light technique bar.
const kBarsKg = [20.0, 15.0, 10.0];
const kBarsLb = [45.0, 35.0, 15.0];

/// The plates for one side of the bar to make [total] on [bar], heaviest
/// first, all in one unit. [left] is the part of [total] these plates
/// cannot make; below the empty bar it is negative.
({List<double> side, double left}) platesFor(double total, double bar, List<double> plates) {
  var per = (total - bar) / 2;
  if (per < 0) return (side: const <double>[], left: total - bar);
  final side = <double>[];
  for (final p in plates) {
    while (per >= p - 1e-9) {
      side.add(p);
      per -= p;
    }
  }
  return (side: side, left: per < 1e-9 ? 0 : per * 2);
}

/// "2 × 20 · 10 · 2.5" for one side.
String sideText(List<double> side) {
  String n(double p) => p == p.roundToDouble() ? '${p.round()}' : '$p';
  final out = <String>[];
  for (var i = 0; i < side.length;) {
    var k = i;
    while (k < side.length && side[k] == side[i]) {
      k++;
    }
    out.add(k - i > 1 ? '${k - i} × ${n(side[i])}' : n(side[i]));
    i = k;
  }
  return out.join(' · ');
}
