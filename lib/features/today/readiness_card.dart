import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../data/bolt_store.dart';
import '../../data/lifts.dart';
import '../../data/models/people.dart';
import '../../data/models/session.dart';
import '../../theme/text_styles.dart';
import '../../theme/tokens.dart';
import '../../widgets/box.dart';
import '../../widgets/common.dart';
import '../../widgets/forms.dart';
import '../../widgets/tap.dart';

/// The three questions and their answers, worst first.
const _questions = [
  ('Sleep', ['Bad', 'OK', 'Great']),
  ('Energy', ['Low', 'OK', 'High']),
  ('Soreness', ['Very sore', 'A bit', 'Fresh']),
];

/// What a readiness level means for today.
const kReadinessText = {
  'ready': 'Ready to go. A good day to push.',
  'normal': 'A normal day. Stick to the plan.',
  'low': 'Low readiness. Take it lighter: one set less per exercise, about 10% lighter.',
};

const kReadinessNames = {'ready': 'Ready', 'normal': 'Normal', 'low': 'Low'};

/// Before a workout: how did you sleep, how is your energy, how sore are
/// you. A low score offers a lighter day.
class ReadinessCard extends ConsumerStatefulWidget {
  const ReadinessCard({super.key, required this.trainee, required this.session, required this.dayKey});

  final Trainee trainee;

  /// Today's workout, if any: a low score can make it lighter.
  final Session? session;
  final String dayKey;

  @override
  ConsumerState<ReadinessCard> createState() => _ReadinessCardState();
}

class _ReadinessCardState extends ConsumerState<ReadinessCard> {
  final _picked = <int?>[null, null, null];

  /// A confirmed workout today that has not been made lighter yet.
  bool get _canLighten {
    final s = widget.session;
    return s != null && s.status != SessionStatus.pending && s.ex.isNotEmpty && s.note != lighterNote;
  }

  @override
  Widget build(BuildContext context) {
    final store = ref.read(boltProvider.notifier);
    final r = widget.trainee.readiness[widget.dayKey];
    final level = r == null ? null : readinessLevel(r);
    return BoltBox(
      color: BoltColors.surface1,
      stroke: Stroke(level == 'low' ? const Color(0x73FF7A45) : BoltColors.lineSoft),
      radius: 18,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Kicker(
            level == null ? tx('READINESS') : '${tx('READINESS')} · ${tx(kReadinessNames[level]!).toUpperCase()}',
            size: 9,
            spacing: .1,
            color: level == 'low' ? BoltColors.warn : BoltColors.neon,
          ),
          const SizedBox(height: 4),
          if (level == null) ...[
            Text(tx('How do you feel today?'), style: BoltText.a(16, weight: 800)),
            for (final (i, (q, answers)) in _questions.indexed) ...[
              FieldLabel(tx(q).toUpperCase(), top: 12),
              ChoiceChips(
                options: const ['1', '2', '3'],
                labels: {'1': answers[0], '2': answers[1], '3': answers[2]},
                selected: _picked[i]?.toString(),
                onSelect: (v) {
                  setState(() => _picked[i] = int.parse(v));
                  if (!_picked.contains(null)) store.setReadiness([for (final x in _picked) x!]);
                },
              ),
            ],
          ] else ...[
            Text(tx(kReadinessText[level]!), style: BoltText.a(14, weight: 700, height: 1.4)),
            if (level == 'low' && _canLighten) ...[
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: Tap(
                  onTap: () => store.lightenDay(widget.trainee.id, widget.dayKey),
                  child: BoltBox(
                    radius: 10,
                    color: BoltColors.warn,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    child: Text(tx('Make today lighter'), style: BoltText.a(12, weight: 800, color: BoltColors.ink)),
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

/// The last week of check-ins as dots, for the coach.
class ReadinessStrip extends StatelessWidget {
  const ReadinessStrip({super.key, required this.readiness, required this.now});

  final Map<String, List<int>> readiness;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final days = [for (var i = 6; i >= 0; i--) dk(addDays(now, -i))];
    final last = (readiness.keys.toList()..sort()).lastOrNull;
    Color dot(String? level) => switch (level) {
      'ready' => BoltColors.neon,
      'normal' => BoltColors.muted,
      'low' => BoltColors.warn,
      _ => BoltColors.lineSoft,
    };
    return Row(
      children: [
        for (final k in days) ...[
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: dot(readiness[k] == null ? null : readinessLevel(readiness[k]!)),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
        ],
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            last == null
                ? tx('No check-ins yet')
                : tx('{level} on {day}', {
                    'level': tx(kReadinessNames[readinessLevel(readiness[last]!)]!),
                    'day': fmtDay(last),
                  }),
            style: BoltText.m(10, color: BoltColors.muted),
          ),
        ),
      ],
    );
  }
}
