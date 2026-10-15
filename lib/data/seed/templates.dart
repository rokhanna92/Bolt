// Default workout templates. The first seven are ported verbatim from `TPL`
// in Bolt UI.html.

import 'exercises.dart';

class ExSeed {
  const ExSeed(this.name, this.sets, this.reps, this.load, [this.area, this.alt]);

  final String name;
  final int sets;
  final String reps;
  final String load;
  final String? area;
  final String? alt;
}

class TemplateSeed {
  const TemplateSeed({
    required this.name,
    required this.code,
    required this.focus,
    required this.mins,
    required this.ex,
  });

  final String name;
  final String code;
  final String focus;
  final int mins;
  final List<ExSeed> ex;
}

final kTemplates = <String, TemplateSeed>{
  'push': TemplateSeed(
    name: 'Push',
    code: 'PUSH',
    focus: 'Chest · Shoulders · Triceps',
    mins: 60,
    ex: [
      ExSeed('Bench Press', 4, '6-8', '70 kg', 'shoulder', 'Floor Press'),
      ExSeed('Overhead Press', 3, '8', '40 kg', 'shoulder', 'Landmine Press'),
      ExSeed('Incline DB Press', 3, '10', '24 kg', 'shoulder', 'Machine Chest Press'),
      ExSeed('Cable Lateral Raise', 3, '15', '7.5 kg'),
      ExSeed('Triceps Pushdown', 3, '12', '25 kg', 'elbow', 'Close-grip Push-up'),
    ],
  ),
  'pull': TemplateSeed(
    name: 'Pull',
    code: 'PULL',
    focus: 'Back · Biceps · Rear delts',
    mins: 60,
    ex: [
      ExSeed('Deadlift', 3, '5', '110 kg', 'back', 'Trap Bar Deadlift'),
      ExSeed('Pull-up', 4, '6-8', 'BW', 'shoulder', 'Lat Pulldown'),
      ExSeed('Barbell Row', 3, '8', '60 kg', 'back', 'Chest-supported Row'),
      ExSeed('Face Pull', 3, '15', '20 kg'),
      ExSeed('Hammer Curl', 3, '12', '14 kg', 'elbow', 'Cable Curl'),
    ],
  ),
  'legs': TemplateSeed(
    name: 'Legs',
    code: 'LEGS',
    focus: 'Quads · Hamstrings · Glutes',
    mins: 65,
    ex: [
      ExSeed('Back Squat', 4, '6', '90 kg', 'knee', 'Box Squat'),
      ExSeed('Romanian Deadlift', 3, '8', '80 kg', 'back', 'Hip Thrust'),
      ExSeed('Walking Lunge', 3, '10/leg', '16 kg', 'knee', 'Glute Bridge'),
      ExSeed('Lying Leg Curl', 3, '12', '35 kg'),
      ExSeed('Standing Calf Raise', 4, '15', '60 kg', 'ankle', 'Seated Calf Raise'),
    ],
  ),
  'upper': TemplateSeed(
    name: 'Upper',
    code: 'UPPR',
    focus: 'Push and pull, upper body',
    mins: 60,
    ex: [
      ExSeed('Incline Bench Press', 4, '8', '60 kg', 'shoulder', 'Machine Chest Press'),
      ExSeed('Chest-supported Row', 4, '10', '26 kg'),
      ExSeed('Seated DB Press', 3, '10', '18 kg', 'shoulder', 'Landmine Press'),
      ExSeed('Lat Pulldown', 3, '12', '55 kg'),
      ExSeed('EZ-bar Curl', 2, '12', '25 kg', 'elbow', 'Cable Curl'),
      ExSeed('Overhead Triceps Ext.', 2, '12', '15 kg', 'elbow', 'Triceps Pushdown'),
    ],
  ),
  'full': TemplateSeed(
    name: 'Full Body',
    code: 'FULL',
    focus: 'Compound basics',
    mins: 55,
    ex: [
      ExSeed('Goblet Squat', 3, '10', '24 kg', 'knee', 'Box Squat'),
      ExSeed('DB Bench Press', 3, '10', '26 kg', 'shoulder', 'Push-up'),
      ExSeed('Seated Cable Row', 3, '12', '50 kg'),
      ExSeed('Hip Thrust', 3, '10', '80 kg'),
      ExSeed('Plank', 3, '45 s', 'BW', 'back', 'Dead Bug'),
    ],
  ),
  'cond': TemplateSeed(
    name: 'Conditioning',
    code: 'COND',
    focus: 'Engine · Work capacity',
    mins: 40,
    ex: [
      ExSeed('Rower Intervals', 6, '250 m', '—'),
      ExSeed('Kettlebell Swing', 4, '15', '24 kg', 'back', 'Banded Hip Hinge'),
      ExSeed('Sled Push', 5, '20 m', '+80 kg', 'knee', 'Bike Sprint'),
      ExSeed('Farmer Carry', 4, '40 m', '2×28 kg', 'wrist', 'Trap Bar Carry'),
      ExSeed('Assault Bike', 5, '30 s', '—'),
    ],
  ),
  'mob': TemplateSeed(
    name: 'Mobility',
    code: 'MOB',
    focus: 'Recovery · Range of motion',
    mins: 35,
    ex: [
      ExSeed('Cat-Cow', 2, '10', '—'),
      ExSeed("World's Greatest Stretch", 2, '5/side', '—'),
      ExSeed('90/90 Hip Switch', 3, '8', '—'),
      ExSeed('Thoracic Rotation', 2, '8/side', '—'),
      ExSeed('Couch Stretch', 2, '60 s', '—', 'knee', 'Lying Quad Stretch'),
    ],
  ),
  'chtri': TemplateSeed(
    name: 'Chest & Triceps',
    code: 'CHTR',
    focus: 'Chest · Triceps · Old school',
    mins: 70,
    ex: [
      _x('Bench Press', 4, '6-8', '70 kg'),
      _x('Incline DB Press', 3, '8-10', '24 kg'),
      _x('Chest Dip', 3, '8-10', 'BW'),
      _x('DB Flye', 3, '12', '14 kg'),
      _x('Skull Crusher', 3, '10', '25 kg'),
      _x('Rope Pushdown', 3, '12-15', '20 kg'),
    ],
  ),
  'bish': TemplateSeed(
    name: 'Biceps & Shoulders',
    code: 'BISH',
    focus: 'Shoulders · Biceps · Old school',
    mins: 65,
    ex: [
      _x('Overhead Press', 4, '6-8', '40 kg'),
      _x('DB Lateral Raise', 4, '12-15', '10 kg'),
      _x('Rear Delt Flye', 3, '15', '8 kg'),
      _x('Barbell Curl', 4, '8-10', '30 kg'),
      _x('Incline DB Curl', 3, '10', '10 kg'),
      _x('Hammer Curl', 3, '12', '14 kg'),
    ],
  ),
  'back': TemplateSeed(
    name: 'Back',
    code: 'BACK',
    focus: 'Width · Thickness · Traps',
    mins: 65,
    ex: [
      _x('Deadlift', 3, '5', '110 kg'),
      _x('Pull-up', 4, '6-8', 'BW'),
      _x('T-bar Row', 3, '8-10', '40 kg'),
      _x('One-arm DB Row', 3, '10', '30 kg'),
      _x('Straight-arm Pulldown', 3, '12-15', '25 kg'),
      _x('Barbell Shrug', 3, '12', '100 kg'),
    ],
  ),
  'chest': TemplateSeed(
    name: 'Chest',
    code: 'CHST',
    focus: 'Upper · Middle · Lower chest',
    mins: 55,
    ex: [
      _x('Bench Press', 4, '6-8', '70 kg'),
      _x('Incline DB Press', 3, '8-10', '24 kg'),
      _x('Chest Dip', 3, '8-10', 'BW'),
      _x('Cable Crossover', 3, '15', '15 kg'),
      _x('DB Pullover', 3, '12', '20 kg'),
    ],
  ),
  'shoul': TemplateSeed(
    name: 'Shoulders',
    code: 'SHLD',
    focus: 'Front · Side · Rear delts · Traps',
    mins: 55,
    ex: [
      _x('Seated DB Press', 4, '8-10', '20 kg'),
      _x('Arnold Press', 3, '10', '16 kg'),
      _x('DB Lateral Raise', 4, '12-15', '10 kg'),
      _x('Reverse Pec Deck', 3, '15', '35 kg'),
      _x('Face Pull', 3, '15', '20 kg'),
      _x('DB Shrug', 3, '15', '30 kg'),
    ],
  ),
  'arms': TemplateSeed(
    name: 'Arms',
    code: 'ARMS',
    focus: 'Biceps · Triceps · Forearms',
    mins: 55,
    ex: [
      _x('Close-grip Bench Press', 3, '8', '60 kg'),
      _x('Barbell Curl', 3, '8-10', '30 kg'),
      _x('Skull Crusher', 3, '10', '25 kg'),
      _x('Preacher Curl', 3, '10', '25 kg'),
      _x('Rope Pushdown', 3, '15', '20 kg'),
      _x('Hammer Curl', 3, '12', '14 kg'),
      _x('Wrist Curl', 2, '15', '20 kg'),
    ],
  ),
  'backbi': TemplateSeed(
    name: 'Back & Biceps',
    code: 'BKBI',
    focus: 'Lats · Upper back · Biceps',
    mins: 65,
    ex: [
      _x('Pull-up', 4, '6-8', 'BW'),
      _x('Barbell Row', 4, '8', '60 kg'),
      _x('Lat Pulldown', 3, '10-12', '55 kg'),
      _x('Seated Cable Row', 3, '12', '50 kg'),
      _x('Barbell Curl', 3, '8-10', '30 kg'),
      _x('Hammer Curl', 3, '12', '14 kg'),
    ],
  ),
  'chback': TemplateSeed(
    name: 'Chest & Back',
    code: 'CHBK',
    focus: 'Arnold style · Push and pull supersets',
    mins: 75,
    ex: [
      _x('Bench Press', 4, '8', '70 kg'),
      _x('Pull-up', 4, '8', 'BW'),
      _x('Incline DB Press', 3, '10', '24 kg'),
      _x('T-bar Row', 3, '10', '40 kg'),
      _x('DB Flye', 3, '12', '14 kg'),
      _x('DB Pullover', 3, '12', '20 kg'),
    ],
  ),
  'sharm': TemplateSeed(
    name: 'Shoulders & Arms',
    code: 'SHAR',
    focus: 'Arnold style · Delts · Biceps · Triceps',
    mins: 70,
    ex: [
      _x('Arnold Press', 4, '10', '16 kg'),
      _x('DB Lateral Raise', 4, '12', '10 kg'),
      _x('Barbell Curl', 3, '8-10', '30 kg'),
      _x('Skull Crusher', 3, '10', '25 kg'),
      _x('Concentration Curl', 3, '12', '12 kg'),
      _x('Overhead Triceps Ext.', 3, '12', '15 kg'),
      _x('Rear Delt Flye', 3, '15', '8 kg'),
    ],
  ),
  'hit': TemplateSeed(
    name: 'Heavy Duty',
    code: 'HIT',
    focus: 'Mentzer style · One all-out set each',
    mins: 40,
    ex: [
      _x('Pec Deck', 1, '6-10', '40 kg'),
      _x('Incline Bench Press', 1, '6-10', '60 kg'),
      _x('DB Pullover', 1, '8-12', '20 kg'),
      _x('Lat Pulldown', 1, '6-10', '55 kg'),
      _x('Leg Extension', 1, '8-12', '45 kg'),
      _x('Leg Press', 1, '8-12', '160 kg'),
      _x('Deadlift', 1, '5-8', '110 kg'),
    ],
  ),
  'glutes': TemplateSeed(
    name: 'Glutes & Hamstrings',
    code: 'GLUT',
    focus: 'Glutes · Hamstrings · Hips',
    mins: 60,
    ex: [
      _x('Hip Thrust', 4, '8-10', '100 kg'),
      _x('Romanian Deadlift', 3, '8', '80 kg'),
      _x('Bulgarian Split Squat', 3, '8/leg', '16 kg'),
      _x('Seated Leg Curl', 3, '12', '40 kg'),
      _x('Cable Kickback', 3, '12/leg', '15 kg'),
      _x('Hip Abduction', 3, '15', '50 kg'),
    ],
  ),
  'core': TemplateSeed(
    name: 'Abs & Core',
    code: 'CORE',
    focus: 'Abs · Obliques · Deep core',
    mins: 30,
    ex: [
      _x('Hanging Leg Raise', 3, '10-12', 'BW'),
      _x('Cable Crunch', 3, '15', '40 kg'),
      _x('Ab Wheel Rollout', 3, '10', 'BW'),
      _x('Pallof Press', 3, '12/side', '15 kg'),
      _x('Side Plank', 3, '30 s/side', 'BW'),
      _x('Stomach Vacuum', 3, '20 s', 'BW'),
    ],
  ),
  'str5a': TemplateSeed(
    name: 'Strength A',
    code: 'STRA',
    focus: '5×5 · Squat · Bench · Row',
    mins: 60,
    ex: [_x('Back Squat', 5, '5', '90 kg'), _x('Bench Press', 5, '5', '70 kg'), _x('Barbell Row', 5, '5', '60 kg')],
  ),
  'str5b': TemplateSeed(
    name: 'Strength B',
    code: 'STRB',
    focus: '5×5 · Squat · Press · Deadlift',
    mins: 60,
    ex: [_x('Back Squat', 5, '5', '90 kg'), _x('Overhead Press', 5, '5', '40 kg'), _x('Deadlift', 1, '5', '120 kg')],
  ),
  'calis': TemplateSeed(
    name: 'Calisthenics',
    code: 'CALI',
    focus: 'Bodyweight · Train anywhere',
    mins: 45,
    ex: [
      _x('Pull-up', 4, '6-10', 'BW'),
      _x('Push-up', 4, '15-20', 'BW'),
      _x('Triceps Dip', 3, '10', 'BW'),
      _x('Pistol Squat', 3, '5/leg', 'BW'),
      _x('Inverted Row', 3, '10', 'BW'),
      _x('Hanging Leg Raise', 3, '10', 'BW'),
    ],
  ),
  'home': TemplateSeed(
    name: 'Home Dumbbell',
    code: 'HOME',
    focus: 'Two dumbbells · Full body',
    mins: 45,
    ex: [
      _x('Goblet Squat', 4, '12', '24 kg'),
      _x('DB Bench Press', 3, '10', '26 kg'),
      _x('One-arm DB Row', 3, '10', '30 kg'),
      _x('Seated DB Press', 3, '10', '18 kg'),
      _x('Single-leg RDL', 3, '8/leg', '16 kg'),
      _x('Hammer Curl', 2, '12', '14 kg'),
    ],
  ),
  'hiit': TemplateSeed(
    name: 'HIIT Circuit',
    code: 'HIIT',
    focus: 'Intervals · Fat loss · Engine',
    mins: 30,
    ex: [
      _x('Burpee', 4, '10', 'BW'),
      _x('Kettlebell Swing', 4, '15', '24 kg'),
      _x('Mountain Climber', 4, '30 s', 'BW'),
      _x('Box Jump', 4, '5', 'BW'),
      _x('Battle Ropes', 4, '30 s', '—'),
    ],
  ),
  'zone2': TemplateSeed(
    name: 'Zone 2 Cardio',
    code: 'ZON2',
    focus: 'Easy steady cardio · Recovery',
    mins: 45,
    ex: [_x('Zone 2 Bike', 1, '30 min', '—'), _x('Incline Walk', 1, '15 min', '—')],
  ),
};

