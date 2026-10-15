// Muscles: the keys exercises are tagged with, the badge group each one
// counts toward, and what Learn says about them.

import '../../l10n/l10n.dart';

class MuscleInfo {
  const MuscleInfo({
    required this.name,
    required this.group,
    required this.parts,
    required this.does,
    required this.tips,
    required this.volume,
  });

  final String name;

  /// Badge counter group (`chest`, `back`, `shoulders`, `arms`, `legs`,
  /// `core`, `cond`).
  final String group;

  /// Heads or regions, e.g. "Upper, middle and lower fibres".
  final String parts;

  /// What it does in plain words.
  final String does;
  final List<String> tips;

  /// Weekly working sets that suit most people.
  final String volume;
}

/// Muscles in picker order. `cardio` is not a muscle but builds an engine day.
const kMuscles = <String, MuscleInfo>{
  'chest': MuscleInfo(
    name: 'Chest',
    group: 'chest',
    parts: 'Pectoralis major (upper/clavicular and lower/sternal fibres), pectoralis minor',
    does: 'Pushes the arms forward and brings them across the body. Every press, push-up and dip uses it.',
    tips: [
      'Keep shoulder blades pinned back and down so the chest, not the front shoulders, does the pressing.',
      'Incline work (30°) biases the upper chest, flat and decline the lower fibres.',
      'Flyes and cable crossovers add stretch and squeeze that presses miss.',
    ],
    volume: '10-20 sets a week',
  ),
  'back': MuscleInfo(
    name: 'Back',
    group: 'back',
    parts: 'Lats, rhomboids, middle traps, teres major, spinal erectors',
    does: 'Pulls the arms down and back and keeps the spine upright. Width comes from the lats, thickness from rows.',
    tips: [
      'Train both a vertical pull (pull-ups, pulldowns) for width and a horizontal pull (rows) for thickness.',
      'Start each pull by moving the shoulder blades, then drive the elbows. Think of the hands as hooks.',
      'Use straps on heavy pulls when grip gives out before the back does.',
    ],
    volume: '10-20 sets a week',
  ),
  'shoulders': MuscleInfo(
    name: 'Shoulders',
    group: 'shoulders',
    parts: 'Deltoids: front, side and rear heads, plus the rotator cuff underneath',
    does: 'Lifts the arm in every direction. Side delts give width, rear delts keep the shoulder healthy and balanced.',
    tips: [
      'Front delts already work hard on every press. Most people need more side and rear delt work, not more front.',
      'Lateral raises respond to higher reps (12-20) and strict control.',
      'Face pulls and rear delt flyes balance out a lot of pressing.',
    ],
    volume: '8-16 sets a week for side and rear delts',
  ),
  'biceps': MuscleInfo(
    name: 'Biceps',
    group: 'arms',
    parts: 'Biceps long and short heads, brachialis, brachioradialis',
    does: 'Bends the elbow and turns the palm up. The brachialis under it adds arm thickness.',
    tips: [
      'Hammer curls hit the brachialis and forearm, supinated curls the biceps peak.',
      'Incline curls stretch the long head, preacher curls load the short head.',
      'Rows and pull-ups already train the biceps, so a few direct sets go a long way.',
    ],
    volume: '6-14 direct sets a week',
  ),
  'triceps': MuscleInfo(
    name: 'Triceps',
    group: 'arms',
    parts: 'Long, lateral and medial heads',
    does: 'Straightens the elbow. It is about two thirds of upper arm size, so big arms need big triceps.',
    tips: [
      'The long head crosses the shoulder: overhead extensions stretch it best.',
      'Close-grip bench and dips let you go heavy, pushdowns finish it off.',
      'Keep elbows still. If they drift, the shoulders take over.',
    ],
    volume: '6-14 direct sets a week',
  ),
  'forearms': MuscleInfo(
    name: 'Forearms',
    group: 'arms',
    parts: 'Wrist flexors and extensors, brachioradialis, grip muscles',
    does: 'Grips, bends and turns the wrist. Grip strength limits deadlifts, rows and carries.',
    tips: [
      'Heavy carries and dead hangs build grip that transfers to every pull.',
      'Wrist curls and reverse curls add size, usually at the end of an arm day.',
      'Skip straps on lighter sets to train grip on the way.',
    ],
    volume: '4-10 sets a week',
  ),
  'traps': MuscleInfo(
    name: 'Traps',
    group: 'back',
    parts: 'Upper, middle and lower trapezius',
    does: 'Shrugs, pulls the shoulder blades together and tilts them up for overhead work.',
    tips: [
      'Shrugs train the upper traps, rows and face pulls the middle and lower.',
      'Deadlifts and carries build a lot of trap size on their own.',
      'Pause at the top of shrugs, do not roll the shoulders.',
    ],
    volume: '6-12 sets a week',
  ),
  'abs': MuscleInfo(
    name: 'Abs & core',
    group: 'core',
    parts: 'Rectus abdominis, obliques, transverse abdominis',
    does: 'Bends and twists the trunk and, more importantly, stops it bending when you lift heavy.',
    tips: [
      'Train both moving (crunches, leg raises) and resisting movement (planks, pallof press).',
      'Abs grow like any muscle: add load or reps over time.',
      'Visible abs come from low body fat, which is a diet job.',
    ],
    volume: '6-12 sets a week',
  ),
  'quads': MuscleInfo(
    name: 'Quads',
    group: 'legs',
    parts: 'Rectus femoris, vastus lateralis, medialis and intermedius',
    does: 'Straightens the knee. The biggest muscle group on the front of the body.',
    tips: [
      'Squats, leg press and lunges are the base; leg extensions isolate them.',
      'Deep knee bend under control grows quads best.',
      'Heels raised or a narrower stance shifts more work to the quads.',
    ],
    volume: '10-20 sets a week',
  ),
  'hamstrings': MuscleInfo(
    name: 'Hamstrings',
    group: 'legs',
    parts: 'Biceps femoris, semitendinosus, semimembranosus',
    does: 'Bends the knee and extends the hip. Strong hamstrings protect the knees and power sprinting.',
    tips: [
      'Train both jobs: a hip hinge (RDL, good morning) and a knee curl (leg curl).',
      'Slow lowering on curls and RDLs builds strength that resists strains.',
      'Nordic curls are hard but among the best hamstring injury-prevention exercises.',
    ],
    volume: '8-16 sets a week',
  ),
  'glutes': MuscleInfo(
    name: 'Glutes',
    group: 'legs',
    parts: 'Gluteus maximus, medius and minimus',
    does: 'Extends and opens the hip. The largest muscle in the body and key for posture and power.',
    tips: [
      'Hip thrusts and bridges load the glutes at full hip extension, squats and lunges at the stretch.',
      'Abduction work (band walks, cable kickouts) trains the glute medius that keeps knees stable.',
      'Squeeze hard at the top of every hip extension.',
    ],
    volume: '8-20 sets a week',
  ),
  'calves': MuscleInfo(
    name: 'Calves',
    group: 'legs',
    parts: 'Gastrocnemius and soleus',
    does: 'Points the foot. Gastrocnemius works best with straight legs, the soleus with bent knees.',
    tips: [
      'Full stretch at the bottom and a pause matter more than weight.',
      'Do standing (straight knee) and seated (bent knee) raises to hit both muscles.',
      'Calves recover fast and tolerate frequent training.',
    ],
    volume: '8-16 sets a week',
  ),
  'cardio': MuscleInfo(
    name: 'Cardio',
    group: 'cond',
    parts: 'Heart, lungs and the whole-body engine',
    does: 'Moves oxygen to the muscles. A better engine means faster recovery between sets and better health.',
    tips: [
      'Mix easy zone 2 work (you can still talk) with a little hard interval work.',
      'Low-impact options (bike, rower, sled) spare the joints on lifting weeks.',
      'Do hard cardio after lifting or on separate days so strength work stays fresh.',
    ],
    volume: '150 easy minutes or 75 hard minutes a week',
  ),
};

