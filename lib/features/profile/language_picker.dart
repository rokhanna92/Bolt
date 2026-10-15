import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/bolt_store.dart';
import '../../l10n/l10n.dart';
import '../../theme/text_styles.dart';
import '../../theme/tokens.dart';
import '../../widgets/box.dart';
import '../../widgets/common.dart';
import '../../widgets/tap.dart';

/// English, Serbian Latin or Serbian Cyrillic. Each option is written in
/// its own language so it can be found whatever is on show.
class LanguagePicker extends ConsumerWidget {
  const LanguagePicker({super.key, this.compact = false});

  /// One row of short codes, for the welcome screen.
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cur = AppLang.byName(ref.watch(boltProvider.select((d) => d.settings.lang)));
    final store = ref.read(boltProvider.notifier);
    if (compact) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final l in AppLang.values) ...[
            if (l.index > 0) const SizedBox(width: 6),
            Tap(
              onTap: () => store.setLanguage(l),
              child: BoltBox(
                radius: 99,
                color: l == cur ? BoltColors.neon : null,
                stroke: Stroke(l == cur ? BoltColors.neon : BoltColors.line),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                child: Text(
                  l.short,
                  style: BoltText.m(11, weight: 700, color: l == cur ? BoltColors.ink : BoltColors.text),
                ),
              ),
            ),
          ],
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Kicker('${tx('LANGUAGE')}${isSerbian ? ' · LANGUAGE' : ' · JEZIK'}', size: 10),
        const SizedBox(height: 8),
        for (final l in AppLang.values) ...[
          Tap(
            onTap: () => store.setLanguage(l),
            child: BoltBox(
              color: BoltColors.surface1,
              stroke: Stroke(l == cur ? BoltColors.neon : BoltColors.lineSoft, l == cur ? 1.5 : 1),
              radius: 14,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Expanded(child: Text(l.label, style: BoltText.a(14, weight: 800))),
                  if (l == cur) Text('✓', style: BoltText.a(14, weight: 800, color: BoltColors.neon)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
        ],
      ],
    );
  }
}
