import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/actions.dart';
import '../../core/format.dart';
import '../../core/units.dart';
import '../../data/bolt_store.dart';
import '../../data/lifts.dart';
import '../../data/models/people.dart';
import '../../data/seed/learn.dart';
import '../../data/strength.dart';
import '../../theme/text_styles.dart';
import '../../theme/tokens.dart';
import '../../widgets/bolt_sheet.dart';
import '../../widgets/box.dart';
import '../../widgets/common.dart';
import '../../widgets/fields.dart';
import '../../widgets/forms.dart';
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
              LiftGoalCard(name: name, t: t, own: own),
              const SizedBox(height: 10),
              if (hasStandards(name))
                if (t.maxes[name] ?? best case final max?) ...[
                  _LevelCard(name: name, max: max, body: t.body, metric: metric),
                  const SizedBox(height: 10),
                ],
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

/// A target max by a date: progress, what is left and the pace.
class LiftGoalCard extends ConsumerWidget {
  const LiftGoalCard({super.key, required this.name, required this.t, required this.own, this.title = false});

  final String name;
  final Trainee t;

  /// The owner's lift: the goal can be set or changed.
  final bool own;

  /// Shows the lift's name, for the list on Progress.
  final bool title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(boltProvider);
    final store = ref.read(boltProvider.notifier);
    final metric = d.settings.kg;
    final g = t.liftGoals[name];
    final pace = goalPace(t, store.plan(t.id), name, store.now);
    void edit() => showBoltSheet<void>(context, (_) => _GoalSheet(name: name, tid: t.id));
    if (g == null) {
      if (!own) return const SizedBox.shrink();
      return OutlineButton(label: tx('+ Set a goal for this lift'), height: 44, radius: 14, fontSize: 13, onTap: edit);
    }
    final String line;
    if (pace == null) {
      line = tx('Log a set or set a max to track it.');
    } else if (pace.left <= 0) {
      line = tx('Goal reached!');
    } else {
      final head = tx('{kg} to go', {'kg': fmtWeight(pace.left, metric: metric)});
      line = pace.eta == null
          ? tx('{head} · no upward trend yet', {'head': head})
          : pace.eta!.compareTo(g.$2) <= 0
          ? tx('{head} · on pace for about {day}', {'head': head, 'day': fmtDay(pace.eta!)})
          : tx('{head} · behind pace, about {day} at this rate', {'head': head, 'day': fmtDay(pace.eta!)});
    }
    return BoltBox(
      color: BoltColors.surface1,
      stroke: const Stroke(BoltColors.lineSoft),
      radius: 14,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Kicker(
                  title ? tx(name).toUpperCase() : tx('GOAL'),
                  size: 9,
                  spacing: .1,
                  color: BoltColors.neon,
                ),
              ),
              if (own)
                Tap(
                  onTap: edit,
                  child: Text(tx('Edit'), style: BoltText.a(12, weight: 800, color: BoltColors.neon)),
                ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            tx('{kg} by {day}', {'kg': fmtWeight(g.$1, metric: metric), 'day': fmtDay(g.$2)}),
            style: BoltText.a(14, weight: 800),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: pace == null ? 0 : (pace.current / g.$1).clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: BoltColors.lineSoft,
              valueColor: const AlwaysStoppedAnimation(BoltColors.neon),
            ),
          ),
          const SizedBox(height: 6),
          Text(line, style: BoltText.a(12, color: BoltColors.muted, height: 1.4)),
        ],
      ),
    );
  }
}

class _GoalSheet extends ConsumerStatefulWidget {
  const _GoalSheet({required this.name, required this.tid});

  final String name;
  final String tid;

  @override
  ConsumerState<_GoalSheet> createState() => _GoalSheetState();
}

class _GoalSheetState extends ConsumerState<_GoalSheet> {
  late final bool _metric = ref.read(boltProvider).settings.kg;
  late final (double, String)? _old = ref.read(boltProvider.notifier).tr(widget.tid).liftGoals[widget.name];
  late final _c = TextEditingController(text: weightValue(_old?.$1, metric: _metric));
  String _weeks = '12';

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
        Text(tx('{what} goal', {'what': tx(widget.name)}), style: BoltText.a(20, weight: 900)),
        const SizedBox(height: 4),
        Text(
          tx('A one-rep max to reach. Progress comes from your max, set by hand or estimated from logged sets.'),
          style: BoltText.a(13, color: BoltColors.muted, height: 1.45),
        ),
        const SizedBox(height: 14),
        BoltField(controller: _c, hint: tx('Target max'), number: true, suffix: weightUnit(_metric)),
        FieldLabel(tx('IN')),
        ChoiceChips(
          options: const ['4', '8', '12', '16', '26'],
          labels: {
            for (final w in const ['4', '8', '12', '16', '26']) w: plural(int.parse(w), 'week'),
          },
          selected: _weeks,
          onSelect: (w) => setState(() => _weeks = w),
        ),
        const SizedBox(height: 16),
        NeonButton(
          label: tx('Save goal'),
          height: 52,
          scale: 1,
          onTap: () {
            final kg = parseWeight(_c.text, metric: _metric);
            if (kg != null) {
              store.setLiftGoal(widget.tid, widget.name, kg, dk(addDays(store.now, 7 * int.parse(_weeks))));
            }
            Navigator.of(context).pop();
          },
        ),
        if (_old != null) ...[
          const SizedBox(height: 8),
          OutlineButton(
            label: tx('Remove goal'),
            color: BoltColors.text,
            borderColor: BoltColors.line,
            weight: 700,
            onTap: () {
              store.setLiftGoal(widget.tid, widget.name, null, '');
              Navigator.of(context).pop();
            },
          ),
        ],
      ],
    );
  }
}

/// Where the max sits against strength standards for the lifter's sex and
/// bodyweight.
class _LevelCard extends StatelessWidget {
  const _LevelCard({required this.name, required this.max, required this.body, required this.metric});

  final String name;
  final double max;
  final Body body;
  final bool metric;

  @override
  Widget build(BuildContext context) {
    final l = strengthLevel(name, max, body);
    return BoltBox(
      color: BoltColors.surface1,
      stroke: const Stroke(BoltColors.lineSoft),
      radius: 14,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Kicker(tx('STRENGTH LEVEL'), size: 9, spacing: .1),
          const SizedBox(height: 3),
          if (l == null)
            Text(
              tx('Add bodyweight and male or female in the profile to see the strength level.'),
              style: BoltText.a(13, color: BoltColors.muted, height: 1.4),
            )
          else ...[
            Text(
              tx('{level} · {x}× bodyweight', {'level': tx(kStrengthLevels[l.level]), 'x': l.ratio.toStringAsFixed(2)}),
              style: BoltText.a(14, weight: 800),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                for (var i = 0; i < kStrengthLevels.length; i++) ...[
                  if (i > 0) const SizedBox(width: 3),
                  Expanded(
                    child: Container(
                      height: 6,
                      decoration: BoxDecoration(
                        color: i <= l.level ? BoltColors.neon : BoltColors.lineSoft,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${l.nextKg == null ? tx('Top level.') : tx('Next: {level} at {kg}.', {'level': tx(kStrengthLevels[l.level + 1]), 'kg': fmtWeight(plates(l.nextKg!), metric: metric)})} '
              '${tx(body.sex == 'f' ? 'Standards for women.' : 'Standards for men.')}',
              style: BoltText.a(12, color: BoltColors.muted, height: 1.4),
            ),
          ],
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
