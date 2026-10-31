import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../data/bolt_store.dart';
import '../../data/models/people.dart';
import '../../data/models/session.dart';
import '../../theme/text_styles.dart';
import '../../theme/tokens.dart';
import '../../widgets/box.dart';
import '../../widgets/calendar_grid.dart';
import '../../widgets/common.dart';
import '../coach_schedule/schedule_screen.dart' show TraineeSessionRow;

const _legend = [
  LegendItem('Done', BoltColors.neon, Stroke(BoltColors.neon)),
  LegendItem('Confirmed', BoltColors.text, Stroke(BoltColors.text)),
  LegendItem('Waiting', Colors.transparent, Stroke(BoltColors.neon, 1.5)),
  LegendItem('Draft', Colors.transparent, Stroke.dashed(BoltColors.muted2, 1.5)),
];

/// Every trainee's sessions by month, a dot per session. Tapping a day lists
/// its sessions. The coach's centre button opens it.
class CoachCalendarScreen extends ConsumerStatefulWidget {
  const CoachCalendarScreen({super.key});

  @override
  ConsumerState<CoachCalendarScreen> createState() => _CoachCalendarScreenState();
}

class _CoachCalendarScreenState extends ConsumerState<CoachCalendarScreen> {
  late final BoltStore _store = ref.read(boltProvider.notifier);
  late DateTime _month = DateTime(_store.now.year, _store.now.month);
  late String _sel = _store.today;

  void _goMonth(int by) {
    final m = DateTime(_month.year, _month.month + by);
    final n = _store.now;
    setState(() {
      _month = m;
      _sel = m.year == n.year && m.month == n.month ? _store.today : dk(m);
    });
  }

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(boltProvider);
    final c = _store.co(d.account?.id ?? '');
    final today = _store.today;
    final my = d.trainees.where((x) => x.coach == c.id).toList()..sort((a, b) => a.name.compareTo(b.name));
    final byDay = <String, List<(Trainee, Session)>>{};
    for (final x in my) {
      _store.plan(x.id).forEach((k, s) => byDay.putIfAbsent(k, () => []).add((x, s)));
    }
    final cells = buildCalendar(
      month: _month,
      plan: const {},
      tpls: d.tpls,
      today: today,
      coach: true,
      mondayFirst: d.settings.mondayFirst,
      selKey: _sel,
      dots: byDay.map((k, v) => MapEntry(k, [for (final e in v) e.$2.status])),
    );
    final inMonth = [
      for (final e in byDay.entries)
        if (e.key.startsWith(dk(_month).substring(0, 8))) ...e.value.map((v) => v.$2.status),
    ];
    final ok = inMonth.where((s) => s == SessionStatus.done || s == SessionStatus.approved).length;
    final open = inMonth.where((s) => s == SessionStatus.pending || s == SessionStatus.moved).length;
    final day = byDay[_sel] ?? const [];

    return ScreenScroll(
      children: [
        Kicker('${tx('CALENDAR')} · ${plural(my.length, 'trainee').toUpperCase()}'),
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(monthsLong[_month.month - 1], style: BoltText.a(30, weight: 900, width: 112, spacing: -.02)),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('${_month.year}', style: BoltText.m(12, color: BoltColors.muted)),
            ),
            const Spacer(),
            SquareButton(onTap: () => _goMonth(-1), label: '‹'),
            const SizedBox(width: 6),
            SquareButton(onTap: () => _goMonth(1), label: '›'),
          ],
        ),
        const SizedBox(height: 16),
        StatRow(
          children: [
            StatTile(value: '${inMonth.length}', label: tx('SESSIONS'), valueSize: 26),
            StatTile(value: '$ok', label: tx('CONFIRMED'), valueSize: 26, valueColor: BoltColors.neon),
            StatTile(value: '$open', label: tx('OPEN'), valueSize: 26),
          ],
        ),
        const SizedBox(height: 18),
        WeekdayHeader(mondayFirst: d.settings.mondayFirst),
        const SizedBox(height: 8),
        CalendarGrid(
          cells: cells,
          onTap: (cell) => setState(() {
            _sel = cell.k;
            final t = DateTime.parse(cell.k);
            _month = DateTime(t.year, t.month);
          }),
        ),
        const SizedBox(height: 12),
        const Legend(items: _legend),
        const SizedBox(height: 22),
        Row(
          children: [
            Text(
              fmtDay(_sel).toUpperCase(),
              style: BoltText.m(
                11,
                weight: 700,
                spacing: .1,
                color: _sel == today ? BoltColors.neon : BoltColors.muted,
              ),
            ),
            const SizedBox(width: 8),
            const Expanded(child: Divider(height: 1, thickness: 1, color: BoltColors.divider)),
          ],
        ),
        for (final (x, s) in day)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: TraineeSessionRow(trainee: x, session: s, inGym: d.gymIn[x.id] != null && _sel == today),
          ),
        if (day.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 10, 2, 2),
            child: Text(
              my.isEmpty ? tx('Add trainees to see their sessions here.') : tx('No sessions'),
              style: BoltText.a(12, color: BoltColors.muted3),
            ),
          ),
      ],
    );
  }
}
