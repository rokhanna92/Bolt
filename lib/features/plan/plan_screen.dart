import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/actions.dart';
import '../../app/ui_state.dart';
import '../../core/format.dart';
import '../../data/bolt_store.dart';
import '../../data/models/session.dart';
import '../../theme/text_styles.dart';
import '../../theme/tokens.dart';
import '../../widgets/box.dart';
import '../../widgets/calendar_grid.dart';
import '../../widgets/common.dart';
import '../../widgets/motion.dart';
import '../../widgets/tap.dart';

class PlanScreen extends ConsumerWidget {
  const PlanScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(boltProvider);
    final store = ref.read(boltProvider.notifier);
    final month = ref.watch(planMonthProvider);
    final moveFrom = ref.watch(moveFromProvider);
    final t = store.trOrNull(d.account?.id ?? '');
    if (t == null) return const SizedBox.shrink();
    final plan = store.plan(t.id);
    final today = store.today;
    final moving = moveFrom == null ? null : plan[moveFrom];
    final up = plan.keys.where((k) => k.compareTo(today) >= 0 && plan[k]!.status != SessionStatus.draft).toList()
      ..sort();
    final cells = buildCalendar(
      month: month,
      plan: plan,
      tpls: d.tpls,
      today: today,
      coach: false,
      mondayFirst: d.settings.mondayFirst,
      moveFrom: moving == null ? null : moveFrom,
    );

    void onTap(CalCell c) {
      if (moving != null) {
        if (c.k == moveFrom) {
          ref.read(moveFromProvider.notifier).set(null);
          return;
        }
        if (c.session == null && c.k.compareTo(today) >= 0) {
          store.move(moveFrom!, c.k);
          ref.read(moveFromProvider.notifier).set(null);
        }
        return;
      }
      if (c.session != null) showDaySheet(c.k);
    }

    return ScreenScroll(
      children: [
        const Kicker('PLAN'),
        const SizedBox(height: 4),
        Row(
          children: [
            Text(
              monthsLong[month.month - 1],
              style: BoltText.a(30, weight: 900, width: 112, spacing: -.02, height: 1.2),
            ),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('${month.year}', style: BoltText.m(13, color: BoltColors.muted)),
            ),
            const Spacer(),
            SquareButton(onTap: () => ref.read(planMonthProvider.notifier).shift(-1), label: '‹'),
            const SizedBox(width: 6),
            SquareButton(onTap: () => ref.read(planMonthProvider.notifier).shift(1), label: '›'),
          ],
        ),
        if (moving != null) ...[
          const SizedBox(height: 14),
          FadeSlideIn(
            duration: const Duration(milliseconds: 250),
            child: BoltBox(
              color: BoltColors.neon,
              radius: 14,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Moving ${moving.title} · ${fmtDay(moveFrom!)}',
                          style: BoltText.a(13, weight: 800, color: BoltColors.ink),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Tap a free day to move it',
                          style: BoltText.a(12, weight: 600, color: BoltColors.ink.withValues(alpha: .75)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Tap(
                    onTap: () => ref.read(moveFromProvider.notifier).set(null),
                    child: BoltBox(
                      radius: 10,
                      stroke: const Stroke(BoltColors.ink, 1.5),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Text('Cancel', style: BoltText.a(12, weight: 800, color: BoltColors.ink)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 16),
        WeekdayHeader(mondayFirst: d.settings.mondayFirst),
        const SizedBox(height: 6),
        CalendarGrid(cells: cells, onTap: onTap),
        const SizedBox(height: 14),
        const Legend(items: traineeLegend),
        const SizedBox(height: 26),
        const SectionTitle('Coming up'),
        const SizedBox(height: 10),
        for (final k in up.take(5)) ...[_UpRow(dayKey: k, session: plan[k]!), const SizedBox(height: 8)],
        if (up.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Text(
              'Nothing planned yet. Your coach will add sessions here.',
              style: BoltText.a(14, color: BoltColors.muted),
            ),
          ),
      ],
    );
  }
}

class _UpRow extends StatelessWidget {
  const _UpRow({required this.dayKey, required this.session});

  final String dayKey;
  final Session session;

  @override
  Widget build(BuildContext context) {
    return Tap(
      onTap: () => showDaySheet(dayKey),
      scale: .98,
      child: BoltBox(
        color: BoltColors.surface1,
        stroke: const Stroke(BoltColors.lineSoft),
        radius: 16,
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Kicker(fmtDay(dayKey).toUpperCase(), size: 10, spacing: .1),
                  const SizedBox(height: 3),
                  Text(session.title, style: BoltText.a(17, weight: 800)),
                  const SizedBox(height: 3),
                  Text(session.focus, style: BoltText.a(12, color: BoltColors.muted)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            StatusPill(status: session.status, label: traineeLabel(session.status)),
          ],
        ),
      ),
    );
  }
}
