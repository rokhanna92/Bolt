import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/tick.dart';
import '../../core/format.dart';
import '../../data/bolt_store.dart';
import '../../data/models/people.dart';
import '../../data/models/session.dart';
import '../../data/seed/splits.dart';
import '../../data/seed/templates.dart';
import '../../theme/text_styles.dart';
import '../../theme/tokens.dart';
import '../../widgets/box.dart';
import '../../widgets/common.dart';
import '../../widgets/tap.dart';

class _Attention {
  const _Attention(this.text, this.sub, this.act, this.dot, this.onAct);

  final String text;
  final String sub;
  final String act;
  final Color dot;
  final VoidCallback onAct;
}

class RosterScreen extends ConsumerWidget {
  const RosterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(boltProvider);
    final store = ref.read(boltProvider.notifier);
    final c = store.co(d.account?.id ?? '');
    final today = store.today;
    final my = d.trainees.where((x) => x.coach == c.id).toList();
    void open(String tid) => context.push('/trainee/$tid');

    final att = <_Attention>[];
    for (final x in my) {
      final p = store.plan(x.id);
      final ks = p.keys.toList()..sort();
      final fn = firstName(x.name);
      for (final k in ks) {
        final s = p[k]!;
        if (s.status == SessionStatus.moved) {
          att.add(
            _Attention(
              '$fn moved ${s.title}',
              '${fmtDay(s.from ?? k)} → ${fmtDay(k)}',
              'OK',
              BoltColors.text,
              () => store.ack(x.id, k),
            ),
          );
        }
      }
      for (final i in x.injuries.where((i) => i.fresh)) {
        att.add(
          _Attention('$fn reported ${kAreas[i.area]!.toLowerCase()} pain', i.note, 'Review', BoltColors.warn, () {
            store.markInjuriesSeen(x.id);
            open(x.id);
          }),
        );
      }
      final pn = ks.where((k) => p[k]!.status == SessionStatus.pending).length;
      if (pn > 0) {
        att.add(
          _Attention(
            '$fn hasn’t confirmed ${plural(pn, 'session')}',
            'Sent for approval',
            'Nudge',
            BoltColors.neon,
            () => store.nudge(x.id),
          ),
        );
      }
      if (!ks.any((k) => k.compareTo(today) >= 0 && p[k]!.status != SessionStatus.draft)) {
        att.add(
          _Attention(
            '$fn has nothing planned',
            'Auto-fill from ${kSplits[x.split]!.name}',
            'Plan',
            BoltColors.muted2,
            () => open(x.id),
          ),
        );
      }
    }

    return ScreenScroll(
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Kicker(c.role.toUpperCase()),
                  const SizedBox(height: 4),
                  Text('Coach ${firstName(c.name)}', style: BoltText.a(26, weight: 800, spacing: -.02, height: 1.2)),
                ],
              ),
            ),
            Avatar(ini: initials(c.name), fill: BoltColors.neon, weight: 900),
          ],
        ),
        const SizedBox(height: 18),
        _LiveCard(trainees: my),
        if (att.isNotEmpty) ...[
          const SizedBox(height: 22),
          const SectionTitle('Needs you'),
          const SizedBox(height: 10),
          for (final a in att) ...[_AttentionRow(a: a), const SizedBox(height: 8)],
        ],
        const SizedBox(height: 24),
        Kicker('TRAINEES · ${my.length}'),
        const SizedBox(height: 10),
        for (final x in my) ...[_TraineeCard(x: x, onOpen: () => open(x.id)), const SizedBox(height: 8)],
        if (my.isEmpty)
          BoltBox(
            radius: 14,
            stroke: const Stroke.dashed(BoltColors.line),
            padding: const EdgeInsets.all(14),
            child: Text('No trainees assigned yet.', style: BoltText.a(13, color: BoltColors.muted)),
          ),
      ],
    );
  }
}

class _LiveCard extends ConsumerWidget {
  const _LiveCard({required this.trainees});

