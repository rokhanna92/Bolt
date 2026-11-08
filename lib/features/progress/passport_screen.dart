import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/units.dart';
import '../../data/bolt_store.dart';
import '../../data/models/session.dart';
import '../../data/models/visit.dart';
import '../../data/period.dart';
import '../../theme/text_styles.dart';
import '../../theme/tokens.dart';
import '../../widgets/box.dart';
import '../../widgets/common.dart';
import '../../widgets/surfaces.dart';

/// Your training passport: one stamp per month since you started, newest
/// first. Private: it never leaves the phone.
class PassportScreen extends ConsumerWidget {
  const PassportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(boltProvider);
    final store = ref.read(boltProvider.notifier);
    final t = store.trOrNull(d.account?.id ?? '');
    if (t == null) return const BoltPage(child: SizedBox.expand());
    final plan = store.plan(t.id);
    final visits = d.visits[t.id] ?? const <Visit>[];
    final now = store.now;
    final metric = d.settings.kg;
    // From the first finished workout or gym visit; this month before any.
    final first = [
      dk(now),
      for (final e in plan.entries)
        if (e.value.status == SessionStatus.done) e.key,
      for (final v in visits) v.date,
    ].reduce((a, b) => a.compareTo(b) < 0 ? a : b);
    final start = DateTime(pk(first).year, pk(first).month);
    final months = [
      for (var m = DateTime(now.year, now.month); !m.isBefore(start); m = DateTime(m.year, m.month - 1)) m,
    ];
    final insets = MediaQuery.paddingOf(context);
    return BoltPage(
      child: ListView(
        padding: EdgeInsets.fromLTRB(20, insets.top + 16, 20, 60 + insets.bottom),
        children: [
          PageHead(
            onBack: () => context.pop(),
            kicker: tx('PASSPORT'),
            title: tx('Training passport'),
            sub: tx('A stamp for every month you train. It stays on this phone.'),
          ),
          const SizedBox(height: 18),
          for (final m in months) ...[
            _Stamp(
              month: m,
              p: periodStats(plan, visits, dk(m), dk(DateTime(m.year, m.month + 1))),
              current: m.year == now.year && m.month == now.month,
              metric: metric,
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

/// One month: a paper stamp when you trained, a quiet line when you did not.
class _Stamp extends StatelessWidget {
  const _Stamp({required this.month, required this.p, required this.current, required this.metric});

  final DateTime month;
  final PeriodStats p;
  final bool current;
  final bool metric;

  @override
  Widget build(BuildContext context) {
    final name = monthsLong[month.month - 1];
    if (p.workouts == 0) {
      return BoltBox(
        color: BoltColors.surface1,
        radius: 18,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Expanded(child: Text('$name ${month.year}', style: BoltText.a(14, weight: 800))),
            Text(
              current ? tx('Your first stamp lands when you finish a workout.') : tx('No workouts'),
              style: BoltText.a(12, color: BoltColors.muted),
            ),
          ],
        ),
      );
    }
    final lifted = metric ? '${(p.volume / 1000).toStringAsFixed(1)} t' : '${(p.volume * 2.20462).round()} lb';
    return Paper(
      watermark: '${month.month}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Kicker('${month.year}', size: 10)),
              if (current) Kicker(tx('IN PROGRESS'), size: 10, weight: 700, color: Tone.paper().accent),
            ],
          ),
          const SizedBox(height: 4),
          Text(name.toUpperCase(), style: BoltText.display(tsz(name, 40), color: BoltColors.paperInk)),
          const SizedBox(height: 14),
          FigureGrid(
            cells: [
              ('${p.workouts}', tx('WORKOUTS')),
              ('${p.sets}', tx('SETS')),
              (p.volume == 0 ? '-' : lifted, tx('LIFTED')),
            ],
          ),
          if (p.top != null || p.prs > 0) ...[
            const SizedBox(height: 12),
            Text(
              [
                if (p.prs > 0) tx('{n} PRs', {'n': p.prs}),
                if (p.top case final x?)
                  tx('Top lift: {lift}', {'lift': '${tx(x.$1)} ${fmtWeight(x.$2, metric: metric)}'}),
              ].join(' · '),
              style: BoltText.a(12, weight: 700, color: BoltColors.paperSoft),
            ),
          ],
        ],
      ),
    );
  }
}
