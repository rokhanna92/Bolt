import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/bolt_store.dart';
import '../../data/seed/demo.dart';
import '../../theme/text_styles.dart';
import '../../theme/tokens.dart';
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
          _Row(
            'Session reminders',
            sub: '2 hours before a planned session',
            toggle: s.remind,
            onTap: () => store.toggleSetting('remind'),
          ),
          _Row(
            'Plan updates',
            sub: isT ? 'When your coach plans or edits sessions' : 'When trainees confirm or move sessions',
            toggle: s.plans,
            onTap: () => store.toggleSetting('plans'),
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
          _Row('Units', value: s.kg ? 'kg' : 'lb', onTap: store.toggleUnits),
          _Row('Week starts on', value: s.mondayFirst ? 'Monday' : 'Sunday', onTap: store.toggleWeekStart),
          _Row('Default rest timer', value: '${s.restSecs} s', onTap: store.cycleRest),
        ],
      ),
      ('GYM', [const _Row('Home gym', value: Gym.name), const _Row('Check-in method', value: 'Plaque QR')]),
      (
        'ACCOUNT',
        [
          const _Row('Edit profile', value: ''),
          const _Row('Privacy', value: ''),
          _Row(
            'Sign out',
            danger: true,
            onTap: () {
              store.signOut();
              context.go('/login');
            },
          ),
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
            if (r.toggle != null) ...[const SizedBox(width: 12), _Toggle(on: r.toggle!)],
            if (r.value != null && !r.danger) ...[
              const SizedBox(width: 12),
              Text('${r.value} ›', style: BoltText.a(13, color: BoltColors.muted)),
            ],
          ],
        ),
      ),
    );
  }
}

class _Toggle extends StatelessWidget {
  const _Toggle({required this.on});

  final bool on;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 46,
      height: 26,
      decoration: BoxDecoration(color: on ? BoltColors.neon : BoltColors.line, borderRadius: BorderRadius.circular(99)),
      child: AnimatedAlign(
        duration: const Duration(milliseconds: 200),
        alignment: on ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          width: 22,
          height: 22,
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(color: on ? BoltColors.ink : BoltColors.muted, shape: BoxShape.circle),
        ),
      ),
    );
  }
}
