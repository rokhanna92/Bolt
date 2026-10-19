import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/units.dart';
import '../../data/bolt_store.dart';
import '../../data/lifts.dart';
import '../../data/models/exercise.dart';
import '../../data/models/session.dart';
import '../../data/rules.dart';
import '../../theme/text_styles.dart';
import '../../theme/tokens.dart';
import '../../widgets/box.dart';
import '../../widgets/common.dart';
import '../../widgets/tap.dart';
import '../workout/floor_view.dart' show setsText;
import '../workout/workout_screen.dart' show volumeText;

/// The logbook: every finished workout, newest first, set by set, with the
/// records it broke. [tpl] opens it on one workout. Your workouts keep their
/// numbers as the standard; this is where every time is kept.
class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key, this.tpl});

  final String? tpl;

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  late String? _tpl = widget.tpl;

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(boltProvider);
    final store = ref.read(boltProvider.notifier);
    final t = store.trOrNull(d.account?.id ?? '');
    if (t == null) return const BoltPage(child: SizedBox.expand());
    final plan = store.plan(t.id);
    final metric = d.settings.kg;
    final insets = MediaQuery.paddingOf(context);
    final days = [
      for (final k in plan.keys.toList()..sort((a, b) => b.compareTo(a)))
        if (plan[k]!.status == SessionStatus.done && plan[k]!.ex.isNotEmpty) k,
    ];
    // One chip per workout done, most recent first.
    final kinds = <String, String>{};
    for (final k in days) {
      kinds.putIfAbsent(plan[k]!.tpl, () => plan[k]!.title);
    }
    if (_tpl != null) kinds.putIfAbsent(_tpl!, () => d.tpls[_tpl]?.name ?? '');
    final shown = [
      for (final k in days)
        if (_tpl == null || plan[k]!.tpl == _tpl) k,
    ];
    final sets = shown.fold(0, (a, k) => a + plan[k]!.ex.fold(0, (b, e) => b + e.logged.length));
    final records = <(String, SetLog, String)>[
      for (final k in shown)
        for (final name in plan[k]!.prs)
          if (_best(plan[k]!, name) case final s?) (name, s, k),
    ].take(4).toList();

    Widget chip(String? id, String label) => Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Tap(
        onTap: () => setState(() => _tpl = id),
        child: BoltBox(
          radius: 99,
          color: _tpl == id ? BoltColors.neon : BoltColors.surface2,
          stroke: Stroke(_tpl == id ? BoltColors.neon : BoltColors.line),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Text(label, style: BoltText.a(12, weight: 700, color: _tpl == id ? BoltColors.ink : BoltColors.text)),
        ),
      ),
    );

    return BoltPage(
      child: ListView(
        padding: EdgeInsets.fromLTRB(20, insets.top + 16, 20, 60 + insets.bottom),
        children: [
          Row(
            children: [
              BackBox(onTap: () => context.pop()),
              const SizedBox(width: 12),
              Kicker(tx('LOGBOOK')),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            _tpl == null ? tx('History') : tx(kinds[_tpl] ?? ''),
            style: BoltText.a(30, weight: 900, width: 112, spacing: -.02),
          ),
          const SizedBox(height: 4),
          Text(
            '${plural(shown.length, 'workout')} · ${plural(sets, 'set')}',
            style: BoltText.a(13, color: BoltColors.muted),
          ),
          if (kinds.length > 1 || _tpl != null) ...[
            const SizedBox(height: 14),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [chip(null, tx('All')), for (final e in kinds.entries) chip(e.key, tx(e.value))]),
            ),
          ],
          if (records.isNotEmpty) ...[
            const SizedBox(height: 20),
            SectionTitle(tx('Latest records')),
            const SizedBox(height: 10),
            for (var r = 0; r < records.length; r += 2) ...[
              if (r > 0) const SizedBox(height: 8),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _Record(r: records[r], metric: metric),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: r + 1 < records.length ? _Record(r: records[r + 1], metric: metric) : const SizedBox(),
                    ),
                  ],
                ),
              ),
            ],
          ],
          const SizedBox(height: 20),
          if (shown.isEmpty)
            Text(
              tx('Finish a workout with its sets ticked and it lands here: every set with its weight and reps.'),
              style: BoltText.a(13, color: BoltColors.muted, height: 1.45),
            ),
          for (final k in shown) ...[_DayCard(dayKey: k, s: plan[k]!, metric: metric), const SizedBox(height: 10)],
        ],
      ),
    );
  }
}

