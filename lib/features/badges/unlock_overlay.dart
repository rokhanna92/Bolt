import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';

import '../../data/seed/badges.dart';
import '../../services/haptics.dart';
import '../../theme/text_styles.dart';
import '../../theme/tokens.dart';
import '../../widgets/badge_medal.dart';
import '../../widgets/motion.dart';

/// "Badge unlocked" overlay; tap anywhere to continue. Several badges from
/// one action share one screen instead of a tap each.
class UnlockRoute extends PageRouteBuilder<void> {
  UnlockRoute(List<String> ids)
    : super(
        opaque: false,
        barrierDismissible: false,
        transitionDuration: const Duration(milliseconds: 300),
        reverseTransitionDuration: const Duration(milliseconds: 200),
        pageBuilder: (context, a, s) {
          final badges = [for (final id in ids) kBadges.firstWhere((b) => b.id == id)];
          return badges.length == 1 ? UnlockOverlay(badge: badges.single) : UnlockManyOverlay(badges: badges);
        },
        transitionsBuilder: (context, a, s, child) => FadeTransition(opacity: a, child: child),
      );
}

/// Two or more badges at once: each medal with its name, rising in turn.
class UnlockManyOverlay extends StatefulWidget {
  const UnlockManyOverlay({super.key, required this.badges});

  final List<BadgeDef> badges;

  @override
  State<UnlockManyOverlay> createState() => _UnlockManyOverlayState();
}

class _UnlockManyOverlayState extends State<UnlockManyOverlay> {
  @override
  void initState() {
    super.initState();
    Haptics.play(Feel.success);
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.badges;
    return Material(
      color: const Color(0xEB050605),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.of(context).pop(),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(30),
            child: Column(
              children: [
                Text(
                  tx('{badges} UNLOCKED', {'badges': plural(b.length, 'badge').toUpperCase()}),
                  style: BoltText.m(11, spacing: .16, color: BoltColors.neon),
                ),
                const SizedBox(height: 22),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 18,
                  children: [
                    for (var i = 0; i < b.length; i++)
                      FadeSlideIn(
                        delay: Duration(milliseconds: 80 * math.min(i, 8)),
                        child: SizedBox(
                          width: 100,
                          child: Column(
                            children: [
                              BadgeMedal(badge: b[i], on: true),
                              const SizedBox(height: 8),
                              Text(
                                tx(b[i].name),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: BoltText.a(13, weight: 800),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 28),
                Text(tx('Tap to continue'), style: BoltText.a(12, color: BoltColors.muted3)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class UnlockOverlay extends StatefulWidget {
  const UnlockOverlay({super.key, required this.badge});

  final BadgeDef badge;

  @override
  State<UnlockOverlay> createState() => _UnlockOverlayState();
}

class _UnlockOverlayState extends State<UnlockOverlay> with SingleTickerProviderStateMixin {
  late final _spin = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..forward();

  @override
  void initState() {
    super.initState();
    Haptics.play(Feel.success);
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.badge;
    return Material(
      color: const Color(0xEB050605),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.of(context).pop(),
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(tx('BADGE UNLOCKED'), style: BoltText.m(11, spacing: .16, color: BoltColors.neon)),
              const SizedBox(height: 18),
              AnimatedBuilder(
                animation: _spin,
                builder: (context, child) {
                  // vSpin: -220deg at .2 -> 14deg at 1.06 (70 %) -> rest.
                  final t = const Cubic(.2, .8, .2, 1).transform(_spin.value);
                  double deg, scale, op;
                  if (t < .7) {
                    final k = t / .7;
                    deg = -220 + 234 * k;
                    scale = .2 + .86 * k;
                    op = k;
                  } else {
                    final k = (t - .7) / .3;
                    deg = 14 * (1 - k);
                    scale = 1.06 - .06 * k;
                    op = 1;
                  }
                  return Opacity(
                    opacity: op.clamp(0, 1),
                    child: Transform.rotate(
                      angle: deg * math.pi / 180,
                      child: Transform.scale(scale: scale, child: child),
                    ),
                  );
                },
                child: Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    color: BoltColors.ink,
                    shape: BoxShape.circle,
                    border: Border.all(color: BoltColors.neon, width: 5),
                    boxShadow: const [BoxShadow(color: Color(0x73C6FF1A), blurRadius: 70)],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Positioned.fill(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: const Color(0x73C6FF1A), width: 1.5),
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        // Inside the inner ring, so words like "WKND" shrink instead of wrapping.
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                tx(b.big),
                                maxLines: 1,
                                style: BoltText.a(42, weight: 900, width: 115, color: BoltColors.neon, height: 1),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(tx(b.unit), style: BoltText.m(10, spacing: .14, color: BoltColors.textSoft)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              FadeSlideIn(
                delay: const Duration(milliseconds: 400),
                duration: const Duration(milliseconds: 400),
                child: Text(tx(b.name), style: BoltText.a(28, weight: 900)),
              ),
              const SizedBox(height: 18),
              FadeSlideIn(
                delay: const Duration(milliseconds: 500),
                duration: const Duration(milliseconds: 400),
                child: Text(
                  tx(b.desc),
                  textAlign: TextAlign.center,
                  style: BoltText.a(14, color: BoltColors.muted),
                ),
              ),
              const SizedBox(height: 28),
              Text(tx('Tap to continue'), style: BoltText.a(12, color: BoltColors.muted3)),
            ],
          ),
        ),
      ),
    );
  }
}
