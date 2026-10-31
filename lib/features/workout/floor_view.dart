import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/actions.dart';
import '../../core/format.dart';
import '../../core/units.dart';
import '../../data/lifts.dart';
import '../../data/models/bolt_data.dart';
import '../../data/models/exercise.dart';
import '../../data/plates.dart';
import '../../data/seed/learn.dart';
import '../../services/haptics.dart';
import '../../services/screen.dart';
import '../../theme/text_styles.dart';
import '../../theme/tokens.dart';
import '../../widgets/box.dart';
import '../../widgets/common.dart';
import '../../widgets/fields.dart';
import '../../widgets/plate_bar.dart';
import '../../widgets/tap.dart';
import 'lifeline.dart';

/// The order sets are done in: an exercise set by set, a superset round by
/// round (A1, B1, A2, B2).
List<(int, int)> setFlow(List<Exercise> ex) {
  final out = <(int, int)>[];
  var i = 0;
  while (i < ex.length) {
    var k = i;
    while (ex[i].group != null && k + 1 < ex.length && ex[k + 1].group == ex[i].group) {
      k++;
    }
    final rounds = ex.sublist(i, k + 1).fold(0, (a, e) => math.max(a, e.sets));
    for (var j = 0; j < rounds; j++) {
      for (var x = i; x <= k; x++) {
        if (j < ex[x].sets) out.add((x, j));
      }
    }
    i = k + 1;
  }
  return out;
}

/// "80×5 · 80×5 · 77.5×4 kg", or "12 · 10 · 9" for bodyweight.
String setsText(List<SetLog> sets, {required bool metric}) {
  final kg = sets.any((s) => s.kg != null);
  final body = sets
      .map((s) => [if (s.kg != null) weightValue(s.kg, metric: metric), s.reps?.toString() ?? '-'].join('×'))
      .join(' · ');
  return kg ? '$body ${weightUnit(metric)}' : body;
}

/// Gym floor mode: one set at a time with big weight and reps steppers that
/// start from last time, a large rest ring and one big button. Timed sets
/// (planks, intervals) count down instead.
class FloorView extends StatefulWidget {
  const FloorView({
    super.key,
    required this.ex,
    required this.workout,
    required this.metric,
    required this.warmup,
    required this.ramp,
    required this.prefill,
    required this.hint,
    required this.canSwap,
    required this.onSwap,
    required this.restEnd,
    required this.restTotal,
    required this.restNext,
    required this.onLog,
    required this.onRestAdd,
    required this.onSkip,
    required this.onFinish,
    required this.onWork,
    required this.header,
    required this.onDiscard,
    required this.volumeLog,
  });

  final List<Exercise> ex;
  final ActiveWorkout workout;
  final bool metric;

  /// Volume down does the big button's job.
  final bool volumeLog;

  /// Shown before the first set: minutes and steps of the warm-up, and the
  /// ramp-up sets of the first big lift.
  final (int, List<String>) warmup;
  final List<SetLog> ramp;

  /// What set j of exercise i starts from.
  final SetLog Function(int i, int j) prefill;
  final LiftHint? Function(int i) hint;

  /// Swap exercise i for another that trains the same muscle, for when the
  /// rack or the machine is taken. Only while it has no ticked sets and
  /// there is something to swap it for.
  final bool Function(int i) canSwap;
  final void Function(int i) onSwap;
  final DateTime? restEnd;
  final int restTotal;
  final String restNext;

  /// Ticks set j of exercise i with [SetLog], or updates it when done.
  final void Function(int i, int j, SetLog log) onLog;
  final ValueChanged<int> onRestAdd;
  final VoidCallback onSkip;
  final VoidCallback onFinish;

  /// A timed set started (its end and title) or stopped (null).
  final void Function(DateTime? end, int total, String title) onWork;

  /// Back button, mode switch and progress, shared with the list.
  final Widget header;

  /// Throws the workout away, after asking.
  final VoidCallback onDiscard;

  @override
  State<FloorView> createState() => _FloorViewState();
}

class _FloorViewState extends State<FloorView> {
  (int, int)? _at;
  double? _kg;
  int? _reps;

  DateTime? _workEnd;
  int _workTotal = 0;
  Timer? _work;

