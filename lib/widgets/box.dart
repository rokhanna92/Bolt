import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// A CSS-style border: solid or dashed.
class Stroke {
  const Stroke(this.color, [this.width = 1, this.dashed = false]);

  const Stroke.dashed(this.color, [this.width = 1]) : dashed = true;

  static const none = Stroke(Colors.transparent, 0);

  final Color color;
  final double width;
  final bool dashed;
}

/// A box with background, border (solid or dashed), radius and shadows, sized
/// like CSS `box-sizing: border-box`: the border sits inside the size and
/// insets the child.
class BoltBox extends StatelessWidget {
  const BoltBox({
    super.key,
    this.color,
    this.stroke = Stroke.none,
    this.radius = 0,
    this.circle = false,
    this.shadows,
    this.padding,
    this.width,
    this.height,
    this.alignment,
    this.gradient,
    this.clip = false,
    this.child,
  });

  final Color? color;
  final Stroke stroke;
  final double radius;
  final bool circle;
  final List<BoxShadow>? shadows;
  final EdgeInsetsGeometry? padding;
  final double? width;
  final double? height;
  final AlignmentGeometry? alignment;
  final Gradient? gradient;
  final bool clip;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final shape = circle ? BoxShape.circle : BoxShape.rectangle;
    final r = circle ? null : BorderRadius.circular(radius);
    final solid = stroke.width > 0 && !stroke.dashed;
    final box = Container(
      width: width,
      height: height,
      alignment: alignment,
      padding: stroke.dashed ? EdgeInsets.all(stroke.width).add(padding ?? EdgeInsets.zero) : padding,
      clipBehavior: clip ? Clip.antiAlias : Clip.none,
      decoration: BoxDecoration(
        color: color,
        gradient: gradient,
        shape: shape,
        borderRadius: r,
        boxShadow: shadows,
        border: solid ? Border.all(color: stroke.color, width: stroke.width) : null,
      ),
      child: child,
    );
    if (!stroke.dashed || stroke.width == 0) return box;
    return CustomPaint(
      foregroundPainter: DashedBorderPainter(stroke: stroke, radius: radius, circle: circle),
      child: box,
    );
  }
}

/// Paints a dashed rounded rectangle or circle, roughly matching how browsers
/// draw `border-style: dashed`.
class DashedBorderPainter extends CustomPainter {
  DashedBorderPainter({required this.stroke, this.radius = 0, this.circle = false});

  final Stroke stroke;
  final double radius;
  final bool circle;

  @override
  void paint(Canvas canvas, Size size) {
    final w = stroke.width;
    final rect = Rect.fromLTWH(w / 2, w / 2, size.width - w, size.height - w);
    final path = Path();
    if (circle) {
      path.addOval(rect);
    } else {
      path.addRRect(RRect.fromRectAndRadius(rect, Radius.circular(math.max(0, radius - w / 2))));
    }
    final paint = Paint()
      ..color = stroke.color
      ..strokeWidth = w
      ..style = PaintingStyle.stroke;
    final dash = math.max(3.0, w * 3);
    final gap = math.max(2.5, w * 2.2);
    for (final m in path.computeMetrics()) {
      // Spread the pattern so it closes evenly around the shape.
      final count = math.max(1, (m.length / (dash + gap)).round());
      final step = m.length / count;
      final d = step * dash / (dash + gap);
      for (var i = 0; i < count; i++) {
        final s = i * step;
        canvas.drawPath(m.extractPath(s, s + d), paint);
      }
    }
  }

  @override
  bool shouldRepaint(DashedBorderPainter old) =>
      old.stroke.color != stroke.color || old.stroke.width != stroke.width || old.radius != radius;
}

/// Shorthand for the prototype's standard card: surface1 with a soft border.
class Card1 extends StatelessWidget {
  const Card1({
    super.key,
    required this.child,
    this.radius = BoltRadii.card,
    this.padding = const EdgeInsets.all(14),
    this.stroke = const Stroke(BoltColors.lineSoft),
  });

  final Widget child;
  final double radius;
  final EdgeInsetsGeometry padding;
  final Stroke stroke;

  @override
  Widget build(BuildContext context) =>
      BoltBox(color: BoltColors.surface1, stroke: stroke, radius: radius, padding: padding, child: child);
}
