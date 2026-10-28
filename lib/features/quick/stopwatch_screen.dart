import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../data/bolt_store.dart' show clockProvider;
import '../../services/haptics.dart';
import '../../theme/text_styles.dart';
import '../../theme/tokens.dart';
import '../../widgets/box.dart';
import '../../widgets/common.dart';
import '../../widgets/tap.dart';
import 'watch.dart';

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
class StopwatchScreen extends ConsumerStatefulWidget {
  const StopwatchScreen({super.key});

  @override
  ConsumerState<StopwatchScreen> createState() => _StopwatchScreenState();
}

class _StopwatchScreenState extends ConsumerState<StopwatchScreen> with SingleTickerProviderStateMixin {
  /// Total elapsed and the lap in progress, held outside the widget tree so
  /// a running watch repaints the dial and the readouts and nothing else.
  final _total = ValueNotifier<Duration>(Duration.zero);
  final _lap = ValueNotifier<Duration>(Duration.zero);
  late final Ticker _ticker = createTicker((_) => _sync());

  @override
  void initState() {
    super.initState();
    _sync();
    if (ref.read(watchProvider).running) _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _total.dispose();
    _lap.dispose();
    super.dispose();
  }

  void _sync() {
    final w = ref.read(watchProvider);
    final now = ref.read(clockProvider)();
    _total.value = w.at(now);
    _lap.value = w.lapAt(now);
  }

  /// Frames are burned only while the watch actually runs.
  void _follow() {
    final running = ref.read(watchProvider).running;
    if (running && !_ticker.isActive) _ticker.start();
    if (!running && _ticker.isActive) _ticker.stop();
    _sync();
  }

  /// The crown: runs and stops. The hands hold where they are when stopped.
  void _crown() {
    Haptics.play(Feel.success);
    ref.read(watchProvider.notifier).startStop();
    _follow();
  }

  /// The side pusher: a lap while it runs, back to zero once it is stopped.
  void _pusher() {
    final w = ref.read(watchProvider);
    if (w.idle) return;
    Haptics.play(w.running ? Feel.tick : Feel.error);
    ref.read(watchProvider.notifier).lapOrReset();
    _follow();
  }

  @override
  Widget build(BuildContext context) {
    final w = ref.watch(watchProvider);
    final running = w.running;
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
                          child: CustomPaint(
                            painter: _ChronoPainter(_total, _lap, running: running, showLap: w.laps.isNotEmpty),
                          ),
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
              valueListenable: _total,
              builder: (context, e, _) =>
                  Text(fmtWatch(e), style: BoltText.m(40, weight: 700, color: BoltColors.text, spacing: -.02)),
            ),
          ),
          if (w.laps.isNotEmpty) ...[
            const SizedBox(height: 2),
            Center(
              child: ValueListenableBuilder<Duration>(
                valueListenable: _lap,
                builder: (context, e, _) => Text(
                  tx('Lap {n} · {time}', {'n': '${w.laps.length + 1}', 'time': fmtWatch(e)}),
                  style: BoltText.m(14, weight: 700, color: BoltColors.muted),
                ),
              ),
            ),
          ],
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: NeonButton(
                  label: running ? tx('Stop') : (w.idle ? tx('Start') : tx('Resume')),
                  color: running ? BoltColors.warn : BoltColors.neon,
                  textColor: BoltColors.ink,
                  onTap: _crown,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlineButton(
                  label: running ? tx('Lap') : tx('Reset'),
                  color: w.idle ? BoltColors.muted3 : BoltColors.text,
                  borderColor: BoltColors.line,
                  weight: 700,
                  onTap: _pusher,
                ),
              ),
            ],
          ),
          if (running || w.laps.isNotEmpty) ...[
            const SizedBox(height: 22),
            Kicker(tx('LAPS'), size: 10),
            const SizedBox(height: 8),
            _lapList(w),
          ],
        ],
      ),
    );
  }

  /// The lap in progress on top, then the finished ones newest first. Once
  /// there are three to compare, the quickest and the slowest are called
  /// out; before that there is nothing meaningful to rank.
  Widget _lapList(Watch w) {
    final splits = w.splits;
    final fast = splits.isEmpty ? null : splits.reduce((a, b) => a < b ? a : b);
    final slow = splits.isEmpty ? null : splits.reduce((a, b) => a > b ? a : b);
    final rank = splits.length >= 3 && fast != slow;
    return BoltBox(
      color: BoltColors.surface1,
      stroke: const Stroke(BoltColors.lineSoft),
      radius: 18,
      clip: true,
      child: Column(
        children: [
          if (w.running)
            ValueListenableBuilder<Duration>(
              valueListenable: _lap,
              builder: (context, lap, _) => ValueListenableBuilder<Duration>(
                valueListenable: _total,
                builder: (context, total, _) => _lapRow(w.laps.length + 1, lap, total, live: true),
              ),
            ),
          for (var i = splits.length - 1; i >= 0; i--)
            _lapRow(
              i + 1,
              splits[i],
              w.laps[i],
              tag: !rank
                  ? null
                  : splits[i] == fast
                  ? tx('QUICKEST')
                  : splits[i] == slow
                  ? tx('SLOWEST')
                  : null,
              accent: !rank
                  ? null
                  : splits[i] == fast
                  ? BoltColors.neon
                  : splits[i] == slow
                  ? BoltColors.warn
                  : null,
            ),
        ],
      ),
    );
  }

  Widget _lapRow(int n, Duration split, Duration total, {String? tag, Color? accent, bool live = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: BoltColors.divider)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            child: Kicker('$n'.padLeft(2, '0'), size: 11, color: live ? BoltColors.neon : BoltColors.muted2),
          ),
          Expanded(
            child: Text(
              fmtWatch(split),
              style: BoltText.m(15, weight: 700, color: accent ?? (live ? BoltColors.textSoft : BoltColors.text)),
            ),
          ),
          if (tag != null && accent != null) ...[
            Text(tag, style: BoltText.m(9, weight: 700, color: accent, spacing: .12)),
            const SizedBox(width: 10),
          ],
          Text(fmtWatch(total), style: BoltText.m(13, color: BoltColors.muted)),
        ],
      ),
    );
  }
}

