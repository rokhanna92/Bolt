import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/actions.dart';
import '../../app/tick.dart';
import '../../core/format.dart';
import '../../data/bolt_store.dart';
import '../../data/gym_times.dart';
import '../../data/models/session.dart';
import '../../data/models/visit.dart';
import '../../theme/text_styles.dart';
import '../../theme/tokens.dart';
import '../../widgets/box.dart';
import '../../widgets/common.dart';
import '../../widgets/motion.dart';
import '../today/today_screen.dart' show clockText;

class GymScreen extends ConsumerWidget {
  const GymScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(boltProvider);
    final store = ref.read(boltProvider.notifier);
    final id = d.account?.id ?? '';
    final g = d.gymIn[id];
    // Live numbers only need the tick while checked in.
    final now = g == null ? store.now : watchNow(ref);
    final visits = d.visits[id] ?? const <Visit>[];
    final live = g?.elapsedMinutes(now) ?? 0;
    final mon0 = monday(now);
    double wkMin(int w) {
      final a = dk(addDays(mon0, 7 * w)), b = dk(addDays(mon0, 7 * w + 7));
      return visits.where((v) => v.date.compareTo(a) >= 0 && v.date.compareTo(b) < 0).fold(0.0, (x, v) => x + v.mins);
    }

    final weeks = [for (var w = -5; w <= 0; w++) (w: w, m: wkMin(w) + (w == 0 ? live : 0))];
    final mx = weeks.fold(240.0, (a, x) => math.max(a, x.m));
    final cw = visits.where((v) => v.date.compareTo(dk(mon0)) >= 0).toList();
    final cwMin = cw.fold(0.0, (a, v) => a + v.mins) + live;
    final cnt = cw.length + (g == null ? 0 : 1);
    final last = visits.firstOrNull;

