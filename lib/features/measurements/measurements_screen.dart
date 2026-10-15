import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/share.dart';
import '../../core/format.dart';
import '../../core/units.dart';
import '../../data/bolt_store.dart';
import '../../data/models/people.dart';
import '../../theme/text_styles.dart';
import '../../theme/tokens.dart';
import '../../widgets/bolt_sheet.dart';
import '../../widgets/box.dart';
import '../../widgets/common.dart';
import '../../widgets/fields.dart';
import '../../widgets/sparkline.dart';
import '../../widgets/tap.dart';
import 'cycle_card.dart';

/// Values of [key] (`weight` or a part) over time, oldest first.
List<(String, double)> bodySeries(Body b, String key) => [
  for (final e in b.history)
    if (e.value(key) case final double v) (e.date, v),
];

/// Change over the last [days]: the latest value minus the newest one at
/// least that old, or the first one when the history is shorter. Null with
/// fewer than two values.
({double delta, String since})? bodyChange(List<(String, double)> s, DateTime now, {int days = 30}) {
  if (s.length < 2) return null;
  final cut = dk(addDays(now, -days));
  final base = s.lastWhere((x) => x.$1.compareTo(cut) <= 0, orElse: () => s.first);
  if (base.$1 == s.last.$1) return null;
  return (delta: s.last.$2 - base.$2, since: base.$1);
}

/// A value in the display unit: weight in kg or lb, parts in cm or in.
String bodyValue(String key, double v, {required bool metric}) =>
    key == 'weight' ? fmtWeight(v, metric: metric) : fmtLength(v, metric: metric);

/// "+0.4 kg" or "-1.6 kg".
String bodyDelta(String key, double d, {required bool metric}) =>
    '${d < 0 ? '-' : '+'}${bodyValue(key, d.abs(), metric: metric)}';

/// What to keep in mind when measuring, for `m` or `f`.
String sexTip(String? sex) => switch (sex) {
  'f' => tx(
    'Water can move your weight 1-2 kg over a monthly cycle. Compare the same week of your cycle and trust the monthly trend. Women tend to store more on hips and thighs, so tape those too.',
  ),
  'm' => tx(
    'Men tend to store fat around the belly first, so the waist tells you the most about fat loss. A shrinking waist with steady weight means muscle is replacing fat.',
  ),
  _ => tx('Set male or female in the profile to get tips and healthy ranges that fit your body.'),
};

/// Waist divided by hips with the WHO line for `m` (0.90) or `f` (0.85).
/// Null without a sex or either measurement.
({double ratio, double limit})? waistToHip(Body b) {
  final w = b.cm['waist'], h = b.cm['hips'];
  if (b.sex == null || w == null || h == null || h == 0) return null;
  return (ratio: w / h, limit: b.sex == 'f' ? .85 : .90);
}

/// Body fat % by the US Navy tape method from height, waist, neck and, for
/// women, hips (all cm). Null when something is missing or out of range.
double? navyBodyFat(String? sex, double? height, double? waist, double? neck, double? hips) {
  if (sex == null || height == null || waist == null || neck == null) return null;
  double log10(double x) => math.log(x) / math.ln10;
  final double v;
  if (sex == 'f') {
    if (hips == null || waist + hips - neck <= 0) return null;
    v = 495 / (1.29579 - .35004 * log10(waist + hips - neck) + .221 * log10(height)) - 450;
  } else {
    if (waist - neck <= 0) return null;
    v = 495 / (1.0324 - .19077 * log10(waist - neck) + .15456 * log10(height)) - 450;
  }
  return v < 2 || v > 60 ? null : v;
}

/// Estimated body fat on each day the tape changed, using the latest
/// earlier value for parts not measured that day.
List<(String, double)> bodyFatSeries(Body b) {
  final last = <String, double>{};
  return [
    for (final e in b.history)
      if ((e.cm.keys.toSet()..retainAll(const {'waist', 'neck', 'hips'})).isNotEmpty)
        if (navyBodyFat(b.sex, b.heightCm, (last..addAll(e.cm))['waist'], last['neck'], last['hips'])
            case final double v)
          (e.date, v),
  ];
}

/// Weight and tape measurements over time: a trend per measurement and every
/// entry. For the owner, or a coach looking at a trainee ([tid]).
class MeasurementsScreen extends ConsumerWidget {
  const MeasurementsScreen({super.key, this.tid});

  final String? tid;

