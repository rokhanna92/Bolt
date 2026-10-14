import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/bolt_store.dart';
import '../../data/rules.dart';
import '../../data/seed/badges.dart';
import '../../theme/text_styles.dart';
import '../../theme/tokens.dart';
import '../../widgets/badge_medal.dart';
import '../../widgets/box.dart';
import '../../widgets/common.dart';
import '../../widgets/motion.dart';

class BadgesScreen extends ConsumerWidget {
  const BadgesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(boltProvider);
    final store = ref.read(boltProvider.notifier);
    final t = store.trOrNull(d.account?.id ?? '');
    if (t == null) return const SizedBox.shrink();
    final stats = displayStats(t.stats, store.now);
    double pct(BadgeDef b) => (stats.value(b.key) / b.goal).clamp(0.0, 1.0);
    bool on(BadgeDef b) => stats.value(b.key) >= b.goal;
    final count = kBadges.where(on).length;
    // Closest locked badge; the first one wins ties, like the prototype's
    // stable sort.
    BadgeDef? next;
    for (final b in kBadges.where((b) => !on(b))) {
      if (next == null || pct(b) > pct(next)) next = b;
    }

    return ScreenScroll(
      children: [
        const Kicker('ACHIEVEMENTS'),
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Expanded(child: Text('Trophy rack', style: BoltText.a(30, weight: 900, width: 112, spacing: -.02))),
            Text('$count / ${kBadges.length}', style: BoltText.m(14, weight: 700, color: BoltColors.neon)),
          ],
        ),
        if (next != null) ...[
          const SizedBox(height: 16),
          BoltBox(
            color: BoltColors.surface1,
            stroke: const Stroke(BoltColors.lineSoft),
            radius: 18,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Kicker('CLOSEST · ${badgeLeftText(next, stats).toUpperCase()}', size: 10),
                const SizedBox(height: 8),
                Text(next.name, style: BoltText.a(18, weight: 800)),
                const SizedBox(height: 8),
                Text(next.desc, style: BoltText.a(13, color: BoltColors.muted)),
                const SizedBox(height: 12),
                _Progress(value: pct(next), height: 8, fill: BoltColors.neon),
              ],
            ),
          ),
        ],
        const SizedBox(height: 20),
        for (var r = 0; r < kBadges.length; r += 3) ...[
          if (r > 0) const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = r; i < r + 3; i++) ...[
                if (i > r) const SizedBox(width: 10),
                Expanded(
                  child: i < kBadges.length
                      ? _cell(kBadges[i], on(kBadges[i]), stats.value(kBadges[i].key), pct(kBadges[i]))
                      : const SizedBox(),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }

  Widget _cell(BadgeDef b, bool on, int v, double pct) {
    return PopIn(
      child: Column(
        children: [
          BadgeMedal(badge: b, on: on),
          const SizedBox(height: 8),
          Text(
            b.name,
            textAlign: TextAlign.center,
            style: BoltText.a(12, weight: 800, color: on ? BoltColors.text : BoltColors.muted),
          ),
          if (!on) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: 64,
              child: _Progress(value: pct, height: 3, fill: BoltColors.muted2),
            ),
            const SizedBox(height: 8),
            Text('${v < b.goal ? v : b.goal} / ${b.goal}', style: BoltText.m(9, color: BoltColors.muted3)),
          ],
        ],
      ),
    );
  }
}

class _Progress extends StatelessWidget {
  const _Progress({required this.value, required this.height, required this.fill});

  final double value;
  final double height;
  final Color fill;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(99),
      child: Container(
        height: height,
        color: BoltColors.lineSoft,
        alignment: Alignment.centerLeft,
        child: GrowTo(
          value: value,
          builder: (context, v) => FractionallySizedBox(
            widthFactor: v,
            heightFactor: 1,
            child: DecoratedBox(
              decoration: BoxDecoration(color: fill, borderRadius: BorderRadius.circular(99)),
            ),
          ),
        ),
      ),
    );
  }
}