/// Badge counters per group, in rack order.
const kMuscleGroups = <String, String>{
  'chest': 'Chest',
  'back': 'Back',
  'shoulders': 'Shoulders',
  'arms': 'Arms',
  'legs': 'Legs',
  'core': 'Core',
  'cond': 'Cardio',
};

/// Name for a muscle selection: "Chest & Triceps", "Chest, Back & Arms".
String musclesTitle(List<String> muscles) {
  final n = [for (final m in muscles) tx(kMuscles[m]?.name ?? m)];
  if (n.isEmpty) return tx('Custom');
  if (n.length == 1) return n.first;
  return '${n.sublist(0, n.length - 1).join(', ')} & ${n.last}';
}

/// Four-letter calendar code for a muscle selection: CHES, CHTR, CBSA.
String musclesCode(List<String> muscles) {
  final n = [for (final m in muscles) (kMuscles[m]?.name ?? m).replaceAll(RegExp('[^A-Za-z]'), '').toUpperCase()];
  if (n.isEmpty) return 'MIX';
  if (n.length == 1) return n.first.substring(0, n.first.length < 4 ? n.first.length : 4);
  if (n.length == 2) return n[0].substring(0, 2) + n[1].substring(0, 2);
  return n.take(4).map((x) => x[0]).join();
}
