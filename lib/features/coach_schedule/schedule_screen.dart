import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/ui_state.dart';
import '../../core/format.dart';
import '../../data/bolt_store.dart';
import '../../data/models/people.dart';
import '../../data/models/session.dart';
import '../../theme/text_styles.dart';
import '../../theme/tokens.dart';
import '../../widgets/box.dart';
import '../../widgets/common.dart';
import '../../widgets/tap.dart';

String _scheduleLabel(SessionStatus s) => switch (s) {
  SessionStatus.done => tx('Done'),
  SessionStatus.approved => tx('Confirmed'),
  SessionStatus.pending => tx('Waiting'),
  SessionStatus.moved => tx('Moved'),
  SessionStatus.draft => tx('Draft'),
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
      0 => tx('This week'),
      1 => tx('Next week'),
      -1 => tx('Last week'),
      _ => wk > 0 ? tx('In {n}', {'n': plural(wk, 'week')}) : tx('{n} ago', {'n': plural(-wk, 'week')}),
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
            child: TraineeSessionRow(trainee: x, session: s, inGym: d.gymIn[x.id] != null && k == today),
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
                      child: Text(tx('TODAY'), style: BoltText.m(9, weight: 700, color: BoltColors.ink)),
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
                  child: Text(tx('No sessions'), style: BoltText.a(12, color: BoltColors.muted3)),
                ),
            ],
          ),
        ),
      );
    }

    return ScreenScroll(
      children: [
        Kicker('${tx('SCHEDULE')} · ${dayMonth(wM)} - ${dayMonth(wE)}'.toUpperCase()),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(child: Text(label, style: BoltText.a(30, weight: 900, width: 112, spacing: -.02))),
            SquareButton(onTap: () => ref.read(scheduleWeekProvider.notifier).set(wk - 1), label: '‹'),
            const SizedBox(width: 6),
            SquareButton(onTap: () => ref.read(scheduleWeekProvider.notifier).set(wk + 1), label: '›'),
          ],
        ),
        const SizedBox(height: 16),
        StatRow(
          children: [
            StatTile(value: '$total', label: tx('SESSIONS'), valueSize: 26),
            StatTile(value: '$ok', label: tx('CONFIRMED'), valueSize: 26, valueColor: BoltColors.neon),
            StatTile(value: '$wait', label: tx('OPEN'), valueSize: 26),
          ],
        ),
        const SizedBox(height: 18),
        ...days,
      ],
    );
  }
}

/// One trainee's session on a day, with its status. Opens the trainee.
class TraineeSessionRow extends StatelessWidget {
  const TraineeSessionRow({super.key, required this.trainee, required this.session, this.inGym = false});

  final Trainee trainee;
  final Session session;

  /// Rings the avatar neon.
  final bool inGym;

  @override
  Widget build(BuildContext context) {
    return Tap(
      onTap: () => context.push('/trainee/${trainee.id}'),
      scale: .98,
      child: BoltBox(
        color: BoltColors.surface1,
        stroke: const Stroke(BoltColors.lineSoft),
        radius: 16,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Avatar(
              ini: initials(trainee.name),
              size: 38,
              fontSize: 12,
              ring: inGym ? BoltColors.neon : BoltColors.line,
              ringWidth: 2,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(trainee.name, style: BoltText.a(14, weight: 800)),
                  const SizedBox(height: 2),
                  Text(tx(session.title), style: BoltText.a(12, color: BoltColors.muted)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            StatusPill(
              status: session.status,
              label: _scheduleLabel(session.status),
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            ),
          ],
        ),
      ),
    );
  }
}
