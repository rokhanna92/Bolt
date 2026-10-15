import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../data/bolt_store.dart';
import '../../data/models/session.dart';
import '../../theme/text_styles.dart';
import '../../theme/tokens.dart';
import '../../widgets/common.dart';

/// Turn this week or next week into a deload week (half the sets), or back.
class DeloadSheet extends ConsumerWidget {
  const DeloadSheet({super.key, required this.tid});

  final String tid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(boltProvider);
    final store = ref.read(boltProvider.notifier);
    final coach = ref.read(boltProvider).account?.isCoach ?? false;
    final p = store.plan(tid);
    Widget week(String label, DateTime mon) {
      final sessions = [
        for (var i = 0; i < 7; i++)
          if (p[dk(addDays(mon, i))] case final Session s when s.status != SessionStatus.done) s,
      ];
      final on = sessions.any((s) => s.deload);
      final text = '$label · ${fmtDay(dk(mon))} to ${fmtDay(dk(addDays(mon, 6)))}';
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: on
            ? OutlineButton(label: 'Undo deload · $label', onTap: () => store.toggleDeload(tid, mon))
            : NeonButton(
                label: sessions.isEmpty ? '$text · nothing planned' : 'Deload $text',
                height: 50,
                fontSize: 13,
                scale: 1,
                color: sessions.isEmpty ? BoltColors.line : BoltColors.neon,
                textColor: sessions.isEmpty ? BoltColors.muted : BoltColors.ink,
                onTap: sessions.isEmpty ? null : () => store.toggleDeload(tid, mon),
              ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Deload week', style: BoltText.a(20, weight: 900)),
        const SizedBox(height: 4),
        Text(
          'Every 4-8 weeks, an easier week lets joints and muscles catch up so you come back stronger. '
          'Every session that week keeps its exercises with half the sets, and a note to go about 10% lighter.'
          '${coach ? ' The changed days become drafts to send again.' : ''}',
          style: BoltText.a(13, color: BoltColors.muted, height: 1.45),
        ),
        const SizedBox(height: 16),
        week('This week', store.mon0),
        week('Next week', addDays(store.mon0, 7)),
      ],
    );
  }
}
