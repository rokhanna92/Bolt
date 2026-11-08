import 'dart:async';
import 'dart:math' as math;

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
import '../../widgets/surfaces.dart';
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
    final tone = level == 'low' ? BoltColors.warn : BoltColors.body;
    return Stage(
      color: tone,
      padding: const EdgeInsets.all(16),
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
                    style: BoltText.headline(16),
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

/// Today's check-in, one question at a time, each answered its own way. An
/// answer lands with a flash and a bolt and the next question slides in;
/// sleep hours and where it is sore take a Next, and the grip saves. Calls
/// [onSaved] once saved.
class CheckInForm extends ConsumerStatefulWidget {
  const CheckInForm({super.key, required this.trainee, this.onSaved});

  final Trainee trainee;
  final VoidCallback? onSaved;

  @override
  ConsumerState<CheckInForm> createState() => _CheckInFormState();
}

enum _Step { hours, sleep, energy, mood, sore, where, grip }

class _CheckInFormState extends ConsumerState<CheckInForm> with SingleTickerProviderStateMixin {
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
  var _step = _Step.hours;

  /// The last move went back a question, so it slides the other way.
  var _back = false;
  late final _flash = AnimationController(vsync: this, duration: const Duration(milliseconds: 560));
  Timer? _next;

  /// Where it is sore is only asked when it is.
  List<_Step> get _steps => [
    for (final s in _Step.values)
      if (s != _Step.where || (_a[kSore] ?? 3) < 3) s,
  ];

  @override
  void dispose() {
    _next?.cancel();
    _flash.dispose();
    super.dispose();
  }

  void _go(int by) {
    final s = _steps;
    setState(() {
      _back = by < 0;
      _step = s[(s.indexOf(_step) + by).clamp(0, s.length - 1)];
    });
  }

  /// A flash and a bolt, then on to the next question.
  void _hit() {
    Haptics.play(Feel.set);
    _flash.forward(from: 0);
    _next?.cancel();
    final at = _step;
    _next = Timer(const Duration(milliseconds: 260), () {
      if (mounted && _step == at) _go(1);
    });
  }

  void _answer(int at, int v) {
    setState(() => _a[at] = v);
    _hit();
  }

  void _save() {
    Haptics.play(Feel.success);
    ref.read(boltProvider.notifier).setReadiness([
      for (final i in [kSleepQ, kEnergy, kSore, kHalfHours, kMood, kGrip]) _a[i]!,
      _a[kSore] == 3 ? 0 : _sore.fold(0, (m, g) => m | (1 << kSoreGroups.indexOf(g))),
    ]);
    widget.onSaved?.call();
  }

  @override
  Widget build(BuildContext context) {
    final steps = _steps;
    final i = steps.indexOf(_step);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: i > 0 ? 1 : 0,
              child: Tap(
                onTap: i > 0 ? () => _go(-1) : null,
                child: SizedBox(
                  width: 32,
                  height: 28,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: BoltIcon('back', size: 18, color: BoltColors.muted),
                  ),
                ),
              ),
            ),
            Expanded(
              child: Row(
                children: [
                  for (var k = 0; k < steps.length; k++) ...[
                    if (k > 0) const SizedBox(width: 4),
                    Expanded(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        height: 4,
                        decoration: BoxDecoration(
                          color: k <= i ? BoltColors.neon : BoltColors.line,
                          borderRadius: BorderRadius.circular(2),
                          boxShadow: k == i ? [BoxShadow(color: BoltColors.glow(0x80), blurRadius: 8)] : const [],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            SizedBox(
              width: 40,
              child: Text(
                '${i + 1}/${steps.length}',
                textAlign: TextAlign.right,
                style: BoltText.m(10, weight: 700, color: BoltColors.muted),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Stack(
          children: [
            AnimatedSize(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 280),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                layoutBuilder: (current, previous) =>
                    Stack(alignment: Alignment.topCenter, children: [...previous, ?current]),
                transitionBuilder: (child, a) {
                  final dx = (child.key == ValueKey(_step) ? 1 : -1) * (_back ? -.35 : .35);
                  return FadeTransition(
                    opacity: a,
                    child: SlideTransition(
                      position: Tween(begin: Offset(dx, 0), end: Offset.zero).animate(a),
                      child: child,
                    ),
                  );
                },
                child: KeyedSubtree(key: ValueKey(_step), child: _question(_step)),
              ),
            ),
            Positioned.fill(child: IgnorePointer(child: _BoltHit(_flash))),
          ],
        ),
      ],
    );
  }

  Widget _question(_Step s) => switch (s) {
    _Step.hours => _Ask(
      title: tx('How many hours of sleep?'),
      next: NeonButton(label: tx('Next'), height: 50, onTap: _hit),
      child: _SleepHours(
        value: _a[kHalfHours]!,
        onChanged: (v) {
          if (v != _a[kHalfHours]) Haptics.play(Feel.tick);
          setState(() => _a[kHalfHours] = v);
        },
      ),
    ),
    _Step.sleep => _Ask(
      title: tx('How was your sleep?'),
      child: _SleepList(answers: _questions[0].$2, value: _a[kSleepQ], onPick: (v) => _answer(kSleepQ, v)),
    ),
    _Step.energy => _Ask(
      title: tx('How is your energy?'),
      child: _Battery(answers: _questions[1].$2, value: _a[kEnergy], onPick: (v) => _answer(kEnergy, v)),
    ),
    _Step.mood => _Ask(
      title: tx('How is your mood?'),
      child: _Faces(answers: _mood.$2, value: _a[kMood], onPick: (v) => _answer(kMood, v)),
    ),
    _Step.sore => _Ask(
      title: tx('How sore are you?'),
      child: _Heat(answers: _questions[2].$2, value: _a[kSore], onPick: (v) => _answer(kSore, v)),
    ),
    _Step.where => _Ask(
      title: tx('Where is it sore?'),
      hint: tx('Tap every part that is.'),
      next: NeonButton(label: tx('Next'), height: 50, onTap: _hit),
      child: _BodyParts(
        on: _sore,
        onTap: (g) {
          Haptics.play(Feel.tick);
          setState(() => _sore.contains(g) ? _sore.remove(g) : _sore.add(g));
        },
      ),
    ),
    _Step.grip => _Ask(
      title: tx('Grip check'),
      hint: tx('Make a fist and squeeze as hard as you can. How strong does it feel?'),
      next: NeonButton(label: tx('Save check-in'), height: 50, onTap: _a.containsKey(kGrip) ? _save : null),
      child: _GripBar(
        value: _a[kGrip],
        onChanged: (g) {
          if (g != _a[kGrip]) Haptics.play(Feel.tick);
          setState(() => _a[kGrip] = g);
        },
      ),
    ),
  };
}

/// One question: the question big, a hint under it, how to answer and
/// the button that moves on, when it takes one.
class _Ask extends StatelessWidget {
  const _Ask({required this.title, required this.child, this.hint, this.next});

  final String title;
  final String? hint;
  final Widget child;
  final Widget? next;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(title, style: BoltText.a(21, weight: 900, width: 108, spacing: -.01, height: 1.15)),
      if (hint != null) ...[
        const SizedBox(height: 6),
        Text(hint!, style: BoltText.a(13, color: BoltColors.muted, height: 1.35)),
      ],
      const SizedBox(height: 16),
      child,
      if (next != null) ...[const SizedBox(height: 16), next!],
    ],
  );
}

/// The flash over the question and a bolt striking in its middle, as
/// [a] runs from 0 to 1.
class _BoltHit extends AnimatedWidget {
  const _BoltHit(Animation<double> a) : super(listenable: a);

  @override
  Widget build(BuildContext context) {
    final t = (listenable as Animation<double>).value;
    if (t == 0 || t == 1) return const SizedBox.shrink();
    return CustomPaint(painter: _BoltPainter(t));
  }
}

class _BoltPainter extends CustomPainter {
  _BoltPainter(this.t);

  final double t;

  /// The bolt from the app icon, on a 24 grid.
  static const _shape = [
    Offset(13.5, 3),
    Offset(5, 13.5),
    Offset(11, 13.5),
    Offset(10, 21),
    Offset(18.5, 10.5),
    Offset(12.5, 10.5),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final neon = BoltColors.neon;
    final rect = Offset.zero & size;
    // The flash: bright at once, gone by the end.
    final f = math.pow(1 - t, 2).toDouble();
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect.inflate(6), const Radius.circular(18)),
      Paint()..color = neon.withAlpha((0x47 * f).round()),
    );
    // The bolt: strikes in big, settles, then fades.
    final grow = Curves.easeOutBack.transform((t / .45).clamp(0.0, 1.0));
    final fade = t < .55 ? 1.0 : 1 - (t - .55) / .45;
    final s = (40 + 60 * grow) / 24;
    final c = rect.center;
    final path = Path()..addPolygon([for (final p in _shape) c + (p - const Offset(12, 12)) * s], true);
    canvas.drawPath(
      path,
      Paint()
        ..color = neon.withAlpha((0x99 * fade).round())
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
    );
    canvas.drawPath(path, Paint()..color = neon.withAlpha((0xFF * fade).round()));
  }

  @override
  bool shouldRepaint(_BoltPainter old) => old.t != t;
}

