import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../data/bolt_store.dart';
import '../../data/programs.dart';
import '../../theme/text_styles.dart';
import '../../theme/tokens.dart';
import '../../widgets/box.dart';
import '../../widgets/common.dart';
import '../../widgets/tap.dart';

/// "Week 2 of 4" for [tid]'s program, or null without one.
String? programWeekText(BoltStore store, String tid) {
  final t = store.trOrNull(tid);
  final prog = programById(t?.program);
  final start = t?.programStart;
  if (prog == null || start == null) return null;
  final w = store.now.difference(pk(start)).inDays ~/ 7 + 1;
  return w > prog.weeks.length
      ? tx('{name} · finished', {'name': tx(prog.name)})
      : tx('{name} · week {w} of {n}', {'name': tx(prog.name), 'w': w, 'n': prog.weeks.length});
}

/// Pick a multi-week program for the main lifts, or stop the current one.
class ProgramSheet extends ConsumerWidget {
  const ProgramSheet({super.key, required this.tid});

  final String tid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(boltProvider);
    final store = ref.read(boltProvider.notifier);
    final coach = ref.read(boltProvider).account?.isCoach ?? false;
    final active = programWeekText(store, tid);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(tx('Programs'), style: BoltText.a(20, weight: 900)),
        const SizedBox(height: 4),
        Text(
          tx(
                'A program plans the coming weeks from your split and sets the main barbell lifts (squat, bench, deadlift, press, row) to a % of the max, week by week. Set maxes on each lift\'s page, or they are estimated from logged sets.',
              ) +
              (coach ? tx(' The changed days become drafts to send again.') : ''),
          style: BoltText.a(13, color: BoltColors.muted, height: 1.45),
        ),
        if (active != null) ...[
          const SizedBox(height: 14),
          BoltBox(
            color: BoltColors.surface1,
            stroke: const Stroke(Color(0x73C6FF1A)),
            radius: 14,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Expanded(child: Text(active, style: BoltText.a(14, weight: 800))),
                Tap(
                  onTap: () => store.stopProgram(tid),
                  child: Text(tx('Stop'), style: BoltText.a(13, weight: 800, color: BoltColors.warn)),
                ),
              ],
            ),
          ),
        ],
        for (final p in kPrograms) ...[
          const SizedBox(height: 10),
          BoltBox(
            color: BoltColors.surface1,
            stroke: const Stroke(BoltColors.lineSoft),
            radius: 16,
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(tx(p.name), style: BoltText.a(16, weight: 800))),
                    Text(plural(p.weeks.length, 'week'), style: BoltText.m(10, color: BoltColors.muted)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(tx(p.desc), style: BoltText.a(12, color: BoltColors.muted, height: 1.4)),
                const SizedBox(height: 6),
                Text(
                  [for (final (s, r, pct) in p.weeks) '$s×$r ${pctText(pct)}'].join(' · '),
                  style: BoltText.m(10, color: BoltColors.muted3, height: 1.5),
                ),
                const SizedBox(height: 10),
                NeonButton(
                  label: tx('Start this week'),
                  height: 42,
                  radius: 12,
                  fontSize: 13,
                  scale: 1,
                  onTap: () {
                    store.startProgram(tid, p.id);
                    Navigator.of(context).pop();
                  },
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
