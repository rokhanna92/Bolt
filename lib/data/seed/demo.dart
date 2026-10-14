import '../../core/format.dart';
import '../models/bolt_data.dart';
import '../models/exercise.dart';
import '../models/people.dart';
import '../models/session.dart';
import '../models/settings.dart';
import '../models/template.dart';
import '../models/visit.dart';
import 'splits.dart';
import 'templates.dart';

/// The gym and its permanent plaque. The token is printed on the QR.
abstract final class Gym {
  static const name = 'Bolt Downtown';
  static const plaqueToken = 'bolt-downtown-7f3k9q';
  static const plaqueUri = 'bolt://checkin?gym=$plaqueToken';

  /// True when [raw] is this gym's plaque.
  static bool isPlaque(String raw) {
    final u = Uri.tryParse(raw.trim());
    return u != null && u.scheme == 'bolt' && u.host == 'checkin' && u.queryParameters['gym'] == plaqueToken;
  }
}

Exercise exerciseFromSeed(ExSeed a, String id) =>
    Exercise(id: id, name: a.name, sets: a.sets, reps: a.reps, load: a.load, area: a.area, alt: a.alt);

/// Copies a template into a new session. Exercises are copied, never shared.
Session sessionFromTemplate(BoltData d, String tplId, SessionStatus status) {
  final x = d.tpls[tplId]!;
  return Session(
    tpl: tplId,
    title: x.name,
    focus: x.focus,
    mins: x.mins,
    ex: [for (final e in x.ex) e.copyWith(id: d.uid())],
    status: status,
  );
}

/// Puts each split day of the week starting at [mon] into [plan] where empty.
void fillWeek(BoltData d, Map<String, Session> plan, String split, DateTime mon, SessionStatus status) {
  for (final day in kSplits[split]!.days) {
    final k = dk(addDays(mon, day.weekday - 1));
    plan.putIfAbsent(k, () => sessionFromTemplate(d, day.tpl, status));
  }
}

class _DemoTrainee {
  const _DemoTrainee(
    this.id,
    this.name,
    this.coach,
    this.goal,
    this.split,
    this.since,
    this.injuries,
    this.stats,
    this.pre,
  );

  final String id, name, coach, goal, split, since;
  final List<Injury> injuries;
  final TraineeStats stats;

  /// Minutes trained in weeks -5, -4 and -3, for the 6-week chart.
  final List<int> pre;
}

TraineeStats _st(int a, int b, int c, int d, int e, int f, int g) =>
    TraineeStats(sessions: a, mins: b, early: c, late: d, prs: e, streak: f, perfect: g);