/// How well you slept as a list, best on top.
class _SleepList extends StatelessWidget {
  const _SleepList({required this.answers, required this.value, required this.onPick});

  final List<String> answers;
  final int? value;
  final ValueChanged<int> onPick;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (var n = 3; n >= 1; n--) ...[
        if (n < 3) const SizedBox(height: 8),
        Tap(
          onTap: () => onPick(n),
          scale: .97,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: _pick(value == n, 14),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    tx(answers[n - 1]),
                    style: BoltText.a(16, weight: 800, color: value == n ? BoltColors.onNeon : BoltColors.text),
                  ),
                ),
                // Moons for how deep it was: one to three.
                for (var m = 0; m < 3; m++)
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: CustomPaint(
                      size: const Size(14, 14),
                      painter: _MoonPainter(
                        m < n
                            ? (value == n ? BoltColors.onNeon : BoltColors.neon)
                            : (value == n ? BoltColors.onNeon.withAlpha(0x40) : BoltColors.line),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    ],
  );
}

class _MoonPainter extends CustomPainter {
  _MoonPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2;
    final moon = Path.combine(
      PathOperation.difference,
      Path()..addOval(Rect.fromCircle(center: Offset(r, r), radius: r)),
      Path()..addOval(Rect.fromCircle(center: Offset(r * 1.55, r * .65), radius: r * .85)),
    );
    canvas.drawPath(moon, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_MoonPainter old) => old.color != color;
}

