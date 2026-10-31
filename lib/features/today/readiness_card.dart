import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/actions.dart';
import '../../core/format.dart';
import '../../data/bolt_store.dart';
import '../../data/lifts.dart';
import '../../data/models/people.dart';
import '../../data/models/session.dart';
import '../../data/models/visit.dart';
import '../../data/readiness.dart';
import '../../services/haptics.dart';
import '../../theme/text_styles.dart';
import '../../theme/tokens.dart';
import '../../widgets/box.dart';
import '../../widgets/common.dart';
import '../../widgets/forms.dart';
import '../../widgets/tap.dart';

/// The questions with three answers, worst first, at their place in a
/// check-in.
const _questions = [
  ('Sleep', ['Bad', 'OK', 'Great']),
  ('Energy', ['Low', 'OK', 'High']),
  ('Soreness', ['Very sore', 'A bit', 'Fresh']),
];
const _mood = ('Mood', ['Down', 'OK', 'Good']);

/// Sore muscle groups as people say them.
const _soreNames = {
  'chest': 'Chest',
  'back': 'Back',
  'shoulders': 'Shoulders',
  'arms': 'Arms',
  'legs': 'Legs',
  'core': 'Core',
};

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

/// "Sleep: Great · Energy: OK · Soreness: A bit" for a check-in, with hours,
/// mood, where it is sore, grip and the score when it has them.
String readinessAnswers(List<int> r) {
  if (r.length <= kScore) {
    return [for (final (i, (q, answers)) in _questions.indexed) '${tx(q)}: ${tx(answers[r[i] - 1])}'].join(' · ');
  }
  final sore = [for (final g in soreGroups(r[kSoreAt])) tx(_soreNames[g]!)];
  return [
    '${tx('Sleep')}: ${_hours(r[kHalfHours])} h, ${tx(_questions[0].$2[r[kSleepQ] - 1])}',
    '${tx('Energy')}: ${tx(_questions[1].$2[r[kEnergy] - 1])}',
    '${tx(_mood.$1)}: ${tx(_mood.$2[r[kMood] - 1])}',
    '${tx('Soreness')}: ${tx(_questions[2].$2[r[kSore] - 1])}${sore.isEmpty ? '' : ' (${sore.join(', ')})'}',
    '${tx('Grip')}: ${r[kGrip] * 10}%',
    '${tx('Score')}: ${r[kScore]}',
  ].join(' · ');
}

