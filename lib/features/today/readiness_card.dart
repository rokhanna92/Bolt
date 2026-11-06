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
import '../../widgets/motion.dart';
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
class ReadinessCard extends ConsumerWidget {
  const ReadinessCard({super.key, required this.trainee, required this.session, required this.dayKey});

  final Trainee trainee;

  /// Today's workout, if any: a low score can make it lighter.
  final Session? session;
  final String dayKey;

  /// A confirmed workout today that has not been made lighter yet.
  bool get _canLighten {
    final s = session;
    return s != null && s.status != SessionStatus.pending && s.ex.isNotEmpty && s.note != lighterNote;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.read(boltProvider.notifier);
    final r = trainee.readiness[dayKey];
    final level = r == null ? null : readinessLevel(r);
    final auto = store.canUndoReadiness ? store.autoDone : null;
    final tone = level == 'low' ? BoltColors.warn : BoltColors.neon;
    return BoltBox(
      color: BoltColors.surface1,
      stroke: Stroke(level == 'low' ? BoltColors.warn.withAlpha(0x73) : BoltColors.lineSoft),
      radius: 20,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Kicker(
            level == null ? tx('READINESS') : '${tx('READINESS')} · ${tx(kReadinessNames[level]!).toUpperCase()}',
            size: 9,
            spacing: .1,
            color: tone,
          ),
          const SizedBox(height: 6),
          if (level == null)
            CheckInForm(trainee: trainee)
          else ...[
            Row(
              children: [
                if (r!.length > kScore) ...[ScoreRing(score: r[kScore], color: tone), const SizedBox(width: 14)],
                Expanded(
                  child: Text(
                    tx((session == null ? kRestReadinessText : kReadinessText)[level]!),
                    style: BoltText.a(14, weight: 700, height: 1.4),
                  ),
                ),
              ],
            ),
            if (auto != null) ...[
              const SizedBox(height: 12),
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
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Tap(
                  onTap: () => store.lightenDay(trainee.id, dayKey),
                  child: BoltBox(
                    radius: 10,
                    color: BoltColors.warn,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    child: Text(tx('Make today lighter'), style: BoltText.a(12, weight: 800, color: BoltColors.onNeon)),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Tap(
              onTap: () => showInjurySheet(trainee.id),
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

/// Today's questions, each on a tile of its own, with how many are answered
/// on top. Saves once every one has an answer and calls [onSaved]. With
/// [stagger] the tiles rise in one after another.
class CheckInForm extends ConsumerStatefulWidget {
  const CheckInForm({super.key, required this.trainee, this.onSaved, this.stagger = false});

  final Trainee trainee;
  final VoidCallback? onSaved;
  final bool stagger;

  @override
  ConsumerState<CheckInForm> createState() => _CheckInFormState();
}

class _CheckInFormState extends ConsumerState<CheckInForm> {
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

  /// What has to be answered before it saves; sleep hours always have a value.
  static const _asked = [kSleepQ, kEnergy, kMood, kSore, kGrip];

  bool get _complete => _asked.every(_a.containsKey);

  void _set(int at, int v) {
    if (_a[at] != v) Haptics.play(Feel.tick);
    setState(() => _a[at] = v);
  }

  void _save() {
    Haptics.play(Feel.success);
    ref.read(boltProvider.notifier).setReadiness([
      for (final i in [kSleepQ, kEnergy, kSore, kHalfHours, kMood, kGrip]) _a[i]!,
      _a[kSore] == 3 ? 0 : _sore.fold(0, (m, g) => m | (1 << kSoreGroups.indexOf(g))),
    ]);
    widget.onSaved?.call();
  }

  Widget _choice(int at, List<String> answers) => _Choices(answers: answers, value: _a[at], onPick: (v) => _set(at, v));

  @override
  Widget build(BuildContext context) {
    final sore = _a[kSore] != null && _a[kSore]! < 3;
    final tiles = [
      _Tile(
        label: tx('HOURS OF SLEEP'),
        answered: true,
        child: _SleepHours(value: _a[kHalfHours]!, onChanged: (v) => _set(kHalfHours, v)),
      ),
      _Tile(
        label: tx('Sleep').toUpperCase(),
        answered: _a.containsKey(kSleepQ),
        child: _choice(kSleepQ, _questions[0].$2),
      ),
      _Tile(
        label: tx('Energy').toUpperCase(),
        answered: _a.containsKey(kEnergy),
        child: _choice(kEnergy, _questions[1].$2),
      ),
      _Tile(label: tx(_mood.$1).toUpperCase(), answered: _a.containsKey(kMood), child: _choice(kMood, _mood.$2)),
      _Tile(
        label: tx('Soreness').toUpperCase(),
        answered: _a.containsKey(kSore),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _choice(kSore, _questions[2].$2),
            AnimatedSize(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: !sore
                  ? const SizedBox(width: double.infinity)
                  : Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Kicker(tx('WHERE?'), size: 9, spacing: .1),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              for (final g in kSoreGroups)
                                _Pill(
                                  label: tx(_soreNames[g]!),
                                  on: _sore.contains(g),
                                  onTap: () {
                                    Haptics.play(Feel.tick);
                                    setState(() => _sore.contains(g) ? _sore.remove(g) : _sore.add(g));
                                  },
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
      _Tile(
        label: tx('GRIP CHECK'),
        answered: _a.containsKey(kGrip),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              tx('Make a fist and squeeze as hard as you can. How strong does it feel?'),
              style: BoltText.a(12, color: BoltColors.muted, height: 1.35),
            ),
            const SizedBox(height: 6),
            _GripBar(value: _a[kGrip], onChanged: (g) => _set(kGrip, g)),
          ],
        ),
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text(tx('How do you feel today?'), style: BoltText.a(17, weight: 800))),
            const SizedBox(width: 10),
            _Progress(done: _asked.where(_a.containsKey).length, of: _asked.length),
          ],
        ),
        const SizedBox(height: 12),
        for (final (i, t) in tiles.indexed) ...[
          if (i > 0) const SizedBox(height: 8),
          FadeSlideIn(
            play: widget.stagger,
            delay: Duration(milliseconds: 420 + 70 * i),
            offset: 16,
            child: t,
          ),
        ],
        const SizedBox(height: 14),
        NeonButton(label: tx('Save check-in'), height: 52, onTap: _complete ? _save : null),
      ],
    );
  }
}

/// One question: its label and answers on a tile that lights up once
/// answered.
class _Tile extends StatelessWidget {
  const _Tile({required this.label, required this.answered, required this.child});

  final String label;
  final bool answered;
  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 260),
    padding: const EdgeInsets.fromLTRB(12, 11, 12, 12),
    decoration: BoxDecoration(
      color: BoltColors.surface2,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: answered ? BoltColors.neon.withAlpha(0x4D) : BoltColors.lineSoft),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 260),
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: answered ? BoltColors.neon : BoltColors.line, shape: BoxShape.circle),
            ),
            const SizedBox(width: 7),
            Kicker(label, size: 9, spacing: .12, color: answered ? BoltColors.text : BoltColors.muted),
          ],
        ),
        const SizedBox(height: 10),
        child,
      ],
    ),
  );
}