/// Energy as a battery: tap a cell and it fills up to there.
class _Battery extends StatelessWidget {
  const _Battery({required this.answers, required this.value, required this.onPick});

  final List<String> answers;
  final int? value;
  final ValueChanged<int> onPick;

  @override
  Widget build(BuildContext context) {
    final v = value ?? 0;
    final fill = v == 1 ? BoltColors.warn : BoltColors.neon;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: v > 0 ? fill.withAlpha(0x8C) : BoltColors.line, width: 2),
            ),
            child: Row(
              children: [
                for (var n = 1; n <= 3; n++) ...[
                  if (n > 1) const SizedBox(width: 5),
                  Expanded(
                    child: Tap(
                      onTap: () => onPick(n),
                      scale: .95,
                      child: AnimatedContainer(
                        duration: Duration(milliseconds: 160 + 70 * n),
                        curve: Curves.easeOutCubic,
                        height: 64,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: n <= v ? fill : BoltColors.surface2,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: n <= v ? [BoxShadow(color: fill.withAlpha(0x40), blurRadius: 14)] : const [],
                        ),
                        child: Text(
                          tx(answers[n - 1]),
                          style: BoltText.a(13, weight: 800, color: n <= v ? BoltColors.onNeon : BoltColors.muted),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        // The battery's nub.
        Container(
          margin: const EdgeInsets.only(left: 3, top: 26),
          width: 6,
          height: 26,
          decoration: BoxDecoration(
            color: v == 3 ? fill : BoltColors.line,
            borderRadius: const BorderRadius.horizontal(right: Radius.circular(3)),
          ),
        ),
      ],
    );
  }
}

/// Mood as three faces, from a frown to a smile.
class _Faces extends StatelessWidget {
  const _Faces({required this.answers, required this.value, required this.onPick});

  final List<String> answers;
  final int? value;
  final ValueChanged<int> onPick;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (var n = 1; n <= 3; n++)
        Expanded(
          child: Tap(
            onTap: () => onPick(n),
            scale: .92,
            child: Column(
              children: [
                AnimatedScale(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutBack,
                  scale: value == n ? 1.1 : 1,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: value == n ? BoltColors.neon : BoltColors.surface2,
                      shape: BoxShape.circle,
                      border: Border.all(color: value == n ? BoltColors.neon : BoltColors.line, width: 1.5),
                      boxShadow: value == n ? [BoxShadow(color: BoltColors.glow(0x59), blurRadius: 18)] : const [],
                    ),
                    child: CustomPaint(painter: _FacePainter(n - 2, value == n ? BoltColors.onNeon : BoltColors.text)),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  tx(answers[n - 1]),
                  style: BoltText.a(13, weight: 800, color: value == n ? BoltColors.neon : BoltColors.muted),
                ),
              ],
            ),
          ),
        ),
    ],
  );
}

class _FacePainter extends CustomPainter {
  _FacePainter(this.smile, this.color);

  /// -1 a frown, 0 flat, 1 a smile.
  final int smile;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final p = Paint()..color = color;
    canvas.drawCircle(Offset(w * .36, w * .4), w * .05, p);
    canvas.drawCircle(Offset(w * .64, w * .4), w * .05, p);
    final y = w * .63;
    canvas.drawPath(
      Path()
        ..moveTo(w * .33, y - smile * w * .03)
        ..quadraticBezierTo(w * .5, y + smile * w * .12, w * .67, y - smile * w * .03),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * .055
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_FacePainter old) => old.smile != smile || old.color != color;
}

