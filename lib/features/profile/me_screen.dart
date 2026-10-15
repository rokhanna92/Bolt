import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/actions.dart';
import '../../app/share.dart';
import '../../core/format.dart';
import '../../data/bolt_store.dart';
import '../../data/models/bolt_data.dart';
import '../../data/models/people.dart';
import '../../data/rules.dart';
import '../../data/seed/splits.dart';
import '../../data/seed/templates.dart';
import '../../theme/text_styles.dart';
import '../../theme/tokens.dart';
import '../../widgets/bolt_sheet.dart';
import '../../widgets/box.dart';
import '../../widgets/common.dart';
import '../../widgets/tap.dart';
import '../sharing/import_sheet.dart';
import '../updates/update_sheet.dart';
import 'admin_switch.dart';
import 'body_card.dart';

class MeScreen extends ConsumerWidget {
  const MeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(boltProvider);
    final store = ref.read(boltProvider.notifier);
    final t = store.trOrNull(d.account?.id ?? '');
    if (t == null) return const SizedBox.shrink();
    final coachName = store.coachNameOf(t);
    final withCoach = d.account?.role == Role.trainee;
    final line = withCoach ? (coachName == null ? 'Trainee' : 'Trainee · Coach $coachName') : 'Training solo';
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
                  Text(t.name, style: BoltText.a(24, weight: 900, spacing: -.02)),
                  const SizedBox(height: 4),
                  Text(line, style: BoltText.a(13, color: BoltColors.muted)),
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
        BodyCard(body: t.body, onEdit: () => context.push('/edit-profile')),
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
              withCoach
                  ? 'No active injuries. If something hurts, report it and your coach gets safer swaps for you.'
                  : 'No active injuries. If something hurts, report it and exercises that load it show safer swaps.',
              style: BoltText.a(13, color: BoltColors.muted),
            ),
          ),
        if (withCoach) ...[
          const SizedBox(height: 24),
          const SectionTitle('Your coach'),
          const SizedBox(height: 10),
          _CoachCard(name: coachName),
        ],
        const SizedBox(height: 24),
        Tap(
          onTap: () => context.push('/workouts'),
          child: BoltBox(
            color: BoltColors.surface1,
            stroke: const Stroke(BoltColors.lineSoft),
            radius: 20,
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const BoltBox(
                  width: 46,
                  height: 46,
                  radius: 14,
                  stroke: Stroke(BoltColors.neon, 1.5),
                  alignment: Alignment.center,
                  child: BoltIcon('plate', color: BoltColors.neon),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Workouts', style: BoltText.a(15, weight: 800)),
                      const SizedBox(height: 3),
                      Text(
                        'Templates and splits used when you plan or auto-fill',
                        style: BoltText.a(12, color: BoltColors.muted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                const Chevron(),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        const AdminSwitch(),
        const UpdateCard(),
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

/// The trainee's coach, with the two ways plans and progress travel.
class _CoachCard extends ConsumerWidget {
  const _CoachCard({required this.name});

  final String? name;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.read(boltProvider.notifier);
    return BoltBox(
      color: BoltColors.surface1,
      stroke: const Stroke(BoltColors.lineSoft),
      radius: 16,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Avatar(ini: name == null ? '?' : initials(name!), ring: BoltColors.neon, color: BoltColors.neon),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name ?? 'Your coach', style: BoltText.a(15, weight: 800)),
                    const SizedBox(height: 2),
                    Text(
                      'Plans come as a message. Import them here, send your progress back.',
                      style: BoltText.a(12, color: BoltColors.muted, height: 1.4),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: NeonButton(
                  label: 'Import plan',
                  height: 44,
                  radius: 12,
                  fontSize: 13,
                  onTap: () => showBoltSheet<void>(context, (_) => const ImportSheet()),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlineButton(
                  label: 'Send update',
                  height: 44,
                  radius: 12,
                  fontSize: 13,
                  onTap: () async {
                    final hint = await shareMessage(store.updateMessage(), subject: 'Bolt update');
                    if (hint != null) store.toast(hint);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
