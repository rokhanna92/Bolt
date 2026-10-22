import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/actions.dart';
import '../../core/format.dart';
import '../../data/bolt_store.dart';
import '../../data/models/bolt_data.dart';
import '../../data/models/template.dart';
import '../../data/seed/splits.dart';
import '../../data/seed/templates.dart';
import '../../theme/text_styles.dart';
import '../../theme/tokens.dart';
import '../../widgets/box.dart';
import '../../widgets/common.dart';
import '../../widgets/forms.dart';
import '../../widgets/tap.dart';

class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(boltProvider);
    final store = ref.read(boltProvider.notifier);
    final coach = d.account?.isCoach ?? false;
    final own = [
      for (final t in d.tpls.values)
        if (isOwnTemplate(t)) t.id,
    ];
    final groups = [
      (tx('Your workouts'), own),
      for (final (title, ids) in kTemplateGroups)
        (
          title,
          [
            for (final id in ids)
              if (d.tpls[id] != null && !own.contains(id)) id,
          ],
        ),
      (
        tx('Your other workouts'),
        [
          for (final t in d.tpls.values)
            if (t.custom && t.hidden) t.id,
        ],
      ),
    ];
    return ScreenScroll(
      children: [
        Kicker(tx('LIBRARY')),
        const SizedBox(height: 4),
        Text(tx('Workouts'), style: BoltText.a(30, weight: 900, width: 112, spacing: -.02)),
        const SizedBox(height: 6),
        Text(
          tx('Templates used by auto-fill and splits. Edit once, every future plan follows.'),
          style: BoltText.a(13, color: BoltColors.muted),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: NeonButton(
                label: tx('+ From muscles'),
                height: 44,
                radius: 12,
                fontSize: 13,
                onTap: newTemplateFromMuscles,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlineButton(
                label: tx('+ Empty'),
                height: 44,
                radius: 12,
                fontSize: 13,
                onTap: () => context.push('/editor/tpl/${store.newTemplate()}'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: Tap(
            onTap: () => context.push('/guide'),
            child: Text(
              tx('Learn: styles, muscles, form & supplements →'),
              style: BoltText.a(13, weight: 700, color: BoltColors.neon),
            ),
          ),
        ),
        for (final (title, ids) in groups)
          if (ids.isNotEmpty) ...[
            const SizedBox(height: 20),
            Kicker(tx(title).toUpperCase(), size: 10, spacing: .1),
            const SizedBox(height: 8),
            for (var r = 0; r < ids.length; r += 2) ...[
              if (r > 0) const SizedBox(height: 8),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final i in [r, r + 1]) ...[
                      if (i > r) const SizedBox(width: 8),
                      Expanded(
                        child: i < ids.length
                            ? _tplCard(
                                context,
                                d.tpls[ids[i]]!,
                                onRemove: identical(ids, own) ? () => store.hideTemplate(ids[i]) : null,
                              )
                            : const SizedBox(),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(child: SectionTitle(tx('Weekly splits'))),
            Tap(
              onTap: () => context.push('/split/${store.newSplit()}'),
              child: Text(tx('+ Build a split'), style: BoltText.a(13, weight: 800, color: BoltColors.neon)),
            ),
          ],
        ),
        const SizedBox(height: 10),
        for (final k in splitIds(d)) ...[
          _splitCard(
            context,
            d,
            k,
            coach
                ? plural(d.trainees.where((x) => x.split == k).length, 'trainee').toUpperCase()
                : (store.trOrNull(Account.ownerId)?.split == k ? tx('YOUR SPLIT') : ''),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  Widget _tplCard(BuildContext context, WorkoutTemplate t, {VoidCallback? onRemove}) {
    return Tap(
      onTap: () => context.push('/editor/tpl/${t.id}'),
      child: BoltBox(
        color: BoltColors.surface1,
        stroke: const Stroke(BoltColors.lineSoft),
        radius: 18,
        padding: const EdgeInsets.all(14),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 112 - 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t.code, style: BoltText.m(10, weight: 700, spacing: .1, color: BoltColors.neon)),
                  const SizedBox(height: 6),
                  Text(tx(t.name), style: BoltText.a(18, weight: 900)),
                  const SizedBox(height: 6),
                  Expanded(
                    child: Text(tx(t.focus), style: BoltText.a(11, color: BoltColors.muted)),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${plural(t.ex.length, 'exercise')} · ${t.mins} min'.toUpperCase(),
                    style: BoltText.m(10, color: BoltColors.muted2),
                  ),
                ],
              ),
            ),
            // Takes it off Your workouts, in the corner so the card keeps
            // the size of the others.
            if (onRemove != null)
              Positioned(
                top: -4,
                right: -4,
                child: Tap(
                  onTap: onRemove,
                  child: SizedBox(
                    width: 32,
                    height: 28,
                    child: Align(
                      alignment: Alignment.topRight,
                      child: Text('✕', style: BoltText.a(13, color: BoltColors.muted2, height: 1)),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _splitCard(BuildContext context, BoltData d, String k, String used) {
    final custom = d.splits.containsKey(k);
    return Tap(
      onTap: custom ? () => context.push('/split/$k') : null,
      child: BoltBox(
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
                Expanded(child: Text(tx(splitOf(d, k).name), style: BoltText.a(14, weight: 800))),
                Text(used, style: BoltText.m(10, color: BoltColors.muted)),
                if (custom) ...[
                  const SizedBox(width: 8),
                  Text(tx('Edit'), style: BoltText.a(12, weight: 800, color: BoltColors.neon)),
                ],
              ],
            ),
            const SizedBox(height: 10),
            SplitWeek(split: splitOf(d, k), tpls: d.tpls),
          ],
        ),
      ),
    );
  }
}
