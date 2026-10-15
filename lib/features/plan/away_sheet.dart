import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../data/bolt_store.dart';
import '../../theme/text_styles.dart';
import '../../theme/tokens.dart';
import '../../widgets/common.dart';
import '../../widgets/forms.dart';
import '../../widgets/tap.dart';

/// Mark weeks away (holiday, sick, busy): the streak survives them and
/// session reminders stay quiet.
class AwaySheet extends ConsumerStatefulWidget {
  const AwaySheet({super.key});

  @override
  ConsumerState<AwaySheet> createState() => _AwaySheetState();
}

class _AwaySheetState extends ConsumerState<AwaySheet> {
  String _start = '0';
  String _weeks = '1';

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(boltProvider);
    final store = ref.read(boltProvider.notifier);
    final t = store.trOrNull(d.account?.id ?? '');
    if (t == null) return const SizedBox.shrink();
    final thisWeek = dk(store.mon0);
    final upcoming = t.stats.away.where((k) => k.compareTo(thisWeek) >= 0).toList()..sort();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(tx('Going away'), style: BoltText.a(20, weight: 900)),
        const SizedBox(height: 4),
        Text(
          tx('Holiday, sick or a busy stretch: away weeks never break your streak and session reminders stay quiet.'),
          style: BoltText.a(13, color: BoltColors.muted, height: 1.45),
        ),
        FieldLabel(tx('FROM')),
        ChoiceChips(
          options: const ['0', '1'],
          labels: const {'0': 'This week', '1': 'Next week'},
          selected: _start,
          onSelect: (s) => setState(() => _start = s),
        ),
        FieldLabel(tx('FOR')),
        ChoiceChips(
          options: const ['1', '2', '3', '4'],
          labels: {
            for (final w in const ['1', '2', '3', '4']) w: plural(int.parse(w), 'week'),
          },
          selected: _weeks,
          onSelect: (w) => setState(() => _weeks = w),
        ),
        const SizedBox(height: 18),
        NeonButton(
          label: tx('Mark away'),
          height: 52,
          scale: 1,
          onTap: () {
            final from = addDays(store.mon0, 7 * int.parse(_start));
            if (!t.stats.away.contains(dk(from))) store.toggleAway(from, int.parse(_weeks));
            Navigator.of(context).pop();
          },
        ),
        if (upcoming.isNotEmpty) ...[
          FieldLabel(tx('AWAY')),
          for (final k in upcoming)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: BoltColors.divider)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      tx('{from} to {to}', {'from': fmtDay(k), 'to': fmtDay(dk(addDays(pk(k), 6)))}),
                      style: BoltText.a(14, weight: 600),
                    ),
                  ),
                  Tap(
                    onTap: () => store.toggleAway(pk(k), 1),
                    child: Text(tx('Clear'), style: BoltText.a(13, weight: 800, color: BoltColors.warn)),
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }
}
