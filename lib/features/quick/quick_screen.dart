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
import 'watch.dart';

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
                  glyph: const BoltIcon('checkin', size: 22, color: BoltColors.neon),
                  title: tx('Check in'),
                  sub: tx('No scan'),
                  onTap: () => _leave(context, (root) => openScanner(root, ref, manual: true)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _Tile(
                  glyph: const BoltIcon('scan_line', size: 22, color: BoltColors.neon),
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
            glyph: const _WatchGlyph(),
            title: tx('Stopwatch'),
            // It keeps running once started, so say so where you left it.
            sub: ref.watch(watchProvider).running ? tx('Still running') : tx('Laps, splits, no workout attached'),
            subColor: ref.watch(watchProvider).running ? BoltColors.neon : null,
            wide: true,
            onTap: () => _leave(context, (root) => root.push('/stopwatch')),
          ),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.glyph,
    required this.title,
    required this.sub,
    required this.onTap,
    this.subColor,
    this.wide = false,
  });

  final Widget glyph;
  final String title;
  final String sub;
  final VoidCallback onTap;
  final Color? subColor;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final body = [
      glyph,
      SizedBox(height: wide ? 0 : 14, width: wide ? 14 : 0),
      Expanded(
        flex: wide ? 1 : 0,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: BoltText.a(17, weight: 800)),
            const SizedBox(height: 2),
            Text(sub, style: BoltText.a(12, color: subColor ?? BoltColors.muted)),
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
        height: wide ? null : 104,
        // Square tiles: the icon at the top, the words at the bottom, no
        // empty half.
        child: wide
            ? Row(children: body)
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: body,
              ),
      ),
    );
  }
}

/// A small chronograph face with its crown, so the stopwatch tile does not
/// have to borrow the calendar icon.
class _WatchGlyph extends StatelessWidget {
  const _WatchGlyph();

  @override
  Widget build(BuildContext context) => CustomPaint(size: const Size.square(24), painter: _WatchGlyphPainter());
}

class _WatchGlyphPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final c = Offset(s.width / 2, s.height * .60);
    final r = s.width * .36;
    final p = Paint()
      ..color = BoltColors.neon
      ..style = PaintingStyle.stroke
      ..strokeWidth = s.width * .10
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(c, r, p);
    canvas.drawLine(c + Offset(0, -r * 1.25), c + Offset(0, -r * 1.75), p);
    canvas.drawLine(c, c + Offset(r * .40, -r * .40), p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
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
              const BoltIcon('bolt', size: 22, color: BoltColors.neon),
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
