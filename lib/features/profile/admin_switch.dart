import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/bolt_store.dart';
import '../../data/models/bolt_data.dart';
import '../../theme/text_styles.dart';
import '../../theme/tokens.dart';
import '../../widgets/box.dart';
import '../../widgets/common.dart';
import '../../widgets/forms.dart';

/// Admin only: shows the app as a coach, trainee or solo user. Nothing for
/// everyone else.
class AdminSwitch extends ConsumerWidget {
  const AdminSwitch({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final a = ref.watch(boltProvider.select((d) => d.account));
    if (a == null || !a.admin) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: BoltBox(
        color: BoltColors.surface1,
        stroke: const Stroke(BoltColors.lineSoft),
        radius: 16,
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Kicker('ADMIN · VIEW AS', size: 10),
            const SizedBox(height: 4),
            Text('Your data stays; only the screens change.', style: BoltText.a(12, color: BoltColors.muted)),
            const SizedBox(height: 12),
            ChoiceChips(
              options: const ['coach', 'trainee', 'solo'],
              labels: const {'coach': 'Coach', 'trainee': 'Trainee', 'solo': 'Solo'},
              selected: a.role.name,
              onSelect: (r) => ref.read(boltProvider.notifier).switchRole(Role.values.byName(r)),
            ),
          ],
        ),
      ),
    );
  }
}
