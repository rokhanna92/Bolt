import 'dart:async';
import 'dart:js_interop';
import 'dart:math' as math;

import 'package:web/web.dart' as web;

import '../services/rest_timer.dart';

/// One partial of a tone: frequency, loudness and how fast it fades.
typedef _Partial = (double hz, double amp, double decay);

/// The rest timer's sounds, the same tones as Android's BoltTones.kt. There is
/// no lock screen timer here: the countdown is on the page, and browsers stop
/// sounds and timers once the page is hidden. On return it picks up from the
/// clock.
class WebRestTimer implements RestTimer {
  WebRestTimer() {
    // Browsers only let sound start from a touch, and iPhones stop it again
    // in the background, so every touch gets it going if needed.
    web.window.addEventListener('pointerup', ((web.Event _) => _wake()).toJS);
    web.document.addEventListener(
      'visibilitychange',
      ((web.Event _) {
        if (!web.document.hidden && _end != null) _arm();
      }).toJS,
    );
  }

  web.AudioContext? _audio;
  DateTime? _end;
  String _sound = 'off';
  bool _blips = false;
  final _nodes = <web.OscillatorNode>[];

  web.AudioContext? _wake() {
    try {
      final a = _audio ??= web.AudioContext();
      if (a.state != 'running') a.resume();
      return a;
    } catch (_) {
      return null;
    }
  }

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
    _end = end;
    _sound = sound;
    _blips = countdown;
    _arm();
  }

  /// Schedules what is left of the countdown from the clock.
  void _arm() {
    _clear();
    final end = _end;
    final a = _wake();
    if (end == null || a == null || _sound == 'off') return;
    final left = end.difference(DateTime.now()).inMilliseconds / 1000;
    if (left <= 0) return;
    if (_blips) {
      for (final s in const [3, 2, 1]) {
        if (left > s) _play(a, _blip(_sound), a.currentTime + left - s);
      }
    }
    _play(a, _endCue(_sound), a.currentTime + left);
  }

  /// A rest ending by itself also lands here, right around the end cue, and
  /// must not cut it off.
  @override
  Future<void> stop() async {
    final end = _end;
    _end = null;
    if (end != null && end.difference(DateTime.now()).inMilliseconds > 250) _clear();
  }

  void _clear() {
    for (final n in _nodes) {
      try {
        n.stop();
      } catch (_) {}
    }
    _nodes.clear();
  }

  @override
  Future<void> preview(String sound) async {
    final a = _wake();
    if (a != null) _play(a, _endCue(sound), a.currentTime);
  }

  @override
  Future<void> blip(String sound) async {
    final a = _wake();
    if (a != null) _play(a, _blip(sound), a.currentTime);
  }

  void _play(web.AudioContext a, List<(double, List<_Partial>)> notes, double at) {
    for (final (delay, partials) in notes) {
      final start = at + delay;
      for (final (hz, amp, decay) in partials) {
        final gain = a.createGain();
        gain.gain
          ..setValueAtTime(0, start)
          // 4 ms attack so nothing clicks.
          ..linearRampToValueAtTime(amp, start + .004)
          ..setTargetAtTime(0, start + .004, 1 / decay);
        gain.connect(a.destination);
        final osc = a.createOscillator()..frequency.value = hz;
        osc.connect(gain);
        osc.start(start);
        osc.stop(start + math.min(1.2, 8 / decay));
        _nodes.add(osc);
      }
    }
    if (_nodes.length > 64) _nodes.removeRange(0, _nodes.length - 64);
  }

  static List<_Partial> _bell(double hz) => [(hz, .26, 4.5), (hz * 2.76, .08, 7), (hz * 5.4, .03, 11)];

  static List<(double, List<_Partial>)> _endCue(String sound) => switch (sound) {
    'beep' => const [
      (0.0, [(1046.5, .38, 9.0), (2093.0, .05, 14.0)]),
    ],
    'chime' => [(0.0, _bell(1318.5)), (.13, _bell(1760))],
    _ => const [],
  };

  static List<(double, List<_Partial>)> _blip(String sound) => switch (sound) {
    'beep' => const [
      (0.0, [(880.0, .32, 45.0)]),
    ],
    'chime' => const [
      (0.0, [(1568.0, .22, 38.0), (3136.0, .04, 60.0)]),
    ],
    _ => const [],
  };

  /// The lock screen's buttons do not exist here.
  @override
  Stream<DateTime?> get changes => const Stream.empty();

  @override
  bool get cuesNatively => false;
}