  Future<void> _delete(BuildContext context, BoltStore store, String date) async {
    final ok = await confirmSheet(
      context,
      title: tx('Remove {day}?', {'day': fmtDay(date)}),
      body: tx('This day\'s weight and measurements are deleted.'),
      confirm: tx('Remove'),
    );
    if (ok) store.deleteBodyEntry(tid, date);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(boltProvider);
    final store = ref.read(boltProvider.notifier);
    final b = store.bodyFor(tid);
    final metric = d.settings.kg;
    final insets = MediaQuery.paddingOf(context);
    final who = tid == null ? null : store.trOrNull(tid!)?.name;
    final series = {for (final k in Body.tracked.keys) k: b == null ? <(String, double)>[] : bodySeries(b, k)};

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
                Expanded(
                  child: Kicker(
                    who == null ? tx('MEASUREMENTS') : '${tx('MEASUREMENTS')} · ${firstName(who).toUpperCase()}',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(tx('Body progress'), style: BoltText.a(30, weight: 900, width: 112, spacing: -.02)),
            const SizedBox(height: 6),
            Text(
              tx(
                tx(
                  'Weigh in at the same time of day, before eating, for the cleanest trend. Tape measurements every 2-4 weeks are enough.',
                ),
              ),
              style: BoltText.a(13, color: BoltColors.muted, height: 1.45),
            ),
            const SizedBox(height: 8),
            Text(sexTip(b?.sex), style: BoltText.a(13, color: BoltColors.muted, height: 1.45)),
            if (b != null && b.sex == null) ...[
              const SizedBox(height: 6),
              Tap(
                onTap: () => context.push(tid == null ? '/edit-profile' : '/edit-profile/$tid'),
                child: Text(tx('Set male or female →'), style: BoltText.a(13, weight: 800, color: BoltColors.neon)),
              ),
            ],
            const SizedBox(height: 14),
            NeonButton(
              label: tx('+ Log today'),
              height: 50,
              scale: 1,
              onTap: () => showBoltSheet<void>(context, (_) => LogBodySheet(tid: tid)),
            ),
            for (final e in Body.tracked.entries)
              if (series[e.key]!.isNotEmpty) ...[
                const SizedBox(height: 10),
                _MetricCard(
                  label: e.value,
                  keyName: e.key,
                  series: series[e.key]!,
                  now: store.now,
                  metric: metric,
                  goal: b?.goals[e.key],
                  onGoal: () => showBoltSheet<void>(context, (_) => _GoalSheet(tid: tid, keyName: e.key)),
                ),
              ],
            if (b != null && b.sex != null && b.cm['waist'] != null) ...[
              const SizedBox(height: 10),
              _BodyFatCard(body: b),
            ],
            if (b != null)
              if (waistToHip(b) case final r?) ...[
                const SizedBox(height: 10),
                BoltBox(
                  color: BoltColors.surface1,
                  stroke: const Stroke(BoltColors.lineSoft),
                  radius: 18,
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Kicker(tx('WAIST-TO-HIP'), size: 9, spacing: .1),
                      const SizedBox(height: 3),
                      Text(
                        r.ratio.toStringAsFixed(2),
                        style: BoltText.a(
                          22,
                          weight: 900,
                          color: r.ratio < r.limit ? BoltColors.neon : BoltColors.text,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        tx(
                          b.sex == 'f'
                              ? 'Under {limit} is the healthy range for women. Above it, belly fat raises heart and diabetes risk.'
                              : 'Under {limit} is the healthy range for men. Above it, belly fat raises heart and diabetes risk.',
                          {'limit': r.limit.toStringAsFixed(2)},
                        ),
                        style: BoltText.a(12, color: BoltColors.muted, height: 1.4),
                      ),
                    ],
                  ),
                ),
              ],
            if (tid == null && (d.account?.isTrainee ?? false) && b?.sex == 'f') ...[
              const SizedBox(height: 10),
              const CycleCard(full: true),
            ],
            if (b == null || b.history.isEmpty) ...[
              const SizedBox(height: 14),
              BoltBox(
                radius: 14,
                stroke: const Stroke.dashed(BoltColors.line),
                padding: const EdgeInsets.all(16),
                child: Text(
                  tx(
                    tx(
                      'Nothing logged yet. Log your weight today and every few days after, and your trend shows up here.',
                    ),
                  ),
                  style: BoltText.a(13, color: BoltColors.muted, height: 1.45),
                ),
              ),
            ],
            if (b != null && b.history.isNotEmpty) ...[
              const SizedBox(height: 24),
              SectionTitle(tx('History')),
              const SizedBox(height: 8),
              for (final e in b.history.reversed)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: BoltColors.divider)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Kicker(fmtDay(e.date).toUpperCase(), size: 10, spacing: .08),
                            const SizedBox(height: 3),
                            Text(
                              [
                                for (final t in Body.tracked.entries)
                                  if (e.value(t.key) case final double v)
                                    '${tx(t.value)} ${bodyValue(t.key, v, metric: metric)}',
                              ].join(' · '),
                              style: BoltText.a(13, weight: 600, height: 1.4),
                            ),
                          ],
                        ),
                      ),
                      Tap(
                        onTap: () => _delete(context, store, e.date),
                        child: SizedBox(
                          width: 36,
                          height: 36,
                          child: Center(
                            child: Text('✕', style: BoltText.a(14, color: BoltColors.muted2)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Body fat from the tape, with its trend and the healthy range for the sex.
class _BodyFatCard extends StatelessWidget {
  const _BodyFatCard({required this.body});

  final Body body;

  @override
  Widget build(BuildContext context) {
    final s = bodyFatSeries(body);
    final f = body.sex == 'f';
    final missing = body.heightCm == null
        ? tx('Add your height in the profile to estimate body fat.')
        : (f ? tx('Log your neck and hips to estimate body fat.') : tx('Log your neck to estimate body fat.'));
    return BoltBox(
      color: BoltColors.surface1,
      stroke: const Stroke(BoltColors.lineSoft),
      radius: 18,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Kicker(tx('BODY FAT · ESTIMATE'), size: 9, spacing: .1),
          const SizedBox(height: 3),
          if (s.isEmpty)
            Text(missing, style: BoltText.a(13, color: BoltColors.muted, height: 1.4))
          else ...[
            Text('${s.last.$2.toStringAsFixed(1)}%', style: BoltText.a(22, weight: 900)),
            if (s.length >= 2) ...[
              const SizedBox(height: 10),
              Sparkline(values: [for (final x in s) x.$2]),
            ],
            const SizedBox(height: 6),
            Text(
              tx(
                f
                    ? 'US Navy tape method, about ±3%. Healthy for women is about 20-30%.'
                    : 'US Navy tape method, about ±3%. Healthy for men is about 10-20%.',
              ),
              style: BoltText.a(12, color: BoltColors.muted, height: 1.4),
            ),
          ],
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.keyName,
    required this.series,
    required this.now,
    required this.metric,
    required this.goal,
    required this.onGoal,
  });

  final String label;
  final String keyName;
  final List<(String, double)> series;
  final DateTime now;
  final bool metric;
  final double? goal;
  final VoidCallback onGoal;

  /// "4.4 kg to go · about 6 weeks at this pace", from the 30-day change.
  String _goalText(({double delta, String since})? ch) {
    final g = goal!;
    final left = g - series.last.$2;
    if (left.abs() < .05) return tx('Goal reached!');
    final head = tx('{amount} to go', {'amount': bodyValue(keyName, left.abs(), metric: metric)});
    if (ch == null || ch.delta == 0 || ch.delta.sign != left.sign) return head;
    final perDay = ch.delta / pk(series.last.$1).difference(pk(ch.since)).inDays;
    final weeks = (left / perDay / 7).ceil();
    return tx('{head} · about {n} at this pace', {'head': head, 'n': plural(weeks, 'week')});
  }

  @override
  Widget build(BuildContext context) {
    final ch = bodyChange(series, now);
    final first = series.first;
    final total = series.last.$2 - first.$2;
    return BoltBox(
      color: BoltColors.surface1,
      stroke: const Stroke(BoltColors.lineSoft),
      radius: 18,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Kicker(tx(label).toUpperCase(), size: 9, spacing: .1),
                    const SizedBox(height: 3),
                    Text(bodyValue(keyName, series.last.$2, metric: metric), style: BoltText.a(22, weight: 900)),
                  ],
                ),
              ),
              if (ch != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      bodyDelta(keyName, ch.delta, metric: metric),
                      style: BoltText.a(14, weight: 800, color: BoltColors.neon),
                    ),
                    Text(tx('since {day}', {'day': fmtDay(ch.since)}), style: BoltText.m(9, color: BoltColors.muted)),
                  ],
                ),
            ],
          ),
          if (series.length >= 2) ...[
            const SizedBox(height: 10),
            Sparkline(values: [for (final x in series) x.$2], goal: goal),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  goal == null
                      ? tx('No goal set')
                      : tx('Goal {value} · {rest}', {
                          'value': bodyValue(keyName, goal!, metric: metric),
                          'rest': _goalText(ch),
                        }),
                  style: BoltText.a(12, weight: 700, color: goal == null ? BoltColors.muted3 : BoltColors.text),
                ),
              ),
              Tap(
                onTap: onGoal,
                child: Text(
                  goal == null ? tx('Set goal') : tx('Edit'),
                  style: BoltText.a(12, weight: 800, color: BoltColors.neon),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            series.length < 2
                ? tx('Log it again on another day to see a trend.')
                : tx('{n} entries since {day} · {delta} in total', {
                    'n': series.length,
                    'day': fmtDay(first.$1),
                    'delta': bodyDelta(keyName, total, metric: metric),
                  }),
            style: BoltText.a(12, color: BoltColors.muted),
          ),
        ],
      ),
    );
  }
}

