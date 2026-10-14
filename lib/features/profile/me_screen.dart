import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/actions.dart';
import '../../core/format.dart';
import '../../data/bolt_store.dart';
import '../../data/models/people.dart';
import '../../data/rules.dart';
import '../../data/seed/splits.dart';
import '../../data/seed/templates.dart';
import '../../theme/text_styles.dart';
import '../../theme/tokens.dart';
import '../../widgets/box.dart';
import '../../widgets/common.dart';
import '../../widgets/tap.dart';

class MeScreen extends ConsumerWidget {
  const MeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(boltProvider);
    final store = ref.read(boltProvider.notifier);
    final t = store.trOrNull(d.account?.id ?? '');
    if (t == null) return const SizedBox.shrink();
    final coach = store.co(t.coach);
    return ScreenScroll(
      children: [
        ProfileHeader(onSettings: () => context.push('/settings')),
        const SizedBox(height: 14),
        Row(
          children: [
            Avatar(ini: initials(t.name), size: 76, fontSize: 26, weight: 900, fill: BoltColors.neon),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t.name, style: BoltText.a(24, weight: 900, spacing: -.02, height: 1.2)),
                  const SizedBox(height: 4),
                  Text('Trainee · Coach ${coach.name}', style: BoltText.a(13, color: BoltColors.muted)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final c in [t.goal, kSplits[t.split]!.name, 'Since ${t.since}'])
              BoltBox(
                radius: 99,
                stroke: const Stroke(BoltColors.line),
                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                child: Text(c, style: BoltText.a(12, weight: 600)),
              ),
          ],
        ),
        const SizedBox(height: 18),
        StatRow(
          children: [
            StatTile(value: '${t.stats.sessions}', label: 'SESSIONS', valueColor: BoltColors.neon),
            StatTile(value: '${t.stats.mins ~/ 60}', label: 'HOURS'),
            StatTile(value: '${currentStreak(t.stats, store.now)}', label: 'WEEK STREAK'),
          ],
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            const Expanded(child: SectionTitle('Injuries & limits')),
            Tap(
              onTap: () => showInjurySheet(t.id),
              child: Text('+ Report', style: BoltText.a(13, weight: 700, color: BoltColors.warn)),
            ),
          ],
        ),
        const SizedBox(height: 10),
        for (final i in t.injuries) ...[InjuryCard(injury: i), const SizedBox(height: 8)],
        if (t.injuries.isEmpty)
          BoltBox(
            radius: 14,
            stroke: const Stroke.dashed(BoltColors.line),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Text(
              'No active injuries. If something hurts, report it and your coach gets safer swaps for you.',
              style: BoltText.a(13, color: BoltColors.muted),
            ),
          ),
        const SizedBox(height: 24),
        const SectionTitle('Your coach'),
        const SizedBox(height: 10),
        BoltBox(
          color: BoltColors.surface1,
          stroke: const Stroke(BoltColors.lineSoft),
          radius: 16,
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Avatar(ini: initials(coach.name), ring: BoltColors.neon, color: BoltColors.neon),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(coach.name, style: BoltText.a(15, weight: 800)),
                    const SizedBox(height: 2),
                    Text(coach.role, style: BoltText.a(12, color: BoltColors.muted)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// "PROFILE" kicker with the settings button.
class ProfileHeader extends StatelessWidget {
  const ProfileHeader({super.key, required this.onSettings});

  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Kicker('PROFILE')),
        SquareButton(onTap: onSettings, size: 42, child: const BoltIcon('sliders', size: 20)),
      ],
    );
  }
}

class InjuryCard extends StatelessWidget {
  const InjuryCard({super.key, required this.injury});

  final Injury injury;

  @override
  Widget build(BuildContext context) {
    return BoltBox(
      color: BoltColors.surface1,
      stroke: const Stroke(Color(0x73FF7A45)),
      radius: 16,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(kAreas[injury.area] ?? injury.area, style: BoltText.a(14, weight: 800, color: BoltColors.warn)),
          const SizedBox(height: 4),
          Text(injury.note, style: BoltText.a(13, height: 1.4)),
          const SizedBox(height: 4),
          Kicker(injury.by, size: 10, spacing: 0),
        ],
      ),
    );
  }
}
