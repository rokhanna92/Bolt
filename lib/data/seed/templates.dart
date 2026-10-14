// Default workout templates, ported verbatim from `TPL` in Bolt UI.html.

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

const kTemplates = <String, TemplateSeed>{
  'push': TemplateSeed(name: 'Push', code: 'PUSH', focus: 'Chest · Shoulders · Triceps', mins: 60, ex: [
    ExSeed('Bench Press', 4, '6-8', '70 kg', 'shoulder', 'Floor Press'),
    ExSeed('Overhead Press', 3, '8', '40 kg', 'shoulder', 'Landmine Press'),
    ExSeed('Incline DB Press', 3, '10', '24 kg', 'shoulder', 'Machine Chest Press'),
    ExSeed('Cable Lateral Raise', 3, '15', '7.5 kg'),
    ExSeed('Triceps Pushdown', 3, '12', '25 kg', 'elbow', 'Close-grip Push-up'),
  ]),
  'pull': TemplateSeed(name: 'Pull', code: 'PULL', focus: 'Back · Biceps · Rear delts', mins: 60, ex: [
    ExSeed('Deadlift', 3, '5', '110 kg', 'back', 'Trap Bar Deadlift'),
    ExSeed('Pull-up', 4, '6-8', 'BW', 'shoulder', 'Lat Pulldown'),
    ExSeed('Barbell Row', 3, '8', '60 kg', 'back', 'Chest-supported Row'),
    ExSeed('Face Pull', 3, '15', '20 kg'),
    ExSeed('Hammer Curl', 3, '12', '14 kg', 'elbow', 'Cable Curl'),
  ]),
  'legs': TemplateSeed(name: 'Legs', code: 'LEGS', focus: 'Quads · Hamstrings · Glutes', mins: 65, ex: [
    ExSeed('Back Squat', 4, '6', '90 kg', 'knee', 'Box Squat'),
    ExSeed('Romanian Deadlift', 3, '8', '80 kg', 'back', 'Hip Thrust'),
    ExSeed('Walking Lunge', 3, '10/leg', '16 kg', 'knee', 'Glute Bridge'),
    ExSeed('Lying Leg Curl', 3, '12', '35 kg'),
    ExSeed('Standing Calf Raise', 4, '15', '60 kg', 'ankle', 'Seated Calf Raise'),
  ]),
  'upper': TemplateSeed(name: 'Upper', code: 'UPPR', focus: 'Push and pull, upper body', mins: 60, ex: [
    ExSeed('Incline Bench Press', 4, '8', '60 kg', 'shoulder', 'Machine Chest Press'),
    ExSeed('Chest-supported Row', 4, '10', '26 kg'),
    ExSeed('Seated DB Press', 3, '10', '18 kg', 'shoulder', 'Landmine Press'),
    ExSeed('Lat Pulldown', 3, '12', '55 kg'),
    ExSeed('EZ-bar Curl', 2, '12', '25 kg', 'elbow', 'Cable Curl'),
    ExSeed('Overhead Triceps Ext.', 2, '12', '15 kg', 'elbow', 'Triceps Pushdown'),
  ]),
  'full': TemplateSeed(name: 'Full Body', code: 'FULL', focus: 'Compound basics', mins: 55, ex: [
    ExSeed('Goblet Squat', 3, '10', '24 kg', 'knee', 'Box Squat'),
    ExSeed('DB Bench Press', 3, '10', '26 kg', 'shoulder', 'Push-up'),
    ExSeed('Seated Cable Row', 3, '12', '50 kg'),
    ExSeed('Hip Thrust', 3, '10', '80 kg'),
    ExSeed('Plank', 3, '45 s', 'BW', 'back', 'Dead Bug'),
  ]),
  'cond': TemplateSeed(name: 'Conditioning', code: 'COND', focus: 'Engine · Work capacity', mins: 40, ex: [
    ExSeed('Rower Intervals', 6, '250 m', '—'),
    ExSeed('Kettlebell Swing', 4, '15', '24 kg', 'back', 'Banded Hip Hinge'),
    ExSeed('Sled Push', 5, '20 m', '+80 kg', 'knee', 'Bike Sprint'),
    ExSeed('Farmer Carry', 4, '40 m', '2×28 kg', 'wrist', 'Trap Bar Carry'),
    ExSeed('Assault Bike', 5, '30 s', '—'),
  ]),
  'mob': TemplateSeed(name: 'Mobility', code: 'MOB', focus: 'Recovery · Range of motion', mins: 35, ex: [
    ExSeed('Cat-Cow', 2, '10', '—'),
    ExSeed("World's Greatest Stretch", 2, '5/side', '—'),
    ExSeed('90/90 Hip Switch', 3, '8', '—'),
    ExSeed('Thoracic Rotation', 2, '8/side', '—'),
    ExSeed('Couch Stretch', 2, '60 s', '—', 'knee', 'Lying Quad Stretch'),
  ]),
};

/// Every distinct exercise across the templates, sorted by name, for the
/// exercise picker (`ALL_EX`).
final List<ExSeed> kAllExercises = () {
  final seen = <String>{};
  final out = <ExSeed>[];
  for (final t in kTemplates.values) {
    for (final e in t.ex) {
      if (seen.add(e.name)) out.add(e);
    }
  }
  out.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  return out;
}();

const kAreas = <String, String>{
  'knee': 'Knee',
  'back': 'Lower back',
  'shoulder': 'Shoulder',
  'elbow': 'Elbow',
  'wrist': 'Wrist',
  'ankle': 'Ankle',
};