/// Log today's weight and any tape measurements. Empty fields are skipped;
/// hints show the last value.
class LogBodySheet extends ConsumerStatefulWidget {
  const LogBodySheet({super.key, this.tid});

  final String? tid;

  @override
  ConsumerState<LogBodySheet> createState() => _LogBodySheetState();
}

class _LogBodySheetState extends ConsumerState<LogBodySheet> {
  final _c = {for (final k in Body.tracked.keys) k: TextEditingController()};

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _save(bool metric) {
    final w = parseWeight(_c['weight']!.text, metric: metric);
    final cm = <String, double>{
      for (final k in Body.parts.keys)
        if (parseLength(_c[k]!.text, metric: metric) case final double v) k: v,
    };
    ref.read(boltProvider.notifier).logBody(widget.tid, w, cm);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final metric = ref.watch(boltProvider.select((d) => d.settings.kg));
    final b = ref.read(boltProvider.notifier).bodyFor(widget.tid);
    String hint(String k, String label) {
      final last = k == 'weight' ? b?.weightKg : b?.cm[k];
      return last == null
          ? tx(label)
          : tx('{label} (last {value})', {'label': tx(label), 'value': bodyValue(k, last, metric: metric)});
    }

    Widget field(String k) => BoltField(
      controller: _c[k]!,
      hint: hint(k, Body.tracked[k]!),
      number: true,
      suffix: k == 'weight' ? weightUnit(metric) : lengthUnit(metric),
    );
    final parts = Body.parts.keys.toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(tx('Log today'), style: BoltText.a(20, weight: 900)),
        const SizedBox(height: 4),
        Text(
          tx('Fill in what you measured. Empty fields are skipped.'),
          style: BoltText.a(13, color: BoltColors.muted, height: 1.45),
        ),
        const SizedBox(height: 14),
        field('weight'),
        const SizedBox(height: 8),
        for (var i = 0; i < parts.length; i += 2) ...[
          if (i > 0) const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: field(parts[i])),
              const SizedBox(width: 8),
              Expanded(child: i + 1 < parts.length ? field(parts[i + 1]) : const SizedBox()),
            ],
          ),
        ],
        const SizedBox(height: 16),
        NeonButton(label: tx('Save'), height: 52, scale: 1, onTap: () => _save(metric)),
      ],
    );
  }
}

