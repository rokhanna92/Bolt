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
/// check-in. Skip goes straight in, and the card on Today still asks. It
/// stays away on a day already checked in, skipped, trained or with a
/// workout running.
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
                        onSaved: () => setState(() => _saved = true),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The day and a greeting, with Skip.
  Widget _header(String name) {
    final now = ref.read(boltProvider.notifier).now;
    final greet = now.hour < 12
        ? 'Good morning, {name}'
        : now.hour < 18
        ? 'Good afternoon, {name}'
        : 'Good evening, {name}';
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 12, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Kicker(
                  '${tx('NEW DAY')} · ${weekdays[jsDay(now)]} ${dayMonth(now)}'.toUpperCase(),
                  size: 10,
                  color: BoltColors.neon,
                ),
              ),
              if (!_saved)
                Tap(
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
            ],
          ),
          const SizedBox(height: 10),
          Text(tx(greet, {'name': vocative(firstName(name))}), style: BoltText.display(30, height: 1.05)),
          const SizedBox(height: 6),
          Text(
            tx('A quick check-in and Bolt sets today to how you feel.'),
            style: BoltText.a(13, color: BoltColors.muted, height: 1.35),
          ),
        ],
      ),
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
