import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/l10n.dart';

import '../../app/actions.dart';
import '../../app/ui_state.dart';
import '../../data/bolt_store.dart';
import '../../data/models/bolt_data.dart';
import '../../data/seed/exercises.dart';
import '../../data/seed/learn.dart';
import '../../data/seed/move.dart';
import '../../data/seed/muscles.dart';
import '../../data/seed/splits.dart' show splitOf;
import '../../theme/text_styles.dart';
import '../../theme/tokens.dart';
import '../../widgets/box.dart';
import '../../widgets/common.dart';
import '../../widgets/forms.dart';
import '../../widgets/tap.dart';

const _tabs = [
  ('w', 'Workouts'),
  ('mv', 'Move'),
  ('st', 'Styles'),
  ('m', 'Muscles'),
  ('e', 'Exercises'),
  ('s', 'Supplements'),
  ('b', 'Basics'),
];

/// Supplement filters: label and the tags it shows.
const _suppFilters = <(String, Set<String>)>[
  ('All', {}),
  ('Strong', {'STRONG EVIDENCE'}),
  ('Moderate', {'MODERATE', 'EMERGING'}),
  ('Situational', {'SITUATIONAL', 'IF LOW'}),
  ('Weak', {'WEAK', 'NO EVIDENCE'}),
];

/// Workout reasoning, training styles, muscles, exercise form, supplements
/// and the basics. A tab for people who train; coaches open it from their
/// Library.
class LearnScreen extends ConsumerWidget {
  const LearnScreen({super.key, this.pushed = false});

  /// Opened over another screen, so it has a back button.
  final bool pushed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(learnTabProvider);
    final d = ref.watch(boltProvider);
    final insets = MediaQuery.paddingOf(context);
    Widget intro(String t) => Text(t, style: BoltText.a(13, color: BoltColors.muted, height: 1.5));

