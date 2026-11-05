import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// A small trend through [values], oldest first: a smooth ribbon with some
/// depth to it, a dot on every entry and a lit bead on the latest. Needs at
/// least two values.
class Sparkline extends StatelessWidget {
  const Sparkline({super.key, required this.values, this.height = 56, this.color, this.goal});

  final List<double> values;
  final double height;
  final Color? color;

  /// A target drawn as a dashed line.
  final double? goal;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: height,
    width: double.infinity,
    child: CustomPaint(painter: _SparkPainter(values, color ?? BoltColors.neon, goal)),
  );
}

class _SparkPainter extends CustomPainter {
  _SparkPainter(this.values, this.color, this.goal);

  final List<double> values;
  final Color color;
  final double? goal;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final all = [...values, ?goal];
    final lo = all.reduce((a, b) => a < b ? a : b);
    final hi = all.reduce((a, b) => a > b ? a : b);
    // A flat line sits in the middle instead of dividing by zero.
    final span = hi - lo == 0 ? 1.0 : hi - lo;
    // Room for the bead on the sides and the ribbon's depth underneath.
    const side = 10.0, top = 8.0, depth = 7.0;
    final bottom = depth + 5;
    double yOf(double v) => top + (size.height - top - bottom) * (1 - (v - lo) / span);
    Offset at(int i) => Offset(
      side + (size.width - 2 * side) * i / (values.length - 1),
      hi - lo == 0 ? (size.height - depth) / 2 : yOf(values[i]),
    );
    // Flat tangents at every entry: it flows, and never overshoots a value.
    final line = Path()..moveTo(at(0).dx, at(0).dy);
    for (var i = 1; i < values.length; i++) {
      final a = at(i - 1), b = at(i);
      final mid = (a.dx + b.dx) / 2;
      line.cubicTo(mid, a.dy, mid, b.dy, b.dx, b.dy);
    }
    final last = at(values.length - 1);

    final fill = Path.from(line)
      ..lineTo(last.dx, size.height)
      ..lineTo(at(0).dx, size.height)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: .26), color.withValues(alpha: 0)],
        ).createShader(Offset.zero & size),
    );

    // The ribbon's edge, fading away below the line.
    for (var d = depth; d >= 1; d--) {
      canvas.drawPath(
        line.shift(Offset(0, d)),
        Paint()
          ..color = color.withValues(alpha: .04 + (depth - d) * .05)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4
          ..strokeCap = StrokeCap.round,
      );
    }
    canvas.drawPath(
      line,
      Paint()
        ..shader = LinearGradient(colors: [color.withValues(alpha: .6), color])
            .createShader(Rect.fromLTRB(at(0).dx, 0, last.dx, size.height))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );

    // A dot per entry while there is room to tell them apart.
    if (values.length <= 14) {
      for (var i = 0; i < values.length - 1; i++) {
        canvas.drawCircle(at(i), 3, Paint()..color = BoltColors.surface1);
        canvas.drawCircle(
          at(i),
          3,
          Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6,
        );
      }
    }

    canvas.drawCircle(last, 9, Paint()..color = color.withValues(alpha: .18));
    canvas.drawCircle(
      last,
      5.5,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-.4, -.4),
          colors: [Color.lerp(color, const Color(0xFFFFFFFF), .8)!, color],
        ).createShader(Rect.fromCircle(center: last, radius: 5.5)),
    );

    final g = goal;
    if (g != null && hi - lo != 0) {
      final y = yOf(g);
      final dash = Paint()
        ..color = BoltColors.text.withValues(alpha: .55)
        ..strokeWidth = 1;
      for (var x = 0.0; x < size.width; x += 8) {
        canvas.drawLine(Offset(x, y), Offset(x + 4, y), dash);
      }
    }
  }

  @override
  bool shouldRepaint(_SparkPainter old) => old.values != values || old.color != color || old.goal != goal;
}
