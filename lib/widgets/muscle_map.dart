import 'package:flutter/material.dart';

import '../core/format.dart';
import '../data/lifts.dart';
import '../theme/text_styles.dart';
import '../theme/tokens.dart';

/// Front and back body outlines with each muscle shaded by its sets against
/// the low end of its weekly range: dim when untouched, full neon once
/// reached. With [recovery] instead: orange while recovering, neon when
/// ready, grey when never trained.
class MuscleMap extends StatelessWidget {
  const MuscleMap({super.key, this.sets = const {}, this.recovery, this.labels = true});

  /// Sets per muscle key.
  final Map<String, int> sets;

  /// Recovery per muscle key, 0 to 1.
  final Map<String, double>? recovery;
  final bool labels;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AspectRatio(
          aspectRatio: 200 / 165,
          child: CustomPaint(painter: _MapPainter(sets, recovery)),
        ),
        if (labels) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  tx('FRONT VIEW'),
                  textAlign: TextAlign.center,
                  style: BoltText.m(10, color: BoltColors.muted),
                ),
              ),
              Expanded(
                child: Text(
                  tx('BACK VIEW'),
                  textAlign: TextAlign.center,
                  style: BoltText.m(10, color: BoltColors.muted),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// One muscle belly, as the outline points of its shape in a 100 × 165
/// figure. [mirror] draws the same shape again on the other side of the
/// body; centre muscles like the abs and traps do not.
typedef _Part = (String muscle, List<Offset> pts, bool mirror);

/// The body itself, from the top of the head down the right side to the
/// crotch. The left side is this mirrored, so the figure cannot come out
/// lopsided.
const _body = <Offset>[
  Offset(50, 2),
  Offset(56.5, 4.5),
  Offset(58, 13),
  Offset(55, 20.5),
  Offset(54, 25),
  Offset(60, 27.5),
  Offset(68, 30.5),
  Offset(72.5, 37),
  Offset(74.5, 47),
  Offset(74.5, 57),
  Offset(73.5, 65.5),
  Offset(76.5, 74),
  Offset(77, 83),
  Offset(78.5, 91),
  Offset(74, 94.5),
  Offset(70, 90),
  Offset(69, 82.5),
  Offset(67.5, 74),
  Offset(65.5, 65.5),
  Offset(64.5, 56),
  Offset(64, 46.5),
  Offset(62, 56),
  Offset(59.5, 66),
  Offset(62.5, 74),
  Offset(64.5, 84),
  Offset(64, 96),
  Offset(62, 110),
  Offset(60, 120),
  Offset(61.5, 132),
  Offset(58.5, 146),
  Offset(57.5, 153.5),
  Offset(62, 160),
  Offset(52.5, 161),
  Offset(52, 152),
  Offset(53, 138),
  Offset(52, 124),
  Offset(51, 108),
  Offset(50.5, 92),
];

// Traps are a back-view muscle here: the upper slope reads as shoulder on
// a front figure and only muddies the delt and the pec.
const _front = <_Part>[
  (
    'shoulders',
    [
      Offset(61, 30),
      Offset(68, 31),
      Offset(72.5, 38),
      Offset(72.5, 46),
      Offset(67, 48),
      Offset(62.5, 42.5),
      Offset(61, 35.5),
    ],
    true,
  ),
  (
    'chest',
    [
      Offset(51, 31),
      Offset(60, 30),
      Offset(66, 34),
      Offset(66.5, 42),
      Offset(61.5, 47),
      Offset(52.5, 46),
      Offset(51, 38),
    ],
    true,
  ),
  (
    'biceps',
    [Offset(66, 49), Offset(71.5, 50.5), Offset(73.5, 58), Offset(71.5, 65), Offset(67, 64), Offset(65, 56)],
    true,
  ),
  (
    'forearms',
    [
      Offset(67, 67.5),
      Offset(73.5, 69.5),
      Offset(76, 77),
      Offset(76, 84),
      Offset(71, 85),
      Offset(68, 77),
      Offset(67, 71.5),
    ],
    true,
  ),
  (
    'abs',
    [
      Offset(44, 49),
      Offset(56, 49),
      Offset(58, 58),
      Offset(57.5, 68),
      Offset(54, 76),
      Offset(50, 78),
      Offset(46, 76),
      Offset(42.5, 68),
      Offset(42, 58),
    ],
    false,
  ),
  (
    'quads',
    [
      Offset(52, 88),
      Offset(62, 90),
      Offset(63.5, 100),
      Offset(62.5, 110),
      Offset(58.5, 119),
      Offset(54, 119),
      Offset(51, 106),
      Offset(51, 95),
    ],
    true,
  ),
  (
    'calves',
    [Offset(53, 126), Offset(59.5, 128), Offset(61.5, 137), Offset(59.5, 147), Offset(55, 148), Offset(53, 136)],
    true,
  ),
];

const _back = <_Part>[
  (
    'traps',
    [
      Offset(50, 24),
      Offset(58, 27),
      Offset(63.5, 34),
      Offset(61.5, 43),
      Offset(54, 48),
      Offset(50, 49),
      Offset(46, 48),
      Offset(38.5, 43),
      Offset(36.5, 34),
      Offset(42, 27),
    ],
    false,
  ),
  (
    'shoulders',
    [
      Offset(61, 30),
      Offset(68, 31),
      Offset(72.5, 38),
      Offset(72.5, 46),
      Offset(67, 48),
      Offset(62.5, 42.5),
      Offset(61, 35.5),
    ],
    true,
  ),
  (
    'back',
    [
      Offset(52, 41),
      Offset(63, 43),
      Offset(66.5, 50),
      Offset(64.5, 59),
      Offset(58, 66),
      Offset(52, 65),
      Offset(51, 52),
    ],
    true,
  ),
  (
    'triceps',
    [Offset(65, 48.5), Offset(71, 49.5), Offset(73.5, 57), Offset(71.5, 65), Offset(66.5, 64), Offset(64, 55)],
    true,
  ),
  (
    'forearms',
    [
      Offset(67, 67.5),
      Offset(73.5, 69.5),
      Offset(76, 77),
      Offset(76, 84),
      Offset(71, 85),
      Offset(68, 77),
      Offset(67, 71.5),
    ],
    true,
  ),
  (
    'glutes',
    [Offset(51, 70), Offset(61, 71), Offset(64.5, 78), Offset(62.5, 86), Offset(55, 88), Offset(51, 80)],
    true,
  ),
  (
    'hamstrings',
    [
      Offset(52, 90),
      Offset(62, 92),
      Offset(63.5, 102),
      Offset(61.5, 113),
      Offset(57, 119),
      Offset(52, 112),
      Offset(51, 99),
    ],
    true,
  ),
  (
    'calves',
    [Offset(53, 125), Offset(60, 127), Offset(62.5, 137), Offset(59.5, 148), Offset(55, 148), Offset(52.5, 136)],
    true,
  ),
];

/// Lines scored into the shading so a belly reads as muscle and not as a
/// blob: the ab segments, the line between the pecs, and so on.
const _frontLines = <List<Offset>>[
  [Offset(50, 50), Offset(50, 77)],
  [Offset(44, 57), Offset(56, 57)],
  [Offset(43.5, 65), Offset(56.5, 65)],
  [Offset(45, 72), Offset(55, 72)],
  [Offset(56, 96), Offset(58, 112)],
  [Offset(44, 96), Offset(42, 112)],
];

const _backLines = <List<Offset>>[
  [Offset(50, 28), Offset(50, 48)],
  [Offset(50, 72), Offset(50, 87)],
  [Offset(56.5, 130), Offset(57, 142)],
  [Offset(43.5, 130), Offset(43, 142)],
];

class _MapPainter extends CustomPainter {
  const _MapPainter(this.sets, this.recovery);

  final Map<String, int> sets;
  final Map<String, double>? recovery;

  Color _shade(String m) {
    if (recovery case final r?) {
      final x = r[m];
      if (x == null) return BoltColors.line;
      return x >= 1 ? BoltColors.neon : Color.lerp(BoltColors.warn, const Color(0xFFFFC233), x)!;
    }
    final n = sets[m] ?? 0;
    if (n == 0) return BoltColors.line;
    final lo = volumeRange(m)?.$1 ?? 10;
    return Color.lerp(const Color(0x40C6FF1A), BoltColors.neon, (n / lo).clamp(0.0, 1.0))!;
  }

  /// A closed curve through [p] (Catmull-Rom as cubics), so a handful of
  /// outline points come out as an organic shape rather than a polygon.
  Path _smooth(List<Offset> p) {
    final path = Path();
    final n = p.length;
    if (n < 3) return path;
    path.moveTo(p[0].dx, p[0].dy);
    for (var i = 0; i < n; i++) {
      final p0 = p[(i - 1 + n) % n];
      final p1 = p[i];
      final p2 = p[(i + 1) % n];
      final p3 = p[(i + 2) % n];
      final c1 = p1 + (p2 - p0) / 6.4;
      final c2 = p2 - (p3 - p1) / 6.4;
      path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, p2.dx, p2.dy);
    }
    return path..close();
  }

  void _figure(Canvas canvas, double s, double dx, List<_Part> parts, List<List<Offset>> lines) {
    Offset at(Offset o) => Offset(dx + o.dx * s, o.dy * s);
    Offset flip(Offset o) => Offset(dx + (100 - o.dx) * s, o.dy * s);

    // The body under the shading: head, limbs and the parts no set trains.
    final half = [for (final o in _body) at(o)];
    final whole = [...half, for (final o in _body.reversed.skip(1).take(_body.length - 2)) flip(o)];
    canvas.drawPath(_smooth(whole), Paint()..color = BoltColors.lineSoft);

    final edge = Paint()
      ..color = BoltColors.ink.withValues(alpha: .85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9 * s
      ..strokeJoin = StrokeJoin.round;
    for (final (m, pts, mirror) in parts) {
      final fill = Paint()..color = _shade(m);
      for (final side in [at, if (mirror) flip]) {
        final path = _smooth([for (final o in pts) side(o)]);
        canvas
          ..drawPath(path, fill)
          ..drawPath(path, edge);
      }
    }

    final score = Paint()
      ..color = BoltColors.ink.withValues(alpha: .6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8 * s
      ..strokeCap = StrokeCap.round;
    for (final line in lines) {
      final path = Path()..moveTo(at(line.first).dx, at(line.first).dy);
      for (final o in line.skip(1)) {
        path.lineTo(at(o).dx, at(o).dy);
      }
      canvas.drawPath(path, score);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 200;
    _figure(canvas, s, 0, _front, _frontLines);
    _figure(canvas, s, 100 * s, _back, _backLines);
  }

  @override
  bool shouldRepaint(_MapPainter old) => old.sets != sets || old.recovery != recovery;
}
