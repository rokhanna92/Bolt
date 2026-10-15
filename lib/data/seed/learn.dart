// Learn content. The first workouts, exercises and supplements are ported
// verbatim from `WHY`, `HOW` and `SUPPS` in Bolt UI.html.

import 'exercises.dart';

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
  'chtri': [
    'The old school pairing: chest presses already tire the triceps, so they get finished off the same day.',
    'Heavy flat and incline pressing first, dips and flyes for stretch, then two triceps moves to fill the sleeves.',
    'A full week before chest comes around again gives plenty of recovery for a high-volume session.',
  ],
  'bish': [
    'Shoulders and biceps on one day leaves chest and triceps fully rested from the day before.',
    'Overhead pressing first while fresh, then side and rear delts for width, then curls from three angles.',
    'A favourite of golden era lifters who wanted round delts and peaked arms.',
  ],
  'back': [
    'A whole session for the back: deadlifts for thickness, pull-ups for width, rows for detail.',
    'Giving the back its own day lets you go heavy on deadlifts without them ruining a leg day.',
    'Shrugs at the end build the traps that frame the back and neck.',
  ],
  'chest': [
    'One muscle, all your energy: flat, incline and dips cover every part of the chest.',
    'Flyes and pullovers add the deep stretch that presses alone miss.',
    'Classic Monday session on a five-day bro split.',
  ],
  'shoul': [
    'Presses for mass, lateral raises for width, rear delts and face pulls for balance and healthy shoulders.',
    'Wide side delts make the waist look smaller: the V-taper every golden era physique chased.',
    'Shrugs finish the session for the upper traps.',
  ],
  'arms': [
    'Biceps and triceps alternate so one rests while the other works, which keeps the pump going.',
    'Heavy close-grip bench and barbell curls first, isolation and forearms after.',
    'Triceps are two thirds of the upper arm, so they get as much work as the biceps.',
  ],
  'backbi': [
    'Every row and pull-up works the biceps, so finishing them the same day makes sense.',
    'Vertical pulls for width and horizontal rows for thickness, then two curl variations.',
    'Pairs with Chest & Triceps for the most common gym split in the world.',
  ],
  'chback': [
    'Arnold\'s pairing: chest and back are opposite muscles, so you can superset a press with a pull.',
    'While one muscle works the other rests, which saves time and builds a huge pump through the whole torso.',
    'Demanding, high-volume work. Eat and sleep well when you run it twice a week.',
  ],
  'sharm': [
    'Arnold\'s second day: delts, biceps and triceps in one session, often supersetting curls with triceps work.',
    'Arms get trained hard twice a week on the Arnold split, which is how the golden era built 20-inch arms.',
    'Keep strict form on the raises, save the heavy weight for presses and curls.',
  ],
  'hit': [
    'Mike Mentzer\'s Heavy Duty idea: one all-out set per exercise after a warm-up, taken to complete failure.',
    'Very short sessions, lots of recovery. Quality of effort beats number of sets.',
    'Only works if every set really goes to failure with perfect form. Use a spotter on presses.',
  ],
  'glutes': [
    'Hip thrusts load the glutes at full hip extension, RDLs and split squats at the stretch.',
    'Hamstrings get both jobs: hip hinge and knee curl.',
    'Abduction work trains the side glutes that keep knees and hips stable.',
  ],
  'core': [
    'Covers all three jobs of the core: bending, resisting bending and resisting rotation.',
    'Short session you can add after any workout or on a rest day.',
    'The stomach vacuum is a golden era trick for a tight, narrow waist.',
  ],
  'str5a': [
    'Five sets of five on the big lifts: heavy enough to build strength, enough reps to build muscle.',
    'Reg Park made 5×5 famous in the 1950s and Arnold trained it as a teenager.',
    'Add a little weight every session while all 25 reps are clean.',
  ],
  'str5b': [
    'Alternates with Strength A so squats happen every session and the other lifts every other one.',
    'One heavy deadlift set is enough after five sets of squats.',
    'Simple, measurable and brutally effective for beginners and returning lifters.',
  ],
  'calis': [
    'Bodyweight only: pull-ups, push-ups, dips and pistols build real strength and control.',
    'Make it harder with slower reps, pauses, harder variations or a weight vest.',
    'Train anywhere: park, home or hotel.',
  ],
  'home': [
    'Everything you need with two dumbbells and a bench or floor.',
    'Covers squat, hinge, push, pull and press in under an hour.',
    'Raise reps or slow down the lowering when the dumbbells get too light.',
  ],
  'hiit': [
    'Short, hard intervals that push heart rate up and burn a lot of energy in 30 minutes.',
    'Builds conditioning without long boring cardio sessions.',
    'Keep it to 1-2 times a week so it does not eat into recovery for lifting.',
  ],
  'zone2': [
    'Easy cardio where you can still talk. It builds the aerobic base that helps you recover between sets.',
    'Good for heart health, fat burning and a light day between heavy sessions.',
    'Does not cut into strength gains the way hard cardio can.',
  ],
};

