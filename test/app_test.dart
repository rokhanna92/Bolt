import 'dart:io';

import 'package:bolt/app.dart';
import 'package:bolt/data/bolt_store.dart';
import 'package:bolt/data/seed/demo.dart';
import 'package:bolt/features/coach_roster/roster_screen.dart';
import 'package:bolt/features/gym/scanner_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Wednesday 14 Oct 2026, 18:00, the prototype's demo day.
final wed = DateTime(2026, 10, 14, 18);

Future<void> pumpApp(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 2.75;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        clockProvider.overrideWithValue(() => wed),
        initialDataProvider.overrideWithValue(buildDemoData(wed)),
      ],
      child: const BoltApp(),
    ),
  );
  await tester.pump(const Duration(milliseconds: 500));
}

/// Unmounts the app so its timers and animations stop.
Future<void> unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 3));
}

/// Taps, then lets transitions finish. A pushed route stays offstage for its
/// first frame (hero measurement), so pump once before advancing time.
Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
}

Future<void> tapText(WidgetTester tester, String text) async {
  await tester.tap(find.text(text).first);
  await settle(tester);
}

Future<void> loadFont(String family, String path) async {
  final bytes = ByteData.sublistView(File(path).readAsBytesSync());
  await (FontLoader(family)..addFont(Future.value(bytes))).load();
}

void main() {
  // Real fonts, so text measures like on a device.
  setUpAll(() async {
    await loadFont('Archivo', 'assets/fonts/Archivo-Variable.ttf');
    await loadFont('JetBrains Mono', 'assets/fonts/JetBrainsMono-Variable.ttf');
  });

  testWidgets('trainee signs in, sees today and the plan', (tester) async {
    await pumpApp(tester);
    expect(find.text('BOLT'), findsOneWidget);

    await tapText(tester, 'Ana Marić');
    expect(find.text('Hey Ana'), findsOneWidget);
    expect(find.text('PULL'), findsOneWidget);
    expect(find.text('Marko planned 3 sessions'), findsOneWidget);

    await tapText(tester, 'Plan');
    expect(find.text('October'), findsOneWidget);
    expect(find.text('Coming up'), findsOneWidget);

    await unmount(tester);
  });

  testWidgets('accept all confirms the coach plan', (tester) async {
    await pumpApp(tester);
    await tapText(tester, 'Ana Marić');
    await tester.ensureVisible(find.text('Accept all'));
    await tapText(tester, 'Accept all');
    expect(find.text('3 sessions confirmed · Marko notified'), findsOneWidget);
    expect(find.text('Accept all'), findsNothing);
    await unmount(tester);
  });

  testWidgets('scan button checks in from the frame', (tester) async {
    await pumpApp(tester);
    await tapText(tester, 'Ana Marić');
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

  testWidgets('coach sees the roster and what needs attention', (tester) async {
    await pumpApp(tester);
    await tapText(tester, 'Marko Ilić');
    expect(find.text('Coach Marko'), findsOneWidget);
    expect(find.text('Needs you'), findsOneWidget);
    expect(find.text('Luka moved Upper'), findsOneWidget);
    expect(find.text('TRAINEES · 3'), findsOneWidget);

    final ana = find.descendant(of: find.byType(RosterScreen), matching: find.text('Ana Marić'));
    await tester.ensureVisible(ana);
    await tester.tap(ana);
    await settle(tester);
    expect(find.text('Auto-fill 3 wks'), findsOneWidget);
    await unmount(tester);
  });
}
