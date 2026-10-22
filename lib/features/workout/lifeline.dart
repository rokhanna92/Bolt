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

/// The session as a heartbeat, one beat per set in the order they are done.
/// Done sets stay as neon spikes, taller for more weight moved; the set you
/// are on is traced live like a monitor. During a rest that beat goes flat
/// and grows back as the countdown runs, and the line flashes when the rest
/// is over. It animates on its own, so nothing else rebuilds.
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
  /// The live trace sweeping through the current set.
  late final _sweep = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat();

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

  /// Adds slot [k]'s beat at [amp] to [path], up to [upTo] of the way.
  void _trace(Path path, Size size, int k, double amp, {double upTo = 1}) {
    final w = size.width / beats.length;
    final base = size.height * .72;
    final h = size.height * .64 * amp;
    final x0 = k * w;
    path.moveTo(x0, base);
    for (var p = 1; p < _beat.length; p++) {
      final (u, v) = _beat[p];
      if (u > upTo) {
        final (pu, pv) = _beat[p - 1];
        final t = (upTo - pu) / (u - pu);
        path.lineTo(x0 + upTo * w, base - (pv + (v - pv) * t) * h);
        return;
      }
      path.lineTo(x0 + u * w, base - v * h);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (beats.isEmpty) return;
    final flashing = flash.isAnimating ? 1 - flash.value : 0.0;
    final done = Path(), todo = Path();
    for (var k = 0; k < beats.length; k++) {
      final b = beats[k];
      if (k == at && b == null) continue;
      if (b == null) {
        _trace(todo, size, k, 0);
      } else {
        final grow = k == popped && pop.isAnimating ? Curves.elasticOut.transform(pop.value) : 1.0;
        _trace(done, size, k, (.35 + .65 * b) * grow);
      }
    }
    canvas.drawPath(
      todo,
      Paint()
        ..color = BoltColors.line
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
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
    canvas.drawPath(done, glow);
    canvas.drawPath(done, line);

    final k = at;
    if (k == null || beats[k] != null) return;
    // The set you are on: traced live. Resting, it starts flat and grows
    // back to a full beat as the countdown runs out.
    var amp = .8;
    var color = BoltColors.neon;
    final end = restEnd;
    if (end != null) {
      final left = (end.difference(DateTime.now()).inMilliseconds / (restTotal * 1000)).clamp(0.0, 1.0);
      amp = .12 + .68 * (1 - left);
      color = Color.lerp(BoltColors.text, BoltColors.neon, 1 - left)!;
    }
    final live = Path();
    _trace(live, size, k, amp, upTo: sweep.value);
    canvas.drawPath(live, glow..color = color.withValues(alpha: .35));
    canvas.drawPath(live, line..color = color);
    // The head of the trace, a glowing dot.
    final metrics = live.computeMetrics().toList();
    if (metrics.isEmpty) return;
    final last = metrics.last;
    final head = last.getTangentForOffset(last.length)?.position;
    if (head == null) return;
    canvas.drawCircle(
      head,
      6,
      Paint()..shader = ui.Gradient.radial(head, 6, [color.withValues(alpha: .7), color.withValues(alpha: 0)]),
    );
    canvas.drawCircle(head, math.max(1.5, 2.5 * amp), Paint()..color = color);
  }

  @override
  bool shouldRepaint(_LifelinePainter old) => true;
}
