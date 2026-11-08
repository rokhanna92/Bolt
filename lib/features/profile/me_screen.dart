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
import '../../widgets/surfaces.dart';
import '../../widgets/tap.dart';
import '../sharing/import_sheet.dart';
import '../updates/update_sheet.dart';
import 'call_friend.dart';
import 'body_card.dart';
import 'role_switch.dart';

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
    final line = withCoach
        ? (coachName == null ? tx('Trainee') : tx('Trainee · Coach {name}', {'name': coachName}))
        : tx('Training solo');
    return ScreenScroll(
      children: [
        ProfileHeader(onSettings: () => context.push('/settings')),
        const SizedBox(height: 14),
        // Who you are, on paper, with your numbers.
        Paper(
          watermark: initials(t.name).isEmpty ? null : initials(t.name)[0],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Avatar(
                    ini: initials(t.name),
                    size: 64,
                    fontSize: 22,
                    weight: 900,
                    fill: BoltColors.paperInk,
                    color: BoltColors.neon,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(t.name, style: BoltText.display(tsz(t.name, 40), color: BoltColors.paperInk)),
              const SizedBox(height: 4),
              Text(line, style: BoltText.a(13, color: BoltColors.paperMuted)),
              const SizedBox(height: 16),
              FigureGrid(
                cells: [
                  ('${t.stats.sessions}', tx('GYM VISITS')),
                  ('${t.stats.mins ~/ 60}', tx('HOURS')),
                  ('${currentStreak(t.stats, store.now)}', tx('WEEK STREAK')),
                ],
                size: 26,
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        BoltBox(
          color: BoltColors.surface1,
          radius: 16,
          child: Column(
            children: [
              _Fact(
                icon: Icons.flag_outlined,
                label: tx('GOAL'),
                value: tx(t.goal),
                onTap: () => context.push('/edit-profile'),
              ),
              _Fact(
                icon: Icons.calendar_view_week_outlined,
                label: tx('WEEKLY SPLIT'),
                value: tx(splitOf(d, t.split).name),
                onTap: () => context.push('/edit-profile'),
              ),
              _Fact(icon: Icons.event_available, label: tx('TRAINING SINCE'), value: monthYear(t.since), last: true),
            ],
          ),
        ),
        const SizedBox(height: 24),
        BodyCard(
          body: t.body,
          onEdit: () => context.push('/edit-profile'),
          onProgress: () => context.push('/measurements'),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(child: SectionTitle(tx('Injuries & limits'))),
            Tap(
              onTap: () => showInjurySheet(t.id),
              child: Text(tx('+ Report'), style: BoltText.a(13, weight: 700, color: BoltColors.warn)),
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
                  ? tx('No active injuries. If something hurts, report it and your coach gets safer swaps for you.')
                  : tx(
                      'No active injuries. If something hurts, report it and exercises that load it show safer swaps.',
                    ),
              style: BoltText.a(13, color: BoltColors.muted),
            ),
          ),
        if (withCoach) ...[
          const SizedBox(height: 24),
          SectionTitle(tx('Your coach')),
          const SizedBox(height: 10),
          _CoachCard(name: coachName),
        ],
        const SizedBox(height: 24),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: DoorTile(
                  title: tx('Progress'),
                  sub: tx('Lifts, records, muscle volume, last week and challenges'),
                  color: BoltColors.neon,
                  onTap: () => context.push('/progress'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DoorTile(
                  title: tx('Atlas'),
                  sub: tx('Training styles, muscles, form, moving more and supplements'),
                  color: BoltColors.heat,
                  onTap: () => context.push('/guide'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const RoleSwitch(),
        const CallFriendCard(),
        const SizedBox(height: 18),
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
        Expanded(child: Kicker(tx('PROFILE'))),
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
      color: Color.alphaBlend(BoltColors.warn.withAlpha(0x1A), BoltColors.surface1),
      radius: 18,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(tx(kAreas[injury.area] ?? injury.area), style: BoltText.a(14, weight: 800, color: BoltColors.warn)),
          const SizedBox(height: 4),
          Text(tx(injury.note), style: BoltText.a(13, height: 1.4)),
          const SizedBox(height: 4),
          Kicker(byLine(injury.by), size: 10, spacing: 0),
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
                    Text(name ?? tx('Your coach'), style: BoltText.a(15, weight: 800)),
                    const SizedBox(height: 2),
                    Text(
                      tx('Plans come as a message. Import them here, send your progress back.'),
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
                  label: tx('Import plan'),
                  height: 44,
                  radius: 12,
                  fontSize: 13,
                  onTap: () => showBoltSheet<void>(context, (_) => const ImportSheet()),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlineButton(
                  label: tx('Send update'),
                  height: 44,
                  radius: 12,
                  fontSize: 13,
                  onTap: () async {
                    final hint = await shareMessage(store.updateMessage(), subject: tx('Bolt update'));
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

/// One line about the owner: what it is, and its value.
class _Fact extends StatelessWidget {
  const _Fact({required this.icon, required this.label, required this.value, this.onTap, this.last = false});

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Tap(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: last
            ? null
            : const BoxDecoration(
                border: Border(bottom: BorderSide(color: BoltColors.divider)),
              ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: BoltColors.neon),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Kicker(label, size: 9),
                  const SizedBox(height: 2),
                  Text(value, style: BoltText.a(14, weight: 700)),
                ],
              ),
            ),
            if (onTap != null) const Chevron(size: 18),
          ],
        ),
      ),
    );
  }
}
