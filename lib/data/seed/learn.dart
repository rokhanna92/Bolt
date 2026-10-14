// Learn content, ported verbatim from `WHY`, `HOW` and `SUPPS` in Bolt UI.html.

/// Why each workout day exists, by template id.
const kWhy = <String, List<String>>{
  'push': [
    'Groups every muscle that presses away from the body: chest, front shoulders and triceps.',
    'Because the triceps and shoulders already work during bench and overhead press, training them on the same day avoids hitting them again when they are still recovering.',
    'Start with the heaviest compound press while fresh, then move to lighter isolation work.',
  ],
  'pull': [
    'Groups every muscle that pulls toward the body: lats, upper back, rear shoulders and biceps.',
    'Rows and pull-ups already load the biceps and grip, so they get their direct work the same day and rest on push day.',
    'Deadlift goes first because it is the most demanding lift and needs a fresh lower back.',
  ],
  'legs': [
    'Trains quads, hamstrings, glutes and calves together, the biggest muscles in the body.',
    'Leg sessions are the most tiring, so they get their own day and at least 48 hours before being trained again.',
    'A squat pattern and a hinge pattern every session keep the front and back of the legs balanced.',
  ],
  'upper': [
    'Combines push and pull for the whole upper body in one session.',
    'Lets each muscle be trained twice a week on a 4-day plan, which is a good frequency for growth.',
    'Pressing and pulling are paired so the shoulders stay balanced.',
  ],
  'full': [
    'Hits every major muscle group in one session with one exercise each.',
    'Best for beginners and people with 2-3 days a week: each muscle still gets trained 2-3 times weekly.',
    'Low volume per session means less soreness and quicker recovery.',
  ],
  'cond': [
    'Builds heart and lung capacity and work capacity, not maximum strength.',
    'A fitter engine means faster recovery between sets and between sessions.',
    'Short hard intervals with rest give most of the benefit in under 40 minutes.',
  ],
  'mob': [
    'Improves range of motion in hips, spine and shoulders.',
    'Better mobility lets you reach correct positions in squats, presses and hinges, which lowers injury risk.',
    'Used on light days or after injury, it keeps you moving without adding fatigue.',
  ],
};

class HowTo {
  const HowTo(this.muscles, this.cues, this.avoid);

  final String muscles;
  final List<String> cues;

  /// Common mistake.
  final String avoid;
}

/// Exercise form, by exercise name.
const kHow = <String, HowTo>{
  'Bench Press': HowTo('Chest, triceps, front shoulders', [
    'Feet flat, shoulder blades squeezed back and down',
    'Grip just wider than shoulders, wrists stacked over elbows',
    'Lower the bar to the mid chest with elbows about 45° from the body',
    'Press up and slightly back toward the face',
  ], 'Bouncing the bar off the chest or flaring elbows to 90°'),
  'Overhead Press': HowTo('Shoulders, triceps, upper back', [
    'Bar on the front of the shoulders, grip just outside them',
    'Squeeze glutes and brace the core so the lower back does not arch',
    'Press straight up, moving the head back slightly to clear the bar',
    'Finish with the bar over the middle of the foot, head through',
  ], 'Leaning back to turn it into an incline press'),
  'Incline DB Press': HowTo('Upper chest, front shoulders', [
    'Bench at 30°, not steeper',
    'Dumbbells start at chest level, palms slightly turned in',
    'Press up and slightly together without clanking them',
    'Lower slowly until you feel a stretch in the chest',
  ], 'Setting the bench too high so the shoulders take over'),
  'Cable Lateral Raise': HowTo('Side shoulders', [
    'Cable at hand height, stand side-on',
    'Lead with the elbow, slight bend in the arm',
    'Raise to shoulder height, no higher',
    'Lower over 2-3 seconds',
  ], 'Swinging the body or shrugging the shoulders up'),
  'Triceps Pushdown': HowTo('Triceps', [
    'Elbows pinned to your sides',
    'Push down until arms are fully straight',
    'Pause and squeeze at the bottom',
    'Let the handle rise only until forearms pass parallel',
  ], 'Elbows drifting forward so the shoulders help'),
  'Deadlift': HowTo('Hamstrings, glutes, back, grip', [
    'Bar over mid foot, shins almost touching it',
    'Hinge down, grip outside the knees, chest up, back flat',
    'Take the slack out of the bar, then push the floor away',
    'Stand tall with hips through, then hinge back down under control',
  ], 'Rounding the lower back or jerking the bar off the floor'),
  'Pull-up': HowTo('Lats, biceps, upper back', [
    'Hands slightly wider than shoulders, start from a dead hang',
    'Pull shoulder blades down first, then drive elbows to ribs',
    'Chin clears the bar, chest toward it',
    'Lower all the way to straight arms',
  ], 'Kicking or doing half reps'),
  'Barbell Row': HowTo('Upper back, lats, rear shoulders', [
    'Hinge to about 45°, back flat, knees soft',
    'Pull the bar to the lower ribs',
    'Squeeze shoulder blades together at the top',
    'Lower under control without standing up',
  ], 'Standing more upright each rep to use more weight'),
  'Face Pull': HowTo('Rear shoulders, rotator cuff', [
    'Rope at face height, thumbs pointing back',
    'Pull toward the forehead, hands apart',
    'Finish with elbows high and hands beside the ears',
    'Slow return',
  ], 'Going too heavy and turning it into a row'),
  'Hammer Curl': HowTo('Biceps, forearms', [
    'Palms face each other the whole rep',
    'Elbows stay at your sides',
    'Curl up without swinging',
    'Lower slowly to full stretch',
  ], 'Rocking the torso to lift the weight'),
  'Back Squat': HowTo('Quads, glutes, adductors', [
    'Bar on upper back, feet shoulder-width, toes slightly out',
    'Brace the core hard before each rep',
    'Sit down between the hips, knees track over toes',
    'Go as deep as you can with a flat back, then drive up',
  ], 'Knees caving in or heels lifting'),
  'Romanian Deadlift': HowTo('Hamstrings, glutes', [
    'Start standing, soft knees',
    'Push hips back, bar slides down the thighs',
    'Stop when hamstrings are fully stretched, back flat',
    'Drive hips forward to stand',
  ], 'Bending the knees into a squat or rounding the back'),
  'Walking Lunge': HowTo('Quads, glutes', [
    'Long step forward, torso upright',
    'Lower until the back knee nearly touches the floor',
    'Front knee stays over the foot',
    'Push through the front heel into the next step',
  ], 'Short steps that push the knee far past the toes'),
  'Lying Leg Curl': HowTo('Hamstrings', [
    'Pad just above the heels',
    'Hips pressed into the bench',
    'Curl fully, squeeze, then lower slowly',
    'Do not let the weight slam',
  ], 'Hips lifting off the pad'),
  'Standing Calf Raise': HowTo('Calves', [
    'Balls of the feet on the edge',
    'Lower heels for a full stretch',
    'Rise as high as possible and pause',
    'Slow and controlled, no bouncing',
  ], 'Tiny bouncing reps'),
  'Goblet Squat': HowTo('Quads, glutes, core', [
    'Hold the weight at the chest, elbows down',
    'Sit between the knees, chest tall',
    'Elbows brush inside the knees at the bottom',
    'Drive up through the whole foot',
  ], 'Letting the chest fall forward'),
  'Hip Thrust': HowTo('Glutes', [
    'Upper back on the bench edge, bar over the hips',
    'Feet flat, shins vertical at the top',
    'Drive hips up, chin tucked, ribs down',
    'Squeeze glutes for one second at the top',
  ], 'Arching the lower back instead of using the glutes'),
  'Plank': HowTo('Core', [
    'Forearms under shoulders',
    'Body in a straight line from head to heels',
    'Squeeze glutes and pull belly button in',
    'Breathe normally',
  ], 'Hips sagging or piking up'),
  'Kettlebell Swing': HowTo('Glutes, hamstrings, core', [
    'Hike the bell back between the legs like a football snap',
    'Snap the hips forward to float it to chest height',
    'Arms stay loose, the hips do the work',
    'Let it fall back and hinge again',
  ], 'Squatting the swing or lifting with the arms'),
};

