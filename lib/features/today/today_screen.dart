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
import '../../data/cycle.dart';
import '../../data/lifts.dart';
import '../../data/rank.dart';
import '../../data/rules.dart';
import '../../data/suggestions.dart';
import '../../data/warmup.dart';
import '../../data/seed/muscles.dart';
import '../../data/seed/templates.dart';
import '../../theme/text_styles.dart';
import '../../theme/tokens.dart';
import '../../widgets/box.dart';
import '../../widgets/common.dart';
import '../../widgets/tap.dart';
import '../../widgets/sparkline.dart';
import '../badges/badges_screen.dart';
import '../progress/challenge_sheet.dart';
import '../workouts/deload_sheet.dart';
import '../progress/progress_screen.dart' show RecapTiles;
import '../progress/recovery_card.dart';
import '../progress/season_card.dart';
import '../measurements/cycle_card.dart';
import '../plan/free_day_sheet.dart';
import '../measurements/measurements_screen.dart' show bodyChange, bodyDelta, bodySeries, bodyValue;
import '../sharing/import_sheet.dart';
import '../rank/rank_screen.dart' show RankCard;
import 'level_card.dart';
import 'readiness_card.dart';
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
    final off = daysOff(plan, d.visits[t.id] ?? const [], t.stats.rest, now);
    final rested = t.stats.rest.contains(today);

    void train() {
      if (tp != null) {
        tp.status == SessionStatus.pending ? openPlanDay(context, ref, today) : openWorkout(today);
      } else if (store.addFromRotation(t.id, today)) {
        openPlanDay(context, ref, today);
      }
    }

    return ScreenScroll(
      stagger: true,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Kicker('${weekdays[jsDay(now)]} · ${dayMonth(now)} ${now.year}'.toUpperCase()),
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
        if (off >= 3 && g == null && !t.stats.away.contains(dk(monday(now)))) ...[
          const SizedBox(height: 18),
          _OffCard(days: off, ready: readyMuscles(plan, today), onGo: train),
        ],
        if (t.stats.away.contains(dk(monday(now)))) ...[
          const SizedBox(height: 18),
          BoltBox(
            color: BoltColors.surface1,
            stroke: const Stroke(BoltColors.lineSoft),
            radius: 14,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Text(
              tx('Away this week. Your streak is safe, train if you feel like it.'),
              style: BoltText.a(13, weight: 700),
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
        if (tp != null &&
            {SessionStatus.approved, SessionStatus.moved}.contains(tp.status) &&
            d.workout?.key != today &&
            !d.settings.hintsSeen.contains('warm:$today')) ...[
          const SizedBox(height: 12),
          _WarmupCard(session: tp, today: today),
        ],
        if (tp == null) ...[
          const SizedBox(height: 18),
          _RestHero(plan: plan, today: today, next: nextText, off: off, rested: rested, onTrain: train),
        ],
        if (nothingAhead) ...[const SizedBox(height: 12), _StartCard(withCoach: withCoach, coachName: coachName)],
        // Today's workout leads; level and news follow it.
        const SizedBox(height: 18),
        LevelCard(stats: t.stats, daysOff: off),
        const SizedBox(height: 10),
        RankCard(rank: rankOf(t, plan), t: t),
        if (_cheers(plan, d.settings.hintsSeen, today) case final c when c.isNotEmpty) ...[
          const SizedBox(height: 18),
          _CheerCard(keys: c, plan: plan, coach: coachName),
        ],
        if (!d.settings.hintsSeen.contains(_newId)) ...[const SizedBox(height: 18), const _NewCard()],
        if (tp?.status != SessionStatus.done && d.workout?.key != today) ...[
          const SizedBox(height: 12),
          ReadinessCard(trainee: t, session: tp, dayKey: today),
        ],
        if (store.currentSeason() case final s?) ...[
          const SizedBox(height: 12),
          SeasonCard(s: s, plan: plan, today: today),
        ] else if (t.seasons.lastOrNull case final s?
            when s.end.compareTo(today) <= 0 &&
                dk(addDays(pk(s.end), 14)).compareTo(today) > 0 &&
                !d.settings.hintsSeen.contains('season:${s.n}')) ...[
          const SizedBox(height: 12),
          SeasonDoneCard(s: s, plan: plan),
        ],
        if (t.challenge case final c? when daysLeft(c, now) > 0 || dk(addDays(now, -3)).compareTo(c.to) <= 0) ...[
          const SizedBox(height: 12),
          ChallengeCard(
            c: c,
            progress: challengeProgress(c, plan, d.visits[t.id] ?? const []),
            now: now,
            onTap: () => context.push('/progress'),
          ),
        ],
        if (t.body.sex == 'f' && cycleInfo(t.periods, now) != null) ...[const SizedBox(height: 12), const CycleCard()],
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
        for (final h in suggestions(
          t,
          plan,
          now,
          weekStart: weekStart(now, mondayFirst: d.settings.mondayFirst),
          seen: d.settings.hintsSeen,
        )) ...[const SizedBox(height: 10), _HintCard(tid: t.id, h: h)],
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
              Expanded(child: _weekDay(context, ref, addDays(ws, i), today, vis, t.stats.rest)),
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
        const SizedBox(height: 8),
        RecoveryCard(plan: plan, today: today),
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

  Widget _weekDay(
    BuildContext context,
    WidgetRef ref,
    DateTime day,
    String today,
    Session? Function(String) vis,
    Set<String> rest,
  ) {
    final k = dk(day);
    final p = vis(k);
    final it = k == today;
    final past = k.compareTo(today) < 0;
    final rested = p == null && rest.contains(k);
    final dot = p == null
        ? Colors.transparent
        : p.status == SessionStatus.done
        ? (it ? BoltColors.ink : BoltColors.neon)
        : p.status == SessionStatus.pending
        ? BoltColors.muted2
        : (it ? BoltColors.ink : BoltColors.text);
    void plan() {
      final store = ref.read(boltProvider.notifier);
      openPlanDay(context, ref, store.addFromRotation(ref.read(boltProvider).account!.id, k) ? k : null);
    }

    return Tap(
      onTap: () => p != null
          ? openPlanDay(context, ref, k)
          : showBoltSheet<void>(context, (_) => FreeDaySheet(dayKey: k, onPlan: plan)),
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
              decoration: BoxDecoration(
                color: dot,
                shape: BoxShape.circle,
                border: rested ? Border.all(color: it ? BoltColors.ink : BoltColors.muted2, width: 1.5) : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Done days from the last four weeks with a high five not closed yet.
List<String> _cheers(Map<String, Session> plan, List<String> seen, String today) => [
  for (final k in plan.keys.toList()..sort((a, b) => b.compareTo(a)))
    if (plan[k]!.cheer case final c?
        when k.compareTo(dk(addDays(pk(today), -28))) >= 0 && !seen.contains('cheer:$k:$c'))
      k,
];

/// High fives from the coach on logged workouts, until closed.
class _CheerCard extends ConsumerWidget {
  const _CheerCard({required this.keys, required this.plan, required this.coach});

  final List<String> keys;
  final Map<String, Session> plan;
  final String? coach;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.read(boltProvider.notifier);
    void close() {
      for (final k in keys) {
        store.dismissHint('cheer:$k:${plan[k]!.cheer}');
      }
    }

    return BoltBox(
      color: BoltColors.surface1,
      stroke: const Stroke(Color(0x73C6FF1A)),
      radius: 20,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Kicker(
                  tx('HIGH FIVE FROM {name}', {'name': firstName(coach ?? tx('your coach')).toUpperCase()}),
                  color: BoltColors.neon,
                ),
              ),
              Tap(
                onTap: close,
                child: Text('✕', style: BoltText.a(15, color: BoltColors.muted2)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final k in keys.take(3))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Text(plan[k]!.cheer!, style: const TextStyle(fontSize: 26)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      tx('{workout} · {day}', {'workout': tx(plan[k]!.title), 'day': fmtDay(k)}),
                      style: BoltText.a(15, weight: 800),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// What to warm up before today's workout and for how long, until closed.
class _WarmupCard extends ConsumerWidget {
  const _WarmupCard({required this.session, required this.today});

  final Session session;
  final String today;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (mins, steps) = warmupPlan(session);
    return BoltBox(
      color: BoltColors.surface1,
      stroke: const Stroke(BoltColors.lineSoft),
      radius: 18,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Kicker(tx('WARM-UP · ~{n} MIN', {'n': mins}), size: 9, spacing: .1, color: BoltColors.neon),
              ),
              Tap(
                onTap: () => ref.read(boltProvider.notifier).dismissHint('warm:$today'),
                child: Text('✕', style: BoltText.a(14, color: BoltColors.muted2)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final (i, s) in steps.indexed) ...[
            if (i > 0) const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 20,
                  child: Text('${i + 1}', style: BoltText.m(11, weight: 700, color: BoltColors.neon)),
                ),
                Expanded(child: Text(s, style: BoltText.a(13, weight: 600, height: 1.4))),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Today without a workout: a calm card for recovery, dotted like rest days
/// on the calendar, with how the body is recovering and what comes next.
class _RestHero extends ConsumerWidget {
  const _RestHero({
    required this.plan,
    required this.today,
    required this.next,
    required this.off,
    required this.rested,
    required this.onTrain,
  });

  final Map<String, Session> plan;
  final String today;
  final String next;
  final int off;
  final bool rested;
  final VoidCallback onTrain;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.read(boltProvider.notifier);
    final r = recovery(plan, today);
    final last = lastTrained(plan, today);
    final busy = [
      for (final m in kMuscles.keys)
        if (r[m] case final x? when x < 1) m,
    ];
    final ready = readyMuscles(plan, today);
    final body = busy.isNotEmpty
        ? tx('Recovering: {muscles}. All ready {day}.', {
            'muscles': busy.map((m) => tx(kMuscles[m]!.name)).join(', '),
            'day': fmtDay(
              busy.map((m) => dk(addDays(pk(last[m]!), recoveryDays(m)))).reduce((a, b) => a.compareTo(b) > 0 ? a : b),
            ),
          })
        : ready.isNotEmpty
        ? tx('Fully recovered: {muscles}.', {'muscles': ready.join(', ')})
        : tx('Sleep, eat well and move a little. Rest is where you grow.');
    final title = tx('REST DAY');
    Widget ring(double size, double width, double alpha) => SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: DashedBorderPainter(
          stroke: Stroke.dotted(BoltColors.neon.withValues(alpha: alpha), width),
          circle: true,
        ),
      ),
    );
    return BoltBox(
      radius: 24,
      stroke: const Stroke.dotted(Color(0x99C6FF1A), 1.5),
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF171A13), Color(0xFF0E1408)],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            Positioned(right: -70, top: -70, child: ring(220, 3, .22)),
            Positioned(right: 4, top: 4, child: ring(84, 2, .4)),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Text(tx('TODAY'), style: BoltText.m(11, weight: 700, spacing: .12, color: BoltColors.muted)),
                      const SizedBox(width: 8),
                      BoltBox(
                        radius: 99,
                        stroke: const Stroke(BoltColors.neon),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        child: Text(
                          rested ? tx('RESTING') : tx('NOTHING PLANNED'),
                          style: BoltText.m(10, weight: 700, spacing: .08, color: BoltColors.neon),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(title, style: BoltText.a(tsz(title, 54), weight: 900, width: 115, spacing: -.03, height: .95)),
                  const SizedBox(height: 8),
                  Text(body, style: BoltText.a(14, weight: 600, color: BoltColors.textSoft, height: 1.4)),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final c in [
                        if (off > 0) tx('{days} off', {'days': plural(off, 'day')}),
                        tx('Next: {what}', {'what': next}),
                      ])
                        BoltBox(
                          radius: 99,
                          stroke: const Stroke(BoltColors.line),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          child: Text(c, style: BoltText.m(11, weight: 600, color: BoltColors.textSoft)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      if (!rested) ...[
                        Expanded(
                          child: NeonButton(
                            label: tx('Mark as rest day'),
                            height: 50,
                            radius: 14,
                            onTap: () => store.toggleRest(today),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Expanded(
                        child: OutlineButton(label: tx('Train anyway'), height: 50, radius: 14, onTap: onTrain),
                      ),
                      if (rested) ...[
                        const SizedBox(width: 8),
                        Tap(
                          onTap: () => store.toggleRest(today),
                          child: BoltBox(
                            height: 50,
                            radius: 14,
                            stroke: const Stroke(BoltColors.line),
                            padding: const EdgeInsets.symmetric(horizontal: 18),
                            alignment: Alignment.center,
                            child: Text(tx('Undo'), style: BoltText.a(14, weight: 700, color: BoltColors.muted)),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Days off in a row: a nudge at 3, louder at 4, all out from 5.
class _OffCard extends StatelessWidget {
  const _OffCard({required this.days, required this.ready, required this.onGo});

  final int days;

  /// Muscles fully recovered and waiting.
  final List<String> ready;
  final VoidCallback onGo;

  @override
  Widget build(BuildContext context) {
    final kicker = tx('{days} OFF', {'days': plural(days, 'day').toUpperCase()});
    if (days >= 5) {
      const ink = BoltColors.ink;
      return BoltBox(
        color: BoltColors.warn,
        radius: 24,
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const PulseDot(),
                const SizedBox(width: 10),
                Text(kicker, style: BoltText.m(11, weight: 700, spacing: .12, color: ink)),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              days >= 7 ? tx('GET BACK IN.') : tx('ENOUGH REST.'),
              style: BoltText.a(44, weight: 900, width: 115, spacing: -.03, height: .95, color: ink),
            ),
            const SizedBox(height: 8),
            Text(
              tx('Your body has recovered and the habit is slipping. Get to the gym today, even 20 minutes counts.'),
              style: BoltText.a(14, weight: 600, color: ink.withValues(alpha: .8), height: 1.4),
            ),
            if (ready.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                tx('Fully recovered: {muscles}.', {'muscles': ready.join(', ')}),
                style: BoltText.a(13, weight: 800, color: ink),
              ),
            ],
            const SizedBox(height: 16),
            NeonButton(
              label: tx('Train today'),
              height: 50,
              radius: 14,
              color: ink,
              textColor: BoltColors.warn,
              onTap: onGo,
            ),
          ],
        ),
      );
    }
    final c = days >= 4 ? BoltColors.warn : BoltColors.neon;
    return BoltBox(
      color: BoltColors.surface1,
      stroke: Stroke(c, 1.5),
      radius: 20,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Kicker(kicker, color: c),
          const SizedBox(height: 6),
          Text(
            days >= 4
                ? tx('Recovery is done. Time to move before the habit slips.')
                : tx('Rested enough? A short session today keeps the habit going.'),
            style: BoltText.a(16, weight: 800, height: 1.3),
          ),
          if (ready.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              tx('Fully recovered: {muscles}.', {'muscles': ready.join(', ')}),
              style: BoltText.a(12, color: BoltColors.muted, height: 1.35),
            ),
          ],
          const SizedBox(height: 12),
          Tap(
            onTap: onGo,
            scale: .96,
            child: BoltBox(
              color: c,
              radius: 12,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Text(tx('Train today'), style: BoltText.a(13, weight: 800, color: BoltColors.ink)),
            ),
          ),
        ],
      ),
    );
  }
}

/// Totals at a glance: workouts, gym time, rest days, this week and days off
/// in a row.
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
    final off = daysOff(plan, visits, stats.rest, now);
    Widget tile(String v, String l, {bool neon = false, bool warn = false}) => StatTile(
      value: v,
      label: l,
      valueSize: 20,
      valueWeight: 800,
      valueColor: neon ? BoltColors.neon : (warn ? BoltColors.warn : BoltColors.text),
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
            tile('$off', tx('DAYS OFF'), warn: off >= 3),
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
                        label: tx('Open workout'),
                        height: 50,
                        radius: 14,
                        color: ink,
                        textColor: BoltColors.neon,
                        onTap: () =>
                            s.status == SessionStatus.pending ? openPlanDay(context, ref, today) : openWorkout(today),
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

const _newId = 'new:1.23';

/// What 1.23 added and where to find it, until closed.
class _NewCard extends ConsumerWidget {
  const _NewCard();

  static const _items = <(String, String, String?)>[
    (
      'Gym floor mode',
      'In a workout, tap GYM FLOOR: one set at a time, big weight and reps steppers, a big rest ring and the plates for the bar.',
      null,
    ),
    ('Last time, filled in', 'Every set starts at what you did on that set last time. Tap + if you go heavier.', null),
    (
      'Rest on the lock screen',
      'The rest counts down on the lock screen with −15, +15 and Skip, a chime in your headphones and a buzz in your pocket.',
      '/settings',
    ),
    ('Your rank', 'From Bodyweight to Olympia, by what you lift for your bodyweight. Share it.', '/rank'),
    ('Logbook', 'Every workout set by set, with your latest records.', '/history'),
    ('Plate calculator', 'Which plates go on each side of the bar.', '/plates'),
    ('Feel it', 'Steppers tick, sets land with a thud, records swell with confetti.', '/settings'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.read(boltProvider.notifier);
    return BoltBox(
      color: BoltColors.surface1,
      stroke: const Stroke(Color(0x73C6FF1A)),
      radius: 20,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Kicker(tx('NEW IN BOLT 1.23'), color: BoltColors.neon)),
              Tap(
                onTap: () => store.dismissHint(_newId),
                child: Text('✕', style: BoltText.a(15, color: BoltColors.muted2)),
              ),
            ],
          ),
          for (final (title, line, route) in _items)
            Tap(
              onTap: route == null
                  ? null
                  : () => route.startsWith('/plan') || route == '/gym' || route == '/learn'
                        ? context.go(route)
                        : context.push(route),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: BoltColors.divider)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(tx(title), style: BoltText.a(14, weight: 800)),
                          const SizedBox(height: 2),
                          Text(tx(line), style: BoltText.a(12, color: BoltColors.muted, height: 1.35)),
                        ],
                      ),
                    ),
                    if (route != null) ...[const SizedBox(width: 8), const Chevron(size: 16)],
                  ],
                ),
              ),
            ),
          const SizedBox(height: 10),
          Tap(
            onTap: () => store.dismissHint(_newId),
            child: Text(tx('Got it'), style: BoltText.a(13, weight: 800, color: BoltColors.neon)),
          ),
        ],
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

/// One suggestion: what is off this week and a one-tap fix.
class _HintCard extends ConsumerWidget {
  const _HintCard({required this.tid, required this.h});

  final String tid;
  final Hint h;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.read(boltProvider.notifier);
    void act() {
      switch (h.kind) {
        case HintKind.missed:
          store.move(h.day!, h.to!);
        case HintKind.volume:
          store.addToDay(tid, h.day!, h.add!);
        case HintKind.deload:
          showBoltSheet<void>(context, (_) => DeloadSheet(tid: tid));
      }
      store.dismissHint(h.id);
    }

    return BoltBox(
      color: BoltColors.surface1,
      stroke: const Stroke(Color(0x59C6FF1A)),
      radius: 16,
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Kicker(tx('SUGGESTION'), size: 9, color: BoltColors.neon),
                const SizedBox(height: 4),
                Text(h.text, style: BoltText.a(13, weight: 700, height: 1.35)),
                const SizedBox(height: 8),
                Tap(
                  onTap: act,
                  child: BoltBox(
                    radius: 10,
                    color: BoltColors.neon,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    child: Text(h.action, style: BoltText.a(12, weight: 800, color: BoltColors.ink)),
                  ),
                ),
              ],
            ),
          ),
          Tap(
            onTap: () => store.dismissHint(h.id),
            child: SizedBox(
              width: 36,
              height: 36,
              child: Center(
                child: Text('✕', style: BoltText.a(14, color: BoltColors.muted2)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
