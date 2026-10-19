import 'dart:io' show Platform;

import 'package:flutter/services.dart';

/// What a touch should feel like, named for the moment rather than the motor
/// so the same thing feels the same on every screen.
enum Feel {
  /// A stepper or wheel moving one notch.
  tick,

  /// Landing on a round number while stepping.
  detent,

  /// A button that does something.
  tap,

  /// A switch turned on or off.
  on,
  off,

  /// A set ticked off: a plate racked.
  set,

  /// A workout finished, a badge or a level.
  success,

  /// A personal record or a new rank.
  record,

  /// Something refused, like a wrong code.
  error,
}

/// Haptics on purpose: steppers tick, sets land with a thud, records swell.
/// Android plays them natively (see BoltHaptics.kt) with the phone maker's
/// tuning and rich patterns; elsewhere Flutter's built-in feedback stands in.
abstract final class Haptics {
  /// Off in Settings. Set by the store.
  static bool enabled = true;

  static const _channel = MethodChannel('bolt/haptics');

  static void play(Feel f) {
    if (!enabled) return;
    if (Platform.isAndroid) {
      _channel.invokeMethod<void>('play', f.name).catchError((_) => _fallback(f));
    } else {
      _fallback(f);
    }
  }

  static void _fallback(Feel f) {
    switch (f) {
      case Feel.tick:
      case Feel.off:
        HapticFeedback.selectionClick();
      case Feel.detent:
      case Feel.tap:
      case Feel.on:
        HapticFeedback.lightImpact();
      case Feel.set:
        HapticFeedback.mediumImpact();
      case Feel.success:
        HapticFeedback.successNotification();
      case Feel.record:
        HapticFeedback.heavyImpact();
        Future.delayed(const Duration(milliseconds: 140), HapticFeedback.successNotification);
      case Feel.error:
        HapticFeedback.errorNotification();
    }
  }
}
