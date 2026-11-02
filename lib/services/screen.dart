import 'package:flutter/services.dart';

/// The hardware keys during a workout (Android).
abstract final class Screen {
  static const _channel = MethodChannel('bolt/screen');

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
