import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../data/bolt_store.dart';
import '../../data/licenses.dart';
import '../../services/haptics.dart';
import '../../theme/text_styles.dart';
import '../../theme/tokens.dart';
import '../../widgets/box.dart';
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
  bool _waiting = false;

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
      case KeyResult.pending:
        Haptics.play(Feel.error);
        setState(() => _waiting = true);
      case KeyResult.wrong:
        Haptics.play(Feel.error);
        setState(() => _error = tx('That key does not open Bolt. Check it and try again.'));
    }
  }

  @override
  Widget build(BuildContext context) {
    return BoltPage(
      child: ScreenScroll(
        top: 72,
        bottom: 40,
        children: [FadeSlideIn(key: ValueKey(_waiting), child: _waiting ? _pending() : _entry())],
      ),
    );
  }

  Widget _entry() {
    final ok = _code.text.trim().length >= 5;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('BOLT', style: BoltText.a(42, weight: 900, color: BoltColors.neon, width: 112, spacing: -.02)),
        const SizedBox(height: 10),
        Kicker(tx('ACCESS KEY')),
        const SizedBox(height: 18),
        Text(tx('Type your key'), style: BoltText.a(28, weight: 900, width: 112, spacing: -.02)),
        const SizedBox(height: 6),
        Text(
          tx('Bolt asks for a key again after this update. Everything you have logged is still on this phone.'),
          style: BoltText.a(13, color: BoltColors.muted, height: 1.45),
        ),
        FieldLabel(tx('KEY'), top: 26),
        BoltField(
          controller: _code,
          hint: tx('5 or 6 digits'),
          number: true,
          onChanged: (_) => setState(() => _error = null),
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!, style: BoltText.a(13, weight: 600, color: BoltColors.warn)),
        ],
        const SizedBox(height: 22),
        NeonButton(label: tx('Open Bolt'), onTap: ok ? _enter : null),
      ],
    );
  }

  /// A real coach key, waiting on the owner's switch. No timer, no promise:
  /// it opens when the owner turns it on.
  Widget _pending() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('BOLT', style: BoltText.a(42, weight: 900, color: BoltColors.neon, width: 112, spacing: -.02)),
        const SizedBox(height: 10),
        Kicker(tx('COACH KEY')),
        const SizedBox(height: 18),
        Text(tx('Not switched on yet'), style: BoltText.a(28, weight: 900, width: 112, spacing: -.02)),
        const SizedBox(height: 10),
        BoltBox(
          color: BoltColors.surface1,
          stroke: const Stroke(BoltColors.line),
          radius: BoltRadii.card,
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tx('Your key is a real one and Bolt recognises it.'),
                style: BoltText.a(15, weight: 700, height: 1.4),
              ),
              const SizedBox(height: 8),
              Text(
                tx(
                  'Coach access is switched on by hand by the owner of Bolt. Message them and they will turn your key on.',
                ),
                style: BoltText.a(13, color: BoltColors.muted, height: 1.45),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        NeonButton(
          label: tx('Try another key'),
          color: BoltColors.surface2,
          textColor: BoltColors.text,
          onTap: () => setState(() {
            _waiting = false;
            _code.clear();
          }),
        ),
      ],
    );
  }
}
