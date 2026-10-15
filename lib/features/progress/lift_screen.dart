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
import '../../widgets/bolt_sheet.dart';
import '../../widgets/box.dart';
import '../../widgets/common.dart';
import '../../widgets/fields.dart';
import '../../widgets/sparkline.dart';
import '../../widgets/tap.dart';

/// One lift over time: best estimated max, heaviest set, a trend and every
/// workout's sets.
class LiftScreen extends ConsumerWidget {
  const LiftScreen({super.key, required this.name, this.tid});

  final String name;

  /// A coach looking at a trainee's lift; null for your own.
  final String? tid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(boltProvider);
    final store = ref.read(boltProvider.notifier);
    final t = store.trOrNull(tid ?? d.account?.id ?? '');
    final own = tid == null;
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
                Expanded(child: Kicker(tx('LIFT'))),
                if (kHow.containsKey(name))
                  Tap(
                    onTap: () => showExerciseSheet(name),
                    child: Text(tx('How to do it'), style: BoltText.a(13, weight: 700, color: BoltColors.neon)),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              tx(name).toUpperCase(),
              style: BoltText.a(tsz(tx(name), 40), weight: 900, width: 112, color: BoltColors.neon),
            ),
            const SizedBox(height: 16),
            if (t != null) ...[
              _MaxRow(name: name, tid: t.id, set: t.maxes[name], estimate: best, own: own, metric: metric),
              const SizedBox(height: 10),
            ],
            StatRow(
              children: [
                StatTile(
                  value: best == null ? '-' : kg(best),
                  label: tx('EST. 1RM'),
                  valueSize: 18,
                  valueWeight: 800,
                  valueColor: BoltColors.neon,
                  labelFirst: true,
                  gap: 4,
                ),
                StatTile(
                  value: top == null ? '-' : kg(top),
                  label: tx('HEAVIEST'),
                  valueSize: 18,
                  valueWeight: 800,
                  labelFirst: true,
                  gap: 4,
                ),
                StatTile(
                  value: '${days.length}',
                  label: tx('WORKOUTS'),
                  valueSize: 18,
                  valueWeight: 800,
                  labelFirst: true,
                  gap: 4,
                ),
              ],
            ),
            if (trend.length >= 2) ...[
              const SizedBox(height: 18),
              Kicker(weighted ? tx('ESTIMATED 1RM PER WORKOUT') : tx('BEST REPS PER WORKOUT'), size: 9),
              const SizedBox(height: 8),
              Sparkline(values: trend, height: 70),
            ],
            const SizedBox(height: 22),
            SectionTitle(tx('History')),
            const SizedBox(height: 8),
            if (days.isEmpty) Text(tx('No logged sets yet.'), style: BoltText.a(13, color: BoltColors.muted)),
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

/// The one-rep max percentage loads use: set by hand, or the estimate.
class _MaxRow extends StatelessWidget {
  const _MaxRow({
    required this.name,
    required this.tid,
    required this.set,
    required this.estimate,
    required this.own,
    required this.metric,
  });

  final String name;
  final String tid;
  final double? set;
  final double? estimate;
  final bool own;
  final bool metric;

  @override
  Widget build(BuildContext context) {
    final max = set ?? estimate;
    return BoltBox(
      color: BoltColors.surface1,
      stroke: const Stroke(BoltColors.lineSoft),
      radius: 14,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Kicker(tx('MAX FOR % LOADS'), size: 9, spacing: .1),
                const SizedBox(height: 3),
                Text(
                  max == null
                      ? tx('Not known yet')
                      : '${fmtWeight(max, metric: metric)} · ${set == null ? tx('estimated') : tx('set by hand')}',
                  style: BoltText.a(14, weight: 800),
                ),
              ],
            ),
          ),
          if (own)
            Tap(
              onTap: () => showBoltSheet<void>(context, (_) => _MaxSheet(name: name, tid: tid, current: set)),
              child: Text(
                set == null ? tx('Set max') : tx('Edit'),
                style: BoltText.a(13, weight: 800, color: BoltColors.neon),
              ),
            ),
        ],
      ),
    );
  }
}

class _MaxSheet extends ConsumerStatefulWidget {
  const _MaxSheet({required this.name, required this.tid, required this.current});

  final String name;
  final String tid;
  final double? current;

  @override
  ConsumerState<_MaxSheet> createState() => _MaxSheetState();
}

class _MaxSheetState extends ConsumerState<_MaxSheet> {
  late final bool _metric = ref.read(boltProvider).settings.kg;
  late final _c = TextEditingController(text: weightValue(widget.current, metric: _metric));

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = ref.read(boltProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(tx('One-rep max'), style: BoltText.a(20, weight: 900)),
        const SizedBox(height: 4),
        Text(
          tx(
            'Loads written as a percentage, like 80%, turn into kilos from this. Leave it empty to use the estimate from your logged sets.',
          ),
          style: BoltText.a(13, color: BoltColors.muted, height: 1.45),
        ),
        const SizedBox(height: 14),
        BoltField(controller: _c, hint: tx(widget.name), number: true, suffix: weightUnit(_metric)),
        const SizedBox(height: 16),
        NeonButton(
          label: tx('Save'),
          height: 52,
          scale: 1,
          onTap: () {
            store.setMax(widget.tid, widget.name, parseWeight(_c.text, metric: _metric));
            Navigator.of(context).pop();
          },
        ),
      ],
    );
  }
}
