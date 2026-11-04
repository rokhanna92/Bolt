import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../data/bolt_store.dart';
import '../../services/haptics.dart';
import '../../theme/text_styles.dart';
import '../../theme/tokens.dart';
import '../../widgets/box.dart';
import '../../widgets/common.dart';
import '../../widgets/fields.dart';
import '../../widgets/tap.dart';

/// The owner's list of keys, to hand them out and cross them off. Bolt's source
/// and releases are public, so the keys themselves are never in the app: the
/// owner pastes them in once and they stay on this phone.
class AddUserScreen extends ConsumerStatefulWidget {
  const AddUserScreen({super.key});

  @override
  ConsumerState<AddUserScreen> createState() => _AddUserScreenState();
}

class _AddUserScreenState extends ConsumerState<AddUserScreen> {
  final _paste = TextEditingController();

  @override
  void dispose() {
    _paste.dispose();
    super.dispose();
  }

  void _save() {
    final store = ref.read(boltProvider.notifier);
    final added = store.addOwnKeys(_paste.text);
    Haptics.play(added > 0 ? Feel.success : Feel.error);
    if (added > 0) _paste.clear();
    store.toast(
      added > 0 ? tx('{n} keys saved on this phone', {'n': added}) : tx('No keys from your list in that text'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(boltProvider).settings;
    final store = ref.read(boltProvider.notifier);
    final insets = MediaQuery.paddingOf(context);
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
                Text(tx('Add a user'), style: BoltText.a(24, weight: 900)),
              ],
            ),
            for (final kind in const ['Solo', 'Trainee', 'Coach'])
              if (s.ownKeys.keys.where((n) => n.startsWith('$kind ')).toList() case final names
                  when names.isNotEmpty) ...[
                const SizedBox(height: 22),
                Kicker(
                  tx('{kind} · {used} of {all} given', {
                    'kind': tx(kind).toUpperCase(),
                    'used': names.where(s.usedKeys.contains).length,
                    'all': names.length,
                  }),
                ),
                const SizedBox(height: 8),
                for (final n in names)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: _KeyRow(
                      name: n,
                      value: s.ownKeys[n]!,
                      used: s.usedKeys.contains(n),
                      onTap: () {
                        Haptics.play(Feel.tick);
                        store.toggleKeyUsed(n);
                      },
                    ),
                  ),
              ],
            if (s.ownKeys.length < 30) ...[
              const SizedBox(height: 22),
              Text(
                tx(
                  'Your keys are not inside Bolt, because its code is public. Paste your list once and it stays on this phone only.',
                ),
                style: BoltText.a(13, color: BoltColors.muted, height: 1.45),
              ),
              const SizedBox(height: 10),
              BoltField(controller: _paste, hint: tx('Paste your keys')),
              const SizedBox(height: 10),
              NeonButton(label: tx('Save keys'), onTap: _save),
            ],
          ],
        ),
      ),
    );
  }
}

/// One key. The bolt marks it given: neon with a black bolt while free, black
/// with a neon bolt once used, and the key gets crossed out. Always these two
/// colors, whichever theme is on.
class _KeyRow extends StatelessWidget {
  const _KeyRow({required this.name, required this.value, required this.used, required this.onTap});

  static const _green = Color(0xFFC6FF1A);
  static const _black = Color(0xFF000000);

  final String name;
  final String value;
  final bool used;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return BoltBox(
      color: BoltColors.surface1,
      stroke: const Stroke(BoltColors.lineSoft),
      radius: 14,
      padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
      child: Row(
        children: [
          SizedBox(
            width: 74,
            child: Text(tx(name), style: BoltText.a(12, weight: 700, color: BoltColors.muted)),
          ),
          Expanded(
            child: Text(
              value,
              style: BoltText.m(16, weight: 700, color: used ? BoltColors.muted3 : BoltColors.text).copyWith(
                decoration: used ? TextDecoration.lineThrough : TextDecoration.none,
                decorationColor: BoltColors.muted,
                decorationThickness: 2,
              ),
            ),
          ),
          Semantics(
            button: true,
            label: name,
            child: Tap(
              onTap: onTap,
              child: BoltBox(
                width: 44,
                height: 44,
                radius: 12,
                alignment: Alignment.center,
                color: used ? _black : _green,
                stroke: const Stroke(_green),
                child: BoltIcon('bolt', size: 22, color: used ? _green : _black),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
