import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../data/bolt_store.dart';
import '../../data/models/session.dart';
import '../../theme/text_styles.dart';
import '../../theme/tokens.dart';
import '../../widgets/bolt_sheet.dart';
import '../../widgets/box.dart';
import '../../widgets/common.dart';
import '../../widgets/fields.dart';
import '../../widgets/tap.dart';
import '../plaque/plaque_qr.dart';
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
    final live = my.where((x) => d.gymIn[x.id] != null).length;

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
                  Text(c.name, style: BoltText.a(24, weight: 900, height: 1.2)),
                  const SizedBox(height: 4),
                  Text(c.role, style: BoltText.a(13, color: BoltColors.muted)),
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
            StatTile(value: '$live', label: 'IN GYM', gap: 0),
          ],
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            const Expanded(child: SectionTitle('Coaches')),
            Tap(
              onTap: () => showBoltSheet<void>(context, (_) => const AddCoachSheet()),
              child: Text('+ Add coach', style: BoltText.a(13, weight: 700, color: BoltColors.neon)),
            ),
          ],
        ),
        const SizedBox(height: 10),
        for (final co in d.coaches) ...[
          BoltBox(
            color: BoltColors.surface1,
            stroke: const Stroke(BoltColors.lineSoft),
            radius: 16,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Avatar(ini: initials(co.name), size: 40, fontSize: 13, ring: BoltColors.neon, color: BoltColors.neon),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(text: co.name, style: BoltText.a(14, weight: 800)),
                            if (co.id == c.id) ...[
                              const WidgetSpan(child: SizedBox(width: 4)),
                              TextSpan(
                                text: ' YOU',
                                style: BoltText.m(9, color: BoltColors.neon),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(co.role, style: BoltText.a(12, color: BoltColors.muted)),
                    ],
                  ),
                ),
                Text(
                  plural(d.trainees.where((x) => x.coach == co.id).length, 'trainee').toUpperCase(),
                  style: BoltText.m(9, color: BoltColors.muted),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
        const SizedBox(height: 12),
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
                      Text('Gym plaque QR', style: BoltText.a(15, weight: 800)),
                      const SizedBox(height: 2),
                      Text(
                        'Fixed code at the entrance · print or reorder',
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
      ],
    );
  }
}

class AddCoachSheet extends ConsumerStatefulWidget {
  const AddCoachSheet({super.key});

  @override
  ConsumerState<AddCoachSheet> createState() => _AddCoachSheetState();
}

class _AddCoachSheetState extends ConsumerState<AddCoachSheet> {
  final _name = TextEditingController();
  final _role = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _role.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ok = _name.text.trim().isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Add coach', style: BoltText.a(20, weight: 900)),
        const SizedBox(height: 10),
        BoltField(controller: _name, hint: 'Full name', onChanged: (_) => setState(() {})),
        const SizedBox(height: 10),
        BoltField(controller: _role, hint: 'Specialty, e.g. Powerlifting'),
        const SizedBox(height: 10),
        NeonButton(
          label: 'Add coach',
          height: 52,
          scale: 1,
          color: ok ? BoltColors.neon : BoltColors.line,
          textColor: ok ? BoltColors.ink : BoltColors.muted,
          onTap: () {
            if (ref.read(boltProvider.notifier).addCoach(_name.text, _role.text)) Navigator.of(context).pop();
          },
        ),
      ],
    );
  }
}
