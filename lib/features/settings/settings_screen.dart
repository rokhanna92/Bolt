import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';

import '../../app/share.dart';
import '../../data/bolt_store.dart';
import '../../services/backup.dart';
import '../../services/haptics.dart';
import '../../services/rest_timer.dart';
import '../../theme/text_styles.dart';
import '../../theme/tokens.dart';
import '../../widgets/bolt_sheet.dart';
import '../../widgets/box.dart';
import '../../widgets/common.dart';
import '../../widgets/tap.dart';

class _Row {
  const _Row(this.label, {this.sub, this.toggle, this.value, this.onTap, this.danger = false});

  final String label;
  final String? sub;
  final bool? toggle;
  final String? value;
  final VoidCallback? onTap;
  final bool danger;
}

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _reset(BuildContext context, WidgetRef ref) async {
    final ok = await confirmSheet(
      context,
      title: tx('Reset Bolt?'),
      body: tx(
        tx('This erases your profile, plans, workouts, gym visits and badges from this phone. It cannot be undone.'),
      ),
      confirm: tx('Erase everything'),
    );
    if (ok && context.mounted) {
      ref.read(boltProvider.notifier).resetAll();
      context.go('/welcome');
    }
  }

  /// Saves everything as one file wherever the user picks.
  Future<void> _backup(WidgetRef ref) async {
    final store = ref.read(boltProvider.notifier);
    try {
      final ok = await BackupFiles.save('bolt-backup-${store.today}.json', store.backupText());
      if (ok == true) store.toast(tx('Backup saved'));
    } catch (_) {
      store.toast(tx('Could not save the backup'));
    }
  }

  /// Replaces everything with a backup file the user picks.
  Future<void> _restore(BuildContext context, WidgetRef ref) async {
    final ok = await confirmSheet(
      context,
      title: tx('Restore a backup?'),
      body: tx(
        tx('Everything on this phone is replaced by the backup you pick: profile, plans, workouts, visits and badges.'),
      ),
      confirm: tx('Pick backup file'),
    );
    if (!ok) return;
    final store = ref.read(boltProvider.notifier);
    try {
      final text = await BackupFiles.open();
      if (text == null) return;
      final error = store.restore(text);
      if (error != null) store.toast(error);
    } catch (_) {
      store.toast(tx('Could not read that file'));
    }
  }

  void _privacy(BuildContext context) {
    showBoltSheet<void>(
      context,
      (context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(tx('Privacy'), style: BoltText.a(20, weight: 900)),
          const SizedBox(height: 8),
          Text(
            tx(
              'Bolt keeps everything on this phone: your profile, body measurements, plans, workouts and gym visits. '
              'There is no account and nothing is uploaded.\n\n'
              'A plan or update only leaves the phone when you share it yourself, as a message to your coach or trainee.',
            ),
            style: BoltText.a(14, height: 1.5),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(boltProvider);
    final store = ref.read(boltProvider.notifier);
    final s = d.settings;
    final isT = d.account?.isTrainee ?? true;
    final insets = MediaQuery.paddingOf(context);
    final groups = <(String, List<_Row>)>[
      (
        tx('NOTIFICATIONS'),
        [
          if (isT)
            _Row(
              tx('Session reminders'),
              sub: tx('{time} before a planned session, and a nudge after 3 days off', {
                'time': spanText(s.board.times.before),
              }),
              toggle: s.remind,
              onTap: () => store.toggleSetting('remind'),
            ),
          if (isT)
            _Row(
              tx('Morning brief'),
              sub: tx('{time} on training days: your workout and what to beat', {'time': fromMin(s.board.times.brief)}),
              toggle: s.brief,
              onTap: () => store.toggleSetting('brief'),
            ),
          _Row(
            tx('Check-out reminder'),
            sub: tx('If you are still checked in after {time}', {'time': spanText(s.board.times.checkout)}),
            toggle: s.checkout,
            onTap: () => store.toggleSetting('checkout'),
          ),
        ],
      ),
      (
        tx('TRAINING'),
        [
          _Row(tx('Units'), value: s.kg ? 'kg · cm' : 'lb · in', onTap: store.toggleUnits),
          _Row(tx('Week starts on'), value: s.mondayFirst ? tx('Monday') : tx('Sunday'), onTap: store.toggleWeekStart),
          _Row(
            tx('Haptics'),
            sub: tx('Steppers tick, sets land with a thud, records swell'),
            toggle: s.haptics,
            onTap: () => store.toggleSetting('haptics'),
          ),
          _Row(
            tx('Default rest timer'),
            sub: s.restAuto ? tx('Longer for big lifts, shorter for isolation') : null,
            value: s.restAuto ? tx('Auto') : '${s.restSecs} s',
            onTap: store.cycleRest,
          ),
          _Row(
            tx('Rest sound'),
            sub: tx('Plays at the end of a rest, in your headphones when they are in'),
            value: tx(const {'chime': 'Chime', 'beep': 'Beep', 'off': 'Off'}[s.restSound] ?? 'Off'),
            onTap: () {
              Haptics.play(Feel.tick);
              ref.read(restTimerProvider).preview(store.cycleRestSound());
            },
          ),
          _Row(
            tx('3-2-1 countdown'),
            sub: tx('A tap, and a blip with a sound on, in the last 3 seconds of a rest'),
            toggle: s.countdown,
            onTap: () => store.toggleSetting('countdown'),
          ),
          _Row(
            tx('Volume down logs a set'),
            sub: tx('During a workout, press volume down instead of the big button'),
            toggle: s.volumeLog,
            onTap: () => store.toggleSetting('volumeLog'),
          ),
        ],
      ),
      (
        'GYM',
        [
          _Row(
            tx('Home gym'),
            value: s.gymName.isEmpty ? tx('Not set') : s.gymName,
            onTap: () => context.push('/edit-profile'),
          ),
          _Row(tx('Check-in plaque'), value: tx('Print'), onTap: () => context.push('/plaque')),
        ],
      ),
      if (d.account?.admin ?? false)
        (
          tx('ADMIN'),
          [
            _Row(
              tx('Push notifications'),
              sub: tx('When reminders go out on every phone, and your own pushes'),
              value: '',
              onTap: () => context.push('/admin'),
            ),
          ],
        ),
      (
        tx('DATA'),
        [
          _Row(
            tx('Back up to a file'),
            sub: tx('Save everything to Drive, Downloads or any folder'),
            value: '',
            onTap: () => _backup(ref),
          ),
          _Row(
            tx('Restore from a backup'),
            sub: tx('Replaces everything on this phone'),
            value: '',
            onTap: () => _restore(context, ref),
          ),
        ],
      ),
      (
        tx('ACCOUNT'),
        [
          _Row(tx('Edit profile'), value: '', onTap: () => context.push('/edit-profile')),
          _Row(tx('Privacy'), value: '', onTap: () => _privacy(context)),
        ],
      ),
    ];

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
                Text(tx('Settings'), style: BoltText.a(24, weight: 900)),
              ],
            ),
            for (final (title, rows) in groups) ...[
              const SizedBox(height: 22),
              Kicker(tx(title), size: 10),
              const SizedBox(height: 8),
              BoltBox(
                color: BoltColors.surface1,
                stroke: const Stroke(BoltColors.lineSoft),
                radius: 18,
                clip: true,
                child: Column(children: [for (final r in rows) _row(r)]),
              ),
            ],
            // Wiping the phone sits apart, so it is never tapped on the way
            // to Privacy.
            const SizedBox(height: 32),
            BoltBox(
              color: BoltColors.surface1,
              stroke: const Stroke(Color(0x66FF7A45)),
              radius: 18,
              clip: true,
              child: _row(_Row(tx('Reset app'), danger: true, onTap: () => _reset(context, ref))),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(_Row r) {
    return Tap(
      onTap: r.toggle == null
          ? r.onTap
          : () {
              // Plays before the switch flips, so turning haptics off still
              // answers this one tap.
              Haptics.play(r.toggle! ? Feel.off : Feel.on);
              r.onTap?.call();
            },
      child: Container(
        constraints: const BoxConstraints(minHeight: 52),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: BoltColors.divider)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    r.label,
                    style: BoltText.a(14, weight: 700, color: r.danger ? BoltColors.warn : BoltColors.text),
                  ),
                  if (r.sub != null) ...[
                    const SizedBox(height: 2),
                    Text(r.sub!, style: BoltText.a(12, color: BoltColors.muted)),
                  ],
                ],
              ),
            ),
            if (r.toggle != null) ...[const SizedBox(width: 12), BoltSwitch(on: r.toggle!)],
            if (r.value != null && !r.danger) ...[
              const SizedBox(width: 12),
              // Long gym names truncate instead of squeezing the label.
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 170),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (r.value!.isNotEmpty)
                      Flexible(
                        child: Text(
                          r.value!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: BoltText.a(13, color: BoltColors.muted),
                        ),
                      ),
                    const SizedBox(width: 2),
                    const Chevron(size: 18),
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
