import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../data/bolt_store.dart';
import '../../data/models/bolt_data.dart';
import '../../theme/text_styles.dart';
import '../../theme/tokens.dart';
import '../../widgets/box.dart';
import '../../widgets/common.dart';
import '../../widgets/tap.dart';

/// Account picker, styled after the prototype's guide panel. Picking an
/// account signs in with that role; the router takes it from there.
class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(boltProvider);
    final store = ref.read(boltProvider.notifier);
    return BoltPage(
      child: ScreenScroll(
        top: 40,
        bottom: 40,
        children: [
          Text('BOLT', style: BoltText.a(40, weight: 900, width: 125, spacing: .02, color: BoltColors.neon, height: 1)),
          const SizedBox(height: 6),
          Text(
            'Pick an account to sign in. Coach and trainee views share this device, so changes show up on both sides.',
            style: BoltText.a(13, color: BoltColors.muted, height: 1.5),
          ),
          const SizedBox(height: 22),
          const Kicker('COACHES', size: 10, spacing: .14),
          const SizedBox(height: 8),
          for (final c in d.coaches) ...[
            _Account(
              name: c.name,
              sub: plural(d.trainees.where((x) => x.coach == c.id).length, 'trainee').toUpperCase(),
              onTap: () => store.signIn(Role.coach, c.id),
            ),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 14),
          const Kicker('TRAINEES', size: 10, spacing: .14),
          const SizedBox(height: 8),
          for (final t in d.trainees) ...[
            _Account(
              name: t.name,
              sub: 'COACH ${firstName(store.co(t.coach).name).toUpperCase()}',
              onTap: () => store.signIn(Role.trainee, t.id),
            ),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 14),
          Text(
            'Try: as Marko, open Ana → tap empty days → Send. Then as Ana, accept or move them. Tap the center button to scan in/out.',
            style: BoltText.a(12, color: BoltColors.muted2, height: 1.6),
          ),
          const SizedBox(height: 22),
          Align(
            alignment: Alignment.centerLeft,
            child: Tap(
              onTap: () {
                store.resetDemo();
                store.toast('Demo reset');
              },
              child: BoltBox(
                radius: 10,
                stroke: const Stroke(BoltColors.line),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                child: Text('Reset demo', style: BoltText.a(12, weight: 700, color: BoltColors.muted)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Account extends StatelessWidget {
  const _Account({required this.name, required this.sub, required this.onTap});

  final String name;
  final String sub;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tap(
      onTap: onTap,
      scale: .98,
      child: BoltBox(
        radius: 12,
        stroke: const Stroke(BoltColors.line),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(
          children: [
            Expanded(child: Text(name, style: BoltText.a(14, weight: 800))),
            Text(sub, style: BoltText.m(9, color: BoltColors.muted)),
          ],
        ),
      ),
    );
  }
}
