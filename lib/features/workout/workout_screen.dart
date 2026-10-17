import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/actions.dart';
import '../../app/router.dart';
import '../../app/tick.dart';
import '../../core/format.dart';
import '../../core/units.dart';
import '../../data/bolt_store.dart';
import '../../data/lifts.dart';
import '../../data/models/bolt_data.dart';
import '../../data/models/exercise.dart';
import '../../data/models/people.dart';
import '../../data/rules.dart';
import '../../data/seed/learn.dart';
import '../../data/seed/templates.dart';
import '../../services/notifications.dart';
import '../../theme/text_styles.dart';
import '../../theme/tokens.dart';
import '../../widgets/bolt_sheet.dart';
import '../../widgets/box.dart';
import '../../widgets/common.dart';
import '../../widgets/exercise_rows.dart';
import '../../widgets/fields.dart';
import '../../widgets/forms.dart';
import '../../widgets/moment_overlay.dart';
import '../../widgets/motion.dart';
import '../../widgets/swap_sheet.dart';
import '../../widgets/tap.dart';
import '../plan/day_sheet.dart';
import '../today/today_screen.dart' show clockText;

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

  late final BoltNotifications _notify = ref.read(notificationsProvider);
  String _restNext = '';

  /// Lifts that already had their record moment in this workout.
  final _celebrated = <String>{};

  /// Already ahead of the last session, so the buzz played.
  bool _passed = false;

  /// One strong buzz the moment this workout overtakes the last one.
  void _checkRace() {
    if (_passed) return;
    final d = ref.read(boltProvider);
    final store = ref.read(boltProvider.notifier);
    final plan = store.plan(d.account!.id);
    final s = plan[widget.dayKey];
    final w = d.workout;
    final k = s == null ? null : lastSame(plan, s, widget.dayKey);
    if (s == null || w == null || k == null) return;
    final (done, target, _) = race(_work(w), workOf(plan[k]!.ex.expand((e) => e.logged)));
    if (target > 0 && done > target) {
      _passed = true;
      HapticFeedback.heavyImpact();
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _notify.clearRest();
    super.dispose();
  }

  /// Rest after a set; [next] says what comes after it, on the lock screen.
  void _startRest(String next, int secs) {
    setState(() {
      _restTotal = secs;
      _restEnd = DateTime.now().add(Duration(seconds: secs));
      _restNext = next;
    });
    _notify.showRest(_restEnd!, next);
    _armRest();
  }

  /// One timer for the end of the rest. The bar counts down on its own, so
  /// the screen does not rebuild while you rest.
  void _armRest() {
    _ticker?.cancel();
    _ticker = Timer(_restEnd!.difference(DateTime.now()), () {
      if (!mounted) return;
      HapticFeedback.vibrate();
      _notify.clearRest();
      setState(() => _restEnd = null);
    });
  }

  void _restAdd(int s) {
    if (_restEnd == null) return;
    setState(() {
      _restEnd = _restEnd!.add(Duration(seconds: s));
      _restTotal = math.max(1, _restTotal + s);
    });
    _notify.showRest(_restEnd!, _restNext);
    _armRest();
  }

  void _skip() {
    _ticker?.cancel();
    _notify.clearRest();
    setState(() => _restEnd = null);
  }

  /// What comes after set [j] of exercise [i]: its next set, or the next
  /// exercise.
  String _nextAfter(List<Exercise> ex, int i, int j, ActiveWorkout w) {
    final e = ex[i];
    for (var k = 0; k < e.sets; k++) {
      if (k != j && !w.isDone(e.id, k)) return tx('{name} · set {n}', {'name': tx(e.name), 'n': k + 1});
    }
    return i + 1 < ex.length
        ? tx('Next: {what}', {'what': tx(ex[i + 1].name)})
        : tx('Last set done. Finish the workout.');
  }

  /// Ticks set [j] with the weight and reps last used in this workout, or
  /// the suggestion, or the plan. Rest starts unless the superset partner
  /// comes next.
  void _tick(List<Exercise> ex, int i, int j, ActiveWorkout w, LiftHint? hint, double? pctKg) {
    final e = ex[i];
    final store = ref.read(boltProvider.notifier);
    final st = ref.read(boltProvider).settings;
    if (w.isDone(e.id, j)) {
      showBoltSheet<void>(context, (_) => _SetSheet(e: e, set: j, onSaved: (log) => _celebrate(e, log)));
      return;
    }
    SetLog? prev;
    for (var k = j - 1; k >= 0 && prev == null; k--) {
      prev = w.log(e.id, k);
    }
    // A set with its own plan (70, 75, 80 kg) starts from that plan.
    final t = ref.read(boltProvider.notifier).tr(ref.read(boltProvider).account!.id);
    final own = setKg(t, ref.read(boltProvider.notifier).plan(t.id), e, j);
    final ownReps = e.ownReps(j) == null ? null : targetReps(e.ownReps(j)!);
    // A max set has no rep count to fill in: the sheet asks what you got.
    final max = isMax(e.repsFor(j));
    final log = SetLog(
      kg: own ?? prev?.kg ?? pctKg ?? hint?.nextKg ?? loadKg(e.load),
      reps: max ? null : ownReps ?? prev?.reps ?? targetReps(e.reps),
    );
    store.logSet(e.id, j, log);
    HapticFeedback.lightImpact();
    _checkRace();
    final partnerNext = e.group != null && i + 1 < ex.length && ex[i + 1].group == e.group;
    if (!partnerNext) _startRest(_nextAfter(ex, i, j, w), restFor(e, auto: st.restAuto, fixed: st.restSecs));
    if (max) {
      showBoltSheet<void>(context, (_) => _SetSheet(e: e, set: j, onSaved: (log) => _celebrate(e, log)));
    } else {
      _celebrate(e, log);
    }
  }

  /// A record set gets its moment, once per lift and workout.
  void _celebrate(Exercise e, SetLog log) {
    _checkRace();
    if (_celebrated.contains(e.name)) return;
    final store = ref.read(boltProvider.notifier);
    final pr = livePr(store.plan(ref.read(boltProvider).account!.id), e.name, widget.dayKey, log);
    if (pr == null) return;
    _celebrated.add(e.name);
    final metric = ref.read(boltProvider).settings.kg;
    final unit = weightUnit(metric);
    Navigator.of(context).push(
      MomentRoute(
        Moment(
          kicker: tx('NEW PR'),
          big: weightValue(pr.now, metric: metric),
          unit: pr.heavier ? unit.toUpperCase() : '${unit.toUpperCase()} · ${tx('EST. MAX')}',
          was: '${weightValue(pr.was, metric: metric)} $unit',
          title: tx(e.name),
          sub: pr.heavier
              ? tx('The heaviest you have ever lifted on it.')
              : tx('Your best set ever on it, by estimated max.'),
        ),
      ),
    );
  }

  void _finish() {
    HapticFeedback.mediumImpact();
    final unlocked = ref.read(boltProvider.notifier).finish();
    _ticker?.cancel();
    _notify.clearRest();
    context.go('/today');
    rootNavigatorKey.currentContext?.push('/summary/${widget.dayKey}');
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
    final coachName = store.coachNameOf(t);
    var tot = 0, done = 0;
    for (final e in s.ex) {
      for (var i = 0; i < e.sets; i++) {
        tot++;
        if (w.isDone(e.id, i)) done++;
      }
    }
    final insets = MediaQuery.paddingOf(context);
    final lastK = lastSame(store.plan(t.id), s, widget.dayKey);

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
                    Expanded(child: Kicker(tx('SESSION · {day}', {'day': fmtDay(widget.dayKey).toUpperCase()}))),
                    if (w.started != null) _Elapsed(started: w.started!),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  tx(s.title).toUpperCase(),
                  style: BoltText.a(
                    tsz(tx(s.title), 52),
                    weight: 900,
                    width: 115,
                    spacing: -.03,
                    height: .95,
                    color: BoltColors.neon,
                  ),
                ),
                const SizedBox(height: 6),
                Text(tx(s.focus), style: BoltText.a(14, color: BoltColors.muted)),
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
                    Text('$done / $tot ${tx('SETS')}', style: BoltText.m(11, weight: 700)),
                  ],
                ),
                if (lastK != null) ...[
                  const SizedBox(height: 10),
                  _Race(
                    day: lastK,
                    now: _work(w),
                    last: workOf(store.plan(t.id)[lastK]!.ex.expand((e) => e.logged)),
                    metric: d.settings.kg,
                  ),
                ],
                if (s.note.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  CoachNote(ini: initials(s.byCoach ? (coachName ?? tx('Coach')) : t.name), note: tx(s.note)),
                ],
                const SizedBox(height: 16),
                for (var i = 0; i < s.ex.length; i++) ...[
                  if (i > 0) const SizedBox(height: 10),
                  Builder(
                    builder: (context) {
                      final hint = hintFor(store.plan(t.id), s.ex[i], widget.dayKey);
                      final pct = percentKg(t, store.plan(t.id), s.ex[i]);
                      final warm = warmupFor(s.ex) == s.ex[i]
                          ? warmups(pct ?? hint?.nextKg ?? loadKg(s.ex[i].load) ?? 0)
                          : const <SetLog>[];
                      return _ExerciseCard(
                        index: i,
                        e: s.ex[i],
                        trainee: t,
                        workout: w,
                        load: loadText(t, store.plan(t.id), s.ex[i], metric: d.settings.kg),
                        metric: d.settings.kg,
                        hint: hint,
                        warmups: warm,
                        partner: s.ex[i].group != null && i > 0 && s.ex[i - 1].group == s.ex[i].group,
                        onSet: (j) => _tick(s.ex, i, j, w, hint, pct),
                      );
                    },
                  ),
                ],
                const SizedBox(height: 18),
                NeonButton(
                  label: done == tot && tot > 0 ? tx('Finish workout') : '${tx('Finish workout')} · $done/$tot',
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
                  end: _restEnd!,
                  total: _restTotal,
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
    required this.metric,
    required this.hint,
    required this.warmups,
    required this.partner,
    required this.onSet,
  });

  final int index;
  final Exercise e;
  final Trainee trainee;
  final ActiveWorkout workout;
  final String load;
  final bool metric;
  final LiftHint? hint;
  final List<SetLog> warmups;

  /// Second exercise of a superset: done straight after the one above.
  final bool partner;
  final ValueChanged<int> onSet;

  String _kg(double kg) => weightValue(kg, metric: metric);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final all = e.sets > 0 && List.generate(e.sets, (j) => workout.isDone(e.id, j)).every((x) => x);
    final f = isFlagged(trainee, e);
    final h = hint;
    final tags = [
      if (e.group != null)
        partner ? tx('SUPERSET {g} · NO REST BEFORE', {'g': e.group}) : tx('SUPERSET {g}', {'g': e.group}),
      if (e.drop) tx('DROP SET ON THE LAST SET'),
    ];
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
          if (tags.isNotEmpty) ...[
            Kicker(tags.join(' · '), size: 9, spacing: .1, color: BoltColors.neon),
            const SizedBox(height: 8),
          ],
          Row(
            children: [
              Text(
                pad(index + 1),
                style: BoltText.m(12, weight: 700, color: all ? BoltColors.neon : BoltColors.muted3),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Tap(
                  onTap: h != null
                      ? () => context.push('/lift/${Uri.encodeComponent(e.name)}')
                      : kHow.containsKey(e.name)
                      ? () => showExerciseSheet(e.name)
                      : null,
                  child: Text(tx(e.name), style: BoltText.a(16, weight: 800)),
                ),
              ),
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
                    child: Text(tx('i'), style: BoltText.a(13, weight: 800, color: BoltColors.neon, height: 1)),
                  ),
                ),
              ],
              if (!(workout.done[e.id]?.contains(true) ?? false) && swapOptions(e, trainee).isNotEmpty) ...[
                const SizedBox(width: 8),
                SwapIcon(onTap: () => showSwapSheet(context, e, trainee)),
              ],
              const SizedBox(width: 10),
              Text(load, style: BoltText.m(12, color: BoltColors.muted)),
            ],
          ),
          if (h != null) ...[
            const SizedBox(height: 8),
            Text(
              h.last.topKg == null
                  ? tx('Last {day}: {reps} reps · beat it', {'day': fmtDay(h.last.date), 'reps': repsText(h.last)})
                  : tx('Last {day}: {kg} × {reps}', {
                          'day': fmtDay(h.last.date),
                          'kg': '${_kg(h.last.topKg!)} ${weightUnit(metric)}',
                          'reps': repsText(h.last),
                        }) +
                        (h.easy
                            ? tx(' · felt easy, try {kg}', {'kg': '${_kg(h.nextKg!)} ${weightUnit(metric)}'})
                            : h.up
                            ? tx(' · every rep hit, try {kg}', {'kg': '${_kg(h.nextKg!)} ${weightUnit(metric)}'})
                            : tx(' · same weight, beat the reps')),
              style: BoltText.a(12, weight: 600, color: h.up ? BoltColors.neon : BoltColors.muted),
            ),
          ],
          if (f) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    tx(trainee.coachName == null ? '{area} flag · try {alt}' : '{area} flag · coach suggests {alt}', {
                      'area': tx(kAreas[e.area]!),
                      'alt': e.alt == null ? tx('a lighter variation') : tx(e.alt!),
                    }),
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
            Text(tx('Swapped from {name}', {'name': tx(e.orig)}), style: BoltText.m(10, color: BoltColors.muted)),
          ],
          if (warmups.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              '${tx('WARM-UP')}  ${warmups.map((x) => '${_kg(x.kg!)}×${x.reps}').join('  ·  ')} ${weightUnit(metric)}',
              style: BoltText.m(10, color: BoltColors.muted, spacing: .04),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (var j = 0; j < e.sets; j++)
                _SetButton(
                  n: j + 1,
                  reps: e.ownLoad(j) == null
                      ? e.repsFor(j)
                      : '${unitLoad(e.ownLoad(j)!, kg: metric).replaceAll(RegExp(r'\s?(kg|lb)$'), '')}×${e.repsFor(j)}',
                  done: workout.isDone(e.id, j),
                  logged: workout.log(e.id, j),
                  metric: metric,
                  onTap: () => onSet(j),
                ),
            ],
          ),
          if (workout.done[e.id]?.contains(true) ?? false) ...[
            const SizedBox(height: 6),
            Text(
              tx('Tap a ticked set to change its weight, reps or reps left in the tank.'),
              style: BoltText.a(11, color: BoltColors.muted3),
            ),
          ],
        ],
      ),
    );
  }
}

