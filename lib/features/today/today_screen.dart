import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/actions.dart';
import '../../app/tick.dart';
import '../../core/format.dart';
import '../../data/bolt_store.dart';
import '../../data/models/bolt_data.dart';
import '../../data/models/exercise.dart';
import '../../data/models/people.dart';
import '../../data/models/session.dart';
import '../../data/models/visit.dart';
import '../../data/lifts.dart';
import '../../data/rules.dart';
import '../../data/seed/templates.dart';
import '../../theme/text_styles.dart';
import '../../theme/tokens.dart';
import '../../widgets/box.dart';
import '../../widgets/common.dart';
import '../../widgets/tap.dart';
import '../../widgets/sparkline.dart';
import '../badges/badges_screen.dart';
import '../progress/challenge_sheet.dart';
import '../progress/progress_screen.dart' show RecapTiles;
import '../measurements/measurements_screen.dart' show bodyChange, bodyDelta, bodySeries, bodyValue;
import '../sharing/import_sheet.dart';
import '../../widgets/bolt_sheet.dart';

class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(boltProvider);
    final store = ref.read(boltProvider.notifier);
    final now = store.now;
    final today = dk(now);
    final t = store.trOrNull(d.account?.id ?? '');
    if (t == null) return const SizedBox.shrink();
    final coachName = store.coachNameOf(t);
    final plan = store.plan(t.id);
    Session? vis(String k) {
      final p = plan[k];
      return p != null && p.status != SessionStatus.draft ? p : null;
    }

    final tp = vis(today);
    final g = d.gymIn[t.id];
    final nextK = (plan.keys.where((k) => k.compareTo(today) > 0 && vis(k) != null).toList()..sort()).firstOrNull;
    final nextText = nextK == null ? tx('Nothing planned yet') : '${fmtDay(nextK)} · ${tx(plan[nextK]!.title)}';
    final pend = plan.keys.where((k) => plan[k]!.status == SessionStatus.pending && k.compareTo(today) >= 0).toList()
      ..sort();
    final ws = weekStart(now, mondayFirst: d.settings.mondayFirst);
    final nothingAhead = vis(today) == null && nextK == null;
    final withCoach = d.account?.role == Role.trainee;
    final noteBy = tp != null && tp.byCoach ? (coachName ?? tx('Coach')) : t.name;

    return ScreenScroll(
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Kicker(
                    '${weekdays[jsDay(now)]} · ${now.day} ${monthsShort[now.month - 1]} ${now.year}'.toUpperCase(),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    tx('Hey {name}', {'name': vocative(firstName(t.name))}),
                    style: BoltText.a(26, weight: 800, spacing: -.02),
                  ),
                ],
              ),
            ),
            Avatar(ini: initials(t.name), ring: BoltColors.neon, color: BoltColors.neon),
          ],
        ),
        if (g != null) ...[
          const SizedBox(height: 18),
          Tap(
            onTap: () => openScanner(context, ref),
            child: BoltBox(
              color: BoltColors.surface1,
              stroke: const Stroke(Color(0x66C6FF1A)),
              radius: 14,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  const PulseDot(),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(tx('In the gym since {time}', {'time': g.since}), style: BoltText.a(13, weight: 700)),
                        const SizedBox(height: 2),
                        Text(tx('Tap to scan out'), style: BoltText.a(12, color: BoltColors.muted)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  const _GymClock(),
                ],
              ),
            ),
          ),
        ],
        if (tp != null && tp.status != SessionStatus.done) ...[
          const SizedBox(height: 18),
          _HeroCard(session: tp, flagged: tp.ex.where((e) => isFlagged(t, e)).toList(), today: today),
        ],
        if (tp != null && tp.status == SessionStatus.done) ...[
          const SizedBox(height: 18),
          BoltBox(
            color: BoltColors.surface1,
            stroke: const Stroke(Color(0x73C6FF1A)),
            radius: 24,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Kicker('${tx('TODAY · DONE')} · ${logText(tp.log).toUpperCase()}', color: BoltColors.neon),
                const SizedBox(height: 8),
                Text(tx(tp.title).toUpperCase(), style: BoltText.a(34, weight: 900, width: 115, spacing: -.02)),
                const SizedBox(height: 6),
                Text(tx('Next: {what}', {'what': nextText}), style: BoltText.a(14, color: BoltColors.muted)),
              ],
            ),
          ),
        ],
        if (tp == null) ...[
          const SizedBox(height: 18),
          BoltBox(
            color: BoltColors.surface1,
            stroke: const Stroke(BoltColors.lineSoft),
            radius: 24,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Kicker(tx('TODAY')),
                const SizedBox(height: 8),
                Text(tx('REST DAY'), style: BoltText.a(34, weight: 900, width: 115)),
                const SizedBox(height: 6),
                Text(tx('Next: {what}', {'what': nextText}), style: BoltText.a(14, color: BoltColors.muted)),
              ],
            ),
          ),
        ],
        if (nothingAhead) ...[const SizedBox(height: 12), _StartCard(withCoach: withCoach, coachName: coachName)],
        if (t.challenge case final c? when daysLeft(c, now) > 0 || dk(addDays(now, -3)).compareTo(c.to) <= 0) ...[
          const SizedBox(height: 12),
          ChallengeCard(
            c: c,
            progress: challengeProgress(c, plan, d.visits[t.id] ?? const []),
            now: now,
            onTap: () => context.push('/progress'),
          ),
        ],
        // Monday and Tuesday: last week in one card until it is closed.
        if (jsDay(now) >= 1 && jsDay(now) <= 2 && d.settings.recapSeen != dk(addDays(ws, -7)))
          if (weekRecap(plan, d.visits[t.id] ?? const [], t.body, addDays(ws, -7)) case final r when !r.isEmpty) ...[
            const SizedBox(height: 12),
            BoltBox(
              color: BoltColors.surface1,
              stroke: const Stroke(Color(0x73C6FF1A)),
              radius: 20,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(child: Kicker(tx('LAST WEEK'), color: BoltColors.neon)),
                      Tap(
                        onTap: () => store.dismissRecap(dk(addDays(ws, -7))),
                        child: Text('✕', style: BoltText.a(15, color: BoltColors.muted2)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    r.planned > 0 && r.done >= r.planned
                        ? tx('Every planned session done. New week, same energy.')
                        : tx('{n} done. Let\'s make this week count.', {'n': plural(r.done, 'workout')}),
                    style: BoltText.a(16, weight: 800),
                  ),
                  const SizedBox(height: 12),
                  RecapTiles(r: r, metric: d.settings.kg),
                ],
              ),
            ),
          ],
        if (tp != null && tp.note.isNotEmpty) ...[
          const SizedBox(height: 12),
          BoltBox(
            color: BoltColors.surface1,
            stroke: const Stroke(BoltColors.lineSoft),
            radius: 16,
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Avatar(
                  ini: initials(noteBy),
                  size: 34,
                  fontSize: 11,
                  fill: BoltColors.surface2,
                  ring: BoltColors.line,
                  ringWidth: 1,
                  color: BoltColors.neon,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Kicker(
                        tp.byCoach
                            ? tx('NOTE FROM {name}', {'name': firstName(noteBy).toUpperCase()})
                            : tx('YOUR NOTE'),
                        size: 10,
                      ),
                      const SizedBox(height: 4),
                      Text(tx(tp.note), style: BoltText.a(14, height: 1.45)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 26),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Expanded(child: SectionTitle(tx('This week'))),
            Tap(
              onTap: () => openPlanDay(context, ref, null),
              child: Text(tx('Calendar →'), style: BoltText.a(13, weight: 700, color: BoltColors.neon)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            for (var i = 0; i < 7; i++) ...[
              if (i > 0) const SizedBox(width: 6),
              Expanded(child: _weekDay(context, ref, addDays(ws, i), today, vis)),
            ],
          ],
        ),
        const SizedBox(height: 26),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Expanded(child: SectionTitle(tx('Your numbers'))),
            Tap(
              onTap: () => context.push('/progress'),
              child: Text(tx('Progress →'), style: BoltText.a(13, weight: 700, color: BoltColors.neon)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _Numbers(stats: t.stats, plan: plan, visits: d.visits[t.id] ?? const [], now: now, weekStart: ws),
        const SizedBox(height: 8),
        _WeightTile(body: t.body, now: now, metric: d.settings.kg),
        const SizedBox(height: 22),
        BadgesCard(stats: displayStats(t.stats, now), onTap: () => context.push('/badges')),
        if (pend.isNotEmpty) ...[
          const SizedBox(height: 22),
          BoltBox(
            stroke: const Stroke.dashed(BoltColors.neon, 1.5),
            radius: 20,
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tx('{coach} planned {n}', {
                              'coach': coachName == null ? tx('Your coach') : firstName(coachName),
                              'n': plural(pend.length, 'session'),
                            }),
                            style: BoltText.a(16, weight: 800),
                          ),
                          const SizedBox(height: 3),
                          Text(tx('Waiting for your OK'), style: BoltText.a(13, color: BoltColors.muted)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Tap(
                      onTap: store.acceptAll,
                      scale: .96,
                      child: BoltBox(
                        color: BoltColors.neon,
                        radius: 12,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        child: Text(tx('Accept all'), style: BoltText.a(13, weight: 800, color: BoltColors.ink)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                for (final k in pend.take(5)) ...[
                  Tap(
                    onTap: () => openPlanDay(context, ref, k),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: const BoxDecoration(
                        border: Border(top: BorderSide(color: BoltColors.lineSoft)),
                      ),
                      child: Row(
                        children: [
                          Expanded(child: Kicker(fmtDay(k).toUpperCase(), spacing: .06)),
                          Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(text: '${tx(plan[k]!.title)} ', style: BoltText.a(14, weight: 700)),
                                TextSpan(
                                  text: '›',
                                  style: BoltText.a(14, weight: 700, color: BoltColors.neon),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _weekDay(BuildContext context, WidgetRef ref, DateTime day, String today, Session? Function(String) vis) {
    final k = dk(day);
    final p = vis(k);
    final it = k == today;
    final past = k.compareTo(today) < 0;
    final dot = p == null
        ? Colors.transparent
        : p.status == SessionStatus.done
        ? (it ? BoltColors.ink : BoltColors.neon)
        : p.status == SessionStatus.pending
        ? BoltColors.muted2
        : (it ? BoltColors.ink : BoltColors.text);
    return Tap(
      onTap: () => openPlanDay(context, ref, p == null ? null : k),
      child: BoltBox(
        height: 72,
        radius: 14,
        color: it ? BoltColors.text : BoltColors.surface1,
        stroke: Stroke(it ? BoltColors.text : BoltColors.divider),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(weekdays[jsDay(day)][0], style: BoltText.m(10, color: it ? BoltColors.handle : BoltColors.muted)),
            const SizedBox(height: 4),
            Text(
              '${day.day}',
              style: BoltText.a(
                17,
                weight: 800,
                color: it ? BoltColors.ink : (past ? BoltColors.muted2 : BoltColors.text),
              ),
            ),
            const SizedBox(height: 4),
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
            ),
          ],
        ),
      ),
    );
  }
}

/// Totals at a glance: workouts, gym time, rest days and this week.
class _Numbers extends StatelessWidget {
  const _Numbers({
    required this.stats,
    required this.plan,
    required this.visits,
    required this.now,
    required this.weekStart,
  });

  final TraineeStats stats;
  final Map<String, Session> plan;
  final List<Visit> visits;
  final DateTime now;
  final DateTime weekStart;

  @override
  Widget build(BuildContext context) {
    final week = [for (var i = 0; i < 7; i++) plan[dk(addDays(weekStart, i))]]
        .whereType<Session>()
        .where((s) => s.status != SessionStatus.draft)
        .toList();
    final done = week.where((s) => s.status == SessionStatus.done).length;
    Widget tile(String v, String l, {bool neon = false}) => StatTile(
      value: v,
      label: l,
      valueSize: 20,
      valueWeight: 800,
      valueColor: neon ? BoltColors.neon : BoltColors.text,
      labelFirst: true,
      gap: 4,
    );
    return Column(
      children: [
        StatRow(
          children: [
            tile('${stats.workouts}', tx('WORKOUTS'), neon: true),
            tile(totalTime(stats.mins), tx('GYM TIME')),
            tile('${restDays(plan, visits, now)}', tx('REST DAYS')),
          ],
        ),
        const SizedBox(height: 8),
        StatRow(
          children: [
            tile('$done/${week.length}', tx('THIS WEEK')),
            tile('${stats.sessions}', tx('GYM VISITS')),
            tile(stats.sessions == 0 ? '-' : dur(stats.mins / stats.sessions), tx('AVG VISIT')),
          ],
        ),
      ],
    );
  }
}

/// Weight at a glance with its trend; opens the measurements page.
class _WeightTile extends StatelessWidget {
  const _WeightTile({required this.body, required this.now, required this.metric});

  final Body body;
  final DateTime now;
  final bool metric;

  @override
  Widget build(BuildContext context) {
    final s = bodySeries(body, 'weight');
    final ch = bodyChange(s, now);
    void open() => context.push('/measurements');
    if (s.isEmpty) {
      return Tap(
        onTap: open,
        child: BoltBox(
          radius: 14,
          stroke: const Stroke.dashed(BoltColors.line),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Text(tx('Log your weight to see your trend'), style: BoltText.a(13, color: BoltColors.muted)),
              ),
              Text(tx('+ Log'), style: BoltText.a(13, weight: 800, color: BoltColors.neon)),
            ],
          ),
        ),
      );
    }
    return Tap(
      onTap: open,
      child: BoltBox(
        color: BoltColors.surface1,
        stroke: const Stroke(BoltColors.lineSoft),
        radius: 14,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Kicker(tx('WEIGHT'), size: 9, spacing: .1),
                const SizedBox(height: 4),
                Text(bodyValue('weight', s.last.$2, metric: metric), style: BoltText.a(20, weight: 800)),
                const SizedBox(height: 2),
                Text(
                  ch == null
                      ? tx('Logged {day}', {'day': fmtDay(s.last.$1)})
                      : tx('{delta} since {day}', {
                          'delta': bodyDelta('weight', ch.delta, metric: metric),
                          'day': fmtDay(ch.since),
                        }),
                  style: BoltText.a(11, color: BoltColors.muted),
                ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: s.length >= 2
                  ? Sparkline(values: [for (final x in s) x.$2], height: 44, goal: body.goals['weight'])
                  : Text(
                      tx('Log again on another day for a trend'),
                      textAlign: TextAlign.right,
                      style: BoltText.a(12, color: BoltColors.muted),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GymClock extends ConsumerWidget {
  const _GymClock();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = watchNow(ref);
    final d = ref.watch(boltProvider);
    final g = d.gymIn[d.account?.id];
    if (g == null) return const SizedBox.shrink();
    return Text(clockText(g.elapsedMinutes(now)), style: BoltText.m(18, weight: 700, color: BoltColors.neon));
  }
}

/// HH:MM:SS from minutes.
String clockText(double minutes) {
  final s = (minutes * 60).floor().clamp(0, 1 << 31);
  return '${pad(s ~/ 3600)}:${pad((s ~/ 60) % 60)}:${pad(s % 60)}';
}

class _HeroCard extends ConsumerWidget {
  const _HeroCard({required this.session, required this.flagged, required this.today});

  final Session session;
  final List<Exercise> flagged;
  final String today;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = session;
    const ink = BoltColors.ink;
    final chips = [plural(s.ex.length, 'exercise'), plural(s.totalSets, 'set'), '~${s.mins} min'];
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Container(
        color: BoltColors.neon,
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              right: -60,
              top: -62,
              child: Container(
                width: 214,
                height: 214,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0x140A0B09), width: 22),
                ),
              ),
            ),
            Positioned(
              right: -5,
              top: -7,
              child: Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0x140A0B09), width: 8),
                ),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Text(tx('TODAY'), style: BoltText.m(11, weight: 700, spacing: .12, color: ink)),
                    const SizedBox(width: 8),
                    BoltBox(
                      color: ink,
                      radius: 99,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      child: Text(
                        traineeLabel(s.status),
                        style: BoltText.m(10, weight: 700, spacing: .08, color: BoltColors.neon),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  tx(s.title).toUpperCase(),
                  style: BoltText.a(
                    tsz(tx(s.title), 54),
                    weight: 900,
                    width: 115,
                    spacing: -.03,
                    height: .95,
                    color: ink,
                  ),
                ),
                const SizedBox(height: 6),
                Text(tx(s.focus), style: BoltText.a(14, weight: 600, color: ink.withValues(alpha: .8))),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final c in chips)
                      BoltBox(
                        radius: 99,
                        stroke: const Stroke(Color(0x590A0B09)),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        child: Text(c, style: BoltText.m(11, weight: 600, color: ink)),
                      ),
                  ],
                ),
                if (flagged.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  BoltBox(
                    color: const Color(0x1F0A0B09),
                    radius: 10,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    child: Text(
                      '⚠\uFE0E ${tx('{n} flagged for your {area} · swap available', {'n': plural(flagged.length, 'exercise'), 'area': tx(kAreas[flagged.first.area]!).toLowerCase()})}',
                      style: BoltText.a(12, weight: 700, color: ink),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: NeonButton(
                        label: tx('Start workout'),
                        height: 50,
                        radius: 14,
                        color: ink,
                        textColor: BoltColors.neon,
                        onTap: () => s.status == SessionStatus.pending
                            ? openPlanDay(context, ref, today)
                            : startWorkout(context, ref, today),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Tap(
                      onTap: () => openPlanDay(context, ref, today),
                      child: BoltBox(
                        height: 50,
                        radius: 14,
                        stroke: const Stroke(ink, 1.5),
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        alignment: Alignment.center,
                        child: Text(tx('Details'), style: BoltText.a(14, weight: 700, color: ink)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Shown when nothing is planned: plan it yourself, or import the coach's plan.
class _StartCard extends ConsumerWidget {
  const _StartCard({required this.withCoach, required this.coachName});

  final bool withCoach;
  final String? coachName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coach = coachName == null ? tx('your coach') : firstName(coachName!);
    Widget small(String label, VoidCallback onTap, {bool filled = true}) => Tap(
      onTap: onTap,
      scale: .96,
      child: BoltBox(
        color: filled ? BoltColors.neon : null,
        stroke: filled ? Stroke.none : const Stroke(BoltColors.neon),
        radius: 12,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Text(label, style: BoltText.a(13, weight: 800, color: filled ? BoltColors.ink : BoltColors.neon)),
      ),
    );
    return BoltBox(
      stroke: const Stroke.dashed(BoltColors.neon, 1.5),
      radius: 20,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(tx('Nothing planned yet'), style: BoltText.a(16, weight: 800)),
          const SizedBox(height: 3),
          Text(
            withCoach
                ? tx('Import the plan {coach} sent you, or plan the days yourself.', {'coach': coach})
                : tx('Pick days on the calendar, or auto-fill 3 weeks from your split.'),
            style: BoltText.a(13, color: BoltColors.muted, height: 1.4),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (withCoach) small(tx('Import plan'), () => showBoltSheet<void>(context, (_) => const ImportSheet())),
              small(
                withCoach ? tx('Plan it myself') : tx('Plan my weeks'),
                () => openPlanDay(context, ref, null),
                filled: !withCoach,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
