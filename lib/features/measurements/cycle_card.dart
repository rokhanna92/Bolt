import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../data/bolt_store.dart';
import '../../data/cycle.dart';
import '../../theme/text_styles.dart';
import '../../theme/tokens.dart';
import '../../widgets/bolt_sheet.dart';
import '../../widgets/box.dart';
import '../../widgets/common.dart';
import '../../widgets/tap.dart';

/// Where the owner is in her cycle and what it usually means for training.
/// [full] adds logging and the last starts (Measurements); on Today the card
/// opens Measurements.
class CycleCard extends ConsumerWidget {
  const CycleCard({super.key, this.full = false});

  final bool full;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(boltProvider);
    final store = ref.read(boltProvider.notifier);
    final t = store.trOrNull(d.account?.id ?? '');
    if (t == null) return const SizedBox.shrink();
    final info = cycleInfo(t.periods, store.now);
    final card = BoltBox(
      color: BoltColors.surface1,
      stroke: const Stroke(BoltColors.lineSoft),
      radius: 18,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Kicker(
            info == null ? tx('CYCLE') : tx('CYCLE · DAY {n}', {'n': info.day}),
            size: 9,
            spacing: .1,
            color: BoltColors.neon,
          ),
          const SizedBox(height: 4),
          if (info == null)
            Text(
              tx('Log when your period starts. Bolt shows your phase and what it usually means for training.'),
              style: BoltText.a(13, color: BoltColors.muted, height: 1.4),
            )
          else ...[
            Text(tx(kCyclePhases[info.phase]!), style: BoltText.a(16, weight: 800)),
            const SizedBox(height: 4),
            Text(
              [
                if (info.phase == 'pre')
                  info.dueIn > 0
                      ? tx('Period due in about {n}.', {'n': plural(info.dueIn, 'day')})
                      : tx('Period due about now.'),
                tx(kCycleTips[info.phase]!),
              ].join(' '),
              style: BoltText.a(13, color: BoltColors.muted, height: 1.4),
            ),
          ],
          if (full) ...[
            const SizedBox(height: 12),
            NeonButton(
              label: tx('Period started…'),
              height: 46,
              scale: 1,
              onTap: () => showBoltSheet<void>(context, (_) => const _PeriodSheet()),
            ),
            const SizedBox(height: 8),
            Text(tx('Stays on this phone. Never sent to your coach.'), style: BoltText.m(10, color: BoltColors.muted)),
            for (final k in t.periods.reversed.take(4))
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.only(top: 6),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: BoltColors.divider)),
                ),
                child: Row(
                  children: [
                    Expanded(child: Text(tx('Started {day}', {'day': fmtDay(k)}), style: BoltText.a(13, weight: 600))),
                    Tap(
                      onTap: () => store.removePeriod(k),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text('✕', style: BoltText.a(14, color: BoltColors.muted2)),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
    return full ? card : Tap(onTap: () => context.push('/measurements'), child: card);
  }
}

/// Pick the day a period started: today or up to 45 days back.
class _PeriodSheet extends ConsumerStatefulWidget {
  const _PeriodSheet();

  @override
  ConsumerState<_PeriodSheet> createState() => _PeriodSheetState();
}

class _PeriodSheetState extends ConsumerState<_PeriodSheet> {
  int _ago = 0;

  @override
  Widget build(BuildContext context) {
    final store = ref.read(boltProvider.notifier);
    final day = addDays(store.now, -_ago);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(tx('Period started'), style: BoltText.a(20, weight: 900)),
        const SizedBox(height: 4),
        Text(
          tx('Pick the first day. Log a few months and the phase estimate gets better.'),
          style: BoltText.a(13, color: BoltColors.muted, height: 1.45),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            SquareButton(onTap: () => setState(() => _ago = (_ago + 1).clamp(0, 45)), label: '‹'),
            Expanded(
              child: Text(
                _ago == 0 ? tx('Today') : (_ago == 1 ? tx('Yesterday') : fmtDay(dk(day))),
                textAlign: TextAlign.center,
                style: BoltText.a(18, weight: 800),
              ),
            ),
            SquareButton(onTap: () => setState(() => _ago = (_ago - 1).clamp(0, 45)), label: '›'),
          ],
        ),
        const SizedBox(height: 16),
        NeonButton(
          label: tx('Save'),
          height: 52,
          scale: 1,
          onTap: () {
            store.logPeriod(dk(day));
            Navigator.of(context).pop();
          },
        ),
      ],
    );
  }
}