/// The heaviest logged set of [name] in [s].
SetLog? _best(Session s, String name) {
  SetLog? b;
  for (final e in s.ex) {
    if (e.name != name) continue;
    for (final l in e.logged) {
      if (b == null || (l.kg ?? 0) > (b.kg ?? 0) || ((l.kg ?? 0) == (b.kg ?? 0) && (l.reps ?? 0) > (b.reps ?? 0))) {
        b = l;
      }
    }
  }
  return b;
}

class _Record extends StatelessWidget {
  const _Record({required this.r, required this.metric});

  final (String, SetLog, String) r;
  final bool metric;

  @override
  Widget build(BuildContext context) {
    final (name, s, k) = r;
    return Tap(
      onTap: () => context.push('/lift/${Uri.encodeComponent(name)}'),
      child: BoltBox(
        color: BoltColors.surface1,
        stroke: const Stroke(Color(0x73C6FF1A)),
        radius: 16,
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Kicker('PR · ${fmtDay(k).toUpperCase()}', size: 9, spacing: .1, color: BoltColors.neon),
            const SizedBox(height: 4),
            Text(
              [if (s.kg != null) fmtWeight(s.kg!, metric: metric), if (s.reps != null) '× ${s.reps}'].join(' '),
              style: BoltText.a(18, weight: 900),
            ),
            const SizedBox(height: 2),
            Text(tx(name), style: BoltText.a(11, color: BoltColors.muted, height: 1.3)),
          ],
        ),
      ),
    );
  }
}

/// One finished workout: when, how long, what it moved and every set.
class _DayCard extends StatelessWidget {
  const _DayCard({required this.dayKey, required this.s, required this.metric});

  final String dayKey;
  final Session s;
  final bool metric;

  @override
  Widget build(BuildContext context) {
    final logged = s.ex.where((e) => e.logged.isNotEmpty).toList();
    final (kg, _) = workOf(logged.expand((e) => e.logged));
    final meta = [
      logText(s.log),
      if (s.took != null) dur(s.took!),
      if (kg > 0) volumeText(kg, metric: metric),
    ].where((x) => x.isNotEmpty).join(' · ');
    return BoltBox(
      color: BoltColors.surface1,
      stroke: Stroke(s.prs.isNotEmpty ? const Color(0x73C6FF1A) : BoltColors.lineSoft),
      radius: 18,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Tap(
            onTap: () => context.push('/summary/$dayKey'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(child: Kicker(fmtDay(dayKey).toUpperCase(), size: 10)),
                    if (s.prs.isNotEmpty)
                      Kicker(
                        s.prs.length == 1 ? 'PR' : tx('{n} PRs', {'n': s.prs.length}),
                        size: 10,
                        weight: 700,
                        color: BoltColors.neon,
                      ),
                    const SizedBox(width: 6),
                    const Chevron(size: 14),
                  ],
                ),
                const SizedBox(height: 4),
                Text(tx(s.title), style: BoltText.a(18, weight: 900)),
                if (meta.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(meta, style: BoltText.a(12, color: BoltColors.muted)),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),
          if (logged.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                tx('Logged as done without sets, so there are no weights to show.'),
                style: BoltText.a(12, color: BoltColors.muted3, height: 1.4),
              ),
            ),
          for (final e in logged)
            Tap(
              onTap: () => context.push('/lift/${Uri.encodeComponent(e.name)}'),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: BoltColors.divider)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(tx(e.name), style: BoltText.a(14, weight: 700)),
                          const SizedBox(height: 2),
                          Text(
                            setsText(e.logged, metric: metric),
                            style: BoltText.m(12, color: BoltColors.textSoft),
                          ),
                        ],
                      ),
                    ),
                    if (s.prs.contains(e.name)) ...[
                      const SizedBox(width: 8),
                      Kicker('PR', size: 10, weight: 700, color: BoltColors.neon),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
