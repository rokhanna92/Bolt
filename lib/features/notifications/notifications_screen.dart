import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/pwa.dart';
import '../../data/bolt_store.dart';
import '../../data/seed/learn.dart';
import '../../services/haptics.dart';
import '../../services/notifications.dart' show Reminder;
import '../../theme/text_styles.dart';
import '../../theme/tokens.dart';
import '../../widgets/box.dart';
import '../../widgets/common.dart';
import '../../widgets/tap.dart';
import '../../widgets/time_wheel.dart';
import '../updates/update_sheet.dart' show UpdateCard, newReleaseProvider;

/// The bell on the home screen. The dot means an update is waiting or the
/// owner sent something since the screen was last opened.
class NotificationBell extends ConsumerWidget {
  const NotificationBell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(boltProvider);
    final dot = ref.watch(newReleaseProvider) != null || ref.read(boltProvider.notifier).bellUnread;
    return SquareButton(
      onTap: () => context.push('/notifications'),
      semanticLabel: tx('Notifications'),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          const BoltIcon('bell', size: 22),
          if (dot)
            Positioned(
              top: -1,
              right: -1,
              child: BoltBox(width: 9, height: 9, radius: 99, color: BoltColors.neon, child: const SizedBox()),
            ),
        ],
      ),
    );
  }
}

