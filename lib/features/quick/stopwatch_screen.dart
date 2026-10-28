import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../services/haptics.dart';
import '../../theme/text_styles.dart';
import '../../theme/tokens.dart';
import '../../widgets/box.dart';
import '../../widgets/common.dart';
import '../../widgets/tap.dart';

/// Case and dial colours. Olive-tinted steel so the chronograph sits in the
/// Bolt palette instead of next to it.
const _steelLight = Color(0xFF5C6354);
const _steelDark = Color(0xFF23271F);
const _dialEdge = Color(0xFF0C0E0B);

/// `01:23.45`, or `01:23:45` once it runs past an hour.
String fmtWatch(Duration e) {
  final cs = (e.inMilliseconds % 1000) ~/ 10;
  final s = e.inSeconds % 60;
  final m = e.inMinutes % 60;
  return e.inHours > 0 ? '${pad(e.inHours)}:${pad(m)}:${pad(s)}' : '${pad(m)}:${pad(s)}.${pad(cs)}';
}

/// A mechanical chronograph, drawn rather than animated from images: sweep
/// seconds hand, 30-minute totalizer, crown for start and stop, side pusher
/// for laps and reset.
class StopwatchScreen extends StatefulWidget {
  const StopwatchScreen({super.key});

  @override
  State<StopwatchScreen> createState() => _StopwatchScreenState();
}

class _StopwatchScreenState extends State<StopwatchScreen> with SingleTickerProviderStateMixin {
  final _watch = Stopwatch();
  final _elapsed = ValueNotifier<Duration>(Duration.zero);
  final _laps = <Duration>[];
  late final Ticker _ticker = createTicker((_) => _elapsed.value = _watch.elapsed);

  @override
  void dispose() {
    _ticker.dispose();
    _elapsed.dispose();
    super.dispose();
  }

  /// The crown: runs and stops. The hands hold where they are when stopped.
  void _crown() {
    Haptics.play(Feel.success);
    setState(() {
      if (_watch.isRunning) {
        _watch.stop();
        _ticker.stop();
      } else {
        _watch.start();
        _ticker.start();
      }
    });
    _elapsed.value = _watch.elapsed;
  }

  /// The side pusher: a lap while it runs, back to zero once it is stopped.
  void _pusher() {
    if (_watch.isRunning) {
      Haptics.play(Feel.tick);
      setState(() => _laps.add(_watch.elapsed));
      return;
    }
    if (_watch.elapsed == Duration.zero && _laps.isEmpty) return;
    Haptics.play(Feel.error);
    setState(() {
      _watch.reset();
      _laps.clear();
    });
    _elapsed.value = Duration.zero;
  }

  @override
  Widget build(BuildContext context) {
    final running = _watch.isRunning;
    return BoltPage(
      child: ScreenScroll(
        top: 16,
        bottom: 40,
        children: [
          Row(
            children: [
              BackBox(onTap: () => context.pop()),
              const SizedBox(width: 12),
              Kicker(tx('STOPWATCH')),
            ],
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, box) {
              final d = math.min(box.maxWidth, 360.0);
              return Center(
                child: SizedBox(
                  width: d,
                  height: d,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: RepaintBoundary(
                          child: CustomPaint(painter: _ChronoPainter(_elapsed, running: running)),
                        ),
                      ),
                      // Tap targets over the crown and the pusher the painter
                      // draws, so the case itself works the way it looks.
                      Positioned(
                        left: d * .5 - d * .09,
                        top: 0,
                        width: d * .18,
                        height: d * .16,
                        child: Tap(onTap: _crown, child: const SizedBox.expand()),
                      ),
                      Positioned(
                        left: d * .09,
                        top: d * .12,
                        width: d * .16,
                        height: d * .16,
                        child: Tap(onTap: _pusher, child: const SizedBox.expand()),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 20),
          Center(
            child: ValueListenableBuilder<Duration>(
              valueListenable: _elapsed,
              builder: (context, e, _) =>
                  Text(fmtWatch(e), style: BoltText.m(40, weight: 700, color: BoltColors.text, spacing: -.02)),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: NeonButton(
                  label: running ? tx('Stop') : (_watch.elapsed == Duration.zero ? tx('Start') : tx('Resume')),
                  color: running ? BoltColors.warn : BoltColors.neon,
                  textColor: BoltColors.ink,
                  onTap: _crown,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlineButton(
                  label: running ? tx('Lap') : tx('Reset'),
                  color: BoltColors.text,
                  borderColor: BoltColors.line,
                  weight: 700,
                  onTap: _pusher,
                ),
              ),
            ],
          ),
          if (_laps.isNotEmpty) ...[
            const SizedBox(height: 22),
            Kicker(tx('LAPS'), size: 10),
            const SizedBox(height: 8),
            BoltBox(
              color: BoltColors.surface1,
              stroke: const Stroke(BoltColors.lineSoft),
              radius: 18,
              clip: true,
              child: Column(children: [for (var i = _laps.length - 1; i >= 0; i--) _lapRow(i)]),
            ),
          ],
        ],
      ),
    );
  }

  Widget _lapRow(int i) {
    final split = i == 0 ? _laps[0] : _laps[i] - _laps[i - 1];
    final best = _laps.length > 1 && split == _bestSplit;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: BoltColors.divider)),
      ),
      child: Row(
        children: [
          SizedBox(width: 44, child: Kicker('${i + 1}'.padLeft(2, '0'), size: 11, color: BoltColors.muted2)),
          Expanded(
            child: Text(
              fmtWatch(split),
              style: BoltText.m(15, weight: 700, color: best ? BoltColors.neon : BoltColors.text),
            ),
          ),
          Text(fmtWatch(_laps[i]), style: BoltText.m(13, color: BoltColors.muted)),
        ],
      ),
    );
  }

  Duration get _bestSplit {
    var best = _laps[0];
    for (var i = 1; i < _laps.length; i++) {
      final s = _laps[i] - _laps[i - 1];
      if (s < best) best = s;
    }
    return best;
  }
}

