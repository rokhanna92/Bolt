import 'dart:io';

import 'package:bolt/core/format.dart';
import 'package:bolt/app/ui_state.dart';
import 'package:bolt/app.dart';
import 'package:bolt/app/actions.dart' show openShortcut;
import 'package:bolt/app/router.dart';
import 'package:bolt/core/pwa.dart';
import 'package:bolt/features/quick/watch.dart';
import 'package:bolt/features/profile/language_picker.dart';
import 'package:bolt/widgets/bolt_nav_bar.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:bolt/widgets/box.dart';
import 'package:bolt/widgets/forms.dart';
import 'package:bolt/widgets/calendar_grid.dart';
import 'package:bolt/data/bolt_store.dart';
import 'package:bolt/data/licenses.dart';
import 'package:bolt/data/models/board.dart';
import 'package:bolt/data/models/bolt_data.dart';
import 'package:bolt/data/models/exercise.dart';
import 'package:bolt/data/models/people.dart';
import 'package:bolt/data/models/session.dart';
import 'package:bolt/theme/tokens.dart';
import 'package:bolt/data/models/settings.dart';
import 'package:bolt/data/rules.dart';
import 'package:bolt/data/seed/badges.dart';
import 'package:bolt/data/seed/content.dart';
import 'package:bolt/features/today/check_in_gate.dart';
import 'package:bolt/features/gym/scanner_overlay.dart';
import 'package:bolt/features/updates/update_sheet.dart';
import 'package:bolt/features/workout/lifeline.dart';
import 'package:bolt/l10n/l10n.dart' show compareNames;
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
  DateTime Function()? clock,
}) async {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 2.75;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        clockProvider.overrideWithValue(clock ?? () => wed),
        initialDataProvider.overrideWithValue(data ?? freshData()),
        updaterProvider.overrideWithValue(updater ?? FakeUpdater(const UpToDate())),
        coachDirectoryProvider.overrideWithValue(FakeDirectory(coaches)),
        noticeBoardProvider.overrideWithValue(board ?? FakeBoard()),
        // Test codes; the real ones are not in the source.
        licenseProvider.overrideWithValue(
          (c) => switch (c) {
            '11111' => License.coach,
            '222222' => License.admin,
            '33333' => License.solo,
            '44444' => License.trainee,
            _ => null,
          },
        ),
        keyNameProvider.overrideWithValue(
          (c) => const {
            '11111': 'Coach 1',
            '222222': 'Admin',
            '33333': 'Solo 1',
            '44444': 'Trainee 1',
            'AAAA-BBBB': 'Solo 1',
            'CCCC-DDDD': 'Coach 2',
            'EEEE-FFFF': 'Solo 2',
          }[c],
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
/// Taps the first widget a screen reader would call [label], for buttons
/// drawn as icons.
Future<void> tapLabel(WidgetTester tester, String label) async {
  final f = find.byWidgetPredicate((w) => w is Semantics && w.properties.label == label).first;
  await tester.ensureVisible(f);
  await tester.tap(f);
  await settle(tester);
}

Future<void> back(WidgetTester tester) async {
  final f = find.byType(BackBox).first;
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

/// The centre button opens the quick screen; the scanner is one tap on.
Future<void> openScanner(WidgetTester tester) async {
  await tapTab(tester, 'Check in');
  await tapText(tester, 'Scan QR');
}

/// Turns the stopwatch over to its other face. There is no button for it:
/// you swipe across the watch.
Future<void> swipeFace(WidgetTester tester) async {
  await tester.drag(find.byKey(const Key('watch-face')), const Offset(-220, 0));
  await settle(tester);
}

/// Goes through onboarding as [role] with [name]. Coaches enter [code].
/// The test key that fits each way of training on the first screen.
String keyFor(String role) => const {'On my own': '33333', 'With a coach': '44444', 'I coach people': '11111'}[role]!;

Future<void> typeKey(WidgetTester tester, String code) async {
  await typeInto(tester, 'Your key', code);
  await tapText(tester, 'Unlock');
}

Future<void> onboard(
  WidgetTester tester,
  String role,
  String name, {
  String? weight,
  String? code,
  bool planned = true,
}) async {
  expect(find.text('HOW DO YOU TRAIN?'), findsOneWidget);
  await tapText(tester, role);
  await typeKey(tester, code ?? keyFor(role));
  await typeInto(tester, 'Your name', name);
  await tapText(tester, 'Continue');
  expect(find.text('Your body'), findsOneWidget);
  if (weight != null) await typeInto(tester, 'Weight (kg)', weight);
  await tapText(tester, role == 'I coach people' ? 'Start coaching' : 'Start training');
  // Bolt never fills the calendar by itself; most tests want a planned week.
  if (planned && role == 'On my own') {
    ProviderScope.containerOf(tester.element(find.byType(BoltApp)))
        .read(boltProvider.notifier)
        .autoFill(Account.ownerId);
  }
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

  testWidgets('Android back on another tab returns to Today', (tester) async {
    await pumpApp(tester);
    await onboard(tester, 'On my own', 'Dani');
    await tapTab(tester, 'Me');
    expect(find.text('Training solo'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await settle(tester);
    expect(find.text('Hey Dani'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('achievements list the ones you have first, then A to Z', (tester) async {
    final c = await pumpApp(tester);
    await onboard(tester, 'On my own', 'Dani');
    c.read(boltProvider).trainees.single.stats.sessions = 1;
    c.read(routerProvider).push('/badges');
    await settle(tester);
    double x(String name) => tester.getTopLeft(find.text(name).last).dx;
    double y(String name) => tester.getTopLeft(find.text(name).last).dy;
    // Gym sessions: First Rep is earned, so it leads; then 25 Club, Century...
    expect(y('First Rep'), lessThanOrEqualTo(y('25 Club')));
    expect(x('First Rep'), lessThan(x('25 Club')));
    expect(y('25 Club'), lessThan(y('Warming Up')));
    expect(compareNames('Čelik', 'Cilj'), greaterThan(0));
    expect(compareNames('Čelik', 'Dan'), lessThan(0));
    await unmount(tester);
  });

  testWidgets('the trophy rack shows what you achieved first, then the rest', (tester) async {
    final c = await pumpApp(tester);
    await onboard(tester, 'On my own', 'Dani');
    await tapText(tester, 'ACHIEVEMENTS');
    expect(find.text('None yet. Train and they land here.'), findsOneWidget);
    await tester.tap(find.byType(BackBox).first);
    await settle(tester);

    final store = c.read(boltProvider.notifier);
    store.edit(const TemplateTarget('push'), () => c.read(boltProvider).trainees.single.stats.sessions = 1);
    await tapText(tester, 'ACHIEVEMENTS');
    expect(find.text('None yet. Train and they land here.'), findsNothing);
    double top(String text) => tester.getTopLeft(find.text(text)).dy;
    expect(top('Achieved'), lessThan(top('First Rep')));
    expect(top('First Rep'), lessThan(top('Still to earn')));
    await unmount(tester);
  });

  testWidgets('workouts go out from the Workouts page and come back in', (tester) async {
    final c = await pumpApp(tester);
    await onboard(tester, 'On my own', 'Dani');
    await tapTab(tester, 'Workouts');

    // On day one the page says what to do first.
    await tapText(tester, 'Send workouts');
    expect(find.textContaining('Nothing to send yet'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await settle(tester);

    final store = c.read(boltProvider.notifier);
    final id = store.newTemplate();
    await settle(tester);
    await tapText(tester, 'Send workouts');
    final send = tester.widget<NeonButton>(find.widgetWithText(NeonButton, 'Send'));
    expect(send.onTap, isNull);
    // The sheet sits over the same workout on the page.
    await tester.tap(find.text('Custom 1').last);
    await settle(tester);
    expect(find.text('Send 1 workout'), findsOneWidget);
    final msg = store.workoutsMessage([id]);
    await tester.binding.handlePopRoute();
    await settle(tester);

    store.hideTemplate(id);
    await settle(tester);
    store.importText(msg);
    await settle(tester);
    expect(find.text('Your workouts'), findsOneWidget);
    expect(find.text('Custom 1'), findsOneWidget);

    await tapText(tester, 'Import workouts');
    expect(find.textContaining('They land in Your workouts'), findsOneWidget);
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
    await tester.tap(find.byType(BackBox).first);
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
    // Today's workout card has the button, so the nudge above it is slim.
    expect(find.text('Recovery is done. Time to move before the habit slips.'), findsOneWidget);
    expect(find.text('ENOUGH REST.'), findsNothing);
    // With nothing planned today the nudge leads, and no rest-day card argues.
    if (c.read(boltProvider).plans[Account.ownerId]!['2026-10-14'] != null) {
      store.removeDay(Account.ownerId, '2026-10-14');
    }
    await settle(tester);
    expect(find.text('ENOUGH REST.'), findsOneWidget);
    expect(find.text('REST DAY'), findsNothing);
    expect(find.text('OFF IN A ROW'), findsOneWidget);

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

  testWidgets('swiping the Plan calendar changes month, and the arrows slide it too', (tester) async {
    final c = await pumpApp(tester);
    await onboard(tester, 'On my own', 'Dani');
    await tapTab(tester, 'Plan');
    final start = c.read(planMonthProvider);
    final next = DateTime(start.year, start.month + 1);
    await tester.fling(find.byType(PageView), const Offset(-300, 0), 1000);
    await settle(tester);
    expect(c.read(planMonthProvider), next);
    expect(find.text(monthsLong[next.month - 1]), findsOneWidget);
    expect(tester.widget<PageView>(find.byType(PageView)).controller!.page, next.year * 12 + next.month - 1);

    await tester.fling(find.byType(PageView), const Offset(300, 0), 1000);
    await settle(tester);
    expect(c.read(planMonthProvider), start);

    c.read(planMonthProvider.notifier).shift(-1);
    await settle(tester);
    await settle(tester); // The slide starts on the frame after the change.
    final back = DateTime(start.year, start.month - 1);
    expect(tester.widget<PageView>(find.byType(PageView)).controller!.page, back.year * 12 + back.month - 1);
    expect(c.read(planMonthProvider), back);
    await unmount(tester);
  });

  testWidgets('the bell opens notifications: water, supplement tiles and their times', (tester) async {
    final c = await pumpApp(tester);
    await onboard(tester, 'On my own', 'Dani');
    await tester.tap(find.bySemanticsLabel('Notifications'));
    await settle(tester);
    expect(find.text('App'), findsOneWidget);
    expect(find.text('A cup of water every 3 h, from 09:00 to 21:00'), findsOneWidget);
    expect(find.text('2 h'), findsNothing);
    await tapText(tester, 'A cup of water every 3 h, from 09:00 to 21:00');
    await settle(tester);
    await tapText(tester, '2 h');
    await settle(tester);
    expect(c.read(boltProvider).settings.waterHours, 2);

    // Adding one goes straight to its time, and it stays on when saved.
    await tapText(tester, 'Magnesium');
    await settle(tester);
    await tapText(tester, 'Save');
    await settle(tester);
    expect(c.read(boltProvider).settings.supps, {'Magnesium': 9 * 60});
    expect(find.text('09:00'), findsOneWidget);
    expect(find.text('Sleep and recovery'), findsNothing);
    await tester.tap(find.bySemanticsLabel('Close'));
    await settle(tester);
    expect(c.read(boltProvider).settings.supps, isEmpty);
    expect(find.text('Sleep and recovery'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('the theme switches to grey and blue and back, and is saved', (tester) async {
    final c = await pumpApp(tester);
    await onboard(tester, 'On my own', 'Dani');
    expect(BoltColors.neon, const Color(0xFFC6FF1A));
    c.read(routerProvider).push('/settings');
    await settle(tester);
    await tapText(tester, 'Orange and neon');
    await settle(tester);
    expect(find.text('Grey and blue'), findsOneWidget);
    expect(c.read(boltProvider).settings.blue, isTrue);
    expect(BoltColors.page, const Color(0xFF00008E));
    expect(BoltColors.neon, const Color(0xFFFFFFFF));
    expect(BoltColors.onNeon, const Color(0xFF000000));
    expect(BoltColors.glow(0x40).a, 0);
    // Everything meant to be read directly on the blue page clears 4.5:1.
    for (final c in [BoltColors.text, BoltColors.textSoft, BoltColors.muted, BoltColors.muted2, BoltColors.muted3]) {
      final ratio = (c.computeLuminance() + .05) / (BoltColors.page.computeLuminance() + .05);
      expect(ratio, greaterThan(4.5));
    }
    expect(AppSettings.fromJson(c.read(boltProvider).settings.toJson()).blue, isTrue);
    await tapText(tester, 'Grey and blue');
    await settle(tester);
    expect(BoltColors.neon, const Color(0xFFC6FF1A));
    expect(BoltColors.onNeon, BoltColors.ink);
    await unmount(tester);
  });

  testWidgets('only the admin gets Add a user: paste keys once, the bolt crosses one off', (tester) async {
    var c = await pumpApp(tester);
    await onboard(tester, 'On my own', 'Dani');
    c.read(routerProvider).push('/settings');
    await settle(tester);
    expect(find.text('Add a user'), findsNothing);
    await unmount(tester);

    c = await pumpApp(tester);
    await onboard(tester, 'I coach people', 'Dani', code: '222222');
    c.read(routerProvider).push('/settings');
    await settle(tester);
    await tapText(tester, 'Add a user');
    await settle(tester);
    expect(find.text('AAAA-BBBB'), findsNothing);

    // Junk and unknown keys are ignored; the list comes out in order.
    await typeInto(tester, 'Paste your keys', '| 2 | eeee-ffff | ZZZZ-ZZZZ | coachdd2 CCCC-DDDD | AAAA-BBBB |');
    await tapText(tester, 'Save keys');
    await settle(tester);
    final s = c.read(boltProvider).settings;
    expect(s.ownKeys, {'Solo 1': 'AAAA-BBBB', 'Solo 2': 'EEEE-FFFF', 'Coach 2': 'CCCC-DDDD'});
    expect(find.text('SOLO · 0 of 2 given'), findsOneWidget);

    TextStyle? style() => tester.widget<Text>(find.text('AAAA-BBBB')).style;
    expect(style()?.decoration, TextDecoration.none);
    await tester.tap(find.bySemanticsLabel('Solo 1').last);
    await settle(tester);
    expect(c.read(boltProvider).settings.usedKeys, ['Solo 1']);
    expect(style()?.decoration, TextDecoration.lineThrough);
    expect(find.text('SOLO · 1 of 2 given'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Solo 1').last);
    await settle(tester);
    expect(c.read(boltProvider).settings.usedKeys, isEmpty);
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
    // One question at a time: an answer moves on by itself, hours and the
    // sore parts take a Next.
    // The next question slides in after the bolt.
    Future<void> answer(String text) async {
      await tapText(tester, text);
      await tester.pump(const Duration(milliseconds: 600));
    }

    expect(find.text('How many hours of sleep?'), findsOneWidget);
    await tapText(tester, '+');
    await answer('Next');
    await answer('Bad');
    expect(find.text('How is your energy?'), findsOneWidget);
    await answer('Low');
    await answer('Down');
    await answer('Very sore');
    expect(find.text('Where is it sore?'), findsOneWidget);
    await tapText(tester, 'Legs');
    await answer('Next');
    expect(find.text('Grip check'), findsOneWidget);
    // Nothing is saved until every question has an answer.
    await tapText(tester, 'Save check-in');
    expect(c.read(boltProvider).trainees.single.readiness, isEmpty);
    await tester.ensureVisible(find.byKey(const ValueKey('grip')));
    await settle(tester);
    final grip = tester.getRect(find.byKey(const ValueKey('grip')));
    await tester.tapAt(Offset(grip.left + 12 + (grip.width - 24) * .3, grip.center.dy));
    await settle(tester);
    // The scale's ends stay; the chosen value has no readout of its own.
    expect(find.text('0%'), findsOneWidget);
    expect(find.text('100%'), findsOneWidget);
    expect(find.text('30%'), findsNothing);
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

  testWidgets('a new day opens on the check-in, which skips or saves straight into Bolt', (tester) async {
    var now = wed;
    final c = await pumpApp(tester, clock: () => now);
    await onboard(tester, 'On my own', 'Dani');
    final store = c.read(boltProvider.notifier);
    // Setup day: no check-in screen over Today.
    expect(find.text('Good evening, Dani'), findsNothing);

    Finder gate(Finder f) => find.descendant(of: find.byType(CheckInGate), matching: f).first;
    Future<void> tapGate(String text) async {
      await tester.ensureVisible(gate(find.text(text)));
      await tester.tap(gate(find.text(text)));
      await settle(tester);
      await tester.pump(const Duration(milliseconds: 600));
    }

    Future<void> nextDay() async {
      now = now.add(const Duration(days: 1));
      store.dismissHint('tick');
      await settle(tester);
      await tester.pump(const Duration(milliseconds: 800));
    }

    // Thursday: it opens first thing, and Skip keeps it away for the day.
    await nextDay();
    expect(find.text('Good evening, Dani'), findsOneWidget);
    expect(find.text('NEW DAY · THU 15 OCT'), findsOneWidget);
    await tapGate('Skip');
    expect(find.text('Good evening, Dani'), findsNothing);
    store.dismissHint('tick');
    await settle(tester);
    expect(find.text('Good evening, Dani'), findsNothing);
    expect(c.read(boltProvider).trainees.single.readiness, isEmpty);

    // Friday: answered in the gate, it shows the score and lets you in.
    await nextDay();
    expect(find.text('Good evening, Dani'), findsOneWidget);
    expect(c.read(boltProvider).settings.hintsSeen.where((h) => h.startsWith('checkin:')), ['checkin:2026-10-15']);
    // Fresh skips where it is sore.
    for (final a in ['+', 'Next', 'Great', 'High', 'Good', 'Fresh']) {
      await tapGate(a);
    }
    await tester.ensureVisible(gate(find.byKey(const ValueKey('grip'))));
    await settle(tester);
    final grip = tester.getRect(gate(find.byKey(const ValueKey('grip'))));
    await tester.tapAt(Offset(grip.right - 12, grip.center.dy));
    await settle(tester);
    await tapGate('Save check-in');
    expect(c.read(boltProvider).trainees.single.readiness.keys, ['2026-10-16']);
    expect(gate(find.textContaining('READINESS · ')), findsOneWidget);
    await tapGate('Into Bolt');
    expect(find.text('Good evening, Dani'), findsNothing);
    expect(find.text('Into Bolt'), findsNothing);
    expect(tester.takeException(), isNull);
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
    await tester.ensureVisible(find.byType(BackBox).first);
    await settle(tester);
    await tester.tap(find.byType(BackBox).first);
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
    expect(find.textContaining('UNLOCKED'), findsOneWidget);
    while (find.textContaining('UNLOCKED').evaluate().isNotEmpty) {
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
    await tapText(tester, 'Classic');
    await settle(tester);
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
    await back(tester);
    expect(tester.getTopLeft(find.text('Your workouts')).dy, lessThan(tester.getTopLeft(find.text('Classic')).dy));
    await tapText(tester, 'Your workouts');
    await settle(tester);
    await tapLabel(tester, 'Close');
    expect(find.text('Your workouts'), findsNothing);
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
    await tapText(tester, 'Classic');
    await settle(tester);
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

  testWidgets('a workout finished early is not measured against the standard', (tester) async {
    final c = await pumpApp(tester);
    await onboard(tester, 'On my own', 'Dani');
    final store = c.read(boltProvider.notifier);
    store.addFromRotation(Account.ownerId, '2026-10-12');
    store.setTemplate(Account.ownerId, '2026-10-12', 'push');
    store.logPast('2026-10-12');
    final s = c.read(boltProvider).plans[Account.ownerId]!['2026-10-12']!;
    s.ex.first.logged.add(SetLog(kg: 80, reps: 5));
    s.log = '1/${s.totalSets} sets';
    c.read(routerProvider).push('/summary/2026-10-12');
    await settle(tester);
    expect(find.textContaining('your standard'), findsNothing);
    expect(find.text('Make this my standard'), findsNothing);
    expect(find.text('400 kg'), findsOneWidget);
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

  testWidgets('an alternate goes on the ready page and moves', (tester) async {
    final c = await pumpApp(tester);
    await onboard(tester, 'On my own', 'Dani');
    await tapText(tester, 'Open workout');
    final ex = c.read(boltProvider).plans[Account.ownerId]!['2026-10-14']!.ex;
    final count = ex.length;
    await tapText(tester, 'Alternate Exercise');
    await tapText(tester, 'Push-up');
    expect(ex.length, count + 1);
    expect(ex.last.name, 'Push-up');
    expect(find.textContaining('ALTERNATE'), findsOneWidget);

    await tapText(tester, '↑');
    expect(ex[count - 1].name, 'Push-up');
    await unmount(tester);
  });

  testWidgets('an alternate added mid workout asks first or after, then rest', (tester) async {
    final c = await pumpApp(tester);
    await onboard(tester, 'On my own', 'Dani');
    await tapText(tester, 'Open workout');
    await tapText(tester, 'START');
    await tapText(tester, 'Warm-up done');
    final ex = c.read(boltProvider).plans[Account.ownerId]!['2026-10-14']!.ex;
    final main = ex.first;

    // No rest: Done, 5 seconds to get in position, then the other exercise.
    await tapText(tester, 'Alternate Exercise');
    await tapText(tester, 'Push-up');
    expect(find.textContaining('first or after'), findsOneWidget);
    await tapText(tester, 'After');
    expect(find.text('Rest between them?'), findsOneWidget);
    await tapText(tester, 'No rest');
    expect((ex[0], ex[1].name, ex[1].noRest), (main, 'Push-up', true));

    await tapText(tester, 'Done · set 1');
    expect(find.text('GET READY'), findsOneWidget);
    expect(find.text('REST'), findsNothing);
    await tester.pump(const Duration(seconds: 6));
    await settle(tester);
    expect(find.text('GET READY'), findsNothing);
    expect(find.text('Push-up'), findsOneWidget);

    // The round is done, so now a real rest.
    await tapText(tester, 'Done · set 1');
    expect(find.text('REST'), findsOneWidget);
    await tester.pump(const Duration(minutes: 6));
    await settle(tester);
    expect(find.text(main.name), findsOneWidget);
    expect(tester.takeException(), isNull);

    // First: it is the set to do right now, with a rest worked out after it.
    await tester.tap(find.text('Alternate Exercise'));
    await settle(tester);
    await tapText(tester, 'Plank');
    await tapText(tester, 'First');
    await tapText(tester, 'Rest');
    expect(ex[0].name, 'Plank');
    expect(ex[0].noRest, isFalse);
    expect(find.text('Plank'), findsOneWidget);
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

  testWidgets('the rack is taken: swap the exercise from gym floor mode', (tester) async {
    final c = await pumpApp(tester);
    await onboard(tester, 'On my own', 'Dani');
    await tapText(tester, 'Open workout');
    final s = c.read(boltProvider).plans[Account.ownerId]!['2026-10-14']!;
    final first = s.ex.first;
    final was = first.name;
    await tapText(tester, 'START');
    await tapText(tester, 'Warm-up done');

    // On the set itself, one tap to the alternatives for the same muscle.
    expect(find.text(was), findsOneWidget);
    await tapText(tester, 'Swap exercise');
    expect(find.text('Swap $was'), findsOneWidget);
    final to = swapOptions(first, c.read(boltProvider.notifier).tr(Account.ownerId)).first.name;
    await tapText(tester, to);

    // The set carries on under the new name, warm-up not repeated.
    expect(first.name, to);
    expect(first.swapped, isTrue);
    expect(first.orig, was);
    expect(find.text(to), findsWidgets);
    expect(find.textContaining('SET 1 OF'), findsOneWidget);

    // Once a set is ticked the swap is gone: the log belongs to what was
    // actually done.
    await tapText(tester, 'Done · set 1');
    await tapText(tester, 'Skip');
    expect(find.text('Swap exercise'), findsNothing);
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
    expect(find.text('PLATINUM I'), findsOneWidget);
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
    await tapLabel(tester, 'Next');
    await tapLabel(tester, 'Next');
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
    await tapText(tester, 'Classic');
    await settle(tester);
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
    await tester.ensureVisible(find.widgetWithText(NeonButton, 'Add trainee'));
    await settle(tester);
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
    await typeKey(tester, '44444');
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
    await typeKey(tester, '44444');
    expect(find.text('Could not load the coach list. Type your coach\'s name instead.'), findsOneWidget);
    await typeInto(tester, 'Your name', 'Ana');
    await typeInto(tester, 'Coach\'s name (optional)', 'Marko');
    await tapText(tester, 'Continue');
    await tapText(tester, 'Start training');
    expect(c.read(boltProvider).trainees.single.coachName, 'Marko');
    await unmount(tester);
  });

  testWidgets('every way of training needs a key that fits it', (tester) async {
    await pumpApp(tester);
    await tapText(tester, 'I coach people');
    expect(find.text('Type your key'), findsOneWidget);
    await typeKey(tester, '12345');
    expect(find.text('That key does not open Bolt. Check it and try again.'), findsOneWidget);
    await typeKey(tester, '33333');
    expect(find.text('That key is for a different way of training. Go back and pick the right one.'), findsOneWidget);
    await typeKey(tester, '11111');
    expect(find.text('About you'), findsOneWidget);
    expect(find.text('STEP 1 OF 2'), findsOneWidget);
    // Back from the profile step returns to the key, then to the roles.
    await tester.tap(find.byType(BackBox).first);
    await settle(tester);
    expect(find.text('Type your key'), findsOneWidget);
    await tester.tap(find.byType(BackBox).first);
    await settle(tester);
    expect(find.text('HOW DO YOU TRAIN?'), findsOneWidget);
    // Solo and trainee keys only fit their own way too.
    await tapText(tester, 'With a coach');
    await typeKey(tester, '33333');
    expect(find.text('About you'), findsNothing);
    await typeKey(tester, '44444');
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
    await typeInto(tester, 'Your key', '99999');
    await tapText(tester, 'Open Bolt');
    expect(find.text('That key does not open Bolt. Check it and try again.'), findsOneWidget);
    await typeInto(tester, 'Your key', '222222');
    await tapText(tester, 'Open Bolt');
    // Straight back in, with the training data still there.
    expect(find.text('Hey Dani'), findsOneWidget);
    final log = c.read(boltProvider).settings.keyLog;
    expect([for (final e in log) '${e.name}:${e.how}'], ['Unknown:wrong', 'Admin:ok']);
    // The admin key makes the phone an admin: every role, ADMIN in Settings.
    expect(c.read(boltProvider).account!.admin, isTrue);
    expect(c.read(boltProvider.notifier).switchRoles, [Role.coach, Role.trainee, Role.solo]);
    expect(c.read(boltProvider).coaches.single.name, 'Dani Kovač');
    await unmount(tester);
  });

  testWidgets('after the reset any real key opens a solo phone, and coaches need a coach key', (tester) async {
    final data = await afterUpdate(tester);
    final c = await pumpApp(tester, data: data);
    await typeInto(tester, 'Your key', '33333');
    await tapText(tester, 'Open Bolt');
    expect(find.text('Hey Dani'), findsOneWidget);
    expect(c.read(boltProvider).settings.keyLog.last.name, 'Solo 1');
    expect(c.read(boltProvider).account!.role, Role.solo);
    await unmount(tester);

    data.settings.keyGen = 0;
    data.account = Account(Role.coach, Account.ownerId);
    data.coaches.add(Coach(id: Account.ownerId, name: 'Dani', role: 'Coach'));
    final c2 = await pumpApp(tester, data: data);
    await typeInto(tester, 'Your key', '44444');
    await tapText(tester, 'Open Bolt');
    expect(find.text('This phone is set up for coaching, so it needs a coach key.'), findsOneWidget);
    expect(c2.read(boltProvider).settings.keyLog.last.how, 'needsCoach');
    await typeInto(tester, 'Your key', '11111');
    await tapText(tester, 'Open Bolt');
    expect(c2.read(boltProvider.notifier).needsKey, isFalse);
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

  testWidgets('the stopwatch laps, ranks them and keeps running when you leave', (tester) async {
    var now = wed;
    await pumpApp(tester, clock: () => now);
    await onboard(tester, 'On my own', 'Dani');
    await tapTab(tester, 'Check in');
    await tapText(tester, 'Stopwatch');
    await tapText(tester, 'Start');

    // Three laps of 5, 9 and 7 seconds.
    for (final secs in [5, 9, 7]) {
      now = now.add(Duration(seconds: secs));
      await tapText(tester, 'Lap');
    }
    // Lap 1's split and its total are both 5 s, so that one shows twice.
    expect(find.text('00:05.00'), findsNWidgets(2));
    expect(find.text('00:09.00'), findsOneWidget);
    expect(find.text('00:07.00'), findsOneWidget);
    expect(find.text('00:14.00'), findsOneWidget);
    // 21 s is the total, lap 3's total and the fresh lap 4's total at once.
    expect(find.text('00:21.00'), findsWidgets);
    // Only once there are three to compare does ranking mean anything.
    expect(find.text('QUICKEST'), findsOneWidget);
    expect(find.text('SLOWEST'), findsOneWidget);
    // The lap in progress sits on top of the finished ones.
    expect(find.text('04'), findsOneWidget);

    // Leaving the screen does not stop it: the quick screen says so, and
    // the laps are still there on the way back.
    await back(tester);
    await tapTab(tester, 'Check in');
    expect(find.text('Still running'), findsOneWidget);
    now = now.add(const Duration(seconds: 3));
    await tapText(tester, 'Stopwatch');
    expect(find.text('00:24.00'), findsWidgets);
    expect(find.text('QUICKEST'), findsOneWidget);

    await tapText(tester, 'Stop');
    await tapText(tester, 'Reset');
    expect(find.text('LAPS'), findsNothing);
    expect(find.text('00:00.00'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });

  testWidgets('the stopwatch goes back and forth from where it was reversed', (tester) async {
    var now = wed;
    await pumpApp(tester, clock: () => now);
    await onboard(tester, 'On my own', 'Dani');
    await tapTab(tester, 'Check in');
    await tapText(tester, 'Stopwatch');

    // Under a second there is nothing to go back over.
    await tapText(tester, 'Start');
    await tapText(tester, 'Reverse');
    expect(find.text('Reverse'), findsOneWidget);

    now = now.add(const Duration(seconds: 30));
    await tapText(tester, 'Reverse');
    expect(find.text('Reverse'), findsNothing);
    expect(find.text('Back and forth: 0 to 00:30.00'), findsOneWidget);

    // 12 s back, then held and picked up again from the same spot.
    now = now.add(const Duration(seconds: 12));
    await tapText(tester, 'Stop');
    expect(find.text('00:18.00'), findsWidgets);
    now = now.add(const Duration(minutes: 5));
    await tapText(tester, 'Resume');
    expect(find.text('00:18.00'), findsWidgets);

    await tapText(tester, 'Stop');
    await tapText(tester, 'Reset');
    expect(find.text('Reverse'), findsOneWidget);
    expect(find.text('00:00.00'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });

  test('a reversed watch bounces between its peak and zero, with cues on each stretch', () {
    const peak = Duration(seconds: 10);
    final start = DateTime(2026);
    Duration on(int secs) => Watch(
      carried: Duration(seconds: secs),
      peak: peak,
    ).at(start);
    expect(on(0), peak);
    expect(on(3), const Duration(seconds: 7));
    expect(on(10), Duration.zero);
    expect(on(13), const Duration(seconds: 3));
    expect(on(20), peak);
    expect(on(23), const Duration(seconds: 7));

    // Over two full stretches: blips at 5, 4, 3, 2, 1 left, then the turn.
    const w = Watch(peak: peak);
    final cues = <({Duration at, bool end})>[];
    var from = Duration.zero;
    while (cues.length < 12) {
      final cue = w.nextCue(from);
      cues.add(cue);
      from = cue.at;
    }
    expect(cues.map((c) => c.at.inSeconds), [5, 6, 7, 8, 9, 10, 15, 16, 17, 18, 19, 20]);
    expect(cues.where((c) => c.end).map((c) => c.at.inSeconds), [10, 20]);

    // A stretch of 3 seconds only has room for 2 and 1 before the turn.
    const short = Watch(peak: Duration(seconds: 3));
    final first = short.nextCue(Duration.zero);
    expect((first.at.inSeconds, first.end), (1, false));
    final turn = short.nextCue(const Duration(seconds: 2));
    expect((turn.at.inSeconds, turn.end), (3, true));
  });

  testWidgets('the stopwatch has two faces and remembers which', (tester) async {
    final c = await pumpApp(tester);
    await onboard(tester, 'On my own', 'Dani');
    await tapTab(tester, 'Check in');
    await tapText(tester, 'Stopwatch');
    // The chronograph is the one out of the box; nothing on screen says the
    // other face is there, a sideways swipe across the watch turns it over.
    expect(find.text('READY'), findsNothing);
    await swipeFace(tester);
    expect(find.text('READY'), findsOneWidget);
    expect(c.read(boltProvider).settings.watchFace, 'digital');

    // Still the digital one on the way back in.
    await back(tester);
    await tapTab(tester, 'Check in');
    await tapText(tester, 'Stopwatch');
    expect(find.text('READY'), findsOneWidget);
    await swipeFace(tester);
    expect(find.text('READY'), findsNothing);
    expect(c.read(boltProvider).settings.watchFace, 'dial');
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
    await typeInto(tester, 'Your key', '222222');
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
    await typeInto(tester, 'Your key', '222222');
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
    expect(find.text('1 h before'), findsOneWidget);

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
    await tapLabel(tester, 'Next');
    expect(find.text('November'), findsOneWidget);
    expect(find.text('SUN 1 NOV'), findsOneWidget);

    await tapLabel(tester, 'Previous');
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
    while (find.textContaining('UNLOCKED').evaluate().isNotEmpty) {
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
    // Found when Bolt opened: a card on Today and a dot on Me.
    expect(find.text('Bolt 1.3.0 is out'), findsOneWidget);
    expect(
      find.byWidgetPredicate((w) => w is Semantics && w.properties.label == 'Me' && w.properties.hint == 'New version'),
      findsOneWidget,
    );
    await tapTab(tester, 'Me');
    expect(find.text('ADMIN · VIEW AS'), findsNothing);
    expect(find.text('Bolt 1.2.0'), findsOneWidget);
    expect(find.text('Bolt 1.3.0 is ready to install'), findsOneWidget);
    await tapText(tester, 'Update');
    expect(find.text('BOLT 1.3.0'), findsOneWidget);
    expect(find.text('• Faster'), findsOneWidget);
    expect(find.text('Download and install'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('the new version card closes for that version', (tester) async {
    await pumpApp(
      tester,
      updater: FakeUpdater(
        const UpdateFound(
          Release(title: 'BOLT 1.3.0', version: '1.3.0', build: 4, notes: '', apkUrl: 'u', apkBytes: 1),
        ),
      ),
    );
    await onboard(tester, 'On my own', 'Dani');
    expect(find.text('Bolt 1.3.0 is out'), findsOneWidget);
    await tester.tap(find.descendant(of: find.byType(NewVersionCard), matching: find.byType(CloseGlyph)));
    await settle(tester);
    expect(find.text('Bolt 1.3.0 is out'), findsNothing);
    await unmount(tester);
  });

  testWidgets('tapping the new-version notification opens the update sheet', (tester) async {
    await pumpApp(tester);
    await onboard(tester, 'On my own', 'Dani');
    openShortcut('update');
    await settle(tester);
    expect(find.text('You are up to date'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('no dot or card when Bolt is up to date', (tester) async {
    await pumpApp(tester);
    await onboard(tester, 'On my own', 'Dani');
    expect(find.textContaining('is out'), findsNothing);
    expect(find.byWidgetPredicate((w) => w is Semantics && w.properties.hint == 'New version'), findsNothing);
    await unmount(tester);
  });

  testWidgets('the blue theme has a black nav bar and a backed calendar', (tester) async {
    final c = await pumpApp(tester);
    await onboard(tester, 'On my own', 'Dani');
    c.read(boltProvider.notifier).toggleTheme();
    await settle(tester);
    final bar = find.descendant(of: find.byType(BoltNavBar), matching: find.byType(ColoredBox));
    expect(tester.widget<ColoredBox>(bar.first).color, Colors.black);
    await tapTab(tester, 'Plan');
    expect(find.byType(BluePanel), findsWidgets);
    expect(find.descendant(of: find.byType(BluePanel), matching: find.byType(CalendarGrid)), findsWidgets);
    c.read(boltProvider.notifier).toggleTheme();
    await unmount(tester);
  });

  testWidgets('only what sits straight on the blue page gets a fill', (tester) async {
    Color? fillOf(Key key) =>
        (tester
                    .widget<Container>(find.descendant(of: find.byKey(key), matching: find.byType(Container)).first)
                    .decoration
                as BoxDecoration)
            .color;
    const stroke = Stroke(Colors.white);
    BoltColors.blue = true;
    addTearDown(() => BoltColors.blue = false);
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Column(
          children: [
            BoltBox(key: Key('page'), stroke: stroke, height: 10, width: 10),
            BoltBox(
              color: Colors.white,
              child: BoltBox(key: Key('card'), stroke: stroke, height: 10, width: 10),
            ),
            OnSurface(
              child: BoltBox(key: Key('surface'), stroke: stroke, height: 10, width: 10),
            ),
          ],
        ),
      ),
    );
    expect(fillOf(const Key('page')), BoltColors.surface1);
    expect(fillOf(const Key('card')), isNull);
    expect(fillOf(const Key('surface')), isNull);
  });

  testWidgets('Me has Call a friend with a QR code, and the language moved to Settings', (tester) async {
    final c = await pumpApp(tester);
    await onboard(tester, 'On my own', 'Dani');
    await tapTab(tester, 'Me');
    expect(find.byType(LanguagePicker), findsNothing);
    await tapText(tester, 'Call a friend');
    await settle(tester);
    expect(find.byType(QrImageView), findsOneWidget);
    expect(find.text('bolt.x3kk3x.cloud'), findsOneWidget);
    await tester.tapAt(const Offset(20, 20));
    await settle(tester);
    c.read(routerProvider).push('/settings');
    await settle(tester);
    expect(find.byType(LanguagePicker), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('signing up never fills the calendar', (tester) async {
    final c = await pumpApp(tester);
    await onboard(tester, 'On my own', 'Dani', planned: false);
    expect(c.read(boltProvider.notifier).plan(Account.ownerId), isEmpty);
    expect(find.text('Nothing planned yet'), findsWidgets);
    await unmount(tester);
  });

  testWidgets('clear month asks first, then leaves finished workouts', (tester) async {
    final c = await pumpApp(tester);
    await onboard(tester, 'On my own', 'Dani');
    final store = c.read(boltProvider.notifier);
    final month = DateTime(store.now.year, store.now.month);
    await tapTab(tester, 'Plan');
    await tapText(tester, 'Clear month');
    await settle(tester);
    expect(find.text('Are you sure?'), findsOneWidget);
    await tapText(tester, 'Cancel');
    await settle(tester);
    final before = store.plan(Account.ownerId).length;
    expect(before, greaterThan(0));
    store.clearMonth(Account.ownerId, month);
    expect(store.hasPlansIn(Account.ownerId, month), isFalse);
    await unmount(tester);
  });

  testWidgets('About you starts with every split category shut, the chosen one named', (tester) async {
    await pumpApp(tester);
    await tapText(tester, 'On my own');
    await typeKey(tester, keyFor('On my own'));
    expect(find.byType(SplitWeek), findsNothing);
    expect(find.text('3-day Push / Pull / Legs'), findsOneWidget);
    await tapText(tester, 'Classic');
    await settle(tester);
    expect(find.byType(SplitWeek), findsWidgets);
    await unmount(tester);
  });

  testWidgets('workouts open and close by category', (tester) async {
    await pumpApp(tester);
    await onboard(tester, 'On my own', 'Dani');
    await tapTab(tester, 'Workouts');
    expect(find.text('Push'), findsNothing);
    expect(find.text('Chest'), findsNothing);
    await tapText(tester, 'Classic');
    await settle(tester);
    expect(find.text('Push'), findsOneWidget);
    await tapText(tester, 'One muscle a day');
    await settle(tester);
    expect(find.text('Chest'), findsOneWidget);
    expect(find.text('Weekly splits'), findsOneWidget);
    await unmount(tester);
  });

  group('as the PWA', () {
    setUp(() => isPwa = true);
    tearDown(() => isPwa = false);

    testWidgets('the bell only carries news', (tester) async {
      await pumpApp(tester);
      await onboard(tester, 'On my own', 'Dani');
      expect(find.bySemanticsLabel('Notifications'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Notifications'));
      await settle(tester);
      expect(find.text('No news yet. Messages from Bolt show up here.'), findsOneWidget);
      for (final gone in ['App', 'Water', 'Supplements', 'Training', 'Session reminders', 'Morning brief']) {
        expect(find.text(gone), findsNothing, reason: gone);
      }
      await unmount(tester);
    });

    testWidgets('settings hide what cannot work and warn about the home screen', (tester) async {
      final c = await pumpApp(tester);
      await onboard(tester, 'On my own', 'Dani');
      c.read(routerProvider).push('/settings');
      await settle(tester);
      for (final gone in [
        'NOTIFICATIONS',
        'Session reminders',
        'Morning brief',
        'Check-out reminder',
        'Haptics',
        'Volume down logs a set',
      ]) {
        expect(find.text(gone), findsNothing, reason: gone);
      }
      for (final kept in ['Rest sound', '3-2-1 countdown', 'Back up to a file', 'Restore from a backup', 'Theme']) {
        expect(find.text(kept), findsOneWidget, reason: kept);
      }
      expect(find.textContaining('Removing Bolt from your home screen'), findsOneWidget);
      // Admin only: a solo user never sees it.
      expect(find.text('Add a user'), findsNothing);
      await unmount(tester);
    });

    testWidgets('Today has no update or 1.24 card and never asks for a new version', (tester) async {
      await pumpApp(
        tester,
        updater: FakeUpdater(
          const UpdateFound(
            Release(title: 'Bolt 9', version: '9.0.0', build: 900, notes: '', apkUrl: 'x', apkBytes: 1),
          ),
        ),
      );
      await onboard(tester, 'On my own', 'Dani');
      expect(find.textContaining('is out'), findsNothing);
      expect(find.text('NEW IN BOLT 1.24'), findsNothing);
      await tapTab(tester, 'Me');
      expect(find.text('Get the newest version without reinstalling'), findsNothing);
      expect(find.text('Check'), findsNothing);
      await unmount(tester);
    });
  });
}
