import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../data/level.dart';
import '../../data/models/people.dart';
import '../../theme/text_styles.dart';
import '../../theme/tokens.dart';
import '../../widgets/bolt_sheet.dart';
import '../../widgets/box.dart';
import '../../widgets/common.dart';
import '../../widgets/forms.dart';
import '../../widgets/motion.dart';
import '../../widgets/tap.dart';

/// Level, rank and the bar to the next level. Days off rust some XP off the
/// bar until the next workout.
class LevelCard extends StatelessWidget {
  const LevelCard({super.key, required this.stats, required this.daysOff});

  final TraineeStats stats;
  final int daysOff;

  @override
  Widget build(BuildContext context) {
    final lv = levelOf(xpOf(stats));
    final rust = rustOf(daysOff).clamp(0, lv.into);
    final left = lv.into - rust;
    return Tap(
      onTap: () => showBoltSheet<void>(context, (_) => const LevelSheet()),
      child: BoltBox(
        color: BoltColors.surface1,
        stroke: Stroke(rust > 0 ? BoltColors.warn : BoltColors.lineSoft),
        radius: 14,
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text('${tx('LVL')} ${lv.level}', style: BoltText.a(15, weight: 900, color: BoltColors.neon)),
                const SizedBox(width: 8),
                Expanded(child: Kicker(tx(lv.rank).toUpperCase(), size: 10, spacing: .12)),
                RollText(
                  tx('{n} XP TO LVL {next}', {'n': lv.need - left, 'next': lv.level + 1}),
                  style: BoltText.m(10, weight: 700, color: BoltColors.muted),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              // XP fills in from the left, rust sits right after it.
              child: SizedBox(
                height: 6,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    const ColoredBox(color: BoltColors.lineSoft),
                    GrowTo(value: (left + rust) / lv.need, builder: (context, v) => _fill(v, BoltColors.warn)),
                    GrowTo(value: left / lv.need, builder: (context, v) => _fill(v, BoltColors.neon)),
                  ],
                ),
              ),
            ),
            if (rust > 0) ...[
              const SizedBox(height: 6),
              Text(
                tx('−{n} XP rusting after {days}. Train to win it back.', {'n': rust, 'days': plural(daysOff, 'day')}),
                style: BoltText.a(11, weight: 700, color: BoltColors.warn),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

Widget _fill(double v, Color c) => FractionallySizedBox(
  alignment: Alignment.centerLeft,
  widthFactor: v.clamp(0.0, 1.0),
  child: ColoredBox(color: c),
);

/// How XP is earned and the ranks.
class LevelSheet extends StatelessWidget {
  const LevelSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final earn = [
      (tx('Each set you tick'), 10),
      (tx('Each workout logged'), 50),
      (tx('Each gym visit'), 30),
      (tx('Each PR'), 100),
      (tx('Each perfect week'), 200),
    ];
    Widget row(String l, String r) => Container(
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: BoltColors.divider)),
      ),
      child: Row(
        children: [
          Expanded(child: Text(l, style: BoltText.a(14, weight: 600))),
          Text(r, style: BoltText.m(12, weight: 700, color: BoltColors.neon)),
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(tx('Athlete level'), style: BoltText.a(20, weight: 900)),
        const SizedBox(height: 4),
        Text(
          tx(
            'Everything you do in the gym earns XP. Each level takes 100 XP more than the last. From 3 days off, XP starts rusting off your bar until you train again.',
          ),
          style: BoltText.a(13, color: BoltColors.muted, height: 1.45),
        ),
        FieldLabel(tx('XP')),
        for (final (l, n) in earn) row(l, '+$n XP'),
        FieldLabel(tx('RANKS')),
        for (final (l, name) in kRanks) row(tx(name), tx('LVL {n}+', {'n': l})),
      ],
    );
  }
}
