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

/// Weight and tape measurements over time: a trend per measurement and every
/// entry. For the owner, or a coach looking at a trainee ([tid]).
class MeasurementsScreen extends ConsumerWidget {
  const MeasurementsScreen({super.key, this.tid});

  final String? tid;

  Future<void> _delete(BuildContext context, BoltStore store, String date) async {
    final ok = await confirmSheet(
      context,
      title: 'Remove ${fmtDay(date)}?',
      body: 'This day\'s weight and measurements are deleted.',
      confirm: 'Remove',
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
                  child: Kicker(who == null ? 'MEASUREMENTS' : 'MEASUREMENTS · ${firstName(who).toUpperCase()}'),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text('Body progress', style: BoltText.a(30, weight: 900, width: 112, spacing: -.02)),
            const SizedBox(height: 6),
            Text(
              'Weigh in at the same time of day, before eating, for the cleanest trend. Tape measurements every 2-4 weeks are enough.',
              style: BoltText.a(13, color: BoltColors.muted, height: 1.45),
            ),
            const SizedBox(height: 14),
            NeonButton(
              label: '+ Log today',
              height: 50,
              scale: 1,
              onTap: () => showBoltSheet<void>(context, (_) => LogBodySheet(tid: tid)),
            ),
            for (final e in Body.tracked.entries)
              if (series[e.key]!.isNotEmpty) ...[
                const SizedBox(height: 10),
                _MetricCard(label: e.value, keyName: e.key, series: series[e.key]!, now: store.now, metric: metric),
              ],
            if (b == null || b.history.isEmpty) ...[
              const SizedBox(height: 14),
              BoltBox(
                radius: 14,
                stroke: const Stroke.dashed(BoltColors.line),
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Nothing logged yet. Log your weight today and every few days after, and your trend shows up here.',
                  style: BoltText.a(13, color: BoltColors.muted, height: 1.45),
                ),
              ),
            ],
            if (b != null && b.history.isNotEmpty) ...[
              const SizedBox(height: 24),
              const SectionTitle('History'),
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
                                    '${t.value} ${bodyValue(t.key, v, metric: metric)}',
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

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.keyName,
    required this.series,
    required this.now,
    required this.metric,
  });

  final String label;
  final String keyName;
  final List<(String, double)> series;
  final DateTime now;
  final bool metric;

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
                    Kicker(label.toUpperCase(), size: 9, spacing: .1),
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
                    Text('since ${fmtDay(ch.since)}', style: BoltText.m(9, color: BoltColors.muted)),
                  ],
                ),
            ],
          ),
          if (series.length >= 2) ...[
            const SizedBox(height: 10),
            Sparkline(values: [for (final x in series) x.$2]),
          ],
          const SizedBox(height: 8),
          Text(
            series.length < 2
                ? 'Log it again on another day to see a trend.'
                : '${series.length} entries since ${fmtDay(first.$1)}'
                      ' · ${bodyDelta(keyName, total, metric: metric)} in total',
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
      return last == null ? label : '$label (last ${bodyValue(k, last, metric: metric)})';
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
        Text('Log today', style: BoltText.a(20, weight: 900)),
        const SizedBox(height: 4),
        Text(
          'Fill in what you measured. Empty fields are skipped.',
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
        NeonButton(label: 'Save', height: 52, scale: 1, onTap: () => _save(metric)),
      ],
    );
  }
}