class HowTo {
  const HowTo(this.muscles, this.cues, this.avoid);

  final String muscles;
  final List<String> cues;

  /// Common mistake.
  final String avoid;
}

/// Exercise form, by exercise name, from the exercise database.
final Map<String, HowTo> kHow = {for (final e in kExercises) e.name: HowTo(e.works, e.cues, e.avoid)};

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
  Supplement(
    name: 'Beta-alanine',
    tag: 'STRONG EVIDENCE',
    why: 'Raises carnosine in muscle, which buffers the burn in hard efforts lasting about 1-4 minutes. Useful for high-rep sets, circuits and HIIT.',
    how: '3.2-6.4 g per day split into doses of 0.8-1.6 g with meals. It works by building up over 4+ weeks, so timing around training does not matter.',
    note: 'The tingling skin feeling is harmless. Smaller split doses or slow-release versions reduce it.',
  ),
  Supplement(
    name: 'Sodium bicarbonate',
    tag: 'STRONG EVIDENCE',
    why: 'Baking soda buffers acid in the blood and helps repeated all-out efforts of 1-7 minutes, like rowing intervals or sprint circuits.',
    how: '0.2-0.3 g per kg of bodyweight 60-180 minutes before, with a carb-rich meal and plenty of water.',
    note: 'Stomach upset is common. Try it on a training day, never first time before a competition. Avoid with high blood pressure or on a low-salt diet.',
  ),
  Supplement(
    name: 'Ashwagandha',
    tag: 'MODERATE',
    why: 'An Ayurvedic herb (an adaptogen). Studies on root extracts show lower stress and cortisol, better sleep and small gains in strength and recovery.',
    how: '300-600 mg per day of a standardised root extract (e.g. KSM-66), with food. Effects build over 4-8 weeks. Many people take it in the evening.',
    note: 'Avoid when pregnant, with thyroid or autoimmune conditions, or with sedatives. Rare cases of liver problems are reported: stop if you notice dark urine or yellow skin.',
  ),
  Supplement(
    name: 'Guarana',
    tag: 'MODERATE',
    why: 'A seed from the Amazon with roughly two to four times the caffeine of coffee beans by weight. The energy and focus boost is mostly that caffeine. Common in energy drinks and pre-workouts.',
    how: 'Dose it by its caffeine content and count it toward the same 3 mg per kg limit as coffee, 30-60 minutes before training.',
    note: 'Easy to double up without noticing: coffee + guarana + pre-workout adds up fast. Same rule as caffeine: none within 8 hours of sleep.',
  ),
  Supplement(
    name: 'Citrulline malate',
    tag: 'MODERATE',
    why: 'Raises nitric oxide, which widens blood vessels. It can mean a bigger pump and a few more reps on high-rep sets.',
    how: '6-8 g of citrulline malate (or 3-5 g pure L-citrulline) 30-60 minutes before training.',
    note: 'Research is mixed; some people feel a clear difference, others none.',
  ),
  Supplement(
    name: 'Beetroot juice (nitrate)',
    tag: 'MODERATE',
    why: 'Dietary nitrate turns into nitric oxide and makes muscles use oxygen more efficiently. Best for endurance and repeated sprints.',
    how: '300-600 mg of nitrate (about 500 ml of beet juice or one concentrated shot) 2-3 hours before.',
    note: 'Pink urine afterwards is harmless. Antibacterial mouthwash blocks the effect.',
  ),
  Supplement(
    name: 'L-theanine',
    tag: 'MODERATE',
    why: 'An amino acid from tea that calms without making you sleepy. Paired with caffeine it gives smoother focus with fewer jitters.',
    how: '100-200 mg together with your caffeine, roughly 2 parts theanine to 1 part caffeine.',
    note: 'Safe for most people. On its own it is relaxing rather than energising.',
  ),
  Supplement(
    name: 'Collagen + vitamin C',
    tag: 'EMERGING',
    why: 'Early research suggests gelatin or collagen with vitamin C before training helps the body build tendon and ligament collagen.',
    how: '10-15 g of gelatin or collagen with about 50 mg of vitamin C, 30-60 minutes before training or rehab exercises.',
    note: 'Not a muscle builder: it is a poor protein source. Think of it as joint and tendon support.',
  ),
  Supplement(
    name: 'Magnesium',
    tag: 'IF LOW',
    why: 'Needed for muscle contraction, nerves and sleep. Many people fall short, especially if they sweat a lot.',
    how: '200-400 mg per day as glycinate or citrate, often in the evening.',
    note: 'Magnesium oxide is poorly absorbed. High doses loosen the stool. Check with a doctor if you have kidney disease.',
  ),
  Supplement(
    name: 'Zinc',
    tag: 'IF LOW',
    why: 'Supports immunity, healing and hormones. It only helps testosterone if you are actually low, which can happen with heavy sweating or little meat.',
    how: '10-25 mg per day with food.',
    note: 'Over 40 mg a day for long periods drains copper. Take it away from iron and calcium.',
  ),
  Supplement(
    name: 'Iron',
    tag: 'IF LOW',
    why: 'Carries oxygen in the blood. Low iron means tiredness and poor endurance. Common in women, vegetarians and endurance athletes.',
    how: 'Only after a blood test shows you are low. Take with vitamin C, away from coffee, tea and calcium.',
    note: 'Too much iron is toxic. Never supplement it just in case.',
  ),
  Supplement(
    name: 'Casein protein',
    tag: 'SITUATIONAL',
    why: 'A slow-digesting milk protein that releases amino acids over several hours.',
    how: '30-40 g before bed if you struggle to reach your daily protein target.',
    note: 'Total daily protein matters far more than which protein you take before bed.',
  ),
  Supplement(
    name: 'Essential amino acids (EAA)',
    tag: 'SITUATIONAL',
    why: 'The amino acids your body cannot make. Useful when a full protein meal is not practical, or for plant-based diets low in leucine.',
    how: '10-15 g around training.',
    note: 'If you already eat enough protein, they add little. Whey contains all of them.',
  ),
  Supplement(
    name: 'Pre-workout blends',
    tag: 'SITUATIONAL',
    why: 'Mostly caffeine plus citrulline and beta-alanine. Can give a real energy and focus boost if the doses are right.',
    how: 'Read the label: check the caffeine per scoop and avoid proprietary blends that hide the amounts. Start with half a scoop.',
    note: 'Count it toward your daily caffeine. Do not take it late in the day.',
  ),
  Supplement(
    name: 'Multivitamin',
    tag: 'SITUATIONAL',
    why: 'Insurance for a diet that is low in fruit, vegetables or variety. It does not boost performance on its own.',
    how: 'One a day with a meal.',
    note: 'Food first. Megadose formulas are not better.',
  ),
  Supplement(
    name: 'Melatonin',
    tag: 'SITUATIONAL',
    why: 'A hormone that signals night time. Helps with jet lag and shift work, less so for everyday sleep.',
    how: '0.5-3 mg 30-60 minutes before bed, short term.',
    note: 'Prescription-only in some countries. Fix light, caffeine and screen habits first.',
  ),
  Supplement(
    name: 'Mass gainer',
    tag: 'SITUATIONAL',
    why: 'A shake of carbs and protein for people who struggle to eat enough to gain weight.',
    how: 'One serving between meals. A homemade one of oats, whey, milk and peanut butter works the same and costs less.',
    note: 'Many are mostly sugar. Only useful if you really cannot eat more food.',
  ),
  Supplement(
    name: 'Electrolyte tablets with caffeine',
    tag: 'SITUATIONAL',
    why: 'Some electrolyte tablets add caffeine for long sessions in the heat.',
    how: 'Use during sessions longer than 90 minutes or in hot weather.',
    note: 'Count the caffeine. Plain electrolytes are enough for most sessions.',
  ),
  Supplement(
    name: 'Taurine',
    tag: 'WEAK',
    why: 'An amino acid found in energy drinks. It may slightly help endurance and muscle function.',
    how: '1-3 g per day.',
    note: 'Very safe, the effects are just small.',
  ),
  Supplement(
    name: 'Rhodiola rosea',
    tag: 'WEAK',
    why: 'An adaptogen herb that may reduce mental fatigue during stressful periods.',
    how: '200-600 mg of a standardised extract in the morning.',
    note: 'Can feel stimulating; avoid in the evening.',
  ),
  Supplement(
    name: 'Tongkat ali',
    tag: 'WEAK',
    why: 'A Southeast Asian herb. Small studies show modest improvements in testosterone and stress in men who are stressed or low.',
    how: '200-400 mg per day of a standardised extract.',
    note: 'Product quality varies a lot; buy third-party tested. Not for under 18s.',
  ),
  Supplement(
    name: 'Fenugreek',
    tag: 'WEAK',
    why: 'A seed extract marketed for testosterone. Some small studies show a slight libido and strength benefit, but no clear hormone boost.',
    how: '500-600 mg of extract per day.',
    note: 'Can make sweat smell like maple syrup.',
  ),
  Supplement(
    name: 'Shilajit',
    tag: 'WEAK',
    why: 'A mineral resin from mountain rocks, rich in fulvic acid. Small studies suggest energy and testosterone benefits.',
    how: '250-500 mg per day of a purified product.',
    note: 'Raw or untested shilajit can contain heavy metals. Only buy lab-tested brands.',
  ),
  Supplement(
    name: 'Panax ginseng',
    tag: 'WEAK',
    why: 'A traditional root used for energy and mental focus.',
    how: '200-400 mg of extract per day.',
    note: 'Can interact with blood thinners and diabetes medication.',
  ),
  Supplement(
    name: 'Maca',
    tag: 'WEAK',
    why: 'A Peruvian root used for libido and energy. It does not affect muscle or hormones in studies.',
    how: '1.5-3 g of powder per day.',
    note: 'Harmless for most, just do not expect muscle gains.',
  ),
  Supplement(
    name: 'Cordyceps',
    tag: 'WEAK',
    why: 'A mushroom said to boost endurance. A few small studies show minor improvements in oxygen use.',
    how: '1-3 g per day.',
    note: 'Evidence is thin; quality varies.',
  ),
  Supplement(
    name: 'Curcumin (turmeric)',
    tag: 'WEAK',
    why: 'The active part of turmeric. May reduce soreness and joint pain a little.',
    how: '500-1000 mg with black pepper extract (piperine), which helps absorption.',
    note: 'Interacts with blood thinners. Rare liver issues with high-absorption products.',
  ),
  Supplement(
    name: 'HMB',
    tag: 'WEAK',
    why: 'A breakdown product of leucine. May help beginners and older adults hold on to muscle, little effect in trained lifters.',
    how: '3 g per day.',
    note: 'Spend the money on food and protein first.',
  ),
  Supplement(
    name: 'BCAAs',
    tag: 'WEAK',
    why: 'Three of the essential amino acids. If you eat enough protein, extra BCAAs do not build more muscle.',
    how: 'Not needed. A scoop of whey contains plenty.',
    note: 'Mostly marketing; they taste nice, that is about it.',
  ),
  Supplement(
    name: 'Glutamine',
    tag: 'WEAK',
    why: 'Popular for recovery, but studies in healthy lifters show no benefit for muscle or strength.',
    how: 'Not needed for gym goals.',
    note: 'Your body makes plenty of it.',
  ),
  Supplement(
    name: 'Glucosamine',
    tag: 'WEAK',
    why: 'Marketed for joints. Results for joint pain are mixed and mostly small.',
    how: '1500 mg per day if you want to try it for 3 months.',
    note: 'Shellfish allergy: check the source.',
  ),
  Supplement(
    name: 'Probiotics',
    tag: 'WEAK',
    why: 'Support gut bacteria. May help digestion and immunity in some people; no direct gym effect.',
    how: 'Follow the product dose; yogurt, kefir and fermented food do a similar job.',
    note: 'Benefits are strain-specific and vary between people.',
  ),
  Supplement(
    name: 'Tribulus terrestris',
    tag: 'NO EVIDENCE',
    why: 'Sold as a testosterone booster for decades. Human studies show it does not raise testosterone, strength or muscle.',
    how: 'Skip it.',
    note: 'Save the money for food, creatine and protein.',
  ),
];