/// Every day: sleep (hours and how well), energy, mood, soreness and where,
/// and a grip squeeze as a quick check of the nervous system. Saved for the
/// day with a score from 0 to 100. A low score makes today's workout
/// lighter and a very low one turns the day into rest, with an undo; on a
/// rest day there is no training advice.
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
  /// Answers by index in a check-in; sleep hours start from the last
  /// check-in that had them.
  late final _a = <int, int>{
    kHalfHours:
        [
          for (final r in widget.trainee.readiness.values)
            if (r.length > kHalfHours) r[kHalfHours],
        ].lastOrNull ??
        15,
  };
  final _sore = <String>{};

  /// A confirmed workout today that has not been made lighter yet.
  bool get _canLighten {
    final s = widget.session;
    return s != null && s.status != SessionStatus.pending && s.ex.isNotEmpty && s.note != lighterNote;
  }

  bool get _complete => [kSleepQ, kEnergy, kMood, kSore, kGrip].every(_a.containsKey);

  void _save() {
    ref.read(boltProvider.notifier).setReadiness([
      for (final i in [kSleepQ, kEnergy, kSore, kHalfHours, kMood, kGrip]) _a[i]!,
      _a[kSore] == 3 ? 0 : _sore.fold(0, (m, g) => m | (1 << kSoreGroups.indexOf(g))),
    ]);
  }

  Widget _chips(int at, (String, List<String>) q) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      FieldLabel(tx(q.$1).toUpperCase(), top: 12),
      ChoiceChips(
        options: const ['1', '2', '3'],
        labels: {'1': q.$2[0], '2': q.$2[1], '3': q.$2[2]},
        selected: _a[at]?.toString(),
        onSelect: (v) => setState(() => _a[at] = int.parse(v)),
      ),
    ],
  );

  /// The sleep hours: − 7.5 h +, half an hour a step from 3 to 12.
  Widget _sleepHours() {
    Widget key(String l, int d) => Tap(
      onTap: () {
        Haptics.play(Feel.tick);
        setState(() => _a[kHalfHours] = (_a[kHalfHours]! + d).clamp(6, 24));
      },
      child: BoltBox(
        width: 40,
        height: 36,
        radius: 10,
        stroke: const Stroke(BoltColors.line),
        alignment: Alignment.center,
        child: Text(l, style: BoltText.a(18, weight: 700)),
      ),
    );
    return Row(
      children: [
        key('−', -1),
        SizedBox(
          width: 76,
          child: Text(
            '${_hours(_a[kHalfHours]!)} h',
            textAlign: TextAlign.center,
            style: BoltText.m(16, weight: 700, color: BoltColors.neon),
          ),
        ),
        key('+', 1),
      ],
    );
  }

  Widget _form() {
    Widget pill(String label, bool on, VoidCallback onTap) => Tap(
      onTap: () {
        Haptics.play(Feel.tick);
        onTap();
      },
      child: BoltBox(
        radius: 99,
        color: on ? BoltColors.neon : BoltColors.surface2,
        stroke: Stroke(on ? BoltColors.neon : BoltColors.line),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        child: Text(label, style: BoltText.a(13, weight: 700, color: on ? BoltColors.ink : BoltColors.text)),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(tx('How do you feel today?'), style: BoltText.a(16, weight: 800)),
        FieldLabel(tx('HOURS OF SLEEP'), top: 12),
        _sleepHours(),
        _chips(kSleepQ, ('Sleep', _questions[0].$2)),
        _chips(kEnergy, _questions[1]),
        _chips(kMood, _mood),
        _chips(kSore, _questions[2]),
        if (_a[kSore] != null && _a[kSore]! < 3) ...[
          FieldLabel(tx('WHERE?'), top: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final g in kSoreGroups)
                pill(
                  tx(_soreNames[g]!),
                  _sore.contains(g),
                  () => setState(() => _sore.contains(g) ? _sore.remove(g) : _sore.add(g)),
                ),
            ],
          ),
        ],
        FieldLabel(tx('GRIP CHECK'), top: 12),
        Text(
          tx('Make a fist and squeeze as hard as you can. How strong does it feel?'),
          style: BoltText.a(12, color: BoltColors.muted, height: 1.35),
        ),
        const SizedBox(height: 8),
        _GripBar(
          value: _a[kGrip],
          onChanged: (g) {
            if (g != _a[kGrip]) Haptics.play(Feel.tick);
            setState(() => _a[kGrip] = g);
          },
        ),
        const SizedBox(height: 14),
        NeonButton(label: tx('Save check-in'), height: 48, onTap: _complete ? _save : null),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = ref.read(boltProvider.notifier);
    final r = widget.trainee.readiness[widget.dayKey];
    final level = r == null ? null : readinessLevel(r);
    final auto = store.canUndoReadiness ? store.autoDone : null;
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
          if (level == null)
            _form()
          else ...[
            if (r!.length > kScore)
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${r[kScore]}',
                    style: BoltText.a(
                      40,
                      weight: 900,
                      height: 1,
                      color: level == 'low' ? BoltColors.warn : BoltColors.neon,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 5),
                    child: Text('/ 100', style: BoltText.m(12, weight: 700, color: BoltColors.muted)),
                  ),
                ],
              ),
            const SizedBox(height: 6),
            Text(
              tx((widget.session == null ? kRestReadinessText : kReadinessText)[level]!),
              style: BoltText.a(14, weight: 700, height: 1.4),
            ),
            if (auto != null) ...[
              const SizedBox(height: 10),
              Text(auto, style: BoltText.a(13, weight: 700, color: BoltColors.warn, height: 1.35)),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Tap(
                  onTap: store.undoReadiness,
                  child: BoltBox(
                    radius: 10,
                    stroke: const Stroke(BoltColors.line),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    child: Text(tx('Undo, I train as planned'), style: BoltText.a(12, weight: 800)),
                  ),
                ),
              ),
            ] else if (level == 'low' && _canLighten) ...[
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
            const SizedBox(height: 10),
            Tap(
              onTap: () => showInjurySheet(widget.trainee.id),
              child: Text(
                tx('Hurt somewhere? Flag it and Bolt swaps those exercises →'),
                style: BoltText.a(12, weight: 700, color: BoltColors.muted),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Half hours as "7.5".
String _hours(int half) => half.isEven ? '${half ~/ 2}' : '${half ~/ 2}.5';

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

/// Grip strength from 0 to 100 % in steps of 10: tap or slide along the bar.
/// One line instead of eleven chips.
class _GripBar extends StatelessWidget {
  const _GripBar({required this.value, required this.onChanged});

  /// 0 to 10, or null before it is answered.
  final int? value;
  final ValueChanged<int> onChanged;

  static const _thumb = 24.0;

  @override
  Widget build(BuildContext context) {
    final v = value;
    return Row(
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, box) {
              final track = box.maxWidth - _thumb;
              void at(double x) => onChanged(((x - _thumb / 2) / track * 10).round().clamp(0, 10));
              return GestureDetector(
                key: const ValueKey('grip'),
                behavior: HitTestBehavior.opaque,
                onTapDown: (d) => at(d.localPosition.dx),
                onHorizontalDragStart: (d) => at(d.localPosition.dx),
                onHorizontalDragUpdate: (d) => at(d.localPosition.dx),
                child: SizedBox(
                  height: 44,
                  child: Stack(
                    alignment: Alignment.centerLeft,
                    children: [
                      Positioned(
                        left: _thumb / 2,
                        right: _thumb / 2,
                        child: Container(
                          height: 6,
                          decoration: BoxDecoration(color: BoltColors.line, borderRadius: BorderRadius.circular(3)),
                        ),
                      ),
                      if (v != null) ...[
                        Positioned(
                          left: _thumb / 2,
                          width: track * v / 10,
                          child: Container(
                            height: 6,
                            decoration: BoxDecoration(color: BoltColors.neon, borderRadius: BorderRadius.circular(3)),
                          ),
                        ),
                        Positioned(
                          left: track * v / 10,
                          child: Container(
                            width: _thumb,
                            height: _thumb,
                            decoration: const BoxDecoration(color: BoltColors.neon, shape: BoxShape.circle),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 52,
          child: Text(
            v == null ? '-' : '${v * 10}%',
            textAlign: TextAlign.right,
            style: BoltText.m(16, weight: 700, color: v == null ? BoltColors.muted3 : BoltColors.neon),
          ),
        ),
      ],
    );
  }
}