    return ScreenScroll(
      children: [
        Kicker(tx('GYM TIME')),
        const SizedBox(height: 16),
        BoltBox(
          color: BoltColors.surface1,
          stroke: const Stroke(BoltColors.lineSoft),
          radius: 28,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 26),
          child: Column(
            children: [
              if (g != null)
                _LiveRing(timer: clockText(live), since: g.since)
              else
                BoltBox(
                  width: 200,
                  height: 200,
                  circle: true,
                  stroke: const Stroke.dashed(BoltColors.line, 2),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(tx('NOT IN'), style: BoltText.a(26, weight: 900, width: 115)),
                      const SizedBox(height: 6),
                      SizedBox(
                        width: 140,
                        child: Text(
                          tx('Scan the plaque at the entrance'),
                          textAlign: TextAlign.center,
                          style: BoltText.a(12, color: BoltColors.muted),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 14),
              Text(
                last == null
                    ? tx('No visits yet')
                    : tx('Last visit {day} · {time}', {'day': fmtDay(last.date), 'time': dur(last.mins)}),
                style: BoltText.a(12, color: BoltColors.muted),
              ),
              const SizedBox(height: 18),
              NeonButton(
                label: g == null ? tx('Scan to check in') : tx('Scan to check out'),
                onTap: () => openScanner(context, ref),
                leading: const BoltIcon('scan_line', size: 20, color: BoltColors.ink),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        StatRow(
          children: [
            StatTile(
              value: dur(cwMin),
              label: tx('THIS WEEK'),
              valueSize: 20,
              valueWeight: 800,
              labelFirst: true,
              gap: 4,
            ),
            StatTile(value: '$cnt', label: tx('VISITS'), valueSize: 20, valueWeight: 800, labelFirst: true, gap: 4),
            StatTile(
              value: cnt > 0 ? dur(cwMin / cnt) : '—',
              label: tx('AVG VISIT'),
              valueSize: 20,
              valueWeight: 800,
              labelFirst: true,
              gap: 4,
            ),
          ],
        ),
        const SizedBox(height: 22),
        SectionTitle(tx('Last 6 weeks')),
        const SizedBox(height: 12),
        SizedBox(
          height: 150,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < weeks.length; i++) ...[
                if (i > 0) const SizedBox(width: 10),
                Expanded(child: _bar(weeks[i].m, mx, addDays(mon0, 7 * weeks[i].w), i == 5)),
              ],
            ],
          ),
        ),
        const SizedBox(height: 22),
        SectionTitle(tx('Last 6 months')),
        const SizedBox(height: 4),
        Text(tx('Every gym day, brighter for longer sessions.'), style: BoltText.a(12, color: BoltColors.muted)),
        const SizedBox(height: 10),
        GymHeatmap(visits: visits, plan: store.plan(id), now: now),
        const SizedBox(height: 22),
        SectionTitle(tx('Your best gym times')),
        const SizedBox(height: 4),
        Text(
          tx('Minutes per set by day and time, from scanned visits with a logged workout. Fewer means less waiting.'),
          style: BoltText.a(12, color: BoltColors.muted, height: 1.4),
        ),
        const SizedBox(height: 10),
        _BestTimes(slots: gymSlots(visits, store.plan(id))),
        const SizedBox(height: 22),
        SectionTitle(tx('Visit log')),
        const SizedBox(height: 8),
        if (g != null)
          VisitRow(day: tx('TODAY · LIVE'), range: tx('{time} → now', {'time': g.since}), dur: dur(live), live: true),
        for (final v in visits.take(6)) VisitRow(day: visitDay(v), range: '${v.inT} → ${v.outT}', dur: dur(v.mins)),
      ],
    );
  }

  Widget _bar(double m, double mx, DateTime d, bool cur) {
    // The prototype sizes bars as a percentage of the 150 px column, capped
    // at 100 px.
    final h = math.min(100.0, math.max(3.0, m / mx * 100) * 1.5);
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text('${(m / 60).toStringAsFixed(1)}h', style: BoltText.m(10, color: cur ? BoltColors.neon : BoltColors.muted)),
        const SizedBox(height: 6),
        GrowTo(
          value: h,
          builder: (context, v) => Container(
            height: v,
            decoration: BoxDecoration(
              color: cur ? BoltColors.neon : BoltColors.line,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text('${d.day} ${monthsShort[d.month - 1].toUpperCase()}', style: BoltText.m(9, color: BoltColors.muted3)),
      ],
    );
  }
}

/// The fastest slots and the slowest one.
class _BestTimes extends StatelessWidget {
  const _BestTimes({required this.slots});

  final List<GymSlot> slots;

  @override
  Widget build(BuildContext context) {
    if (slots.length < 2) {
      return BoltBox(
        radius: 14,
        stroke: const Stroke.dashed(BoltColors.line),
        padding: const EdgeInsets.all(14),
        child: Text(
          tx('After a few more scanned workouts at different times, Bolt shows when you train fastest.'),
          style: BoltText.a(13, color: BoltColors.muted, height: 1.45),
        ),
      );
    }
    String when(GymSlot s) => '${weekdays[s.weekday % 7]} ${pad(s.hour)}:00-${pad(s.hour + 2)}:00';
    Widget row(GymSlot s, {bool slow = false}) => Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: BoltColors.divider)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(when(s), style: BoltText.a(14, weight: 800, color: slow ? BoltColors.muted : BoltColors.text)),
                const SizedBox(height: 2),
                Text(plural(s.visits, 'gym visit'), style: BoltText.m(10, color: BoltColors.muted)),
              ],
            ),
          ),
          Text(
            tx('{n} min a set', {'n': s.minPerSet.toStringAsFixed(1)}),
            style: BoltText.m(12, weight: 700, color: slow ? BoltColors.warn : BoltColors.neon),
          ),
        ],
      ),
    );
    final fast = slots.take(3).toList();
    final slowest = slots.last;
    final gain = (100 * (1 - fast.first.minPerSet / slowest.minPerSet)).round();
    return BoltBox(
      color: BoltColors.surface1,
      stroke: const Stroke(BoltColors.lineSoft),
      radius: 18,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            tx('{when} is your quickest slot, {n}% faster than your slowest.', {'when': when(fast.first), 'n': gain}),
            style: BoltText.a(13, weight: 700, height: 1.4),
          ),
          const SizedBox(height: 6),
          for (final s in fast) row(s),
          if (!fast.contains(slowest)) row(slowest, slow: true),
        ],
      ),
    );
  }
}

String visitDay(Visit v) => fmtDay(v.date).toUpperCase() + (v.auto ? ' · ${tx('AUTO')}' : '');

class VisitRow extends StatelessWidget {
  const VisitRow({
    super.key,
    required this.day,
    required this.range,
    required this.dur,
    this.live = false,
    this.compact = false,
  });

  final String day;
  final String range;
  final String dur;
  final bool live;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: compact ? 10 : 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: BoltColors.divider)),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: live ? BoltColors.neon : BoltColors.handle, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Kicker(day, size: 10, spacing: compact ? 0 : .08),
                const SizedBox(height: 2),
                Text(range, style: BoltText.a(compact ? 13 : 14, weight: 600)),
              ],
            ),
          ),
          Text(dur, style: BoltText.m(compact ? 13 : 14, weight: 700)),
        ],
      ),
    );
  }
}

