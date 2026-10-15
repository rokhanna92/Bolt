import 'package:flutter/services.dart';

/// Sends what the Android home screen widget shows. Fails silently where
/// there is no widget support.
abstract final class HomeWidget {
  static const _channel = MethodChannel('bolt/widget');

  static Future<void> update(Map<String, Object?> data) async {
    try {
      await _channel.invokeMethod<bool>('update', data);
    } catch (_) {}
  }
}
