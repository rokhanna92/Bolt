import 'package:bolt/data/models/exercise.dart';
import 'package:bolt/data/models/people.dart';
import 'package:bolt/data/models/session.dart';
import 'package:bolt/data/suggestions.dart';
import 'package:flutter_test/flutter_test.dart';

Session _day(String title, String lift, SessionStatus status) => Session(
  tpl: 'x',
  title: title,
  focus: '',
  mins: 60,
  ex: [Exercise(id: 'e1', name: lift, sets: 3, reps: '8', load: '')],
  status: status,
);

Trainee _me() => Trainee(
  id: 'me',
  name: 'Dani',
  coach: '',
  goal: '',
  split: 'ppl',
  since: '2026-01-01',
  injuries: [],
  stats: TraineeStats(),
);

void main() {
  // Wednesday 11 November 2026.
  final now = DateTime(2026, 11, 11);
  final monday = DateTime(2026, 11, 9);

  test('a missed session skips a free day next to the same muscles, and says why', () {
    final plan = {
      '2026-11-09': _day('Push', 'Bench Press', SessionStatus.approved),
      '2026-11-12': _day('Push 2', 'Bench Press', SessionStatus.approved),
    };
    final h = suggestions(_me(), plan, now, weekStart: monday, seen: []).single;
    expect(h.kind, HintKind.missed);
    // Today and Friday both touch Thursday's bench day: Saturday it is.
    expect(h.to, '2026-11-14');
    expect(h.text, contains('Not today: it sits next to Push 2, the same muscles.'));
  });

  test('with no clash the missed session moves to the first free day', () {
    final plan = {
      '2026-11-09': _day('Push', 'Bench Press', SessionStatus.approved),
      '2026-11-12': _day('Legs', 'Back Squat', SessionStatus.approved),
    };
    final h = suggestions(_me(), plan, now, weekStart: monday, seen: []).single;
    expect(h.to, '2026-11-11');
    expect(h.text, isNot(contains('Not ')));
  });
}