/// Answered count as segments that fill in, with `3/5` beside them.
class _Progress extends StatelessWidget {
  const _Progress({required this.done, required this.of});

  final int done;
  final int of;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (var i = 0; i < of; i++)
        AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.only(left: 3),
          width: i < done ? 16 : 10,
          height: 4,
          decoration: BoxDecoration(
            color: i < done ? BoltColors.neon : BoltColors.line,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      const SizedBox(width: 8),
      Text('$done/$of', style: BoltText.m(10, weight: 700, color: done == of ? BoltColors.neon : BoltColors.muted)),
    ],
  );
}

/// Three answers, worst first, as tiles with one, two or three rising bars.
class _Choices extends StatelessWidget {
  const _Choices({required this.answers, required this.value, required this.onPick});

  final List<String> answers;

  /// 1 to 3, or null before it is answered.
  final int? value;
  final ValueChanged<int> onPick;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (var i = 0; i < 3; i++) ...[
        if (i > 0) const SizedBox(width: 6),
        Expanded(
          child: Tap(onTap: () => onPick(i + 1), scale: .95, child: _choiceTile(i + 1, answers[i], value == i + 1)),
        ),
      ],
    ],
  );

  Widget _choiceTile(int n, String label, bool on) => AnimatedContainer(
    duration: const Duration(milliseconds: 220),
    curve: Curves.easeOutCubic,
    height: 60,
    decoration: BoxDecoration(
      color: on ? BoltColors.neon : BoltColors.surface1,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: on ? BoltColors.neon : BoltColors.line),
      boxShadow: on ? [BoxShadow(color: BoltColors.glow(0x59), blurRadius: 18, spreadRadius: -4)] : const [],
    ),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (var b = 1; b <= 3; b++) ...[
              if (b > 1) const SizedBox(width: 2),
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                width: 4,
                height: 3.0 + 3 * b,
                decoration: BoxDecoration(
                  color: b <= n
                      ? (on ? BoltColors.onNeon : BoltColors.muted)
                      : (on ? BoltColors.onNeon.withAlpha(0x40) : BoltColors.line),
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 7),
        Text(
          tx(label),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: BoltText.a(12.5, weight: 800, color: on ? BoltColors.onNeon : BoltColors.text),
        ),
      ],
    ),
  );
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.on, required this.onTap});

  final String label;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tap(
    onTap: onTap,
    scale: .95,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
      decoration: BoxDecoration(
        color: on ? BoltColors.neon : BoltColors.surface1,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: on ? BoltColors.neon : BoltColors.line),
      ),
      child: Text(label, style: BoltText.a(13, weight: 700, color: on ? BoltColors.onNeon : BoltColors.text)),
    ),
  );
}

/// Sleep hours, half an hour a step from 3 to 12: the hours big with − and
/// + beside them, over a row of rising bars to tap or slide along.
class _SleepHours extends StatelessWidget {
  const _SleepHours({required this.value, required this.onChanged});

  /// Half hours, 6 to 24.
  final int value;
  final ValueChanged<int> onChanged;

