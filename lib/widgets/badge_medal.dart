import 'package:flutter/material.dart';

import '../data/seed/badges.dart';
import '../theme/text_styles.dart';
import '../theme/tokens.dart';

/// Colors for one medal (`ON_PAL` / `OFF_PAL` in the prototype).
class MedalPalette {
  const MedalPalette({
    required this.fill,
    required this.rim,
    required this.ring,
    required this.hub,
    required this.ink,
    required this.ink2,
    this.glow,
    this.hexGlow = false,
  });

  final Color fill;
  final Color rim;
  final Color ring;
  final Color hub;
  final Color ink;
  final Color ink2;
  final BoxShadow? glow;
  final bool hexGlow;

  static MedalPalette of(BadgeShape shape, bool on) {
    if (!on) {
      return const MedalPalette(
        fill: BoltColors.surface1,
        rim: BoltColors.line,
        ring: BoltColors.lineFaint,
        hub: BoltColors.surface2,
        ink: BoltColors.muted2,
        ink2: BoltColors.muted4,
      );
    }
    return switch (shape) {
      BadgeShape.plate => const MedalPalette(
        fill: BoltColors.ink,
        rim: BoltColors.neon,
        ring: Color(0x73C6FF1A),
        hub: BoltColors.surface1,
        ink: BoltColors.neon,
        ink2: BoltColors.textSoft,
        glow: BoxShadow(color: Color(0x47C6FF1A), blurRadius: 22),
      ),
      BadgeShape.kb => const MedalPalette(
        fill: BoltColors.neon,
        rim: BoltColors.neon,
        ring: Colors.transparent,
        hub: Colors.transparent,
        ink: BoltColors.ink,
        ink2: BoltColors.ink,
        glow: BoxShadow(color: Color(0x4DC6FF1A), blurRadius: 22),
      ),
      BadgeShape.hex => const MedalPalette(
        fill: BoltColors.ink,
        rim: BoltColors.neon,
        ring: Colors.transparent,
        hub: Colors.transparent,
        ink: BoltColors.neon,
        ink2: BoltColors.textSoft,
        hexGlow: true,
      ),
    };
  }
}

/// A badge in one of three gym shapes: weight plate (sessions), kettlebell
/// (hours and streaks) or hex dumbbell head (special).
class BadgeMedal extends StatelessWidget {
  const BadgeMedal({super.key, required this.badge, required this.on});

  final BadgeDef badge;
  final bool on;

  @override
  Widget build(BuildContext context) {
    final p = MedalPalette.of(badge.shape, on);
    return SizedBox(
      width: 92,
      height: 92,
      child: Center(
        child: switch (badge.shape) {
          BadgeShape.plate => _plate(p),
          BadgeShape.kb => _kettlebell(p),
          BadgeShape.hex => _hex(p),
        },
      ),
    );
  }

  Widget _labels(MedalPalette p, double big, double unitSpacing, {double topGap = 0}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (topGap > 0) SizedBox(height: topGap),
        Text(badge.big, style: BoltText.a(big, weight: 900, width: 115, color: p.ink, height: 1)),
        const SizedBox(height: 3),
        Text(
          badge.unit,
          style: BoltText.m(7, color: p.ink2, spacing: unitSpacing),
        ),
      ],
    );
  }

  Widget _plate(MedalPalette p) {
    return Container(
      width: 84,
      height: 84,
      decoration: BoxDecoration(
        color: p.fill,
        shape: BoxShape.circle,
        border: Border.all(color: p.rim, width: 3),
        boxShadow: p.glow == null ? null : [p.glow!],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.all(7),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: p.ring),
                ),
              ),
            ),
          ),
          Positioned(
            top: 9,
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: p.hub,
                shape: BoxShape.circle,
                border: Border.all(color: p.ring),
              ),
            ),
          ),
          _labels(p, 24, .12, topGap: 6),
        ],
      ),
    );
  }

  Widget _kettlebell(MedalPalette p) {
    return SizedBox(
      width: 84,
      height: 88,
      child: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            child: CustomPaint(size: const Size(84, 40), painter: _HandlePainter(p.rim)),
          ),
          Positioned(
            bottom: 0,
            left: 7,
            child: CustomPaint(
              painter: _BellPainter(p),
              child: SizedBox(width: 70, height: 62, child: Center(child: _labels(p, 20, .12))),
            ),
          ),
        ],
      ),
    );
  }

  Widget _hex(MedalPalette p) {
    return SizedBox(
      width: 86,
      height: 86,
      child: CustomPaint(
        painter: _HexPainter(p),
        child: Center(child: _labels(p, 21, .1)),
      ),
    );
  }
}

class _HandlePainter extends CustomPainter {
  _HandlePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(24, 34)
      ..cubicTo(22, 8, 62, 8, 60, 34);
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_HandlePainter old) => old.color != color;
}

/// `border-radius: 50% 50% 44% 44%` body with a 3 px rim.
class _BellPainter extends CustomPainter {
  _BellPainter(this.p);

  final MedalPalette p;

  RRect _shape(Rect r) => RRect.fromRectAndCorners(
    r,
    topLeft: Radius.elliptical(r.width * .5, r.height * .5),
    topRight: Radius.elliptical(r.width * .5, r.height * .5),
    bottomLeft: Radius.elliptical(r.width * .44, r.height * .44),
    bottomRight: Radius.elliptical(r.width * .44, r.height * .44),
  );

  @override
  void paint(Canvas canvas, Size size) {
    final outer = _shape(Offset.zero & size);
    if (p.glow != null) {
      canvas.drawRRect(
        outer,
        Paint()
          ..color = p.glow!.color
          ..maskFilter = MaskFilter.blur(BlurStyle.outer, p.glow!.blurSigma),
      );
    }
    canvas.drawRRect(outer, Paint()..color = p.fill);
    canvas.drawRRect(
      _shape((Offset.zero & size).deflate(1.5)),
      Paint()
        ..color = p.rim
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
  }

  @override
  bool shouldRepaint(_BellPainter old) => old.p != p;
}

class _HexPainter extends CustomPainter {
  _HexPainter(this.p);

  final MedalPalette p;

  Path _poly(List<double> pts) {
    final path = Path()..moveTo(pts[0], pts[1]);
    for (var i = 2; i < pts.length; i += 2) {
      path.lineTo(pts[i], pts[i + 1]);
    }
    return path..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final outer = _poly(const [43, 4, 77, 23.5, 77, 62.5, 43, 82, 9, 62.5, 9, 23.5]);
    if (p.hexGlow) {
      canvas.drawPath(
        outer,
        Paint()
          ..color = const Color(0x59C6FF1A)
          ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 6),
      );
    }
    canvas.drawPath(outer, Paint()..color = p.fill);
    canvas.drawPath(
      outer,
      Paint()
        ..color = p.rim
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawPath(
      _poly(const [43, 13, 69, 28, 69, 58, 43, 73, 17, 58, 17, 28]),
      Paint()
        ..color = p.rim.withValues(alpha: .45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(_HexPainter old) => old.p != p;
}
