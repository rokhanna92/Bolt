import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../core/format.dart';
import '../../data/bolt_store.dart';
import '../../data/models/bolt_data.dart';
import '../../theme/text_styles.dart';
import '../../theme/tokens.dart';
import '../../widgets/common.dart';
import '../../widgets/forms.dart';

/// Choose someone's weekly split, or build a new one for them.
class SplitSheet extends ConsumerWidget {
  const SplitSheet({super.key, required this.tid});

  final String tid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(boltProvider);
    final store = ref.read(boltProvider.notifier);
    final t = store.trOrNull(tid);
    if (t == null) return const SizedBox(height: 120);
    final own = tid == Account.ownerId;
    void close() => Navigator.of(context).pop();
    void edit(String id) {
      close();
      rootNavigatorKey.currentContext!.push('/split/$id');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(tx('Weekly split'), style: BoltText.a(20, weight: 900)),
        const SizedBox(height: 4),
        Text(
          own
              ? tx('How your week is laid out. Auto-fill and tapping an empty day follow it.')
              : tx('How {name}\'s week is laid out. Auto-fill and tapping an empty day follow it.', {
                  'name': firstName(t.name),
                }),
          style: BoltText.a(13, color: BoltColors.muted, height: 1.45),
        ),
        const SizedBox(height: 14),
        OutlineButton(
          label: tx('+ Build your own split'),
          height: 48,
          radius: 14,
          onTap: () {
            final id = store.newSplit();
            store.setSplit(tid, id);
            edit(id);
          },
        ),
        const SizedBox(height: 12),
        SplitPicker(
          selected: t.split,
          data: d,
          onSelect: (k) {
            store.setSplit(tid, k);
            close();
          },
          onEdit: edit,
        ),
      ],
    );
  }
}
