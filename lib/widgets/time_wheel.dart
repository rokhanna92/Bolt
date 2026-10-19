import 'package:flutter/material.dart';

import '../core/format.dart';
import '../services/haptics.dart';
import '../theme/text_styles.dart';
import '../theme/tokens.dart';
import 'bolt_sheet.dart';
import 'common.dart';

/// Picks a time of day in 24-hour form on two wheels, hours and minutes in
/// fives, with a haptic tick on every notch. Returns minutes after
/// midnight, or null when closed.
Future<int?> pickTime(BuildContext context, int initial, {required String title}) =>
    showBoltSheet<int>(context, (_) => _TimeWheel(initial: initial, title: title));

class _TimeWheel extends StatefulWidget {
  const _TimeWheel({required this.initial, required this.title});

  final int initial;
  final String title;

  @override
  State<_TimeWheel> createState() => _TimeWheelState();
}

class _TimeWheelState extends State<_TimeWheel> {
  late int _h = widget.initial ~/ 60;
  late int _m = (widget.initial % 60) ~/ 5;
  late final _hours = FixedExtentScrollController(initialItem: _h);
  late final _mins = FixedExtentScrollController(initialItem: _m);

  @override
  void dispose() {
    _hours.dispose();
    _mins.dispose();
    super.dispose();
  }

  Widget _wheel(FixedExtentScrollController c, int count, int step, ValueChanged<int> onPick) => SizedBox(
    width: 90,
    height: 180,
    child: ListWheelScrollView.useDelegate(
      controller: c,
      itemExtent: 48,
      physics: const FixedExtentScrollPhysics(),
      diameterRatio: 1.4,
      overAndUnderCenterOpacity: .35,
      onSelectedItemChanged: (i) {
        Haptics.play(Feel.tick);
        onPick(i);
      },
      childDelegate: ListWheelChildLoopingListDelegate(
        children: [
          for (var i = 0; i < count; i++) Center(child: Text(pad(i * step), style: BoltText.m(30, weight: 700))),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(widget.title, style: BoltText.a(20, weight: 900)),
        const SizedBox(height: 10),
        Stack(
          alignment: Alignment.center,
          children: [
            Container(
              height: 50,
              decoration: BoxDecoration(
                color: BoltColors.surface2,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: BoltColors.neon, width: 1.5),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _wheel(_hours, 24, 1, (i) => _h = i % 24),
                Text(':', style: BoltText.m(30, weight: 700, color: BoltColors.neon)),
                _wheel(_mins, 12, 5, (i) => _m = i % 12),
              ],
            ),
          ],
        ),
        const SizedBox(height: 14),
        NeonButton(label: tx('Save'), height: 52, scale: 1, onTap: () => Navigator.of(context).pop(_h * 60 + _m * 5)),
      ],
    );
  }
}
