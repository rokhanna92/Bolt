import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../data/bolt_store.dart';
import '../../data/seed/templates.dart';
import '../../theme/text_styles.dart';
import '../../theme/tokens.dart';
import '../../widgets/box.dart';
import '../../widgets/common.dart';
import '../../widgets/fields.dart';
import '../../widgets/tap.dart';

/// Trainee reports pain, or a coach adds an injury flag.
class InjurySheet extends ConsumerStatefulWidget {
  const InjurySheet({super.key, required this.tid});

  final String tid;

  @override
  ConsumerState<InjurySheet> createState() => _InjurySheetState();
}

class _InjurySheetState extends ConsumerState<InjurySheet> {
  String _area = 'knee';
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = ref.read(boltProvider.notifier);
    final isT = ref.watch(boltProvider).account?.isTrainee ?? false;
    final name = firstName(store.tr(widget.tid).name);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(isT ? 'Report pain or injury' : 'Add injury flag', style: BoltText.a(20, weight: 900)),
        const SizedBox(height: 6),
        Text(
          isT
              ? 'Your coach gets notified. Exercises that load this area get a safer swap.'
              : 'Exercises that load this area will show swap suggestions for $name.',
          style: BoltText.a(13, color: BoltColors.muted, height: 1.45),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final a in kAreas.entries)
              Tap(
                onTap: () => setState(() => _area = a.key),
                child: BoltBox(
                  radius: 99,
                  color: _area == a.key ? BoltColors.warn : BoltColors.surface2,
                  stroke: Stroke(_area == a.key ? BoltColors.warn : BoltColors.line),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  child: Text(
                    a.value,
                    style: BoltText.a(13, weight: 700, color: _area == a.key ? BoltColors.ink : BoltColors.text),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        BoltTextArea(controller: _note, hint: 'What happened, what hurts', minHeight: 76),
        const SizedBox(height: 12),
        NeonButton(
          label: isT ? 'Send to coach' : 'Add flag',
          height: 52,
          color: BoltColors.warn,
          scale: 1,
          onTap: () {
            store.reportInjury(widget.tid, _area, _note.text);
            Navigator.of(context).pop();
          },
        ),
      ],
    );
  }
}
