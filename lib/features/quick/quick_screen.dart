import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/actions.dart';
import '../../app/router.dart';
import '../../core/format.dart';
import '../../theme/text_styles.dart';
import '../../theme/tokens.dart';
import '../../widgets/box.dart';
import '../../widgets/common.dart';
import '../../widgets/tap.dart';

/// The centre button's hub: check in by hand or by QR, start a workout on the
/// spot, or run the stopwatch. One tap from the nav bar to any of them.
class QuickScreen extends ConsumerWidget {
  const QuickScreen({super.key});

  /// Closes the hub, then runs [go] against the root navigator. The hub's
  /// own context is gone once it pops, so the next screen cannot use it.
  void _leave(BuildContext context, void Function(BuildContext root) go) {
    final root = rootNavigatorKey.currentContext!;
    context.pop();
    go(root);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return BoltPage(
      child: ScreenScroll(
        top: 16,
        bottom: 40,
        stagger: true,
        children: [
          Row(
            children: [
              BackBox(onTap: () => context.pop()),
              const SizedBox(width: 12),
              Kicker(tx('QUICK')),
            ],
          ),
          const SizedBox(height: 14),
          Text(tx('What now?'), style: BoltText.a(30, weight: 900, width: 112, spacing: -.02)),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _Tile(
                  icon: 'check',
                  title: tx('Check in'),
                  sub: tx('No scan'),
                  onTap: () => _leave(context, (root) => openScanner(root, ref, manual: true)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _Tile(
                  icon: 'scan',
                  title: tx('Scan QR'),
                  sub: tx('Gym plaque'),
                  onTap: () => _leave(context, (root) => openScanner(root, ref)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _FastWorkout(onPick: (cardio) => _leave(context, (_) => startFastWorkout(cardio: cardio))),
          const SizedBox(height: 10),
          _Tile(
            icon: 'schedule',
            title: tx('Stopwatch'),
            sub: tx('Laps, splits, no workout attached'),
            wide: true,
            onTap: () => _leave(context, (root) => root.push('/stopwatch')),
          ),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.icon, required this.title, required this.sub, required this.onTap, this.wide = false});

  final String icon;
  final String title;
  final String sub;
  final VoidCallback onTap;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final body = [
      BoltIcon(icon, size: 22, color: BoltColors.neon),
      SizedBox(height: wide ? 0 : 14, width: wide ? 14 : 0),
      Expanded(
        flex: wide ? 1 : 0,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: BoltText.a(17, weight: 800)),
            const SizedBox(height: 2),
            Text(sub, style: BoltText.a(12, color: BoltColors.muted)),
          ],
        ),
      ),
    ];
    return Tap(
      onTap: onTap,
      child: BoltBox(
        color: BoltColors.surface1,
        stroke: const Stroke(BoltColors.line),
        radius: BoltRadii.card,
        padding: const EdgeInsets.all(16),
        height: wide ? null : 136,
        child: wide
            ? Row(children: body)
            : Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: body),
      ),
    );
  }
}

/// Start training now: an engine day or weights, picked right on the tile.
class _FastWorkout extends StatelessWidget {
  const _FastWorkout({required this.onPick});

  final ValueChanged<bool> onPick;

  @override
  Widget build(BuildContext context) {
    Widget pill(String label, bool cardio) => Expanded(
      child: Tap(
        onTap: () => onPick(cardio),
        child: BoltBox(
          color: BoltColors.surface2,
          stroke: const Stroke(BoltColors.line),
          radius: BoltRadii.pill,
          height: 46,
          alignment: Alignment.center,
          child: Text(label, style: BoltText.a(14, weight: 800)),
        ),
      ),
    );

    return BoltBox(
      color: BoltColors.surface1,
      stroke: const Stroke(BoltColors.line),
      radius: BoltRadii.card,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const BoltIcon('barbell', size: 22, color: BoltColors.neon),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tx('Fast workout'), style: BoltText.a(17, weight: 800)),
                    const SizedBox(height: 2),
                    Text(tx('Starts on today, nothing planned needed'), style: BoltText.a(12, color: BoltColors.muted)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(children: [pill(tx('Cardio'), true), const SizedBox(width: 10), pill(tx('Weights'), false)]),
        ],
      ),
    );
  }
}
