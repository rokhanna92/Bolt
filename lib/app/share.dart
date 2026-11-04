import 'dart:io' if (dart.library.js_interop) '../web/io.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart' if (dart.library.js_interop) '../web/paths.dart';
import 'package:share_plus/share_plus.dart';

import '../l10n/l10n.dart';

import '../data/share_codes.dart';
import '../theme/text_styles.dart';
import '../theme/tokens.dart';
import '../widgets/bolt_sheet.dart';
import '../widgets/common.dart';

/// Opens the share sheet with [text]. If sharing is unavailable, copies it so
/// it can be pasted into any chat. Returns a hint for a toast when copied.
Future<String?> shareMessage(String text, {required String subject}) async {
  try {
    // Without a share sheet (a computer's browser) copy it, rather than
    // opening an email.
    await SharePlus.instance.share(ShareParams(text: text, subject: subject, mailToFallbackEnabled: false));
    return null;
  } catch (_) {
    await Clipboard.setData(ClipboardData(text: text));
    return tx('Copied · paste it into a message');
  }
}

/// Opens the share sheet with a PNG. A browser has no files to point at, so
/// there it is handed over in memory, and downloads without a share sheet.
Future<void> sharePng(Uint8List png, String name, String subject) async {
  final XFile file;
  if (kIsWeb) {
    file = XFile.fromData(png, name: name, mimeType: 'image/png');
  } else {
    final dir = await getTemporaryDirectory();
    final f = File('${dir.path}/$name');
    await f.writeAsBytes(png);
    file = XFile(f.path, mimeType: 'image/png');
  }
  await SharePlus.instance.share(ShareParams(files: [file], subject: subject));
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
          label: tx('Cancel'),
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