  /// Nothing done yet: the warm-up comes first, until "Warm-up done".
  late bool _warming = !widget.workout.done.values.any((d) => d.contains(true));

  /// The set is showing during a rest instead of the dark rest screen.
  bool _peek = false;

  @override
  void initState() {
    super.initState();
    _go(_nextUndone(null));
    if (widget.volumeLog) Screen.volumeKey(_press);
  }

  @override
  void didUpdateWidget(FloorView old) {
    super.didUpdateWidget(old);
    if (old.restEnd == null && widget.restEnd != null) _peek = false;
    if (old.volumeLog != widget.volumeLog) Screen.volumeKey(widget.volumeLog ? _press : null);
  }

  @override
  void dispose() {
    _work?.cancel();
    if (widget.volumeLog) Screen.volumeKey(null);
    super.dispose();
  }

  /// The big button's job, from volume down: warm-up done, start or end a
  /// timed set, or log the set. Never under a sheet or a moment, and never
  /// on a set already done.
  void _press() {
    final at = _at;
    if (!mounted || at == null || !(ModalRoute.of(context)?.isCurrent ?? false)) return;
    final (i, j) = at;
    final secs = targetSecs(widget.ex[i].repsFor(j));
    if (_warming) {
      _endWarmUp();
    } else if (_workEnd != null) {
      _stopWork(log: true);
    } else if (_done(i, j)) {
      return;
    } else if (secs != null) {
      _startWork(secs);
    } else {
      _log();
    }
  }

  void _endWarmUp() {
    Haptics.play(Feel.tap);
    setState(() => _warming = false);
  }

  bool _done(int i, int j) => widget.workout.isDone(widget.ex[i].id, j);

  /// The first set still to do after [from] in [setFlow], then from the top.
  (int, int)? _nextUndone((int, int)? from) {
    final flow = setFlow(widget.ex);
    final start = from == null ? 0 : flow.indexOf(from) + 1;
    for (var n = 0; n < flow.length; n++) {
      final x = flow[(start + n) % flow.length];
      if (!_done(x.$1, x.$2)) return x;
    }
    return from ?? (flow.isEmpty ? null : flow.first);
  }

  /// Moves to set [at] and loads its numbers: the logged ones when it is
  /// done, otherwise where it starts from.
  void _go((int, int)? at) {
    _at = at;
    if (at == null) return;
    final (i, j) = at;
    final e = widget.ex[i];
    final log = widget.workout.log(e.id, j) ?? widget.prefill(i, j);
    _kg = log.kg;
    _reps = log.reps;
    // A max set starts from last time's best effort, to beat it.
    if (_reps == null && isMax(e.repsFor(j))) {
      final last = widget.hint(i)?.last.sets;
      _reps = last == null || last.isEmpty ? null : last[math.min(j, last.length - 1)].reps;
    }
  }

  void _select((int, int) at) {
    if (_workEnd != null) return;
    Haptics.play(Feel.tick);
    setState(() => _go(at));
  }

  /// Jumps to the previous or next exercise, at its first set still to do.
  void _exercise(int dir) {
    final (i, _) = _at!;
    final n = i + dir;
    if (n < 0 || n >= widget.ex.length) return;
    final sets = widget.ex[n].sets;
    var j = 0;
    while (j < sets - 1 && _done(n, j)) {
      j++;
    }
    _select((n, j));
  }

  void _stepKg(int dir) {
    final next = stepWeight(_kg, dir, metric: widget.metric);
    if (next == _kg) return;
    final shown = double.tryParse(weightValue(next, metric: widget.metric)) ?? 0;
    // Every 10 kg (or 25 lb) lands with a firmer notch, like a detent.
    Haptics.play(shown > 0 && shown % (widget.metric ? 10 : 25) == 0 ? Feel.detent : Feel.tick);
    setState(() => _kg = next);
  }

  void _stepReps(int dir) {
    final next = math.max(0, (_reps ?? 0) + dir);
    if (next == (_reps ?? 0)) return;
    Haptics.play(next % 5 == 0 ? Feel.detent : Feel.tick);
    setState(() => _reps = next == 0 ? null : next);
  }

  void _log() {
    final (i, j) = _at!;
    final wasDone = _done(i, j);
    widget.onLog(i, j, SetLog(kg: _kg, reps: _reps, rir: widget.workout.log(widget.ex[i].id, j)?.rir));
    if (!wasDone) setState(() => _go(_nextUndone(_at)));
  }