class _SetButton extends StatelessWidget {
  const _SetButton({
    required this.n,
    required this.reps,
    required this.done,
    required this.logged,
    required this.metric,
    required this.onTap,
  });

  final int n;
  final String reps;
  final bool done;
  final SetLog? logged;
  final bool metric;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = done ? BoltColors.ink : BoltColors.text;
    final l = logged;
    final value = !done || l == null
        ? reps
        : [if (l.kg != null) weightValue(l.kg, metric: metric), if (l.reps != null) '${l.reps}'].join('×');
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
            Text(tx('SET {n}', {'n': n}), style: BoltText.m(9, spacing: .1, color: fg.withValues(alpha: .75))),
            Text(value.isEmpty ? reps : value, style: BoltText.a(14, weight: 800, color: fg)),
          ],
        ),
      ),
    );
  }
}

/// Change a ticked set's weight and reps, or untick it.
class _SetSheet extends ConsumerStatefulWidget {
  const _SetSheet({required this.e, required this.set, required this.onSaved});

  final Exercise e;
  final int set;
  final ValueChanged<SetLog> onSaved;

  @override
  ConsumerState<_SetSheet> createState() => _SetSheetState();
}

class _SetSheetState extends ConsumerState<_SetSheet> {
  late final bool _metric = ref.read(boltProvider).settings.kg;
  late final SetLog? _log = ref.read(boltProvider).workout?.log(widget.e.id, widget.set);
  late final _kg = TextEditingController(text: weightValue(_log?.kg, metric: _metric));
  late final _reps = TextEditingController(text: _log?.reps?.toString() ?? '');
  late int? _rir = _log?.rir;

