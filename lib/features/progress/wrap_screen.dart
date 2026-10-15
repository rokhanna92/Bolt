import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/units.dart';
import '../../data/bolt_store.dart';
import '../../data/lifts.dart';
import '../../data/models/session.dart';
import '../../data/models/visit.dart';
import '../../data/rules.dart';
import '../../data/seed/muscles.dart';
import '../../theme/text_styles.dart';
import '../../theme/tokens.dart';
import '../../widgets/common.dart';
import '../../widgets/forms.dart';
import '../workout/summary_screen.dart' show shareCard;

/// A month or year in Bolt as one card: workouts, gym time, sets, weight
/// lifted, records, the top lift and the most trained muscle. Shareable.
class WrapScreen extends ConsumerStatefulWidget {
  const WrapScreen({super.key});

  @override
  ConsumerState<WrapScreen> createState() => _WrapScreenState();
}

class _WrapScreenState extends ConsumerState<WrapScreen> {
  final _card = GlobalKey();
  String _period = 'month';

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(boltProvider);
    final store = ref.read(boltProvider.notifier);
    final t = store.trOrNull(d.account?.id ?? '');
    if (t == null) return const BoltPage(child: SizedBox.expand());
    final now = store.now;
    final (from, to, label) = switch (_period) {
      'last' => (
        DateTime(now.year, now.month - 1),
        DateTime(now.year, now.month),
        '${monthsLong[DateTime(now.year, now.month - 1).month - 1]} ${DateTime(now.year, now.month - 1).year}',
      ),
      'year' => (DateTime(now.year), DateTime(now.year + 1), '${now.year}'),
      _ => (
        DateTime(now.year, now.month),
        DateTime(now.year, now.month + 1),
        '${monthsLong[now.month - 1]} ${now.year}',
      ),
    };
    final a = dk(from), b = dk(to);
    bool inRange(String k) => k.compareTo(a) >= 0 && k.compareTo(b) < 0;
    final plan = store.plan(t.id);
    final done = [
      for (final e in plan.entries)
        if (e.value.status == SessionStatus.done && inRange(e.key)) e,
    ];
    final visits = (d.visits[t.id] ?? const <Visit>[]).where((v) => inRange(v.date)).toList();
    final mins = visits.fold(0, (x, v) => x + v.mins);
    var sets = 0, prs = 0;
    var volume = 0.0;
    (String, double)? top;
    for (final e in done) {
      prs += e.value.prs.length;
      for (final x in e.value.ex) {
        sets += x.logged.isNotEmpty ? x.logged.length : x.sets;
        for (final l in x.logged) {
          volume += (l.kg ?? 0) * (l.reps ?? 0);
          final m = e1rm(l);
          if (m != null && (top == null || m > top.$2)) top = (x.name, m);
        }
      }
    }
    final muscles = muscleSets(plan, a, b).entries.toList()..sort((x, y) => y.value - x.value);
    final metric = d.settings.kg;
    final insets = MediaQuery.paddingOf(context);
    Widget stat(String v, String l) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(v, style: BoltText.a(24, weight: 900, color: BoltColors.ink)),
          Text(l, style: BoltText.m(9, weight: 700, spacing: .1, color: BoltColors.ink.withValues(alpha: .7))),
        ],
      ),
    );
    Widget line(String k, String v) => Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(k, style: BoltText.m(10, weight: 700, spacing: .1, color: BoltColors.ink)),
          ),
          Text(v, style: BoltText.a(15, weight: 800, color: BoltColors.ink)),
        ],
      ),
    );

    return BoltPage(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, insets.top + 16, 20, 40 + insets.bottom),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                BackBox(onTap: () => context.pop()),
                const SizedBox(width: 12),
                Kicker(tx('YOUR WRAP')),
              ],
            ),
            const SizedBox(height: 14),
            ChoiceChips(
              options: const ['month', 'last', 'year'],
              labels: const {'month': 'This month', 'last': 'Last month', 'year': 'This year'},
              selected: _period,
              onSelect: (p) => setState(() => _period = p),
            ),
            const SizedBox(height: 16),
            RepaintBoundary(
              key: _card,
              child: Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(color: BoltColors.neon, borderRadius: BorderRadius.circular(26)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Text('BOLT', style: BoltText.a(18, weight: 900, width: 125, color: BoltColors.ink)),
                        const Spacer(),
                        Text(tx('WRAP'), style: BoltText.m(11, weight: 700, color: BoltColors.ink)),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Text(
                      label.toUpperCase(),
                      style: BoltText.a(tsz(label, 44), weight: 900, width: 115, height: .95, color: BoltColors.ink),
                    ),
                    const SizedBox(height: 4),
                    Text(t.name, style: BoltText.a(14, weight: 700, color: BoltColors.ink.withValues(alpha: .8))),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        stat('${done.length}', tx('WORKOUTS')),
                        stat(mins == 0 ? '-' : totalTime(mins), tx('GYM TIME')),
                        stat('$sets', tx('SETS')),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        stat('${visits.length}', tx('VISITS')),
                        stat(
                          volume == 0
                              ? '-'
                              : metric
                              ? '${(volume / 1000).toStringAsFixed(1)} t'
                              : '${(volume * 2.20462).round()} lb',
                          tx('LIFTED'),
                        ),
                        stat('$prs', tx('PRS')),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (top case final x?) line(tx('TOP LIFT'), '${tx(x.$1)} · ${fmtWeight(x.$2, metric: metric)}'),
                    if (muscles.firstOrNull case final m?)
                      line(tx('MOST TRAINED'), '${tx(kMuscles[m.key]?.name ?? m.key)} · ${plural(m.value, 'set')}'),
                    line(tx('BEST STREAK'), tx('{n} wk', {'n': t.stats.bestStreak})),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            NeonButton(
              label: tx('Share'),
              height: 52,
              scale: 1,
              onTap: () => shareCard(_card, 'bolt-wrap-$a.png', tx('My {when} in Bolt', {'when': label}), store),
            ),
          ],
        ),
      ),
    );
  }
}