    return BoltPage(
      // Built lazily: the exercise tab alone holds every exercise.
      child: ListView(
        padding: EdgeInsets.fromLTRB(20, insets.top + 20, 20, 120 + insets.bottom),
        children: [
          Row(
            children: [
              if (pushed) ...[BackBox(onTap: () => context.pop()), const SizedBox(width: 12)],
              Kicker(tx('ATLAS')),
            ],
          ),
          const SizedBox(height: 4),
          Text(tx('Train smarter'), style: BoltText.a(30, weight: 900, width: 112, spacing: -.02)),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            child: Row(
              children: [
                for (final (i, (k, l)) in _tabs.indexed) ...[
                  if (i > 0) const SizedBox(width: 6),
                  Tap(
                    onTap: () => ref.read(learnTabProvider.notifier).set(k),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      height: 40,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: tab == k ? BoltColors.neon : const Color(0x00C6FF1A),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: tab == k ? BoltColors.neon : BoltColors.line),
                      ),
                      child: Text(
                        tx(l),
                        style: BoltText.a(13, weight: 800, color: tab == k ? BoltColors.ink : BoltColors.text),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          ...switch (tab) {
            'st' => [
              intro(
                tx(
                  'How the greats trained and the splits that copy them. Tap "Use this split" to plan your weeks with it.',
                ),
              ),
              const SizedBox(height: 12),
              for (final st in kStyles) ...[_StyleCard(style: st, data: d), const SizedBox(height: 10)],
              const SizedBox(height: 14),
              SectionTitle(tx('Intensity techniques')),
              const SizedBox(height: 4),
              intro(tx('Old school tricks to push a set further. Use them on the last set, not every set.')),
              const SizedBox(height: 12),
              for (final t in kTechniques) ...[
                _Card(
                  children: [
                    Text(tx(t.name), style: BoltText.a(16, weight: 900)),
                    const SizedBox(height: 6),
                    Text(tx(t.how), style: BoltText.a(13, height: 1.45)),
                    const SizedBox(height: 6),
                    Text(tx(t.when), style: BoltText.a(12, color: BoltColors.muted, height: 1.4)),
                  ],
                ),
                const SizedBox(height: 8),
              ],
            ],
            'mv' => [
              intro(
                tx(
                  'Walking, cycling, running and stretching: why each one helps beyond the weights, and how to start. Numbers are from large studies and show links, not guarantees.',
                ),
              ),
              const SizedBox(height: 12),
              for (final m in kMove) ...[
                _Card(
                  children: [
                    Kicker(tx(m.tag).toUpperCase(), size: 9, spacing: .1, color: BoltColors.neon),
                    const SizedBox(height: 4),
                    Text(tx(m.name), style: BoltText.a(20, weight: 900)),
                    const SizedBox(height: 10),
                    _Bullets(m.why),
                    const SizedBox(height: 14),
                    Kicker(tx('HOW TO START'), size: 9, spacing: .1),
                    const SizedBox(height: 8),
                    _Bullets(m.how),
                    const SizedBox(height: 12),
                    Text(m.source, style: BoltText.a(11, color: BoltColors.muted3, height: 1.4)),
                  ],
                ),
                const SizedBox(height: 10),
              ],
            ],
            'm' => [
              intro(
                tx('What each muscle does, how to train it and the exercises that hit it. Tap an exercise for form.'),
              ),
              const SizedBox(height: 12),
              for (final e in kMuscles.entries) ...[_MuscleCard(id: e.key, m: e.value), const SizedBox(height: 10)],
            ],
            'e' => [
              intro(tx('Correct form, step by step. You can also tap ⓘ next to any exercise in a workout.')),
              for (final g in kExerciseGroups.entries) ...[
                const SizedBox(height: 16),
                Kicker(tx(g.value).toUpperCase(), size: 10, spacing: .1),
                const SizedBox(height: 8),
                for (final e in kExercises.where((x) => x.muscle == g.key)) ...[
                  _ExerciseRow(e: e),
                  const SizedBox(height: 6),
                ],
              ],
            ],
            's' => [
              intro(
                tx(
                  tx(
                    'What works, what might, and what is marketing. Food, sleep and training come first. Check with a doctor if you have a medical condition or take medication.',
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const _SuppList(),
            ],
            'b' => [
              intro(tx('The fundamentals behind every split. Get these right and any style works.')),
              const SizedBox(height: 12),
              for (final (title, points) in kBasics) ...[
                _Card(
                  children: [
                    Text(tx(title), style: BoltText.a(17, weight: 900)),
                    const SizedBox(height: 10),
                    _Bullets(points),
                  ],
                ),
                const SizedBox(height: 10),
              ],
            ],
            _ => [
              intro(tx('Why each workout day exists and what it trains.')),
              const SizedBox(height: 12),
              for (final k in kWhy.keys)
                if (d.tpls[k] != null) ...[
                  _Card(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            d.tpls[k]!.code,
                            style: BoltText.m(10, weight: 700, spacing: .1, color: BoltColors.neon),
                          ),
                          const SizedBox(width: 10),
                          Expanded(child: Text(tx(d.tpls[k]!.name), style: BoltText.a(19, weight: 900))),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(tx(d.tpls[k]!.focus), style: BoltText.a(12, color: BoltColors.muted)),
                      const SizedBox(height: 10),
                      _Bullets(kWhy[k]!),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],
            ],
          },
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => BoltBox(
    color: BoltColors.surface1,
    stroke: const Stroke(BoltColors.lineSoft),
    radius: 18,
    padding: const EdgeInsets.all(16),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
  );
}

class _Bullets extends StatelessWidget {
  const _Bullets(this.points);

  final List<String> points;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final (i, p) in points.indexed) ...[
        if (i > 0) const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 6,
              height: 6,
              margin: const EdgeInsets.only(top: 6),
              decoration: const BoxDecoration(color: BoltColors.neon, shape: BoxShape.circle),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(tx(p), style: BoltText.a(13, height: 1.45))),
          ],
        ),
      ],
    ],
  );
}

class _StyleCard extends ConsumerWidget {
  const _StyleCard({required this.style, required this.data});

  final TrainingStyle style;
  final BoltData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.read(boltProvider.notifier);
    final me = (data.account?.isTrainee ?? false) ? store.trOrNull(Account.ownerId) : null;
    final split = style.split;
    return _Card(
      children: [
        Text(tx(style.name), style: BoltText.a(19, weight: 900)),
        const SizedBox(height: 4),
        Text(tx(style.who), style: BoltText.a(12, weight: 600, color: BoltColors.neon, height: 1.4)),
        const SizedBox(height: 10),
        Text(tx(style.how), style: BoltText.a(13, height: 1.5)),
        const SizedBox(height: 10),
        _Bullets(style.why),
        const SizedBox(height: 10),
        BoltBox(
          radius: 12,
          color: const Color(0x0FFF7A45),
          stroke: const Stroke(Color(0x73FF7A45)),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Kicker(tx('WATCH OUT'), size: 9, color: BoltColors.warn),
              const SizedBox(height: 4),
              Text(tx(style.watch), style: BoltText.a(13, height: 1.45)),
            ],
          ),
        ),
        if (split != null) ...[
          const SizedBox(height: 12),
          SplitWeek(split: splitOf(data, split), tpls: data.tpls),
          if (me != null) ...[
            const SizedBox(height: 10),
            me.split == split
                ? Text(tx('Your current split'), style: BoltText.a(13, weight: 800, color: BoltColors.neon))
                : OutlineButton(
                    label: tx('Use this split'),
                    height: 44,
                    radius: 12,
                    fontSize: 13,
                    onTap: () => store.setSplit(me.id, split),
                  ),
          ],
        ],
      ],
    );
  }
}

