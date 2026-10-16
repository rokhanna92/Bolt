import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

/// The same on a day without a workout: no advice about training.
const kRestReadinessText = {
  'ready': 'Feeling good. Enjoy the rest, you are set for the next session.',
  'normal': 'Saved. Rest up for the next session.',
  'low': 'Low today, so resting is the right call. Sleep well and eat well.',
};

const kReadinessNames = {'ready': 'Ready', 'normal': 'Normal', 'low': 'Low'};

/// "Sleep: Great · Energy: OK · Soreness: A bit" for a check-in.
String readinessAnswers(List<int> r) =>
    [for (final (i, (q, answers)) in _questions.indexed) '${tx(q)}: ${tx(answers[r[i] - 1])}'].join(' · ');

/// Every day: how did you sleep, how is your energy, how sore are you. Saved
/// for the day. Before a workout a low score offers a lighter day; on a rest
/// day there is no training advice.
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
            Text(
              tx((widget.session == null ? kRestReadinessText : kReadinessText)[level]!),
              style: BoltText.a(14, weight: 700, height: 1.4),
            ),
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

/// The last [days] days of check-ins as dots.
class ReadinessStrip extends StatelessWidget {
  const ReadinessStrip({super.key, required this.readiness, required this.now, this.days = 7});

  final Map<String, List<int>> readiness;
  final DateTime now;
  final int days;

  @override
  Widget build(BuildContext context) {
    final days = [for (var i = this.days - 1; i >= 0; i--) dk(addDays(now, -i))];
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

/// What was logged on day [dayKey] besides the workout: the check-in and
/// the gym visits from scanning the plaque.
class DayLog extends ConsumerWidget {
  const DayLog({super.key, required this.dayKey});

  final String dayKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(boltProvider);
    final t = ref.read(boltProvider.notifier).trOrNull(d.account?.id ?? '');
    if (t == null) return const SizedBox.shrink();
    final r = t.readiness[dayKey];
    final visits = [
      for (final v in d.visits[t.id] ?? const <Visit>[])
        if (v.date == dayKey) v,
    ];
    if (r == null && visits.isEmpty) return const SizedBox.shrink();
    final level = r == null ? null : readinessLevel(r);
    return BoltBox(
      color: BoltColors.surface1,
      stroke: const Stroke(BoltColors.lineSoft),
      radius: 14,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (r != null) ...[
            Kicker(
              '${tx('CHECK-IN')} · ${tx(kReadinessNames[level]!).toUpperCase()}',
              size: 9,
              spacing: .1,
              color: level == 'low' ? BoltColors.warn : BoltColors.neon,
            ),
            const SizedBox(height: 4),
            Text(readinessAnswers(r), style: BoltText.a(13, weight: 700, height: 1.35)),
          ],
          if (r != null && visits.isNotEmpty) const SizedBox(height: 10),
          if (visits.isNotEmpty) ...[
            Kicker(tx('IN THE GYM'), size: 9, spacing: .1),
            const SizedBox(height: 4),
            for (final v in visits)
              Text(
                '${v.inT} → ${v.outT} · ${dur(v.mins)}${v.auto ? ' · ${tx('AUTO')}' : ''}',
                style: BoltText.a(13, weight: 700, height: 1.35),
              ),
          ],
        ],
      ),
    );
  }
}

/// The last two weeks of check-ins: dots per day and how sleep, energy and
/// soreness averaged, 3 being the best.
class CheckIns extends StatelessWidget {
  const CheckIns({super.key, required this.readiness, required this.now});

  final Map<String, List<int>> readiness;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final from = dk(addDays(now, -13));
    final recent = [
      for (final e in readiness.entries)
        if (e.key.compareTo(from) >= 0) e.value,
    ];
    return BoltBox(
      color: BoltColors.surface1,
      stroke: const Stroke(BoltColors.lineSoft),
      radius: 18,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ReadinessStrip(readiness: readiness, now: now, days: 14),
          if (recent.isEmpty) ...[
            const SizedBox(height: 10),
            Text(
              tx('Answer the three questions on Today and every day shows up here.'),
              style: BoltText.a(12, color: BoltColors.muted, height: 1.35),
            ),
          ] else
            for (final (i, (q, _)) in _questions.indexed) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  SizedBox(width: 92, child: Text(tx(q), style: BoltText.a(12, weight: 700))),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        value: recent.fold(0, (a, r) => a + r[i]) / recent.length / 3,
                        minHeight: 6,
                        backgroundColor: BoltColors.lineSoft,
                        valueColor: const AlwaysStoppedAnimation(BoltColors.neon),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    (recent.fold(0, (a, r) => a + r[i]) / recent.length).toStringAsFixed(1),
                    style: BoltText.m(11, weight: 700),
                  ),
                ],
              ),
            ],
        ],
      ),
    );
  }
}
