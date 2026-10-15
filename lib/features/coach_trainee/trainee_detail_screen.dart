import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/actions.dart';
import '../../app/share.dart';
import '../../app/tick.dart';
import '../../core/format.dart';
import '../../data/bolt_store.dart';
import '../../data/models/session.dart';
import '../../data/models/visit.dart';
import '../../data/rules.dart';
import '../../data/seed/splits.dart';
import '../../data/seed/templates.dart';
import '../../theme/text_styles.dart';
import '../../theme/tokens.dart';
import '../../widgets/box.dart';
import '../../widgets/calendar_grid.dart';
import '../../widgets/common.dart';
import '../../widgets/exercise_rows.dart';
import '../../widgets/motion.dart';
import '../../widgets/tap.dart';
import '../badges/badges_screen.dart';
import '../gym/gym_screen.dart' show VisitRow, visitDay;
import '../profile/body_card.dart';
import '../workouts/workout_picker.dart';

class TraineeDetailScreen extends ConsumerStatefulWidget {
  const TraineeDetailScreen({super.key, required this.tid});

  final String tid;

  @override
  ConsumerState<TraineeDetailScreen> createState() => _TraineeDetailScreenState();
}

class _TraineeDetailScreenState extends ConsumerState<TraineeDetailScreen> {
  late DateTime _month = () {
    final n = ref.read(boltProvider.notifier).now;
    return DateTime(n.year, n.month);
  }();
  String? _sel;

  String _coachLabel(SessionStatus s, String fn) => switch (s) {
    SessionStatus.done => 'Done',
    SessionStatus.approved => 'Confirmed by $fn',
    SessionStatus.pending => 'Waiting for $fn',
    SessionStatus.moved => 'Moved by $fn',
    SessionStatus.draft => 'Draft · not sent',
  };

  /// Sends drafts: the plan goes out as a message the trainee pastes into Bolt.
  Future<void> _send(String tid, String fn) async {
    final store = ref.read(boltProvider.notifier);
    final n = store.plan(tid).values.where((s) => s.status == SessionStatus.draft).length;
    final msg = store.sendDrafts(tid);
    if (msg == null) return;
    final hint = await shareMessage(msg, subject: 'Your Bolt plan');
    store.toast(hint ?? 'Sent ${plural(n, 'session')} · waiting for $fn');
  }

