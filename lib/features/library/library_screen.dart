import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../data/bolt_store.dart';
import '../../data/models/template.dart';
import '../../data/seed/splits.dart';
import '../../theme/text_styles.dart';
import '../../theme/tokens.dart';
import '../../widgets/box.dart';
import '../../widgets/common.dart';
import '../../widgets/tap.dart';

class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(boltProvider);
    final store = ref.read(boltProvider.notifier);
    final tpls = d.tpls.values.toList();
    return ScreenScroll(
      children: [
        const Kicker('LIBRARY'),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(child: Text('Workouts', style: BoltText.a(30, weight: 900, width: 112, spacing: -.02))),
            Tap(
              onTap: () => context.push('/editor/tpl/${store.newTemplate()}'),
              child: BoltBox(
                color: BoltColors.neon,
                radius: 12,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                child: Text('+ New', style: BoltText.a(13, weight: 800, color: BoltColors.ink)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Default templates used by auto-fill. Edit once, every future plan follows.',
          style: BoltText.a(13, color: BoltColors.muted),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: Tap(
            onTap: () => context.push('/learn'),
            child: Text(
              'Learn: workout reasoning, form & supplements →',
              style: BoltText.a(13, weight: 700, color: BoltColors.neon),
            ),
          ),
        ),
        const SizedBox(height: 16),
        for (var r = 0; r < tpls.length; r += 2) ...[
          if (r > 0) const SizedBox(height: 8),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _tplCard(context, tpls[r])),
                const SizedBox(width: 8),
                Expanded(child: r + 1 < tpls.length ? _tplCard(context, tpls[r + 1]) : const SizedBox()),
              ],
            ),
          ),
        ],
        const SizedBox(height: 24),
        const SectionTitle('Weekly splits'),
        const SizedBox(height: 10),
        for (final k in kSplitOrder) ...[
          _splitCard(d.tpls, k, d.trainees.where((x) => x.split == k).length),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  Widget _tplCard(BuildContext context, WorkoutTemplate t) {
    return Tap(
      onTap: () => context.push('/editor/tpl/${t.id}'),
      child: BoltBox(
        color: BoltColors.surface1,
        stroke: const Stroke(BoltColors.lineSoft),
        radius: 18,
        padding: const EdgeInsets.all(14),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 112 - 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t.code, style: BoltText.m(10, weight: 700, spacing: .1, color: BoltColors.neon)),
              const SizedBox(height: 6),
              Text(t.name, style: BoltText.a(18, weight: 900)),
              const SizedBox(height: 6),
              Expanded(
                child: Text(t.focus, style: BoltText.a(11, color: BoltColors.muted)),
              ),
              const SizedBox(height: 6),
              Text(
                '${plural(t.ex.length, 'exercise')} · ${t.mins} min'.toUpperCase(),
                style: BoltText.m(9, color: BoltColors.muted2),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _splitCard(Map<String, WorkoutTemplate> tpls, String k, int used) {
    final s = kSplits[k]!;
    final byDay = {for (final d in s.days) d.weekday: d.tpl};
    return BoltBox(
      color: BoltColors.surface1,
      stroke: const Stroke(BoltColors.lineSoft),
      radius: 18,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(child: Text(s.name, style: BoltText.a(14, weight: 800))),
              Text(plural(used, 'trainee').toUpperCase(), style: BoltText.m(9, color: BoltColors.muted)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (final (i, wd) in const [1, 2, 3, 4, 5, 6, 0].indexed) ...[
                if (i > 0) const SizedBox(width: 4),
                Expanded(
                  child: BoltBox(
                    height: 40,
                    radius: 9,
                    color: byDay[wd] != null ? BoltColors.surface2 : Colors.transparent,
                    stroke: byDay[wd] != null
                        ? const Stroke(BoltColors.line)
                        : const Stroke.dashed(BoltColors.lineFaint),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(weekdays[wd][0], style: BoltText.m(8, color: BoltColors.muted3)),
                        const SizedBox(height: 1),
                        Text(
                          byDay[wd] == null ? '' : tpls[byDay[wd]]?.code ?? '',
                          style: BoltText.m(8, weight: 700, color: BoltColors.neon),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