/// A way to train: who made it famous, how it works and the split to try it.
class TrainingStyle {
  const TrainingStyle({
    required this.name,
    required this.who,
    required this.how,
    required this.why,
    required this.watch,
    this.split,
  });

  final String name;

  /// Who made it famous, or who it suits.
  final String who;
  final String how;
  final List<String> why;

  /// What to watch out for.
  final String watch;

  /// Built-in split that runs this style.
  final String? split;
}

const kStyles = <TrainingStyle>[
  TrainingStyle(
    name: 'Old School Split',
    who: 'Golden era bodybuilders of the 60s, 70s and 80s',
    how: 'Chest & Triceps, Biceps & Shoulders, Legs, Back. Every muscle gets one big, high-volume day a week: heavy basics first, then pump work until it is fully trained.',
    why: [
      'All your energy goes into one or two muscles, so you can push them harder than in a full body session.',
      'A full week of recovery for each muscle.',
      'Simple, fun and built around the pump and the mind-muscle connection.',
    ],
    watch: 'Miss one session and that muscle waits two weeks. Keep your attendance high.',
    split: 'old4',
  ),
  TrainingStyle(
    name: 'Arnold Split',
    who: 'Arnold Schwarzenegger, 7× Mr. Olympia',
    how: 'Chest & Back, Shoulders & Arms, Legs, then repeat: six days a week. Chest and back are often supersetted, a press straight into a pull.',
    why: [
      'Every muscle trained twice a week with high volume.',
      'Supersetting opposite muscles saves time and makes a huge pump through the torso.',
      'Arms get direct work twice a week, which is where the famous golden era arms came from.',
    ],
    watch: 'Very demanding. It needs serious food, 8 hours of sleep and some experience.',
    split: 'arnold',
  ),
  TrainingStyle(
    name: 'Bro Split',
    who: 'The classic magazine routine used by countless pro bodybuilders',
    how: 'Chest, Back, Shoulders, Arms, Legs: one muscle group a day, five days a week.',
    why: [
      'Lots of exercises and angles for every muscle.',
      'Each session is focused and short enough to go all out.',
      'Easy to follow and easy to adjust: just swap exercises.',
    ],
    watch: 'Each muscle once a week. Make every set count and do not skip legs.',
    split: 'bro5',
  ),
  TrainingStyle(
    name: 'Back & Bi / Chest & Tri',
    who: 'The most common gym pairing in the world',
    how: 'Chest & Triceps, Back & Biceps, Shoulders, Legs over four days.',
    why: [
      'Muscles that work together are trained together: presses tire the triceps, pulls tire the biceps.',
      'Small muscles get finished off when they are already warm.',
      'Four days fits most schedules.',
    ],
    watch: 'Arms are already tired from the big lifts, so lower the weight on curls and extensions.',
    split: 'classic4',
  ),
  TrainingStyle(
    name: 'Heavy Duty (HIT)',
    who: 'Mike Mentzer (perfect 300 score at the 1978 Mr. Universe) and Dorian Yates, 6× Mr. Olympia, with his Blood & Guts version',
    how: 'After warm-up sets, one single all-out working set per exercise taken to total failure. Few exercises, short sessions, lots of rest days.',
    why: [
      'Maximum intensity, minimum time: sessions take 30-45 minutes.',
      'Lots of recovery suits busy people and lifters who recover slowly.',
      'Forces you to focus on perfect form and real effort.',
    ],
    watch: 'Only works if the set truly goes to failure. Use a spotter, and warm up properly before that one set.',
    split: 'hit2',
  ),
  TrainingStyle(
    name: 'Push / Pull / Legs',
    who: 'The modern standard, run by everyone from beginners to pros',
    how: 'Pushing muscles one day, pulling the next, legs the third. Run it 3 days a week, or twice through for 6.',
    why: [
      'Muscles that work together rest together.',
      'Twice a week frequency on the 6-day version.',
      'Easy to balance pushing and pulling for healthy shoulders.',
    ],
    watch: 'Six days a week is a lot. Start with three if you are new.',
    split: 'ppl',
  ),
  TrainingStyle(
    name: 'Upper / Lower',
    who: 'Strength athletes and busy lifters',
    how: 'Upper body and lower body on alternating days, four days a week.',
    why: [
      'Every muscle twice a week.',
      'Good balance of heavy compound work and accessories.',
      'Easy to fit around work: four days with rest between.',
    ],
    watch: 'Upper days get long. Keep the accessories short.',
    split: 'ul',
  ),
  TrainingStyle(
    name: 'Full Body',
    who: 'Steve Reeves and the 1940s-50s pioneers, and most beginners today',
    how: 'The whole body in every session, three days a week, a few hard sets per muscle.',
    why: ['Every muscle three times a week.', 'Missing a day costs little.', 'Best way to learn the main lifts fast.'],
    watch: 'Hard to give every muscle lots of volume. Keep the exercises few and the effort high.',
    split: 'fb',
  ),
  TrainingStyle(
    name: '5×5 Strength',
    who: 'Reg Park, 3× Mr. Universe and Arnold\'s idol, made it famous',
    how: 'Squat every session plus bench and row, or overhead press and deadlift, for 5 sets of 5. Add weight every session.',
    why: [
      'Fast, measurable strength gains.',
      'Builds a solid base of muscle on the big lifts.',
      'Only three exercises a day: simple and quick.',
    ],
    watch: 'When you stall three sessions in a row, drop the weight 10% and build back up.',
    split: 'str3',
  ),
  TrainingStyle(
    name: 'Calisthenics',
    who: 'Gymnasts, street workout athletes and anyone without a gym',
    how: 'Pull-ups, push-ups, dips, pistols and core work, made harder with slower tempo and tougher variations.',
    why: [
      'Train anywhere, for free.',
      'Builds relative strength and body control.',
      'Joint-friendly when progressed slowly.',
    ],
    watch: 'Legs need hard variations (pistols, jumps) or they get left behind.',
    split: 'calis3',
  ),
  TrainingStyle(
    name: 'Glute Focus',
    who: 'Physique and bikini competitors, and anyone who wants stronger hips',
    how: 'Two glute-and-hamstring days a week, one upper day, one leg day.',
    why: [
      'Glutes recover fast and grow well with frequent, varied work.',
      'Strong glutes help the lower back and knees.',
      'The upper day keeps the physique balanced.',
    ],
    watch: 'Do not skip the upper day.',
    split: 'glute4',
  ),
  TrainingStyle(
    name: 'Hybrid',
    who: 'Hybrid athletes who want to look strong and run far',
    how: 'Lifting on upper, lower and full body days, plus one easy zone 2 day and one HIIT day.',
    why: [
      'Strength and engine at the same time.',
      'Easy cardio helps you recover between sets and sessions.',
      'Great all-round health.',
    ],
    watch: 'Keep the zone 2 really easy, or it will cut into your lifting.',
    split: 'hybrid',
  ),
  TrainingStyle(
    name: 'Home Dumbbell',
    who: 'Anyone training at home with a pair of dumbbells',
    how: 'Full body dumbbell sessions plus one HIIT day.',
    why: [
      'Minimal equipment, no commute.',
      'Unilateral work fixes left-right imbalances.',
      'Works as a backup plan when you cannot get to the gym.',
    ],
    watch: 'When the dumbbells get light, slow down, pause and add reps.',
    split: 'home3',
  ),
];

