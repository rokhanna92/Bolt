import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../data/bolt_store.dart';
import '../../data/models/template.dart';
import '../../data/seed/templates.dart';
import '../../theme/text_styles.dart';
import '../../theme/tokens.dart';
import '../../widgets/box.dart';
import '../../widgets/common.dart';
import '../../widgets/tap.dart';

/// Picker results besides a template id.
abstract final class PickResult {
  /// Open the muscle builder instead.
  static const muscles = '__muscles';

  /// A rest day (split editor only).
  static const rest = '__rest';
}

/// Every workout, grouped by style, with the muscle builder on top. Pops
/// with a template id or a [PickResult].
class WorkoutPickerSheet extends ConsumerWidget {
  const WorkoutPickerSheet({super.key, this.selected, this.muscles = true, this.rest = false});

  /// Current template id, highlighted.
  final String? selected;

  /// Offer "Build from muscles".
  final bool muscles;

  /// Offer a rest day.
  final bool rest;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tpls = ref.watch(boltProvider).tpls;
    void pick(String v) => Navigator.of(context).pop(v);
    final own = [
      for (final t in tpls.values)
        if (isOwnTemplate(t)) t.id,
    ];
    final groups = [
      if (own.isNotEmpty) (tx('Your workouts'), own),
      for (final (title, ids) in kTemplateGroups)
        (
          title,
          [
            for (final id in ids)
              if (tpls[id] != null && !own.contains(id)) id,
          ],
        ),
      (
        tx('Your other workouts'),
        [
          for (final t in tpls.values)
            if (t.custom && t.hidden) t.id,
        ],
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(tx('Pick a workout'), style: BoltText.a(20, weight: 900)),
        const SizedBox(height: 4),
        Text(
          tx('Train your way: classic splits, old school bodybuilding days, or build one from the muscles you want.'),
          style: BoltText.a(13, color: BoltColors.muted, height: 1.45),
        ),
        const SizedBox(height: 14),
        if (muscles) ...[
          Tap(
            onTap: () => pick(PickResult.muscles),
            child: BoltBox(
              radius: 16,
              color: BoltColors.neon,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(tx('Build from muscles'), style: BoltText.a(16, weight: 900, color: BoltColors.ink)),
                        const SizedBox(height: 2),
                        Text(
                          tx('Pick chest + triceps, biceps + shoulders, anything'),
                          style: BoltText.a(12, weight: 600, color: BoltColors.ink.withValues(alpha: .75)),
                        ),
                      ],
                    ),
                  ),
                  Text('›', style: BoltText.a(24, weight: 900, color: BoltColors.ink)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
        if (rest) ...[
          _Row(
            code: tx('REST'),
            name: tx('Rest day'),
            focus: tx('Recover, eat, sleep. Muscles grow between sessions.'),
            meta: '',
            on: selected == null,
            onTap: () => pick(PickResult.rest),
          ),
          const SizedBox(height: 6),
        ],
        for (final (title, ids) in groups)
          if (ids.isNotEmpty) ...[
            const SizedBox(height: 10),
            Kicker(tx(title).toUpperCase(), size: 10, spacing: .1),
            const SizedBox(height: 8),
            for (final id in ids) ...[_tplRow(tpls[id]!, selected == id, () => pick(id)), const SizedBox(height: 6)],
          ],
      ],
    );
  }

  Widget _tplRow(WorkoutTemplate t, bool on, VoidCallback onTap) => _Row(
    code: t.code,
    name: tx(t.name),
    focus: tx(t.focus),
    meta: '${plural(t.ex.length, 'exercise')} · ${t.mins} min'.toUpperCase(),
    on: on,
    onTap: onTap,
  );
}

class _Row extends StatelessWidget {
  const _Row({
    required this.code,
    required this.name,
    required this.focus,
    required this.meta,
    required this.on,
    required this.onTap,
  });

  final String code;
  final String name;
  final String focus;
  final String meta;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tap(
      onTap: onTap,
      scale: .98,
      child: BoltBox(
        color: BoltColors.surface1,
        stroke: Stroke(on ? BoltColors.neon : BoltColors.lineSoft, on ? 1.5 : 1),
        radius: 14,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(
          children: [
            SizedBox(
              width: 44,
              child: Text(code, style: BoltText.m(10, weight: 700, spacing: .06, color: BoltColors.neon)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: BoltText.a(15, weight: 800)),
                  const SizedBox(height: 2),
                  Text(focus, style: BoltText.a(12, color: BoltColors.muted)),
                  if (meta.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(meta, style: BoltText.m(9, color: BoltColors.muted2)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Opens the workout picker for a planned day.
class ChangeWorkoutButton extends StatelessWidget {
  const ChangeWorkoutButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tap(
      onTap: onTap,
      scale: .98,
      child: BoltBox(
        radius: 14,
        stroke: const Stroke(BoltColors.neon, 1.5),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tx('Change workout'), style: BoltText.a(14, weight: 800, color: BoltColors.neon)),
                  const SizedBox(height: 2),
                  Text(
                    tx('Any style, or build it from the muscles you want'),
                    style: BoltText.a(12, color: BoltColors.muted),
                  ),
                ],
              ),
            ),
            Text('›', style: BoltText.a(22, weight: 900, color: BoltColors.neon)),
          ],
        ),
      ),
    );
  }
}
