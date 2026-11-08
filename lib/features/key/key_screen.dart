import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../data/bolt_store.dart';
import '../../data/licenses.dart';
import '../../services/haptics.dart';
import '../../theme/text_styles.dart';
import '../../theme/tokens.dart';
import '../../widgets/common.dart';
import '../../widgets/fields.dart';
import '../../widgets/forms.dart';
import '../../widgets/motion.dart';

/// The lock on the front door. Every phone types its key once after a key
/// generation goes up; training data on the phone is never touched.
/// A coach key the owner has not switched on yet lands on [_pending].
class KeyScreen extends ConsumerStatefulWidget {
  const KeyScreen({super.key});

  @override
  ConsumerState<KeyScreen> createState() => _KeyScreenState();
}

class _KeyScreenState extends ConsumerState<KeyScreen> {
  final _code = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  void _enter() {
    FocusScope.of(context).unfocus();
    switch (ref.read(boltProvider.notifier).enterKey(_code.text)) {
      case KeyResult.ok:
        Haptics.play(Feel.success);
      case KeyResult.needsCoach:
        Haptics.play(Feel.error);
        setState(() => _error = tx('This phone is set up for coaching, so it needs a coach key.'));
      case KeyResult.wrong:
        Haptics.play(Feel.error);
        setState(() => _error = tx('That key does not open Bolt. Check it and try again.'));
    }
  }

  @override
  Widget build(BuildContext context) {
    return BoltPage(
      child: ScreenScroll(top: 72, bottom: 40, children: [FadeSlideIn(child: _entry())]),
    );
  }

  Widget _entry() {
    final ok = _code.text.trim().length >= 5;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('BOLT', style: BoltText.display(48, color: BoltColors.neon)),
        const SizedBox(height: 10),
        Kicker(tx('ACCESS KEY')),
        const SizedBox(height: 18),
        Text(tx('Type your key'), style: BoltText.display(32)),
        const SizedBox(height: 6),
        Text(
          tx('Bolt asks for a key again after this update. Everything you have logged is still on this phone.'),
          style: BoltText.a(13, color: BoltColors.muted, height: 1.45),
        ),
        FieldLabel(tx('KEY'), top: 26),
        BoltField(controller: _code, hint: tx('Your key'), onChanged: (_) => setState(() => _error = null)),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!, style: BoltText.a(13, weight: 600, color: BoltColors.warn)),
        ],
        const SizedBox(height: 22),
        NeonButton(label: tx('Open Bolt'), onTap: ok ? _enter : null),
      ],
    );
  }
}
