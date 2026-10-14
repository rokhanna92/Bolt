import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/actions.dart';
import '../../app/ui_state.dart';
import '../../data/bolt_store.dart';
import '../../data/seed/learn.dart';
import '../../theme/text_styles.dart';
import '../../theme/tokens.dart';
import '../../widgets/box.dart';
import '../../widgets/common.dart';
import '../../widgets/tap.dart';

class LearnScreen extends ConsumerWidget {
  const LearnScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(learnTabProvider);
    final tpls = ref.watch(boltProvider).tpls;
    final insets = MediaQuery.paddingOf(context);
    Widget intro(String t) => Text(t, style: BoltText.a(13, color: BoltColors.muted, height: 1.5));

    return BoltPage(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, insets.top + 16, 20, 120 + insets.bottom),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                BackBox(onTap: () => context.pop()),
                const SizedBox(width: 12),
                Text('Learn', style: BoltText.a(24, weight: 900)),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                for (final (i, (k, l)) in const [
                  ('w', 'Workouts'),
                  ('e', 'Exercises'),
                  ('s', 'Supplements'),
                ].indexed) ...[
                  if (i > 0) const SizedBox(width: 6),
                  Expanded(
                    child: Tap(
                      onTap: () => ref.read(learnTabProvider.notifier).set(k),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: tab == k ? BoltColors.neon : const Color(0x00C6FF1A),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: tab == k ? BoltColors.neon : BoltColors.line),
                        ),
                        child: Text(
                          l,
                          style: BoltText.a(13, weight: 800, color: tab == k ? BoltColors.ink : BoltColors.text),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            if (tab == 'w') ...[
              intro('Why each workout day exists and what it trains.'),
              const SizedBox(height: 12),
              for (final k in kWhy.keys) ...[
                if (tpls[k] != null)
                  BoltBox(
                    color: BoltColors.surface1,
                    stroke: const Stroke(BoltColors.lineSoft),
                    radius: 18,
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              tpls[k]!.code,
                              style: BoltText.m(10, weight: 700, spacing: .1, color: BoltColors.neon),
                            ),
                            const SizedBox(width: 10),
                            Text(tpls[k]!.name, style: BoltText.a(19, weight: 900)),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(tpls[k]!.focus, style: BoltText.a(12, color: BoltColors.muted)),
                        const SizedBox(height: 10),
                        for (final (i, p) in kWhy[k]!.indexed) ...[
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
                              Expanded(child: Text(p, style: BoltText.a(13, height: 1.45))),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                const SizedBox(height: 10),
              ],
            ],
            if (tab == 'e') ...[
              intro('Correct form, step by step. You can also tap ⓘ next to any exercise in a workout.'),
              const SizedBox(height: 12),
              for (final e in kHow.entries) ...[
                Tap(
                  onTap: () => showExerciseSheet(e.key),
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
                              Text(e.key, style: BoltText.a(14, weight: 800)),
                              const SizedBox(height: 2),
                              Text(e.value.muscles, style: BoltText.a(12, color: BoltColors.muted)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Chevron(size: 18),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 6),
              ],
            ],
            if (tab == 's') ...[
              intro(
                'The few supplements with solid research behind them. Food, sleep and training come first. Check with a doctor if you have a medical condition or take medication.',
              ),
              const SizedBox(height: 12),
              for (final u in kSupplements) ...[
                BoltBox(
                  color: BoltColors.surface1,
                  stroke: const Stroke(BoltColors.lineSoft),
                  radius: 18,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text(u.name, style: BoltText.a(17, weight: 900))),
                          const SizedBox(width: 8),
                          BoltBox(
                            radius: 6,
                            stroke: const Stroke(BoltColors.neon),
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                            child: Text(u.tag, style: BoltText.m(9, weight: 700, spacing: .08, color: BoltColors.neon)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(u.why, style: BoltText.a(13, height: 1.5)),
                      const SizedBox(height: 8),
                      BoltBox(
                        color: BoltColors.ink,
                        stroke: const Stroke(BoltColors.lineSoft),
                        radius: 12,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Kicker('HOW TO TAKE', size: 9, color: BoltColors.neon),
                            const SizedBox(height: 4),
                            Text(u.how, style: BoltText.a(13, height: 1.45)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(u.note, style: BoltText.a(12, color: BoltColors.muted, height: 1.4)),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
