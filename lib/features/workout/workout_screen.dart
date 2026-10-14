import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/actions.dart';
import '../../core/format.dart';
import '../../data/bolt_store.dart';
import '../../data/models/bolt_data.dart';
import '../../data/models/exercise.dart';
import '../../data/models/people.dart';
import '../../data/rules.dart';
import '../../data/seed/learn.dart';
import '../../data/seed/templates.dart';
import '../../theme/text_styles.dart';
import '../../theme/tokens.dart';
import '../../widgets/box.dart';
import '../../widgets/common.dart';
import '../../widgets/exercise_rows.dart';
import '../../widgets/motion.dart';
import '../../widgets/tap.dart';
import '../plan/day_sheet.dart';

class WorkoutScreen extends ConsumerStatefulWidget {
  const WorkoutScreen({super.key, required this.dayKey});

  final String dayKey;

  @override
  ConsumerState<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends ConsumerState<WorkoutScreen> {
  DateTime? _restEnd;
  int _restTotal = 90;
  Timer? _ticker;

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _startRest() {
    final secs = ref.read(boltProvider).settings.restSecs;
    setState(() {
      _restTotal = secs;
      _restEnd = DateTime.now().add(Duration(seconds: secs));
    });
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (!mounted || _restEnd == null) return;
      if (!DateTime.now().isBefore(_restEnd!)) {
        _ticker?.cancel();
        HapticFeedback.vibrate();
        setState(() => _restEnd = null);
      } else {
        setState(() {});
      }
    });
  }

  void _restAdd(int s) {
    if (_restEnd == null) return;
    setState(() {
      _restEnd = _restEnd!.add(Duration(seconds: s));
      _restTotal = math.max(1, _restTotal + s);
    });
  }

  void _skip() {
    _ticker?.cancel();
    setState(() => _restEnd = null);
  }

  void _finish() {
    final unlocked = ref.read(boltProvider.notifier).finish();
    _ticker?.cancel();
    context.go('/today');
    showUnlocks(unlocked);
  }

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(boltProvider);
    final store = ref.read(boltProvider.notifier);
    final t = store.trOrNull(d.account?.id ?? '');
    final s = t == null ? null : store.plan(t.id)[widget.dayKey];
    final w = d.workout;
    if (t == null || s == null || w == null || w.key != widget.dayKey) {
      return const BoltPage(child: SizedBox.expand());
    }
    final coach = store.co(t.coach);
    var tot = 0, done = 0;
    for (final e in s.ex) {
      for (var i = 0; i < e.sets; i++) {
        tot++;
        if (w.isDone(e.id, i)) done++;
      }
    }
    final insets = MediaQuery.paddingOf(context);
    final restLeft = _restEnd == null
        ? 0
        : math.max(0, (_restEnd!.difference(DateTime.now()).inMilliseconds / 1000).ceil());

    return BoltPage(
      child: Stack(
        children: [
          SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(20, insets.top + 16, 20, 130 + insets.bottom),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    BackBox(onTap: () => context.pop()),
                    const SizedBox(width: 12),
                    Kicker('SESSION · ${fmtDay(widget.dayKey).toUpperCase()}'),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  s.title.toUpperCase(),
                  style: BoltText.a(
                    tsz(s.title, 52),
                    weight: 900,
                    width: 115,
                    spacing: -.03,
                    height: .95,
                    color: BoltColors.neon,
                  ),
                ),
                const SizedBox(height: 6),
                Text(s.focus, style: BoltText.a(14, color: BoltColors.muted)),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: Container(
                          height: 8,
                          color: BoltColors.lineSoft,
                          alignment: Alignment.centerLeft,
                          child: AnimatedFractionallySizedBox(
                            duration: const Duration(milliseconds: 350),
                            curve: const Cubic(.2, .8, .2, 1),
                            widthFactor: tot == 0 ? 0 : done / tot,
                            heightFactor: 1,
                            child: const ColoredBox(color: BoltColors.neon),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text('$done / $tot SETS', style: BoltText.m(11, weight: 700)),
                  ],
                ),
                if (s.note.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  CoachNote(ini: initials(coach.name), note: s.note),
                ],
                const SizedBox(height: 16),
                for (var i = 0; i < s.ex.length; i++) ...[
                  if (i > 0) const SizedBox(height: 10),
                  _ExerciseCard(
                    index: i,
                    e: s.ex[i],
                    trainee: t,
                    workout: w,
                    load: store.unit(s.ex[i].load),
                    onSet: (j) {
                      if (store.toggleSet(s.ex[i].id, j)) _startRest();
                    },
                  ),
                ],
                const SizedBox(height: 18),
                NeonButton(
                  label: done == tot && tot > 0 ? 'Finish workout' : 'Finish workout · $done/$tot',
                  onTap: _finish,
                ),
              ],
            ),
          ),
          if (_restEnd != null)
            Positioned(
              left: 14,
              right: 14,
              bottom: 16 + insets.bottom,
              child: FadeSlideIn(
                duration: const Duration(milliseconds: 300),
                child: _RestBar(
                  time: '${restLeft ~/ 60}:${pad(restLeft % 60)}',
                  pct: restLeft / _restTotal,
                  onMinus: () => _restAdd(-15),
                  onPlus: () => _restAdd(15),
                  onSkip: _skip,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ExerciseCard extends ConsumerWidget {
  const _ExerciseCard({
    required this.index,
    required this.e,
    required this.trainee,
    required this.workout,
    required this.load,
    required this.onSet,
  });

  final int index;
  final Exercise e;
  final Trainee trainee;
  final ActiveWorkout workout;
  final String load;
  final ValueChanged<int> onSet;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final all = e.sets > 0 && List.generate(e.sets, (j) => workout.isDone(e.id, j)).every((x) => x);
    final f = isFlagged(trainee, e);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: BoltColors.surface1,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: all ? const Color(0x8CC6FF1A) : BoltColors.lineSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                pad(index + 1),
                style: BoltText.m(12, weight: 700, color: all ? BoltColors.neon : BoltColors.muted4),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(e.name, style: BoltText.a(16, weight: 800))),
              if (kHow.containsKey(e.name)) ...[
                const SizedBox(width: 10),
                Tap(
                  onTap: () => showExerciseSheet(e.name),
                  child: BoltBox(
                    width: 28,
                    height: 28,
                    circle: true,
                    stroke: const Stroke(BoltColors.line),
                    alignment: Alignment.center,
                    child: Text('i', style: BoltText.a(13, weight: 800, color: BoltColors.neon, height: 1)),
                  ),
                ),
              ],
              const SizedBox(width: 10),
              Text(load, style: BoltText.m(12, color: BoltColors.muted)),
            ],
          ),
          if (f) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${kAreas[e.area]} flag · coach suggests ${e.alt ?? 'a lighter variation'}',
                    style: BoltText.a(12, color: BoltColors.warn),
                  ),
                ),
                if (e.alt != null) ...[
                  const SizedBox(width: 8),
                  SwapButton(
                    onTap: () => ref.read(boltProvider.notifier).swap(e),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  ),
                ],
              ],
            ),
          ],
          if (e.swapped) ...[
            const SizedBox(height: 6),
            Text('Swapped from ${e.orig}', style: BoltText.m(10, color: BoltColors.muted)),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (var j = 0; j < e.sets; j++)
                _SetButton(n: j + 1, reps: e.reps, done: workout.isDone(e.id, j), onTap: () => onSet(j)),
            ],
          ),
        ],
      ),
    );
  }
}

