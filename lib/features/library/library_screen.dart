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
import '../../services/haptics.dart';
import '../../theme/text_styles.dart';
import '../../theme/tokens.dart';
import '../../widgets/bolt_sheet.dart';
import '../../widgets/box.dart';
import '../../widgets/common.dart';
import '../../widgets/forms.dart';
import '../../widgets/tap.dart';
import '../sharing/import_sheet.dart';
import '../workouts/workout_picker.dart';

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
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlineButton(
                label: tx('Send workouts'),
                height: 44,
                radius: 12,
                fontSize: 13,
                onTap: () => showBoltSheet<void>(context, (_) => const SendWorkoutsSheet()),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlineButton(
                label: tx('Import workouts'),
                height: 44,
                radius: 12,
                fontSize: 13,
                onTap: () => showBoltSheet<void>(context, (_) => const ImportSheet(workouts: true)),
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
              tx('Atlas: styles, muscles, form & supplements →'),
              style: BoltText.a(13, weight: 700, color: BoltColors.neon),
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Everything at a glance: categories shut, the first one open.
        for (final (i, (title, ids)) in groups.where((g) => g.$2.isNotEmpty).indexed) ...[
          if (i > 0) const SizedBox(height: 8),
          _Category(
            key: ValueKey(title),
            title: tx(title),
            preview: [for (final id in ids) tx(d.tpls[id]!.name)],
            initiallyOpen: i == 0,
            children: [
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
          ),
        ],
        const SizedBox(height: 8),
        _Category(
          key: const ValueKey('splits'),
          title: tx('Weekly splits'),
          preview: [for (final k in splitIds(d)) tx(splitOf(d, k).name)],
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: Tap(
                onTap: () => context.push('/split/${store.newSplit()}'),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(tx('+ Build a split'), style: BoltText.a(13, weight: 800, color: BoltColors.neon)),
                ),
              ),
            ),
            const SizedBox(height: 6),
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
        ),
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
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(14),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 112 - 30),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: 14,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(t.code, style: BoltText.m(10, weight: 700, spacing: .1, color: BoltColors.neon)),
                      ),
                    ),
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
            ),
            // Takes it off Your workouts. The glyph is 38 tall with its tap
            // padding, so top 2 centres the X on the code row (14 + 7 - 19).
            if (onRemove != null)
              Positioned(
                top: 2,
                right: 2,
                child: Tap(onTap: onRemove, child: const CloseGlyph()),
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

/// A category that opens to show its cards. Shut, it still names what is
/// inside, so the whole library fits on a screen or two.
class _Category extends StatefulWidget {
  const _Category({
    super.key,
    required this.title,
    required this.preview,
    required this.children,
    this.initiallyOpen = false,
  });

  final String title;
  final List<String> preview;
  final List<Widget> children;
  final bool initiallyOpen;

  @override
  State<_Category> createState() => _CategoryState();
}

class _CategoryState extends State<_Category> {
  late bool _open = widget.initiallyOpen;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          button: true,
          expanded: _open,
          child: Tap(
            onTap: () {
              Haptics.play(Feel.tick);
              setState(() => _open = !_open);
            },
            child: BoltBox(
              color: BoltColors.surface1,
              stroke: Stroke(_open ? BoltColors.line : BoltColors.lineSoft),
              radius: 16,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.title, style: BoltText.a(16, weight: 800)),
                        // Open, the cards below say it already.
                        if (!_open) ...[
                          const SizedBox(height: 2),
                          Text(
                            widget.preview.join(' · '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: BoltText.a(12, color: BoltColors.muted),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text('${widget.preview.length}', style: BoltText.m(12, weight: 700, color: BoltColors.neon)),
                  const SizedBox(width: 4),
                  AnimatedRotation(
                    turns: _open ? .25 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: const Chevron(size: 18),
                  ),
                ],
              ),
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          alignment: Alignment.topCenter,
          child: _open
              ? Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 4),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: widget.children),
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}
