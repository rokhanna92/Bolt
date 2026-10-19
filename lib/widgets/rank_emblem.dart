import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/rank.dart';
import '../theme/tokens.dart';

/// Colours per tier, dark then light, for the emblem's metal.
const _metal = <(Color, Color)>[
  (BoltColors.line, BoltColors.muted3),
  (Color(0xFF6E7B8A), Color(0xFFAEBACB)),
  (Color(0xFF8E5129), Color(0xFFE09A5E)),
  (Color(0xFF454B52), Color(0xFF8D959F)),
  (Color(0xFF557189), Color(0xFFB2CBE0)),
  (Color(0xFF8F98A3), Color(0xFFF1F4F7)),
  (Color(0xFFB57F12), Color(0xFFFFDD6E)),
  (Color(0xFF1F9C86), Color(0xFF94F5E1)),
  (Color(0xFF4F6EF0), Color(0xFFCDB0FF)),
  (Color(0xFF8E1736), Color(0xFFFF5470)),
  (Color(0xFF7FB000), BoltColors.neon),
  (Color(0xFF00E5FF), BoltColors.neon),
];

/// Atlas shifts through neon green, electric cyan and magenta.
const kAtlasNeon = [BoltColors.neon, Color(0xFF00F0FF), Color(0xFFFF2BD6), BoltColors.neon];

/// The colour a tier is known by, for text next to its emblem.
Color tierColor(int tier) => _metal[tier.clamp(0, _metal.length - 1)].$2;

/// A rank's badge. The shape grows with the tier: a plate for Plastic to
/// Iron, a hexagon for Steel to Gold, a cut gem for Platinum to Immortal, a
/// star for Olympia and the sky's globe for Atlas, each with Bolt's
/// lightning in the middle and one to three pips for the division.
/// Bodyweight is an empty ring. A big Atlas emblem slowly turns its neon.
class RankEmblem extends StatefulWidget {
  const RankEmblem({super.key, required this.step, this.size = 56});

  final int step;
  final double size;

  @override
  State<RankEmblem> createState() => _RankEmblemState();
}

class _RankEmblemState extends State<RankEmblem> with SingleTickerProviderStateMixin {
  AnimationController? _spin;

  bool get _live => widget.step >= kAtlas && widget.size >= 100;

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(RankEmblem old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    if (_live && _spin == null) {
      _spin = AnimationController(vsync: this, duration: const Duration(seconds: 6))..repeat();
    } else if (!_live && _spin != null) {
      _spin!.dispose();
      _spin = null;
    }
  }

  @override
  void dispose() {
    _spin?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    width: widget.size,
    height: widget.size,
    child: CustomPaint(painter: _EmblemPainter(widget.step, _spin)),
  );
}

class _EmblemPainter extends CustomPainter {
  _EmblemPainter(this.step, this.spin) : super(repaint: spin);

  final int step;

  /// Turns Atlas's neon, 0 to 1; null stands still.
  final Animation<double>? spin;

  @override
  void paint(Canvas canvas, Size size) {
    final tier = tierOf(step), div = divisionOf(step);
    final s = size.width;
    final c = Offset(s / 2, s * .44);
    final r = s * .38;
    final (dark, light) = _metal[tier];

    if (tier == kTiers.length - 1) return _atlas(canvas, s, c, r);
    if (tier == 0) {
      canvas.drawCircle(
        c,
        r * .9,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * .05
          ..color = BoltColors.line,
      );
      canvas.drawCircle(c, r * .22, Paint()..color = BoltColors.muted3);
      return;
    }

    final Path shape;
    if (tier <= 3) {
      shape = Path()..addOval(Rect.fromCircle(center: c, radius: r));
    } else if (tier <= 6) {
      shape = _poly(c, r * 1.05, 6, -math.pi / 2);
    } else if (tier <= 9) {
      shape = Path()
        ..moveTo(c.dx, c.dy - r * 1.12)
        ..lineTo(c.dx + r * .95, c.dy - r * .3)
        ..lineTo(c.dx + r * .62, c.dy + r * .78)
        ..lineTo(c.dx, c.dy + r * 1.1)
        ..lineTo(c.dx - r * .62, c.dy + r * .78)
        ..lineTo(c.dx - r * .95, c.dy - r * .3)
        ..close();
    } else {
      shape = _star(c, r * 1.15, r * .72, 8);
      canvas.drawPath(
        shape,
        Paint()
          ..color = BoltColors.neon.withValues(alpha: .45)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * .08),
      );
    }

