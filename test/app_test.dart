import 'dart:io';

import 'package:bolt/app.dart';
import 'package:bolt/app/router.dart';
import 'package:bolt/data/bolt_store.dart';
import 'package:bolt/data/licenses.dart';
import 'package:bolt/data/models/board.dart';
import 'package:bolt/data/models/bolt_data.dart';
import 'package:bolt/data/models/exercise.dart';
import 'package:bolt/data/models/session.dart';
import 'package:bolt/data/seed/badges.dart';
import 'package:bolt/data/seed/content.dart';
import 'package:bolt/features/gym/scanner_overlay.dart';
import 'package:bolt/features/updates/update_sheet.dart';
import 'package:bolt/features/workout/lifeline.dart';
import 'package:bolt/services/coach_directory.dart';
import 'package:bolt/services/notice_board.dart';
import 'package:bolt/services/updater.dart';
import 'package:bolt/widgets/common.dart';
import 'package:bolt/widgets/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Wednesday 14 Oct 2026, 18:00.
final wed = DateTime(2026, 10, 14, 18);

/// Answers update checks without the network.
class FakeUpdater extends Updater {
  FakeUpdater(this.result);

  final CheckResult result;

  @override
  Future<Installed> installed() async => const Installed('1.2.0', 3);

  @override
  Future<CheckResult> check() async => result;
}

/// Serves the coach list without the network; null means it failed.
class FakeDirectory extends CoachDirectory {
  FakeDirectory(this.coaches);

  final List<ListedCoach>? coaches;

  @override
  Future<List<ListedCoach>?> fetch() async => coaches;
}

/// Holds the owner's notices in memory instead of GitHub.
class FakeBoard extends NoticeBoard {
  Board? published;
  String? saved;

  @override
  Future<Board?> fetch() async => published;

  @override
  Future<String?> publish(Board b, String token) async {
    published = Board.fromJson(b.toJson());
    return null;
  }

  @override
  Future<String?> token() async => saved;

  @override
  Future<void> saveToken(String? t) async => saved = t;
}

Future<ProviderContainer> pumpApp(
  WidgetTester tester, {
  BoltData? data,
  Updater? updater,
  List<ListedCoach>? coaches = const [],
  FakeBoard? board,
}) async {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 2.75;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        clockProvider.overrideWithValue(() => wed),
        initialDataProvider.overrideWithValue(data ?? freshData()),
        updaterProvider.overrideWithValue(updater ?? FakeUpdater(const UpToDate())),
        coachDirectoryProvider.overrideWithValue(FakeDirectory(coaches)),
        noticeBoardProvider.overrideWithValue(board ?? FakeBoard()),
        // Test codes; the real ones are not in the source.
        licenseProvider.overrideWithValue(
          (c) => switch (c) {
            '11111' => License.coach,
            '222222' => License.admin,
            _ => null,
          },
        ),
        coachSlotProvider.overrideWithValue((c) => c == '11111' ? 0 : null),
      ],
      child: const BoltApp(),
    ),
  );
  await tester.pump(const Duration(milliseconds: 500));
  return ProviderScope.containerOf(tester.element(find.byType(BoltApp)));
}

/// Unmounts the app so its timers and animations stop.
Future<void> unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 3));
}

/// Lets transitions finish. A pushed route stays offstage for its first frame
/// (hero measurement), so pump once before advancing time.
Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
}

Future<void> tapText(WidgetTester tester, String text) async {
  final f = find.text(text).first;
  await tester.ensureVisible(f);
  await tester.tap(f);
  await settle(tester);
}

/// Taps a bottom nav button. They show icons only, so they are found by the
/// label screen readers hear.
Future<void> tapTab(WidgetTester tester, String label) async {
  await tester.tap(find.byWidgetPredicate((w) => w is Semantics && w.properties.label == label).first);
  await settle(tester);
}

/// The phone's volume down key, as Android sends it during a workout.
Future<void> volumeDown(WidgetTester tester) async {
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    'bolt/screen',
    const StandardMethodCodec().encodeMethodCall(const MethodCall('volumeDown')),
    (_) {},
  );
  await settle(tester);
}

/// The page's own back button.
Future<void> back(WidgetTester tester) async {
  await tester.tap(find.byType(BackBox).first);
  await settle(tester);
}

Future<void> typeInto(WidgetTester tester, String hint, String text) async {
  await tester.enterText(find.widgetWithText(TextField, hint), text);
  await tester.pump();
}

Future<void> loadFont(String family, String path) async {
  final bytes = ByteData.sublistView(File(path).readAsBytesSync());
  await (FontLoader(family)..addFont(Future.value(bytes))).load();
}

/// The centre button opens the quick screen; the scanner is one tap on.
Future<void> openScanner(WidgetTester tester) async {
  await tapTab(tester, 'Check in');
  await tapText(tester, 'Scan QR');
}

/// Goes through onboarding as [role] with [name]. Coaches enter [code].
Future<void> onboard(WidgetTester tester, String role, String name, {String? weight, String code = '11111'}) async {
  expect(find.text('HOW DO YOU TRAIN?'), findsOneWidget);
  await tapText(tester, role);
  if (role == 'I coach people') {
    await typeInto(tester, '5-digit code', code);
    await tapText(tester, 'Unlock');
  }
  await typeInto(tester, 'Your name', name);
  await tapText(tester, 'Continue');
  expect(find.text('Your body'), findsOneWidget);
  if (weight != null) await typeInto(tester, 'Weight (kg)', weight);
  await tapText(tester, role == 'I coach people' ? 'Start coaching' : 'Start training');
  // Today's cards rise in one after another; let them land.
  await tester.pump(const Duration(milliseconds: 600));
}

