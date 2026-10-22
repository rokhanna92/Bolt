import 'package:flutter/services.dart';

/// The screen during a workout (Android): kept on while the workout page is
/// open, so the rest countdown stays in view without touching the phone.
abstract final class Screen {
  static const _channel = MethodChannel('bolt/screen');

  static Future<void> keepOn(bool on) async {
    try {
      await _channel.invokeMethod<void>('keepOn', on);
    } catch (_) {}
  }

  /// Volume down calls [onPress] instead of turning the volume down; null
  /// gives the key back to the volume.
  static Future<void> volumeKey(VoidCallback? onPress) async {
    _channel.setMethodCallHandler(
      onPress == null
          ? null
          : (call) async {
              if (call.method == 'volumeDown') onPress();
            },
    );
    try {
      await _channel.invokeMethod<void>('volumeKey', onPress != null);
    } catch (_) {}
  }
}