/// A template line with the injury area and swap from the exercise database.
ExSeed _x(String name, int sets, String reps, String load) {
  final e = kExerciseByName[name]!;
  return ExSeed(name, sets, reps, load, e.area, e.alt);
}

/// How the workout picker groups the built-in templates. Custom templates
/// are listed after these.
const kTemplateGroups = <(String, List<String>)>[
  ('Classic', ['push', 'pull', 'legs', 'upper', 'full']),
  ('Old school bodybuilding', ['chtri', 'bish', 'backbi', 'chback', 'sharm', 'hit']),
  ('One muscle a day', ['chest', 'back', 'shoul', 'arms', 'legs', 'glutes', 'core']),
  ('Strength', ['str5a', 'str5b']),
  ('Bodyweight & home', ['calis', 'home']),
  ('Engine & recovery', ['cond', 'hiit', 'zone2', 'mob']),
];

/// Every exercise Bolt knows, sorted by name, for the exercise picker.
final List<ExSeed> kAllExercises = [for (final e in kExercises) ExSeed(e.name, e.sets, e.reps, e.load, e.area, e.alt)]
  ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

const kAreas = <String, String>{
  'knee': 'Knee',
  'back': 'Lower back',
  'shoulder': 'Shoulder',
  'elbow': 'Elbow',
  'wrist': 'Wrist',
  'ankle': 'Ankle',
};
