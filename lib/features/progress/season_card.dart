import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../data/bolt_store.dart';
import '../../data/models/people.dart';
import '../../data/models/session.dart';
import '../../theme/text_styles.dart';
import '../../theme/tokens.dart';
import '../../widgets/bolt_sheet.dart';
import '../../widgets/box.dart';
import '../../widgets/common.dart';
import '../../widgets/fields.dart';
import '../../widgets/forms.dart';
import '../../widgets/tap.dart';

/// Workouts logged in [s] and PRs set in it.
(int, int) seasonProgress(Season s, Map<String, Session> plan) {
  var done = 0, prs = 0;
  plan.forEach((k, x) {
    if (x.status != SessionStatus.done || !s.has(k)) return;
    done++;
    prs += x.prs.length;
  });
  return (done, prs);
}

/// The season running: week, workouts against the goal and PRs. Tap to
/// manage it.
class SeasonCard extends StatelessWidget {
  const SeasonCard({super.key, required this.s, required this.plan, required this.today});

  final Season s;
  final Map<String, Session> plan;
  final String today;

  @override
  Widget build(BuildContext context) {
    final (done, prs) = seasonProgress(s, plan);
    final pace = (s.goal * s.week(today) / Season.weeks).ceil();
    return Tap(
      onTap: () => showBoltSheet<void>(context, (_) => const SeasonSheet()),
      child: BoltBox(
        color: BoltColors.surface1,
        stroke: const Stroke(Color(0x73C6FF1A)),
        radius: 18,
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Kicker(
                    tx('SEASON {n} · WEEK {w} OF 8', {'n': s.n, 'w': s.week(today)}),
                    size: 9,
                    spacing: .1,
                    color: BoltColors.neon,
                  ),
                ),
                Text(tx('{n} PRS', {'n': prs}), style: BoltText.m(10, weight: 700, color: BoltColors.muted)),
              ],
            ),
            const SizedBox(height: 4),
            Text(s.name.toUpperCase(), style: BoltText.a(22, weight: 900, width: 112)),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: (done / s.goal).clamp(0.0, 1.0),
                minHeight: 6,
                backgroundColor: BoltColors.lineSoft,
                valueColor: const AlwaysStoppedAnimation(BoltColors.neon),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${tx('{done} of {goal} workouts', {'done': done, 'goal': s.goal})} · '
              '${done >= pace ? tx('on pace') : tx('{n} behind pace', {'n': pace - done})}',
              style: BoltText.a(12, color: done >= pace ? BoltColors.neon : BoltColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}

/// A season that ended in the last two weeks: its wrap and the next one.
class SeasonDoneCard extends ConsumerWidget {
  const SeasonDoneCard({super.key, required this.s, required this.plan});

  final Season s;
  final Map<String, Session> plan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.read(boltProvider.notifier);
    final (done, _) = seasonProgress(s, plan);
    return BoltBox(
      color: BoltColors.neon,
      radius: 20,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  tx('SEASON {n} COMPLETE', {'n': s.n}),
                  style: BoltText.m(11, weight: 700, spacing: .12, color: BoltColors.ink),
                ),
              ),
              Tap(
                onTap: () => store.dismissHint('season:${s.n}'),
                child: Text('✕', style: BoltText.a(15, color: BoltColors.ink)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(s.name.toUpperCase(), style: BoltText.a(26, weight: 900, width: 112, color: BoltColors.ink)),
          const SizedBox(height: 4),
          Text(
            done >= s.goal
                ? tx('Goal reached: {done} of {goal} workouts.', {'done': done, 'goal': s.goal})
                : tx('{done} of {goal} workouts. Next season, beat it.', {'done': done, 'goal': s.goal}),
            style: BoltText.a(13, weight: 700, color: BoltColors.ink.withValues(alpha: .8)),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: NeonButton(
                  label: tx('Season wrap'),
                  height: 44,
                  radius: 12,
                  fontSize: 13,
                  color: BoltColors.ink,
                  textColor: BoltColors.neon,
                  onTap: () => context.push('/wrap?season=${s.n}'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlineButton(
                  label: tx('Next season'),
                  height: 44,
                  radius: 12,
                  fontSize: 13,
                  color: BoltColors.ink,
                  onTap: () => showBoltSheet<void>(context, (_) => const SeasonSheet()),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Start a season, or stop the one running.
class SeasonSheet extends ConsumerStatefulWidget {
  const SeasonSheet({super.key});

  @override
  ConsumerState<SeasonSheet> createState() => _SeasonSheetState();
}

class _SeasonSheetState extends ConsumerState<SeasonSheet> {
  final _name = TextEditingController();
  String _perWeek = '3';

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(boltProvider);
    final store = ref.read(boltProvider.notifier);
    final cur = store.currentSeason();
    final next = (store.tr(ref.read(boltProvider).account!.id).seasons.lastOrNull?.n ?? 0) + 1;
    void close() => Navigator.of(context).pop();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(cur == null ? tx('Start a season') : cur.name, style: BoltText.a(20, weight: 900)),
        const SizedBox(height: 4),
        Text(
          tx('8 weeks, one goal. Every workout counts toward it, and at the end you get a season wrap to share.'),
          style: BoltText.a(13, color: BoltColors.muted, height: 1.45),
        ),
        if (cur == null) ...[
          FieldLabel(tx('NAME')),
          BoltField(controller: _name, hint: tx('Season {n}', {'n': next})),
          FieldLabel(tx('WORKOUTS A WEEK')),
          ChoiceChips(
            options: const ['2', '3', '4', '5'],
            selected: _perWeek,
            onSelect: (v) => setState(() => _perWeek = v),
          ),
          const SizedBox(height: 18),
          NeonButton(
            label: tx('Start season {n}', {'n': next}),
            height: 52,
            scale: 1,
            onTap: () {
              store.startSeason(_name.text, int.parse(_perWeek));
              close();
            },
          ),
        ] else ...[
          const SizedBox(height: 18),
          OutlineButton(
            label: tx('Stop this season'),
            color: BoltColors.warn,
            onTap: () {
              store.stopSeason();
              close();
            },
          ),
        ],
      ],
    );
  }
}
