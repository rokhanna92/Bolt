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
}
