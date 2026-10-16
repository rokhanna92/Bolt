// Moving outside the weights: walking, incline walking, cycling, running and
// stretching, why each helps and how to start. The numbers come from large
// studies of many people; they show links, not guarantees.

class MoveTopic {
  const MoveTopic({required this.name, required this.tag, required this.why, required this.how, required this.source});

  final String name;
  final String tag;
  final List<String> why;
  final List<String> how;

  /// Where the numbers come from.
  final String source;
}

const kMove = <MoveTopic>[
  MoveTopic(
    name: 'Walking',
    tag: 'Every day',
    why: [
      'Every extra 1,000 steps a day was linked to about 15% lower risk of dying early, in a review of 17 studies and 226,000 people.',
      'It starts early: lower risk from about 4,000 steps a day for early death and about 2,300 for heart disease.',
      'Compared with 2,000 steps a day, people at 7,000 had about half the risk of dying early, 38% lower risk of dementia and 22% fewer signs of depression.',
      'Walking burns calories without eating into your recovery, so it helps fat loss while you lift.',
    ],
    how: [
      'See where your normal day is, then add about 1,000 steps a day each week.',
      '7,000-10,000 steps a day is a strong target. More still helps.',
      'Split it up: a 10-minute walk after each meal is about 3,000 steps.',
    ],
    source:
        'Banach et al., European Journal of Preventive Cardiology 2023. Ding et al., The Lancet Public Health 2025.',
  ),
  MoveTopic(
    name: 'Incline walking',
    tag: 'Low impact cardio',
    why: [
      'Walking uphill gets your heart rate close to running, with far less pounding on knees and hips.',
      'In one treadmill study, 30 minutes at 12% incline burned about as much as 24 minutes of running, and more of it came from fat.',
      'A good pick for heavier lifters, for rest days and for joints that do not like running.',
    ],
    how: [
      'Start at 5-8% incline and 4.5-5 km/h for 15-20 minutes.',
      'Build to 10-15% for 30 minutes. Hands off the rails: holding on takes away the work.',
      'After lifting or on rest days, 2-4 times a week.',
    ],
    source: 'Treadmill studies comparing incline walking and running, 2024.',
  ),
  MoveTopic(
    name: 'Cycling',
    tag: 'Heart and legs',
    why: [
      'People who cycled to work had about 41% lower risk of dying early and about half the risk of dying from heart disease, in a UK study of 263,000 adults.',
      'No impact on the joints, so you add cardio without beating up the knees you squat with.',
      'Easy rides help recovery by moving blood through tired legs.',
    ],
    how: [
      'Easy: 20-45 minutes at a pace where you can still talk.',
      'Hard: 6-10 rounds of 30 seconds fast and 90 seconds easy. Keep these away from leg day.',
      'Riding to the gym is your warm-up and cardio in one.',
    ],
    source: 'Celis-Morales et al., BMJ 2017.',
  ),
  MoveTopic(
    name: 'Running',
    tag: 'Most return per minute',
    why: [
      'Runners had 27% lower risk of dying early than people who did not run, across 14 studies and 232,000 people.',
      'Even once a week for 50 minutes or less was linked to the benefit. Running a lot more did not clearly add more.',
      'It builds your heart and lungs fast, so you recover quicker between sets.',
    ],
    how: [
      'New to it: 1 minute running, 2 minutes walking, for 20 minutes.',
      'Keep most runs easy enough to talk. One faster run a week is plenty.',
      'Running is harder on the joints than walking. Add distance slowly, about 10% a week.',
    ],
    source: 'Pedisic et al., British Journal of Sports Medicine 2020.',
  ),
  MoveTopic(
    name: 'Stretching',
    tag: 'Range of motion',
    why: [
      'Regular stretching lets your joints move further, so squats get deeper and presses feel smoother.',
      'Short holds, under 60 seconds per muscle inside a warm-up, barely touch your strength. Long holds right before heavy sets can cost some force.',
      'Lifting through a full range of motion also improves flexibility, so good reps count as mobility work too.',
    ],
    how: [
      'Before lifting: moving stretches like leg swings, arm circles and lunges with a twist.',
      'After lifting or on rest days: hold each stretch 30-60 seconds, 2-3 times.',
      'Hips, hamstrings, chest and upper back are the usual tight spots for lifters.',
    ],
    source: 'Reviews by Behm and colleagues on stretching and performance, 2016-2024.',
  ),
];