void main() {
  // Real fonts, so text measures like on a device.
  setUpAll(() async {
    await loadFont('Archivo', 'assets/fonts/Archivo-Variable.ttf');
    await loadFont('JetBrains Mono', 'assets/fonts/JetBrainsMono-Variable.ttf');
  });

  testWidgets('solo onboarding plans the weeks and keeps the body data', (tester) async {
    final c = await pumpApp(tester);
    await onboard(tester, 'On my own', 'Dani Kovač', weight: '81.5');
    expect(find.text('Hey Dani'), findsOneWidget);
    expect(find.text('PULL'), findsOneWidget);
    expect(c.read(boltProvider).trainees.single.body.weightKg, 81.5);

    await tapTab(tester, 'Me');
    expect(find.text('Training solo'), findsOneWidget);
    expect(find.text('81.5 kg'), findsOneWidget);
    expect(find.text('Your coach'), findsNothing);
    await unmount(tester);
  });

  testWidgets('Atlas opens from Me, badges sit on Today', (tester) async {
    await pumpApp(tester);
    await onboard(tester, 'On my own', 'Dani');
    expect(find.text('ACHIEVEMENTS'), findsOneWidget);
    expect(find.text('0 / ${kBadges.length}'), findsOneWidget);
    expect(find.text('Next: First Rep'), findsOneWidget);
    await tapText(tester, 'ACHIEVEMENTS');
    expect(find.text('Trophy rack'), findsOneWidget);
    await tester.tap(find.text('‹'));
    await settle(tester);

    await tapTab(tester, 'Me');
    await tapText(tester, 'Atlas');
    expect(find.text('Train smarter'), findsOneWidget);
    await tapText(tester, 'Move');
    expect(find.text('Walking'), findsOneWidget);
    expect(find.textContaining('Every extra 1,000 steps a day'), findsOneWidget);
    expect(find.text('Supplements'), findsOneWidget);
    // Opening the Move tab scrolled the back button away.
    await tester.drag(find.byType(ListView).first, const Offset(0, 800));
    await settle(tester);
    await back(tester);
    expect(find.text('Training solo'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('days off push you back to the gym and free days can be marked rest', (tester) async {
    var widget = <Object?, Object?>{};
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(const MethodChannel('bolt/widget'), (call) async {
      widget = call.arguments as Map<Object?, Object?>;
      return true;
    });
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(const MethodChannel('bolt/widget'), null),
    );
    final c = await pumpApp(tester);
    await onboard(tester, 'On my own', 'Dani');
    final store = c.read(boltProvider.notifier);
    store.addFromRotation(Account.ownerId, '2026-10-08');
    store.logPast('2026-10-08');
    if (c.read(boltProvider).plans[Account.ownerId]!['2026-10-18'] != null) {
      store.removeDay(Account.ownerId, '2026-10-18');
    }
    await settle(tester);
    // 9 to 13 October without training.
    expect(find.text('5 DAYS OFF'), findsOneWidget);
    // The home screen widget turns orange today and stays ahead a week.
    await tester.pump(const Duration(milliseconds: 700));
    expect(widget['off_2026-10-14'], '5 DAYS OFF');
    expect(widget['off_2026-10-16'], '7 DAYS OFF');
    expect(widget['off_2026-10-13'], isNull);
    expect(widget['kicker'], '5 DAYS OFF');
    expect(widget['footer'] as String, startsWith('LVL 2 · '));
    expect(find.text('ENOUGH REST.'), findsOneWidget);
    expect(find.text('DAYS OFF'), findsOneWidget);

    await tapText(tester, '18');
    await tapText(tester, 'Mark as rest day');
    expect(c.read(boltProvider).trainees.single.stats.rest, {'2026-10-18'});

    // The calendar shows it, and a long press clears it again.
    await tapTab(tester, 'Plan');
    expect(find.text('REST'), findsOneWidget);
    expect(find.textContaining('Long-press one to mark it as a rest day.'), findsOneWidget);
    await tester.longPress(find.text('18').first);
    await settle(tester);
    expect(c.read(boltProvider).trainees.single.stats.rest, isEmpty);
    expect(find.text('REST'), findsNothing);
    await unmount(tester);
  });

  testWidgets('a check-in on a rest day gives no training advice and shows on the day', (tester) async {
    final c = await pumpApp(tester);
    await onboard(tester, 'On my own', 'Dani');
    final store = c.read(boltProvider.notifier);
    store.dismissHint('new:1.24');
    if (c.read(boltProvider).plans[Account.ownerId]!['2026-10-14'] != null) {
      store.removeDay(Account.ownerId, '2026-10-14');
    }
    await settle(tester);
    await tapText(tester, 'Mark as rest day');
    await tapText(tester, '+');
    await tapText(tester, 'Bad');
    await tapText(tester, 'Low');
    await tapText(tester, 'Down');
    await tapText(tester, 'Very sore');
    await tapText(tester, 'Legs');
    // Nothing is saved until every question has an answer.
    await tapText(tester, 'Save check-in');
    expect(c.read(boltProvider).trainees.single.readiness, isEmpty);
    await tapText(tester, '30%');
    await tapText(tester, 'Save check-in');
    expect(find.text('Low today, so resting is the right call. Sleep well and eat well.'), findsOneWidget);
    expect(find.text('20'), findsOneWidget);
    expect(find.text('Make today lighter'), findsNothing);
    expect(find.textContaining('Take it lighter'), findsNothing);

    // The calendar day shows the check-in.
    await tapTab(tester, 'Plan');
    await tapText(tester, '14');
    expect(find.text('REST DAY'), findsOneWidget);
    expect(find.text('CHECK-IN · LOW'), findsOneWidget);
    expect(
      find.text('Sleep: 8 h, Bad · Energy: Low · Mood: Down · Soreness: Very sore (Legs) · Grip: 30% · Score: 20'),
      findsOneWidget,
    );
    await unmount(tester);
  });

  testWidgets('a season starts from Progress and shows on Today', (tester) async {
    await pumpApp(tester);
    await onboard(tester, 'On my own', 'Dani');
    // The nav shows icons only.
    expect(find.text('Atlas'), findsNothing);
    expect(find.text('LVL 1'), findsOneWidget);
    expect(find.text('RECOVERY'), findsOneWidget);
    expect(find.text('NEW IN BOLT 1.24'), findsOneWidget);
    expect(find.text('Workout page with START'), findsOneWidget);
    await tapText(tester, 'Progress →');
    await tapText(tester, '+ Start a season');
    await tapText(tester, '4');
    await tapText(tester, 'Start season 1');
    expect(find.text('SEASON 1 · WEEK 1 OF 8'), findsOneWidget);
    await tester.tap(find.text('‹'));
    await settle(tester);
    expect(find.text('SEASON 1 · WEEK 1 OF 8'), findsOneWidget);
    expect(find.text('SEASON 1'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('solo users log past days from their diary', (tester) async {
    final c = await pumpApp(tester);
    await onboard(tester, 'On my own', 'Dani');
    await tapTab(tester, 'Plan');
    expect(find.textContaining('Past days too'), findsOneWidget);
    await tapText(tester, '13');
    expect(find.text('Log as done'), findsOneWidget);
    expect(find.text('Edit exercises'), findsOneWidget);
    await tapText(tester, 'Log as done');
    expect(find.text('BADGE UNLOCKED'), findsOneWidget);
    while (find.text('BADGE UNLOCKED').evaluate().isNotEmpty) {
      await tapText(tester, 'Tap to continue');
    }
    // A full logged day is enough for level 2.
    expect(find.text('LEVEL UP'), findsOneWidget);
    expect(find.text('ATHLETE LEVEL'), findsWidgets);
    await tapText(tester, 'Tap to continue');
    await tapTab(tester, 'Today');
    expect(find.text('LVL 2'), findsOneWidget);
    final s = c.read(boltProvider).plans[Account.ownerId]!['2026-10-13']!;
    expect(s.status, SessionStatus.done);
    expect(c.read(boltProvider).trainees.single.stats.workouts, 1);
    await unmount(tester);
  });

  testWidgets('trainees cannot add days behind them', (tester) async {
    final c = await pumpApp(tester);
    await onboard(tester, 'With a coach', 'Ana');
    await tapTab(tester, 'Plan');
    expect(find.textContaining('Past days too'), findsNothing);
    await tapText(tester, '13');
    expect(c.read(boltProvider).plans[Account.ownerId]!['2026-10-13'], isNull);
    await unmount(tester);
  });

  testWidgets('the workout library is a tab for solo users', (tester) async {
    await pumpApp(tester);
    await onboard(tester, 'On my own', 'Dani');
    await tapTab(tester, 'Workouts');
    expect(find.text('LIBRARY'), findsOneWidget);
    expect(find.byType(BackBox), findsNothing);
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });

  testWidgets('a changed workout gets kg, max reps and goes to the top of the library', (tester) async {
    final c = await pumpApp(tester);
    await onboard(tester, 'On my own', 'Dani');
    await tapTab(tester, 'Workouts');
    await tapText(tester, 'Push');
    expect(find.text('VS YOUR STANDARD'), findsOneWidget);
    final bench = c.read(boltProvider).tpls['push']!.ex.first;
    await tester.enterText(find.widgetWithText(TextField, '70 kg').first, '75');
    expect(bench.load, '75 kg');
    FocusManager.instance.primaryFocus?.unfocus();
    await settle(tester);
    expect(tester.widget<TextField>(find.widgetWithText(TextField, '75 kg').first).controller!.text, '75 kg');
    await tapText(tester, 'Max reps');
    expect(bench.reps, 'max');
    await tapText(tester, '‹');
    expect(tester.getTopLeft(find.text('YOUR WORKOUTS')).dy, lessThan(tester.getTopLeft(find.text('CLASSIC')).dy));
    await tapText(tester, '✕');
    expect(find.text('YOUR WORKOUTS'), findsNothing);
    expect(c.read(boltProvider).tpls['push']!.ex.first.load, '75 kg');
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });

  testWidgets('a finished workout shows against its standard and can become it', (tester) async {
    final c = await pumpApp(tester);
    await onboard(tester, 'On my own', 'Dani');
    final store = c.read(boltProvider.notifier);
    store.addFromRotation(Account.ownerId, '2026-10-12');
    store.setTemplate(Account.ownerId, '2026-10-12', 'push');
    store.logPast('2026-10-12');
    c.read(boltProvider).plans[Account.ownerId]!['2026-10-12']!.ex.first.logged.add(SetLog(kg: 80, reps: 5));
    c.read(routerProvider).push('/summary/2026-10-12');
    await settle(tester);
    expect(find.text('▲ 11% above your standard'), findsOneWidget);
    await tapText(tester, 'Done');
    await tapTab(tester, 'Workouts');
    await tapText(tester, 'Push');
    await tapText(tester, '+11%');
    expect(find.text('80 kg × 5 · standard 70 kg × 6'), findsOneWidget);
    await tapText(tester, 'Make this my standard');
    expect(c.read(boltProvider).tpls['push']!.ex.first.load, '80 kg');
    expect(find.text('±0%'), findsOneWidget);
    expect(find.widgetWithText(TextField, '80 kg'), findsWidgets);
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });

  testWidgets('a ticked set starts a rest that can grow, be skipped or run out', (tester) async {
    final c = await pumpApp(tester);
    await onboard(tester, 'On my own', 'Dani');
    final store = c.read(boltProvider.notifier);
    store.addFromRotation(Account.ownerId, '2026-10-14');
    store.setTemplate(Account.ownerId, '2026-10-14', 'push');
    store.startWorkout('2026-10-14');
    c.read(routerProvider).push('/workout/2026-10-14');
    await settle(tester);
    final rest = c.read(boltProvider).settings.restAuto ? null : c.read(boltProvider).settings.restSecs;
    await tapText(tester, 'SET 1');
    expect(find.text('REST'), findsOneWidget);
    final shown = tester.widget<Text>(find.textContaining(RegExp(r'^\d+:\d\d$'))).data!;
    if (rest != null) expect(shown, '${rest ~/ 60}:${(rest % 60).toString().padLeft(2, '0')}');
    await tapText(tester, '+15');
    final longer = tester.widget<Text>(find.textContaining(RegExp(r'^\d+:\d\d$'))).data!;
    int secs(String t) => int.parse(t.split(':')[0]) * 60 + int.parse(t.split(':')[1]);
    expect(secs(longer), secs(shown) + 15);
    await tapText(tester, 'Skip');
    expect(find.text('REST'), findsNothing);

    // The next rest runs out by itself.
    await tapText(tester, 'SET 2');
    expect(find.text('REST'), findsOneWidget);
    await tester.pump(const Duration(minutes: 6));
    await settle(tester);
    expect(find.text('REST'), findsNothing);
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });

  testWidgets('today\'s workout opens ready, then START, warm-up and set by set', (tester) async {
    final c = await pumpApp(tester);
    await onboard(tester, 'On my own', 'Dani');
    await tapText(tester, 'Open workout');
    // Nothing starts until START: the page lists the exercises first.
    expect(find.text('START'), findsOneWidget);
    expect(c.read(boltProvider).workout, isNull);
    final s = c.read(boltProvider).plans[Account.ownerId]!['2026-10-14']!;
    expect(find.text(s.ex.first.name), findsOneWidget);

    await tapText(tester, 'START');
    expect(c.read(boltProvider).workout?.key, '2026-10-14');
    expect(c.read(boltProvider).settings.floor, isTrue);
    expect(find.byType(Lifeline), findsOneWidget);
    expect(find.textContaining('WARM-UP'), findsOneWidget);
    await tapText(tester, 'Warm-up done');
    expect(find.textContaining('SET 1 OF'), findsOneWidget);
    await tapText(tester, 'Done · set 1');
    expect(c.read(boltProvider).workout!.isDone(s.ex.first.id, 0), isTrue);
    expect(find.text('1 / ${s.totalSets} SETS'), findsOneWidget);

    // The rest goes dark with the countdown and the next set; a tap shows
    // the set itself with the same countdown.
    expect(find.byKey(const ValueKey('rest-screen')), findsOneWidget);
    expect(find.text('REST'), findsOneWidget);
    expect(find.textContaining('NEXT · SET'), findsOneWidget);
    await tapText(tester, 'Tap to see the set');
    expect(find.byKey(const ValueKey('rest-screen')), findsNothing);
    expect(find.text('REST'), findsOneWidget);
    await tapText(tester, 'Skip');

    // Volume down logs the next set without looking at the phone.
    await volumeDown(tester);
    final w = c.read(boltProvider).workout!;
    expect(s.ex.fold(0, (a, e) => a + List.generate(e.sets, (j) => w.isDone(e.id, j)).where((x) => x).length), 2);
    expect(find.byKey(const ValueKey('rest-screen')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });

  testWidgets('a workout started by mistake is discarded back to START', (tester) async {
    final c = await pumpApp(tester);
    await onboard(tester, 'On my own', 'Dani');
    await tapText(tester, 'Open workout');
    await tapText(tester, 'START');
    await tapText(tester, 'Warm-up done');
    await tapText(tester, 'Done · set 1');
    await tapText(tester, 'Tap to see the set');
    await tapText(tester, 'Discard workout');
    expect(find.text('Discard this workout?'), findsOneWidget);
    await tester.tap(find.text('Discard workout').last);
    await settle(tester);
    expect(c.read(boltProvider).workout, isNull);
    expect(find.text('START'), findsOneWidget);
    expect(find.text('REST'), findsNothing);
    final s = c.read(boltProvider).plans[Account.ownerId]!['2026-10-14']!;
    expect(s.status, isNot(SessionStatus.done));
    expect(s.ex.every((e) => e.logged.isEmpty), isTrue);
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });

  testWidgets('a done workout is deleted from its day', (tester) async {
    final c = await pumpApp(tester);
    await onboard(tester, 'On my own', 'Dani');
    final store = c.read(boltProvider.notifier);
    store.startWorkout('2026-10-14');
    final s = c.read(boltProvider).plans[Account.ownerId]!['2026-10-14']!;
    store.logSet(s.ex.first.id, 0, SetLog(kg: 60, reps: 8));
    store.finish();
    await settle(tester);
    expect(c.read(boltProvider).trainees.single.stats.workouts, 1);
    await tapTab(tester, 'Plan');
    await tapText(tester, '14');
    await tapText(tester, 'Delete workout');
    expect(find.text('Delete this workout?'), findsOneWidget);
    await tester.tap(find.text('Delete workout').last);
    await settle(tester);
    expect(c.read(boltProvider).plans[Account.ownerId]!['2026-10-14'], isNull);
    expect(c.read(boltProvider).trainees.single.stats.workouts, 0);
    expect(find.text('Delete this workout?'), findsNothing);
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });

  testWidgets('sets start from last time and gym floor mode logs with steppers', (tester) async {
    final c = await pumpApp(tester);
    await onboard(tester, 'On my own', 'Dani');
    final store = c.read(boltProvider.notifier);
    store.addFromRotation(Account.ownerId, '2026-10-12');
    store.setTemplate(Account.ownerId, '2026-10-12', 'push');
    store.logPast('2026-10-12');
    c.read(boltProvider).plans[Account.ownerId]!['2026-10-12']!.ex.first.logged.addAll([
      SetLog(kg: 80, reps: 6),
      SetLog(kg: 82.5, reps: 5),
      SetLog(kg: 85, reps: 3),
    ]);
    store.addFromRotation(Account.ownerId, '2026-10-14');
    store.setTemplate(Account.ownerId, '2026-10-14', 'push');
    store.startWorkout('2026-10-14');
    c.read(routerProvider).push('/workout/2026-10-14');
    await settle(tester);
    final bench = c.read(boltProvider).plans[Account.ownerId]!['2026-10-14']!.ex.first;
    SetLog log(int j) => c.read(boltProvider).workout!.log(bench.id, j)!;

    // A quick tick takes exactly what set 1 was last time.
    await tapText(tester, 'SET 1');
    expect((log(0).kg, log(0).reps), (80.0, 6));
    await tapText(tester, 'Skip');

    // Gym floor mode picks up at set 2, from last time's set 2.
    await tapText(tester, 'GYM FLOOR');
    expect(c.read(boltProvider).settings.floor, isTrue);
    expect(find.text('SET 2 OF 4'), findsOneWidget);
    expect(find.text('82.5'), findsOneWidget);
    expect(find.text('Last Mon 12 Oct: 80×6 · 82.5×5 · 85×3 kg'), findsOneWidget);
    await tester.tap(find.text('+').first);
    await tester.pump();
    expect(find.text('85'), findsOneWidget);
    await tapText(tester, 'Done · set 2');
    expect((log(1).kg, log(1).reps), (85.0, 5));
    // 85 kg beats last time's best, so its record moment comes first.
    expect(find.text('NEW PR'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    await tapText(tester, 'Tap to continue');
    expect(find.text('REST'), findsOneWidget);
    await tapText(tester, 'Skip');

    // Going 2.5 kg heavier on set 2 carries over to set 3.
    expect(find.text('SET 3 OF 4'), findsOneWidget);
    expect(find.text('87.5'), findsOneWidget);
    await tapText(tester, 'LIST');
    expect(c.read(boltProvider).settings.floor, isFalse);
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });

  testWidgets('everyone starts at Bodyweight and a new max ranks you up', (tester) async {
    final c = await pumpApp(tester);
    await onboard(tester, 'On my own', 'Dani');
    expect(find.text('BODYWEIGHT'), findsOneWidget);
    expect(find.text('Add your bodyweight and sex to get placed'), findsOneWidget);
    c.read(boltProvider).trainees.single.body
      ..weightKg = 80
      ..sex = 'm';
    c.read(routerProvider).push('/lift/Bench Press');
    await settle(tester);
    await tapText(tester, 'Set max');
    await typeInto(tester, 'Bench Press', '80');
    await tapText(tester, 'Save');
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('RANK UP'), findsOneWidget);
    expect(find.text('STEEL II'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    await tapText(tester, 'Tap to continue');
    c.read(routerProvider).push('/rank');
    await settle(tester);
    expect(find.text('Share my rank'), findsOneWidget);
    expect(find.text('What counts'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });

  testWidgets('a record set gets its moment with confetti', (tester) async {
    final c = await pumpApp(tester);
    await onboard(tester, 'On my own', 'Dani');
    final store = c.read(boltProvider.notifier);
    store.addFromRotation(Account.ownerId, '2026-10-12');
    store.setTemplate(Account.ownerId, '2026-10-12', 'push');
    store.logPast('2026-10-12');
    c.read(boltProvider).plans[Account.ownerId]!['2026-10-12']!.ex.first.logged.add(SetLog(kg: 80, reps: 5));
    store.addFromRotation(Account.ownerId, '2026-10-14');
    store.setTemplate(Account.ownerId, '2026-10-14', 'push');
    store.toggleSetting('floor');
    store.startWorkout('2026-10-14');
    c.read(routerProvider).push('/workout/2026-10-14');
    await settle(tester);
    await tapText(tester, 'Warm-up done');
    await tester.tap(find.text('+').first);
    await tester.pump();
    await tapText(tester, 'Done · set 1');
    expect(find.text('NEW PR'), findsOneWidget);
    expect(find.byType(Confetti), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    await tapText(tester, 'Tap to continue');
    expect(find.text('NEW PR'), findsNothing);
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });

  testWidgets('the logbook keeps every workout set by set and filters by workout', (tester) async {
    final c = await pumpApp(tester);
    await onboard(tester, 'On my own', 'Dani');
    final store = c.read(boltProvider.notifier);
    for (final (k, tpl) in [('2026-10-12', 'push'), ('2026-10-13', 'pull')]) {
      store.addFromRotation(Account.ownerId, k);
      store.setTemplate(Account.ownerId, k, tpl);
      store.logPast(k);
    }
    final push = c.read(boltProvider).plans[Account.ownerId]!['2026-10-12']!;
    push.ex.first.logged.addAll([SetLog(kg: 80, reps: 6), SetLog(kg: 82.5, reps: 5)]);
    push.prs.add('Bench Press');
    c.read(routerProvider).push('/history');
    await settle(tester);
    expect(find.text('2 workouts · 2 sets'), findsOneWidget);
    expect(find.text('80×6 · 82.5×5 kg'), findsOneWidget);
    expect(find.text('Latest records'), findsOneWidget);
    await tapText(tester, 'Pull');
    expect(find.text('1 workout · 0 sets'), findsOneWidget);
    expect(find.text('80×6 · 82.5×5 kg'), findsNothing);
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });

  testWidgets('a timed set counts down in gym floor mode and logs itself', (tester) async {
    final c = await pumpApp(tester);
    await onboard(tester, 'On my own', 'Dani');
    final store = c.read(boltProvider.notifier);
    store.addFromRotation(Account.ownerId, '2026-10-14');
    store.setTemplate(Account.ownerId, '2026-10-14', 'hiit');
    store.toggleSetting('floor');
    store.startWorkout('2026-10-14');
    c.read(routerProvider).push('/workout/2026-10-14');
    await settle(tester);
    final s = c.read(boltProvider).plans[Account.ownerId]!['2026-10-14']!;
    final climber = s.ex.firstWhere((e) => e.name == 'Mountain Climber');
    await tapText(tester, 'Warm-up done');
    // To the mountain climbers: burpees and swings come first.
    await tapText(tester, '›');
    await tapText(tester, '›');
    expect(find.text('Mountain Climber'), findsOneWidget);
    await tapText(tester, 'Start 0:30');
    expect(find.text('GO'), findsOneWidget);
    await tester.pump(const Duration(seconds: 31));
    await settle(tester);
    expect(c.read(boltProvider).workout!.isDone(climber.id, 0), isTrue);
    expect(find.text('REST'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });

  testWidgets('exercises move up and down and explain themselves in the editor', (tester) async {
    final c = await pumpApp(tester);
    await onboard(tester, 'On my own', 'Dani');
    await tapTab(tester, 'Workouts');
    await tapText(tester, 'Push');
    List<String> names() => c.read(boltProvider).tpls['push']!.ex.map((e) => e.name).toList();
    expect(names().take(2), ['Bench Press', 'Overhead Press']);
    await tapText(tester, '↓');
    expect(names().take(2), ['Overhead Press', 'Bench Press']);
    await tapText(tester, '↑');
    expect(names().take(2), ['Overhead Press', 'Bench Press'], reason: 'the first row cannot move up');
    await tapText(tester, 'Incline DB Press');
    expect(find.text('INCLINE DB PRESS'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });

  testWidgets('a trainee starts empty and can import or plan', (tester) async {
    await pumpApp(tester);
    await onboard(tester, 'With a coach', 'Ana');
    expect(find.text('Nothing planned yet'), findsOneWidget);
    expect(find.text('Import plan'), findsOneWidget);

    await tapText(tester, 'Plan it myself');
    expect(find.text('Auto-fill 3 wks'), findsOneWidget);
    await tapText(tester, 'Auto-fill 3 wks');
    expect(find.text('8 sessions planned from 3-day Push / Pull / Legs'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('a coach adds a trainee and plans for them', (tester) async {
    final c = await pumpApp(tester);
    await onboard(tester, 'I coach people', 'Marko Ilić');
    expect(find.text('COACH'), findsOneWidget);
    expect(find.text('Marko'), findsOneWidget);
    expect(find.text('TRAINEES · 0'), findsOneWidget);

    await tapText(tester, '+ Add trainee');
    await typeInto(tester, 'Full name', 'Ana Marić');
    // The sheet's title says the same, so tap the button itself.
    await tester.tap(find.widgetWithText(NeonButton, 'Add trainee'));
    await settle(tester);
    await settle(tester);
    expect(find.text('Auto-fill 3 wks'), findsOneWidget);
    await tapText(tester, 'Auto-fill 3 wks');
    final tid = c.read(boltProvider).trainees.single.id;
    expect(c.read(boltProvider).plans[tid], hasLength(8));
    await unmount(tester);
  });

  testWidgets('a trainee picks their coach from the list', (tester) async {
    final c = await pumpApp(
      tester,
      coaches: const [ListedCoach('Marko Ilić', 'Strength & Hypertrophy'), ListedCoach('Sara Novak', '')],
    );
    await tapText(tester, 'With a coach');
    expect(find.text('Strength & Hypertrophy'), findsOneWidget);
    expect(find.text('Not listed? Type their name.'), findsOneWidget);
    await typeInto(tester, 'Your name', 'Ana');
    expect(find.widgetWithText(TextField, 'Marko Ilić'), findsNothing);
    await tapText(tester, 'Marko Ilić');
    expect(find.widgetWithText(TextField, 'Marko Ilić'), findsOneWidget);
    await tapText(tester, 'Continue');
    await tapText(tester, 'Start training');
    expect(c.read(boltProvider).trainees.single.coachName, 'Marko Ilić');
    await tapTab(tester, 'Me');
    expect(find.text('Trainee · Coach Marko Ilić'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('without the coach list a trainee types the name', (tester) async {
    final c = await pumpApp(tester, coaches: null);
    await tapText(tester, 'With a coach');
    expect(find.text('Could not load the coach list. Type your coach\'s name instead.'), findsOneWidget);
    await typeInto(tester, 'Your name', 'Ana');
    await typeInto(tester, 'Coach\'s name (optional)', 'Marko');
    await tapText(tester, 'Continue');
    await tapText(tester, 'Start training');
    expect(c.read(boltProvider).trainees.single.coachName, 'Marko');
    await unmount(tester);
  });

  testWidgets('coaching needs a license code', (tester) async {
    await pumpApp(tester);
    await tapText(tester, 'I coach people');
    expect(find.text('Your coach code'), findsOneWidget);
    await typeInto(tester, '5-digit code', '12345');
    await tapText(tester, 'Unlock');
    expect(find.text('That code is not valid. Check it and try again.'), findsOneWidget);
    await typeInto(tester, '5-digit code', '11111');
    await tapText(tester, 'Unlock');
    expect(find.text('About you'), findsOneWidget);
    expect(find.text('STEP 1 OF 2'), findsOneWidget);
    // Back from the profile step returns to the code, then to the roles.
    await tester.tap(find.text('‹'));
    await settle(tester);
    expect(find.text('Your coach code'), findsOneWidget);
    await tester.tap(find.text('‹'));
    await settle(tester);
    expect(find.text('HOW DO YOU TRAIN?'), findsOneWidget);
    // Trainees and solo users skip the code.
    await tapText(tester, 'With a coach');
    expect(find.text('About you'), findsOneWidget);
    await unmount(tester);
  });

  /// Onboards a solo user, then hands back their data with the key gate set
  /// back, which is what an update that raises the generation looks like.
  Future<BoltData> afterUpdate(WidgetTester tester) async {
    final c = await pumpApp(tester);
    await onboard(tester, 'On my own', 'Dani Kovač');
    final data = c.read(boltProvider)..settings.keyGen = 0;
    await unmount(tester);
    return data;
  }

  testWidgets('an update asks for the key again and the admin key opens it', (tester) async {
    final c = await pumpApp(tester, data: await afterUpdate(tester));
    expect(find.text('Type your key'), findsOneWidget);
    expect(find.text('Hey Dani'), findsNothing);
    await typeInto(tester, '5 or 6 digits', '99999');
    await tapText(tester, 'Open Bolt');
    expect(find.text('That key does not open Bolt. Check it and try again.'), findsOneWidget);
    await typeInto(tester, '5 or 6 digits', '222222');
    await tapText(tester, 'Open Bolt');
    // Straight back in, with the training data still there.
    expect(find.text('Hey Dani'), findsOneWidget);
    final log = c.read(boltProvider).settings.keyLog;
    expect([for (final e in log) '${e.name}:${e.how}'], ['Unknown:wrong', 'Admin:ok']);
    await unmount(tester);
  });

  testWidgets('a coach key waits until the owner switches it on', (tester) async {
    final data = await afterUpdate(tester);
    final c = await pumpApp(tester, data: data);
    await typeInto(tester, '5 or 6 digits', '11111');
    await tapText(tester, 'Open Bolt');
    expect(find.text('Not switched on yet'), findsOneWidget);
    expect(find.text('Hey Dani'), findsNothing);
    expect(c.read(boltProvider).settings.keyLog.last.how, 'pending');
    await unmount(tester);

    // The owner switches that key on; the same code now opens the app.
    data.settings.keyGen = 0;
    data.settings.coachKeysOn.add(0);
    await pumpApp(tester, data: data);
    await typeInto(tester, '5 or 6 digits', '11111');
    await tapText(tester, 'Open Bolt');
    expect(find.text('Hey Dani'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('the centre button opens the quick screen, and the stopwatch laps', (tester) async {
    await pumpApp(tester);
    await onboard(tester, 'On my own', 'Dani');
    await tapTab(tester, 'Check in');
    expect(find.text('What now?'), findsOneWidget);
    for (final t in ['Check in', 'Scan QR', 'Fast workout', 'Cardio', 'Weights', 'Stopwatch']) {
      expect(find.text(t), findsWidgets, reason: t);
    }
    await tapText(tester, 'Stopwatch');
    expect(find.text('Start'), findsOneWidget);
    expect(find.text('LAPS'), findsNothing);

    await tapText(tester, 'Start');
    expect(find.text('Stop'), findsOneWidget);
    await tapText(tester, 'Lap');
    await tapText(tester, 'Lap');
    expect(find.text('LAPS'), findsOneWidget);
    expect(find.text('01'), findsOneWidget);
    expect(find.text('02'), findsOneWidget);

    // Stopped it holds the time; the pusher then puts it back to zero.
    await tapText(tester, 'Stop');
    expect(find.text('Reset'), findsOneWidget);
    await tapText(tester, 'Reset');
    expect(find.text('LAPS'), findsNothing);
    expect(find.text('00:00.00'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });

  testWidgets('a fast cardio workout starts on today without a plan', (tester) async {
    final c = await pumpApp(tester);
    await onboard(tester, 'On my own', 'Dani');
    await tapTab(tester, 'Check in');
    await tapText(tester, 'Cardio');
    await tester.pump(const Duration(milliseconds: 600));
    final today = c.read(boltProvider.notifier).today;
    expect(c.read(boltProvider.notifier).plan(Account.ownerId)[today]?.code, isNotNull);
    expect(find.text('START'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('the admin key switches between every role', (tester) async {
    final c = await pumpApp(tester);
    await tapText(tester, 'I coach people');
    await typeInto(tester, '5-digit code', '222222');
    await tapText(tester, 'Unlock');
    expect(find.text('ADMIN · STEP 1 OF 2'), findsOneWidget);
    await typeInto(tester, 'Your name', 'Dani');
    await tapText(tester, 'Continue');
    await tapText(tester, 'Start coaching');
    expect(find.text('COACH'), findsOneWidget);
    expect(find.text('Dani'), findsOneWidget);
    // The admin's own trainee record is not one of their trainees.
    expect(find.text('TRAINEES · 0'), findsOneWidget);

    await tapTab(tester, 'Profile');
    expect(find.text('ADMIN · VIEW AS'), findsOneWidget);
    await tapText(tester, 'Trainee');
    expect(find.text('Hey Dani'), findsOneWidget);
    await tapTab(tester, 'Me');
    expect(find.text('Trainee'), findsWidgets);
    await tapText(tester, 'Solo');
    expect(find.text('Training solo'), findsOneWidget);
    expect(c.read(boltProvider).account!.admin, isTrue);
    await unmount(tester);
  });

  testWidgets('the admin sets reminder times and pushes for every phone', (tester) async {
    final board = FakeBoard();
    final c = await pumpApp(tester, board: board);
    await tapText(tester, 'I coach people');
    await typeInto(tester, '5-digit code', '222222');
    await tapText(tester, 'Unlock');
    await typeInto(tester, 'Your name', 'Dani');
    await tapText(tester, 'Continue');
    await tapText(tester, 'Start coaching');
    c.read(routerProvider).push('/settings');
    await settle(tester);
    await tapText(tester, 'Push notifications');
    expect(find.text('BUILT-IN REMINDERS'), findsOneWidget);
    expect(find.text('Published'), findsOneWidget);

    // The session reminder moves to an hour before.
    await tapText(tester, 'Session reminder');
    await tapText(tester, '1 h');
    expect(find.text('1 h before ›'), findsOneWidget);

    await tapText(tester, '+ New push');
    await tester.enterText(find.widgetWithText(TextField, 'Title').first, 'Gym closed Sunday');
    await tester.pump();
    await tapText(tester, 'Every day');
    await tapText(tester, 'Coaches');
    await tapText(tester, 'Save');
    expect(find.text('Gym closed Sunday'), findsOneWidget);
    expect(find.text('EVERY DAY · 18:00 · COACHES'), findsOneWidget);

    // No token yet: publishing asks for one first.
    await tapText(tester, 'Publish to every phone');
    await tester.enterText(find.byType(TextField).last, 'github_pat_test');
    await tapText(tester, 'Save');
    await tester.pump(const Duration(milliseconds: 600));
    expect(board.saved, 'github_pat_test');
    expect(board.published!.times.before, 60);
    expect(board.published!.pushes.single.to, 'coaches');
    expect(c.read(boltProvider).settings.board.pushes.single.title, 'Gym closed Sunday');
    expect(find.text('Published'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });

  testWidgets('a coach sees each trainee\'s progress', (tester) async {
    final c = await pumpApp(tester);
    await onboard(tester, 'I coach people', 'Marko');
    final store = c.read(boltProvider.notifier);
    final tid = store.addTrainee(const ProfileInput(name: 'Ana Marić'));
    // As if her update had come in.
    store.tr(tid).stats
      ..sessions = 12
      ..mins = 600
      ..workouts = 1;
    store.toggleWeekStart();
    store.toggleWeekStart();
    await settle(tester);
    // Sessions 1, 5 and 10, hours 1, 5 and 10, and the first logged workout.
    expect(find.text('12 SESSIONS · 0W STREAK · 7/${kBadges.length} BADGES'), findsOneWidget);

    await tapText(tester, 'Ana Marić');
    expect(find.text('Progress'), findsOneWidget);
    expect(find.text('7 / ${kBadges.length}'), findsOneWidget);
    expect(find.text('Next: 25 Club'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('the coach centre button opens a calendar of every trainee', (tester) async {
    final c = await pumpApp(tester);
    await onboard(tester, 'I coach people', 'Marko');
    expect(find.byWidgetPredicate((w) => w is Semantics && w.properties.label == 'Check in'), findsNothing);
    final store = c.read(boltProvider.notifier);
    store.autoFill(store.addTrainee(const ProfileInput(name: 'Ana Marić')));
    store.autoFill(store.addTrainee(const ProfileInput(name: 'Luka Horvat')));
    await settle(tester);

    await tapTab(tester, 'Calendar');
    expect(find.text('CALENDAR · 2 TRAINEES'), findsOneWidget);
    expect(find.text('October'), findsOneWidget);
    // Today both have Pull drafted.
    expect(find.text('WED 14 OCT'), findsOneWidget);
    expect(find.text('Ana Marić'), findsOneWidget);
    expect(find.text('Luka Horvat'), findsOneWidget);
    await tapText(tester, '15');
    expect(find.text('No sessions'), findsOneWidget);
    await tapText(tester, '›');
    expect(find.text('November'), findsOneWidget);
    expect(find.text('SUN 1 NOV'), findsOneWidget);

    await tapText(tester, '‹');
    await tapText(tester, '14');
    await tapText(tester, 'Ana Marić');
    expect(find.text('Progress'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('a coach switches to solo and back from the profile', (tester) async {
    await pumpApp(tester);
    await onboard(tester, 'I coach people', 'Marko');
    await tapTab(tester, 'Profile');
    expect(find.text('MODE'), findsOneWidget);
    expect(find.text('Trainee'), findsNothing);
    await tapText(tester, 'Solo');
    expect(find.text('Hey Marko'), findsOneWidget);
    expect(find.text('ACHIEVEMENTS'), findsOneWidget);
    await tapTab(tester, 'Me');
    expect(find.text('Training solo'), findsOneWidget);
    await tapText(tester, 'Coach');
    expect(find.text('COACH'), findsOneWidget);
    expect(find.text('Marko'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('scan button checks in from the frame', (tester) async {
    await pumpApp(tester);
    await onboard(tester, 'On my own', 'Dani');
    await openScanner(tester);
    expect(find.text('Scan to check in'), findsWidgets);
    // Tapping the frame simulates a scan.
    await tester.tap(find.byKey(const Key('scan-frame')));
    await settle(tester);
    expect(find.text('CHECKED IN'), findsOneWidget);
    // The overlay closes itself after 4 s and today's workout opens, ready
    // to start; back from it is the gym screen.
    await tester.pump(const Duration(seconds: 4));
    await settle(tester);
    expect(find.byType(ScannerOverlay), findsNothing);
    expect(find.text('START'), findsOneWidget);
    await back(tester);
    expect(find.text('Scan to check out'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('checking in and out works without a scan', (tester) async {
    final c = await pumpApp(tester);
    await onboard(tester, 'On my own', 'Dani');
    bool inGym() => c.read(boltProvider).gymIn[Account.ownerId] != null;

    // From the scanner, when the plaque or camera is not there.
    await openScanner(tester);
    await tapText(tester, 'Check in without scanning');
    expect(find.text('CHECKED IN'), findsOneWidget);
    expect(inGym(), isTrue);
    await tester.pump(const Duration(seconds: 4));
    await settle(tester);
    expect(find.byType(ScannerOverlay), findsNothing);
    await back(tester);

    // From the gym page: straight to the result, no camera.
    await tapText(tester, 'Check out without scanning');
    expect(find.byKey(const Key('scan-frame')), findsNothing);
    expect(find.text('CHECKED OUT'), findsOneWidget);
    expect(inGym(), isFalse);
    // A short visit explains itself, so the result stays up longer.
    await tester.pump(const Duration(seconds: 6));
    await settle(tester);
    expect(find.text('Check in without scanning'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });

  testWidgets('a scan by mistake is undone from the result or the gym page', (tester) async {
    final c = await pumpApp(tester);
    await onboard(tester, 'On my own', 'Dani');
    bool inGym() => c.read(boltProvider).gymIn[Account.ownerId] != null;
    await openScanner(tester);
    await tapText(tester, 'Check in without scanning');
    expect(inGym(), isTrue);
    await tapText(tester, 'Undo check-in');
    expect(inGym(), isFalse);
    expect(find.byType(ScannerOverlay), findsNothing);
    expect(find.text('Check-in undone'), findsOneWidget);

    // Checked in for real, out by mistake: back in from the gym page.
    await tapText(tester, 'Check in without scanning');
    await tester.pump(const Duration(seconds: 4));
    await settle(tester);
    await back(tester);
    await tapText(tester, 'Check out without scanning');
    await tester.pump(const Duration(seconds: 6));
    await settle(tester);
    expect(inGym(), isFalse);
    // The first visit unlocks a badge; its moment does not stop the undo.
    while (find.text('BADGE UNLOCKED').evaluate().isNotEmpty) {
      await tapText(tester, 'Tap to continue');
    }
    await tapText(tester, 'Undo last check-out');
    expect(inGym(), isTrue);
    expect(c.read(boltProvider).visits[Account.ownerId] ?? const [], isEmpty);
    expect(find.text('Check out without scanning'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });

  testWidgets('the profile has an update button', (tester) async {
    await pumpApp(
      tester,
      updater: FakeUpdater(
        const UpdateFound(
          Release(title: 'BOLT 1.3.0', version: '1.3.0', build: 4, notes: '• Faster', apkUrl: 'u', apkBytes: 28311552),
        ),
      ),
    );
    await onboard(tester, 'On my own', 'Dani');
    await tapTab(tester, 'Me');
    expect(find.text('ADMIN · VIEW AS'), findsNothing);
    expect(find.text('Bolt 1.2.0'), findsOneWidget);
    await tapText(tester, 'Update');
    expect(find.text('BOLT 1.3.0'), findsOneWidget);
    expect(find.text('• Faster'), findsOneWidget);
    expect(find.text('Download and install'), findsOneWidget);
    await unmount(tester);
  });
}
