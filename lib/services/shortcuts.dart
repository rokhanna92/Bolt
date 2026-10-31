import 'package:flutter/services.dart';

/// The app icon's long-press shortcuts (Android): `scan`, `workout`, `gym`;
/// and `update` from the new-version notification.
abstract final class AppShortcuts {
  static const _channel = MethodChannel('bolt/shortcuts');

  /// Calls [onShortcut] for the shortcut Bolt was launched with, and for any
  /// picked while it runs.
  static void listen(void Function(String) onShortcut) {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'open' && call.arguments is String) onShortcut(call.arguments as String);
    });
    _channel
        .invokeMethod<String>('initial')
        .then((s) {
          if (s != null) onShortcut(s);
        })
        .catchError((_) => null);
  }

  /// Sends Bolt to the background, back to where the user came from.
  static Future<void> toBackground() async {
    try {
      await _channel.invokeMethod<bool>('background');
    } catch (_) {}
  }
}
