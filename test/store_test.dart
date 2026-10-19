import 'package:bolt/data/repositories/bolt_repository.dart';
import 'package:bolt/data/models/people.dart';
import 'package:bolt/core/units.dart';

import 'dart:io';
import 'dart:convert';

import 'package:bolt/core/format.dart';
import 'package:bolt/data/bolt_store.dart';
import 'package:bolt/data/licenses.dart';
import 'package:bolt/data/models/board.dart';
import 'package:bolt/data/models/bolt_data.dart';
import 'package:bolt/data/level.dart';
import 'package:bolt/data/lifts.dart';
import 'package:bolt/data/warmup.dart';
import 'package:bolt/data/models/exercise.dart';
import 'package:bolt/features/progress/season_card.dart';
import 'package:bolt/data/models/session.dart';
import 'package:bolt/data/models/template.dart';
import 'package:bolt/data/models/visit.dart';
import 'package:bolt/data/plates.dart';
import 'package:bolt/data/rank.dart';
import 'package:bolt/data/rules.dart';
import 'package:bolt/data/seed/badges.dart';
import 'package:bolt/data/seed/content.dart';
import 'package:bolt/data/seed/exercises.dart';
import 'package:bolt/data/seed/templates.dart';
import 'package:bolt/l10n/sr.dart';
import 'package:bolt/services/notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/demo_data.dart';

/// Wednesday 14 Oct 2026, 18:00, the prototype's demo day.
final wed = DateTime(2026, 10, 14, 18);

class Harness {
  Harness([DateTime? start]) : clock = start ?? wed {
    container = ProviderContainer(
      overrides: [
        clockProvider.overrideWithValue(() => clock),
        initialDataProvider.overrideWith((ref) => buildDemoData(ref.read(clockProvider)())),
      ],
    );
  }

  DateTime clock;
  late final ProviderContainer container;

  BoltStore get store => container.read(boltProvider.notifier);
  BoltData get data => container.read(boltProvider);
  String? get toast => container.read(toastProvider)?.text;

  void as(Role role, String id) => data.account = Account(role, id);
}

