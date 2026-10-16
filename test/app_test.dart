import 'dart:io';

import 'package:bolt/app.dart';
import 'package:bolt/data/bolt_store.dart';
import 'package:bolt/data/licenses.dart';
import 'package:bolt/data/models/bolt_data.dart';
import 'package:bolt/data/models/session.dart';
import 'package:bolt/data/seed/badges.dart';
import 'package:bolt/data/seed/content.dart';
import 'package:bolt/features/gym/scanner_overlay.dart';
import 'package:bolt/features/updates/update_sheet.dart';
import 'package:bolt/services/coach_directory.dart';
import 'package:bolt/services/updater.dart';
import 'package:bolt/widgets/common.dart';
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

Future<ProviderContainer> pumpApp(
  WidgetTester tester, {
  BoltData? data,
  Updater? updater,
  List<ListedCoach>? coaches = const [],
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
        // Test codes; the real ones are not in the source.
        licenseProvider.overrideWithValue(
          (c) => switch (c) {
            '11111' => License.coach,
            '222222' => License.admin,
            _ => null,
          },
        ),
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

Future<void> typeInto(WidgetTester tester, String hint, String text) async {
  await tester.enterText(find.widgetWithText(TextField, hint), text);
  await tester.pump();
}

Future<void> loadFont(String family, String path) async {
  final bytes = ByteData.sublistView(File(path).readAsBytesSync());
  await (FontLoader(family)..addFont(Future.value(bytes))).load();
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

    await tapText(tester, 'Me');
    expect(find.text('Training solo'), findsOneWidget);
    expect(find.text('81.5 kg'), findsOneWidget);
    expect(find.text('Your coach'), findsNothing);
    await unmount(tester);
  });

  testWidgets('Learn has its own tab, badges sit on Today', (tester) async {
    await pumpApp(tester);
    await onboard(tester, 'On my own', 'Dani');
    expect(find.text('ACHIEVEMENTS'), findsOneWidget);
    expect(find.text('0 / ${kBadges.length}'), findsOneWidget);
    expect(find.text('Next: First Rep'), findsOneWidget);
    await tapText(tester, 'ACHIEVEMENTS');
    expect(find.text('Trophy rack'), findsOneWidget);
    await tester.tap(find.text('‹'));
    await settle(tester);

    await tapText(tester, 'Learn');
    expect(find.text('Train smarter'), findsOneWidget);
    expect(find.text('Supplements'), findsOneWidget);
    expect(find.text('‹'), findsNothing);
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
    await tapText(tester, 'Plan');
    expect(find.text('REST'), findsOneWidget);
    expect(find.textContaining('Long-press one to mark it as a rest day.'), findsOneWidget);
    await tester.longPress(find.text('18').first);
    await settle(tester);
    expect(c.read(boltProvider).trainees.single.stats.rest, isEmpty);
    expect(find.text('REST'), findsNothing);
    await unmount(tester);
  });

  testWidgets('solo users log past days from their diary', (tester) async {
    final c = await pumpApp(tester);
    await onboard(tester, 'On my own', 'Dani');
    await tapText(tester, 'Plan');
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
    expect(find.text('ROOKIE'), findsOneWidget);
    await tapText(tester, 'Tap to continue');
    await tapText(tester, 'Today');
    expect(find.text('LVL 2'), findsOneWidget);
    final s = c.read(boltProvider).plans[Account.ownerId]!['2026-10-13']!;
    expect(s.status, SessionStatus.done);
    expect(c.read(boltProvider).trainees.single.stats.workouts, 1);
    await unmount(tester);
  });

  testWidgets('trainees cannot add days behind them', (tester) async {
    final c = await pumpApp(tester);
    await onboard(tester, 'With a coach', 'Ana');
    await tapText(tester, 'Plan');
    expect(find.textContaining('Past days too'), findsNothing);
    await tapText(tester, '13');
    expect(c.read(boltProvider).plans[Account.ownerId]!['2026-10-13'], isNull);
    await unmount(tester);
  });

  testWidgets('solo users open the workout library from Me', (tester) async {
    await pumpApp(tester);
    await onboard(tester, 'On my own', 'Dani');
    await tapText(tester, 'Me');
    await tapText(tester, 'Workouts');
    expect(find.text('LIBRARY'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('‹'));
    await settle(tester);
    expect(find.text('Training solo'), findsOneWidget);
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
    expect(find.text('Coach Marko'), findsOneWidget);
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
    // The split already has its tick; the coach gets the second.
    expect(find.text('✓'), findsOneWidget);
    await tapText(tester, 'Marko Ilić');
    expect(find.text('✓'), findsNWidgets(2));
    await tapText(tester, 'Continue');
    await tapText(tester, 'Start training');
    expect(c.read(boltProvider).trainees.single.coachName, 'Marko Ilić');
    await tapText(tester, 'Me');
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

  testWidgets('the admin key switches between every role', (tester) async {
    final c = await pumpApp(tester);
    await tapText(tester, 'I coach people');
    await typeInto(tester, '5-digit code', '222222');
    await tapText(tester, 'Unlock');
    expect(find.text('ADMIN · STEP 1 OF 2'), findsOneWidget);
    await typeInto(tester, 'Your name', 'Dani');
    await tapText(tester, 'Continue');
    await tapText(tester, 'Start coaching');
    expect(find.text('Coach Dani'), findsOneWidget);
    // The admin's own trainee record is not one of their trainees.
    expect(find.text('TRAINEES · 0'), findsOneWidget);

    await tapText(tester, 'Profile');
    expect(find.text('ADMIN · VIEW AS'), findsOneWidget);
    await tapText(tester, 'Trainee');
    expect(find.text('Hey Dani'), findsOneWidget);
    await tapText(tester, 'Me');
    expect(find.text('Trainee'), findsWidgets);
    await tapText(tester, 'Solo');
    expect(find.text('Training solo'), findsOneWidget);
    expect(c.read(boltProvider).account!.admin, isTrue);
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
    expect(find.text('Check in'), findsNothing);
    final store = c.read(boltProvider.notifier);
    store.autoFill(store.addTrainee(const ProfileInput(name: 'Ana Marić')));
    store.autoFill(store.addTrainee(const ProfileInput(name: 'Luka Horvat')));
    await settle(tester);

    await tapText(tester, 'Calendar');
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
    await tapText(tester, 'Profile');
    expect(find.text('MODE'), findsOneWidget);
    expect(find.text('Trainee'), findsNothing);
    await tapText(tester, 'Solo');
    expect(find.text('Hey Marko'), findsOneWidget);
    expect(find.text('ACHIEVEMENTS'), findsOneWidget);
    await tapText(tester, 'Me');
    expect(find.text('Training solo'), findsOneWidget);
    await tapText(tester, 'Coach');
    expect(find.text('Coach Marko'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('scan button checks in from the frame', (tester) async {
    await pumpApp(tester);
    await onboard(tester, 'On my own', 'Dani');
    await tapText(tester, 'Check in');
    expect(find.text('Scan to check in'), findsWidgets);
    // Tapping the frame simulates a scan.
    await tester.tap(find.byKey(const Key('scan-frame')));
    await settle(tester);
    expect(find.text('CHECKED IN'), findsOneWidget);
    // The overlay closes itself after 1.8 s, leaving the gym screen.
    await tester.pump(const Duration(seconds: 2));
    await settle(tester);
    expect(find.byType(ScannerOverlay), findsNothing);
    expect(find.text('Scan to check out'), findsOneWidget);
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
    await tapText(tester, 'Me');
    expect(find.text('ADMIN · VIEW AS'), findsNothing);
    expect(find.text('Bolt 1.2.0'), findsOneWidget);
    await tapText(tester, 'Update');
    expect(find.text('BOLT 1.3.0'), findsOneWidget);
    expect(find.text('• Faster'), findsOneWidget);
    expect(find.text('Download and install'), findsOneWidget);
    await unmount(tester);
  });
}
