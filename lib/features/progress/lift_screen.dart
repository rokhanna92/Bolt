import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/actions.dart';
import '../../core/format.dart';
import '../../core/units.dart';
import '../../data/bolt_store.dart';
import '../../data/lifts.dart';
import '../../data/seed/learn.dart';
import '../../theme/text_styles.dart';
import '../../theme/tokens.dart';
import '../../widgets/common.dart';
import '../../widgets/sparkline.dart';
import '../../widgets/tap.dart';

/// One lift over time: best estimated max, heaviest set, a trend and every
/// workout's sets.
class LiftScreen extends ConsumerWidget {
  const LiftScreen({super.key, required this.name});

  final String name;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(boltProvider);
    final store = ref.read(boltProvider.notifier);
    final t = store.trOrNull(d.account?.id ?? '');
    final days = t == null ? <LiftDay>[] : liftHistory(store.plan(t.id), name);
    final metric = d.settings.kg;
    final insets = MediaQuery.paddingOf(context);
    String kg(double v) => '${weightValue(v, metric: metric)} ${weightUnit(metric)}';
    double? most(double? Function(LiftDay) f) =>
        days.map(f).whereType<double>().fold<double?>(null, (a, b) => a == null || b > a ? b : a);
    final best = most((x) => x.best), top = most((x) => x.topKg);
    final weighted = days.any((x) => x.best != null);
    final trend = [
      for (final x in days)
        if (weighted ? x.best != null : x.topReps != null) weighted ? x.best! : x.topReps!.toDouble(),
    ];

    return BoltPage(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, insets.top + 16, 20, 60 + insets.bottom),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                BackBox(onTap: () => context.pop()),
                const SizedBox(width: 12),
                const Expanded(child: Kicker('LIFT')),
                if (kHow.containsKey(name))
                  Tap(
                    onTap: () => showExerciseSheet(name),
                    child: Text('How to do it', style: BoltText.a(13, weight: 700, color: BoltColors.neon)),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Text(name.toUpperCase(), style: BoltText.a(tsz(name, 40), weight: 900, width: 112, color: BoltColors.neon)),
            const SizedBox(height: 16),
            StatRow(
              children: [
                StatTile(
                  value: best == null ? '-' : kg(best),
                  label: 'EST. 1RM',
                  valueSize: 18,
                  valueWeight: 800,
                  valueColor: BoltColors.neon,
                  labelFirst: true,
                  gap: 4,
                ),
                StatTile(
                  value: top == null ? '-' : kg(top),
                  label: 'HEAVIEST',
                  valueSize: 18,
                  valueWeight: 800,
                  labelFirst: true,
                  gap: 4,
                ),
                StatTile(
                  value: '${days.length}',
                  label: 'WORKOUTS',
                  valueSize: 18,
                  valueWeight: 800,
                  labelFirst: true,
                  gap: 4,
                ),
              ],
            ),
            if (trend.length >= 2) ...[
              const SizedBox(height: 18),
              Kicker(weighted ? 'ESTIMATED 1RM PER WORKOUT' : 'BEST REPS PER WORKOUT', size: 9),
              const SizedBox(height: 8),
              Sparkline(values: trend, height: 70),
            ],
            const SizedBox(height: 22),
            const SectionTitle('History'),
            const SizedBox(height: 8),
            if (days.isEmpty) Text('No logged sets yet.', style: BoltText.a(13, color: BoltColors.muted)),
            for (final x in days.reversed)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: BoltColors.divider)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Kicker(fmtDay(x.date).toUpperCase(), size: 10, spacing: .08)),
                        if (x.best != null)
                          Text('e1RM ${kg(x.best!)}', style: BoltText.m(10, weight: 700, color: BoltColors.neon)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      x.sets
                          .map(
                            (s) => [
                              if (s.kg != null) weightValue(s.kg, metric: metric),
                              if (s.reps != null) '${s.reps}',
                            ].join('×'),
                          )
                          .where((v) => v.isNotEmpty)
                          .join('  ·  '),
                      style: BoltText.a(14, weight: 700),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
