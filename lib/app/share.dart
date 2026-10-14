import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../data/share_codes.dart';
import '../theme/text_styles.dart';
import '../theme/tokens.dart';
import '../widgets/bolt_sheet.dart';
import '../widgets/common.dart';

/// Opens the share sheet with [text]. If sharing is unavailable, copies it so
/// it can be pasted into any chat. Returns a hint for a toast when copied.
Future<String?> shareMessage(String text, {required String subject}) async {
  try {
    await SharePlus.instance.share(ShareParams(text: text, subject: subject));
    return null;
  } catch (_) {
    await Clipboard.setData(ClipboardData(text: text));
    return 'Copied · paste it into a message';
  }
}

/// Text on the clipboard if it holds a Bolt code.
Future<String?> clipboardCode() async {
  try {
    final t = (await Clipboard.getData(Clipboard.kTextPlain))?.text;
    return t != null && ShareCode.contains(t) ? t : null;
  } catch (_) {
    return null;
  }
}

/// Bottom sheet asking to confirm something hard to undo.
Future<bool> confirmSheet(
  BuildContext context, {
  required String title,
  required String body,
  required String confirm,
}) async {
  final ok = await showBoltSheet<bool>(
    context,
    (context) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: BoltText.a(20, weight: 900)),
        const SizedBox(height: 6),
        Text(body, style: BoltText.a(13, color: BoltColors.muted, height: 1.45)),
        const SizedBox(height: 16),
        NeonButton(
          label: confirm,
          height: 52,
          color: BoltColors.warn,
          scale: 1,
          onTap: () => Navigator.of(context).pop(true),
        ),
        const SizedBox(height: 8),
        OutlineButton(
          label: 'Cancel',
          color: BoltColors.text,
          borderColor: BoltColors.line,
          weight: 700,
          onTap: () => Navigator.of(context).pop(false),
        ),
      ],
    ),
  );
  return ok ?? false;
}
