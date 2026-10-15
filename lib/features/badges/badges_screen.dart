import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/l10n.dart';

import '../../data/bolt_store.dart';
import '../../data/models/people.dart';
import '../../data/rules.dart';
import '../../data/seed/badges.dart';
import '../../theme/text_styles.dart';
import '../../theme/tokens.dart';
import '../../widgets/badge_medal.dart';
import '../../widgets/box.dart';
import '../../widgets/common.dart';
import '../../widgets/motion.dart';
import '../../widgets/tap.dart';

/// The trophy rack: every badge, earned or not. Opened from Today.
class BadgesScreen extends ConsumerWidget {
  const BadgesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(boltProvider);
    final store = ref.read(boltProvider.notifier);
    final t = store.trOrNull(d.account?.id ?? '');
    if (t == null) return const BoltPage(child: SizedBox.expand());
    final stats = displayStats(t.stats, store.now);
    double pct(BadgeDef b) => badgeProgress(b, stats);
    bool on(BadgeDef b) => badgeEarned(b, stats);
    final count = kBadges.where(on).length;
    final next = lockedByCloseness(stats).firstOrNull;

    return BoltPage(
      child: ScreenScroll(
        bottom: 40,
        children: [
          Row(
            children: [
              BackBox(onTap: () => context.pop()),
              const SizedBox(width: 12),
              Kicker(tx('ACHIEVEMENTS')),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(child: Text(tx('Trophy rack'), style: BoltText.a(30, weight: 900, width: 112, spacing: -.02))),
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
                  Kicker('${tx('CLOSEST')} · ${badgeLeftText(next, stats).toUpperCase()}', size: 10),
                  const SizedBox(height: 8),
                  Text(tx(next.name), style: BoltText.a(18, weight: 800)),
                  const SizedBox(height: 8),
                  Text(tx(next.desc), style: BoltText.a(13, color: BoltColors.muted)),
                  const SizedBox(height: 12),
                  _Progress(value: pct(next), height: 8, fill: BoltColors.neon),
                ],
              ),
            ),
          ],
          for (final (key, title) in kBadgeSections)
            if (kBadges.any((b) => b.key == key)) ..._section(title, _sorted(key), stats, on, pct),
        ],
      ),
    );
  }

  /// Badges on one counter, smallest goal first.
  List<BadgeDef> _sorted(String key) => kBadges.where((b) => b.key == key).toList()..sort((a, b) => a.goal - b.goal);

  List<Widget> _section(
    String title,
    List<BadgeDef> list,
    TraineeStats stats,
    bool Function(BadgeDef) on,
    double Function(BadgeDef) pct,
  ) => [
    const SizedBox(height: 26),
    Row(
      children: [
        Expanded(child: Kicker(tx(title).toUpperCase(), size: 10, spacing: .1)),
        Text('${list.where(on).length} / ${list.length}', style: BoltText.m(10, color: BoltColors.muted)),
      ],
    ),
    const SizedBox(height: 14),
    for (var r = 0; r < list.length; r += 3) ...[
      if (r > 0) const SizedBox(height: 18),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = r; i < r + 3; i++) ...[
            if (i > r) const SizedBox(width: 10),
            Expanded(
              child: i < list.length
                  ? _cell(list[i], on(list[i]), stats.value(list[i].key), pct(list[i]))
                  : const SizedBox(),
            ),
          ],
        ],
      ),
    ],
  ];

  Widget _cell(BadgeDef b, bool on, int v, double pct) {
    return PopIn(
      child: Column(
        children: [
          BadgeMedal(badge: b, on: on),
          const SizedBox(height: 8),
          Text(
            tx(b.name),
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

/// Badges at a glance: how many are earned, a strip of medals and the
/// closest one to go. On Today it opens the trophy rack; a coach sees one
/// per trainee.
class BadgesCard extends StatelessWidget {
  const BadgesCard({super.key, required this.stats, this.onTap});

  /// As shown on badges, see [displayStats].
  final TraineeStats stats;
  final VoidCallback? onTap;

  static const _strip = 5;

  @override
  Widget build(BuildContext context) {
    final earned = kBadges.where((b) => badgeEarned(b, stats)).toList();
    final locked = lockedByCloseness(stats);
    final next = locked.firstOrNull;
    // The furthest earned medals, topped up with the closest locked ones.
    final shown = [
      ...earned.skip(earned.length > _strip ? earned.length - _strip : 0),
      ...locked.take(_strip - (earned.length > _strip ? _strip : earned.length)),
    ];
    final card = BoltBox(
      color: BoltColors.surface1,
      stroke: const Stroke(BoltColors.lineSoft),
      radius: 20,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Kicker(tx('ACHIEVEMENTS'), size: 10)),
              Text('${earned.length} / ${kBadges.length}', style: BoltText.m(13, weight: 700, color: BoltColors.neon)),
              if (onTap != null) ...[const SizedBox(width: 6), const Chevron(size: 18)],
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (final (i, b) in shown.indexed) ...[
                if (i > 0) const SizedBox(width: 6),
                Expanded(
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: FittedBox(
                      child: BadgeMedal(badge: b, on: badgeEarned(b, stats)),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          if (next == null)
            Text(tx('Every badge earned.'), style: BoltText.a(13, weight: 700, color: BoltColors.neon))
          else ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Expanded(
                  child: Text(
                    tx('Next: {what}', {'what': tx(next.name)}),
                    overflow: TextOverflow.ellipsis,
                    style: BoltText.a(13, weight: 700),
                  ),
                ),
                const SizedBox(width: 8),
                Text(badgeLeftText(next, stats), style: BoltText.m(10, color: BoltColors.muted)),
              ],
            ),
            const SizedBox(height: 8),
            _Progress(value: badgeProgress(next, stats), height: 6, fill: BoltColors.neon),
          ],
        ],
      ),
    );
    return onTap == null ? card : Tap(onTap: onTap, scale: .98, child: card);
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
