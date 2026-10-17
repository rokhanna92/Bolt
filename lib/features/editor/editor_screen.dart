import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/actions.dart';
import '../../app/share.dart';
import '../../core/format.dart';
import '../../data/bolt_store.dart';
import '../../data/models/exercise.dart';
import '../../data/models/people.dart';
import '../../data/models/session.dart';
import '../../data/models/template.dart';
import '../../data/lifts.dart';
import '../../data/rules.dart';
import '../../data/seed/exercises.dart';
import '../../data/seed/learn.dart';
import '../../data/seed/templates.dart';
import '../../theme/text_styles.dart';
import '../../theme/tokens.dart';
import '../../widgets/bolt_sheet.dart';
import '../../widgets/box.dart';
import '../../widgets/common.dart';
import '../../widgets/exercise_rows.dart';
import '../../widgets/fields.dart';
import '../../widgets/tap.dart';

/// Edits one trainee's day (saving sends it for approval) or a template
/// (affects future auto-fills only).
class EditorScreen extends ConsumerStatefulWidget {
  const EditorScreen({super.key, required this.target});

  final EditTarget target;

  @override
  ConsumerState<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends ConsumerState<EditorScreen> {
  final _reps = <String, TextEditingController>{};
  final _loads = <String, TextEditingController>{};
  late final TextEditingController _name;
  late final TextEditingController _note;

  BoltStore get _store => ref.read(boltProvider.notifier);

  @override
  void initState() {
    super.initState();
    final o = _store.editObject(widget.target);
    _name = TextEditingController(text: o is WorkoutTemplate ? o.name : '');
    _note = TextEditingController(text: o is Session ? o.note : '');
  }

  @override
  void dispose() {
    for (final c in [..._reps.values, ..._loads.values, _name, _note]) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _ctl(Map<String, TextEditingController> m, String id, String text) =>
      m.putIfAbsent(id, () => TextEditingController(text: text));

  void _edit(void Function() fn) => _store.edit(widget.target, fn);

  @override
  Widget build(BuildContext context) {
    ref.watch(boltProvider);
    final target = widget.target;
    final o = _store.editObject(target);
    if (o == null) return const BoltPage(child: SizedBox.expand());
    final isTpl = o is WorkoutTemplate;
    final day = target is DayTarget ? target : null;
    final Trainee? x = day == null ? null : _store.tr(day.tid);
    final ex = _store.editExercises(target);
    final insets = MediaQuery.paddingOf(context);
    final coach = ref.read(boltProvider).account?.isCoach ?? false;
    final session = o is Session ? o : null;

    return BoltPage(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, insets.top + 16, 20, 140 + insets.bottom),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                BackBox(onTap: () => context.pop()),
                const SizedBox(width: 12),
                Kicker(
                  isTpl ? tx('EDIT TEMPLATE') : tx('EDIT SESSION · {day}', {'day': fmtDay(day!.key).toUpperCase()}),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (isTpl)
              TextField(
                controller: _name,
                onChanged: (v) => _store.renameTemplate(o.id, v),
                textCapitalization: TextCapitalization.words,
                style: BoltText.a(34, weight: 900, width: 112, color: BoltColors.neon),
                decoration: const InputDecoration(
                  isDense: true,
                  contentPadding: EdgeInsets.fromLTRB(0, 4, 0, 8),
                  border: UnderlineInputBorder(borderSide: BorderSide(color: BoltColors.line, width: 1.5)),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: BoltColors.line, width: 1.5)),
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: BoltColors.line, width: 1.5)),
                ),
              )
            else
              Text(
                tx(session!.title).toUpperCase(),
                style: BoltText.a(tsz(session.title, 44), weight: 900, width: 115, color: BoltColors.neon, height: .95),
              ),
            const SizedBox(height: 8),
            Text(
              isTpl
                  ? tx('Changes apply to future auto-fills')
                  : coach
                  ? tx('For {name} · {focus}', {'name': x!.name, 'focus': tx(session!.focus)})
                  : tx(session!.focus),
              style: BoltText.a(13, color: BoltColors.muted),
            ),
            if (session != null && session.status == SessionStatus.draft) ...[
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: BoltBox(
                  radius: 8,
                  stroke: const Stroke.dashed(BoltColors.muted2),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  child: Text(
                    tx('DRAFT · {name} SEES IT AFTER YOU SEND', {'name': firstName(x!.name).toUpperCase()}),
                    style: BoltText.m(10, spacing: .08, color: BoltColors.textSoft),
                  ),
                ),
              ),
            ],
            if (x != null && x.injuries.isNotEmpty) ...[
              const SizedBox(height: 10),
              BoltBox(
                radius: 12,
                color: const Color(0x14FF7A45),
                stroke: const Stroke(Color(0x59FF7A45)),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Text(
                  x.injuries.map((i) => '${tx(kAreas[i.area]!)}: ${tx(i.note)}').join('  ·  '),
                  style: BoltText.a(12, color: BoltColors.warn),
                ),
              ),
            ],
            const SizedBox(height: 16),
            if (isTpl) ...[_Standard(tpl: o, onNew: _resetFields), const SizedBox(height: 12)],
            for (var i = 0; i < ex.length; i++) ...[_row(i, ex[i], x), const SizedBox(height: 8)],
            if (ex.isEmpty) ...[
              BoltBox(
                radius: 14,
                stroke: const Stroke.dashed(BoltColors.line),
                padding: const EdgeInsets.all(16),
                child: Text(
                  tx('No exercises yet.'),
                  textAlign: TextAlign.center,
                  style: BoltText.a(13, color: BoltColors.muted),
                ),
              ),
              const SizedBox(height: 8),
            ],
            Tap(
              onTap: () => showBoltSheet<void>(context, (_) => _Picker(target: target), maxHeight: .78),
              child: BoltBox(
                height: 48,
                radius: 14,
                stroke: const Stroke.dashed(BoltColors.neon, 1.5),
                alignment: Alignment.center,
                child: Text(tx('+ Add exercise'), style: BoltText.a(14, weight: 800, color: BoltColors.neon)),
              ),
            ),
            if (session != null) ...[
              const SizedBox(height: 18),
              Kicker(coach ? tx('NOTE FOR {name}', {'name': firstName(x!.name).toUpperCase()}) : tx('NOTE'), size: 10),
              const SizedBox(height: 8),
              BoltTextArea(
                controller: _note,
                hint: coach ? tx('Cues, targets, anything they should know') : tx('Cues and targets for yourself'),
                onChanged: (v) => _edit(() => session.note = v),
              ),
            ],
            const SizedBox(height: 18),
            NeonButton(
              label: isTpl
                  ? tx('Save template')
                  : coach
                  ? tx('Save & send to {name}', {'name': firstName(x!.name)})
                  : tx('Save session'),
              onTap: () async {
                final msg = _store.saveEdit(target);
                context.pop();
                if (msg != null) {
                  final hint = await shareMessage(msg, subject: tx('Your Bolt plan'));
                  _store.toast(hint ?? tx('Sent to {name} for approval', {'name': firstName(x!.name)}));
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Moves exercise [i] one place up ([by] -1) or down (+1).
  void _move(int i, int by) => _edit(() {
    final list = _store.editExercises(widget.target);
    list.insert(i + by, list.removeAt(i));
    normalizeGroups(list);
  });

  Widget _arrow(String l, VoidCallback? f) => Tap(
    onTap: f,
    child: SizedBox(
      width: 30,
      height: 30,
      child: Center(
        child: Text(l, style: BoltText.m(15, weight: 700, color: f == null ? BoltColors.line : BoltColors.muted)),
      ),
    ),
  );

  Widget _row(int i, Exercise e, Trainee? x) {
    final f = isFlagged(x, e);
    final last = _store.editExercises(widget.target).length - 1;
    return BoltBox(
      key: ValueKey(e.id),
      color: BoltColors.surface1,
      stroke: const Stroke(BoltColors.lineSoft),
      radius: 16,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(pad(i + 1), style: BoltText.m(11, color: BoltColors.muted3)),
              const SizedBox(width: 10),
              Expanded(
                child: Tap(
                  onTap: kHow.containsKey(e.name) ? () => showExerciseSheet(e.name) : null,
                  child: Text(tx(e.name), style: BoltText.a(15, weight: 800)),
                ),
              ),
              _arrow('↑', i > 0 ? () => _move(i, -1) : null),
              _arrow('↓', i < last ? () => _move(i, 1) : null),
              Tap(
                onTap: () => _edit(() {
                  final list = _store.editExercises(widget.target)..remove(e);
                  normalizeGroups(list);
                }),
                child: SizedBox(
                  width: 30,
                  height: 30,
                  child: Center(
                    child: Text('✕', style: BoltText.a(16, color: BoltColors.muted2)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              BoltBox(
                height: 40,
                radius: 10,
                stroke: const Stroke(BoltColors.line),
                child: Row(
                  children: [
                    _step('−', BoltColors.text, () => _edit(() => e.sets = (e.sets - 1).clamp(1, 10))),
                    SizedBox(
                      width: 44,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('${e.sets}', style: BoltText.a(15, weight: 800, height: 1.1)),
                          Text(tx('SETS'), style: BoltText.m(8, color: BoltColors.muted, height: 1.1)),
                        ],
                      ),
                    ),
                    _step('+', BoltColors.neon, () => _edit(() => e.sets = (e.sets + 1).clamp(1, 10))),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(child: _input(_ctl(_reps, e.id, e.reps), tx('Reps'), withMax, (v) => _edit(() => e.reps = v))),
              const SizedBox(width: 8),
              Expanded(child: _input(_ctl(_loads, e.id, unitLoad(e.load, kg: true)), tx('Load'), withKg, (v) => _edit(() => e.load = v))),
            ],
          ),
          // Sets from the second on: their own reps and load, empty means
          // the same as the first.
          for (var j = 1; j < e.sets; j++) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                // Lines up with the reps and load of the first row: the
                // sets stepper is 108 wide plus its border and gap.
                SizedBox(
                  width: 118,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 14),
                    child: Text(tx('SET {n}', {'n': j + 1}), style: BoltText.m(10, color: BoltColors.muted)),
                  ),
                ),
                Expanded(
                  child: _input(
                    _ctl(_reps, '${e.id}:$j', e.ownReps(j) ?? ''),
                    e.reps,
                    withMax,
                    (v) => _edit(() => e.planSet(j, reps: v)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _input(
                    _ctl(_loads, '${e.id}:$j', e.ownLoad(j) ?? ''),
                    unitLoad(e.load, kg: true),
                    withKg,
                    (v) => _edit(() => e.planSet(j, load: v)),
                  ),
                ),
              ],
            ),
          ],
          if (f) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    e.alt != null
                        ? tx('{area} flag · swap to {alt}', {'area': tx(kAreas[e.area]!), 'alt': tx(e.alt!)})
                        : tx('{area} flag', {'area': tx(kAreas[e.area]!)}),
                    style: BoltText.a(12, color: BoltColors.warn),
                  ),
                ),
                if (e.alt != null) ...[const SizedBox(width: 8), SwapButton(onTap: () => _edit(() => swapExercise(e)))],
              ],
            ),
          ],
          if (e.swapped) ...[
            const SizedBox(height: 6),
            Text(tx('Swapped from {name}', {'name': tx(e.orig)}), style: BoltText.m(10, color: BoltColors.muted)),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (i + 1 < _store.editExercises(widget.target).length) ...[
                _chip(
                  e.group != null && _store.editExercises(widget.target)[i + 1].group == e.group
                      ? tx('Superset {g} with next', {'g': e.group})
                      : tx('Superset with next'),
                  e.group != null && _store.editExercises(widget.target)[i + 1].group == e.group,
                  () => _edit(() => toggleSuperset(_store.editExercises(widget.target), i)),
                ),
              ],
              _chip(tx('Max reps'), isMax(e.reps), () {
                _edit(() {
                  e.reps = isMax(e.reps) ? kExerciseByName[e.name]?.reps ?? '10' : 'max';
                  e.setReps.clear();
                });
                _resetFields();
              }),
              _chip(tx('Drop set'), e.drop, () => _edit(() => e.drop = !e.drop)),
              _chip(
                e.rest == null ? tx('Rest auto') : tx('Rest {s} s', {'s': e.rest}),
                e.rest != null,
                () => _edit(() {
                  const steps = [null, 60, 90, 120, 180, 240];
                  e.rest = steps[(steps.indexOf(e.rest) + 1) % steps.length];
                }),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, bool on, VoidCallback onTap) => Tap(
    onTap: onTap,
    child: BoltBox(
      radius: 99,
      color: on ? const Color(0x1FC6FF1A) : null,
      stroke: Stroke(on ? BoltColors.neon : BoltColors.line),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Text(label, style: BoltText.a(11, weight: 700, color: on ? BoltColors.neon : BoltColors.muted)),
    ),
  );

  Widget _step(String l, Color c, VoidCallback f) => Tap(
    onTap: f,
    child: SizedBox(
      width: 32,
      height: 40,
      child: Center(
        child: Text(l, style: BoltText.a(16, color: c)),
      ),
    ),
  );

  /// A reps or load field. [fix] tidies what was typed (`15` is `15 kg`):
  /// the plan gets it at once, the field when you leave it.
  Widget _input(TextEditingController c, String hint, String Function(String) fix, ValueChanged<String> onChanged) =>
      Focus(
        onFocusChange: (f) {
          if (!f && fix(c.text) != c.text) c.text = fix(c.text);
        },
        child: BoltField(
          controller: c,
          hint: hint,
          onChanged: (v) => onChanged(fix(v)),
          height: 40,
          fontSize: 14,
          weight: 700,
          radius: 10,
          fill: BoltColors.ink,
          padding: 10,
        ),
      );

  /// Throws away the reps and load fields so they show the plan again.
  void _resetFields() => setState(() {
    for (final c in [..._reps.values, ..._loads.values]) {
      c.dispose();
    }
    _reps.clear();
    _loads.clear();
  });
}

