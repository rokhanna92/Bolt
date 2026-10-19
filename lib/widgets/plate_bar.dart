import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// A loaded barbell, both sides, plates in the competition colours: red 25,
/// blue 20, yellow 15, green 10, white 5, then small red and chrome. Pounds
/// follow the same order from 45 down.
class PlateBar extends StatelessWidget {
  const PlateBar({super.key, required this.side, required this.plates, this.height = 120});

  /// One side's plates, heaviest first.
  final List<double> side;

  /// Every plate size in the unit, heaviest first; picks colour and size.
  final List<double> plates;
  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: height,
    width: double.infinity,
    child: CustomPaint(painter: _PlatePainter(side, plates)),
  );
}

const _colors = [
  Color(0xFFE5383B),
  Color(0xFF2F6FEB),
  Color(0xFFF2C14E),
  Color(0xFF2BA84A),
  Color(0xFFECEFF1),
  Color(0xFFB3261E),
  Color(0xFFB8BEC6),
];

// Height and thickness of each size, from the biggest plate down.
const _tall = [1.0, .94, .84, .74, .56, .46, .38];
const _thick = [.07, .065, .055, .045, .034, .028, .022];

class _PlatePainter extends CustomPainter {
  _PlatePainter(this.side, this.plates);

  final List<double> side;
  final List<double> plates;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height, mid = h / 2;
    final steel = Paint()..color = const Color(0xFF8C9389);
    // Shaft between the collars, then the sleeves out to the ends.
    final collar = w * .3;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(collar, mid - h * .035, w - collar, mid + h * .035),
        const Radius.circular(2),
      ),
      steel,
    );
    final sleeve = Paint()..color = const Color(0xFFB5BBB1);
    for (final (a, b) in [(0.0, collar), (w - collar, w)]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTRB(a, mid - h * .06, b, mid + h * .06), const Radius.circular(3)),
        sleeve,
      );
    }
    for (final x in [collar - w * .012, w - collar]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(x, mid - h * .13, w * .012, h * .26), const Radius.circular(2)),
        steel,
      );
    }
    // Plates from the collar outwards, mirrored, thinner when they would
    // run off the sleeve.
    int kind(double p) => plates.indexOf(p).clamp(0, _colors.length - 1);
    final room = collar - w * .03;
    final need = side.fold(0.0, (a, p) => a + w * _thick[kind(p)]);
    final fit = need > room ? room / need : 1.0;
    var off = 0.0;
    for (final p in side) {
      final i = kind(p);
      final t = w * _thick[i] * fit, ph = h * .92 * _tall[i];
      final fill = Paint()..color = _colors[i];
      final edge = Paint()
        ..color = BoltColors.ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      for (final left in [collar - w * .012 - off - t, w - collar + w * .012 + off]) {
        final r = RRect.fromRectAndRadius(Rect.fromLTWH(left, mid - ph / 2, t, ph), Radius.circular(t * .3));
        canvas.drawRRect(r, fill);
        canvas.drawRRect(r, edge);
      }
      off += t;
    }
  }

  @override
  bool shouldRepaint(_PlatePainter old) => old.side.join() != side.join() || old.plates != plates;
}