class _SetButton extends StatelessWidget {
  const _SetButton({required this.n, required this.reps, required this.done, required this.onTap});

  final int n;
  final String reps;
  final bool done;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = done ? BoltColors.ink : BoltColors.text;
    return Tap(
      onTap: onTap,
      scale: .94,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        constraints: const BoxConstraints(minWidth: 64),
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: done ? BoltColors.neon : BoltColors.surface2,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: done ? BoltColors.neon : BoltColors.line),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('SET $n', style: BoltText.m(8, spacing: .1, color: fg.withValues(alpha: .75), height: 1.2)),
            Text(reps, style: BoltText.a(14, weight: 800, color: fg, height: 1.25)),
          ],
        ),
      ),
    );
  }
}

class _RestBar extends StatelessWidget {
  const _RestBar({
    required this.time,
    required this.pct,
    required this.onMinus,
    required this.onPlus,
    required this.onSkip,
  });

  final String time;
  final double pct;
  final VoidCallback onMinus;
  final VoidCallback onPlus;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    Widget step(String l, VoidCallback f) => Tap(
      onTap: f,
      child: BoltBox(
        width: 44,
        height: 44,
        radius: 12,
        stroke: const Stroke(BoltColors.ink, 1.5),
        alignment: Alignment.center,
        child: Text(l, style: BoltText.m(12, weight: 700, color: BoltColors.ink)),
      ),
    );
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: BoltColors.text,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Color(0x99000000), blurRadius: 34, offset: Offset(0, 12))],
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'REST',
                        style: BoltText.m(10, weight: 700, spacing: .12, color: BoltColors.ink.withValues(alpha: .6)),
                      ),
                      Text(time, style: BoltText.m(28, weight: 700, color: BoltColors.ink, height: 1)),
                    ],
                  ),
                ),
                step('−15', onMinus),
                const SizedBox(width: 10),
                step('+15', onPlus),
                const SizedBox(width: 10),
                Tap(
                  onTap: onSkip,
                  child: BoltBox(
                    height: 44,
                    radius: 12,
                    color: BoltColors.ink,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    alignment: Alignment.center,
                    child: Text('Skip', style: BoltText.a(13, weight: 800, color: BoltColors.neon)),
                  ),
                ),
              ],
            ),
          ),
          Positioned.fill(
            child: Align(
              alignment: Alignment.bottomLeft,
              child: AnimatedFractionallySizedBox(
                duration: const Duration(milliseconds: 500),
                widthFactor: pct.clamp(0.0, 1.0),
                child: Container(height: 4, color: BoltColors.ink),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
