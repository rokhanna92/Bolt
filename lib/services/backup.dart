import 'package:flutter/services.dart';

/// Saves and opens backup files with Android's own file pickers.
abstract final class BackupFiles {
  static const _channel = MethodChannel('bolt/backup');

  /// True when saved, null when the user cancelled. Throws on failure.
  static Future<bool?> save(String name, String text) =>
      _channel.invokeMethod<bool>('save', {'name': name, 'text': text});

  /// The picked file's text, or null when the user cancelled.
  static Future<String?> open() => _channel.invokeMethod<String>('open');
}
