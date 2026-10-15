import 'package:flutter/material.dart';

import '../core/format.dart';
import '../data/models/session.dart';
import '../data/models/template.dart';
import '../theme/text_styles.dart';
import '../theme/tokens.dart';
import 'box.dart';
import 'tap.dart';

class CalCell {
  const CalCell({
    required this.k,
    required this.n,
    required this.lab,
    required this.bg,
    required this.stroke,
    required this.num,
    required this.labColor,
    required this.ring,
    required this.inMonth,
    required this.today,
    required this.todayColor,
    required this.session,
    this.dots = const [],
  });

  final String k;
  final int n;
  final String lab;
  final Color bg;
  final Stroke stroke;
  final Color num;
  final Color labColor;
  final bool ring;
  final bool inMonth;
  final bool today;
  final Color todayColor;
  final Session? session;

  /// Several people's sessions on this day, shown as dots instead of [lab].
  final List<SessionStatus> dots;
}

/// Calendar cells for [month], styled per session status (`cal()` in the
/// prototype). Trainees never see drafts. [dots] puts several people's
/// sessions on a day instead, one dot each.
List<CalCell> buildCalendar({
  required DateTime month,
  required Map<String, Session> plan,
  required Map<String, WorkoutTemplate> tpls,
  required String today,
  required bool coach,
  required bool mondayFirst,
  String? selKey,
  String? moveFrom,
  Map<String, List<SessionStatus>> dots = const {},
}) {
  final first = DateTime(month.year, month.month, 1);
  final start = weekStart(first, mondayFirst: mondayFirst);
  final dim = DateTime(month.year, month.month + 1, 0).day;
  final off = first.difference(start).inDays;
  final cnt = ((off + dim) / 7).ceil() * 7;
  final cells = <CalCell>[];
  for (var i = 0; i < cnt; i++) {
    final d = addDays(start, i);
    final k = dk(d);
    final inM = d.month == month.month;
    var p = plan[k];
    if (p != null && !coach && p.status == SessionStatus.draft) p = null;
    final past = k.compareTo(today) < 0;
    var bg = Colors.transparent;
    var stroke = const Stroke(Colors.transparent);
    var num = inM ? (past ? BoltColors.muted4 : BoltColors.textSoft) : BoltColors.handle;
    var lab = BoltColors.neon;
    switch (p?.status) {
      case SessionStatus.done:
        bg = BoltColors.neon;
        stroke = const Stroke(BoltColors.neon);
        num = BoltColors.ink;
        lab = BoltColors.ink;
      case SessionStatus.approved:
        bg = BoltColors.surface2;
        stroke = const Stroke(BoltColors.line);
        num = BoltColors.text;
      case SessionStatus.pending:
        stroke = const Stroke.dashed(BoltColors.neon, 1.5);
        num = BoltColors.text;
      case SessionStatus.moved:
        bg = BoltColors.surface2;
        stroke = const Stroke(BoltColors.text, 1.5);
        num = BoltColors.text;
        lab = BoltColors.text;
      case SessionStatus.draft:
        stroke = const Stroke.dashed(BoltColors.muted2, 1.5);
        num = BoltColors.text;
        lab = BoltColors.textSoft;
      case null:
        break;
    }
    final ds = dots[k] ?? const <SessionStatus>[];
    if (ds.isNotEmpty && inM && !past) num = BoltColors.text;
    if (moveFrom != null && p == null && !past && inM) bg = const Color(0x17C6FF1A);
    if (moveFrom == k) stroke = const Stroke(BoltColors.neon, 1.5);
    final tpl = p == null ? null : tpls[p.tpl];
    final title = p?.title ?? '';
    cells.add(
      CalCell(
        k: k,
        n: d.day,
        lab: p == null ? '' : (tpl?.code ?? (title.length > 4 ? title.substring(0, 4) : title).toUpperCase()),
        bg: bg,
        stroke: stroke,
        num: num,
        labColor: lab,
        ring: selKey == k,
        inMonth: inM,
        today: k == today,
        todayColor: p?.status == SessionStatus.done ? BoltColors.ink : BoltColors.neon,
        session: p,
        dots: ds,
      ),
    );
  }
  return cells;
}

/// Weekday initials row.
class WeekdayHeader extends StatelessWidget {
  const WeekdayHeader({super.key, required this.mondayFirst});

  final bool mondayFirst;

  @override
  Widget build(BuildContext context) {
    final letters = mondayFirst ? 'MTWTFSS' : 'SMTWTFS';
    return Row(
      children: [
        for (var i = 0; i < 7; i++) ...[
          if (i > 0) const SizedBox(width: 5),
          Expanded(
            child: Text(
              letters[i],
              textAlign: TextAlign.center,
              style: BoltText.m(10, color: BoltColors.muted3),
            ),
          ),
        ],
      ],
    );
  }
}

class CalendarGrid extends StatelessWidget {
  const CalendarGrid({
    super.key,
    required this.cells,
    required this.onTap,
    this.cellHeight = 50,
    this.numSize = 14,
    this.labSpacing = .04,
  });

