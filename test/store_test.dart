import 'dart:convert';

import 'package:bolt/core/format.dart';
import 'package:bolt/data/bolt_store.dart';
import 'package:bolt/data/models/bolt_data.dart';
import 'package:bolt/data/models/session.dart';
import 'package:bolt/data/models/visit.dart';
import 'package:bolt/data/rules.dart';
import 'package:bolt/data/seed/demo.dart';
import 'package:bolt/data/seed/templates.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Wednesday 14 Oct 2026, 18:00, the prototype's demo day.
final wed = DateTime(2026, 10, 14, 18);

class Harness {
  Harness([DateTime? start]) : clock = start ?? wed {
    container = ProviderContainer(overrides: [clockProvider.overrideWithValue(() => clock)]);
  }

  DateTime clock;
  late final ProviderContainer container;

  BoltStore get store => container.read(boltProvider.notifier);
  BoltData get data => container.read(boltProvider);
  String? get toast => container.read(toastProvider)?.text;

  void as(Role role, String id) => store.signIn(role, id);
}

void main() {
  group('format', () {
    test('dates and durations read like the prototype', () {
      expect(fmtDay('2026-10-14'), 'Wed 14 Oct');
      expect(dk(monday(wed)), '2026-10-12');
      expect(dur(67), '1h 07m');
      expect(dur(42), '42m');
      expect(fromMin(toMin('23:30') + 45), '00:15');
      expect(initials('Marko Ilić'), 'MI');
      expect(plural(1, 'session'), '1 session');
      expect(plural(3, 'session'), '3 sessions');
    });

    test('title auto-size steps at 6 and 9 chars', () {
      expect(tsz('PULL', 54), 54);
      expect(tsz('Mobility', 54), 40);
      expect(tsz('Conditioning', 54), 30);
    });
  });

  group('rules', () {
    test('kg loads convert to lb, other loads stay', () {
      expect(unitLoad('70 kg', kg: false), '154 lb');
      expect(unitLoad('2×28 kg', kg: false), '2×62 lb');
      expect(unitLoad('BW', kg: false), 'BW');
      expect(unitLoad('70 kg', kg: true), '70 kg');
    });

    test('picker lists every template exercise once, sorted', () {
      final names = kAllExercises.map((e) => e.name).toList();
      expect(names.toSet().length, names.length);
      expect(names.first, '90/90 Hip Switch');
      expect(names, contains('Bench Press'));
    });

    test('plaque token is checked', () {
      expect(Gym.isPlaque(Gym.plaqueUri), isTrue);
      expect(Gym.isPlaque('bolt://checkin?gym=other'), isFalse);
      expect(Gym.isPlaque('https://example.com'), isFalse);
    });
  });

  group('demo seed', () {
    test('matches the prototype on its demo day', () {
      final h = Harness();
      final d = h.data;
      final ana = d.plans['t1']!;
      expect(ana['2026-10-12']!.status, SessionStatus.done);
      expect(ana['2026-10-14']!.title, 'Pull');
      expect(ana['2026-10-14']!.status, SessionStatus.approved);
      expect(ana['2026-10-14']!.note, startsWith('Stay at 110 kg'));
      expect(ana['2026-10-19']!.status, SessionStatus.pending);
      final luka = d.plans['t2']!;
      expect(luka['2026-10-15'], isNull);
      expect(luka['2026-10-17']!.status, SessionStatus.moved);
      expect(luka['2026-10-17']!.from, '2026-10-15');
      expect(d.gymIn.keys, ['t3']);
      expect(d.plans['t6'], isEmpty);
      expect(d.visits['t1']!.first.inT, '18:05');
    });

    test('survives a JSON round trip', () {
      final h = Harness();
      final json = jsonEncode(h.data.toJson());
      final back = BoltData.fromJson(jsonDecode(json) as Map<String, dynamic>);
      expect(jsonEncode(back.toJson()), json);
    });
  });

  group('check-in', () {
    test('the same scan checks in then out and counts the visit', () {
      final h = Harness()..as(Role.trainee, 't1');
      expect(h.store.scan().head, 'Checked in');
      expect(h.data.gymIn['t1']!.since, '18:00');
      h.clock = wed.add(const Duration(minutes: 72));
      final out = h.store.scan();
      expect(out.head, 'Checked out');
      expect(out.sub, '1h 12m in the gym · 18:00 → 19:12');
      expect(out.unlocked, ['s25']);
      expect(h.data.visits['t1']!.first.mins, 72);
      expect(h.data.trainees.first.stats.sessions, 25);
    });

    test('a visit across midnight stays on its check-in day', () {
      final h = Harness(DateTime(2026, 10, 14, 23, 30))..as(Role.trainee, 't1');
      h.store.scan();
      h.clock = DateTime(2026, 10, 15, 0, 20);
      h.store.scan();
      final v = h.data.visits['t1']!.first;
      expect(v.date, '2026-10-14');
      expect(v.outT, '00:20');
      expect(v.mins, 50);
    });

    test('open visits auto-close after 5 hours', () {
      final h = Harness();
      expect(h.data.gymIn.keys, ['t3']);
      h.clock = wed.add(const Duration(hours: 5));
      h.store.autoCloseStale();
      expect(h.data.gymIn, isEmpty);
      final v = h.data.visits['t3']!.first;
      expect(v.auto, isTrue);
      expect(v.mins, 300);
    });

    test('coaches can check in too', () {
      final h = Harness()..as(Role.coach, 'c1');
      h.store.scan();
      expect(h.data.gymIn.containsKey('c1'), isTrue);
    });
  });

  group('trainee plan', () {
    test('accept all confirms pending sessions and names the coach', () {
      final h = Harness()..as(Role.trainee, 't1');
      h.store.acceptAll();
      expect(h.toast, '3 sessions confirmed · Marko notified');
      expect(h.data.plans['t1']!.values.where((s) => s.status == SessionStatus.pending), isEmpty);
    });

    test('moving only works onto empty days that are today or later', () {
      final h = Harness()..as(Role.trainee, 't1');
      expect(h.store.move('2026-10-19', '2026-10-13'), isFalse);
      expect(h.store.move('2026-10-19', '2026-10-21'), isFalse);
      expect(h.store.move('2026-10-19', '2026-10-20'), isTrue);
      final s = h.data.plans['t1']!['2026-10-20']!;
      expect(s.status, SessionStatus.moved);
      expect(s.from, '2026-10-19');
      expect(h.toast, 'Moved to Tue 20 Oct · Marko notified');
    });

    test('finishing logs sets done and records a perfect week', () {
      final h = Harness()..as(Role.trainee, 't1');
      h.store.startWorkout('2026-10-14');
      final ex = h.data.plans['t1']!['2026-10-14']!.ex;
      expect(h.store.toggleSet(ex[0].id, 0), isTrue);
      h.store.toggleSet(ex[0].id, 1);
      h.store.finish();
      final s = h.data.plans['t1']!['2026-10-14']!;
      expect(s.status, SessionStatus.done);
      expect(s.log, '2/16 sets');
      // Friday is still open, so not a perfect week yet.
      expect(h.data.trainees.first.stats.perfect, 2);
    });
  });

  group('coach planning', () {
    test('tapping an empty day adds the next workout in the rotation', () {
      final h = Harness()..as(Role.coach, 'c1');
      h.store.addFromRotation('t1', '2026-10-17');
      // Last session before the 17th is Friday's Legs, so Push comes next.
      expect(h.data.plans['t1']!['2026-10-17']!.tpl, 'push');
      expect(h.data.plans['t1']!['2026-10-17']!.status, SessionStatus.draft);
      h.store.addFromRotation('t1', '2026-10-13');
      expect(h.data.plans['t1']!['2026-10-13'], isNull);
    });

    test('auto-fill drafts empty future split days for 3 weeks', () {
      final h = Harness()..as(Role.coach, 'c2');
      h.store.autoFill('t6');
      final p = h.data.plans['t6']!;
      // Full body Mon/Wed/Fri: Wed 14 and Fri 16 this week, then 2 full weeks.
      expect(p.keys.toList()..sort(), [
        '2026-10-14',
        '2026-10-16',
        '2026-10-19',
        '2026-10-21',
        '2026-10-23',
        '2026-10-26',
        '2026-10-28',
        '2026-10-30',
      ]);
      expect(p.values.every((s) => s.status == SessionStatus.draft), isTrue);
      expect(h.toast, '8 sessions drafted from 3-day Full Body');
      h.store.autoFill('t6');
      expect(h.toast, 'The next 3 weeks are already planned');
      h.store.sendDrafts('t6');
      expect(h.toast, 'Sent 8 sessions · waiting for Petra');
      expect(p.values.every((s) => s.status == SessionStatus.pending), isTrue);
    });

    test('editing a sent day turns it into a draft until saved', () {
      final h = Harness()..as(Role.coach, 'c1');
      const t = DayTarget('t1', '2026-10-19');
      h.store.edit(t, () => h.store.editExercises(t).first.sets = 5);
      expect(h.data.plans['t1']!['2026-10-19']!.status, SessionStatus.draft);
      h.store.saveEdit(t);
      expect(h.data.plans['t1']!['2026-10-19']!.status, SessionStatus.pending);
      expect(h.toast, 'Sent to Ana for approval');
    });

    test('sessions copy template exercises', () {
      final h = Harness()..as(Role.coach, 'c1');
      h.store.edit(const TemplateTarget('push'), () => h.data.tpls['push']!.ex.first.sets = 9);
      expect(h.data.plans['t1']!['2026-10-19']!.ex.first.sets, 4);
    });

    test('injury flags offer swaps that record the original', () {
      final h = Harness()..as(Role.trainee, 't1');
      h.store.reportInjury('t1', 'shoulder', '');
      final t = h.data.trainees.first;
      expect(t.injuries.last.note, 'Shoulder pain reported');
      expect(t.injuries.last.fresh, isTrue);
      final bench = h.data.plans['t1']!['2026-10-19']!.ex.first;
      expect(isFlagged(t, bench), isTrue);
      h.store.swap(bench);
      expect(bench.name, 'Floor Press');
      expect(bench.orig, 'Bench Press');
      expect(isFlagged(t, bench), isFalse);
    });

    test('custom templates get a code from their name', () {
      final h = Harness()..as(Role.coach, 'c1');
      final id = h.store.newTemplate();
      expect(id, 'cu1');
      h.store.renameTemplate(id, 'Arms 2');
      expect(h.data.tpls[id]!.code, 'ARMS');
    });
  });

  test('streak breaks after a week without a perfect week', () {
    final h = Harness();
    final s = h.data.trainees.first.stats;
    // Last perfect week was the one before this, so the streak still holds...
    expect(currentStreak(s, wed), 4);
    // ...until this week ends without one.
    expect(currentStreak(s, wed.add(const Duration(days: 7))), 0);
  });

  test('visit json keeps the auto flag', () {
    final v = Visit(date: '2026-10-14', inT: '18:00', outT: '23:00', mins: 300, auto: true);
    expect(Visit.fromJson(v.toJson()).auto, isTrue);
  });
}