class _ChronoPainter extends CustomPainter {
  _ChronoPainter(this.elapsed, {required this.running}) : super(repaint: elapsed);

  final ValueNotifier<Duration> elapsed;
  final bool running;

  @override
  void paint(Canvas canvas, Size size) {
    final d = size.width;
    final c = Offset(d / 2, d * .56);
    final r = d * .42;

    _case(canvas, c, r, d);
    _dial(canvas, c, r);
    _track(canvas, c, r);
    _subdial(canvas, c, r);
    _hands(canvas, c, r);
  }

  /// Brushed steel case with the crown on top and the lap pusher at ten
  /// o'clock, the way a pocket chronograph carries them.
  void _case(Canvas canvas, Offset c, double r, double d) {
    void pusher(double angle, double len, double w) {
      final dir = Offset(math.cos(angle), math.sin(angle));
      final base = c + dir * (r * 1.0);
      final tip = c + dir * (r * (1 + len));
      canvas.drawLine(
        base,
        tip,
        Paint()
          ..shader = LinearGradient(colors: const [_steelLight, _steelDark]).createShader(Rect.fromPoints(base, tip))
          ..strokeWidth = w
          ..strokeCap = StrokeCap.round,
      );
    }

    // Crown at 12, pusher at 10.
    pusher(-math.pi / 2, .17, d * .052);
    pusher(-math.pi * .78, .10, d * .038);

    // The case ring, brushed by sweeping light around it.
    canvas.drawCircle(
      c,
      r * 1.03,
      Paint()
        ..shader = const SweepGradient(
          colors: [_steelDark, _steelLight, _steelDark, _steelLight, _steelDark],
          stops: [0, .25, .5, .75, 1],
        ).createShader(Rect.fromCircle(center: c, radius: r * 1.03)),
    );
    // Inner bevel, so the ring reads as metal with depth.
    canvas.drawCircle(
      c,
      r * .975,
      Paint()
        ..shader = const SweepGradient(
          colors: [_steelLight, _steelDark, _steelLight, _steelDark, _steelLight],
          stops: [0, .25, .5, .75, 1],
        ).createShader(Rect.fromCircle(center: c, radius: r * .975)),
    );
  }