  final List<CalCell> cells;
  final void Function(CalCell c) onTap;
  final double cellHeight;
  final double numSize;
  final double labSpacing;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var r = 0; r < cells.length; r += 7) {
      if (r > 0) rows.add(const SizedBox(height: 5));
      rows.add(
        Row(
          children: [
            for (var i = 0; i < 7; i++) ...[if (i > 0) const SizedBox(width: 5), Expanded(child: _cell(cells[r + i]))],
          ],
        ),
      );
    }
    return Column(children: rows);
  }

  Widget _cell(CalCell c) {
    return Tap(
      onTap: () => onTap(c),
      child: Opacity(
        opacity: c.inMonth ? 1 : .35,
        child: CustomPaint(
          foregroundPainter: c.ring ? const _RingPainter() : null,
          child: BoltBox(
            height: cellHeight,
            borderBox: true,
            radius: BoltRadii.cell,
            color: c.bg,
            stroke: c.stroke,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('${c.n}', style: BoltText.a(numSize, weight: 700, color: c.num)),
                      const SizedBox(height: 2),
                      if (c.dots.isEmpty)
                        Text(
                          c.lab,
                          style: BoltText.m(8, weight: 700, color: c.labColor, spacing: labSpacing),
                        )
                      else
                        _dots(c.dots),
                    ],
                  ),
                ),
                if (c.today)
                  Positioned(
                    top: 4,
                    right: 5,
                    child: Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(color: c.todayColor, shape: BoxShape.circle),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Up to four dots; more show three and a count.
Widget _dots(List<SessionStatus> d) {
  final more = d.length > 4;
  return SizedBox(
    height: 10,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (i, s) in d.take(more ? 3 : 4).indexed) ...[
          if (i > 0) const SizedBox(width: 3),
          SessionDot(s, size: 6),
        ],
        if (more) ...[
          const SizedBox(width: 2),
          Text('+${d.length - 3}', style: BoltText.m(8, weight: 700, color: BoltColors.neon, height: 1)),
        ],
      ],
    ),
  );
}

/// A session's status as a small square: done is solid neon, confirmed or
/// moved solid white, waiting outlined neon, a draft dashed, no session an
/// empty outline.
class SessionDot extends StatelessWidget {
  const SessionDot(this.status, {super.key, this.size = 9});

  final SessionStatus? status;
  final double size;

  @override
  Widget build(BuildContext context) {
    final bg = switch (status) {
      SessionStatus.done => BoltColors.neon,
      SessionStatus.approved || SessionStatus.moved => BoltColors.text,
      _ => Colors.transparent,
    };
    final stroke = switch (status) {
      SessionStatus.pending => const Stroke(BoltColors.neon, 1.5),
      SessionStatus.draft => const Stroke.dashed(BoltColors.muted2, 1.5),
      null => const Stroke(BoltColors.line, 1.5),
      _ => Stroke.none,
    };
    return BoltBox(width: size, height: size, borderBox: true, radius: size / 3, color: bg, stroke: stroke);
  }
}

/// The selected day's ring: 2 px outside the cell, like CSS
/// `box-shadow: 0 0 0 2px`, which never paints under the cell itself.
class _RingPainter extends CustomPainter {
  const _RingPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final r = RRect.fromRectAndRadius((Offset.zero & size).inflate(1), const Radius.circular(BoltRadii.cell + 1));
    canvas.drawRRect(
      r,
      Paint()
        ..color = BoltColors.text
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) => false;
}

class LegendItem {
  const LegendItem(this.label, this.bg, this.stroke);

  final String label;
  final Color bg;
  final Stroke stroke;
}

const traineeLegend = [
  LegendItem('Done', BoltColors.neon, Stroke(BoltColors.neon)),
  LegendItem('Confirmed', BoltColors.surface2, Stroke(BoltColors.line)),
  LegendItem('Needs your OK', Colors.transparent, Stroke.dashed(BoltColors.neon, 1.5)),
  LegendItem('Moved', BoltColors.surface2, Stroke(BoltColors.text, 1.5)),
];

const coachLegend = [
  LegendItem('Done', BoltColors.neon, Stroke(BoltColors.neon)),
  LegendItem('Confirmed', BoltColors.surface2, Stroke(BoltColors.line)),
  LegendItem('Waiting', Colors.transparent, Stroke.dashed(BoltColors.neon, 1.5)),
  LegendItem('Moved', BoltColors.surface2, Stroke(BoltColors.text, 1.5)),
  LegendItem('Draft', Colors.transparent, Stroke.dashed(BoltColors.muted2, 1.5)),
];

class Legend extends StatelessWidget {
  const Legend({super.key, required this.items, this.gap = 12});

  final List<LegendItem> items;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: gap,
      runSpacing: gap,
      children: [
        for (final l in items)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              BoltBox(width: 12, height: 12, borderBox: true, radius: 4, color: l.bg, stroke: l.stroke),
              const SizedBox(width: 6),
              Text(l.label, style: BoltText.a(11, color: BoltColors.muted)),
            ],
          ),
      ],
    );
  }
}
