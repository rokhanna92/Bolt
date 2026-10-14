import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/share.dart';
import '../../core/format.dart';
import '../../data/bolt_store.dart';
import '../../data/models/exercise.dart';
import '../../data/models/people.dart';
import '../../data/models/session.dart';
import '../../data/models/template.dart';
import '../../data/rules.dart';
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
                Kicker(isTpl ? 'EDIT TEMPLATE' : 'EDIT SESSION · ${fmtDay(day!.key).toUpperCase()}'),
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
                session!.title.toUpperCase(),
                style: BoltText.a(tsz(session.title, 44), weight: 900, width: 115, color: BoltColors.neon, height: .95),
              ),
            const SizedBox(height: 8),
            Text(
              isTpl
                  ? 'Changes apply to future auto-fills'
                  : coach
                  ? 'For ${x!.name} · ${session!.focus}'
                  : session!.focus,
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
                    'DRAFT · ${firstName(x!.name).toUpperCase()} SEES IT AFTER YOU SEND',
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
                  x.injuries.map((i) => '${kAreas[i.area]}: ${i.note}').join('  ·  '),
                  style: BoltText.a(12, color: BoltColors.warn),
                ),
              ),
            ],
            const SizedBox(height: 16),
            for (var i = 0; i < ex.length; i++) ...[_row(i, ex[i], x), const SizedBox(height: 8)],
            if (ex.isEmpty) ...[
              BoltBox(
                radius: 14,
                stroke: const Stroke.dashed(BoltColors.line),
                padding: const EdgeInsets.all(16),
                child: Text(
                  'No exercises yet.',
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
                child: Text('+ Add exercise', style: BoltText.a(14, weight: 800, color: BoltColors.neon)),
              ),
            ),
            if (session != null) ...[
              const SizedBox(height: 18),
              Kicker(coach ? 'NOTE FOR ${firstName(x!.name).toUpperCase()}' : 'NOTE', size: 10),
              const SizedBox(height: 8),
              BoltTextArea(
                controller: _note,
                hint: coach ? 'Cues, targets, anything they should know' : 'Cues and targets for yourself',
                onChanged: (v) => _edit(() => session.note = v),
              ),
            ],
            const SizedBox(height: 18),
            NeonButton(
              label: isTpl
                  ? 'Save template'
                  : coach
                  ? 'Save & send to ${firstName(x!.name)}'
                  : 'Save session',
              onTap: () async {
                final msg = _store.saveEdit(target);
                context.pop();
                if (msg != null) {
                  final hint = await shareMessage(msg, subject: 'Your Bolt plan');
                  _store.toast(hint ?? 'Sent to ${firstName(x!.name)} for approval');
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(int i, Exercise e, Trainee? x) {
    final f = isFlagged(x, e);
    return BoltBox(
      color: BoltColors.surface1,
      stroke: const Stroke(BoltColors.lineSoft),
      radius: 16,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(pad(i + 1), style: BoltText.m(11, color: BoltColors.muted4)),
              const SizedBox(width: 10),
              Expanded(child: Text(e.name, style: BoltText.a(15, weight: 800))),
              Tap(
                onTap: () => _edit(() => _store.editExercises(widget.target).remove(e)),
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
                          Text('SETS', style: BoltText.m(8, color: BoltColors.muted, height: 1.1)),
                        ],
                      ),
                    ),
                    _step('+', BoltColors.neon, () => _edit(() => e.sets = (e.sets + 1).clamp(1, 10))),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(child: _input(_ctl(_reps, e.id, e.reps), 'Reps', (v) => _edit(() => e.reps = v))),
              const SizedBox(width: 8),
              Expanded(child: _input(_ctl(_loads, e.id, e.load), 'Load', (v) => _edit(() => e.load = v))),
            ],
          ),
          if (f) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${kAreas[e.area]} flag${e.alt != null ? ' · swap to ${e.alt}' : ''}',
                    style: BoltText.a(12, color: BoltColors.warn),
                  ),
                ),
                if (e.alt != null) ...[const SizedBox(width: 8), SwapButton(onTap: () => _edit(() => swapExercise(e)))],
              ],
            ),
          ],
          if (e.swapped) ...[
            const SizedBox(height: 6),
            Text('Swapped from ${e.orig}', style: BoltText.m(10, color: BoltColors.muted)),
          ],
        ],
      ),
    );
  }

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

  Widget _input(TextEditingController c, String hint, ValueChanged<String> onChanged) => BoltField(
    controller: c,
    hint: hint,
    onChanged: onChanged,
    height: 40,
    fontSize: 14,
    weight: 700,
    radius: 10,
    fill: BoltColors.ink,
    padding: 10,
  );
}

/// Every exercise from the templates.
class _Picker extends ConsumerWidget {
  const _Picker({required this.target});

  final EditTarget target;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Add exercise', style: BoltText.a(20, weight: 900)),
        const SizedBox(height: 10),
        for (final a in kAllExercises)
          Tap(
            onTap: () {
              ref.read(boltProvider.notifier).addExercise(target, a);
              Navigator.of(context).pop();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: BoltColors.divider)),
              ),
              child: Row(
                children: [
                  Expanded(child: Text(a.name, style: BoltText.a(14, weight: 700))),
                  const SizedBox(width: 10),
                  Text(
                    '${a.sets} × ${a.reps}${a.load != '—' ? ' · ${a.load}' : ''}'.toUpperCase(),
                    style: BoltText.m(9, color: BoltColors.muted),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
