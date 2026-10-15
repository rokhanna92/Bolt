import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/format.dart';
import '../data/bolt_store.dart';
import '../data/lifts.dart';
import '../data/models/exercise.dart';
import '../data/models/people.dart';
import '../data/rules.dart';
import '../data/seed/learn.dart';
import '../data/seed/templates.dart';
import '../theme/text_styles.dart';
import '../theme/tokens.dart';
import 'box.dart';
import 'swap_sheet.dart';
import 'tap.dart';

/// Numbered exercise list with injury flags and swaps (`exRows`), used by the
/// day sheet and the coach's trainee detail.
class ExerciseRows extends ConsumerWidget {
  const ExerciseRows({
    super.key,
    required this.trainee,
    required this.exercises,
    required this.canSwap,
    this.onHow,
    this.compact = false,
    this.swapAny = false,
  });

  final Trainee? trainee;
  final List<Exercise> exercises;
  final bool canSwap;

  /// Shows the "i" how-to button when set.
  final void Function(String name)? onHow;

  /// Coach detail sizing (14 px names, 9 px padding).
  final bool compact;

  /// Any exercise can be swapped for another one for the same muscle.
  final bool swapAny;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.read(boltProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [for (var i = 0; i < exercises.length; i++) _row(context, store, i, exercises[i])],
    );
  }

  Widget _row(BuildContext context, BoltStore store, int i, Exercise e) {
    final f = isFlagged(trainee, e);
    final t = trainee;
    final shown = t == null ? store.unit(e.load) : loadText(t, store.plan(t.id), e, metric: store.metric);
    final load = e.load.isNotEmpty && e.load != '—' ? ' · $shown' : '';
    return Container(
      padding: EdgeInsets.symmetric(vertical: compact ? 9 : 10),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: BoltColors.divider)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 16,
                child: Text(pad(i + 1), style: BoltText.m(11, color: BoltColors.muted4)),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(tx(e.name), style: BoltText.a(compact ? 14 : 15, weight: 700))),
              if (onHow != null && kHow.containsKey(e.name)) ...[
                const SizedBox(width: 10),
                Tap(
                  onTap: () => onHow!(e.name),
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
              if (swapAny && swapOptions(e, t).isNotEmpty) ...[
                const SizedBox(width: 8),
                SwapIcon(onTap: () => showSwapSheet(context, e, t), size: 24),
              ],
              const SizedBox(width: 10),
              Text('${e.sets} × ${e.reps}$load', style: BoltText.m(11, color: BoltColors.muted)),
            ],
          ),
          if (f)
            Padding(
              padding: const EdgeInsets.only(left: 26, top: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      e.alt != null
                          ? tx('{area} flag · try {alt}', {'area': tx(kAreas[e.area]!), 'alt': tx(e.alt!)})
                          : tx('{area} flag · ask your coach', {'area': tx(kAreas[e.area]!)}),
                      style: BoltText.a(12, color: BoltColors.warn),
                    ),
                  ),
                  if (canSwap && e.alt != null) ...[const SizedBox(width: 8), SwapButton(onTap: () => store.swap(e))],
                ],
              ),
            ),
          if (e.swapped)
            Padding(
              padding: const EdgeInsets.only(left: 26, top: 3),
              child: Text(
                tx('Swapped from {name}', {'name': tx(e.orig)}),
                style: BoltText.m(10, color: BoltColors.muted),
              ),
            ),
        ],
      ),
    );
  }
}

class SwapButton extends StatelessWidget {
  const SwapButton({
    super.key,
    required this.onTap,
    this.padding = const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
  });

  final VoidCallback onTap;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Tap(
      onTap: onTap,
      child: BoltBox(
        color: BoltColors.warn,
        radius: 8,
        padding: padding,
        child: Text(tx('Swap'), style: BoltText.a(12, weight: 800, color: BoltColors.ink)),
      ),
    );
  }
}