/// How each finished workout of this template stood against it, newest
/// first. Tap one to see it lift by lift or make it the new standard.
class _Standard extends ConsumerWidget {
  const _Standard({required this.tpl, required this.onNew});

  final WorkoutTemplate tpl;
  final VoidCallback onNew;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(boltProvider);
    final store = ref.read(boltProvider.notifier);
    final t = store.trOrNull(d.account?.id ?? '');
    if (t == null) return const SizedBox.shrink();
    final plan = store.plan(t.id);
    final days = standardDays(plan, tpl.id).take(6).toList();
    return BoltBox(
      color: BoltColors.surface1,
      stroke: const Stroke(BoltColors.lineSoft),
      radius: 16,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Kicker(tx('VS YOUR STANDARD'), size: 10),
          const SizedBox(height: 6),
          if (days.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                tx(
                  'The numbers below are your standard. Finish this workout and every time shows here, above or below it.',
                ),
                style: BoltText.a(12, color: BoltColors.muted, height: 1.4),
              ),
            ),
          for (final k in days)
            Tap(
              onTap: () => showBoltSheet<void>(context, (_) => _StandardDay(tpl: tpl, dayKey: k, onNew: onNew)),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: BoltColors.divider)),
                ),
                child: Row(
                  children: [
                    Expanded(child: Text(fmtDay(k), style: BoltText.a(13, weight: 700))),
                    if (overallPct(vsStandard(tpl, plan[k]!)) case final p?)
                      Text(
                        diffText(p),
                        style: BoltText.m(12, weight: 700, color: p >= 0 ? BoltColors.neon : BoltColors.warn),
                      ),
                    const SizedBox(width: 8),
                    const Chevron(size: 16),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// One finished workout lift by lift against the standard, with a button
/// to make it the new standard.
class _StandardDay extends ConsumerWidget {
  const _StandardDay({required this.tpl, required this.dayKey, required this.onNew});

  final WorkoutTemplate tpl;
  final String dayKey;
  final VoidCallback onNew;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(boltProvider);
    final store = ref.read(boltProvider.notifier);
    final s = store.plan(d.account!.id)[dayKey];
    if (s == null) return const SizedBox(height: 120);
    final vs = vsStandard(tpl, s);
    final all = overallPct(vs);
    String set(double? kg, int reps) => kg == null ? plural(reps, 'rep') : '${store.unit(kgText(kg))} × $reps';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Kicker(fmtDay(dayKey).toUpperCase(), size: 10),
        const SizedBox(height: 4),
        Text(tx(tpl.name), style: BoltText.a(20, weight: 900)),
        if (all != null) ...[
          const SizedBox(height: 4),
          Text(
            standardText(all),
            style: BoltText.a(14, weight: 800, color: all >= 0 ? BoltColors.neon : BoltColors.warn),
          ),
        ],
        const SizedBox(height: 10),
        for (final v in vs)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: BoltColors.divider)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tx(v.name), style: BoltText.a(14, weight: 700)),
                      const SizedBox(height: 2),
                      Text(
                        tx('{done} · standard {std}', {
                          'done': set(v.doneKg, v.doneReps),
                          'std': set(v.stdKg, v.stdReps),
                        }),
                        style: BoltText.a(11, color: BoltColors.muted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  diffText(v.pct),
                  style: BoltText.m(12, weight: 700, color: v.pct >= 0 ? BoltColors.neon : BoltColors.warn),
                ),
              ],
            ),
          ),
        if (vs.isEmpty)
          Text(
            tx('Nothing to compare: log weights and reps for the exercises of this workout.'),
            style: BoltText.a(12, color: BoltColors.muted, height: 1.4),
          ),
        const SizedBox(height: 14),
        NeonButton(
          label: tx('Make this my standard'),
          height: 50,
          scale: 1,
          onTap: () {
            store.setStandard(tpl.id, dayKey);
            onNew();
            Navigator.of(context).pop();
          },
        ),
      ],
    );
  }
}

