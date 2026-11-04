import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Saves and opens backup files in the browser. Removing Bolt from an iPhone's
/// home screen erases its data, so this is the only copy that survives it.
abstract final class BackupFiles {
  /// True when saved, null when the user cancelled. Throws on failure.
  static Future<bool?> save(String name, String text) async {
    final parts = [Uint8List.fromList(utf8.encode(text)).toJS].toJS;
    final file = web.File(parts, name, web.FilePropertyBag(type: 'application/json'));
    // A phone's share sheet reaches Save to Files; elsewhere it downloads.
    if (_canShare(file)) {
      try {
        await web.window.navigator.share(web.ShareData(files: [file].toJS)).toDart;
        return true;
      } catch (e) {
        if ('$e'.contains('AbortError')) return null;
      }
    }
    _download(file, name);
    return true;
  }

  static bool _canShare(web.File file) {
    try {
      return web.window.navigator.canShare(web.ShareData(files: [file].toJS));
    } catch (_) {
      return false;
    }
  }

  static void _download(web.File file, String name) {
    final url = web.URL.createObjectURL(file);
    final a = web.HTMLAnchorElement()
      ..href = url
      ..download = name;
    web.document.body!.append(a);
    a.click();
    a.remove();
    Timer(const Duration(minutes: 1), () => web.URL.revokeObjectURL(url));
  }

  /// The picked file's text, or null when the user cancelled.
  static Future<String?> open() {
    final done = Completer<String?>();
    // No accept filter: iPhones grey out .json files with one.
    final input = web.HTMLInputElement()
      ..type = 'file'
      ..style.display = 'none';
    Future<void> read() async {
      final file = input.files?.item(0);
      input.remove();
      if (file == null) {
        done.complete(null);
        return;
      }
      try {
        done.complete((await file.text().toDart).toDart);
      } catch (e) {
        done.completeError(e);
      }
    }

    void onChange(web.Event _) => read();
    input.onchange = onChange.toJS;
    input.oncancel = ((web.Event _) {
      input.remove();
      done.complete(null);
    }).toJS;
    web.document.body!.append(input);
    input.click();
    return done.future;
  }
}
