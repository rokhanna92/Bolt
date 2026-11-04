import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../data/bolt_store.dart';
import '../../data/seed/learn.dart';
import '../../services/haptics.dart';
import '../../theme/text_styles.dart';
import '../../theme/tokens.dart';
import '../../widgets/box.dart';
import '../../widgets/common.dart';
import '../../widgets/forms.dart';
import '../../widgets/tap.dart';
import '../../widgets/time_wheel.dart';

/// Reminders that repeat every day: a cup of water every few hours, and each
/// daily supplement at its own time.
class DailyRemindersSheet extends ConsumerWidget {
  const DailyRemindersSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(boltProvider).settings;
    final store = ref.read(boltProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(tx('Daily reminders'), style: BoltText.a(20, weight: 900)),
        const SizedBox(height: 16),
        Tap(
          onTap: () {
            Haptics.play(s.water ? Feel.off : Feel.on);
            store.toggleSetting('water');
          },
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tx('Water'), style: BoltText.a(15, weight: 800)),
                    const SizedBox(height: 2),
                    Text(
                      tx('A cup of water every {time}, from 09:00 to 21:00', {'time': spanText(s.waterHours * 60)}),
                      style: BoltText.a(12, color: BoltColors.muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              BoltSwitch(on: s.water),
            ],
          ),
        ),
        if (s.water) ...[
          const SizedBox(height: 10),
          ChoiceChips(
            options: const ['1', '2', '3', '4'],
            labels: {
              for (final h in const [1, 2, 3, 4]) '$h': spanText(h * 60),
            },
            selected: '${s.waterHours}',
            onSelect: (h) => store.setWaterHours(int.parse(h)),
          ),
        ],
        const SizedBox(height: 22),
        Text(tx('Supplements'), style: BoltText.a(15, weight: 800)),
        const SizedBox(height: 2),
        Text(
          tx('Pick what you take every day, then tap a time to change it.'),
          style: BoltText.a(12, color: BoltColors.muted),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final name in kDailySupplements)
              Tap(
                onTap: () {
                  Haptics.play(Feel.tick);
                  store.toggleSupp(name);
                },
                child: BoltBox(
                  radius: 99,
                  color: s.supps.containsKey(name) ? BoltColors.neon : BoltColors.surface2,
                  stroke: Stroke(s.supps.containsKey(name) ? BoltColors.neon : BoltColors.line),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  child: Text(
                    tx(name),
                    style: BoltText.a(
                      13,
                      weight: 700,
                      color: s.supps.containsKey(name) ? BoltColors.ink : BoltColors.text,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        for (final name in kDailySupplements)
          if (s.supps[name] case final minute?)
            Tap(
              onTap: () async {
                final v = await pickTime(context, minute, title: tx(name));
                if (v != null) store.setSuppTime(name, v);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  children: [
                    Expanded(child: Text(tx(name), style: BoltText.a(14, weight: 700))),
                    Text(fromMin(minute), style: BoltText.m(15, weight: 700, color: BoltColors.neon)),
                  ],
                ),
              ),
            ),
      ],
    );
  }
}
