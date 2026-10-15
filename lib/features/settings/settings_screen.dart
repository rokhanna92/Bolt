import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/share.dart';
import '../../data/bolt_store.dart';
import '../../services/backup.dart';
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
      title: 'Reset Bolt?',
      body: 'This erases your profile, plans, workouts, gym visits and badges from this phone. It cannot be undone.',
      confirm: 'Erase everything',
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
      if (ok == true) store.toast('Backup saved');
    } catch (_) {
      store.toast('Could not save the backup');
    }
  }

  /// Replaces everything with a backup file the user picks.
  Future<void> _restore(BuildContext context, WidgetRef ref) async {
    final ok = await confirmSheet(
      context,
      title: 'Restore a backup?',
      body: 'Everything on this phone is replaced by the backup you pick: profile, plans, workouts, visits and badges.',
      confirm: 'Pick backup file',
    );
    if (!ok) return;
    final store = ref.read(boltProvider.notifier);
    try {
      final text = await BackupFiles.open();
      if (text == null) return;
      final error = store.restore(text);
      if (error != null) store.toast(error);
    } catch (_) {
      store.toast('Could not read that file');
    }
  }

  void _privacy(BuildContext context) {
    showBoltSheet<void>(
      context,
      (context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Privacy', style: BoltText.a(20, weight: 900)),
          const SizedBox(height: 8),
          Text(
            'Bolt keeps everything on this phone: your profile, body measurements, plans, workouts and gym visits. '
            'There is no account and nothing is uploaded.\n\n'
            'A plan or update only leaves the phone when you share it yourself, as a message to your coach or trainee.',
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
        'NOTIFICATIONS',
        [
          if (isT)
            _Row(
              'Session reminders',
              sub: '2 hours before a planned session',
              toggle: s.remind,
              onTap: () => store.toggleSetting('remind'),
            ),
          _Row(
            'Check-out reminder',
            sub: 'If you are still checked in after 3 hours',
            toggle: s.checkout,
            onTap: () => store.toggleSetting('checkout'),
          ),
        ],
      ),
      (
        'TRAINING',
        [
          _Row('Units', value: s.kg ? 'kg · cm' : 'lb · in', onTap: store.toggleUnits),
          _Row('Week starts on', value: s.mondayFirst ? 'Monday' : 'Sunday', onTap: store.toggleWeekStart),
          _Row('Default rest timer', value: '${s.restSecs} s', onTap: store.cycleRest),
        ],
      ),
      (
        'GYM',
        [
          _Row(
            'Home gym',
            value: s.gymName.isEmpty ? 'Not set' : s.gymName,
            onTap: () => context.push('/edit-profile'),
          ),
          _Row('Check-in plaque', value: 'Print', onTap: () => context.push('/plaque')),
        ],
      ),
      (
        'DATA',
        [
          _Row(
            'Back up to a file',
            sub: 'Save everything to Drive, Downloads or any folder',
            value: '',
            onTap: () => _backup(ref),
          ),
          _Row(
            'Restore from a backup',
            sub: 'Replaces everything on this phone',
            value: '',
            onTap: () => _restore(context, ref),
          ),
        ],
      ),
      (
        'ACCOUNT',
        [
          _Row('Edit profile', value: '', onTap: () => context.push('/edit-profile')),
          _Row('Privacy', value: '', onTap: () => _privacy(context)),
          _Row('Reset app', danger: true, onTap: () => _reset(context, ref)),
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
                Text('Settings', style: BoltText.a(24, weight: 900)),
              ],
            ),
            for (final (title, rows) in groups) ...[
              const SizedBox(height: 22),
              Kicker(title, size: 10),
              const SizedBox(height: 8),
              BoltBox(
                color: BoltColors.surface1,
                stroke: const Stroke(BoltColors.lineSoft),
                radius: 18,
                clip: true,
                child: Column(children: [for (final r in rows) _row(r)]),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _row(_Row r) {
    return Tap(
      onTap: r.onTap,
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
                child: Text(
                  '${r.value} ›',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: BoltText.a(13, color: BoltColors.muted),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