/// Old school intensity techniques.
class Technique {
  const Technique(this.name, this.how, this.when);

  final String name;
  final String how;
  final String when;
}

const kTechniques = <Technique>[
  Technique(
    'Supersets',
    'Two exercises back to back with no rest, often for opposite muscles like chest and back.',
    'Saves time and builds a big pump. Arnold supersetted almost everything.',
  ),
  Technique(
    'Drop sets',
    'At failure, drop the weight by 20-30% and keep going, once or twice.',
    'On the last set of an isolation exercise. Machines and dumbbells make it quick.',
  ),
  Technique(
    'Rest-pause',
    'Go to failure, rest 10-20 seconds, then squeeze out a few more reps. Repeat once or twice.',
    'Gets more hard reps out of one set. A Heavy Duty favourite.',
  ),
  Technique(
    'Pre-exhaust',
    'An isolation move right before a compound: flyes then bench, leg extensions then leg press.',
    'When the triceps or another helper muscle gives out before the target muscle.',
  ),
  Technique(
    'Forced reps',
    'A partner helps just enough to finish 1-3 reps past failure.',
    'Sparingly, on the last set. Needs a good spotter.',
  ),
  Technique(
    '21s',
    '7 reps in the bottom half, 7 in the top half, 7 full reps, no rest.',
    'Classic for biceps curls. Brutal pump.',
  ),
  Technique(
    'Giant sets',
    'Four or more exercises for one muscle back to back.',
    'Old school finisher for a lagging muscle.',
  ),
  Technique(
    'Cheat reps',
    'A little body English to get the weight past the sticking point, then a slow lowering.',
    'Only on the last reps, only when you can control the negative. Arnold used them on curls.',
  ),
  Technique(
    'Slow negatives',
    'Lower the weight over 3-5 seconds.',
    'Builds strength and muscle with less weight, and is easier on joints.',
  ),
  Technique(
    'Peak contraction',
    'Hold the squeezed position for 1-2 seconds every rep.',
    'Isolation work: curls, lateral raises, leg curls, calf raises.',
  ),
];

