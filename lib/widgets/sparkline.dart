import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// A small trend line through [values], oldest first, with the latest
/// point marked. Needs at least two values.
class Sparkline extends StatelessWidget {
  const Sparkline({super.key, required this.values, this.height = 40, this.color = BoltColors.neon, this.goal});

  final List<double> values;
  final double height;
  final Color color;

  /// A target drawn as a dashed line.
  final double? goal;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: height,
    width: double.infinity,
    child: CustomPaint(painter: _SparkPainter(values, color, goal)),
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
    const pad = 4.0;
    Offset at(int i) => Offset(
      pad + (size.width - 2 * pad) * i / (values.length - 1),
      hi - lo == 0 ? size.height / 2 : pad + (size.height - 2 * pad) * (1 - (values[i] - lo) / span),
    );
    final line = Path()..moveTo(at(0).dx, at(0).dy);
    for (var i = 1; i < values.length; i++) {
      line.lineTo(at(i).dx, at(i).dy);
    }
    final fill = Path.from(line)
      ..lineTo(at(values.length - 1).dx, size.height)
      ..lineTo(at(0).dx, size.height)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: .22), color.withValues(alpha: 0)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      line,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(at(values.length - 1), 3.5, Paint()..color = color);
    final g = goal;
    if (g != null && hi - lo != 0) {
      final y = pad + (size.height - 2 * pad) * (1 - (g - lo) / span);
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
