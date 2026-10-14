import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/actions.dart';
import '../../app/router.dart';
import '../../app/ui_state.dart';
import '../../core/format.dart';
import '../../data/bolt_store.dart';
import '../../data/models/session.dart';
import '../../theme/text_styles.dart';
import '../../theme/tokens.dart';
import '../../widgets/box.dart';
import '../../widgets/common.dart';
import '../../widgets/exercise_rows.dart';

/// Trainee's day sheet: the session, its exercises and what they can do.
class DaySheet extends ConsumerWidget {
  const DaySheet({super.key, required this.dayKey});

  final String dayKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(boltProvider);
    final store = ref.read(boltProvider.notifier);
    final t = store.trOrNull(d.account?.id ?? '');
    final s = t == null ? null : store.plan(t.id)[dayKey];
    if (t == null || s == null || s.status == SessionStatus.draft) return const SizedBox(height: 120);
    final coach = store.co(t.coach);
    final c = chipFor(s.status);
    final today = store.today;
    final sum = '${plural(s.ex.length, 'exercise')} · ${plural(s.totalSets, 'set')} · ~${s.mins} min'.toUpperCase();
    void close() => Navigator.of(context).pop();

    void move() {
      close();
      ref.read(planMonthProvider.notifier).set(pk(dayKey));
      ref.read(moveFromProvider.notifier).set(dayKey);
      rootNavigatorKey.currentContext!.go('/plan');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Kicker(fmtDay(dayKey).toUpperCase(), spacing: .1)),
            const SizedBox(width: 8),
            BoltBox(
              color: c.bg,
              stroke: c.stroke,
              radius: 99,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              child: Text(traineeLabel(s.status), style: BoltText.a(11, weight: 700, color: c.fg)),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          s.title.toUpperCase(),
          style: BoltText.a(
            tsz(s.title, 44),
            weight: 900,
            width: 115,
            spacing: -.02,
            height: .95,
            color: BoltColors.neon,
          ),
        ),
        const SizedBox(height: 6),
        Text(s.focus, style: BoltText.a(14, color: BoltColors.muted)),
        const SizedBox(height: 6),
        Kicker(sum, size: 10, spacing: .08, color: BoltColors.muted2),
        if (s.from != null) ...[
          const SizedBox(height: 4),
          Kicker('ORIGINALLY ${fmtDay(s.from!).toUpperCase()}', size: 10, spacing: 0),
        ],
        if (s.note.isNotEmpty) ...[const SizedBox(height: 12), CoachNote(ini: initials(coach.name), note: s.note)],
        const SizedBox(height: 12),
        ExerciseRows(trainee: t, exercises: s.ex, canSwap: true, onHow: showExerciseSheet),
        if (s.status == SessionStatus.done) ...[
          const SizedBox(height: 12),
          Text('Logged · ${s.log ?? ''}', style: BoltText.a(14, weight: 700, color: BoltColors.neon)),
        ],
        const SizedBox(height: 16),
        if (s.status == SessionStatus.pending) ...[
          NeonButton(
            label: 'Accept',
            height: 52,
            scale: 1,
            onTap: () {
              store.accept(dayKey);
              close();
            },
          ),
          const SizedBox(height: 8),
          OutlineButton(label: 'Can’t make it · pick another day', color: BoltColors.text, onTap: move),
        ],
        if (dayKey == today && (s.status == SessionStatus.approved || s.status == SessionStatus.moved))
          NeonButton(
            label: 'Start workout',
            height: 52,
            scale: 1,
            onTap: () {
              close();
              startWorkout(rootNavigatorKey.currentContext!, ref, dayKey);
            },
          ),
        if (s.status != SessionStatus.done && s.status != SessionStatus.pending && dayKey.compareTo(today) >= 0) ...[
          if (dayKey == today) const SizedBox(height: 8),
          OutlineButton(
            label: 'Move to another day',
            color: BoltColors.text,
            borderColor: BoltColors.line,
            weight: 700,
            onTap: move,
          ),
        ],
      ],
    );
  }
}

/// Coach note: initials bubble plus the note.
class CoachNote extends StatelessWidget {
  const CoachNote({super.key, required this.ini, required this.note, this.padding = 12});

  final String ini;
  final String note;
  final double padding;

  @override
  Widget build(BuildContext context) {
    return BoltBox(
      color: BoltColors.surface1,
      stroke: const Stroke(BoltColors.lineSoft),
      radius: 14,
      padding: EdgeInsets.all(padding),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Avatar(ini: ini, size: 30, fontSize: 10, ring: BoltColors.line, ringWidth: 1, color: BoltColors.neon),
          const SizedBox(width: 10),
          Expanded(child: Text(note, style: BoltText.a(13, height: 1.45))),
        ],
      ),
    );
  }
}
