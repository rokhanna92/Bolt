import 'package:flutter/material.dart';

import '../core/format.dart';
import '../data/lifts.dart';
import '../theme/text_styles.dart';
import '../theme/tokens.dart';

/// Front and back body outlines with each muscle shaded by its sets against
/// the low end of its weekly range: dim when untouched, full neon once
/// reached.
class MuscleMap extends StatelessWidget {
  const MuscleMap({super.key, required this.sets});

  /// Sets per muscle key.
  final Map<String, int> sets;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AspectRatio(
          aspectRatio: 200 / 165,
          child: CustomPaint(painter: _MapPainter(sets)),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: Text(
                tx('FRONT VIEW'),
                textAlign: TextAlign.center,
                style: BoltText.m(9, color: BoltColors.muted),
              ),
            ),
            Expanded(
              child: Text(
                tx('BACK VIEW'),
                textAlign: TextAlign.center,
                style: BoltText.m(9, color: BoltColors.muted),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// A region of one muscle: an oval or rounded box in a 100 × 165 figure.
typedef _Part = (String muscle, double l, double t, double r, double b, bool oval);

const _front = <_Part>[
  ('shoulders', 25, 29, 37, 41, true),
  ('shoulders', 63, 29, 75, 41, true),
  ('chest', 37, 30, 49.5, 46, false),
  ('chest', 50.5, 30, 63, 46, false),
  ('biceps', 24, 42, 33, 59, true),
  ('biceps', 67, 42, 76, 59, true),
  ('forearms', 20, 61, 29, 81, true),
  ('forearms', 71, 61, 80, 81, true),
  ('abs', 42, 48, 58, 72, false),
  ('quads', 37, 80, 49, 119, true),
  ('quads', 51, 80, 63, 119, true),
  ('calves', 38.5, 125, 47, 152, true),
  ('calves', 53, 125, 61.5, 152, true),
];

const _back = <_Part>[
  ('traps', 38, 23, 62, 36, true),
  ('shoulders', 25, 29, 37, 41, true),
  ('shoulders', 63, 29, 75, 41, true),
  ('back', 36, 37, 49.5, 64, false),
  ('back', 50.5, 37, 64, 64, false),
  ('triceps', 24, 42, 33, 59, true),
  ('triceps', 67, 42, 76, 59, true),
  ('forearms', 20, 61, 29, 81, true),
  ('forearms', 71, 61, 80, 81, true),
  ('glutes', 38, 70, 49.5, 88, true),
  ('glutes', 50.5, 70, 62, 88, true),
  ('hamstrings', 37.5, 90, 49, 121, true),
  ('hamstrings', 51, 90, 62.5, 121, true),
  ('calves', 38.5, 125, 47, 152, true),
  ('calves', 53, 125, 61.5, 152, true),
];

class _MapPainter extends CustomPainter {
  const _MapPainter(this.sets);

  final Map<String, int> sets;

  Color _shade(String m) {
    final n = sets[m] ?? 0;
    if (n == 0) return BoltColors.line;
    final lo = volumeRange(m)?.$1 ?? 10;
    return Color.lerp(const Color(0x40C6FF1A), BoltColors.neon, (n / lo).clamp(0.0, 1.0))!;
  }

  void _figure(Canvas canvas, double s, double dx, List<_Part> parts) {
    Rect r(double l, double t, double rr, double b) => Rect.fromLTRB(dx + l * s, t * s, dx + rr * s, b * s);
    final base = Paint()..color = BoltColors.lineSoft;
    // Head, neck, hips, hands, knees and feet: the parts that are not shaded.
    canvas
      ..drawOval(r(42, 4, 58, 22), base)
      ..drawRect(r(46, 20, 54, 27), base)
      ..drawRRect(RRect.fromRectAndRadius(r(38, 70, 62, 82), Radius.circular(4 * s)), base)
      ..drawOval(r(19, 82, 28, 92), base)
      ..drawOval(r(72, 82, 81, 92), base)
      ..drawOval(r(39, 118, 47, 126), base)
      ..drawOval(r(53, 118, 61, 126), base)
      ..drawOval(r(37, 152, 47, 160), base)
      ..drawOval(r(53, 152, 63, 160), base);
    final edge = Paint()
      ..color = BoltColors.surface1
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    for (final (m, l, t, rr, b, oval) in parts) {
      final fill = Paint()..color = _shade(m);
      final box = r(l, t, rr, b);
      if (oval) {
        canvas
          ..drawOval(box, fill)
          ..drawOval(box, edge);
      } else {
        final rrect = RRect.fromRectAndRadius(box, Radius.circular(5 * s));
        canvas
          ..drawRRect(rrect, fill)
          ..drawRRect(rrect, edge);
      }
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 200;
    _figure(canvas, s, 0, _front);
    _figure(canvas, s, 100 * s, _back);
  }

  @override
  bool shouldRepaint(_MapPainter old) => old.sets != sets;
}
