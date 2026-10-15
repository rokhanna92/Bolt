import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/share.dart';
import '../../core/format.dart';
import '../../data/bolt_store.dart';
import '../../data/models/people.dart';
import '../../data/models/session.dart';
import '../../data/programs.dart';
import '../../theme/text_styles.dart';
import '../../theme/tokens.dart';
import '../../widgets/box.dart';
import '../../widgets/common.dart';
import '../../widgets/forms.dart';
import '../../widgets/tap.dart';

const _actions = {
  'fill': 'Auto-fill 3 weeks',
  'deload': 'Deload next week',
  'program': 'Start a program',
  'challenge': 'Set a challenge',
};

/// One change for several trainees at once, then a message for each of them.
class BulkSheet extends ConsumerStatefulWidget {
  const BulkSheet({super.key, required this.trainees});

  final List<Trainee> trainees;

  @override
  ConsumerState<BulkSheet> createState() => _BulkSheetState();
}

class _BulkSheetState extends ConsumerState<BulkSheet> {
  late final _picked = {for (final t in widget.trainees) t.id};
  String _action = 'fill';
  String _program = kPrograms.first.id;
  String _kind = 'workouts';
  int _target = 12;

  /// Trainees the change was applied to, waiting for their message.
  List<String>? _toSend;
  final _sent = <String>{};

  void _apply() {
    final d = ref.read(boltProvider);
    final store = ref.read(boltProvider.notifier);
    final ids = [
      for (final t in widget.trainees)
        if (_picked.contains(t.id)) t.id,
    ];
    final next = addDays(store.mon0, 7);
    for (final id in ids) {
      switch (_action) {
        case 'fill':
          store.autoFill(id);
        case 'deload':
          final p = store.plan(id);
          final week = [for (var i = 0; i < 7; i++) p[dk(addDays(next, i))]].whereType<Session>();
          if (week.isNotEmpty && !week.any((s) => s.deload)) store.toggleDeload(id, next);
        case 'program':
          store.startProgram(id, _program);
        case 'challenge':
          store.setChallenge(
            id,
            Challenge(
              kind: _kind,
              target: _target,
              from: store.today,
              to: dk(addDays(store.now, 29)),
              by: store.co(d.account!.id).name,
            ),
          );
      }
    }
    store.toast(tx('Done for {n} · send each their plan', {'n': plural(ids.length, 'trainee')}));
    setState(() => _toSend = ids);
  }

  Future<void> _send(String id) async {
    final store = ref.read(boltProvider.notifier);
    final msg = store.sendDrafts(id) ?? store.planMessage(id);
    final hint = await shareMessage(msg, subject: tx('Your Bolt plan'));
    if (hint != null) store.toast(hint);
    setState(() => _sent.add(id));
  }

  @override
  Widget build(BuildContext context) {
    final store = ref.read(boltProvider.notifier);
    final toSend = _toSend;
    if (toSend != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(tx('Send the plans'), style: BoltText.a(20, weight: 900)),
          const SizedBox(height: 4),
          Text(
            tx('Each trainee gets their own message. Tap Send for each one.'),
            style: BoltText.a(13, color: BoltColors.muted, height: 1.45),
          ),
          const SizedBox(height: 10),
          for (final id in toSend)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: BoltColors.divider)),
              ),
              child: Row(
                children: [
                  Expanded(child: Text(store.trOrNull(id)?.name ?? '', style: BoltText.a(15, weight: 700))),
                  Tap(
                    onTap: () => _send(id),
                    child: BoltBox(
                      radius: 10,
                      color: _sent.contains(id) ? null : BoltColors.neon,
                      stroke: _sent.contains(id) ? const Stroke(BoltColors.line) : Stroke.none,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      child: Text(
                        _sent.contains(id) ? tx('Sent · again') : tx('Send'),
                        style: BoltText.a(
                          12,
                          weight: 800,
                          color: _sent.contains(id) ? BoltColors.muted : BoltColors.ink,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 14),
          OutlineButton(
            label: tx('Done'),
            color: BoltColors.text,
            borderColor: BoltColors.line,
            weight: 700,
            onTap: () => Navigator.of(context).pop(),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(tx('For several trainees'), style: BoltText.a(20, weight: 900)),
        const SizedBox(height: 4),
        Text(
          tx('Pick who, pick what, then send each of them their updated plan.'),
          style: BoltText.a(13, color: BoltColors.muted, height: 1.45),
        ),
        FieldLabel(tx('WHO')),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final t in widget.trainees)
              Tap(
                onTap: () => setState(() => _picked.contains(t.id) ? _picked.remove(t.id) : _picked.add(t.id)),
                child: BoltBox(
                  radius: 99,
                  color: _picked.contains(t.id) ? BoltColors.neon : BoltColors.surface2,
                  stroke: Stroke(_picked.contains(t.id) ? BoltColors.neon : BoltColors.line),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  child: Text(
                    firstName(t.name),
                    style: BoltText.a(
                      13,
                      weight: 700,
                      color: _picked.contains(t.id) ? BoltColors.ink : BoltColors.text,
                    ),
                  ),
                ),
              ),
          ],
        ),
        FieldLabel(tx('WHAT')),
        ChoiceChips(
          options: _actions.keys.toList(),
          labels: _actions,
          selected: _action,
          onSelect: (a) => setState(() => _action = a),
        ),
        if (_action == 'program') ...[
          FieldLabel(tx('PROGRAM')),
          ChoiceChips(
            options: [for (final p in kPrograms) p.id],
            labels: {for (final p in kPrograms) p.id: p.name},
            selected: _program,
            onSelect: (p) => setState(() => _program = p),
          ),
        ],
        if (_action == 'challenge') ...[
          FieldLabel(tx('NEXT 30 DAYS')),
          ChoiceChips(
            options: Challenge.kinds.keys.toList(),
            labels: const {'workouts': 'Workouts', 'visits': 'Gym visits', 'hours': 'Gym hours'},
            selected: _kind,
            onSelect: (k) => setState(() => _kind = k),
          ),
          const SizedBox(height: 10),
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
        ],
        const SizedBox(height: 18),
        NeonButton(
          label: tx('Apply to {n}', {'n': plural(_picked.length, 'trainee')}),
          height: 52,
          scale: 1,
          color: _picked.isEmpty ? BoltColors.line : BoltColors.neon,
          textColor: _picked.isEmpty ? BoltColors.muted : BoltColors.ink,
          onTap: _picked.isEmpty ? null : _apply,
        ),
      ],
    );
  }
}
