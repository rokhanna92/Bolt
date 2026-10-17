import 'package:bolt/widgets/bolt_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Opens a sheet whose content is [tall] or short.
Future<void> openSheet(WidgetTester tester, {required bool tall}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Center(
          child: TextButton(
            onPressed: () => showBoltSheet<void>(
              context,
              (_) => Column(children: [const Text('content'), SizedBox(height: tall ? 3000 : 100)]),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  expect(find.text('content'), findsOneWidget);
}

double sheetTop(WidgetTester tester) => tester.getTopLeft(find.text('content')).dy;

void main() {
  for (final tall in [false, true]) {
    final kind = tall ? 'a scrolling sheet' : 'a short sheet';

    testWidgets('$kind closes when dragged down far enough', (tester) async {
      await openSheet(tester, tall: tall);
      await tester.drag(find.text('content'), const Offset(0, 300));
      await tester.pumpAndSettle();
      expect(find.text('content'), findsNothing);
    });

    testWidgets('$kind eases back after a short drag', (tester) async {
      await openSheet(tester, tall: tall);
      final top = sheetTop(tester);
      final g = await tester.startGesture(tester.getCenter(find.text('content')));
      await g.moveBy(const Offset(0, 20));
      await g.moveBy(const Offset(0, 40));
      await tester.pump();
      expect(sheetTop(tester), greaterThan(top + 20));
      await g.up();
      await tester.pump(const Duration(milliseconds: 100));
      expect(sheetTop(tester), greaterThan(top), reason: 'still easing back');
      await tester.pumpAndSettle();
      expect(sheetTop(tester), top);
      expect(find.text('content'), findsOneWidget);
    });
  }
}
