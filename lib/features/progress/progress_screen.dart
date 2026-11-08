import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/units.dart';
import '../../data/bolt_store.dart';
import '../../data/lifts.dart';
import '../../data/models/bolt_data.dart';
import '../../data/models/people.dart';
import '../../data/models/session.dart';
import '../../data/models/visit.dart';
import '../../data/rules.dart';
import '../../data/seed/muscles.dart';
import '../../data/strength.dart';
import '../../theme/text_styles.dart';
import '../../theme/tokens.dart';
import '../../widgets/bolt_sheet.dart';
import '../../widgets/box.dart';
import '../../widgets/common.dart';
import '../../widgets/motion.dart';
import '../../widgets/muscle_map.dart';
import '../../widgets/sparkline.dart';
import '../../widgets/surfaces.dart';
import '../../widgets/tap.dart';
import 'challenge_sheet.dart';
import 'lift_screen.dart' show LiftGoalCard;
import '../today/readiness_card.dart' show CheckIns;
import 'recovery_card.dart';
import 'season_card.dart';

/// Everything you have built up: challenge, last week, muscle volume this
/// week, records and every lift you have logged.
class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(boltProvider);
    final store = ref.read(boltProvider.notifier);
    final t = store.trOrNull(d.account?.id ?? '');
    if (t == null) return const BoltPage(child: SizedBox.expand());
    final plan = store.plan(t.id);
    final visits = d.visits[t.id] ?? const <Visit>[];
    final metric = d.settings.kg;
    final now = store.now;
    final ws = weekStart(now, mondayFirst: d.settings.mondayFirst);
    final insets = MediaQuery.paddingOf(context);
    final c = t.challenge;
    final solo = d.account?.role == Role.solo;
    final lifts = loggedLifts(plan);

    return BoltPage(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, insets.top + 16, 20, 60 + insets.bottom),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PageHead(onBack: () => context.pop(), kicker: tx('PROGRESS'), title: tx('Your training')),
            const SizedBox(height: 18),
            _ProofOfWork(plan: plan, ws: ws, metric: metric),
            const SizedBox(height: 10),
            // Two doors side by side: the month story and the logbook.
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: DoorTile(
                      title: tx('Your month in Bolt'),
                      color: BoltColors.neon,
                      onTap: () => context.push('/wrap'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DoorTile(
                      title: tx('Logbook'),
                      sub: tx('Every workout, set by set, and your records'),
                      color: BoltColors.heat,
                      onTap: () => context.push('/history'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            if (store.currentSeason() case final s?) ...[
              SeasonCard(s: s, plan: plan, today: dk(now)),
              const SizedBox(height: 10),
            ],
            if (c != null) ...[
              ChallengeCard(
                c: c,
                progress: challengeProgress(c, plan, visits),
                now: now,
                onTap: solo ? () => showBoltSheet<void>(context, (_) => ChallengeSheet(tid: t.id)) : null,
              ),
              const SizedBox(height: 10),
            ],
            // What can still be started, side by side rather than stacked.
            Row(
              children: [
                if (store.currentSeason() == null)
                  Expanded(
                    child: OutlineButton(
                      label: tx('+ Start a season'),
                      height: 46,
                      radius: 14,
                      fontSize: 13,
                      onTap: () => showBoltSheet<void>(context, (_) => const SeasonSheet()),
                    ),
                  ),
                if (store.currentSeason() == null && c == null && solo) const SizedBox(width: 8),
                if (c == null && solo)
                  Expanded(
                    child: OutlineButton(
                      label: tx('+ Set a challenge'),
                      height: 46,
                      radius: 14,
                      fontSize: 13,
                      onTap: () => showBoltSheet<void>(context, (_) => ChallengeSheet(tid: t.id)),
                    ),
                  ),
              ],
            ),
            Section(tx('Last week')),
            RecapTiles(r: weekRecap(plan, visits, t.body, addDays(ws, -7)), metric: metric),
            Section(
              tx('Recovery'),
              sub: tx('From your last workout for each muscle: 3 days for legs and back, 2 for the rest.'),
            ),
            // Full size once there is something to show.
            RecoveryCard(plan: plan, today: dk(now), big: lastTrained(plan, dk(now)).isNotEmpty),
            Section(
              tx('Check-ins'),
              sub: tx('Your daily sleep, energy and soreness answers. Tap a day on the calendar to see it.'),
            ),
            CheckIns(readiness: t.readiness, now: now),
            Section(
              tx('Muscle volume this week'),
              sub: tx('Hard sets per muscle in finished workouts, against the weekly range from Atlas.'),
            ),
            // An empty map says nothing the zero bars below do not.
            if (muscleSets(plan, dk(ws), dk(addDays(ws, 7))).values.any((v) => v > 0)) ...[
              Stage(
                color: BoltColors.body,
                padding: const EdgeInsets.fromLTRB(14, 16, 14, 12),
                child: MuscleMap(sets: muscleSets(plan, dk(ws), dk(addDays(ws, 7)))),
              ),
              const SizedBox(height: 8),
            ],
            _Volume(sets: muscleSets(plan, dk(ws), dk(addDays(ws, 7)))),
            if (t.liftGoals.isNotEmpty) ...[
              Section(tx('Lift goals')),
              for (final name in t.liftGoals.keys) ...[
                const SizedBox(height: 8),
                Tap(
                  onTap: () => context.push('/lift/${Uri.encodeComponent(name)}'),
                  child: LiftGoalCard(name: name, t: t, own: false, title: true),
                ),
              ],
            ],
            Section(tx('Records')),
            _Records(d: d, plan: plan, visits: visits, metric: metric, bestStreak: t.stats.bestStreak),
            Section(
              tx('Main lifts'),
              sub: tx('Set a max and a goal on any of them, logged or not, and see your strength level.'),
            ),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final name in kStandardLifts)
                  Tap(
                    onTap: () => context.push('/lift/${Uri.encodeComponent(name)}'),
                    child: BoltBox(
                      radius: 99,
                      color: BoltColors.surface2,
                      stroke: Stroke(t.liftGoals.containsKey(name) ? BoltColors.rank : BoltColors.line),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Text(
                        '${tx(name)}${levelSuffix(name, maxFor(t, plan, name), t.body)}',
                        style: BoltText.a(12, weight: 700),
                      ),
                    ),
                  ),
              ],
            ),
            Section(
              tx('Lifts'),
              sub: lifts.isEmpty
                  ? tx('Tick sets with their weight and reps in a workout and every lift shows up here.')
                  : tx('Tap a lift for its history and estimated max.'),
            ),
            for (final name in lifts) _LiftRow(name: name, days: liftHistory(plan, name), metric: metric, t: t),
          ],
        ),
      ),
    );
  }
}

