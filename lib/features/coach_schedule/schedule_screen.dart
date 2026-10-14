import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/ui_state.dart';
import '../../core/format.dart';
import '../../data/bolt_store.dart';
import '../../data/models/session.dart';
import '../../theme/text_styles.dart';
import '../../theme/tokens.dart';
import '../../widgets/box.dart';
import '../../widgets/common.dart';
import '../../widgets/tap.dart';

String _scheduleLabel(SessionStatus s) => switch (s) {
  SessionStatus.done => 'Done',
  SessionStatus.approved => 'Confirmed',
  SessionStatus.pending => 'Waiting',
  SessionStatus.moved => 'Moved',
  SessionStatus.draft => 'Draft',
};

class ScheduleScreen extends ConsumerWidget {
  const ScheduleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(boltProvider);
    final store = ref.read(boltProvider.notifier);
    final wk = ref.watch(scheduleWeekProvider);
    final c = store.co(d.account?.id ?? '');
    final today = store.today;
    final my = d.trainees.where((x) => x.coach == c.id).toList();
    final wM = addDays(weekStart(store.now, mondayFirst: d.settings.mondayFirst), 7 * wk);
    final wE = addDays(wM, 6);
    final label = switch (wk) {
      0 => 'This week',
      1 => 'Next week',
      -1 => 'Last week',
      _ => wk > 0 ? 'In $wk weeks' : '${-wk} weeks ago',
    };
    var total = 0, ok = 0, wait = 0;
    final days = <Widget>[];
    for (var i = 0; i < 7; i++) {
      final k = dk(addDays(wM, i));
      final items = <Widget>[];
      for (final x in my) {
        final s = store.plan(x.id)[k];
        if (s == null) continue;
        total++;
        if (s.status == SessionStatus.done || s.status == SessionStatus.approved) ok++;
        if (s.status == SessionStatus.pending || s.status == SessionStatus.moved) wait++;
        items.add(
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Tap(
              onTap: () => context.push('/trainee/${x.id}'),
              scale: .98,
              child: BoltBox(
                color: BoltColors.surface1,
                stroke: const Stroke(BoltColors.lineSoft),
                radius: 16,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    Avatar(
                      ini: initials(x.name),
                      size: 38,
                      fontSize: 12,
                      ring: d.gymIn[x.id] != null && k == today ? BoltColors.neon : BoltColors.line,
                      ringWidth: 2,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(x.name, style: BoltText.a(14, weight: 800)),
                          const SizedBox(height: 2),
                          Text(s.title, style: BoltText.a(12, color: BoltColors.muted)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    StatusPill(
                      status: s.status,
                      label: _scheduleLabel(s.status),
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }
      final it = k == today;
      days.add(
        Padding(
          padding: EdgeInsets.only(top: i == 0 ? 0 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text(
                    fmtDay(k).toUpperCase(),
                    style: BoltText.m(11, weight: 700, spacing: .1, color: it ? BoltColors.neon : BoltColors.muted),
                  ),
                  if (it) ...[
                    const SizedBox(width: 8),
                    BoltBox(
                      color: BoltColors.neon,
                      radius: 6,
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      child: Text('TODAY', style: BoltText.m(9, weight: 700, color: BoltColors.ink)),
                    ),
                  ],
                  const SizedBox(width: 8),
                  const Expanded(child: Divider(height: 1, thickness: 1, color: BoltColors.divider)),
                ],
              ),
              ...items,
              if (items.isEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(2, 10, 2, 2),
                  child: Text('No sessions', style: BoltText.a(12, color: BoltColors.muted3)),
                ),
            ],
          ),
        ),
      );
    }

    return ScreenScroll(
      children: [
        Kicker(
          'SCHEDULE · ${wM.day} ${monthsShort[wM.month - 1]} – ${wE.day} ${monthsShort[wE.month - 1]}'.toUpperCase(),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(child: Text(label, style: BoltText.a(30, weight: 900, width: 112, spacing: -.02, height: 1.2))),
            SquareButton(onTap: () => ref.read(scheduleWeekProvider.notifier).set(wk - 1), label: '‹'),
            const SizedBox(width: 6),
            SquareButton(onTap: () => ref.read(scheduleWeekProvider.notifier).set(wk + 1), label: '›'),
          ],
        ),
        const SizedBox(height: 16),
        StatRow(
          children: [
            StatTile(value: '$total', label: 'SESSIONS', valueSize: 26, gap: 0),
            StatTile(value: '$ok', label: 'CONFIRMED', valueSize: 26, valueColor: BoltColors.neon, gap: 0),
            StatTile(value: '$wait', label: 'OPEN', valueSize: 26, gap: 0),
          ],
        ),
        const SizedBox(height: 18),
        ...days,
      ],
    );
  }
}