class _ChronoPainter extends CustomPainter {
  _ChronoPainter(this.total, this.lap, {required this.running, required this.showLap})
    : super(repaint: Listenable.merge([total, lap]));

  final ValueNotifier<Duration> total;
  final ValueNotifier<Duration> lap;
  final bool running;

  /// A second, quieter hand for the lap in progress, once laps are running.
  final bool showLap;

  @override
  void paint(Canvas canvas, Size size) {
    final d = size.width;
    final c = Offset(d / 2, d * .56);
    final r = d * .42;

    _case(canvas, c, r, d);
    _dial(canvas, c, r);
    _track(canvas, c, r);
    _subdial(canvas, c, r);
    // Maker's name, where a dial carries it.
    _text(canvas, 'BOLT', c + Offset(0, r * .40), r * .085, BoltColors.muted3, weight: 700);
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
    // Tucked in far enough that the 60 at the top of the track clears it.
    final sc = c + Offset(0, -r * .35);
    final sr = r * .19;
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

    final mins = total.value.inSeconds / 60.0;
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
    // The lap hand sits under the sweep hand and is deliberately plain, so
    // the eye still goes to the total first.
    if (showLap) {
      final la = -math.pi / 2 + (lap.value.inMilliseconds / 1000.0 % 60) * math.pi / 30;
      final ldir = Offset(math.cos(la), math.sin(la));
      canvas.drawLine(
        c - ldir * (r * .12),
        c + ldir * (r * .72),
        Paint()
          ..color = BoltColors.textSoft.withValues(alpha: .75)
          ..strokeWidth = r * .022
          ..strokeCap = StrokeCap.round,
      );
    }

    final secs = total.value.inMilliseconds / 1000.0;
    final a = -math.pi / 2 + (secs % 60) * math.pi / 30;
    final dir = Offset(math.cos(a), math.sin(a));
    final side = Offset(-dir.dy, dir.dx);
    final tip = c + dir * (r * .88);
    final tail = c - dir * (r * .27);
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
    canvas.drawCircle(tail + dir * (r * .07), r * .05, Paint()..color = BoltColors.neon);
    canvas.drawCircle(tail + dir * (r * .07), r * .022, Paint()..color = _dialEdge);

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
  bool shouldRepaint(_ChronoPainter old) => old.running != running || old.showLap != showLap;
}
