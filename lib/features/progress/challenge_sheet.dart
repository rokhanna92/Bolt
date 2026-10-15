import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/share.dart';
import '../../core/format.dart';
import '../../data/bolt_store.dart';
import '../../data/lifts.dart';
import '../../data/models/people.dart';
import '../../data/models/session.dart';
import '../../data/models/visit.dart';
import '../../theme/text_styles.dart';
import '../../theme/tokens.dart';
import '../../widgets/box.dart';
import '../../widgets/common.dart';
import '../../widgets/forms.dart';

const _periods = {'week': 'This week', 'month': 'This month', '30': 'Next 30 days'};
const _defaults = {'workouts': 12, 'visits': 12, 'hours': 15};

/// Set a challenge: a number of workouts, gym visits or gym hours in a
/// period. A coach's goes to the trainee with the plan message.
class ChallengeSheet extends ConsumerStatefulWidget {
  const ChallengeSheet({super.key, required this.tid});

  final String tid;

  @override
  ConsumerState<ChallengeSheet> createState() => _ChallengeSheetState();
}

class _ChallengeSheetState extends ConsumerState<ChallengeSheet> {
  late final Challenge? _old = ref.read(boltProvider.notifier).trOrNull(widget.tid)?.challenge;
  late String _kind = _old?.kind ?? 'workouts';
  late int _target = _old?.target ?? _defaults[_kind]!;
  String _period = 'month';

  (String, String) _range(DateTime now, bool mondayFirst) => switch (_period) {
    'week' => (dk(weekStart(now, mondayFirst: mondayFirst)), dk(addDays(weekStart(now, mondayFirst: mondayFirst), 6))),
    '30' => (dk(now), dk(addDays(now, 29))),
    _ => (dk(DateTime(now.year, now.month)), dk(DateTime(now.year, now.month + 1, 0))),
  };

  Future<void> _save() async {
    final d = ref.read(boltProvider);
    final store = ref.read(boltProvider.notifier);
    final (from, to) = _range(store.now, d.settings.mondayFirst);
    final coach = d.account?.isCoach ?? false;
    final msg = store.setChallenge(
      widget.tid,
      Challenge(kind: _kind, target: _target, from: from, to: to, by: coach ? store.co(d.account!.id).name : null),
    );
    Navigator.of(context).pop();
    if (msg != null) {
      final hint = await shareMessage(msg, subject: tx('Your Bolt challenge'));
      if (hint != null) store.toast(hint);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = ref.read(boltProvider.notifier);
    final coach = ref.read(boltProvider).account?.isCoach ?? false;
    final name = store.trOrNull(widget.tid)?.name ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(tx('Set a challenge'), style: BoltText.a(20, weight: 900)),
        const SizedBox(height: 4),
        Text(
          coach
              ? tx(
                  'A goal for {name}. It goes out with the plan message and their progress comes back with every update.',
                  {'name': firstName(name)},
                )
              : tx('A goal to chase. Progress counts itself from your workouts and gym scans.'),
          style: BoltText.a(13, color: BoltColors.muted, height: 1.45),
        ),
        FieldLabel(tx('WHAT')),
        ChoiceChips(
          options: Challenge.kinds.keys.toList(),
          labels: const {'workouts': 'Workouts', 'visits': 'Gym visits', 'hours': 'Gym hours'},
          selected: _kind,
          onSelect: (k) => setState(() {
            _kind = k;
            _target = _defaults[k]!;
          }),
        ),
        FieldLabel(tx('HOW MANY')),
        Row(
          children: [
            SquareButton(onTap: () => setState(() => _target = (_target - 1).clamp(1, 999)), label: '−'),
            Expanded(
              child: Text(
                '$_target',
                textAlign: TextAlign.center,
                style: BoltText.a(30, weight: 900, color: BoltColors.neon),
              ),
            ),
            SquareButton(onTap: () => setState(() => _target = (_target + 1).clamp(1, 999)), label: '+'),
          ],
        ),
        FieldLabel(tx('WHEN')),
        ChoiceChips(
          options: _periods.keys.toList(),
          labels: _periods,
          selected: _period,
          onSelect: (p) => setState(() => _period = p),
        ),
        const SizedBox(height: 18),
        NeonButton(
          label: coach ? tx('Save & send to {name}', {'name': firstName(name)}) : tx('Start challenge'),
          height: 52,
          scale: 1,
          onTap: _save,
        ),
        if (_old != null) ...[
          const SizedBox(height: 8),
          OutlineButton(
            label: tx('Remove challenge'),
            color: BoltColors.warn,
            borderColor: BoltColors.line,
            weight: 700,
            onTap: () async {
              final msg = store.setChallenge(widget.tid, null);
              Navigator.of(context).pop();
              if (msg != null) await shareMessage(msg, subject: tx('Your Bolt plan'));
            },
          ),
        ],
      ],
    );
  }
}

/// A challenge with its progress bar. [progress] null shows "waiting for
/// an update" (coach side).
class ChallengeCard extends StatelessWidget {
  const ChallengeCard({super.key, required this.c, required this.progress, required this.now, this.onTap});

  final Challenge c;
  final int? progress;
  final DateTime now;
  final VoidCallback? onTap;

  /// Progress on this phone.
  static int local(Challenge c, Map<String, Session> plan, List<Visit> visits) => challengeProgress(c, plan, visits);

  @override
  Widget build(BuildContext context) {
    final n = progress ?? 0;
    final pct = (n / c.target).clamp(0.0, 1.0);
    final left = daysLeft(c, now);
    final won = n >= c.target;
    final status = won
        ? tx('Done. Challenge complete!')
        : left == 0
        ? tx('Ended {day} at {n} of {target}', {'day': fmtDay(c.to), 'n': n, 'target': c.target})
        : tx('{n} to go · {days} left', {'n': c.target - n, 'days': plural(left, 'day')});
    final box = BoltBox(
      color: BoltColors.surface1,
      stroke: Stroke(won ? BoltColors.neon : BoltColors.lineSoft, won ? 1.5 : 1),
      radius: 18,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Kicker(
            '${c.by == null ? tx('CHALLENGE') : tx('CHALLENGE FROM {name}', {'name': firstName(c.by!).toUpperCase()})}'
            ' · ${tx('{from} TO {to}', {'from': fmtDay(c.from).toUpperCase(), 'to': fmtDay(c.to).toUpperCase()})}',
            size: 9,
            spacing: .08,
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(child: Text(c.title, style: BoltText.a(19, weight: 900))),
              Text(
                progress == null ? '?' : '$n / ${c.target}',
                style: BoltText.m(14, weight: 700, color: BoltColors.neon),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 8,
              backgroundColor: BoltColors.lineSoft,
              valueColor: const AlwaysStoppedAnimation(BoltColors.neon),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            progress == null ? tx('Progress arrives with their next update.') : status,
            style: BoltText.a(12, weight: 600, color: won ? BoltColors.neon : BoltColors.muted),
          ),
        ],
      ),
    );
    return onTap == null ? box : GestureDetector(onTap: onTap, child: box);
  }
}
