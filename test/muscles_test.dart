import 'package:bolt/data/lifts.dart';
import 'package:bolt/data/models/exercise.dart';
import 'package:bolt/data/models/session.dart';
import 'package:flutter_test/flutter_test.dart';

Session _done(List<String> lifts) => Session(
  tpl: 'x',
  title: 'Day',
  focus: '',
  mins: 60,
  ex: [for (final (i, n) in lifts.indexed) Exercise(id: 'e$i', name: n, sets: 4, reps: '8', load: '')],
  status: SessionStatus.done,
);

void main() {
  test('arm work counts the forearms, hanging pulls the abs and forearms too', () {
    expect(musclesOf('Barbell Curl'), {'biceps', 'forearms'});
    expect(musclesOf('Pull-up'), {'back', 'forearms', 'abs'});
    expect(musclesOf('Chin-up'), containsAll(['abs', 'forearms']));
    // Kneeling on the assisted machine braces nothing.
    expect(musclesOf('Assisted Pull-up'), isNot(contains('abs')));
    expect(musclesOf('Back Squat'), {'quads'});
  });

  test('after an arms day the forearms are recovering, after pull-ups the abs', () {
    final plan = {
      '2026-11-07': _done(['Barbell Curl']),
      '2026-11-08': _done(['Pull-up']),
    };
    final r = recovery(plan, '2026-11-08');
    expect(r['forearms'], 0);
    expect(r['abs'], 0);
    expect(lastTrained(plan, '2026-11-08')['abs'], '2026-11-08');
    // Four pull-up sets: two abs sets and two forearm sets; four curl sets
    // add two more for the forearms.
    final sets = muscleSets(plan, '2026-11-01', '2026-11-09');
    expect(sets['abs'], 2);
    expect(sets['forearms'], 4);
  });
}
