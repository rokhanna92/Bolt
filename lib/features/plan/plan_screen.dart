import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/actions.dart';
import '../../app/ui_state.dart';
import '../../app/share.dart';
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
    List<CalCell> cellsOf(DateTime m) => buildCalendar(
      month: m,
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
                          style: BoltText.a(13, weight: 800, color: BoltColors.onNeon),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          tx('Tap a free day to move it'),
                          style: BoltText.a(12, weight: 600, color: BoltColors.onNeon.withValues(alpha: .75)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Tap(
                    onTap: () => ref.read(moveFromProvider.notifier).set(null),
                    child: BoltBox(
                      radius: 10,
                      stroke: Stroke(BoltColors.onNeon, 1.5),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Text(tx('Cancel'), style: BoltText.a(12, weight: 800, color: BoltColors.onNeon)),
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
                    child: Text(tx('Auto-fill 3 wks'), style: BoltText.a(13, weight: 800, color: BoltColors.onNeon)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _PlanTool(
                  icon: Icons.south,
                  label: tx('Deload week'),
                  sub: tx('A lighter week'),
                  onTap: () => showBoltSheet<void>(context, (_) => DeloadSheet(tid: t.id)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _PlanTool(
                  icon: Icons.flight_takeoff,
                  label: t.stats.away.contains(dk(store.mon0)) ? tx('Away this week') : tx('Away'),
                  sub: tx('Keeps your streak'),
                  on: t.stats.away.contains(dk(store.mon0)),
                  onTap: () => showBoltSheet<void>(context, (_) => const AwaySheet()),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _PlanTool(
                  icon: Icons.view_timeline_outlined,
                  label: programWeekText(store, t.id) ?? tx('Programs'),
                  sub: tx('Ready-made blocks'),
                  on: programWeekText(store, t.id) != null,
                  onTap: () => showBoltSheet<void>(context, (_) => ProgramSheet(tid: t.id), maxHeight: .92),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _PlanTool(
                  icon: Icons.delete_sweep_outlined,
                  label: tx('Clear month'),
                  sub: tx('Wipe what you planned'),
                  danger: true,
                  onTap: () => _clearMonth(context, ref, t.id, month),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            tx('Tap an empty day to add the next session from your split.'),
            style: BoltText.a(13, color: BoltColors.muted, height: 1.4),
          ),
          const SizedBox(height: 6),
          Text(
            d.account?.isSolo ?? false
                ? '${tx('Past days too, to log your diary.')} ${tx('Long-press one to mark it as a rest day.')}'
                : tx('Long-press one to mark it as a rest day.'),
            style: BoltText.a(13, color: BoltColors.muted, height: 1.4),
          ),
          const SizedBox(height: 4),
        ],
        const SizedBox(height: 16),
        BluePanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              WeekdayHeader(mondayFirst: d.settings.mondayFirst),
              const SizedBox(height: 6),
              MonthPager(
                month: month,
                onMonth: ref.read(planMonthProvider.notifier).set,
                grid: (m) => CalendarGrid(cells: cellsOf(m), onTap: onTap, onLongPress: onLongPress),
              ),
              const SizedBox(height: 14),
              Legend(items: traineeLegend),
            ],
          ),
        ),
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
/// One of the plan's tools: what it is and what it does, with room to breathe.
class _PlanTool extends StatelessWidget {
  const _PlanTool({
    required this.icon,
    required this.label,
    required this.sub,
    required this.onTap,
    this.on = false,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final String sub;
  final VoidCallback onTap;
  final bool on;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final accent = danger ? BoltColors.warn : BoltColors.neon;
    return Tap(
      onTap: onTap,
      scale: .97,
      child: BoltBox(
        color: BoltColors.surface1,
        stroke: Stroke(on ? BoltColors.neon : BoltColors.lineSoft, on ? 1.5 : 1),
        radius: 14,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        child: Row(
          children: [
            Icon(icon, size: 20, color: accent),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: BoltText.a(13, weight: 800, color: danger ? BoltColors.warn : BoltColors.text),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    sub,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: BoltText.a(11, color: BoltColors.muted),
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

/// Asks first, since this wipes a whole month of planning.
Future<void> _clearMonth(BuildContext context, WidgetRef ref, String tid, DateTime month) async {
  final store = ref.read(boltProvider.notifier);
  final name = monthsLong[month.month - 1];
  if (!store.hasPlansIn(tid, month)) {
    store.toast(tx('Nothing planned in {month}', {'month': name}));
    return;
  }
  final ok = await confirmSheet(
    context,
    title: tx('Are you sure?'),
    body: tx('This removes everything you planned in {month}, sessions and rest days. Finished workouts stay.', {
      'month': name,
    }),
    confirm: tx('Clear {month}', {'month': name}),
  );
  if (ok) store.clearMonth(tid, month);
}
