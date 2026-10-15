import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../data/bolt_store.dart';
import '../../data/models/session.dart';
import '../../theme/text_styles.dart';
import '../../theme/tokens.dart';
import '../../widgets/box.dart';
import '../../widgets/common.dart';
import '../../widgets/tap.dart';
import '../plaque/plaque_qr.dart';
import '../profile/body_card.dart';
import '../updates/update_sheet.dart';
import '../profile/me_screen.dart' show ProfileHeader;

class CoachProfileScreen extends ConsumerWidget {
  const CoachProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(boltProvider);
    final store = ref.read(boltProvider.notifier);
    final c = store.co(d.account?.id ?? '');
    final my = d.trainees.where((x) => x.coach == c.id).toList();
    final mon = monday(store.now);
    var planned = 0;
    for (final x in my) {
      for (var i = 0; i < 7; i++) {
        final s = store.plan(x.id)[dk(addDays(mon, i))];
        if (s != null && s.status != SessionStatus.draft) planned++;
      }
    }
    final waiting = my.fold(
      0,
      (n, x) => n + store.plan(x.id).values.where((s) => s.status == SessionStatus.pending).length,
    );
    final gym = d.settings.gymName;

    return ScreenScroll(
      children: [
        ProfileHeader(onSettings: () => context.push('/settings')),
        const SizedBox(height: 14),
        Row(
          children: [
            Avatar(ini: initials(c.name), size: 76, fontSize: 26, weight: 900, fill: BoltColors.neon),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(c.name, style: BoltText.a(24, weight: 900)),
                  const SizedBox(height: 4),
                  Text(gym.isEmpty ? c.role : '${c.role} · $gym', style: BoltText.a(13, color: BoltColors.muted)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        StatRow(
          children: [
            StatTile(value: '${my.length}', label: 'TRAINEES', valueColor: BoltColors.neon, gap: 0),
            StatTile(value: '$planned', label: 'THIS WEEK', gap: 0),
            StatTile(value: '$waiting', label: 'WAITING', gap: 0),
          ],
        ),
        const SizedBox(height: 24),
        BodyCard(body: c.body, onEdit: () => context.push('/edit-profile')),
        const SizedBox(height: 20),
        Tap(
          onTap: () => context.push('/plaque'),
          child: BoltBox(
            radius: 18,
            stroke: const Stroke(BoltColors.line),
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                const BoltBox(
                  width: 48,
                  height: 48,
                  borderBox: true,
                  radius: 10,
                  color: BoltColors.text,
                  padding: EdgeInsets.all(5),
                  child: PlaqueQr(),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Check-in plaque', style: BoltText.a(15, weight: 800)),
                      const SizedBox(height: 2),
                      Text(
                        'Print it for the entrance · scan in and out',
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
        const UpdateCard(),
      ],
    );
  }
}