/// Soreness as three tiles that run hot: a glow that grows the sorer it is.
class _Heat extends StatelessWidget {
  const _Heat({required this.answers, required this.value, required this.onPick});

  final List<String> answers;
  final int? value;
  final ValueChanged<int> onPick;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (var n = 1; n <= 3; n++) ...[
        if (n > 1) const SizedBox(width: 8),
        Expanded(
          child: Tap(onTap: () => onPick(n), scale: .95, child: _tile(n, value == n)),
        ),
      ],
    ],
  );

  Widget _tile(int n, bool on) {
    final heat = n == 3 ? BoltColors.neon : BoltColors.warn;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: 96,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: on ? heat : BoltColors.surface2,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: on ? heat : BoltColors.line),
        boxShadow: on ? [BoxShadow(color: heat.withAlpha(0x4D), blurRadius: 18)] : const [],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // The glow: wide for very sore, small for a bit, none when fresh.
          if (n < 3)
            Container(
              width: n == 1 ? 84 : 46,
              height: n == 1 ? 84 : 46,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [(on ? BoltColors.onNeon : heat).withAlpha(0x59), heat.withAlpha(0)]),
              ),
            ),
          Text(
            tx(answers[n - 1]),
            textAlign: TextAlign.center,
            style: BoltText.a(14, weight: 800, color: on ? BoltColors.onNeon : BoltColors.text),
          ),
        ],
      ),
    );
  }
}

/// The sore parts as a grid of tiles: tap to mark, tap again to clear.
class _BodyParts extends StatelessWidget {
  const _BodyParts({required this.on, required this.onTap});

  final Set<String> on;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (var row = 0; row < 2; row++) ...[
        if (row > 0) const SizedBox(height: 8),
        Row(
          children: [
            for (var col = 0; col < 3; col++) ...[
              if (col > 0) const SizedBox(width: 8),
              Expanded(child: _part(kSoreGroups[row * 3 + col])),
            ],
          ],
        ),
      ],
    ],
  );

  Widget _part(String g) {
    final sel = on.contains(g);
    return Tap(
      onTap: () => onTap(g),
      scale: .94,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 62,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: sel ? BoltColors.warn : BoltColors.surface2,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: sel ? BoltColors.warn : BoltColors.line),
          boxShadow: sel ? [BoxShadow(color: BoltColors.warn.withAlpha(0x4D), blurRadius: 14)] : const [],
        ),
        child: Text(
          tx(_soreNames[g]!),
          style: BoltText.a(14, weight: 800, color: sel ? BoltColors.onNeon : BoltColors.text),
        ),
      ),
    );
  }
}

/// The selected or open look of an answer.
BoxDecoration _pick(bool on, double radius) => BoxDecoration(
  color: on ? BoltColors.neon : BoltColors.surface2,
  borderRadius: BorderRadius.circular(radius),
  border: Border.all(color: on ? BoltColors.neon : BoltColors.line),
  boxShadow: on ? [BoxShadow(color: BoltColors.glow(0x59), blurRadius: 18, spreadRadius: -4)] : const [],
);

/// Sleep hours, half an hour a step from 3 to 12: the hours big between −
/// and +, over a row of rising bars to tap or slide along.
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
      width: 48,
      height: 48,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: BoltColors.surface2,
        shape: BoxShape.circle,
        border: Border.all(color: BoltColors.line),
      ),
      child: Text(l, style: BoltText.a(22, weight: 700)),
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
            _key('−', -1),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(_hours(value), style: BoltText.display(60, color: BoltColors.neon, height: 1)),
                  const SizedBox(width: 4),
                  Text('h', style: BoltText.m(16, weight: 700, color: BoltColors.muted)),
                ],
              ),
            ),
            _key('+', 1),
          ],
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, box) {
            void at(double x) => onChanged(_min + (x / box.maxWidth * n).floor().clamp(0, n - 1));
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (d) => at(d.localPosition.dx),
              onHorizontalDragStart: (d) => at(d.localPosition.dx),
              onHorizontalDragUpdate: (d) => at(d.localPosition.dx),
              child: SizedBox(
                height: 34,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (var i = 0; i < n; i++)
                      Expanded(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 160),
                          margin: const EdgeInsets.symmetric(horizontal: 1.5),
                          height: 8 + 26 * i / (n - 1),
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
                  decoration: BoxDecoration(color: BoltColors.surface2, borderRadius: BorderRadius.circular(5)),
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