  @override
  void dispose() {
    _kg.dispose();
    _reps.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = ref.read(boltProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Kicker(tx('SET {n}', {'n': widget.set + 1}), size: 10),
        const SizedBox(height: 4),
        Text(tx(widget.e.name), style: BoltText.a(20, weight: 900)),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: BoltField(
                controller: _kg,
                hint: tx('Weight (empty = bodyweight)'),
                number: true,
                suffix: weightUnit(_metric),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: BoltField(controller: _reps, hint: tx('Reps'), number: true),
            ),
          ],
        ),
        FieldLabel(tx('REPS LEFT IN THE TANK')),
        ChoiceChips(
          options: const ['0', '1', '2', '3', '4'],
          labels: const {'0': '0', '1': '1', '2': '2', '3': '3', '4': '4+'},
          selected: _rir?.toString(),
          onSelect: (v) => setState(() => _rir = _rir == int.parse(v) ? null : int.parse(v)),
        ),
        const SizedBox(height: 6),
        Text(
          tx('0 means you could not do another rep. 2-3 left is the sweet spot for most sets.'),
          style: BoltText.a(12, color: BoltColors.muted, height: 1.4),
        ),
        const SizedBox(height: 16),
        NeonButton(
          label: tx('Save set'),
          height: 52,
          scale: 1,
          onTap: () {
            final log = SetLog(
              kg: parseWeight(_kg.text, metric: _metric),
              reps: int.tryParse(_reps.text.trim()),
              rir: _rir,
            );
            store.logSet(widget.e.id, widget.set, log);
            Navigator.of(context).pop();
            widget.onSaved(log);
          },
        ),
        const SizedBox(height: 8),
        OutlineButton(
          label: tx('Untick set'),
          color: BoltColors.text,
          borderColor: BoltColors.line,
          weight: 700,
          onTap: () {
            HapticFeedback.selectionClick();
            store.toggleSet(widget.e.id, widget.set);
            Navigator.of(context).pop();
          },
        ),
      ],
    );
  }
}