  Future<void> _remove(String tid, String name) async {
    final ok = await confirmSheet(
      context,
      title: 'Remove ${firstName(name)}?',
      body: 'Their plan, visits and measurements are deleted from this phone.',
      confirm: 'Remove',
    );
    if (ok && mounted) {
      context.pop();
      ref.read(boltProvider.notifier).removeTrainee(tid);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(boltProvider);
    final store = ref.read(boltProvider.notifier);
    final x = store.trOrNull(widget.tid);
    if (x == null) return const BoltPage(child: SizedBox.expand());
    final p = store.plan(x.id);
    final fn = firstName(x.name);
    final today = store.today;
    final sp = _sel == null ? null : p[_sel];
    final drafts = p.values.where((s) => s.status == SessionStatus.draft).length;
    final insets = MediaQuery.paddingOf(context);
    final cells = buildCalendar(
      month: _month,
      plan: p,
      tpls: d.tpls,
      today: today,
      coach: true,
      mondayFirst: d.settings.mondayFirst,
      selKey: _sel,
    );

    void onCell(CalCell c) {
      if (c.session == null && c.k.compareTo(today) >= 0) {
        store.addFromRotation(x.id, c.k);
        setState(() => _sel = c.k);
        return;
      }
      setState(() => _sel = c.session != null ? c.k : null);
    }

    return BoltPage(
      child: Stack(
        children: [
          SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(20, insets.top + 16, 20, 140 + insets.bottom),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    BackBox(onTap: () => context.pop()),
                    const SizedBox(width: 12),
                    Avatar(ini: initials(x.name), size: 46, fontSize: 15, weight: 900, fill: BoltColors.neon),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(x.name, style: BoltText.a(20, weight: 900, spacing: -.01)),
                          const SizedBox(height: 2),
                          Text('${x.goal} · since ${x.since}', style: BoltText.a(12, color: BoltColors.muted)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: Tap(
                          onTap: () => showSplitSheet(x.id),
                          child: BoltBox(
                            radius: 14,
                            stroke: const Stroke(BoltColors.line),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Kicker('DEFAULT SPLIT · TAP TO CHANGE', size: 9, spacing: .1),
                                const SizedBox(height: 2),
                                Text(splitOf(d, x.split).name, style: BoltText.a(13, weight: 800)),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Tap(
                        onTap: () => store.autoFill(x.id),
                        scale: .96,
                        child: BoltBox(
                          radius: 14,
                          color: BoltColors.neon,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          alignment: Alignment.center,
                          child: Text('Auto-fill 3 wks', style: BoltText.a(13, weight: 800, color: BoltColors.ink)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                for (var i = 0; i < x.injuries.length; i++) ...[
                  BoltBox(
                    radius: 14,
                    color: const Color(0x0FFF7A45),
                    stroke: const Stroke(Color(0x73FF7A45)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                kAreas[x.injuries[i].area]!,
                                style: BoltText.a(13, weight: 800, color: BoltColors.warn),
                              ),
                              const SizedBox(height: 2),
                              Text(x.injuries[i].note, style: BoltText.a(12)),
                              const SizedBox(height: 2),
                              Kicker(x.injuries[i].by, size: 9, spacing: 0),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Tap(
                          onTap: () => store.resolveInjury(x.id, i),
                          child: Padding(
                            padding: const EdgeInsets.all(6),
                            child: Text('Resolve', style: BoltText.a(12, weight: 700, color: BoltColors.muted)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                ],
                Align(
                  alignment: Alignment.centerLeft,
                  child: Tap(
                    onTap: () => showInjurySheet(x.id),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
                      child: Text('+ Add injury flag', style: BoltText.a(12, weight: 700, color: BoltColors.warn)),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const SectionTitle('Progress', size: 16),
                const SizedBox(height: 4),
                Text(
                  'From $fn\'s updates: gym sessions, workouts and badges.',
                  style: BoltText.a(12, color: BoltColors.muted),
                ),
                const SizedBox(height: 10),
                StatRow(
                  children: [
                    StatTile(value: '${x.stats.sessions}', label: 'SESSIONS', valueColor: BoltColors.neon),
                    StatTile(value: '${x.stats.mins ~/ 60}', label: 'HOURS'),
                    StatTile(value: '${currentStreak(x.stats, store.now)}', label: 'WEEK STREAK'),
                  ],
                ),
                const SizedBox(height: 8),
                BadgesCard(stats: displayStats(x.stats, store.now)),
                const SizedBox(height: 18),
                BodyCard(
                  body: x.body,
                  titleSize: 16,
                  empty: 'No measurements yet. Add them here, or they arrive with $fn\'s updates.',
                  onEdit: () => context.push('/edit-profile/${x.id}'),
                  onProgress: () => context.push('/measurements/${x.id}'),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Text(monthsLong[_month.month - 1], style: BoltText.a(22, weight: 900)),
                    const SizedBox(width: 8),
                    Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: Text('${_month.year}', style: BoltText.m(12, color: BoltColors.muted)),
                    ),
                    const Spacer(),
                    SquareButton(
                      onTap: () => setState(() => _month = DateTime(_month.year, _month.month - 1)),
                      label: '‹',
                      size: 36,
                      radius: 10,
                      fontSize: 16,
                    ),
                    const SizedBox(width: 6),
                    SquareButton(
                      onTap: () => setState(() => _month = DateTime(_month.year, _month.month + 1)),
                      label: '›',
                      size: 36,
                      radius: 10,
                      fontSize: 16,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Tap an empty day to add the next session from the split.',
                  style: BoltText.a(12, color: BoltColors.muted),
                ),
                const SizedBox(height: 10),
                WeekdayHeader(mondayFirst: d.settings.mondayFirst),
                const SizedBox(height: 6),
                CalendarGrid(cells: cells, onTap: onCell, cellHeight: 48, numSize: 13, labSpacing: 0),
                const SizedBox(height: 12),
                const Legend(items: coachLegend, gap: 10),
                if (sp != null) ...[
                  const SizedBox(height: 16),
                  FadeSlideIn(
                    key: ValueKey(_sel),
                    duration: const Duration(milliseconds: 250),
                    child: _SelectedDay(
                      tid: x.id,
                      dayKey: _sel!,
                      label: _coachLabel(sp.status, fn),
                      onRemove: () {
                        store.removeDay(x.id, _sel!);
                        setState(() => _sel = null);
                      },
                    ),
                  ),
                ],
                const SizedBox(height: 22),
                const SectionTitle('Recent visits', size: 16),
                const SizedBox(height: 6),
                _Visits(tid: x.id),
                const SizedBox(height: 22),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Tap(
                    onTap: () => _remove(x.id, x.name),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Text('Remove trainee', style: BoltText.a(13, weight: 700, color: BoltColors.warn)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (drafts > 0)
            Positioned(
              left: 20,
              right: 20,
              bottom: 20 + insets.bottom,
              child: FadeSlideIn(
                duration: const Duration(milliseconds: 300),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: const [BoxShadow(color: Color(0x99000000), blurRadius: 30, offset: Offset(0, 10))],
                  ),
                  child: NeonButton(
                    label: 'Send ${plural(drafts, 'session')} to $fn',
                    height: 56,
                    radius: 18,
                    onTap: () => _send(x.id, fn),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SelectedDay extends ConsumerWidget {
  const _SelectedDay({required this.tid, required this.dayKey, required this.label, required this.onRemove});

  final String tid;
  final String dayKey;
  final String label;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(boltProvider);
    final store = ref.read(boltProvider.notifier);
    final s = store.plan(tid)[dayKey];
    if (s == null) return const SizedBox.shrink();
    final editable = s.status != SessionStatus.done;
    final c = chipFor(s.status);
    return BoltBox(
      color: BoltColors.surface1,
      stroke: const Stroke(BoltColors.line),
      radius: 20,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Kicker(fmtDay(dayKey).toUpperCase(), size: 10, spacing: .1)),
              const SizedBox(width: 8),
              BoltBox(
                color: c.bg,
                stroke: c.stroke,
                radius: 99,
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                child: Text(label, style: BoltText.a(11, weight: 700, color: c.fg)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(s.title.toUpperCase(), style: BoltText.a(26, weight: 900, width: 112)),
          if (s.from != null) ...[
            const SizedBox(height: 2),
            Kicker('ORIGINALLY ${fmtDay(s.from!).toUpperCase()}', size: 10, spacing: 0),
          ],
          if (!editable) ...[
            const SizedBox(height: 4),
            Text('Logged · ${s.log ?? ''}', style: BoltText.a(13, color: BoltColors.neon)),
          ],
          if (editable) ...[
            const SizedBox(height: 10),
            ChangeWorkoutButton(onTap: () => changeDayWorkout(tid, dayKey)),
          ],
          const SizedBox(height: 10),
          ExerciseRows(trainee: store.tr(tid), exercises: s.ex, canSwap: editable, compact: true),
          if (editable) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlineButton(
                    label: 'Edit exercises',
                    height: 44,
                    radius: 12,
                    fontSize: 13,
                    onTap: () => context.push('/editor/day/$tid/$dayKey'),
                  ),
                ),
                const SizedBox(width: 8),
                Tap(
                  onTap: onRemove,
                  child: BoltBox(
                    height: 44,
                    radius: 12,
                    stroke: const Stroke(BoltColors.line),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    alignment: Alignment.center,
                    child: Text('Remove', style: BoltText.a(13, weight: 700, color: BoltColors.muted)),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Visits extends ConsumerWidget {
  const _Visits({required this.tid});

  final String tid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(boltProvider);
    final g = d.gymIn[tid];
    final now = g == null ? DateTime.now() : watchNow(ref);
    final v = d.visits[tid] ?? const <Visit>[];
    if (g == null && v.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Text('No visits yet.', style: BoltText.a(13, color: BoltColors.muted)),
      );
    }
    return Column(
      children: [
        if (g != null)
          VisitRow(
            day: 'TODAY · LIVE',
            range: '${g.since} → now',
            dur: dur(g.elapsedMinutes(now)),
            live: true,
            compact: true,
          ),
        for (final x in v.take(3))
          VisitRow(day: visitDay(x), range: '${x.inT} → ${x.outT}', dur: dur(x.mins), compact: true),
      ],
    );
  }
}
