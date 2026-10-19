import 'package:flutter/material.dart';

import '../core/format.dart';
import '../services/haptics.dart';
import '../theme/text_styles.dart';
import '../theme/tokens.dart';
import 'motion.dart';

/// A big moment worth stopping for: a personal record or a new level.
class Moment {
  const Moment({
    required this.kicker,
    required this.big,
    required this.unit,
    required this.title,
    this.was,
    this.sub,
    this.feel = Feel.success,
  });

  final String kicker;
  final String big;
  final String unit;
  final String title;

  /// The number it beat, shown struck through.
  final String? was;
  final String? sub;

  /// How it lands in the hand: a record swells, a level taps twice.
  final Feel feel;
}

/// Full-screen moment; tap anywhere to continue.
class MomentRoute extends PageRouteBuilder<void> {
  MomentRoute(Moment m)
    : super(
        opaque: false,
        barrierDismissible: false,
        transitionDuration: const Duration(milliseconds: 250),
        reverseTransitionDuration: const Duration(milliseconds: 200),
        pageBuilder: (context, a, s) => MomentOverlay(moment: m),
        transitionsBuilder: (context, a, s, child) => FadeTransition(opacity: a, child: child),
      );
}

class MomentOverlay extends StatefulWidget {
  const MomentOverlay({super.key, required this.moment});

  final Moment moment;

  @override
  State<MomentOverlay> createState() => _MomentOverlayState();
}

class _MomentOverlayState extends State<MomentOverlay> {
  @override
  void initState() {
    super.initState();
    Haptics.play(widget.moment.feel);
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.moment;
    return Material(
      color: const Color(0xF2050605),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.of(context).pop(),
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(m.kicker, style: BoltText.m(12, weight: 700, spacing: .2, color: BoltColors.neon)),
              const SizedBox(height: 18),
              PopIn(
                duration: const Duration(milliseconds: 550),
                child: Text(
                  m.big,
                  style: BoltText.a(96, weight: 900, width: 115, height: .95, spacing: -.03, color: BoltColors.neon),
                ),
              ),
              Text(m.unit, style: BoltText.m(12, weight: 700, spacing: .16, color: BoltColors.textSoft)),
              if (m.was != null) ...[
                const SizedBox(height: 14),
                FadeSlideIn(
                  delay: const Duration(milliseconds: 350),
                  child: Text(
                    m.was!,
                    style: BoltText.m(
                      16,
                      weight: 700,
                      color: BoltColors.muted2,
                    ).copyWith(decoration: TextDecoration.lineThrough, decorationColor: BoltColors.warn),
                  ),
                ),
              ],
              const SizedBox(height: 22),
              FadeSlideIn(
                delay: const Duration(milliseconds: 450),
                child: Text(m.title, textAlign: TextAlign.center, style: BoltText.a(26, weight: 900)),
              ),
              if (m.sub != null) ...[
                const SizedBox(height: 10),
                FadeSlideIn(
                  delay: const Duration(milliseconds: 550),
                  child: Text(
                    m.sub!,
                    textAlign: TextAlign.center,
                    style: BoltText.a(14, color: BoltColors.muted, height: 1.4),
                  ),
                ),
              ],
              const SizedBox(height: 30),
              Text(tx('Tap to continue'), style: BoltText.a(12, color: BoltColors.muted3)),
            ],
          ),
        ),
      ),
    );
  }
}
