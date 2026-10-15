import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/actions.dart';
import '../../app/share.dart';
import '../../core/format.dart';
import '../../data/bolt_store.dart';
import '../../data/seed/splits.dart';
import '../../theme/text_styles.dart';
import '../../theme/tokens.dart';
import '../../widgets/box.dart';
import '../../widgets/common.dart';
import '../../widgets/tap.dart';

/// Builds a custom weekly split: a workout or a rest day for each weekday.
class SplitEditorScreen extends ConsumerStatefulWidget {
  const SplitEditorScreen({super.key, required this.id});

  final String id;

  @override
  ConsumerState<SplitEditorScreen> createState() => _SplitEditorScreenState();
}

class _SplitEditorScreenState extends ConsumerState<SplitEditorScreen> {
  late final TextEditingController _name = TextEditingController(
    text: ref.read(boltProvider).splits[widget.id]?.name ?? '',
  );

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _delete(String name) async {
    final ok = await confirmSheet(
      context,
      title: 'Delete $name?',
      body: 'Planned days stay. Anyone on this split goes back to Push / Pull / Legs.',
      confirm: 'Delete',
    );
    if (ok && mounted) {
      context.pop();
      ref.read(boltProvider.notifier).deleteSplit(widget.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(boltProvider);
    final store = ref.read(boltProvider.notifier);
    final x = d.splits[widget.id];
    if (x == null) return const BoltPage(child: SizedBox.expand());
    final insets = MediaQuery.paddingOf(context);
    final training = x.days.length;

    return BoltPage(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, insets.top + 16, 20, 60 + insets.bottom),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                BackBox(onTap: () => context.pop()),
                const SizedBox(width: 12),
                const Kicker('YOUR SPLIT'),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _name,
              onChanged: (v) => store.renameSplit(x.id, v),
              textCapitalization: TextCapitalization.words,
              style: BoltText.a(30, weight: 900, width: 112, color: BoltColors.neon),
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.fromLTRB(0, 4, 0, 8),
                border: UnderlineInputBorder(borderSide: BorderSide(color: BoltColors.line, width: 1.5)),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: BoltColors.line, width: 1.5)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: BoltColors.line, width: 1.5)),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${plural(training, 'training day')} · ${plural(7 - training, 'rest day')}. Tap a day to set its workout. '
              'Want a workout that is not listed? Build one from muscles and save it to the Library.',
              style: BoltText.a(13, color: BoltColors.muted, height: 1.45),
            ),
            const SizedBox(height: 16),
            for (final wd in kWeekOrder) ...[
              _day(wd, d.tpls[x.days[wd]]?.name, d.tpls[x.days[wd]]?.code, d.tpls[x.days[wd]]?.focus),
              const SizedBox(height: 6),
            ],
            const SizedBox(height: 16),
            NeonButton(label: 'Done', height: 52, scale: 1, onTap: () => context.pop()),
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerLeft,
              child: Tap(
                onTap: () => _delete(x.name),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Text('Delete split', style: BoltText.a(13, weight: 700, color: BoltColors.warn)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _day(int wd, String? name, String? code, String? focus) {
    final rest = name == null;
    final day = weekdays[wd % 7];
    return Tap(
      onTap: () => pickSplitDay(widget.id, wd),
      scale: .98,
      child: BoltBox(
        color: rest ? Colors.transparent : BoltColors.surface1,
        stroke: rest ? const Stroke.dashed(BoltColors.line) : const Stroke(BoltColors.lineSoft),
        radius: 14,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            SizedBox(width: 44, child: Text(day.toUpperCase(), style: BoltText.m(11, weight: 700))),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    rest ? 'Rest' : name,
                    style: BoltText.a(15, weight: 800, color: rest ? BoltColors.muted : BoltColors.text),
                  ),
                  if (focus != null) ...[
                    const SizedBox(height: 2),
                    Text(focus, style: BoltText.a(12, color: BoltColors.muted)),
                  ],
                ],
              ),
            ),
            if (code != null) ...[
              Text(code, style: BoltText.m(10, weight: 700, color: BoltColors.neon)),
              const SizedBox(width: 8),
            ],
            const Chevron(size: 16),
          ],
        ),
      ),
    );
  }
}
