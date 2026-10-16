import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../data/bolt_store.dart';
import '../../theme/text_styles.dart';
import '../../theme/tokens.dart';
import '../../widgets/common.dart';

/// A day with nothing planned: mark it as rest, or add a workout.
class FreeDaySheet extends ConsumerWidget {
  const FreeDaySheet({super.key, required this.dayKey, required this.onPlan});

  final String dayKey;
  final VoidCallback onPlan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(boltProvider);
    final store = ref.read(boltProvider.notifier);
    final rested = store.trOrNull(d.account?.id ?? '')?.stats.rest.contains(dayKey) ?? false;
    void close() => Navigator.of(context).pop();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Kicker(fmtDay(dayKey).toUpperCase(), spacing: .1),
        const SizedBox(height: 10),
        Text(
          rested ? tx('REST DAY') : tx('NOTHING PLANNED'),
          style: BoltText.a(34, weight: 900, width: 115, color: BoltColors.neon),
        ),
        const SizedBox(height: 6),
        Text(
          tx('Rest days count toward your days off. After 3 in a row, Bolt starts pushing you back to the gym.'),
          style: BoltText.a(13, color: BoltColors.muted, height: 1.45),
        ),
        const SizedBox(height: 16),
        NeonButton(
          label: rested ? tx('Clear rest day') : tx('Mark as rest day'),
          height: 52,
          scale: 1,
          onTap: () {
            store.toggleRest(dayKey);
            close();
          },
        ),
        const SizedBox(height: 8),
        OutlineButton(
          label: tx('Add a workout'),
          color: BoltColors.text,
          borderColor: BoltColors.line,
          weight: 700,
          onTap: () {
            close();
            onPlan();
          },
        ),
      ],
    );
  }
}