/// 200 px ring: neon arc rotating every 3 s and a breathing glow (2.4 s).
class _LiveRing extends StatefulWidget {
  const _LiveRing({required this.timer, required this.since});

  final String timer;
  final String since;

  @override
  State<_LiveRing> createState() => _LiveRingState();
}

class _LiveRingState extends State<_LiveRing> with TickerProviderStateMixin {
  late final _spin = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();
  late final _glow = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _spin.dispose();
    _glow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      height: 200,
      child: Stack(
        alignment: Alignment.center,
        children: [
          const BoltBox(width: 200, height: 200, borderBox: true, circle: true, stroke: Stroke(BoltColors.lineSoft, 2)),
          RotationTransition(
            turns: _spin,
            child: const CustomPaint(size: Size(200, 200), painter: _ArcPainter()),
          ),
          AnimatedBuilder(
            animation: _glow,
            builder: (context, _) {
              final t = Curves.easeInOut.transform(_glow.value);
              return Opacity(
                opacity: .45 + .55 * t,
                child: Transform.scale(
                  scale: .92 + .13 * t,
                  child: Container(
                    width: 172,
                    height: 172,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(colors: [Color(0x24C6FF1A), Color(0x00C6FF1A)], stops: [0, .7]),
                    ),
                  ),
                ),
              );
            },
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(widget.timer, style: BoltText.m(30, weight: 700, color: BoltColors.neon)),
              const SizedBox(height: 4),
              Kicker(tx('IN SINCE {time}', {'time': widget.since}), spacing: .1),
            ],
          ),
        ],
      ),
    );
  }
}

/// Top and right border of a circle, i.e. a half arc from top-left to
/// bottom-right.
class _ArcPainter extends CustomPainter {
  const _ArcPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final r = (Offset.zero & size).deflate(1);
    canvas.drawArc(
      r,
      -math.pi * 3 / 4,
      math.pi,
      false,
      Paint()
        ..color = BoltColors.neon
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_ArcPainter old) => false;
}

/// 26 weeks of gym days, Monday to Sunday down, oldest week on the left.
/// A visit shades by its length; a logged workout without a scan shows
/// faintly.
class GymHeatmap extends StatelessWidget {
  const GymHeatmap({super.key, required this.visits, required this.plan, required this.now});

  final List<Visit> visits;
  final Map<String, Session> plan;
  final DateTime now;

  static const _weeks = 26;

  @override
  Widget build(BuildContext context) {
    final mins = <String, int>{};
    for (final v in visits) {
      mins[v.date] = (mins[v.date] ?? 0) + v.mins;
    }
    final today = dk(now);
    final first = addDays(monday(now), -7 * (_weeks - 1));
    Color shade(String k) {
      final m = mins[k];
      if (m == null) {
        return plan[k]?.status == SessionStatus.done ? const Color(0x33C6FF1A) : BoltColors.lineSoft;
      }
      return m >= 90 ? BoltColors.neon : (m >= 45 ? const Color(0xB3C6FF1A) : const Color(0x66C6FF1A));
    }

    return LayoutBuilder(
      builder: (context, box) {
        const gap = 3.0;
        final cell = ((box.maxWidth - gap * (_weeks - 1)) / _weeks).floorToDouble();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var r = 0; r < 7; r++) ...[
              if (r > 0) const SizedBox(height: gap),
              Row(
                children: [
                  for (var w = 0; w < _weeks; w++) ...[
                    if (w > 0) const SizedBox(width: gap),
                    Builder(
                      builder: (context) {
                        final k = dk(addDays(first, 7 * w + r));
                        return Container(
                          width: cell,
                          height: cell,
                          decoration: BoxDecoration(
                            color: k.compareTo(today) > 0 ? Colors.transparent : shade(k),
                            borderRadius: BorderRadius.circular(2),
                            border: k == today ? Border.all(color: BoltColors.text) : null,
                          ),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ],
            const SizedBox(height: 8),
            Text(
              tx('{n} since {day}', {
                'n': plural(
                  visits.where((v) => v.date.compareTo(dk(first)) >= 0).map((v) => v.date).toSet().length,
                  'gym day',
                ),
                'day': fmtDay(dk(first)),
              }),
              style: BoltText.m(10, color: BoltColors.muted),
            ),
          ],
        );
      },
    );
  }
}