/// Set or clear a target for one measurement.
class _GoalSheet extends ConsumerStatefulWidget {
  const _GoalSheet({required this.tid, required this.keyName});

  final String? tid;
  final String keyName;

  @override
  ConsumerState<_GoalSheet> createState() => _GoalSheetState();
}

class _GoalSheetState extends ConsumerState<_GoalSheet> {
  late final bool _metric = ref.read(boltProvider).settings.kg;
  late final double? _old = ref.read(boltProvider.notifier).bodyFor(widget.tid)?.goals[widget.keyName];
  late final _c = TextEditingController(
    text: _old == null
        ? ''
        : (widget.keyName == 'weight' ? weightValue(_old, metric: _metric) : lengthValue(_old, metric: _metric)),
  );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = ref.read(boltProvider.notifier);
    final weight = widget.keyName == 'weight';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(tx('{what} goal', {'what': tx(Body.tracked[widget.keyName]!)}), style: BoltText.a(20, weight: 900)),
        const SizedBox(height: 4),
        Text(
          tx('Shows as a dashed line on the trend, with how far there is to go.'),
          style: BoltText.a(13, color: BoltColors.muted, height: 1.45),
        ),
        const SizedBox(height: 14),
        BoltField(
          controller: _c,
          hint: tx('Target'),
          number: true,
          suffix: weight ? weightUnit(_metric) : lengthUnit(_metric),
        ),
        const SizedBox(height: 16),
        NeonButton(
          label: tx('Save goal'),
          height: 52,
          scale: 1,
          onTap: () {
            final v = weight ? parseWeight(_c.text, metric: _metric) : parseLength(_c.text, metric: _metric);
            store.setBodyGoal(widget.tid, widget.keyName, v);
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
              store.setBodyGoal(widget.tid, widget.keyName, null);
              Navigator.of(context).pop();
            },
          ),
        ],
      ],
    );
  }
}