  /// Dark enamel face, lit slightly from above.
  void _dial(Canvas canvas, Offset c, double r) {
    canvas.drawCircle(
      c,
      r * .93,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-.25, -.45),
          radius: 1.1,
          colors: const [BoltColors.surface2, BoltColors.surface1, _dialEdge],
          stops: const [0, .55, 1],
        ).createShader(Rect.fromCircle(center: c, radius: r * .93)),
    );
    canvas.drawCircle(c, r * .93, Paint()..color = Colors.black.withValues(alpha: .25));
  }

  /// Sixty seconds: a fine tick each, a long one and a number every five.
  void _track(Canvas canvas, Offset c, double r) {
    for (var i = 0; i < 60; i++) {
      final a = -math.pi / 2 + i * math.pi / 30;
      final dir = Offset(math.cos(a), math.sin(a));
      final five = i % 5 == 0;
      canvas.drawLine(
        c + dir * (r * (five ? .76 : .82)),
        c + dir * (r * .87),
        Paint()
          ..color = five ? BoltColors.text : BoltColors.muted4
          ..strokeWidth = five ? r * .022 : r * .009
          ..strokeCap = StrokeCap.round,
      );
      if (five) {
        _text(canvas, '${i == 0 ? 60 : i}', c + dir * (r * .64), r * .105, BoltColors.textSoft, weight: 700);
      }
    }
  }

  /// The 30-minute totalizer at 12, where a chronograph counts the minutes
  /// its sweep hand has already been round.
  void _subdial(Canvas canvas, Offset c, double r) {
    final sc = c + Offset(0, -r * .40);
    final sr = r * .24;
    canvas.drawCircle(sc, sr, Paint()..color = _dialEdge.withValues(alpha: .55));
    canvas.drawCircle(
      sc,
      sr,
      Paint()
        ..color = BoltColors.lineFaint
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * .008,
    );
    for (var i = 0; i < 30; i++) {
      final a = -math.pi / 2 + i * math.pi / 15;
      final dir = Offset(math.cos(a), math.sin(a));
      final five = i % 5 == 0;
      canvas.drawLine(
        sc + dir * (sr * (five ? .68 : .80)),
        sc + dir * (sr * .92),
        Paint()
          ..color = five ? BoltColors.textSoft : BoltColors.muted4
          ..strokeWidth = five ? sr * .07 : sr * .03,
      );
    }
    for (final m in [10, 20, 30]) {
      final a = -math.pi / 2 + m * math.pi / 15;
      final dir = Offset(math.cos(a), math.sin(a));
      _text(canvas, '$m', sc + dir * (sr * .46), sr * .34, BoltColors.muted);
    }

    final mins = elapsed.value.inSeconds / 60.0;
    final a = -math.pi / 2 + (mins % 30) * math.pi / 15;
    final dir = Offset(math.cos(a), math.sin(a));
    canvas.drawLine(
      sc - dir * (sr * .18),
      sc + dir * (sr * .78),
      Paint()
        ..color = BoltColors.textSoft
        ..strokeWidth = sr * .085
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(sc, sr * .085, Paint()..color = BoltColors.text);
  }

  /// The sweep hand: long, counterweighted, and glowing a little the way
  /// lume does. It is the only neon on the dial, so the eye goes to it.
  void _hands(Canvas canvas, Offset c, double r) {
    final secs = elapsed.value.inMilliseconds / 1000.0;
    final a = -math.pi / 2 + (secs % 60) * math.pi / 30;
    final dir = Offset(math.cos(a), math.sin(a));
    final side = Offset(-dir.dy, dir.dx);
    final tip = c + dir * (r * .88);
    final tail = c - dir * (r * .20);
    final w = r * .018;

    final hand = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo((c + side * w + dir * (r * .1)).dx, (c + side * w + dir * (r * .1)).dy)
      ..lineTo((tail + side * (w * 1.9)).dx, (tail + side * (w * 1.9)).dy)
      ..lineTo((tail - side * (w * 1.9)).dx, (tail - side * (w * 1.9)).dy)
      ..lineTo((c - side * w + dir * (r * .1)).dx, (c - side * w + dir * (r * .1)).dy)
      ..close();

    canvas.drawPath(
      hand,
      Paint()
        ..color = BoltColors.neon.withValues(alpha: running ? .45 : .22)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * .035),
    );
    canvas.drawPath(hand, Paint()..color = BoltColors.neon);
    // Counterweight ring on the tail, as on a real chronograph hand.
    canvas.drawCircle(tail + dir * (r * .055), r * .042, Paint()..color = BoltColors.neon);
    canvas.drawCircle(tail + dir * (r * .055), r * .018, Paint()..color = _dialEdge);

    canvas.drawCircle(c, r * .055, Paint()..color = BoltColors.neon);
    canvas.drawCircle(c, r * .022, Paint()..color = _dialEdge);
  }

  void _text(Canvas canvas, String s, Offset at, double size, Color color, {double weight = 400}) {
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: BoltText.m(size, color: color, weight: weight),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, at - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(_ChronoPainter old) => old.running != running;
}
