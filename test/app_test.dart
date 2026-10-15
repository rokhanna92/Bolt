import 'dart:io';

import 'package:bolt/app.dart';
import 'package:bolt/data/bolt_store.dart';
import 'package:bolt/data/models/bolt_data.dart';
import 'package:bolt/data/seed/content.dart';
import 'package:bolt/features/gym/scanner_overlay.dart';
import 'package:bolt/features/updates/update_sheet.dart';
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

Future<ProviderContainer> pumpApp(WidgetTester tester, {BoltData? data, Updater? updater}) async {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 2.75;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        clockProvider.overrideWithValue(() => wed),
        initialDataProvider.overrideWithValue(data ?? freshData()),
        updaterProvider.overrideWithValue(updater ?? FakeUpdater(const UpToDate())),
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

/// Goes through onboarding as [role] with [name].
Future<void> onboard(WidgetTester tester, String role, String name, {String? weight}) async {
  expect(find.text('HOW DO YOU TRAIN?'), findsOneWidget);
  await tapText(tester, role);
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
    expect(find.text('Bolt 1.2.0'), findsOneWidget);
    await tapText(tester, 'Update');
    expect(find.text('BOLT 1.3.0'), findsOneWidget);
    expect(find.text('• Faster'), findsOneWidget);
    expect(find.text('Download and install'), findsOneWidget);
    await unmount(tester);
  });
}