/// Every exercise Bolt knows, grouped by muscle, with a muscle filter.
class _Picker extends ConsumerStatefulWidget {
  const _Picker({required this.target});

  final EditTarget target;

  @override
  ConsumerState<_Picker> createState() => _PickerState();
}

class _PickerState extends ConsumerState<_Picker> {
  String? _group;

  @override
  Widget build(BuildContext context) {
    final groups = _group == null ? kExerciseGroups.keys.toList() : [_group!];
    Widget chip(String? k, String label) => Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Tap(
        onTap: () => setState(() => _group = k),
        child: BoltBox(
          radius: 99,
          color: _group == k ? BoltColors.neon : BoltColors.surface2,
          stroke: Stroke(_group == k ? BoltColors.neon : BoltColors.line),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Text(label, style: BoltText.a(12, weight: 700, color: _group == k ? BoltColors.ink : BoltColors.text)),
        ),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(tx('Add exercise'), style: BoltText.a(20, weight: 900)),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [chip(null, tx('All')), for (final e in kExerciseGroups.entries) chip(e.key, tx(e.value))],
          ),
        ),
        for (final g in groups) ...[
          const SizedBox(height: 14),
          Kicker(tx(kExerciseGroups[g]!).toUpperCase(), size: 10, spacing: .1),
          const SizedBox(height: 4),
          for (final a in kExercises.where((e) => e.muscle == g))
            Tap(
              onTap: () {
                ref
                    .read(boltProvider.notifier)
                    .addExercise(widget.target, ExSeed(a.name, a.sets, a.reps, a.load, a.area, a.alt));
                Navigator.of(context).pop();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: BoltColors.divider)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(tx(a.name), style: BoltText.a(14, weight: 700)),
                          const SizedBox(height: 2),
                          Text(tx(a.works), style: BoltText.a(11, color: BoltColors.muted)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '${a.sets} × ${a.reps}${a.load != '—' ? ' · ${a.load}' : ''}'.toUpperCase(),
                      style: BoltText.m(9, color: BoltColors.muted),
                    ),
                    const SizedBox(width: 10),
                    Tap(
                      onTap: () => showExerciseSheet(a.name),
                      child: BoltBox(
                        width: 24,
                        height: 24,
                        circle: true,
                        stroke: const Stroke(BoltColors.line),
                        alignment: Alignment.center,
                        child: Text(tx('i'), style: BoltText.a(11, weight: 800, color: BoltColors.neon, height: 1)),
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
}
