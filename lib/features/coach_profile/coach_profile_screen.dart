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
import '../../widgets/surfaces.dart';
import '../../widgets/tap.dart';
import '../plaque/plaque_qr.dart';
import '../profile/body_card.dart';
import '../profile/role_switch.dart';
import '../updates/update_sheet.dart';
import '../profile/call_friend.dart';
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
        Paper(
          watermark: initials(c.name).isEmpty ? null : initials(c.name)[0],
          markTop: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Avatar(
                    ini: initials(c.name),
                    size: 64,
                    fontSize: 22,
                    weight: 900,
                    fill: BoltColors.paperInk,
                    color: BoltColors.neon,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(c.name, style: BoltText.display(tsz(c.name, 40), color: BoltColors.paperInk)),
              const SizedBox(height: 4),
              Text(
                gym.isEmpty ? tx(c.role) : '${tx(c.role)} · $gym',
                style: BoltText.a(13, color: BoltColors.paperMuted),
              ),
              const SizedBox(height: 16),
              FigureGrid(
                cells: [('${my.length}', tx('TRAINEES')), ('$planned', tx('THIS WEEK')), ('$waiting', tx('WAITING'))],
                size: 26,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        BodyCard(
          body: c.body,
          onEdit: () => context.push('/edit-profile'),
          onProgress: () => context.push('/measurements'),
        ),
        const SizedBox(height: 20),
        Tap(
          onTap: () => context.push('/plaque'),
          child: BoltBox(
            radius: 20,
            color: BoltColors.surface1,
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
                      Text(tx('Check-in plaque'), style: BoltText.a(15, weight: 800)),
                      const SizedBox(height: 2),
                      Text(
                        tx('Print it for the entrance · scan in and out'),
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
        const RoleSwitch(),
        const CallFriendCard(),
        const SizedBox(height: 18),
        const UpdateCard(),
      ],
    );
  }
}