/// Training basics: a title and its key points.
const kBasics = <(String, List<String>)>[
  (
    'The best split is the one you show up for',
    [
      'Bro split, old school, PPL or full body all build muscle when the effort is high and you keep coming back.',
      'Pick what you enjoy and what fits your week. Variety keeps training fun and fun keeps you consistent.',
      'Change exercises every few months to keep it fresh, but keep the main lifts long enough to see progress.',
    ],
  ),
  (
    'Progressive overload',
    [
      'Muscles grow when you ask them for a bit more than last time: more weight, more reps, or cleaner reps.',
      'Write it down. Beat the logbook a little most weeks.',
      'When the top of the rep range is easy for all sets, add weight.',
    ],
  ),
  (
    'How hard to train',
    [
      'Most working sets should end with 0-3 reps left in the tank.',
      'Warm-up sets do not count. Easy sets far from failure build little.',
      'Go to full failure mainly on machines and isolation work, not heavy squats or deadlifts.',
    ],
  ),
  (
    'Sets and reps',
    [
      'Strength: 1-6 reps with heavier weight and longer rest.',
      'Muscle: anything from about 6 to 20 reps works if the sets are hard.',
      'Most people grow well on 10-20 hard sets per muscle per week.',
    ],
  ),
  (
    'Rest between sets',
    [
      '2-3 minutes on big compound lifts so you can lift heavy again.',
      '1-2 minutes on isolation work.',
      'Supersets and drop sets are the exception, on purpose.',
    ],
  ),
  (
    'Warm up properly',
    [
      '5 minutes of light cardio to raise body temperature.',
      'Then 2-4 lighter ramp-up sets of your first exercise.',
      'Joints that ache: warm up longer, start lighter.',
    ],
  ),
  (
    'Mind-muscle connection',
    [
      'Think about the muscle you are training and feel it contract. Old school lifters swore by it, and research backs it up for isolation work.',
      'Slow down the lowering part and squeeze at the top.',
      'Lighter weight with a great contraction beats heavy weight with sloppy form.',
    ],
  ),
  (
    'Recovery and sleep',
    [
      'Muscles grow between sessions, not during them.',
      '7-9 hours of sleep. Nothing you can buy beats it.',
      'Sore is fine. Sharp pain in a joint is not: stop and flag it in Bolt.',
    ],
  ),
  (
    'Eat for your goal',
    [
      'Protein: 1.6-2.2 g per kg of bodyweight every day.',
      'To gain muscle, eat a little more than you burn (about 200-400 kcal over).',
      'To lose fat, eat a little less (about 300-500 kcal under) and keep lifting heavy to keep muscle.',
    ],
  ),
  (
    'Deloads',
    [
      'Every 4-8 weeks, take an easier week: half the sets, lighter weight.',
      'Comes back stronger, joints feel better.',
      'Also a good time to change exercises or try a new split.',
    ],
  ),
  (
    'Cardio and lifting',
    [
      'Some cardio helps recovery and health without hurting muscle gains.',
      'Do hard cardio after lifting or on another day.',
      'Easy walks count. 8,000-10,000 steps a day is a great base.',
    ],
  ),
  (
    'Men and women',
    [
      'The same lifts, sets and progressive overload build muscle in both. Train for your goal, not for your sex.',
      'Men carry more muscle, mostly in the upper body, so they lift more in total. Relative to body size, women\'s legs are nearly as strong.',
      'Women usually recover faster between sets and get more reps at the same % of their max, so they can often handle a bit more volume.',
      'Coaches: start women\'s upper body loads lighter compared to their legs, and expect a few extra reps on % based sets.',
      'Healthy body fat is higher for women (about 20-30%) than for men (about 10-20%). Compare yourself to your own trend, not to the other sex.',
      'Hormones shift through the monthly cycle. Strength can dip the days before a period: going lighter is fine, and so is training hard when you feel good.',
      'Protein needs per kg are the same for both. Women who train hard should watch iron, calcium and vitamin D.',
    ],
  ),
];
