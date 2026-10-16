import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../data/lifts.dart';
import '../../data/models/session.dart';
import '../../data/seed/muscles.dart';
import '../../theme/text_styles.dart';
import '../../theme/tokens.dart';
import '../../widgets/box.dart';
import '../../widgets/common.dart';
import '../../widgets/muscle_map.dart';
import '../../widgets/tap.dart';

/// Names of the trained muscles that are fully recovered on [today], in
/// picker order.
List<String> readyMuscles(Map<String, Session> plan, String today) {
  final r = recovery(plan, today);
  return [
    for (final m in kMuscles.keys)
      if ((r[m] ?? 0) >= 1) tx(kMuscles[m]!.name),
  ];
}

/// Which muscles are ready to train and which are still recovering, on a
/// body map. [big] is the Progress version with a legend.
class RecoveryCard extends StatelessWidget {
  const RecoveryCard({super.key, required this.plan, required this.today, this.big = false});

  final Map<String, Session> plan;
  final String today;
  final bool big;

  @override
  Widget build(BuildContext context) {
    final r = recovery(plan, today);
    final last = lastTrained(plan, today);
    final ready = readyMuscles(plan, today);
    final busy = [
      for (final m in kMuscles.keys)
        if (r[m] case final x? when x < 1) m,
    ];
    final by = busy.isEmpty
        ? null
        : busy.map((m) => dk(addDays(pk(last[m]!), recoveryDays(m)))).reduce((a, b) => a.compareTo(b) > 0 ? a : b);
    final lines = <(String, String, Color)>[
      if (ready.isNotEmpty) (tx('READY'), ready.join(', '), BoltColors.neon),
      if (busy.isNotEmpty)
        (
          tx('RECOVERING'),
          '${busy.map((m) => tx(kMuscles[m]!.name)).join(', ')} · ${tx('all ready {day}', {'day': fmtDay(by!)})}',
          BoltColors.warn,
        ),
    ];
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!big) ...[Kicker(tx('RECOVERY'), size: 9, spacing: .1), const SizedBox(height: 6)],
        if (lines.isEmpty)
          Text(
            tx('Log a workout and each muscle shows how recovered it is.'),
            style: BoltText.a(12, color: BoltColors.muted, height: 1.35),
          ),
        for (final (k, v, c) in lines) ...[
          Text(k, style: BoltText.m(9, weight: 700, spacing: .1, color: c)),
          const SizedBox(height: 2),
          Text(v, style: BoltText.a(12, weight: 700, height: 1.35)),
          const SizedBox(height: 6),
        ],
      ],
    );
    final box = BoltBox(
      color: BoltColors.surface1,
      stroke: const Stroke(BoltColors.lineSoft),
      radius: big ? 18 : 14,
      padding: EdgeInsets.all(big ? 14 : 12),
      child: big
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                MuscleMap(recovery: r),
                const SizedBox(height: 12),
                text,
              ],
            )
          : Row(
              children: [
                SizedBox(width: 120, child: MuscleMap(recovery: r, labels: false)),
                const SizedBox(width: 12),
                Expanded(child: text),
              ],
            ),
    );
    return big ? box : Tap(onTap: () => context.push('/progress'), child: box);
  }
}