/// Last week's numbers as tiles, shared with the Monday card on Today.
class RecapTiles extends StatelessWidget {
  const RecapTiles({super.key, required this.r, required this.metric});

  final WeekRecap r;
  final bool metric;

  @override
  Widget build(BuildContext context) {
    final w = r.weightDelta;
    final cells = [
      ('${r.done}/${r.planned}', tx('WORKOUTS')),
      (totalTime(r.gymMins), tx('GYM TIME')),
      ('${r.sets}', tx('SETS')),
      ('${r.visits}', tx('VISITS')),
      (
        w == null ? '-' : '${w < 0 ? '-' : '+'}${weightValue(w.abs(), metric: metric)} ${weightUnit(metric)}',
        tx('WEIGHT'),
      ),
      (r.planned == 0 ? '-' : '${(100 * r.done / r.planned).round()}%', tx('DONE')),
    ];
    // One panel, six figures split by hairlines, not six boxes.
    Widget cell((String, String) c) => Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 8, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Kicker(c.$2, size: 9, spacing: .1),
          const SizedBox(height: 6),
          RollText(c.$1, maxLines: 1, style: BoltText.display(22, color: BoltColors.text)),
        ],
      ),
    );
    return BoltBox(
      color: BoltColors.surface1,
      radius: 20,
      clip: true,
      child: Column(
        children: [
          for (var i = 0; i < cells.length; i += 3) ...[
            if (i > 0) const Divider(height: 1, thickness: 1, color: BoltColors.lineSoft),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var j = i; j < i + 3; j++) ...[
                    if (j > i) const VerticalDivider(width: 1, thickness: 1, color: BoltColors.lineSoft),
                    Expanded(child: cell(cells[j])),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Volume extends StatelessWidget {
  const _Volume({required this.sets});

  final Map<String, int> sets;

  @override
  Widget build(BuildContext context) {
    final rows = [
      for (final e in kMuscles.entries)
        if (volumeRange(e.key) case final (int, int) r when e.key != 'cardio') (e.key, e.value.name, r),
    ];
    return BoltBox(
      color: BoltColors.surface1,
      radius: 20,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          for (final (k, name, (lo, hi)) in rows) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  SizedBox(width: 92, child: Text(tx(name), style: BoltText.a(12, weight: 700))),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        value: ((sets[k] ?? 0) / hi).clamp(0.0, 1.0),
                        minHeight: 6,
                        backgroundColor: BoltColors.lineSoft,
                        valueColor: AlwaysStoppedAnimation((sets[k] ?? 0) >= lo ? BoltColors.body : BoltColors.muted2),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 64,
                    child: Text(
                      '${sets[k] ?? 0} / $lo-$hi',
                      textAlign: TextAlign.right,
                      style: BoltText.m(
                        10,
                        weight: 700,
                        color: (sets[k] ?? 0) >= lo ? BoltColors.body : BoltColors.muted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Records extends StatelessWidget {
  const _Records({
    required this.d,
    required this.plan,
    required this.visits,
    required this.metric,
    required this.bestStreak,
  });

  final BoltData d;
  final Map<String, Session> plan;
  final List<Visit> visits;
  final bool metric;
  final int bestStreak;

  @override
  Widget build(BuildContext context) {
    (String, double, int?, String)? heaviest;
    var volume = 0.0;
    (int, String, String)? mostSets;
    plan.forEach((k, s) {
      if (s.status != SessionStatus.done) return;
      var n = 0;
      for (final e in s.ex) {
        n += e.logged.isNotEmpty ? e.logged.length : e.sets;
        for (final l in e.logged) {
          volume += (l.kg ?? 0) * (l.reps ?? 0);
          if (l.kg != null && (heaviest == null || l.kg! > heaviest!.$2)) heaviest = (e.name, l.kg!, l.reps, k);
        }
      }
      if (n > 0 && (mostSets == null || n > mostSets!.$1)) mostSets = (n, s.title, k);
    });
    final longest = visits.fold<Visit?>(null, (a, v) => a == null || v.mins > a.mins ? v : a);
    String kg(double v) => '${weightValue(v, metric: metric)} ${weightUnit(metric)}';
    final items = <(String, String, String)>[
      if (heaviest case final h?)
        (tx('HEAVIEST SET'), kg(h.$2), '${tx(h.$1)}${h.$3 == null ? '' : ' × ${h.$3}'} · ${fmtDay(h.$4)}'),
      if (longest != null) (tx('LONGEST SESSION'), dur(longest.mins), fmtDay(longest.date)),
      if (mostSets case final m?) (tx('MOST SETS'), '${m.$1}', '${tx(m.$2)} · ${fmtDay(m.$3)}'),
      if (volume > 0)
        (
          tx('TOTAL LIFTED'),
          metric ? '${(volume / 1000).toStringAsFixed(1)} t' : '${(volume * 2.20462).round()} lb',
          tx('Weight × reps, every logged set'),
        ),
      (tx('BEST STREAK'), tx('{n} wk', {'n': bestStreak}), tx('Perfect weeks in a row')),
    ];
    final lead = items.first;
    return Paper(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Kicker(lead.$1, size: 10),
          const SizedBox(height: 8),
          BigFigure(lead.$2, size: 52),
          const SizedBox(height: 6),
          Text(lead.$3, style: BoltText.a(12, color: BoltColors.paperMuted, height: 1.3)),
          const SizedBox(height: 16),
          for (var r = 1; r < items.length; r += 2)
            Container(
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: BoltColors.paperLine)),
              ),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: _record(items[r])),
                    const VerticalDivider(width: 1, thickness: 1, color: BoltColors.paperLine),
                    Expanded(
                      child: r + 1 < items.length
                          ? Padding(padding: const EdgeInsets.only(left: 14), child: _record(items[r + 1]))
                          : const SizedBox(),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _record((String, String, String) x) => Padding(
    padding: const EdgeInsets.fromLTRB(0, 14, 10, 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Kicker(x.$1, size: 9, spacing: .1),
        const SizedBox(height: 6),
        Text(x.$2, style: BoltText.display(24, color: BoltColors.paperInk)),
        const SizedBox(height: 4),
        Text(x.$3, style: BoltText.a(11, color: BoltColors.paperMuted, height: 1.3)),
      ],
    ),
  );
}

class _LiftRow extends StatelessWidget {
  const _LiftRow({required this.name, required this.days, required this.metric, required this.t});

  final String name;
  final List<LiftDay> days;
  final bool metric;
  final Trainee t;

  @override
  Widget build(BuildContext context) {
    final best = days.map((x) => x.best).whereType<double>().fold<double?>(null, (a, b) => a == null || b > a ? b : a);
    final reps = days.map((x) => x.topReps).whereType<int>().fold<int?>(null, (a, b) => a == null || b > a ? b : a);
    return Tap(
      onTap: () => context.push('/lift/${Uri.encodeComponent(name)}'),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: BoltColors.divider)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tx(name), style: BoltText.a(14, weight: 800)),
                  const SizedBox(height: 2),
                  Text(
                    tx('{n} · last {day}', {'n': plural(days.length, 'workout'), 'day': fmtDay(days.last.date)}) +
                        levelSuffix(name, t.maxes[name] ?? best, t.body),
                    style: BoltText.a(11, color: BoltColors.muted),
                  ),
                ],
              ),
            ),
            Text(
              best != null
                  ? 'e1RM ${weightValue(best, metric: metric)} ${weightUnit(metric)}'
                  : (reps == null ? '' : tx('best {n} reps', {'n': reps})),
              style: BoltText.m(11, weight: 700, color: BoltColors.neon),
            ),
            const SizedBox(width: 8),
            const Chevron(size: 16),
          ],
        ),
      ),
    );
  }
}

