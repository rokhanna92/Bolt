import 'package:bolt/data/models/exercise.dart';
import 'package:bolt/data/models/session.dart';
import 'package:bolt/data/models/visit.dart';
import 'package:bolt/data/period.dart';
import 'package:flutter_test/flutter_test.dart';

Session _done(List<SetLog> sets, {SessionStatus status = SessionStatus.done}) => Session(
  tpl: 'x',
  title: 'Push',
  focus: '',
  mins: 60,
  ex: [Exercise(id: 'e1', name: 'Bench Press', sets: 3, reps: '5', load: '', logged: sets)],
  status: status,
  prs: ['Bench Press'],
);

void main() {
  test('a month counts its finished workouts, visits, sets, volume and top lift', () {
    final plan = {
      '2026-11-03': _done([SetLog(kg: 100, reps: 5), SetLog(kg: 100, reps: 5)]),
      // Planned but not done, and a done day outside the month: neither counts.
      '2026-11-05': _done([SetLog(kg: 200, reps: 5)], status: SessionStatus.approved),
      '2026-10-31': _done([SetLog(kg: 300, reps: 5)]),
    };
    final visits = [
      Visit(date: '2026-11-03', inT: '18:00', outT: '19:10', mins: 70),
      Visit(date: '2026-10-31', inT: '18:00', outT: '19:00', mins: 60),
    ];
    final p = periodStats(plan, visits, '2026-11-01', '2026-12-01');
    expect(p.workouts, 1);
    expect(p.visits, 1);
    expect(p.mins, 70);
    expect(p.sets, 2);
    expect(p.volume, 1000);
    expect(p.prs, 1);
    expect(p.top?.$1, 'Bench Press');
    expect(p.top!.$2, closeTo(116.7, .1));
    expect(p.isEmpty, isFalse);
    expect(periodStats(plan, visits, '2026-09-01', '2026-10-01').isEmpty, isTrue);
  });
}
