import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';

import '../../app/share.dart';
import '../../data/bolt_store.dart';
import '../../theme/text_styles.dart';
import '../../theme/tokens.dart';
import '../../widgets/common.dart';
import '../../widgets/fields.dart';

/// Paste a plan (trainee) or an update (coach) that arrived as a message.
class ImportSheet extends ConsumerStatefulWidget {
  const ImportSheet({super.key});

  @override
  ConsumerState<ImportSheet> createState() => _ImportSheetState();
}

class _ImportSheetState extends ConsumerState<ImportSheet> {
  final _text = TextEditingController();
  String? _error;

  @override
  void initState() {
    super.initState();
    clipboardCode().then((t) {
      if (t != null && mounted && _text.text.isEmpty) setState(() => _text.text = t);
    });
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _paste() async {
    final t = (await Clipboard.getData(Clipboard.kTextPlain))?.text ?? '';
    setState(() {
      _text.text = t;
      _error = t.isEmpty ? tx('The clipboard is empty. Copy the message first.') : null;
    });
  }

  void _import() {
    final err = ref.read(boltProvider.notifier).importText(_text.text);
    if (err == null) {
      Navigator.of(context).pop();
    } else {
      setState(() => _error = err);
    }
  }

  @override
  Widget build(BuildContext context) {
    final coach = ref.watch(boltProvider).account?.isCoach ?? false;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(coach ? tx('Import update') : tx('Import plan'), style: BoltText.a(20, weight: 900)),
        const SizedBox(height: 6),
        Text(
          coach
              ? tx('Copy the update message your trainee sent you, then paste it here.')
              : tx('Copy the plan message your coach sent you, then paste it here.'),
          style: BoltText.a(13, color: BoltColors.muted, height: 1.45),
        ),
        const SizedBox(height: 14),
        BoltTextArea(controller: _text, hint: tx('Paste the message here'), minHeight: 96),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!, style: BoltText.a(12, color: BoltColors.warn, height: 1.4)),
        ],
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlineButton(
                label: tx('Paste'),
                height: 52,
                color: BoltColors.text,
                borderColor: BoltColors.line,
                weight: 700,
                onTap: _paste,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: NeonButton(label: tx('Import'), height: 52, scale: 1, onTap: _import),
            ),
          ],
        ),
      ],
    );
  }
}
