import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../data/bolt_store.dart';
import '../../data/models/bolt_data.dart';
import '../../theme/text_styles.dart';
import '../../theme/tokens.dart';
import '../../widgets/box.dart';
import '../../widgets/common.dart';
import '../../widgets/forms.dart';

/// Switches what the app shows: a coach between coaching and training solo,
/// the admin between all three roles. Nothing for everyone else.
class RoleSwitch extends ConsumerWidget {
  const RoleSwitch({super.key});

  static const _labels = {'coach': 'Coach', 'trainee': 'Trainee', 'solo': 'Solo'};

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final a = ref.watch(boltProvider).account;
    final roles = ref.read(boltProvider.notifier).switchRoles;
    if (a == null || roles.length < 2) return const SizedBox.shrink();
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
            Kicker(a.admin ? tx('ADMIN · VIEW AS') : tx('MODE'), size: 10),
            const SizedBox(height: 4),
            Text(
              a.admin
                  ? tx('Your data stays; only the screens change.')
                  : tx('Coach for your trainees, Solo for your own training.'),
              style: BoltText.a(12, color: BoltColors.muted),
            ),
            const SizedBox(height: 12),
            ChoiceChips(
              options: [for (final r in roles) r.name],
              labels: _labels,
              selected: a.role.name,
              onSelect: (r) => ref.read(boltProvider.notifier).switchRole(Role.values.byName(r)),
            ),
          ],
        ),
      ),
    );
  }
}
