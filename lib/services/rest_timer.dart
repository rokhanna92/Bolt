import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/l10n.dart';
import 'notifications.dart';

/// Sounds at the end of a rest: off, a clean beep or a two-note chime.
const kRestSounds = ['chime', 'beep', 'off'];

/// The countdown between sets, or of a timed set, that keeps going on the
/// lock screen with Bolt in the background.
abstract class RestTimer {
  /// Counts down to [end] ([total] seconds in all). A rest gets −15, +15 and
  /// Skip on the lock screen; a timed set does not.
  Future<void> start({
    required DateTime end,
    required int total,
    required String title,
    required String body,
    required bool rest,
    required String sound,
    required bool countdown,
    required bool haptics,
  });

  Future<void> stop();

  /// Plays a sound's end cue once, to hear it in Settings.
  Future<void> preview(String sound);

  /// The lock screen's buttons: a new end after −15 or +15, null after Skip.
  Stream<DateTime?> get changes;

  /// The phone plays the end cue itself (sound and vibration), so the
  /// screen should not add its own.
  bool get cuesNatively;
}

class NoopRestTimer implements RestTimer {
  const NoopRestTimer();

  @override
  Future<void> start({
    required DateTime end,
    required int total,
    required String title,
    required String body,
    required bool rest,
    required String sound,
    required bool countdown,
    required bool haptics,
  }) async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> preview(String sound) async {}

  @override
  Stream<DateTime?> get changes => const Stream.empty();

  @override
  bool get cuesNatively => false;
}

/// Android: a foreground service with a Live Update notification, sounds
/// and haptics (RestTimerService.kt).
class AndroidRestTimer implements RestTimer {
  AndroidRestTimer() {
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'changed':
          _changes.add(DateTime.fromMillisecondsSinceEpoch(call.arguments as int));
        case 'skipped':
          _changes.add(null);
      }
    });
  }

  static const _channel = MethodChannel('bolt/rest');
  final _changes = StreamController<DateTime?>.broadcast();

  @override
  Future<void> start({
    required DateTime end,
    required int total,
    required String title,
    required String body,
    required bool rest,
    required String sound,
    required bool countdown,
    required bool haptics,
  }) async {
    try {
      await _channel.invokeMethod<void>('start', {
        'end': end.millisecondsSinceEpoch,
        'total': total,
        'title': title,
        'body': body,
        'rest': rest,
        'sound': sound,
        'countdown': countdown,
        'haptics': haptics,
        'minus': '−15 s',
        'plus': '+15 s',
        'skipLabel': tx('Skip'),
        'channel': tx('Rest timer'),
        'channelAbout': tx('Countdown between sets'),
      });
    } catch (_) {}
  }

  @override
  Future<void> stop() async {
    try {
      await _channel.invokeMethod<void>('stop');
    } catch (_) {}
  }

  @override
  Future<void> preview(String sound) async {
    try {
      await _channel.invokeMethod<void>('preview', sound);
    } catch (_) {}
  }

  @override
  Stream<DateTime?> get changes => _changes.stream;

  @override
  bool get cuesNatively => true;
}

/// Elsewhere: the plain countdown notification, and the screen buzzes.
class NotificationRestTimer implements RestTimer {
  const NotificationRestTimer(this._notify);

  final BoltNotifications _notify;

  @override
  Future<void> start({
    required DateTime end,
    required int total,
    required String title,
    required String body,
    required bool rest,
    required String sound,
    required bool countdown,
    required bool haptics,
  }) => _notify.showRest(end, body);

  @override
  Future<void> stop() => _notify.clearRest();

  @override
  Future<void> preview(String sound) async {}

  @override
  Stream<DateTime?> get changes => const Stream.empty();

  @override
  bool get cuesNatively => false;
}

final restTimerProvider = Provider<RestTimer>((ref) => const NoopRestTimer());
