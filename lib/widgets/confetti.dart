import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// One burst of confetti from [origin], fluttering down and fading out over
/// about two seconds. Mostly neon and white with a few warm pieces, so it
/// reads as Bolt rather than a party.
class Confetti extends StatefulWidget {
  const Confetti({super.key, this.origin = const Alignment(0, -.2), this.count = 80});

  final Alignment origin;
  final int count;

  @override
  State<Confetti> createState() => _ConfettiState();
}

class _Piece {
  _Piece(math.Random r)
    : angle = -math.pi / 2 + (r.nextDouble() - .5) * math.pi * 1.1,
      speed = 420 + r.nextDouble() * 520,
      spin = (r.nextDouble() - .5) * 14,
      sway = 6 + r.nextDouble() * 10,
      phase = r.nextDouble() * math.pi * 2,
      w = 5 + r.nextDouble() * 5,
      h = 9 + r.nextDouble() * 8,
      round = r.nextDouble() < .25,
      color = _palette[r.nextInt(_palette.length)];

  final double angle, speed, spin, sway, phase, w, h;
  final bool round;
  final Color color;
}

const _palette = [
  BoltColors.neon,
  BoltColors.neon,
  BoltColors.neon,
  BoltColors.text,
  BoltColors.text,
  BoltColors.warn,
  Color(0xFF57E0C8),
];

class _ConfettiState extends State<Confetti> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200))..forward();
  late final _pieces = List.generate(widget.count, (_) => _Piece(math.Random()));

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: RepaintBoundary(
      child: CustomPaint(size: Size.infinite, painter: _ConfettiPainter(_c, _pieces, widget.origin)),
    ),
  );
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.t, this.pieces, this.origin) : super(repaint: t);

  final Animation<double> t;
  final List<_Piece> pieces;
  final Alignment origin;

  @override
  void paint(Canvas canvas, Size size) {
    if (t.value == 0 || t.value == 1) return;
    final s = t.value * 2.2;
    final o = origin.alongSize(size);
    // Air slows the pieces fast; gravity pulls them down after the pop.
    final drag = (1 - math.exp(-3.2 * s)) / 3.2;
    final fade = t.value < .7 ? 1.0 : 1 - (t.value - .7) / .3;
    final paint = Paint();
    for (final p in pieces) {
      final x = o.dx + math.cos(p.angle) * p.speed * drag + math.sin(s * 5 + p.phase) * p.sway * s;
      final y = o.dy + math.sin(p.angle) * p.speed * drag + 420 * s * s;
      paint.color = p.color.withValues(alpha: fade);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.phase + p.spin * s);
      if (p.round) {
        canvas.drawCircle(Offset.zero, p.w / 2, paint);
      } else {
        // Ribbons turn edge-on and back as they tumble.
        final flip = math.cos(s * 9 + p.phase).abs();
        canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: p.w, height: p.h * (.25 + .75 * flip)), paint);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => false;
}