/// Everything that can reach this phone: news and updates first, then the
/// daily reminders and the training ones.
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(boltProvider.notifier).markBellSeen();
    });
  }

  Future<void> _pick(DailySupp x, int minute) async {
    final store = ref.read(boltProvider.notifier);
    final v = await pickTime(context, minute, title: tx(x.short));
    if (v != null) store.setSuppTime(x.name, v);
  }

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(boltProvider);
    final store = ref.read(boltProvider.notifier);
    final s = d.settings;
    final isT = d.account?.isTrainee ?? true;
    final insets = MediaQuery.paddingOf(context);
    final news = store.recentPushes();
    return BoltPage(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, insets.top + 16, 20, 60 + insets.bottom),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                BackBox(onTap: () => context.pop()),
                const SizedBox(width: 12),
                Text(tx('Notifications'), style: BoltText.display(24)),
              ],
            ),
            const SizedBox(height: 22),
            if (news.isNotEmpty) ...[
              SectionTitle(tx('News')),
              const SizedBox(height: 10),
              for (final n in news) ...[_NewsCard(n), const SizedBox(height: 8)],
              const SizedBox(height: 16),
            ],
            // No push server and no APK: the bell only carries news here.
            if (isPwa && news.isEmpty)
              Text(tx('No news yet. Messages from Bolt show up here.'), style: BoltText.a(14, color: BoltColors.muted)),
            if (!isPwa) ...[
              const UpdateCard(),
              const SizedBox(height: 26),
              SectionTitle(tx('Water')),
              const SizedBox(height: 10),
              _WaterCard(on: s.water, hours: s.waterHours),
              const SizedBox(height: 26),
              SectionTitle(tx('Supplements')),
              const SizedBox(height: 2),
              Text(tx('Tap what you take every day and set its time.'), style: BoltText.a(12, color: BoltColors.muted)),
              for (final (group, items) in kDailySupps) ...[
                const SizedBox(height: 16),
                Kicker(tx(group).toUpperCase()),
                const SizedBox(height: 8),
                for (var i = 0; i < items.length; i += 2) ...[
                  if (i > 0) const SizedBox(height: 8),
                  Row(
                    children: [
                      for (final x in items.skip(i).take(2)) ...[
                        if (x != items[i]) const SizedBox(width: 8),
                        Expanded(
                          child: _SuppTile(
                            x: x,
                            minute: s.supps[x.name],
                            onTap: () {
                              Haptics.play(Feel.tick);
                              final m = s.supps[x.name];
                              if (m == null) store.toggleSupp(x.name);
                              _pick(x, m ?? 9 * 60);
                            },
                            onRemove: () {
                              Haptics.play(Feel.off);
                              store.toggleSupp(x.name);
                            },
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ],
              const SizedBox(height: 26),
              SectionTitle(tx('Training')),
              const SizedBox(height: 10),
              BoltBox(
                color: BoltColors.surface1,
                radius: 18,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Column(
                  children: [
                    if (isT)
                      _ToggleRow(
                        tx('Session reminders'),
                        tx('{time} before a planned session, and a nudge after 3 days off', {
                          'time': spanText(s.board.times.before),
                        }),
                        s.remind,
                        () => store.toggleSetting('remind'),
                      ),
                    if (isT)
                      _ToggleRow(
                        tx('Morning brief'),
                        tx('{time} on training days: your workout and what to beat', {
                          'time': fromMin(s.board.times.brief),
                        }),
                        s.brief,
                        () => store.toggleSetting('brief'),
                      ),
                    _ToggleRow(
                      tx('Check-out reminder'),
                      tx('If you are still checked in after {time}', {'time': spanText(s.board.times.checkout)}),
                      s.checkout,
                      () => store.toggleSetting('checkout'),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _NewsCard extends StatelessWidget {
  const _NewsCard(this.n);

  final Reminder n;

  @override
  Widget build(BuildContext context) => BoltBox(
    color: BoltColors.surface1,
    radius: 16,
    padding: const EdgeInsets.all(14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(n.title, style: BoltText.a(15, weight: 800)),
        if (n.body.isNotEmpty) ...[
          const SizedBox(height: 3),
          Text(n.body, style: BoltText.a(13, color: BoltColors.muted, height: 1.4)),
        ],
      ],
    ),
  );
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow(this.title, this.sub, this.on, this.onTap);

  final String title;
  final String sub;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tap(
    onTap: () {
      Haptics.play(on ? Feel.off : Feel.on);
      onTap();
    },
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: BoltText.a(15, weight: 800)),
                const SizedBox(height: 2),
                Text(sub, style: BoltText.a(12, color: BoltColors.muted)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          BoltSwitch(on: on),
        ],
      ),
    ),
  );
}

/// The water switch and, once on, four equal steps for how often.
class _WaterCard extends ConsumerWidget {
  const _WaterCard({required this.on, required this.hours});

  final bool on;
  final int hours;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.read(boltProvider.notifier);
    return BoltBox(
      color: BoltColors.surface1,
      stroke: Stroke(on ? BoltColors.neon.withAlpha(0x73) : BoltColors.lineSoft),
      radius: 18,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Tap(
            onTap: () {
              Haptics.play(on ? Feel.off : Feel.on);
              store.toggleSetting('water');
            },
            child: Row(
              children: [
                BoltIcon('drop', size: 26, color: on ? BoltColors.neon : BoltColors.muted2),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    tx('A cup of water every {time}, from 09:00 to 21:00', {'time': spanText(hours * 60)}),
                    style: BoltText.a(13, weight: 700),
                  ),
                ),
                const SizedBox(width: 12),
                BoltSwitch(on: on),
              ],
            ),
          ),
          if (on) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                for (final h in const [1, 2, 3, 4]) ...[
                  if (h > 1) const SizedBox(width: 6),
                  Expanded(
                    child: Tap(
                      onTap: () {
                        Haptics.play(Feel.tick);
                        store.setWaterHours(h);
                      },
                      child: BoltBox(
                        height: 38,
                        radius: 10,
                        alignment: Alignment.center,
                        color: h == hours ? BoltColors.neon : BoltColors.surface2,
                        stroke: Stroke(h == hours ? BoltColors.neon : BoltColors.line),
                        child: Text(
                          spanText(h * 60),
                          style: BoltText.a(13, weight: 800, color: h == hours ? BoltColors.onNeon : BoltColors.text),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// One supplement, all the same size. Off it says what it is for; on it has a
/// neon border, its time and an X to take it off again.
class _SuppTile extends StatelessWidget {
  const _SuppTile({required this.x, required this.minute, required this.onTap, required this.onRemove});

  final DailySupp x;
  final int? minute;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final m = minute;
    return Tap(
      onTap: onTap,
      child: BoltBox(
        height: 70,
        radius: 14,
        color: BoltColors.surface1,
        stroke: m != null ? Stroke(BoltColors.neon, 1.5) : const Stroke(BoltColors.lineSoft),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 20,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(tx(x.short), style: BoltText.a(14, weight: 800)),
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (m != null)
                    Text(fromMin(m), style: BoltText.m(14, weight: 700, color: BoltColors.neon))
                  else
                    Text(tx(x.why), maxLines: 1, style: BoltText.a(11, color: BoltColors.muted)),
                ],
              ),
            ),
            // 38 tall with its tap padding: top 3 centres the X on the name.
            if (m != null)
              Positioned(
                top: 3,
                right: 0,
                child: Tap(onTap: onRemove, child: const CloseGlyph()),
              ),
          ],
        ),
      ),
    );
  }
}