  static const _min = 6, _max = 24;

  Widget _key(String l, int d) => Tap(
    onTap: () => onChanged((value + d).clamp(_min, _max)),
    scale: .9,
    child: Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: BoltColors.surface1,
        shape: BoxShape.circle,
        border: Border.all(color: BoltColors.line),
      ),
      child: Text(l, style: BoltText.a(18, weight: 700)),
    ),
  );

  @override
  Widget build(BuildContext context) {
    const n = _max - _min + 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(_hours(value), style: BoltText.a(34, weight: 900, height: 1, color: BoltColors.neon)),
            const SizedBox(width: 4),
            Text('h', style: BoltText.m(14, weight: 700, color: BoltColors.muted)),
            const Spacer(),
            _key('−', -1),
            const SizedBox(width: 8),
            _key('+', 1),
          ],
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, box) {
            void at(double x) => onChanged(_min + (x / box.maxWidth * n).floor().clamp(0, n - 1));
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (d) => at(d.localPosition.dx),
              onHorizontalDragStart: (d) => at(d.localPosition.dx),
              onHorizontalDragUpdate: (d) => at(d.localPosition.dx),
              child: SizedBox(
                height: 30,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (var i = 0; i < n; i++)
                      Expanded(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 160),
                          margin: const EdgeInsets.symmetric(horizontal: 1.5),
                          height: 8 + 22 * i / (n - 1),
                          decoration: BoxDecoration(
                            color: _min + i <= value
                                ? BoltColors.neon.withAlpha(0x59 + (0xA6 * i / (n - 1)).round())
                                : BoltColors.line,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

/// A check-in's score as a ring that fills while the number counts up.
class ScoreRing extends StatelessWidget {
  const ScoreRing({super.key, required this.score, required this.color, this.size = 64});

  final int score;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: score.toDouble()),
    duration: const Duration(milliseconds: 550),
    curve: Curves.easeOutCubic,
    builder: (context, v, _) => SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RingPainter(v / 100, color, size / 13),
        child: Center(
          child: Text('${v.round()}', style: BoltText.a(size * .36, weight: 900, height: 1, color: color)),
        ),
      ),
    ),
  );
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.f, this.color, this.width);

  final double f;
  final Color color;
  final double width;

  @override
  void paint(Canvas canvas, Size size) {
    final r = Offset.zero & size;
    final arc = r.deflate(width / 2);
    canvas.drawArc(
      arc,
      0,
      6.2832,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..color = BoltColors.line,
    );
    canvas.drawArc(
      arc,
      -1.5708,
      6.2832 * f,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.f != f || old.color != color;
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
              // An older check-in still names its day in the strip above,
              // so say why the last two weeks are empty.
              readiness.isEmpty
                  ? tx('Answer the three questions on Today and every day shows up here.')
                  : tx('None in the last two weeks. Answer the questions on Today and the days show up here.'),
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
                        valueColor: AlwaysStoppedAnimation(BoltColors.neon),
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

/// Grip strength from 0 to 100 % in steps of 10: tap or slide along the bar,
/// with a mark on every step. One line instead of eleven chips.
class _GripBar extends StatelessWidget {
  const _GripBar({required this.value, required this.onChanged});

  /// 0 to 10, or null before it is answered.
  final int? value;
  final ValueChanged<int> onChanged;

  static const _thumb = 24.0;

  @override
  Widget build(BuildContext context) {
    final v = value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _bar(v),
        // The ends of the scale, so an empty bar still reads as one to slide
        // along. Each sits centred under its end mark.
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (final l in ['0%', '100%'])
              SizedBox(
                width: _thumb,
                child: Text(
                  l,
                  softWrap: false,
                  textAlign: TextAlign.center,
                  style: BoltText.m(10, color: BoltColors.muted3),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _bar(int? v) => LayoutBuilder(
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
                  height: 10,
                  decoration: BoxDecoration(color: BoltColors.surface1, borderRadius: BorderRadius.circular(5)),
                ),
              ),
              for (var i = 0; i <= 10; i++)
                Positioned(
                  left: _thumb / 2 + track * i / 10 - 1,
                  child: Container(
                    width: 2,
                    height: i % 5 == 0 ? 22 : 16,
                    decoration: BoxDecoration(
                      color: v != null && i <= v ? BoltColors.neon.withAlpha(0x80) : BoltColors.line,
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ),
              if (v != null)
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 140),
                  curve: Curves.easeOut,
                  left: _thumb / 2,
                  width: track * v / 10,
                  child: Container(
                    height: 10,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(5),
                      gradient: LinearGradient(colors: [BoltColors.neon.withAlpha(0x59), BoltColors.neon]),
                      boxShadow: [BoxShadow(color: BoltColors.glow(0x4D), blurRadius: 10)],
                    ),
                  ),
                ),
              if (v != null)
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 140),
                  curve: Curves.easeOut,
                  left: track * v / 10,
                  child: Container(
                    width: _thumb,
                    height: _thumb,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: BoltColors.neon,
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: BoltColors.glow(0x73), blurRadius: 14)],
                    ),
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(color: BoltColors.onNeon, shape: BoxShape.circle),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );
}