/// Demo gym from the prototype's `seed()`, anchored on [now] instead of a
/// fixed date so the calendar always looks lived in.
BoltData buildDemoData(DateTime now) {
  final d = BoltData(
    tpls: {},
    coaches: [
      Coach(id: 'c1', name: 'Marko Ilić', role: 'Strength & Hypertrophy'),
      Coach(id: 'c2', name: 'Sara Novak', role: 'Conditioning & Rehab'),
    ],
    trainees: [],
    plans: {},
    visits: {},
    gymIn: {},
    settings: AppSettings(),
  );
  kTemplates.forEach((k, t) {
    d.tpls[k] = WorkoutTemplate(
      id: k,
      name: t.name,
      code: t.code,
      focus: t.focus,
      mins: t.mins,
      ex: [for (final e in t.ex) exerciseFromSeed(e, d.uid())],
    );
  });

  final today = dk(now);
  final mon0 = monday(now);
  final demo = [
    _DemoTrainee('t1', 'Ana Marić', 'c1', 'Strength', 'ppl', 'Mar 2026', [], _st(24, 1890, 2, 0, 3, 4, 2), [
      214,
      246,
      198,
    ]),
    _DemoTrainee(
      't2',
      'Luka Petrović',
      'c1',
      'Hypertrophy',
      'ul',
      'Jan 2026',
      [Injury(area: 'back', note: 'Lower back strain. No heavy hinging for two weeks.', by: 'Added by Marko · 9 Oct')],
      _st(41, 3120, 0, 6, 7, 2, 3),
      [262, 238, 251],
    ),
    _DemoTrainee('t3', 'Ivan Horvat', 'c1', 'Fat loss', 'fb', 'Aug 2026', [], _st(14, 980, 6, 0, 1, 3, 1), [
      150,
      182,
      170,
    ]),
    _DemoTrainee('t4', 'Mia Kos', 'c2', 'Conditioning', 'fb', 'May 2026', [], _st(33, 2210, 1, 2, 4, 6, 4), [
      196,
      205,
      188,
    ]),
    _DemoTrainee(
      't5',
      'David Jurić',
      'c2',
      'Return to sport',
      'rehab',
      'Sep 2026',
      [Injury(area: 'knee', note: 'Right knee. Avoid deep flexion and jumping.', by: 'Added by Sara · 2 Oct')],
      _st(8, 470, 0, 0, 0, 1, 1),
      [0, 96, 110],
    ),
    _DemoTrainee('t6', 'Petra Babić', 'c2', 'General fitness', 'fb', 'Oct 2026', [], _st(0, 0, 0, 0, 0, 0, 0), [
      0,
      0,
      0,
    ]),
  ];

  for (var ti = 0; ti < demo.length; ti++) {
    final t = demo[ti];
    if (t.stats.streak > 0) t.stats.lastPerfectWeek = dk(addDays(mon0, -7));
    d.trainees.add(
      Trainee(
        id: t.id,
        name: t.name,
        coach: t.coach,
        goal: t.goal,
        split: t.split,
        since: t.since,
        injuries: t.injuries,
        stats: t.stats,
      ),
    );
    final plan = d.plans[t.id] = {};
    if (t.id != 't6') {
      for (var w = -2; w <= 0; w++) {
        fillWeek(d, plan, t.split, addDays(mon0, 7 * w), SessionStatus.approved);
      }
    }
    for (final e in plan.entries) {
      if (e.key.compareTo(today) < 0) {
        e.value.status = SessionStatus.done;
        final n = e.value.totalSets;
        e.value.log = '$n/$n sets';
      }
    }

    final pat = t.id == 't1'
        ? ['18:05', '06:48', '17:40', '18:10', '06:55', '18:20', '17:55']
        : ['17:20', '18:40', '07:30', '19:05', '16:50', '18:15', '20:10'];
    final doneKeys = plan.keys.where((k) => plan[k]!.status == SessionStatus.done).toList()..sort();
    final recent = doneKeys.reversed.toList();
    final visits = <Visit>[];
    for (var i = 0; i < recent.length; i++) {
      final inT = pat[(i + ti) % pat.length];
      final mins = t.id == 't1' ? const [77, 67, 72, 81, 67, 74, 70][i % 7] : 55 + ((i * 17 + ti * 11) % 35);
      visits.add(Visit(date: recent[i], inT: inT, outT: fromMin(toMin(inT) + mins), mins: mins));
    }
    // Older weeks for the chart: three visits a week adding up to `pre`.
    for (var i = 2; i >= 0; i--) {
      final total = t.pre[i];
      if (total == 0) continue;
      final mon = addDays(mon0, 7 * (i - 5));
      final part = total ~/ 3;
      for (final (j, wd) in const [(2, 4), (1, 2), (0, 0)]) {
        final mins = j == 2 ? total - part * 2 : part;
        final inT = pat[(j + i + ti) % pat.length];
        visits.add(Visit(date: dk(addDays(mon, wd)), inT: inT, outT: fromMin(toMin(inT) + mins), mins: mins));
      }
    }
    d.visits[t.id] = visits;
  }

  fillWeek(d, d.plans['t1']!, 'ppl', addDays(mon0, 7), SessionStatus.pending);
  fillWeek(d, d.plans['t4']!, 'fb', addDays(mon0, 7), SessionStatus.pending);

  // Luka moved Thursday's session to Saturday and waits for the coach's OK.
  final luka = d.plans['t2']!;
  final from = dk(addDays(mon0, 3)), to = dk(addDays(mon0, 5));
  final moved = luka[from];
  if (moved != null && moved.status != SessionStatus.done && luka[to] == null) {
    luka.remove(from);
    luka[to] = moved
      ..status = SessionStatus.moved
      ..from = from;
  }

  final anaToday = d.plans['t1']![today];
  if (anaToday != null) anaToday.note = 'Stay at 110 kg on deadlifts and focus on bar path. Film your last set.';

  d.gymIn['t3'] = GymIn(at: now.millisecondsSinceEpoch, base: 38, since: hm(now.subtract(const Duration(minutes: 38))));
  return d;
}