  final List<Trainee> trainees;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(boltProvider);
    final live = trainees.where((x) => d.gymIn[x.id] != null).toList();
    final now = live.isEmpty ? DateTime.now() : watchNow(ref);
    return BoltBox(
      color: BoltColors.surface1,
      stroke: const Stroke(BoltColors.lineSoft),
      radius: 20,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const PulseDot(size: 8),
              const SizedBox(width: 8),
              Kicker('IN THE GYM NOW · ${live.length}', size: 10),
            ],
          ),
          const SizedBox(height: 12),
          if (live.isEmpty)
            Text('Nobody checked in right now.', style: BoltText.a(13, color: BoltColors.muted))
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (var i = 0; i < live.length; i++) ...[
                    if (i > 0) const SizedBox(width: 14),
                    ConstrainedBox(
                      constraints: const BoxConstraints(minWidth: 64),
                      child: Column(
                        children: [
                          Avatar(
                            ini: initials(live[i].name),
                            size: 48,
                            ring: BoltColors.neon,
                            ringWidth: 2,
                            color: BoltColors.neon,
                          ),
                          const SizedBox(height: 4),
                          Text(firstName(live[i].name), style: BoltText.a(12, weight: 700)),
                          const SizedBox(height: 4),
                          Text(
                            dur(d.gymIn[live[i].id]!.elapsedMinutes(now)),
                            style: BoltText.m(10, color: BoltColors.neon),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _AttentionRow extends StatelessWidget {
  const _AttentionRow({required this.a});

  final _Attention a;

  @override
  Widget build(BuildContext context) {
    return BoltBox(
      color: BoltColors.surface1,
      stroke: const Stroke(BoltColors.lineSoft),
      radius: 16,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: a.dot, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(a.text, style: BoltText.a(14, weight: 700)),
                const SizedBox(height: 2),
                Text(
                  a.sub,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: BoltText.a(12, color: BoltColors.muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Tap(
            onTap: a.onAct,
            child: BoltBox(
              radius: 10,
              stroke: const Stroke(BoltColors.neon),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Text(a.act, style: BoltText.a(12, weight: 800, color: BoltColors.neon)),
            ),
          ),
        ],
      ),
    );
  }
}

class _TraineeCard extends ConsumerWidget {
  const _TraineeCard({required this.x, required this.onOpen});

  final Trainee x;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(boltProvider);
    final store = ref.read(boltProvider.notifier);
    final p = store.plan(x.id);
    final mon = weekStart(store.now, mondayFirst: d.settings.mondayFirst);
    final w7 = [for (var i = 0; i < 7; i++) p[dk(addDays(mon, i))]];
    final planned = w7.whereType<Session>().toList();
    final inGym = d.gymIn[x.id] != null;
    return Tap(
      onTap: onOpen,
      scale: .98,
      child: BoltBox(
        color: BoltColors.surface1,
        stroke: const Stroke(BoltColors.lineSoft),
        radius: 18,
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Avatar(ini: initials(x.name), size: 46, ring: inGym ? BoltColors.neon : BoltColors.line, ringWidth: 2),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(child: Text(x.name, style: BoltText.a(15, weight: 800))),
                      if (x.injuries.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        BoltBox(
                          color: const Color(0x26FF7A45),
                          radius: 6,
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          child: Text(
                            kAreas[x.injuries.first.area]!.toUpperCase(),
                            style: BoltText.m(9, weight: 700, color: BoltColors.warn),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text('${x.goal} · ${kSplits[x.split]!.short}', style: BoltText.a(12, color: BoltColors.muted)),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      for (final s in w7) ...[_dot(s?.status), const SizedBox(width: 4)],
                      const SizedBox(width: 6),
                      Text(
                        '${planned.where((s) => s.status == SessionStatus.done).length}/${planned.length} THIS WEEK',
                        style: BoltText.m(9, color: BoltColors.muted),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            const Chevron(),
          ],
        ),
      ),
    );
  }

  Widget _dot(SessionStatus? s) {
    final bg = switch (s) {
      SessionStatus.done => BoltColors.neon,
      SessionStatus.approved || SessionStatus.moved => BoltColors.text,
      _ => Colors.transparent,
    };
    final stroke = switch (s) {
      SessionStatus.pending => const Stroke(BoltColors.neon, 1.5),
      SessionStatus.draft => const Stroke.dashed(BoltColors.muted2, 1.5),
      null => const Stroke(BoltColors.line, 1.5),
      _ => Stroke.none,
    };
    return BoltBox(width: 9, height: 9, radius: 3, color: bg, stroke: stroke);
  }
}