class _MuscleCard extends StatelessWidget {
  const _MuscleCard({required this.id, required this.m});

  final String id;
  final MuscleInfo m;

  @override
  Widget build(BuildContext context) {
    final ex = kExercises.where((e) => e.muscle == id).toList();
    return _Card(
      children: [
        Row(
          children: [
            Expanded(child: Text(tx(m.name), style: BoltText.a(19, weight: 900))),
            BoltBox(
              radius: 6,
              stroke: const Stroke(BoltColors.neon),
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              child: Text(tx(m.volume).toUpperCase(), style: BoltText.m(8, weight: 700, color: BoltColors.neon)),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(tx(m.parts), style: BoltText.a(12, color: BoltColors.muted, height: 1.4)),
        const SizedBox(height: 10),
        Text(tx(m.does), style: BoltText.a(13, height: 1.5)),
        const SizedBox(height: 10),
        _Bullets(m.tips),
        if (ex.isNotEmpty) ...[
          const SizedBox(height: 12),
          Kicker(tx('EXERCISES'), size: 9),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final e in ex)
                Tap(
                  onTap: () => showExerciseSheet(e.name),
                  child: BoltBox(
                    radius: 99,
                    color: BoltColors.surface2,
                    stroke: const Stroke(BoltColors.line),
                    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                    child: Text(tx(e.name), style: BoltText.a(12, weight: 600)),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _ExerciseRow extends StatelessWidget {
  const _ExerciseRow({required this.e});

  final ExInfo e;

  @override
  Widget build(BuildContext context) => Tap(
    onTap: () => showExerciseSheet(e.name),
    child: BoltBox(
      color: BoltColors.surface1,
      stroke: const Stroke(BoltColors.lineSoft),
      radius: 14,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tx(e.name), style: BoltText.a(14, weight: 800)),
                const SizedBox(height: 2),
                Text(tx(e.works), style: BoltText.a(12, color: BoltColors.muted)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          const Chevron(size: 18),
        ],
      ),
    ),
  );
}

class _SuppList extends ConsumerWidget {
  const _SuppList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = ref.watch(suppFilterProvider);
    final tags = _suppFilters[f].$2;
    final list = kSupplements.where((u) => tags.isEmpty || tags.contains(u.tag)).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          child: Row(
            children: [
              for (final (i, (label, _)) in _suppFilters.indexed)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Tap(
                    onTap: () => ref.read(suppFilterProvider.notifier).set(i),
                    child: BoltBox(
                      radius: 99,
                      color: f == i ? BoltColors.neon : BoltColors.surface2,
                      stroke: Stroke(f == i ? BoltColors.neon : BoltColors.line),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      child: Text(
                        tx(label),
                        style: BoltText.a(12, weight: 700, color: f == i ? BoltColors.ink : BoltColors.text),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        for (final u in list) ...[
          _Card(
            children: [
              Row(
                children: [
                  Expanded(child: Text(tx(u.name), style: BoltText.a(17, weight: 900))),
                  const SizedBox(width: 8),
                  BoltBox(
                    radius: 6,
                    stroke: Stroke(u.tag == 'NO EVIDENCE' || u.tag == 'WEAK' ? BoltColors.muted2 : BoltColors.neon),
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    child: Text(
                      tx(u.tag),
                      style: BoltText.m(
                        9,
                        weight: 700,
                        spacing: .08,
                        color: u.tag == 'NO EVIDENCE' || u.tag == 'WEAK' ? BoltColors.muted : BoltColors.neon,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(tx(u.why), style: BoltText.a(13, height: 1.5)),
              const SizedBox(height: 8),
              BoltBox(
                color: BoltColors.ink,
                stroke: const Stroke(BoltColors.lineSoft),
                radius: 12,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Kicker(tx('HOW TO TAKE'), size: 9, color: BoltColors.neon),
                    const SizedBox(height: 4),
                    Text(tx(u.how), style: BoltText.a(13, height: 1.45)),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(tx(u.note), style: BoltText.a(12, color: BoltColors.muted, height: 1.4)),
            ],
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}