/// The rest countdown. It runs its own animation from [end], so only the
/// bar repaints each frame.
class _RestBar extends StatefulWidget {
  const _RestBar({
    required this.end,
    required this.total,
    required this.onMinus,
    required this.onPlus,
    required this.onSkip,
  });

  final DateTime end;

  /// Full rest in seconds.
  final int total;
  final VoidCallback onMinus;
  final VoidCallback onPlus;
  final VoidCallback onSkip;

  @override
  State<_RestBar> createState() => _RestBarState();
}

class _RestBarState extends State<_RestBar> with SingleTickerProviderStateMixin {
  /// Share of the rest still left, running down to 0 in real time.
  late final _c = AnimationController(vsync: this);

  @override
  void initState() {
    super.initState();
    _run();
  }

  @override
  void didUpdateWidget(_RestBar old) {
    super.didUpdateWidget(old);
    if (old.end != widget.end || old.total != widget.total) _run();
  }

  void _run() {
    final left = widget.end.difference(DateTime.now());
    _c.value = (left.inMilliseconds / (widget.total * 1000)).clamp(0.0, 1.0);
    if (left > Duration.zero) _c.animateTo(0, duration: left);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final onMinus = widget.onMinus, onPlus = widget.onPlus, onSkip = widget.onSkip;
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
                        tx('REST'),
                        style: BoltText.m(10, weight: 700, spacing: .12, color: BoltColors.ink.withValues(alpha: .6)),
                      ),
                      AnimatedBuilder(
                        animation: _c,
                        builder: (context, _) {
                          final ms = widget.end.difference(DateTime.now()).inMilliseconds;
                          final left = math.max(0, (ms / 1000).ceil());
                          return Text(
                            '${left ~/ 60}:${pad(left % 60)}',
                            style: BoltText.m(28, weight: 700, color: BoltColors.ink, height: 1),
                          );
                        },
                      ),
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
                    child: Text(tx('Skip'), style: BoltText.a(13, weight: 800, color: BoltColors.neon)),
                  ),
                ),
              ],
            ),
          ),
          Positioned.fill(
            child: Align(
              alignment: Alignment.bottomLeft,
              child: AnimatedBuilder(
                animation: _c,
                builder: (context, child) => FractionallySizedBox(widthFactor: _c.value, child: child),
                child: Container(height: 4, color: BoltColors.ink),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// What the ticked sets of [w] moved so far.
(double, int) _work(ActiveWorkout w) => workOf(w.logs.values.expand((m) => m.values));

/// Kilograms moved, whole, in the chosen unit.
String volumeText(double kg, {required bool metric}) => '${(metric ? kg : kg * 2.20462).round()} ${weightUnit(metric)}';

/// This workout against the last time you did it.
class _Race extends StatelessWidget {
  const _Race({required this.day, required this.now, required this.last, required this.metric});

  final String day;
  final (double, int) now;
  final (double, int) last;
  final bool metric;

  @override
  Widget build(BuildContext context) {
    final (done, target, byKg) = race(now, last);
    final ahead = target > 0 && done > target;
    String v(double x) => byKg ? volumeText(x, metric: metric) : plural(x.round(), 'rep');
    return BoltBox(
      color: BoltColors.surface1,
      stroke: Stroke(ahead ? BoltColors.neon : BoltColors.lineSoft, ahead ? 1.5 : 1),
      radius: 14,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Kicker(
                  ahead
                      ? tx('AHEAD OF {day} BY {x}', {
                          'day': fmtDay(day).toUpperCase(),
                          'x': v(done - target).toUpperCase(),
                        })
                      : tx('RACING {day}', {'day': fmtDay(day).toUpperCase()}),
                  size: 9,
                  spacing: .1,
                  color: ahead ? BoltColors.neon : BoltColors.muted,
                ),
              ),
              Text('${v(done)} / ${v(target)}', style: BoltText.m(10, weight: 700)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: Container(
              height: 6,
              color: BoltColors.lineSoft,
              alignment: Alignment.centerLeft,
              child: AnimatedFractionallySizedBox(
                duration: const Duration(milliseconds: 350),
                widthFactor: target == 0 ? 0 : (done / target).clamp(0.0, 1.0),
                heightFactor: 1,
                child: ColoredBox(color: ahead ? BoltColors.neon : BoltColors.textSoft),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Time since the workout started, ticking.
class _Elapsed extends ConsumerWidget {
  const _Elapsed({required this.started});

  final int started;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mins = (watchNow(ref).millisecondsSinceEpoch - started) / 60000;
    return Text(clockText(mins), style: BoltText.m(14, weight: 700, color: BoltColors.neon));
  }
}
