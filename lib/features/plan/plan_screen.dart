import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/actions.dart';
import '../../app/ui_state.dart';
import '../../core/format.dart';
import '../../data/bolt_store.dart';
import '../../data/models/session.dart';
import '../../data/seed/splits.dart';
import '../../theme/text_styles.dart';
import '../../theme/tokens.dart';
import '../../widgets/box.dart';
import '../../widgets/calendar_grid.dart';
import '../../widgets/common.dart';
import '../../widgets/motion.dart';
import '../../widgets/bolt_sheet.dart';
import '../../widgets/tap.dart';
import '../workouts/deload_sheet.dart';
import '../workouts/program_sheet.dart';
import 'away_sheet.dart';
import 'free_day_sheet.dart';

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
    // Done days are behind you, today's included.
    final up =
        plan.keys
            .where(
              (k) =>
                  k.compareTo(today) >= 0 &&
                  plan[k]!.status != SessionStatus.draft &&
                  plan[k]!.status != SessionStatus.done,
            )
            .toList()
          ..sort();
    final cells = buildCalendar(
      month: month,
      plan: plan,
      tpls: d.tpls,
      today: today,
      coach: false,
      mondayFirst: d.settings.mondayFirst,
      moveFrom: moving == null ? null : moveFrom,
      rest: t.stats.rest,
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
      if (c.session != null) {
        showDaySheet(c.k);
      } else if (t.stats.rest.contains(c.k) ||
          (c.k.compareTo(today) <= 0 &&
              (t.readiness.containsKey(c.k) || (d.visits[t.id] ?? const []).any((v) => v.date == c.k)))) {
        showBoltSheet<void>(
          context,
          (_) => FreeDaySheet(
            dayKey: c.k,
            onPlan: () {
              if (store.addFromRotation(t.id, c.k)) showDaySheet(c.k);
            },
          ),
        );
      } else if (store.addFromRotation(t.id, c.k)) {
        showDaySheet(c.k);
      }
    }

    // A free day is marked as rest with a long press.
    void onLongPress(CalCell c) {
      if (moving == null && c.session == null) store.toggleRest(c.k);
    }

    return ScreenScroll(
      children: [
        Kicker(tx('PLAN')),
        const SizedBox(height: 4),
        Row(
          children: [
            Text(monthsLong[month.month - 1], style: BoltText.a(30, weight: 900, width: 112, spacing: -.02)),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('${month.year}', style: BoltText.m(13, color: BoltColors.muted)),
            ),
            const Spacer(),
            SquareButton(onTap: () => ref.read(planMonthProvider.notifier).shift(-1), icon: 'back'),
            const SizedBox(width: 6),
            SquareButton(onTap: () => ref.read(planMonthProvider.notifier).shift(1), icon: 'chevron'),
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
                          tx('Moving {workout} · {day}', {'workout': tx(moving.title), 'day': fmtDay(moveFrom!)}),
                          style: BoltText.a(13, weight: 800, color: BoltColors.ink),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          tx('Tap a free day to move it'),
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
                      child: Text(tx('Cancel'), style: BoltText.a(12, weight: 800, color: BoltColors.ink)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        if (moving == null) ...[
          const SizedBox(height: 14),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Tap(
                    onTap: () => showSplitSheet(t.id),
                    child: BoltBox(
                      radius: 14,
                      stroke: const Stroke(BoltColors.line),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Kicker(tx('YOUR SPLIT · TAP TO CHANGE'), size: 9, spacing: .1),
                          const SizedBox(height: 2),
                          Text(tx(splitOf(d, t.split).name), style: BoltText.a(13, weight: 800)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Tap(
                  onTap: () => store.autoFill(t.id),
                  scale: .96,
                  child: BoltBox(
                    radius: 14,
                    color: BoltColors.neon,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    alignment: Alignment.center,
                    child: Text(tx('Auto-fill 3 wks'), style: BoltText.a(13, weight: 800, color: BoltColors.ink)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Three equal pills: they open sheets, and a trailing "…" read
          // like text cut short.
          Row(
            children: [
              Expanded(
                child: _PlanPill(
                  label: tx('Deload week'),
                  onTap: () => showBoltSheet<void>(context, (_) => DeloadSheet(tid: t.id)),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _PlanPill(
                  label: t.stats.away.contains(dk(store.mon0)) ? tx('Away this week') : tx('Away'),
                  on: t.stats.away.contains(dk(store.mon0)),
                  onTap: () => showBoltSheet<void>(context, (_) => const AwaySheet()),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _PlanPill(
                  label: programWeekText(store, t.id) ?? tx('Programs'),
                  on: programWeekText(store, t.id) != null,
                  onTap: () => showBoltSheet<void>(context, (_) => ProgramSheet(tid: t.id), maxHeight: .92),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${d.account?.isSolo ?? false ? tx('Tap an empty day to add the next session from your split. Past days too, to log your diary.') : tx('Tap an empty day to add the next session from your split.')} ${tx('Long-press one to mark it as a rest day.')}',
            style: BoltText.a(12, color: BoltColors.muted),
          ),
        ],
        const SizedBox(height: 16),
        WeekdayHeader(mondayFirst: d.settings.mondayFirst),
        const SizedBox(height: 6),
        CalendarGrid(cells: cells, onTap: onTap, onLongPress: onLongPress),
        const SizedBox(height: 14),
        Legend(items: traineeLegend),
        const SizedBox(height: 26),
        SectionTitle(tx('Coming up')),
        const SizedBox(height: 10),
        for (final k in up.take(5)) ...[_UpRow(dayKey: k, session: plan[k]!), const SizedBox(height: 8)],
        if (up.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Text(
              tx('Nothing planned yet. Tap a day above or auto-fill from your split.'),
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
                  Text(tx(session.title), style: BoltText.a(18, weight: 800)),
                  const SizedBox(height: 3),
                  Text(tx(session.focus), style: BoltText.a(12, color: BoltColors.muted)),
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

/// A small outlined pill that opens a planning sheet; neon while it is on.
class _PlanPill extends StatelessWidget {
  const _PlanPill({required this.label, required this.onTap, this.on = false});

  final String label;
  final VoidCallback onTap;
  final bool on;

  @override
  Widget build(BuildContext context) {
    return Tap(
      onTap: onTap,
      scale: .96,
      child: BoltBox(
        height: 40,
        radius: BoltRadii.pill,
        stroke: Stroke(on ? BoltColors.neon : BoltColors.line, on ? 1.5 : 1),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        alignment: Alignment.center,
        borderBox: true,
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: BoltText.a(13, weight: 700, color: on ? BoltColors.neon : BoltColors.textSoft),
        ),
      ),
    );
  }
}
