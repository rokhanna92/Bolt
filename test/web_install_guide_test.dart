@TestOn('browser')
library;

import 'package:bolt/web/install_guide.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// The guide sits outside the app's pages. Without its own Material, Flutter
// draws its text red with a yellow underline. Run with
// flutter test --platform chrome test/web_install_guide_test.dart

void main() {
  testWidgets('the guide has real text styling and fits a small phone', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var skipped = false;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Stack(
            children: [Positioned.fill(child: InstallGuide(onSkip: () => skipped = true))],
          ),
        ),
      ),
    );
    await tester.pump();
    final texts = find.byType(RichText).evaluate().map((e) => e.widget as RichText).toList();
    expect(texts, isNotEmpty);
    for (final t in texts) {
      final style = (t.text as TextSpan).style;
      expect(style?.decoration, anyOf(isNull, TextDecoration.none), reason: t.text.toPlainText());
      expect(style?.color?.r, isNot(closeTo(0xD0 / 255, .01)), reason: t.text.toPlainText());
    }
    expect(find.text('1'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('Continue in the browser'));
    await tester.pump();
    await tester.tap(find.text('Continue in the browser'));
    expect(skipped, isTrue);
  });
}