void main() {
  ownerTests();

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

    test('plates load each side heaviest first and say what is short', () {
      expect(platesFor(100, 20, kPlatesKg).side, [25.0, 15.0]);
      expect(sideText(platesFor(142.5, 20, kPlatesKg).side), '2 × 25 · 10 · 1.25');
      expect(platesFor(20, 20, kPlatesKg).side, isEmpty);
      expect(platesFor(15, 20, kPlatesKg).left, -5);
      expect(platesFor(101, 20, kPlatesKg).left, closeTo(1, 1e-9));
      expect(platesFor(225, 45, kPlatesLb).side, [45.0, 45.0]);
    });

    test('weights step on the plate grid and time targets read as seconds', () {
      expect(stepWeight(100, 1, metric: true), 102.5);
      expect(stepWeight(101, -1, metric: true), 100);
      expect(stepWeight(2.5, -1, metric: true), isNull);
      expect(stepWeight(null, 1, metric: true), 2.5);
      expect(weightValue(stepWeight(100 / 2.20462, 1, metric: false), metric: false), '105');
      expect(targetSecs('45 s'), 45);
      expect(targetSecs('30-45 s'), 45);
      expect(targetSecs('30 min'), 1800);
      expect(targetSecs('8-10'), isNull);
      expect(targetSecs('250 m'), isNull);
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

    test('every exercise has Serbian text and a real swap', () {
      for (final e in kExercises) {
        for (final s in [e.name, e.works, e.avoid, ...e.cues]) {
          expect(kSr, contains(s), reason: s);
        }
        if (e.alt != null) expect(kExerciseByName, contains(e.alt), reason: e.name);
      }
      expect(kExerciseByName, contains('Incline Machine Chest Press'));
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
    test('a mistaken scan is undone in full until something else changes', () {
      final f = Fresh(wed)..store.createProfile(Role.solo, const ProfileInput(name: 'Dani', split: 'ppl'));
      f.store.addFromRotation(Account.ownerId, '2026-10-14');
      f.store.scan();
      expect(f.store.canUndoScan, isTrue);
      expect(f.store.undoScan(), isTrue);
      expect(f.data.gymIn, isEmpty);
      expect(f.store.undoScan(), isNull);

      // A real visit, then a check-out by mistake that finished the day.
      f.store.scan();
      f.clock = wed.add(const Duration(minutes: 40));
      f.store.scan();
      final t = f.data.trainees.single;
      expect((f.mine['2026-10-14']!.status, t.stats.sessions, t.stats.workouts), (SessionStatus.done, 1, 1));
      expect(f.store.undoScan(), isFalse);
      final back = f.data.trainees.single;
      expect(f.data.gymIn[Account.ownerId], isNotNull);
      expect(f.data.visits[Account.ownerId] ?? const [], isEmpty);
      expect((f.mine['2026-10-14']!.status, back.stats.sessions, back.stats.workouts), (SessionStatus.approved, 0, 0));

      // Anything else after the scan keeps it, and so does time.
      f.store.scan();
      f.store.dismissHint('x');
      expect(f.store.canUndoScan, isFalse);
      f.store.scan();
      f.clock = f.clock.add(const Duration(minutes: 11));
      expect(f.store.undoScan(), isNull);
    });

    test('the same scan checks in then out and counts the visit', () {
      final h = Harness()..as(Role.trainee, 't1');
      expect(h.store.scan().head, 'Checked in');
      expect(h.data.gymIn['t1']!.since, '18:00');
      h.clock = wed.add(const Duration(minutes: 72));
      final out = h.store.scan();
      expect(out.head, 'Day done');
      expect(out.sub, '1h 12m in the gym · 18:00 → 19:12');
      expect(out.unlocked, ['s25', 'lg1', 'st10', 'mb1', 'ms1', 'ma1']);
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
    test('accept all confirms pending sessions', () {
      final h = Harness()..as(Role.trainee, 't1');
      h.store.acceptAll();
      expect(h.toast, '3 sessions confirmed');
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
      expect(h.toast, 'Moved to Tue 20 Oct');
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

    test('logged workouts and their sets count toward badges', () {
      final f = Fresh()..store.createProfile(Role.solo, const ProfileInput(name: 'Dani'), autoPlan: true);
      f.store.startWorkout('2026-10-14');
      final ex = f.mine['2026-10-14']!.ex;
      f.store.toggleSet(ex[0].id, 0);
      f.store.toggleSet(ex[1].id, 0);
      f.store.toggleSet(ex[1].id, 1);
      expect(f.store.finish(), ['lg1', 'mb1', 'ms1', 'ma1']);
      final stats = f.data.trainees.single.stats;
      expect(stats.workouts, 1);
      expect(stats.sets, 3);
      expect(TraineeStats.fromJson(stats.toJson()).sets, 3);
      expect(badgeLeftText(kBadges.firstWhere((b) => b.id == 'st100'), stats), '97 sets to go');
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
      final msg = h.store.sendDrafts('t6');
      expect(msg, contains('Petra, here is your Bolt plan from Sara: 8 sessions'));
      expect(msg, contains('BOLT1.'));
      expect(p.values.every((s) => s.status == SessionStatus.pending), isTrue);
    });

    test('editing a sent day turns it into a draft until saved', () {
      final h = Harness()..as(Role.coach, 'c1');
      const t = DayTarget('t1', '2026-10-19');
      h.store.edit(t, () => h.store.editExercises(t).first.sets = 5);
      expect(h.data.plans['t1']!['2026-10-19']!.status, SessionStatus.draft);
      expect(h.store.saveEdit(t), contains('BOLT1.'));
      expect(h.data.plans['t1']!['2026-10-19']!.status, SessionStatus.pending);
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

  test('closest badge text counts down', () {
    final h = Harness();
    final s = h.data.trainees.first.stats;
    expect(badgeLeftText(kBadges.firstWhere((b) => b.id == 's25'), s), '1 session to go');
  });

  test('visit json keeps the auto flag', () {
    final v = Visit(date: '2026-10-14', inT: '18:00', outT: '23:00', mins: 300, auto: true);
    expect(Visit.fromJson(v.toJson()).auto, isTrue);
  });
}

/// A phone with nothing on it yet.
class Fresh {
  Fresh([DateTime? start, BoltNotifications? notify]) : clock = start ?? wed {
    container = ProviderContainer(
      overrides: [
        clockProvider.overrideWithValue(() => clock),
        if (notify != null) notificationsProvider.overrideWithValue(notify),
      ],
    );
  }

  DateTime clock;
  late final ProviderContainer container;

  BoltStore get store => container.read(boltProvider.notifier);
  BoltData get data => container.read(boltProvider);
  String? get toast => container.read(toastProvider)?.text;
  Map<String, Session> get mine => data.plans[Account.ownerId]!;
}

/// A solo user who lifted 100 kg × 5 on the first exercise a week ago.
Fresh lifted() {
  final f = Fresh(DateTime(2026, 10, 7, 18))
    ..store.createProfile(Role.solo, const ProfileInput(name: 'Dani', split: 'fb'));
  f.store.addFromRotation(Account.ownerId, '2026-10-07');
  f.store.startWorkout('2026-10-07');
  final e = f.mine['2026-10-07']!.ex.first;
  f.store.logSet(e.id, 0, SetLog(kg: 100, reps: 5));
  f.store.finish();
  f.clock = wed;
  return f;
}

void ownerTests() {
  group('onboarding', () {
    test('a fresh phone has templates and nobody in it', () {
      final f = Fresh();
      expect(f.data.account, isNull);
      expect(f.data.trainees, isEmpty);
      expect(f.data.coaches, isEmpty);
      expect(f.data.tpls.keys, containsAll(['push', 'pull', 'legs']));
    });

    test('solo profile with body and an auto-planned 3 weeks', () {
      final f = Fresh();
      f.store.createProfile(
        Role.solo,
        ProfileInput(
          name: ' Dani ',
          goal: 'Strength',
          split: 'ppl',
          gym: 'Iron Den',
          body: Body(weightKg: 80, cm: {'waist': 84}),
        ),
        autoPlan: true,
      );
      final me = f.data.trainees.single;
      expect(f.data.account!.role, Role.solo);
      expect(me.name, 'Dani');
      expect(me.body.weightKg, 80);
      expect(me.body.updated, '2026-10-14');
      expect(f.data.settings.gymName, 'Iron Den');
      // PPL Mon/Wed/Fri from this Monday, today onwards: 14, 16 then 2 weeks.
      expect(f.mine.length, 8);
      expect(f.mine.values.every((s) => s.status == SessionStatus.approved && !s.byCoach), isTrue);
      expect(f.mine['2026-10-14']!.title, 'Pull');
    });

    test('coach profile', () {
      final f = Fresh();
      f.store.createProfile(Role.coach, const ProfileInput(name: 'Sara', specialty: ''));
      expect(f.data.coaches.single.role, 'Coach');
      expect(f.data.account!.isCoach, isTrue);
    });

    test('an admin has both records and switches roles', () {
      final f = Fresh()..store.createProfile(Role.coach, const ProfileInput(name: 'Dani'), admin: true);
      expect(f.data.coaches.single.id, Account.ownerId);
      expect(f.data.trainees.single.coach, '');
      f.store.switchRole(Role.solo);
      expect(f.data.account!.role, Role.solo);
      expect(f.data.account!.admin, isTrue);
      final json = jsonEncode(f.data.toJson());
      expect(BoltData.fromJson(jsonDecode(json) as Map<String, dynamic>).account!.admin, isTrue);
    });

    test('a coach switches between coaching and training solo', () {
      final f = Fresh()..store.createProfile(Role.coach, ProfileInput(name: 'Sara', body: Body(weightKg: 64)));
      final tid = f.store.addTrainee(const ProfileInput(name: 'Ana'));
      expect(f.store.switchRoles, [Role.coach, Role.solo]);
      f.store.switchRole(Role.trainee);
      expect(f.data.account!.role, Role.coach);

      f.store.switchRole(Role.solo);
      expect(f.data.account!.role, Role.solo);
      final me = f.store.tr(Account.ownerId);
      expect(me.name, 'Sara');
      expect(me.body.weightKg, 64);
      // Training solo plans confirmed sessions, not drafts for a trainee.
      expect(f.store.addFromRotation(Account.ownerId, '2026-10-15'), isTrue);
      expect(f.mine['2026-10-15']!.status, SessionStatus.approved);

      f.store.switchRole(Role.coach);
      expect(f.data.account!.isCoach, isTrue);
      expect(f.data.trainees.where((t) => t.coach == Account.ownerId).map((t) => t.id), [tid]);
      // Switching back keeps the solo record and its plan.
      f.store.switchRole(Role.solo);
      expect(f.mine.keys, ['2026-10-15']);

      final solo = Fresh()..store.createProfile(Role.solo, const ProfileInput(name: 'Dani'));
      expect(solo.store.switchRoles, isEmpty);
      solo.store.switchRole(Role.coach);
      expect(solo.data.account!.role, Role.solo);
    });

    test('license codes', () {
      for (final c in ['', '00000', '000000', 'abcde', '1234', '1234567']) {
        expect(checkLicense(c), isNull, reason: c);
      }
      expect(licenseHash('12345'), licenseHash('12345'));
      expect(licenseHash('12345'), isNot(licenseHash('12346')));
    });

    test('profile edits save body and stamp the date', () {
      final f = Fresh()..store.createProfile(Role.solo, const ProfileInput(name: 'Dani'));
      f.store.saveProfile(Account.ownerId, ProfileInput(name: 'Dani K', body: Body(heightCm: 180)));
      expect(f.data.trainees.single.name, 'Dani K');
      expect(f.data.trainees.single.body.heightCm, 180);
      expect(f.data.trainees.single.body.updated, '2026-10-14');
    });

    test('reset erases everything', () {
      final f = Fresh()..store.createProfile(Role.solo, const ProfileInput(name: 'Dani'), autoPlan: true);
      f.store.resetAll();
      expect(f.data.account, isNull);
      expect(f.data.trainees, isEmpty);
    });
  });

  group('planning for yourself', () {
    test('sessions are confirmed straight away and edits keep them so', () {
      final f = Fresh()..store.createProfile(Role.solo, const ProfileInput(name: 'Dani', split: 'fb'));
      expect(f.store.addFromRotation(Account.ownerId, '2026-10-15'), isTrue);
      expect(f.mine['2026-10-15']!.status, SessionStatus.approved);
      const t = DayTarget(Account.ownerId, '2026-10-15');
      f.store.edit(t, () => f.store.editExercises(t).first.sets = 5);
      expect(f.mine['2026-10-15']!.status, SessionStatus.approved);
      expect(f.store.saveEdit(t), isNull);
      expect(f.toast, 'Session saved');
    });

    test('solo users fill in and log past days from their diary', () {
      final f = Fresh()..store.createProfile(Role.solo, const ProfileInput(name: 'Dani', split: 'ppl'));
      expect(f.store.addFromRotation(Account.ownerId, '2026-10-07'), isTrue);
      final s = f.mine['2026-10-07']!;
      expect(s.status, SessionStatus.approved);
      expect(f.store.logPast('2026-10-07'), ['lg1', 'di1', 'st10', 'mc1', 'ms1', 'ma1']);
      expect(s.status, SessionStatus.done);
      expect(s.log, '${s.totalSets}/${s.totalSets} sets');
      expect(f.toast, 'Wed 7 Oct logged · ${s.log}');
      final stats = f.data.trainees.single.stats;
      expect(stats.workouts, 1);
      expect(stats.sets, s.totalSets);
      // Logging twice, or a day not behind us, changes nothing.
      expect(f.store.logPast('2026-10-07'), isEmpty);
      f.store.addFromRotation(Account.ownerId, '2026-10-15');
      expect(f.store.logPast('2026-10-15'), isEmpty);
      expect(stats.workouts, 1);

      final ana = Fresh()..store.createProfile(Role.trainee, const ProfileInput(name: 'Ana'));
      expect(ana.store.addFromRotation(Account.ownerId, '2026-10-07'), isFalse);
      final coach = Fresh()..store.createProfile(Role.coach, const ProfileInput(name: 'Marko'));
      final tid = coach.store.addTrainee(const ProfileInput(name: 'Ana'));
      expect(coach.store.addFromRotation(tid, '2026-10-07'), isFalse);
    });

    test('moving your own session does not mark it moved', () {
      final f = Fresh()..store.createProfile(Role.solo, const ProfileInput(name: 'Dani'), autoPlan: true);
      expect(f.store.move('2026-10-16', '2026-10-17'), isTrue);
      expect(f.mine['2026-10-17']!.status, SessionStatus.approved);
      expect(f.mine['2026-10-17']!.from, isNull);
    });
  });

  group('immersion', () {
    test('a live record is a heavier weight, else a better estimated max', () {
      final f = lifted();
      final name = f.mine['2026-10-07']!.ex.first.name;
      LivePr? pr(SetLog l) => livePr(f.mine, name, '2026-10-14', l);
      expect(pr(SetLog(kg: 100, reps: 5)), isNull);
      expect(pr(SetLog(kg: 102.5, reps: 1))!.heavier, isTrue);
      final more = pr(SetLog(kg: 100, reps: 8))!;
      expect(more.heavier, isFalse);
      expect(more.was, closeTo(116.67, .01));
      expect(livePr(f.mine, 'Nothing logged', '2026-10-14', SetLog(kg: 10, reps: 5)), isNull);
    });

    test('a workout races the last one with the same template', () {
      final f = lifted();
      final first = f.mine['2026-10-07']!;
      expect(f.store.addFromRotation(Account.ownerId, '2026-10-14'), isTrue);
      f.store.setTemplate(Account.ownerId, '2026-10-14', first.tpl);
      expect(lastSame(f.mine, f.mine['2026-10-14']!, '2026-10-14'), '2026-10-07');
      expect(lastSame(f.mine, first, '2026-10-07'), isNull);
      final last = workOf(first.ex.expand((e) => e.logged));
      expect(race(workOf([SetLog(kg: 100, reps: 6)]), last), (600.0, 500.0, true));
      // Bodyweight work races on reps.
      expect(race((0.0, 12), (0.0, 20)), (12.0, 20.0, false));
    });

    test('levels come from XP, each takes 100 more and days off rust the bar', () {
      expect(levelOf(199).level, 1);
      expect(levelOf(200).level, 2);
      expect((levelOf(500).level, levelOf(500).into, levelOf(500).need), (3, 0, 400));
      expect(xpOf(TraineeStats(sets: 10, workouts: 1, sessions: 1, prs: 1, perfect: 1)), 480);
      expect([rustOf(2), rustOf(3), rustOf(5)], [0, 25, 75]);
    });

    test('rank places the best three main lifts for bodyweight on the tiers', () {
      final f = Fresh(wed)..store.createProfile(Role.solo, const ProfileInput(name: 'Dani'));
      final t = f.data.trainees.single;
      expect(rankName(rankOf(t, f.mine).step), 'Bodyweight');
      t.body
        ..weightKg = 80
        ..sex = 'm';
      expect(rankOf(t, f.mine).placed, isFalse);
      // Bench at bodyweight is where Intermediate starts.
      t.maxes['Bench Press'] = 80;
      expect(rankName(rankOf(t, f.mine).step), 'Steel II');
      t.maxes
        ..['Back Squat'] = 200
        ..['Deadlift'] = 250;
      final r = rankOf(t, f.mine);
      expect(rankName(r.step), 'Platinum I');
      expect(r.lifts.map((l) => l.name), ['Deadlift', 'Back Squat', 'Bench Press']);
      expect(nextStep(r, t.body), ('Back Squat', 17.5));
      t.maxes
        ..['Bench Press'] = 400
        ..['Back Squat'] = 400
        ..['Deadlift'] = 400;
      expect(rankName(rankOf(t, f.mine).step), 'Olympia');
      expect(nextStep(rankOf(t, f.mine), t.body), isNull);
    });

    test('days logged as done count toward the rank with their planned numbers', () {
      final f = Fresh(wed)..store.createProfile(Role.solo, const ProfileInput(name: 'Dani', split: 'ppl'));
      final t = f.data.trainees.single;
      t.body
        ..weightKg = 80
        ..sex = 'm';
      f.store.addFromRotation(Account.ownerId, '2026-10-12');
      f.store.setTemplate(Account.ownerId, '2026-10-12', 'push');
      expect(rankOf(t, f.mine).placed, isFalse);
      f.store.logPast('2026-10-12');
      // Push plans Bench Press 70 kg for 6-8: 6 reps, about 84 kg.
      expect(plannedMax(f.mine, 'Bench Press'), closeTo(84, .01));
      final r = rankOf(t, f.mine);
      expect(r.placed, isTrue);
      expect(r.lifts.map((l) => l.name), containsAll(['Bench Press', 'Overhead Press']));
      // A ticked heavier set wins, and a max set by hand wins over both.
      f.mine['2026-10-12']!.ex.first.logged.add(SetLog(kg: 90, reps: 3));
      expect(rankOf(t, f.mine).lifts.firstWhere((l) => l.name == 'Bench Press').maxKg, closeTo(99, .01));
      t.maxes['Bench Press'] = 60;
      expect(rankOf(t, f.mine).lifts.firstWhere((l) => l.name == 'Bench Press').maxKg, 60);
    });

    test('a new rank is celebrated once', () {
      final f = Fresh(wed)..store.createProfile(Role.solo, const ProfileInput(name: 'Dani'));
      final t = f.data.trainees.single;
      t.body
        ..weightKg = 80
        ..sex = 'm';
      // A new profile starts at Bodyweight, so placing is a rank up.
      expect(f.data.settings.rankSeen, 0);
      expect(f.store.rankUp(), isNull);
      t.maxes['Bench Press'] = 80;
      expect(f.store.rankUp(), 11);
      expect(f.store.rankUp(), isNull);
      // A save from before ranks only remembers where it stands.
      f.data.settings.rankSeen = null;
      t.maxes['Back Squat'] = 200;
      expect(f.store.rankUp(), isNull);
      expect(f.data.settings.rankSeen, greaterThan(11));
    });

    test('a new level is celebrated once', () {
      final f = lifted();
      final stats = f.data.trainees.single.stats;
      // One set, one workout and a perfect week: 260 XP.
      expect(xpOf(stats), 260);
      expect(f.store.levelUp(), 2);
      expect(f.store.levelUp(), isNull);
      stats.sets += 30;
      expect(f.store.levelUp(), 3);
      // A save from before levels starts where it stands.
      f.data.settings.levelSeen = null;
      stats.sets += 40;
      expect(f.store.levelUp(), isNull);
      expect(f.data.settings.levelSeen, 4);
    });

    test('muscles recover in 3 days for legs and back, 2 for the rest', () {
      final f = Fresh()..store.createProfile(Role.solo, const ProfileInput(name: 'Dani', split: 'ppl'));
      f.store.addFromRotation(Account.ownerId, '2026-10-13');
      f.store.setTemplate(Account.ownerId, '2026-10-13', 'legs');
      f.store.logPast('2026-10-13');
      f.store.addFromRotation(Account.ownerId, '2026-10-12');
      f.store.setTemplate(Account.ownerId, '2026-10-12', 'push');
      f.store.logPast('2026-10-12');
      final r = recovery(f.mine, '2026-10-14');
      expect(r['quads'], closeTo(1 / 3, .01));
      expect(r['chest'], 1.0);
      expect(r.containsKey('biceps'), isFalse);
      expect(recovery(f.mine, '2026-10-16')['quads'], 1.0);
    });

    test('forearms count a share of curls, pulls and presses', () {
      final f = Fresh()..store.createProfile(Role.solo, const ProfileInput(name: 'Dani', split: 'ppl'));
      f.store.addFromRotation(Account.ownerId, '2026-10-12');
      f.store.setTemplate(Account.ownerId, '2026-10-12', 'push');
      f.store.logPast('2026-10-12');
      expect(muscleSets(f.mine, '2026-10-12', '2026-10-19')['forearms'], 4);
      f.store.addFromRotation(Account.ownerId, '2026-10-13');
      f.store.setTemplate(Account.ownerId, '2026-10-13', 'pull');
      f.store.logPast('2026-10-13');
      final sets = muscleSets(f.mine, '2026-10-12', '2026-10-19');
      // 16 pressing sets × ¼, 13 pulling sets × ¼ and 3 curl sets × ½.
      expect(sets['forearms'], 9);
      expect(sets['biceps'], 3);
    });
  });

  group('your standard', () {
    test('typed loads get kg and max reps stay max', () {
      expect(withKg('15'), '15 kg');
      expect(withKg('72,5'), '72.5 kg');
      expect(withKg('15 kg'), '15 kg');
      expect(withKg('BW'), 'BW');
      expect(withMax('MAX'), 'max');
      expect(withMax('8-10'), '8-10');
      expect(lowReps('8-10'), 8);
      expect(lowReps('max'), isNull);
      expect(targetReps('max'), isNull);
    });

    test('changed and custom templates are your own', () {
      final f = Fresh()..store.createProfile(Role.solo, const ProfileInput(name: 'Dani', split: 'ppl'));
      expect(f.data.tpls.values.where(isOwnTemplate), isEmpty);
      f.store.edit(const TemplateTarget('push'), () => f.data.tpls['push']!.ex.first.load = '75 kg');
      final id = f.store.newTemplate();
      expect(f.data.tpls.values.where(isOwnTemplate).map((t) => t.id), ['push', id]);

      // Taken off the list, kept as it is; saving it brings it back.
      f.store.hideTemplate('push');
      expect(f.data.tpls.values.where(isOwnTemplate).map((t) => t.id), [id]);
      expect(f.data.tpls['push']!.ex.first.load, '75 kg');
      expect(WorkoutTemplate.fromJson(f.data.tpls['push']!.toJson()).hidden, isTrue);
      f.store.saveEdit(const TemplateTarget('push'));
      expect(isOwnTemplate(f.data.tpls['push']!), isTrue);
    });

    test('a workout stands against its template and can become the standard', () {
      final f = Fresh()..store.createProfile(Role.solo, const ProfileInput(name: 'Dani', split: 'ppl'));
      f.store.addFromRotation(Account.ownerId, '2026-10-12');
      f.store.setTemplate(Account.ownerId, '2026-10-12', 'push');
      f.store.logPast('2026-10-12');
      final s = f.mine['2026-10-12']!;
      // The standard is 4 × 6-8 at 70 kg: 70 kg × 6.
      s.ex.first.logged.addAll([SetLog(kg: 75, reps: 6), SetLog(kg: 75, reps: 6), SetLog(kg: 80, reps: 5)]);
      final vs = vsStandard(f.data.tpls['push']!, s).single;
      expect([vs.name, vs.stdKg, vs.stdReps, vs.doneKg, vs.doneReps], ['Bench Press', 70, 6, 80, 5]);
      expect(vs.pct, closeTo(80 * (1 + 5 / 30) / (70 * (1 + 6 / 30)) - 1, 1e-9));
      expect(standardText(vs.pct), '11% above your standard');
      expect(standardDays(f.mine, 'push'), ['2026-10-12']);

      f.store.setStandard('push', '2026-10-12');
      final bench = f.data.tpls['push']!.ex.first;
      expect([bench.sets, bench.load, bench.reps, bench.loadFor(2), bench.repsFor(2)], [3, '75 kg', '6', '80 kg', '5']);
      expect(overallPct(vsStandard(f.data.tpls['push']!, s)), closeTo(0, 1e-9));
    });
  });

  group('rest days', () {
    test('days off count back to the last workout, today once marked', () {
      final f = Fresh()..store.createProfile(Role.solo, const ProfileInput(name: 'Dani', split: 'ppl'));
      final rest = f.data.trainees.single.stats.rest;
      int off() => daysOff(f.mine, const [], rest, f.store.now);
      expect(off(), 0);
      expect(f.store.addFromRotation(Account.ownerId, '2026-10-10'), isTrue);
      f.store.logPast('2026-10-10');
      // 11, 12 and 13 October; today is not over yet.
      expect(off(), 3);
      f.store.toggleRest('2026-10-14');
      expect(f.toast, 'Rest day · recover well');
      expect(off(), 4);
      f.store.toggleRest('2026-10-14');
      expect(f.toast, 'Rest day cleared');
      expect(off(), 3);
    });

    test('a rest day replaces a planned session but never a logged one', () {
      final f = Fresh()..store.createProfile(Role.solo, const ProfileInput(name: 'Dani'), autoPlan: true);
      final rest = f.data.trainees.single.stats.rest;
      final k = (f.mine.keys.where((k) => k.compareTo('2026-10-14') >= 0).toList()..sort()).first;
      f.store.toggleRest(k);
      expect(f.mine[k], isNull);
      expect(rest, {k});
      // Adding a workout back clears the rest mark.
      expect(f.store.addFromRotation(Account.ownerId, k), isTrue);
      expect(rest, isEmpty);
      f.store.addFromRotation(Account.ownerId, '2026-10-07');
      f.store.logPast('2026-10-07');
      f.store.toggleRest('2026-10-07');
      expect(f.mine['2026-10-07']!.status, SessionStatus.done);
      expect(rest, isEmpty);
    });

    test('3 days off schedule nudges, louder from 5, quiet in the gym', () {
      final n = _Reminders();
      final f = Fresh(wed, n)..store.createProfile(Role.solo, const ProfileInput(name: 'Dani', split: 'ppl'));
      f.store.addFromRotation(Account.ownerId, '2026-10-10');
      f.store.logPast('2026-10-10');
      String at(Reminder r) => '${dk(r.at)} ${hm(r.at)}';
      expect(
        [for (final r in n.last.take(4)) '${at(r)} ${r.title}'],
        [
          '2026-10-14 09:00 3 days off',
          '2026-10-15 09:00 4 days off',
          '2026-10-16 09:00 5 days off',
          '2026-10-16 16:00 Still time to train today',
        ],
      );
      f.store.scan();
      expect(n.last.where((r) => dk(r.at) == '2026-10-14'), isEmpty);
      f.clock = wed.add(const Duration(minutes: 72));
      f.store.scan();
      // Trained today, so the next nudge is three days off later.
      expect(at(n.last.first), '2026-10-18 09:00');
      expect(n.last.first.title, '3 days off');
    });

    test('the owner\'s notices move reminder times and push to the right people', () {
      final n = _Reminders();
      final f = Fresh(wed, n)..store.createProfile(Role.solo, const ProfileInput(name: 'Dani', split: 'ppl'));
      f.store.addFromRotation(Account.ownerId, '2026-10-10');
      f.store.logPast('2026-10-10');
      String at(Reminder r) => '${dk(r.at)} ${hm(r.at)}';
      f.store.applyBoard(
        Board.fromJson({
          'times': {'nudge': 7 * 60 + 30, 'before': 60, 'checkout': 90, 'brief': 'bad'},
          'pushes': [
            {
              'id': 'a',
              'title': 'Gym closed',
              'titleSr': 'Teretana zatvorena',
              'body': 'Holiday',
              'at': 20 * 60,
              'date': '2026-10-15',
            },
            {
              'id': 'b',
              'title': 'Leg day',
              'at': 7 * 60,
              'days': [1, 3],
              'to': 'solo',
            },
            {'id': 'c', 'title': 'Coaches only', 'at': 9 * 60, 'to': 'coaches'},
            {'title': 'no id'},
          ],
        }),
      );
      expect(f.data.settings.board.times.brief, 8 * 60);
      expect(
        [for (final r in n.last.take(4)) at(r)],
        ['2026-10-14 07:30', '2026-10-15 07:30', '2026-10-16 07:30', '2026-10-16 17:00'],
      );
      // Today is Wednesday 18:00: today's 07:00 push has passed.
      expect(
        [for (final r in f.store.broadcasts().take(4)) '${at(r)} ${r.title}'],
        [
          '2026-10-15 20:00 Gym closed',
          '2026-10-19 07:00 Leg day',
          '2026-10-21 07:00 Leg day',
          '2026-10-26 07:00 Leg day',
        ],
      );
      f.store.setLanguage(AppLang.sr);
      expect(f.store.broadcasts().first.title, 'Teretana zatvorena');
      f.store.setLanguage(AppLang.en);
      f.store.scan();
      // Checked in at 18:00, the check-out reminder comes 90 minutes later.
      expect(f.data.settings.board.times.checkout, 90);
    });

    test('each set can have its own reps and load, carried into planned days', () {
      final f = Fresh()..store.createProfile(Role.solo, const ProfileInput(name: 'Dani', split: 'ppl'));
      final e = f.data.tpls['push']!.ex.first
        ..sets = 4
        ..load = '70 kg';
      e.planSet(1, load: '75 kg');
      e.planSet(2, load: '80 kg', reps: '6');
      e.planSet(3, load: '85 kg', reps: '4');
      expect([for (var i = 0; i < 4; i++) e.loadFor(i)], ['70 kg', '75 kg', '80 kg', '85 kg']);
      expect((e.repsFor(1), e.repsFor(2)), (e.reps, '6'));
      expect(e.perSet, isTrue);
      e.planSet(1, load: '');
      expect(e.loadFor(1), '70 kg');

      f.store.addFromRotation(Account.ownerId, '2026-10-15');
      f.store.setTemplate(Account.ownerId, '2026-10-15', 'push');
      final s = f.mine['2026-10-15']!.ex.first;
      expect(s.loadFor(3), '85 kg');
      final t = f.data.trainees.single;
      expect((setKg(t, f.mine, s, 0), setKg(t, f.mine, s, 2)), (null, 80.0));
      final back = Exercise.fromJson(jsonDecode(jsonEncode(s.toJson())) as Map<String, dynamic>);
      expect((back.loadFor(2), back.repsFor(3)), ('80 kg', '4'));
    });

    test('the warm-up follows what the workout trains', () {
      final f = Fresh()..store.createProfile(Role.solo, const ProfileInput(name: 'Dani', split: 'ppl'));
      f.store.addFromRotation(Account.ownerId, '2026-10-15');
      f.store.setTemplate(Account.ownerId, '2026-10-15', 'push');
      final (mins, steps) = warmupPlan(f.mine['2026-10-15']!);
      expect(steps.first, '5 minutes easy cardio: bike, rower or incline walk.');
      expect(steps, contains('Shoulders: 15 arm circles, 15 band pull-aparts, 10 push-ups.'));
      expect(steps.any((x) => x.startsWith('Legs')), isFalse);
      expect(steps.last, startsWith('Then 2-3 lighter ramp-up sets of '));
      expect(mins, 8);
      f.store.setTemplate(Account.ownerId, '2026-10-15', 'full');
      expect(warmupPlan(f.mine['2026-10-15']!).$1, greaterThan(8));
    });

    test('a season runs 8 weeks from this Monday and counts its workouts', () {
      final f = lifted();
      expect(f.store.currentSeason(), isNull);
      f.store.startSeason('', 3);
      final s = f.store.currentSeason()!;
      expect((s.n, s.name, s.start, s.end, s.goal), (1, 'Season 1', '2026-10-12', '2026-12-07', 24));
      expect([s.week('2026-10-14'), s.week('2026-10-19'), s.week('2026-12-06')], [1, 2, 8]);
      // The workout on 7 October was before it.
      expect(seasonProgress(s, f.mine), (0, 0));
      f.store.addFromRotation(Account.ownerId, '2026-10-13');
      f.store.logPast('2026-10-13');
      expect(seasonProgress(s, f.mine), (1, 0));
      final back = Trainee.fromJson(jsonDecode(jsonEncode(f.data.trainees.single.toJson())) as Map<String, dynamic>);
      expect(back.seasons.single.toJson(), s.toJson());
      f.clock = DateTime(2026, 12, 8, 18);
      expect(f.store.currentSeason(), isNull);
      f.store.startSeason('Cut', 4);
      expect((f.store.currentSeason()!.n, f.store.currentSeason()!.name), (2, 'Cut'));
      f.store.stopSeason();
      expect(f.store.currentSeason(), isNull);
    });

    test('training days get a morning brief with what to beat', () {
      final n = _Reminders();
      final f = Fresh(DateTime(2026, 10, 7, 18), n)
        ..store.createProfile(Role.solo, const ProfileInput(name: 'Dani', split: 'fb'));
      f.store.addFromRotation(Account.ownerId, '2026-10-07');
      f.store.startWorkout('2026-10-07');
      final e = f.mine['2026-10-07']!.ex.first;
      f.store.logSet(e.id, 0, SetLog(kg: 100, reps: 99));
      f.store.finish();
      f.clock = wed;
      f.store.addFromRotation(Account.ownerId, '2026-10-15');
      f.store.setTemplate(Account.ownerId, '2026-10-15', f.mine['2026-10-07']!.tpl);
      final brief = n.last.firstWhere((r) => r.at == DateTime(2026, 10, 15, 8));
      expect(brief.title, 'Today: ${f.mine['2026-10-15']!.title}');
      // Every rep was hit last time, so the weight goes up.
      expect(brief.body, contains('Go for'));
      expect(brief.body, contains(e.name));
      f.store.toggleSetting('brief');
      expect(n.last.where((r) => r.at.hour == 8), isEmpty);
      expect(n.last.where((r) => r.at == DateTime(2026, 10, 15, 16)), hasLength(1));
    });

    test('rest days survive a JSON round trip', () {
      final s = TraineeStats(rest: {'2026-10-12'});
      expect(TraineeStats.fromJson(jsonDecode(jsonEncode(s.toJson())) as Map<String, dynamic>).rest, {'2026-10-12'});
    });
  });

  group('coach and trainee on two phones', () {
    test('plan goes out, progress comes back', () {
      final coach = Fresh()..store.createProfile(Role.coach, const ProfileInput(name: 'Marko Ilić'));
      final tid = coach.store.addTrainee(const ProfileInput(name: 'Ana Marić', split: 'ppl'));
      coach.store.autoFill(tid);
      final plan = coach.store.sendDrafts(tid)!;

      final ana = Fresh()..store.createProfile(Role.trainee, const ProfileInput(name: 'Ana'));
      expect(ana.store.importText('Hi!\n$plan'), isNull);
      expect(ana.toast, '8 sessions from Marko · 8 waiting for your OK');
      expect(ana.data.linkId, tid);
      expect(ana.data.trainees.single.coachName, 'Marko Ilić');
      expect(ana.mine.values.every((s) => s.byCoach && s.status == SessionStatus.pending), isTrue);

      ana.store.accept('2026-10-14');
      ana.store.accept('2026-10-16');
      ana.store.move('2026-10-16', '2026-10-17');
      ana.store.startWorkout('2026-10-14');
      ana.store.toggleSet(ana.mine['2026-10-14']!.ex.first.id, 0);
      ana.store.finish();
      ana.store.reportInjury(Account.ownerId, 'knee', 'Twinge on lunges');
      ana.store.saveProfile(Account.ownerId, ProfileInput(name: 'Ana', body: Body(weightKg: 61)));

      expect(coach.store.importText(ana.store.updateMessage()), isNull);
      final p = coach.data.plans[tid]!;
      expect(p['2026-10-14']!.status, SessionStatus.done);
      expect(p['2026-10-14']!.log, '1/16 sets');
      expect(p['2026-10-16'], isNull);
      expect(p['2026-10-17']!.status, SessionStatus.moved);
      expect(p['2026-10-17']!.from, '2026-10-16');
      final t = coach.store.tr(tid);
      expect(t.injuries.single.fresh, isTrue);
      expect(t.body.weightKg, 61);
      expect(coach.toast, 'Update from Ana · 0 confirmed, 1 moved, 1 done');

      // The coach OKs the move; a second import of the same update keeps it.
      coach.store.ack(tid, '2026-10-17');
      coach.store.importText(ana.store.updateMessage());
      expect(p['2026-10-17']!.status, SessionStatus.approved);
    });

    test('a coach high five reaches the trainee with the next plan', () {
      final coach = Fresh()..store.createProfile(Role.coach, const ProfileInput(name: 'Marko'));
      final tid = coach.store.addTrainee(const ProfileInput(name: 'Ana', split: 'ppl'));
      coach.store.autoFill(tid);
      final ana = Fresh()..store.createProfile(Role.trainee, const ProfileInput(name: 'Ana'));
      ana.store.importText(coach.store.sendDrafts(tid)!);
      ana.store.accept('2026-10-14');
      ana.store.startWorkout('2026-10-14');
      ana.store.toggleSet(ana.mine['2026-10-14']!.ex.first.id, 0);
      ana.store.finish();
      coach.store.importText(ana.store.updateMessage());

      // Only done days take a high five; the same one again takes it back.
      coach.store.cheer(tid, '2026-10-16', '🔥');
      expect(coach.data.plans[tid]!['2026-10-16']!.cheer, isNull);
      coach.store.cheer(tid, '2026-10-14', '🔥');
      coach.store.cheer(tid, '2026-10-14', '🔥');
      expect(coach.data.plans[tid]!['2026-10-14']!.cheer, isNull);
      coach.store.cheer(tid, '2026-10-14', '💪');

      expect(ana.store.importText(coach.store.planMessage(tid)), isNull);
      expect(ana.mine['2026-10-14']!.cheer, '💪');
      expect(ana.toast, endsWith(' · 1 high five'));
      // The same plan again brings nothing new.
      ana.store.importText(coach.store.planMessage(tid));
      expect(ana.toast, isNot(contains('high five')));
    });

    test('re-importing a plan keeps days the trainee moved or did', () {
      final coach = Fresh()..store.createProfile(Role.coach, const ProfileInput(name: 'Marko'));
      final tid = coach.store.addTrainee(const ProfileInput(name: 'Ana', split: 'ppl'));
      coach.store.autoFill(tid);
      final plan = coach.store.sendDrafts(tid)!;
      final ana = Fresh()..store.createProfile(Role.trainee, const ProfileInput(name: 'Ana'));
      ana.store.importText(plan);
      ana.store.accept('2026-10-16');
      ana.store.move('2026-10-16', '2026-10-18');
      ana.store.addFromRotation(Account.ownerId, '2026-10-20');
      ana.store.importText(plan);
      expect(ana.mine['2026-10-16'], isNull);
      expect(ana.mine['2026-10-18']!.status, SessionStatus.moved);
      // Her own session stays.
      expect(ana.mine['2026-10-20']!.byCoach, isFalse);
    });

    test('wrong codes explain themselves', () {
      final coach = Fresh()..store.createProfile(Role.coach, const ProfileInput(name: 'Marko'));
      final tid = coach.store.addTrainee(const ProfileInput(name: 'Ana'));
      coach.store.autoFill(tid);
      final plan = coach.store.sendDrafts(tid)!;
      expect(coach.store.importText('hello'), 'No Bolt code found in the copied text.');
      expect(coach.store.importText(plan), 'This is a plan for a trainee. Open it on their phone.');
      expect(coach.store.importText('BOLT1.AAAA'), 'That code looks damaged. Copy the whole message again.');
      final solo = Fresh()..store.createProfile(Role.solo, const ProfileInput(name: 'Dani'));
      expect(solo.store.updateMessage(), contains('BOLT1.'));
      final other = Fresh()..store.createProfile(Role.coach, const ProfileInput(name: 'Sara'));
      expect(
        other.store.importText(solo.store.updateMessage()),
        'This update is from someone who is not in your trainees. Send them a plan first.',
      );
    });
  });

  test('saved demo data from 1.0 is discarded', () {
    final dir = Directory.systemTemp.createTempSync('bolt');
    final file = File('${dir.path}/bolt.json');
    final old = buildDemoData(wed).toJson()..['version'] = 1;
    file.writeAsStringSync(jsonEncode(old));
    expect(BoltRepository(file).load(), isNull);
    final cur = freshData()..account = const Account(Role.solo, 'me');
    file.writeAsStringSync(jsonEncode(cur.toJson()));
    expect(BoltRepository(file).load()!.account!.role, Role.solo);
    dir.deleteSync(recursive: true);
  });

  test('saves queue up and the newest one lands on disk', () async {
    final dir = Directory.systemTemp.createTempSync('bolt');
    final repo = BoltRepository(File('${dir.path}/bolt.json'));
    for (final r in [Role.coach, Role.trainee, Role.solo]) {
      repo
        ..scheduleSave(freshData()..account = Account(r, 'me'))
        ..flush();
    }
    await repo.saved;
    expect(BoltRepository(File('${dir.path}/bolt.json')).load()!.account!.role, Role.solo);
    dir.deleteSync(recursive: true);
  });

  test('body units convert both ways', () {
    expect(fmtWeight(80, metric: false), '176.4 lb');
    expect(parseWeight('176.4', metric: false)!, closeTo(80, .05));
    expect(fmtLength(84, metric: false), '33.1 in');
    expect(parseLength('84,5', metric: true), 84.5);
    expect(parseWeight('', metric: true), isNull);
  });
}

/// Keeps the last scheduled reminders.
class _Reminders extends NoopNotifications {
  List<Reminder> last = const [];

  @override
  Future<void> replaceSessionReminders(List<Reminder> list) async => last = list;
}
