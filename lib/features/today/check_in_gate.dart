import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../data/bolt_store.dart';
import '../../data/models/bolt_data.dart';
import '../../data/models/people.dart';
import '../../data/models/session.dart';
import '../../data/readiness.dart';
import '../../theme/text_styles.dart';
import '../../theme/tokens.dart';
import '../../widgets/common.dart';
import '../../widgets/tap.dart';
import 'readiness_card.dart';

/// The first thing each day: the app blurs behind a card that asks today's
/// check-in, under a sun coming up. Skip goes straight in, and the card on
/// Today still asks. It stays away on a day already checked in, skipped,
/// trained or with a workout running.
class CheckInGate extends ConsumerStatefulWidget {
  const CheckInGate({super.key});

  @override
  ConsumerState<CheckInGate> createState() => _CheckInGateState();
}

class _CheckInGateState extends ConsumerState<CheckInGate> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
    reverseDuration: const Duration(milliseconds: 380),
  );
  bool _open = false;
  bool _saved = false;

  bool _due(BoltData d) {
    final store = ref.read(boltProvider.notifier);
    final t = store.trOrNull(d.account?.id ?? '');
    if (t == null) return false;
    final today = store.today;
    return t.readiness[today] == null &&
        !d.settings.hintsSeen.contains('checkin:$today') &&
        store.plan(t.id)[today]?.status != SessionStatus.done &&
        d.workout?.key != today;
  }

  Future<void> _close({bool skip = false}) async {
    if (skip) ref.read(boltProvider.notifier).skipCheckIn();
    await _c.reverse();
    if (mounted) setState(() => _open = _saved = false);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final due = _due(ref.watch(boltProvider));
    if (due && !_open) {
      _open = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _c.forward(from: 0);
      });
    }
    if (!_open) return const SizedBox.shrink();
    final pad = MediaQuery.paddingOf(context);
    final fade = CurvedAnimation(
      parent: _c,
      curve: const Interval(0, .45, curve: Curves.easeOut),
    );
    final rise = CurvedAnimation(
      parent: _c,
      curve: const Interval(.12, .7, curve: Curves.easeOutCubic),
    );
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close(skip: !_saved);
      },
      child: Material(
        type: MaterialType.transparency,
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, card) => Stack(
            children: [
              Positioned.fill(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 16 * fade.value, sigmaY: 16 * fade.value),
                  child: ColoredBox(color: BoltColors.scannerBg.withAlpha((0x9E * fade.value).round())),
                ),
              ),
              Positioned.fill(
                top: pad.top + 14,
                bottom: pad.bottom + 14,
                left: 14,
                right: 14,
                child: Opacity(
                  opacity: rise.value,
                  child: Transform.translate(
                    offset: Offset(0, 48 * (1 - rise.value)),
                    child: Transform.scale(scale: .94 + .06 * rise.value, child: card),
                  ),
                ),
              ),
            ],
          ),
          child: Center(child: _card()),
        ),
      ),
    );
  }

  Widget _card() {
    final store = ref.read(boltProvider.notifier);
    final t = store.trOrNull(ref.read(boltProvider).account?.id ?? '');
    if (t == null) return const SizedBox.shrink();
    return Container(
      constraints: const BoxConstraints(maxWidth: 460),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: BoltColors.sheet,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: BoltColors.neon.withAlpha(0x38)),
        boxShadow: [
          BoxShadow(color: BoltColors.glow(0x26), blurRadius: 40, spreadRadius: -6),
          const BoxShadow(color: Color(0x99000000), blurRadius: 30, offset: Offset(0, 14)),
        ],
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _header(t.name),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 350),
                switchInCurve: Curves.easeOutCubic,
                transitionBuilder: (child, a) => FadeTransition(
                  opacity: a,
                  child: SizeTransition(sizeFactor: a, alignment: Alignment.topCenter, child: child),
                ),
                child: _saved
                    ? _result(key: const ValueKey('result'))
                    : CheckInForm(
                        key: const ValueKey('form'),
                        trainee: t,
                        stagger: true,
                        onSaved: () => setState(() => _saved = true),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The sun coming up over the horizon, the day and a greeting, with Skip.
  Widget _header(String name) {
    final now = ref.read(boltProvider.notifier).now;
    final greet = now.hour < 12
        ? 'Good morning, {name}'
        : now.hour < 18
        ? 'Good afternoon, {name}'
        : 'Good evening, {name}';
    final sun = CurvedAnimation(
      parent: _c,
      curve: const Interval(.25, 1, curve: Curves.easeOutCubic),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 112,
          child: Stack(
            children: [
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: sun,
                  builder: (context, _) => CustomPaint(painter: _SunrisePainter(sun.value)),
                ),
              ),
              if (!_saved)
                Positioned(
                  top: 12,
                  right: 12,
                  child: Tap(
                    onTap: () => _close(skip: true),
                    scale: .94,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: BoltColors.ink.withAlpha(0x8C),
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(color: BoltColors.line),
                      ),
                      child: Text(tx('Skip'), style: BoltText.a(12, weight: 800, color: BoltColors.textSoft)),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 6, 18, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Kicker(
                '${tx('NEW DAY')} · ${weekdays[jsDay(now)]} ${dayMonth(now)}'.toUpperCase(),
                size: 10,
                color: BoltColors.neon,
              ),
              const SizedBox(height: 6),
              Text(
                tx(greet, {'name': vocative(firstName(name))}),
                style: BoltText.a(26, weight: 900, width: 110, spacing: -.02, height: 1.05),
              ),
              const SizedBox(height: 6),
              Text(
                tx('A quick check-in and Bolt sets today to how you feel.'),
                style: BoltText.a(13, color: BoltColors.muted, height: 1.35),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// The score once saved, what it means today and the way in.
  Widget _result({Key? key}) {
    final store = ref.read(boltProvider.notifier);
    final t = store.trOrNull(ref.read(boltProvider).account?.id ?? '')!;
    final r = t.readiness[store.today];
    final level = r == null ? 'normal' : readinessLevel(r);
    final tone = level == 'low' ? BoltColors.warn : BoltColors.neon;
    final s = store.plan(t.id)[store.today];
    final workout = s != null && s.status != SessionStatus.draft;
    final auto = store.canUndoReadiness ? store.autoDone : null;
    return Column(
      key: key,
      children: [
        const SizedBox(height: 8),
        if (r != null && r.length > kScore) ScoreRing(score: r[kScore], color: tone, size: 132),
        const SizedBox(height: 16),
        Kicker('${tx('READINESS')} · ${tx(kReadinessNames[level]!).toUpperCase()}', size: 10, spacing: .1, color: tone),
        const SizedBox(height: 8),
        Text(
          tx((workout ? kReadinessText : kRestReadinessText)[level]!),
          textAlign: TextAlign.center,
          style: BoltText.a(15, weight: 700, height: 1.4),
        ),
        if (auto != null) ...[
          const SizedBox(height: 12),
          Text(
            auto,
            textAlign: TextAlign.center,
            style: BoltText.a(13, weight: 700, color: BoltColors.warn, height: 1.35),
          ),
          const SizedBox(height: 10),
          Tap(
            onTap: () {
              store.undoReadiness();
              setState(() {});
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: BoltColors.line),
              ),
              child: Text(tx('Undo, I train as planned'), style: BoltText.a(12, weight: 800)),
            ),
          ),
        ],
        const SizedBox(height: 20),
        NeonButton(label: tx('Into Bolt'), height: 52, onTap: _close),
      ],
    );
  }
}

/// A half sun rising over a horizon line as [t] goes from 0 to 1, with rays
/// fanning out and a glow spreading over the sky.
class _SunrisePainter extends CustomPainter {
  _SunrisePainter(this.t);

  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final neon = BoltColors.neon;
    const r = 34.0;
    final horizon = size.height - 16;
    final c = Offset(size.width * .5, horizon + r + 4 - (r + 24) * t);

    // The sky warming up.
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = RadialGradient(
          center: Alignment(c.dx / size.width * 2 - 1, c.dy / size.height * 2 - 1),
          radius: .9,
          colors: [neon.withAlpha((0x40 * t).round()), neon.withAlpha(0)],
        ).createShader(Offset.zero & size),
    );

    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width, horizon));

    // Rays, longer as it climbs.
    final ray = Paint()
      ..color = neon.withAlpha((0x59 * t).round())
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 9; i++) {
      final a = math.pi + math.pi * (i + 1) / 10;
      final d = Offset(math.cos(a), math.sin(a));
      canvas.drawLine(c + d * (r + 10), c + d * (r + 10 + 22 * t), ray);
    }

    // The sun: a glow, then the disc.
    canvas.drawCircle(
      c,
      r + 18,
      Paint()
        ..color = neon.withAlpha((0x2E * t).round())
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16),
    );
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [neon, neon.withAlpha(0x8C)],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
    canvas.restore();

    // The horizon, brightest under the sun.
    canvas.drawLine(
      Offset(0, horizon),
      Offset(size.width, horizon),
      Paint()
        ..strokeWidth = 1.5
        ..shader = LinearGradient(
          colors: [neon.withAlpha(0), neon.withAlpha(0xB3), neon.withAlpha(0)],
          stops: const [0, .5, 1],
        ).createShader(Rect.fromLTWH(0, horizon - 1, size.width, 2)),
    );
  }

  @override
  bool shouldRepaint(_SunrisePainter old) => old.t != t;
}
