import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../theme/tokens.dart';

/// One heartbeat across a slot from 0 to 1: flat, a small bump, the spike
/// and the dip after it, as on a heart monitor. Heights are shares of the
/// beat's amplitude.
const _beat = [
  (0.0, 0.0),
  (0.26, 0.0),
  (0.32, 0.1),
  (0.38, 0.0),
  (0.43, -0.14),
  (0.49, 1.0),
  (0.55, -0.32),
  (0.6, 0.0),
  (0.7, 0.16),
  (0.8, 0.0),
  (1.0, 0.0),
];

/// The session as a heartbeat across the full width, one beat per set in the
/// order they are done. Done sets stay as neon spikes, taller for more weight
/// moved; the sets ahead wait dimmed, the one you are on the tallest, and a
/// trace sweeps the whole line like a monitor. During a rest they go flat and
/// grow back as the countdown runs, and the line flashes when the rest is
/// over. It animates on its own, so nothing else rebuilds.
class Lifeline extends StatefulWidget {
  const Lifeline({super.key, required this.beats, required this.at, required this.restEnd, required this.restTotal});

  /// Per set, from 0 to 1 when done (its share of the heaviest set), else
  /// null.
  final List<double?> beats;

  /// The set you are on, as an index into [beats].
  final int? at;
  final DateTime? restEnd;

  /// Full rest in seconds.
  final int restTotal;

  @override
  State<Lifeline> createState() => _LifelineState();
}

class _LifelineState extends State<Lifeline> with TickerProviderStateMixin {
  /// The live trace sweeping the whole line.
  late final _sweep = AnimationController(vsync: this, duration: _sweepTime)..repeat();

  /// A steady pulse however many sets there are, within reason.
  Duration get _sweepTime => Duration(milliseconds: (widget.beats.length * 700).clamp(2000, 8000));

  /// The newest done set's spike shooting up.
  late final _pop = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));

  /// The whole line lighting up when a rest ends.
  late final _flash = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
  int? _popped;

  @override
  void didUpdateWidget(Lifeline old) {
    super.didUpdateWidget(old);
    for (var k = 0; k < widget.beats.length && k < old.beats.length; k++) {
      if (old.beats[k] == null && widget.beats[k] != null) {
        _popped = k;
        _pop.forward(from: 0);
      }
    }
    if (old.restEnd != null && widget.restEnd == null) _flash.forward(from: 0);
    if (old.beats.length != widget.beats.length) {
      _sweep
        ..duration = _sweepTime
        ..repeat();
    }
  }

  @override
  void dispose() {
    _sweep.dispose();
    _pop.dispose();
    _flash.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        size: const Size(double.infinity, 56),
        painter: _LifelinePainter(
          beats: widget.beats,
          at: widget.at,
          restEnd: widget.restEnd,
          restTotal: widget.restTotal,
          sweep: _sweep,
          pop: _pop,
          popped: _popped,
          flash: _flash,
        ),
      ),
    );
  }
}

class _LifelinePainter extends CustomPainter {
  _LifelinePainter({
    required this.beats,
    required this.at,
    required this.restEnd,
    required this.restTotal,
    required this.sweep,
    required this.pop,
    required this.popped,
    required this.flash,
  }) : super(repaint: Listenable.merge([sweep, pop, flash]));

  final List<double?> beats;
  final int? at;
  final DateTime? restEnd;
  final int restTotal;
  final Animation<double> sweep;
  final Animation<double> pop;
  final int? popped;
  final Animation<double> flash;

  /// Adds slot [k]'s beat at [amp] to [path]. Every set gets an equal slot,
  /// so the line always fills the width.
  void _trace(Path path, Size size, int k, double amp) {
    final w = size.width / beats.length;
    final x0 = k * w;
    final base = size.height * .72;
    final h = size.height * .64 * amp;
    path.moveTo(x0, base);
    for (final (u, v) in _beat.skip(1)) {
      path.lineTo(x0 + u * w, base - v * h);
    }
  }

  /// How high the line is at [u], from 0 to 1 across it, before scaling.
  static double _height(double u, List<double> amps) {
    final at = u * amps.length;
    final k = math.min(amps.length - 1, at.floor());
    final x = at - k;
    for (var p = 1; p < _beat.length; p++) {
      final (bu, bv) = _beat[p];
      if (x <= bu) {
        final (pu, pv) = _beat[p - 1];
        return (pv + (bv - pv) * (x - pu) / (bu - pu)) * amps[k];
      }
    }
    return 0;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (beats.isEmpty) return;
    final flashing = flash.isAnimating ? 1 - flash.value : 0.0;

    // The sets not done yet. Resting, they start flat and grow back to full
    // beats as the countdown runs out.
    var live = .8;
    var color = BoltColors.neon;
    final end = restEnd;
    if (end != null) {
      final left = (end.difference(DateTime.now()).inMilliseconds / (restTotal * 1000)).clamp(0.0, 1.0);
      live = .12 + .68 * (1 - left);
      color = Color.lerp(BoltColors.text, BoltColors.neon, 1 - left)!;
    }

    final amps = <double>[];
    final wave = Path(), done = Path();
    for (var k = 0; k < beats.length; k++) {
      final b = beats[k];
      final grow = k == popped && pop.isAnimating ? Curves.elasticOut.transform(pop.value) : 1.0;
      final amp = b != null ? (.35 + .65 * b) * grow : (k == at ? live : live * .6);
      amps.add(amp);
      _trace(wave, size, k, amp);
      if (b != null) _trace(done, size, k, amp);
    }

    final glow = Paint()
      ..color = BoltColors.neon.withValues(alpha: .28 + .5 * flashing)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6 + 6 * flashing
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
    final line = Paint()
      ..color = BoltColors.neon
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeJoin = StrokeJoin.round;
    final dim = Paint()
      ..color = color.withValues(alpha: .35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeJoin = StrokeJoin.round;

    final k = at;
    if (k == null || beats[k] != null) {
      canvas.drawPath(wave, dim);
      canvas.drawPath(done, glow);
      canvas.drawPath(done, line);
      return;
    }

    // The trace: bright behind its head, then a small gap ahead of it where
    // the last sweep is wiped, and the waiting line after that.
    final u = sweep.value;
    final x = u * size.width;
    const gap = 14.0;
    canvas.save();
    canvas.clipRect(Rect.fromLTRB(x + gap, -8, size.width, size.height + 8));
    canvas.drawPath(wave, dim);
    canvas.restore();
    canvas.save();
    canvas.clipRect(Rect.fromLTRB(0, -8, x, size.height + 8));
    canvas.drawPath(wave, Paint.from(glow)..color = color.withValues(alpha: .35));
    canvas.drawPath(wave, Paint.from(line)..color = color);
    canvas.restore();
    canvas.drawPath(done, glow);
    canvas.drawPath(done, line);

    // The head of the trace, a glowing dot.
    final head = Offset(x, size.height * .72 - _height(u, amps) * size.height * .64);
    canvas.drawCircle(
      head,
      6,
      Paint()..shader = ui.Gradient.radial(head, 6, [color.withValues(alpha: .7), color.withValues(alpha: 0)]),
    );
    canvas.drawCircle(head, 2.5, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_LifelinePainter old) => true;
}