    final fill = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [light, dark],
      ).createShader(Rect.fromCircle(center: c, radius: r * 1.2));
    canvas.drawPath(shape, fill);
    canvas.drawPath(
      shape,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * .025
        ..color = BoltColors.ink.withValues(alpha: .55),
    );

    // An inner ring like a plate's lip, or a facet line on the gems.
    if (tier <= 3) {
      canvas.drawCircle(
        c,
        r * .74,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * .02
          ..color = BoltColors.ink.withValues(alpha: .35),
      );
    } else if (tier <= 6) {
      canvas.drawPath(
        _poly(c, r * .8, 6, -math.pi / 2),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * .02
          ..color = BoltColors.ink.withValues(alpha: .3),
      );
    } else if (tier <= 9) {
      canvas.drawLine(
        Offset(c.dx - r * .95, c.dy - r * .3),
        Offset(c.dx + r * .95, c.dy - r * .3),
        Paint()
          ..strokeWidth = s * .018
          ..color = Colors.white.withValues(alpha: .35),
      );
    }

    // Bolt's lightning.
    final b = r * .5;
    final bolt = Path()
      ..moveTo(c.dx + b * .25, c.dy - b * 1.05)
      ..lineTo(c.dx - b * .55, c.dy + b * .12)
      ..lineTo(c.dx - b * .02, c.dy + b * .12)
      ..lineTo(c.dx - b * .25, c.dy + b * 1.05)
      ..lineTo(c.dx + b * .55, c.dy - b * .12)
      ..lineTo(c.dx + b * .02, c.dy - b * .12)
      ..close();
    canvas.drawPath(bolt, Paint()..color = BoltColors.ink.withValues(alpha: .85));

    // Division pips under the shape.
    if (div > 0) {
      final w = s * .09, gap = s * .05, y = s * .92;
      final x0 = s / 2 - (3 * w + 2 * gap) / 2;
      for (var i = 0; i < 3; i++) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(x0 + i * (w + gap), y - s * .025, w, s * .05), Radius.circular(s)),
          Paint()..color = i < div ? light : BoltColors.line,
        );
      }
    }
  }

  /// Atlas holds up the sky: a neon globe with its meridians, a burst of
  /// rays behind it and the lightning across it.
  void _atlas(Canvas canvas, double s, Offset c, double r) {
    final turn = (spin?.value ?? 0) * 2 * math.pi;
    final sweep = SweepGradient(colors: kAtlasNeon, transform: GradientRotation(turn));
    final box = Rect.fromCircle(center: c, radius: r * 1.3);
    // Glow, then a 12-ray burst.
    canvas.drawCircle(
      c,
      r * 1.15,
      Paint()
        ..shader = sweep.createShader(box)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * .1),
    );
    canvas.drawPath(_star(c, r * 1.28, r * .95, 12), Paint()..shader = sweep.createShader(box));
    // The globe, dark inside so the lines glow.
    canvas.drawCircle(c, r * .9, Paint()..color = BoltColors.ink);
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * .022
      ..shader = sweep.createShader(box);
    canvas.drawCircle(c, r * .9, line..strokeWidth = s * .03);
    line.strokeWidth = s * .018;
    for (final k in [.35, .7]) {
      canvas.drawOval(Rect.fromCenter(center: c, width: r * 1.8 * k, height: r * 1.8), line);
    }
    canvas.drawLine(Offset(c.dx, c.dy - r * .9), Offset(c.dx, c.dy + r * .9), line);
    for (final y in [-.45, 0.0, .45]) {
      final half = r * .9 * math.sqrt(1 - y * y);
      canvas.drawLine(Offset(c.dx - half, c.dy + y * r * .9), Offset(c.dx + half, c.dy + y * r * .9), line);
    }
    final b = r * .55;
    final bolt = Path()
      ..moveTo(c.dx + b * .25, c.dy - b * 1.05)
      ..lineTo(c.dx - b * .55, c.dy + b * .12)
      ..lineTo(c.dx - b * .02, c.dy + b * .12)
      ..lineTo(c.dx - b * .25, c.dy + b * 1.05)
      ..lineTo(c.dx + b * .55, c.dy - b * .12)
      ..lineTo(c.dx + b * .02, c.dy - b * .12)
      ..close();
    canvas.drawPath(bolt, Paint()..color = BoltColors.neon);
    canvas.drawPath(
      bolt,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * .015
        ..color = BoltColors.ink,
    );
  }

  Path _poly(Offset c, double r, int n, double start) {
    final p = Path();
    for (var i = 0; i < n; i++) {
      final a = start + i * 2 * math.pi / n;
      final o = c + Offset(math.cos(a), math.sin(a)) * r;
      i == 0 ? p.moveTo(o.dx, o.dy) : p.lineTo(o.dx, o.dy);
    }
    return p..close();
  }

  Path _star(Offset c, double outer, double inner, int points) {
    final p = Path();
    for (var i = 0; i < points * 2; i++) {
      final a = -math.pi / 2 + i * math.pi / points;
      final o = c + Offset(math.cos(a), math.sin(a)) * (i.isEven ? outer : inner);
      i == 0 ? p.moveTo(o.dx, o.dy) : p.lineTo(o.dx, o.dy);
    }
    return p..close();
  }

  @override
  bool shouldRepaint(_EmblemPainter old) => old.step != step || old.spin != spin;
}
