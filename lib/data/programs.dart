// Multi-week programs: sets, reps and a percentage of the one-rep max for
// the main barbell lifts, week by week. Everything else in the plan stays
// as the split has it.

/// One week of a program for the main lifts.
typedef ProgramWeek = (int sets, String reps, double pct);

class Program {
  const Program(this.id, this.name, this.desc, this.weeks);

  final String id;
  final String name;
  final String desc;
  final List<ProgramWeek> weeks;
}

const kPrograms = [
  Program(
    'lp',
    'Linear progression',
    'For beginners: 3 sets of 5 on the main lifts, a little heavier every week for 8 weeks.',
    [
      (3, '5', 65),
      (3, '5', 67.5),
      (3, '5', 70),
      (3, '5', 72.5),
      (3, '5', 75),
      (3, '5', 77.5),
      (3, '5', 80),
      (3, '5', 82.5),
    ],
  ),
  Program(
    'w531',
    'Wave 5/3/1',
    'Four-week waves inspired by 5/3/1: fives, threes, heavy singles, then a deload week. Straight sets.',
    [(3, '5', 75), (3, '3', 82.5), (3, '1', 90), (3, '5', 55)],
  ),
  Program(
    'block',
    '12-week block',
    'Four weeks of volume (4×10), four of strength (4×6), three of peaking (5×3), then a light week to test.',
    [
      (4, '10', 65),
      (4, '10', 67.5),
      (4, '10', 70),
      (4, '10', 72.5),
      (4, '6', 75),
      (4, '6', 77.5),
      (4, '6', 80),
      (4, '6', 82.5),
      (5, '3', 85),
      (5, '3', 87.5),
      (5, '3', 90),
      (3, '3', 60),
    ],
  ),
];

Program? programById(String? id) {
  for (final p in kPrograms) {
    if (p.id == id) return p;
  }
  return null;
}

/// The barbell lifts a program sets loads for.
const kMainLifts = {
  'Back Squat',
  'Front Squat',
  'Box Squat',
  'Bench Press',
  'Incline Bench Press',
  'Close-grip Bench Press',
  'Deadlift',
  'Sumo Deadlift',
  'Trap Bar Deadlift',
  'Romanian Deadlift',
  'Overhead Press',
  'Barbell Row',
  'Hip Thrust',
};

/// "80%" or "82.5%".
String pctText(double p) => '${p == p.roundToDouble() ? p.toStringAsFixed(0) : p.toString()}%';
