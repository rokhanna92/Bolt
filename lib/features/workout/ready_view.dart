import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/units.dart';
import '../../data/lifts.dart';
import '../../data/models/exercise.dart';
import '../../data/models/session.dart';
import '../../data/rules.dart';
import '../../data/warmup.dart';
import '../../theme/text_styles.dart';
import '../../theme/tokens.dart';
import '../../widgets/box.dart';
import '../../widgets/common.dart';
import '../../widgets/tap.dart';
import 'floor_view.dart';

/// A workout before it starts: every exercise with its sets and the weight
/// it starts from, and a big START. Nothing is logged until START.
class ReadyView extends StatelessWidget {
  const ReadyView({
    super.key,
    required this.session,
    required this.top,
    required this.first,
    required this.hint,
    required this.metric,
    required this.note,
    required this.onStart,
    required this.onAlternate,
    required this.onMove,
    required this.onRemove,
  });

  final Session session;

  /// Back button and the day.
  final Widget top;

  /// What exercise i's first set starts from.
  final SetLog Function(int i) first;
  final LiftHint? Function(int i) hint;
  final bool metric;
  final Widget? note;
  final VoidCallback onStart;

  /// Adds an alternate at the bottom.
  final VoidCallback onAlternate;

  /// Moves alternate i one place up (-1) or down (+1).
  final void Function(int i, int by) onMove;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    final s = session;
    final insets = MediaQuery.paddingOf(context);
    final (warm, _) = warmupPlan(s);
    final chips = [
      plural(s.ex.length, 'exercise'),
      plural(s.totalSets, 'set'),
      '~${s.mins} min',
      tx('warm-up ~{n} min', {'n': warm}),
    ];
    return Stack(
      children: [
        SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(20, insets.top + 16, 20, 120 + insets.bottom),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              top,
              const SizedBox(height: 16),
              Text(
                tx(s.title).toUpperCase(),
                style: BoltText.a(
                  tsz(tx(s.title), 52),
                  weight: 900,
                  width: 115,
                  spacing: -.03,
                  height: .95,
                  color: BoltColors.neon,
                ),
              ),
              const SizedBox(height: 6),
              Text(tx(s.focus), style: BoltText.a(14, color: BoltColors.muted)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final c in chips)
                    BoltBox(
                      radius: 99,
                      stroke: const Stroke(BoltColors.line),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      child: Text(c, style: BoltText.m(11, weight: 600)),
                    ),
                ],
              ),
              if (note != null) ...[const SizedBox(height: 14), note!],
              const SizedBox(height: 16),
              for (var i = 0; i < s.ex.length; i++) ...[if (i > 0) const SizedBox(height: 8), _row(i, s.ex[i])],
              const SizedBox(height: 12),
              OutlineButton(label: tx('Alternate Exercise'), height: 48, fontSize: 14, onTap: onAlternate),
            ],
          ),
        ),
        Positioned(
          left: 20,
          right: 20,
          bottom: 16 + insets.bottom,
          child: NeonButton(label: tx('START'), height: 72, radius: 20, fontSize: 22, onTap: onStart),
        ),
      ],
    );
  }

  Widget _row(int i, Exercise e) {
    final h = hint(i);
    final kg = first(i).kg;
    return BoltBox(
      color: BoltColors.surface1,
      stroke: const Stroke(BoltColors.lineSoft),
      radius: 16,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(pad(i + 1), style: BoltText.m(12, weight: 700, color: BoltColors.muted3)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tx(e.name), style: BoltText.a(16, weight: 800)),
                    const SizedBox(height: 2),
                    Text(
                      [
                        '${e.sets} × ${e.reps}',
                        if (e.alternate) tx('ALTERNATE'),
                        if (e.group != null && e.noRest == null) tx('SUPERSET {g}', {'g': e.group}),
                      ].join(' · '),
                      style: BoltText.m(11, weight: 600, color: e.alternate ? BoltColors.neon : BoltColors.muted),
                    ),
                    if (h != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        tx('Last: {sets}', {'sets': setsText(h.last.sets, metric: metric)}),
                        style: BoltText.a(11, color: BoltColors.muted3),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              if (kg != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      weightValue(kg, metric: metric),
                      style: BoltText.a(22, weight: 900, color: BoltColors.neon),
                    ),
                    Text(weightUnit(metric), style: BoltText.m(10, color: BoltColors.muted)),
                  ],
                )
              else
                Text(
                  unitLoad(e.load, kg: metric),
                  style: BoltText.m(12, weight: 700, color: BoltColors.muted),
                ),
            ],
          ),
          // A paired one stays with its partner, so it only comes off.
          if (e.alternate) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (e.group == null) ...[
                  if (i > 0) SquareButton(label: '↑', onTap: () => onMove(i, -1)),
                  const SizedBox(width: 8),
                  if (i < session.ex.length - 1) SquareButton(label: '↓', onTap: () => onMove(i, 1)),
                  const SizedBox(width: 4),
                ],
                Tap(onTap: () => onRemove(i), child: const CloseGlyph()),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