  void _startWork(int secs) {
    final (i, j) = _at!;
    Haptics.play(Feel.tap);
    final end = DateTime.now().add(Duration(seconds: secs));
    setState(() {
      _workEnd = end;
      _workTotal = secs;
    });
    widget.onWork(end, secs, tx('{name} · set {n}', {'name': tx(widget.ex[i].name), 'n': j + 1}));
    _work?.cancel();
    _work = Timer(Duration(seconds: secs), () {
      if (!mounted) return;
      _stopWork(log: true);
    });
  }

  /// Ends a timed set, logged unless it was cancelled. A logged one hands
  /// its countdown over to the rest that follows.
  void _stopWork({required bool log}) {
    _work?.cancel();
    setState(() => _workEnd = null);
    if (log) {
      _log();
    } else {
      widget.onWork(null, 0, '');
    }
  }

  Future<void> _type(String label, String value, String? unit, ValueChanged<String> onSave) async {
    final v = await askText(
      context,
      title: label,
      hint: label,
      save: tx('Save'),
      initial: value,
      suffix: unit,
      number: true,
    );
    if (v != null && mounted) onSave(v);
  }

  /// The warm-up before the first set, then one tap on to set 1.
  Widget _warmUp() {
    final (mins, steps) = widget.warmup;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BoltBox(
          color: BoltColors.surface1,
          stroke: const Stroke(BoltColors.lineSoft),
          radius: 24,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Kicker(tx('WARM-UP · ~{n} MIN', {'n': mins}), size: 11, weight: 700, color: BoltColors.neon),
              for (final step in steps) ...[
                const SizedBox(height: 10),
                Text(step, style: BoltText.a(14, weight: 600, height: 1.35)),
              ],
              if (widget.ramp.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  '${widget.ramp.map((x) => '${weightValue(x.kg, metric: widget.metric)}×${x.reps}').join('  ·  ')} '
                  '${weightUnit(widget.metric)}',
                  style: BoltText.m(13, weight: 700, color: BoltColors.neon),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// The plates for [kg] under the weight, live as it steps. Tap for the
  /// full calculator.
  Widget _plates(double kg) {
    final plates = widget.metric ? kPlatesKg : kPlatesLb;
    final total = widget.metric ? kg : kg * 2.20462;
    final r = platesFor(total, plates.first == 25 ? 20 : 45, plates);
    if (r.left < 0) return const SizedBox.shrink();
    return Tap(
      onTap: () => context.push('/plates?kg=$kg'),
      child: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Column(
          children: [
            PlateBar(side: r.side, plates: plates, height: 56),
            const SizedBox(height: 4),
            Text(
              r.side.isEmpty
                  ? tx('Just the bar')
                  : tx('Each side: {plates}', {'plates': '${sideText(r.side)} ${weightUnit(widget.metric)}'}),
              style: BoltText.m(11, weight: 700, color: BoltColors.textSoft),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final at = _at;
    final metric = widget.metric;
    final unit = weightUnit(metric);
    final insets = MediaQuery.paddingOf(context);
    var tot = 0, doneCount = 0;
    for (final e in widget.ex) {
      for (var j = 0; j < e.sets; j++) {
        tot++;
        if (widget.workout.isDone(e.id, j)) doneCount++;
      }
    }
    final all = tot > 0 && doneCount == tot;
    final flow = setFlow(widget.ex);
    SetLog? logAt(int i, int j) => widget.workout.log(widget.ex[i].id, j);
    double work(SetLog? l) => (l?.kg ?? 0) * (l?.reps ?? 1);
    final heaviest = flow.fold(0.0, (a, x) => math.max(a, work(logAt(x.$1, x.$2))));
    final beats = <double?>[
      for (final (i, j) in flow)
        if (!_done(i, j)) null else if (heaviest == 0 || logAt(i, j)?.kg == null) .6 else work(logAt(i, j)) / heaviest,
    ];

    Widget body;
    if (at == null) {
      body = const SizedBox.shrink();
    } else if (_warming) {
      body = _warmUp();
    } else {
      final (i, j) = at;
      final e = widget.ex[i];
      final h = widget.hint(i);
      final secs = targetSecs(e.repsFor(j));
      final distance = secs == null && targetReps(e.repsFor(j)) == null && !isMax(e.repsFor(j));
      final done = _done(i, j);
      final tags = [
        tx('EXERCISE {n} OF {total}', {'n': i + 1, 'total': widget.ex.length}),
        if (e.group != null) tx('SUPERSET {g}', {'g': e.group}),
      ];
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Kicker(tags.join(' · '), size: 10, color: e.group != null ? BoltColors.neon : BoltColors.muted),
          const SizedBox(height: 6),
          Row(
            children: [
              SquareButton(onTap: () => _exercise(-1), icon: 'back', size: 40),
              const SizedBox(width: 10),
              Expanded(
                child: Tap(
                  onTap: kHow.containsKey(e.name) ? () => showExerciseSheet(e.name) : null,
                  child: Text(tx(e.name), textAlign: TextAlign.center, style: BoltText.a(24, weight: 900, height: 1.1)),
                ),
              ),
              const SizedBox(width: 10),
              SquareButton(onTap: () => _exercise(1), icon: 'chevron', size: 40),
            ],
          ),
          if (widget.canSwap(i)) ...[
            const SizedBox(height: 8),
            Center(
              child: Tap(
                onTap: () => widget.onSwap(i),
                child: BoltBox(
                  radius: BoltRadii.pill,
                  stroke: const Stroke(BoltColors.line),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const BoltIcon('swap', size: 15, color: BoltColors.neon),
                      const SizedBox(width: 7),
                      Text(tx('Swap exercise'), style: BoltText.a(13, weight: 700, color: BoltColors.textSoft)),
                    ],
                  ),
                ),
              ),
            ),
          ],
          if (h != null) ...[
            const SizedBox(height: 8),
            Text(
              tx('Last {day}: {sets}', {'day': fmtDay(h.last.date), 'sets': setsText(h.last.sets, metric: metric)}),
              textAlign: TextAlign.center,
              style: BoltText.a(12, weight: 600, color: BoltColors.muted),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var k = 0; k < e.sets; k++)
                Tap(
                  onTap: () => _select((i, k)),
                  scale: .92,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _done(i, k) ? BoltColors.neon : BoltColors.surface2,
                      border: Border.all(
                        color: k == j ? BoltColors.neon : (_done(i, k) ? BoltColors.neon : BoltColors.line),
                        width: k == j ? 2.5 : 1,
                      ),
                    ),
                    child: Text(
                      '${k + 1}',
                      style: BoltText.m(14, weight: 700, color: _done(i, k) ? BoltColors.ink : BoltColors.text),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          BoltBox(
            color: BoltColors.surface1,
            stroke: Stroke(done ? const Color(0x8CC6FF1A) : BoltColors.lineSoft),
            radius: 24,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Kicker(
                        tx('SET {n} OF {total}', {'n': j + 1, 'total': e.sets}),
                        size: 11,
                        weight: 700,
                        color: BoltColors.neon,
                      ),
                    ),
                    Kicker(
                      tx('TARGET {reps}', {
                        'reps': (isMax(e.repsFor(j)) ? tx('Max reps') : e.repsFor(j)).toUpperCase(),
                      }),
                      size: 10,
                    ),
                  ],
                ),
                if (h != null && h.up && h.nextKg != null && _kg != h.nextKg) ...[
                  const SizedBox(height: 10),
                  Center(
                    child: Tap(
                      onTap: () {
                        Haptics.play(Feel.detent);
                        setState(() => _kg = h.nextKg);
                      },
                      child: BoltBox(
                        radius: 99,
                        stroke: const Stroke(BoltColors.neon, 1.5),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                        child: Text(
                          tx('Every rep hit last time · try {kg}', {
                            'kg': '${weightValue(h.nextKg, metric: metric)} $unit',
                          }),
                          style: BoltText.a(12, weight: 800, color: BoltColors.neon),
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                FloorStepper(
                  label: tx('WEIGHT'),
                  value: _kg == null ? tx('BW') : weightValue(_kg, metric: metric),
                  unit: _kg == null ? null : unit,
                  onStep: _stepKg,
                  onTapValue: () => _type(
                    tx('WEIGHT'),
                    weightValue(_kg, metric: metric),
                    unit,
                    (v) => setState(() => _kg = parseWeight(v, metric: metric)),
                  ),
                ),
                if (kBarbellLifts.contains(e.name) && _kg != null) _plates(_kg!),
                if (secs == null && !distance) ...[
                  const SizedBox(height: 14),
                  FloorStepper(
                    label: tx('REPS'),
                    value: _reps?.toString() ?? '-',
                    onStep: _stepReps,
                    onTapValue: () => _type(tx('REPS'), _reps?.toString() ?? '', null, (v) {
                      final n = int.tryParse(v.trim());
                      setState(() => _reps = n == null || n <= 0 ? null : n);
                    }),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (_workEnd != null)
            FloorRing(
              end: _workEnd!,
              total: _workTotal,
              label: tx('GO'),
              color: BoltColors.neon,
              actions: [
                Expanded(
                  child: OutlineButton(
                    label: tx('Cancel'),
                    height: 56,
                    color: BoltColors.text,
                    borderColor: BoltColors.line,
                    onTap: () => _stopWork(log: false),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: NeonButton(label: tx('Done'), height: 56, onTap: () => _stopWork(log: true)),
                ),
              ],
            )
          else if (secs != null && !done) ...[
            NeonButton(
              label: tx('Start {time}', {'time': clockSecs(secs)}),
              height: 68,
              fontSize: 18,
              onTap: () => _startWork(secs),
            ),
            const SizedBox(height: 4),
            Center(
              child: Tap(
                onTap: _log,
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Text(
                    tx('Done without the timer'),
                    style: BoltText.a(13, weight: 700, color: BoltColors.muted),
                  ),
                ),
              ),
            ),
          ] else
            NeonButton(
              label: done ? tx('Update set {n}', {'n': j + 1}) : tx('Done · set {n}', {'n': j + 1}),
              height: 68,
              fontSize: 18,
              color: done ? BoltColors.surface2 : BoltColors.neon,
              textColor: done ? BoltColors.neon : BoltColors.ink,
              onTap: _log,
            ),
        ],
      );
    }

    // When the workout should be over, at the pace so far.
    String? finish;
    final started = widget.workout.started;
    if (started != null && doneCount >= 2 && !all) {
      final now = DateTime.now();
      final perSet = (now.millisecondsSinceEpoch - started) / doneCount;
      finish = hm(now.add(Duration(milliseconds: (perSet * (tot - doneCount)).round())));
    }
    final lifeAt = at == null ? null : flow.indexOf(at);
    final resting = widget.restEnd != null && !_peek;

    // Under whichever button logs: the set's, or the warm-up's.
    final Widget volumeHint = widget.volumeLog && at != null && !all
        ? Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              tx('or press volume down'),
              textAlign: TextAlign.center,
              style: BoltText.m(11, color: BoltColors.muted3),
            ),
          )
        : const SizedBox.shrink();

    return Stack(
      children: [
        // The page is at least a screen tall and its two halves sit apart:
        // the set on top, the button for it low under the thumb, Finish and
        // Discard well clear of it.
        LayoutBuilder(
          builder: (context, box) {
            final padTop = insets.top + 16, padBottom = 40 + insets.bottom;
            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(20, padTop, 20, padBottom),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: math.max(0, box.maxHeight - padTop - padBottom)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        widget.header,
                        const SizedBox(height: 12),
                        Lifeline(beats: beats, at: lifeAt, restEnd: widget.restEnd, restTotal: widget.restTotal),
                        const SizedBox(height: 4),
                        Text(
                          [
                            '$doneCount / $tot ${tx('SETS')}',
                            if (finish != null) tx('DONE ~{time}', {'time': finish}),
                          ].join(' · '),
                          textAlign: TextAlign.right,
                          style: BoltText.m(11, weight: 700, color: BoltColors.muted),
                        ),
                        AnimatedSize(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOut,
                          alignment: Alignment.topCenter,
                          child: widget.restEnd == null || resting
                              ? const SizedBox(width: double.infinity, height: 16)
                              : Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 18),
                                  child: Column(
                                    children: [
                                      _ring(),
                                      if (widget.restNext.isNotEmpty) ...[
                                        const SizedBox(height: 12),
                                        Text(
                                          widget.restNext,
                                          textAlign: TextAlign.center,
                                          style: BoltText.a(13, weight: 700, color: BoltColors.muted),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                        ),
                        body,
                        if (!_warming) volumeHint,
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_warming && at != null) ...[
                          const SizedBox(height: 14),
                          NeonButton(label: tx('Warm-up done'), height: 68, fontSize: 18, onTap: _endWarmUp),
                        ],
                        if (_warming && at != null) volumeHint,
                        const SizedBox(height: 28),
                        if (all)
                          NeonButton(label: tx('Finish workout'), height: 60, onTap: widget.onFinish)
                        else
                          OutlineButton(
                            label: '${tx('Finish workout')} · $doneCount/$tot',
                            color: BoltColors.text,
                            borderColor: BoltColors.line,
                            weight: 700,
                            onTap: widget.onFinish,
                          ),
                        DiscardLink(onTap: widget.onDiscard),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        // Under the rest screen, which is dark to the top.
        const StatusScrim(),
        Positioned.fill(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            child: resting ? _restScreen(beats, lifeAt) : const SizedBox.shrink(),
          ),
        ),
      ],
    );
  }

  /// The rest countdown with −15, +15 and Skip.
  Widget _ring() => FloorRing(
    end: widget.restEnd!,
    total: widget.restTotal,
    label: tx('REST'),
    color: BoltColors.text,
    actions: [
      Expanded(
        child: _RestKey(label: '−15', onTap: () => widget.onRestAdd(-15)),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: _RestKey(label: '+15', onTap: () => widget.onRestAdd(15)),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: NeonButton(label: tx('Skip'), height: 56, onTap: widget.onSkip),
      ),
    ],
  );

  /// A rest, dark and calm: the lifeline, a big countdown and the next set
  /// with its weight, readable from a bench. A tap shows the set itself.
  Widget _restScreen(List<double?> beats, int? lifeAt) {
    final insets = MediaQuery.paddingOf(context);
    final next = _at;
    final e = next == null ? null : widget.ex[next.$1];
    return GestureDetector(
      key: const ValueKey('rest-screen'),
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _peek = true),
      child: ColoredBox(
        color: BoltColors.scannerBg,
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, insets.top + 20, 20, 16 + insets.bottom),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Lifeline(beats: beats, at: lifeAt, restEnd: widget.restEnd, restTotal: widget.restTotal),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _ring(),
                        if (next != null && e != null && !_done(next.$1, next.$2)) ...[
                          const SizedBox(height: 28),
                          Center(
                            child: Kicker(
                              tx('NEXT · SET {n} OF {total}', {'n': next.$2 + 1, 'total': e.sets}),
                              size: 10,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            tx(e.name),
                            textAlign: TextAlign.center,
                            style: BoltText.a(22, weight: 900, height: 1.1),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            [
                              if (_kg != null)
                                '${weightValue(_kg, metric: widget.metric)} ${weightUnit(widget.metric)}',
                              if (_reps != null) '× $_reps',
                            ].join(' '),
                            textAlign: TextAlign.center,
                            style: BoltText.a(30, weight: 900, color: BoltColors.neon),
                          ),
                          if (kBarbellLifts.contains(e.name) && _kg != null) _plates(_kg!),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              Text(
                tx('Tap to see the set'),
                textAlign: TextAlign.center,
                style: BoltText.m(11, color: BoltColors.muted3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Discard workout" under the Finish button, for a START pressed by
/// mistake.
class DiscardLink extends StatelessWidget {
  const DiscardLink({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Center(
    child: Tap(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(tx('Discard workout'), style: BoltText.a(13, weight: 700, color: BoltColors.muted)),
      ),
    ),
  );
}

class _RestKey extends StatelessWidget {
  const _RestKey({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tap(
    onTap: onTap,
    scale: .95,
    child: BoltBox(
      height: 56,
      radius: 16,
      stroke: const Stroke(BoltColors.line, 1.5),
      alignment: Alignment.center,
      child: Text(label, style: BoltText.m(16, weight: 700)),
    ),
  );
}

/// A big − value + row. Holding a button keeps stepping, faster after a
/// moment; tapping the number lets you type it.
class FloorStepper extends StatelessWidget {
  const FloorStepper({
    super.key,
    required this.label,
    required this.value,
    required this.onStep,
    required this.onTapValue,
    this.unit,
  });

  final String label;
  final String value;
  final String? unit;
  final ValueChanged<int> onStep;
  final VoidCallback onTapValue;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Kicker(label, size: 10),
        const SizedBox(height: 6),
        Row(
          children: [
            _StepKey(label: '−', onStep: () => onStep(-1)),
            Expanded(
              child: Tap(
                onTap: onTapValue,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          value,
                          style: BoltText.a(52, weight: 900, width: 110, height: 1, color: BoltColors.neon),
                        ),
                      ),
                    ),
                    if (unit != null) ...[
                      const SizedBox(width: 6),
                      Text(unit!, style: BoltText.m(14, weight: 700, color: BoltColors.muted)),
                    ],
                  ],
                ),
              ),
            ),
            _StepKey(label: '+', onStep: () => onStep(1)),
          ],
        ),
      ],
    );
  }
}

class _StepKey extends StatefulWidget {
  const _StepKey({required this.label, required this.onStep});

  final String label;
  final VoidCallback onStep;

  @override
  State<_StepKey> createState() => _StepKeyState();
}

class _StepKeyState extends State<_StepKey> {
  Timer? _repeat;
  int _count = 0;

  void _hold() {
    _count = 0;
    widget.onStep();
    _tick(const Duration(milliseconds: 260));
  }

  void _tick(Duration wait) {
    _repeat = Timer(wait, () {
      if (!mounted) return;
      widget.onStep();
      _count++;
      _tick(Duration(milliseconds: _count < 6 ? 140 : 70));
    });
  }

  void _release() {
    _repeat?.cancel();
    _repeat = null;
  }

  @override
  void dispose() {
    _repeat?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onStep,
        onLongPressStart: (_) => _hold(),
        onLongPressEnd: (_) => _release(),
        onLongPressCancel: _release,
        child: BoltBox(
          width: 64,
          height: 64,
          radius: 18,
          color: BoltColors.surface2,
          stroke: const Stroke(BoltColors.line, 1.5),
          alignment: Alignment.center,
          child: Text(widget.label, style: BoltText.a(30, weight: 700, height: 1)),
        ),
      ),
    );
  }
}

/// A big countdown ring to [end]: the rest between sets, or a timed set. It
/// animates on its own, so nothing else rebuilds while it runs.
class FloorRing extends StatefulWidget {
  const FloorRing({
    super.key,
    required this.end,
    required this.total,
    required this.label,
    required this.color,
    required this.actions,
  });

  final DateTime end;

  /// Full length in seconds.
  final int total;
  final String label;
  final Color color;
  final List<Widget> actions;

  @override
  State<FloorRing> createState() => _FloorRingState();
}

class _FloorRingState extends State<FloorRing> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this);

  @override
  void initState() {
    super.initState();
    _run();
  }

  @override
  void didUpdateWidget(FloorRing old) {
    super.didUpdateWidget(old);
    if (old.end != widget.end || old.total != widget.total) _run();
  }

  void _run() {
    final left = widget.end.difference(DateTime.now());
    _c.value = (left.inMilliseconds / (math.max(1, widget.total) * 1000)).clamp(0.0, 1.0);
    if (left > Duration.zero) _c.animateTo(0, duration: left);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: 220,
          height: 220,
          child: CustomPaint(
            painter: _RingPainter(_c, widget.color),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(widget.label, style: BoltText.m(11, weight: 700, spacing: .2, color: BoltColors.muted)),
                  const SizedBox(height: 4),
                  AnimatedBuilder(
                    animation: _c,
                    builder: (context, _) {
                      final ms = widget.end.difference(DateTime.now()).inMilliseconds;
                      return Text(
                        clockSecs(math.max(0, (ms / 1000).ceil())),
                        style: BoltText.m(60, weight: 700, height: 1, color: widget.color),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(children: widget.actions),
      ],
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.left, this.color) : super(repaint: left);

  final Animation<double> left;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const w = 10.0;
    final r = Rect.fromLTWH(w / 2, w / 2, size.width - w, size.height - w);
    canvas.drawArc(
      r,
      0,
      math.pi * 2,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w
        ..color = BoltColors.lineSoft,
    );
    canvas.drawArc(
      r,
      -math.pi / 2,
      math.pi * 2 * left.value,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w
        ..strokeCap = StrokeCap.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.color != color;
}
