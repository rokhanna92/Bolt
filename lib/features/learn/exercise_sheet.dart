import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../data/bolt_store.dart';
import '../../data/lifts.dart';
import '../../data/seed/learn.dart';
import '../../theme/text_styles.dart';
import '../../theme/tokens.dart';
import '../../widgets/box.dart';
import '../../widgets/common.dart';
import '../../widgets/tap.dart';

/// How to do an exercise: numbered cues and the common mistake.
class ExerciseSheet extends StatelessWidget {
  const ExerciseSheet({super.key, required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final h = kHow[name];
    if (h == null) return const SizedBox(height: 120);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Kicker(h.muscles.toUpperCase(), size: 10),
        const SizedBox(height: 6),
        Text(name.toUpperCase(), style: BoltText.a(30, weight: 900, width: 112, color: BoltColors.neon, height: 1)),
        Consumer(
          builder: (context, ref, _) {
            final d = ref.watch(boltProvider);
            final store = ref.read(boltProvider.notifier);
            final t = (d.account?.isTrainee ?? false) ? store.trOrNull(d.account!.id) : null;
            if (t == null || liftHistory(store.plan(t.id), name).isEmpty) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Tap(
                  onTap: () {
                    Navigator.of(context).pop();
                    rootNavigatorKey.currentContext?.push('/lift/${Uri.encodeComponent(name)}');
                  },
                  child: Text(
                    'Your progress on this lift →',
                    style: BoltText.a(13, weight: 700, color: BoltColors.neon),
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 16),
        for (var i = 0; i < h.cues.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: const BoxDecoration(color: BoltColors.neon, shape: BoxShape.circle),
                child: Text('${i + 1}', style: BoltText.m(12, weight: 700, color: BoltColors.ink, height: 1)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(h.cues[i], style: BoltText.a(14, height: 1.45)),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 16),
        BoltBox(
          radius: 14,
          color: const Color(0x0FFF7A45),
          stroke: const Stroke(Color(0x73FF7A45)),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Kicker('COMMON MISTAKE', size: 9, color: BoltColors.warn),
              const SizedBox(height: 4),
              Text(h.avoid, style: BoltText.a(13, height: 1.45)),
            ],
          ),
        ),
      ],
    );
  }
}
