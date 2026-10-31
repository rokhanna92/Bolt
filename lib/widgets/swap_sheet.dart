import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/format.dart';
import '../data/bolt_store.dart';
import '../data/models/exercise.dart';
import '../data/models/people.dart';
import '../data/rules.dart';
import '../theme/text_styles.dart';
import '../theme/tokens.dart';
import 'bolt_sheet.dart';
import 'common.dart';
import 'tap.dart';

/// Opens the swap picker for [e].
void showSwapSheet(BuildContext context, Exercise e, Trainee? t) =>
    showBoltSheet<void>(context, (_) => SwapSheet(e: e, trainee: t), maxHeight: .84);

/// Other exercises for the same muscle, e.g. when the machine is taken.
/// Ones that load a flagged injury are left out.
class SwapSheet extends ConsumerWidget {
  const SwapSheet({super.key, required this.e, required this.trainee});

  final Exercise e;
  final Trainee? trainee;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.read(boltProvider.notifier);
    final options = swapOptions(e, trainee);
    void pick(String name) {
      store.swapTo(e, name);
      Navigator.of(context).pop();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(tx('Swap {name}', {'name': tx(e.name)}), style: BoltText.a(20, weight: 900)),
        const SizedBox(height: 4),
        Text(
          tx('Same muscle, with its own reps and load. Exercises that load an injury flag are left out.'),
          style: BoltText.a(13, color: BoltColors.muted, height: 1.45),
        ),
        const SizedBox(height: 10),
        if (e.swapped && e.orig.isNotEmpty) ...[
          OutlineButton(
            label: tx('Back to {name}', {'name': tx(e.orig)}),
            height: 44,
            radius: 12,
            fontSize: 13,
            onTap: () => pick(e.orig),
          ),
          const SizedBox(height: 6),
        ],
        if (options.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(tx('No other exercises for this muscle.'), style: BoltText.a(13, color: BoltColors.muted)),
          ),
        for (final o in options)
          Tap(
            onTap: () => pick(o.name),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: BoltColors.divider)),
              ),
              child: Row(
                children: [
                  Expanded(child: Text(tx(o.name), style: BoltText.a(15, weight: 700))),
                  Text(
                    '${o.sets} × ${o.reps}${o.load.isEmpty || o.load == '—' ? '' : ' · ${store.unit(o.load)}'}',
                    style: BoltText.m(11, color: BoltColors.muted),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Small swap button that opens the swap picker.
class SwapIcon extends StatelessWidget {
  const SwapIcon({super.key, required this.onTap, this.size = 28});

  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) => CircleIconButton(
    onTap: onTap,
    size: size,
    label: tx('Swap exercise'),
    child: BoltIcon('swap', size: size * .52, color: BoltColors.neon),
  );
}