class Supplement {
  const Supplement({required this.name, required this.tag, required this.why, required this.how, required this.note});

  final String name;
  final String tag;
  final String why;
  final String how;
  final String note;
}

const kSupplements = <Supplement>[
  Supplement(
    name: 'Creatine monohydrate',
    tag: 'STRONG EVIDENCE',
    why: 'The most researched supplement in sport. It refills the fast energy system used in short heavy efforts, which means a few more reps per set and more strength and muscle over time.',
    how: '3-5 g every day, any time, with water or food. No loading phase needed. Keep taking it on rest days.',
    note: 'Some water weight gain in the first weeks is normal.',
  ),
  Supplement(
    name: 'Protein powder',
    tag: 'STRONG EVIDENCE',
    why: 'Not magic, just a convenient way to reach a daily protein target. Total protein is what builds muscle.',
    how: 'Aim for 1.6-2.2 g of protein per kg of bodyweight per day in total. Use a 25-40 g scoop when food alone falls short, ideally spread over 3-5 meals.',
    note: 'Whey for most people; pea or soy blends if dairy is a problem.',
  ),
  Supplement(
    name: 'Caffeine',
    tag: 'STRONG EVIDENCE',
    why: 'Improves focus, power and endurance, and makes hard sessions feel easier.',
    how: '3 mg per kg of bodyweight about 30-60 minutes before training. Start lower to check tolerance.',
    note: 'Avoid within 8 hours of sleep. Sleep matters more than any supplement.',
  ),
  Supplement(
    name: 'Vitamin D3',
    tag: 'IF LOW',
    why: 'Supports bone, muscle and immune function. Many people are low in winter or with little sun.',
    how: '1000-2000 IU per day with a meal that contains fat. Best to test blood levels first.',
    note: 'More is not better; very high doses can be harmful.',
  ),
  Supplement(
    name: 'Omega-3 (fish oil)',
    tag: 'MODERATE',
    why: 'Supports heart health and may reduce joint soreness. Useful if you eat fish less than twice a week.',
    how: '1-2 g of combined EPA and DHA per day with food.',
    note: 'Check the EPA + DHA amount on the label, not the total oil.',
  ),
  Supplement(
    name: 'Electrolytes',
    tag: 'SITUATIONAL',
    why: 'Replace sodium lost in sweat during long or hot sessions, helping performance and preventing cramps.',
    how: 'Add to water for sessions longer than an hour or when sweating heavily.',
    note: 'Not needed for a normal one-hour session.',
  ),
];