/// The hero: what you lifted in the last four weeks, in big type on paper,
/// with eight weeks of volume as a line and the change on the four before.
class _ProofOfWork extends StatelessWidget {
  const _ProofOfWork({required this.plan, required this.ws, required this.metric});

  final Map<String, Session> plan;
  final DateTime ws;
  final bool metric;

  @override
  Widget build(BuildContext context) {
    final weeks = [for (var w = 7; w >= 0; w--) _volume(plan, dk(addDays(ws, -7 * w)), dk(addDays(ws, 7 - 7 * w)))];
    final recent = weeks.skip(4).fold(0.0, (a, b) => a + b);
    final before = weeks.take(4).fold(0.0, (a, b) => a + b);
    final value = metric ? (recent / 1000).toStringAsFixed(1) : '${(recent * 2.20462).round()}';
    final change = before > 0 && recent > 0 ? ((recent - before) / before * 100).round() : null;
    return Paper(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Kicker(tx('LAST 8 WEEKS'), size: 10),
          const SizedBox(height: 10),
          BigFigure(value, unit: metric ? tx('tonnes lifted in 4 weeks') : tx('lb lifted in 4 weeks'), size: 68),
          const SizedBox(height: 14),
          if (weeks.any((v) => v > 0))
            Sparkline(values: weeks, height: 64, color: BoltColors.paperInk)
          else
            Text(
              tx('Tick sets with their weight and reps in a workout and every lift shows up here.'),
              style: BoltText.a(12, color: BoltColors.paperMuted, height: 1.4),
            ),
          if (change != null) ...[
            const SizedBox(height: 12),
            Text(
              tx('{p} on the 4 weeks before', {'p': '${change >= 0 ? '+' : ''}$change%'}),
              style: BoltText.m(11, weight: 700, color: Tone.paper().accent),
            ),
          ],
        ],
      ),
    );
  }

  static double _volume(Map<String, Session> plan, String from, String to) {
    var v = 0.0;
    plan.forEach((k, s) {
      if (s.status != SessionStatus.done || k.compareTo(from) < 0 || k.compareTo(to) >= 0) return;
      for (final e in s.ex) {
        for (final l in e.logged) {
          v += (l.kg ?? 0) * (l.reps ?? 0);
        }
      }
    });
    return v;
  }
}
