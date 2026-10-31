import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/actions.dart';
import '../../app/router.dart';
import '../../app/share.dart';
import '../../app/ui_state.dart';
import '../../core/format.dart';
import '../../data/bolt_store.dart';
import '../../data/models/session.dart';
import '../../data/rules.dart';
import '../../theme/text_styles.dart';
import '../../theme/tokens.dart';
import '../../widgets/box.dart';
import '../../widgets/common.dart';
import '../../widgets/exercise_rows.dart';
import '../../widgets/tap.dart';
import '../today/readiness_card.dart' show DayLog;
import '../workouts/workout_picker.dart';

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
    final coachName = store.coachNameOf(t);
    final c = chipFor(s.status);
    final today = store.today;
    // Confirmed days that are not over can be reshaped by the trainee; a solo
    // user can also fill in and log days behind them from their diary.
    final open = s.status == SessionStatus.approved || s.status == SessionStatus.moved;
    final logPast = open && store.canLogPast(t.id, dayKey);
    final editable = open && (dayKey.compareTo(today) >= 0 || logPast);
    // A logged day you planned yourself, like a gym session saved by
    // scanning out, can still get what you trained.
    final fillIn = store.canFillIn(s);
    final canMove = s.status != SessionStatus.done && s.status != SessionStatus.pending && dayKey.compareTo(today) >= 0;
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
          tx(s.title).toUpperCase(),
          style: BoltText.a(
            tsz(tx(s.title), 44),
            weight: 900,
            width: 115,
            spacing: -.02,
            height: .95,
            color: BoltColors.neon,
          ),
        ),
        const SizedBox(height: 6),
        Text(tx(s.focus), style: BoltText.a(14, color: BoltColors.muted)),
        const SizedBox(height: 6),
        Kicker(sum, size: 10, spacing: .08, color: BoltColors.muted2),
        if (s.from != null) ...[
          const SizedBox(height: 4),
          Kicker(tx('ORIGINALLY {day}', {'day': fmtDay(s.from!).toUpperCase()}), size: 10, spacing: 0),
        ],
        if (dayKey.compareTo(today) <= 0) ...[const SizedBox(height: 12), DayLog(dayKey: dayKey)],
        if (s.cheer != null) ...[
          const SizedBox(height: 10),
          Text(
            '${s.cheer} ${tx('High five from {name}', {'name': firstName(coachName ?? tx('your coach'))})}',
            style: BoltText.a(14, weight: 800, color: BoltColors.neon),
          ),
        ],
        if (s.note.isNotEmpty) ...[
          const SizedBox(height: 12),
          CoachNote(ini: initials(s.byCoach ? (coachName ?? tx('Coach')) : t.name), note: tx(s.note)),
        ],
        if (fillIn && s.ex.isEmpty) ...[
          const SizedBox(height: 12),
          Text(
            tx('You trained {log}. Add what you did: pick a workout or build it from muscles.', {
              'log': logText(s.log),
            }),
            style: BoltText.a(13, color: BoltColors.muted, height: 1.45),
          ),
        ],
        if (editable || fillIn) ...[
          const SizedBox(height: 12),
          ChangeWorkoutButton(onTap: () => changeDayWorkout(t.id, dayKey)),
        ],
        const SizedBox(height: 12),
        ExerciseRows(
          trainee: t,
          exercises: s.ex,
          canSwap: true,
          onHow: showExerciseSheet,
          swapAny: s.status != SessionStatus.done,
        ),
        if (s.status == SessionStatus.done) ...[
          const SizedBox(height: 12),
          Text(
            tx('Logged · {log}', {'log': logText(s.log)}),
            style: BoltText.a(14, weight: 700, color: BoltColors.neon),
          ),
          if (s.ex.any((e) => e.logged.isNotEmpty)) ...[
            const SizedBox(height: 10),
            NeonButton(
              label: tx('Workout summary'),
              height: 48,
              scale: 1,
              onTap: () {
                close();
                rootNavigatorKey.currentContext!.push('/summary/$dayKey');
              },
            ),
          ],
          if (fillIn) ...[
            const SizedBox(height: 10),
            OutlineButton(
              label: s.ex.isEmpty ? tx('Add exercises') : tx('Edit exercises'),
              onTap: () {
                close();
                rootNavigatorKey.currentContext!.push('/editor/day/${t.id}/$dayKey');
              },
            ),
          ],
          const SizedBox(height: 10),
          OutlineButton(
            label: tx('Delete workout'),
            color: BoltColors.warn,
            borderColor: BoltColors.line,
            weight: 700,
            onTap: () async {
              final ok = await confirmSheet(
                context,
                title: tx('Delete this workout?'),
                body: tx(
                  'It comes off your log with its sets, records and XP. The day is free again. Gym visits stay.',
                ),
                confirm: tx('Delete workout'),
              );
              if (!ok || !context.mounted) return;
              close();
              store.deleteDone(dayKey);
            },
          ),
        ],
        const SizedBox(height: 16),
        if (s.status == SessionStatus.pending) ...[
          NeonButton(
            label: tx('Accept'),
            height: 52,
            scale: 1,
            onTap: () {
              store.accept(dayKey);
              close();
            },
          ),
          const SizedBox(height: 8),
          OutlineButton(label: tx('Can’t make it · pick another day'), color: BoltColors.text, onTap: move),
        ],
        if (dayKey == today && (s.status == SessionStatus.approved || s.status == SessionStatus.moved))
          NeonButton(
            label: tx('Open workout'),
            height: 52,
            scale: 1,
            onTap: () {
              close();
              openWorkout(dayKey);
            },
          ),
        if (logPast)
          NeonButton(
            label: tx('Log as done'),
            height: 52,
            scale: 1,
            onTap: () {
              close();
              showUnlocks(store.logPast(dayKey));
            },
          ),
        // Starting the workout is the one thing that matters on this sheet.
        // Everything under it only changes or clears the day, so it is half
        // the height, and clearing the day is quieter still.
        if (editable || canMove) ...[
          if (dayKey == today || logPast) const SizedBox(height: 10),
          Row(
            children: [
              if (editable)
                Expanded(
                  child: OutlineButton(
                    label: tx('Edit exercises'),
                    height: 44,
                    fontSize: 13,
                    onTap: () {
                      close();
                      rootNavigatorKey.currentContext!.push('/editor/day/${t.id}/$dayKey');
                    },
                  ),
                ),
              if (editable && canMove) const SizedBox(width: 8),
              if (canMove)
                Expanded(
                  child: OutlineButton(
                    label: tx('Move day'),
                    height: 44,
                    fontSize: 13,
                    color: BoltColors.text,
                    borderColor: BoltColors.line,
                    weight: 700,
                    onTap: move,
                  ),
                ),
            ],
          ),
        ],
        if (editable)
          Row(
            children: [
              Expanded(
                child: _QuietAction(
                  label: tx('Rest day instead'),
                  onTap: () {
                    store.toggleRest(dayKey);
                    close();
                  },
                ),
              ),
              Container(width: 1, height: 14, color: BoltColors.divider),
              Expanded(
                child: _QuietAction(
                  label: tx('Remove'),
                  color: BoltColors.warn,
                  onTap: () {
                    store.removeDay(t.id, dayKey);
                    close();
                  },
                ),
              ),
            ],
          ),
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

/// A quiet text action. The ways to clear a day sit at the bottom of the
/// sheet and should never pull the eye away from starting the workout.
class _QuietAction extends StatelessWidget {
  const _QuietAction({required this.label, required this.onTap, this.color = BoltColors.muted});

  final String label;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) => Tap(
    onTap: onTap,
    child: Container(
      height: 44,
      // Clear of the divider between the two, even in longer Serbian.
      padding: const EdgeInsets.symmetric(horizontal: 10),
      alignment: Alignment.center,
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: BoltText.a(13, weight: 700, color: color),
      ),
    ),
  );
}
